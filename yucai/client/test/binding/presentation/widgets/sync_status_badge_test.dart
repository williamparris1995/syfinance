// F12 T2(2026-09-05):SyncStatusBadge 单测(spec FR-1,design ADR-1/ADR-4)——
// - 四态渲染:syncing(spinner+「同步中」)/ failed(negative chip+原因+tap
//   重试)/ 其余态 N>0(muted chip「待同步 N」,无交互)/ clean(N==0)隐藏;
// - 渲染优先级:syncing/failed 优先于计数文本(failed 且 N>0 只显失败态);
// - guest 隐藏(tracker 判定,spec「仅绑定态渲染」);
// - 令牌:静态源码检查无裸色(Color(0x)/AppColors)+ 渲染色等于语义令牌值。
//
// bloc 用 mocktail 替身(照 backup_page_test 形态:state/stream stub);
// tracker 经 getIt 注册(照库内 widget 取 app 级单例的 guarded getIt 惯例)。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/binding/presentation/bloc/sync_coordinator_bloc.dart';
import 'package:yucai_client/binding/presentation/widgets/sync_status_badge.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/theme/app_theme.dart';

class _MockSyncBloc extends Mock implements SyncCoordinatorBloc {}

void main() {
  setUpAll(() => registerFallbackValue(SyncRetryRequested()));

  final getIt = GetIt.instance;
  setUp(getIt.reset);
  tearDown(getIt.reset);

  /// 挂载 harness:bloc 经 BlocProvider.value 注入(生产由 AppShell 提供),
  /// 主题走 AppTheme.light()(extension<YucaiTheme> 真注入,令牌断言用)。
  Future<void> pumpBadge(WidgetTester tester, {required SyncCoordinatorBloc bloc}) {
    return tester.pumpWidget(
      BlocProvider<SyncCoordinatorBloc>.value(
        value: bloc,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: Align(
              alignment: Alignment.centerLeft,
              child: SyncStatusBadge(),
            ),
          ),
        ),
      ),
    );
  }

  /// 构造 mock bloc(state 桩 + 空 stream,BlocBuilder 仅读初始态)。
  _MockSyncBloc stubBloc(SyncCoordinatorState state) {
    final bloc = _MockSyncBloc();
    when(() => bloc.state).thenReturn(state);
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
    return bloc;
  }

  /// badge 渲染出的 chip 容器(隐藏态无 Container → 由调用方先行断言可见)。
  Container chipOf(WidgetTester tester) => tester.widget<Container>(
        find.descendant(
          of: find.byType(SyncStatusBadge),
          matching: find.byType(Container),
        ),
      );

  group('隐藏态', () {
    testWidgets('guest:tracker 判定 guest → 零尺寸不渲染', (tester) async {
      getIt.registerSingleton<SessionModeTracker>(
          SessionModeTracker()..isGuest = true);
      final bloc = stubBloc(const SyncCoordinatorState(
          status: SyncStatus.clean, pendingCount: 3));
      await pumpBadge(tester, bloc: bloc);
      expect(tester.getSize(find.byType(SyncStatusBadge)), Size.zero);
    });

    testWidgets('无 DI 图(tracker 未注册)→ 零尺寸不渲染(OfflineBadge 守卫惯例)',
        (tester) async {
      final bloc = stubBloc(const SyncCoordinatorState(
          status: SyncStatus.clean, pendingCount: 3));
      await pumpBadge(tester, bloc: bloc);
      expect(tester.getSize(find.byType(SyncStatusBadge)), Size.zero);
    });

    testWidgets('clean 且 N==0 → 零尺寸不渲染(在线零感知)', (tester) async {
      getIt.registerSingleton<SessionModeTracker>(
          SessionModeTracker()..isGuest = false);
      final bloc = stubBloc(
          const SyncCoordinatorState(status: SyncStatus.clean, pendingCount: 0));
      await pumpBadge(tester, bloc: bloc);
      expect(tester.getSize(find.byType(SyncStatusBadge)), Size.zero);
    });

    testWidgets('idle 且 N==0(未触发过)→ 零尺寸不渲染', (tester) async {
      getIt.registerSingleton<SessionModeTracker>(
          SessionModeTracker()..isGuest = false);
      final bloc = stubBloc(
          const SyncCoordinatorState(status: SyncStatus.idle, pendingCount: 0));
      await pumpBadge(tester, bloc: bloc);
      expect(tester.getSize(find.byType(SyncStatusBadge)), Size.zero);
    });
  });

  group('待同步 chip(其余态 N>0)', () {
    testWidgets('idle + N>0(离线冷启动补扫计数)→「待同步 2」muted chip,无 onTap',
        (tester) async {
      getIt.registerSingleton<SessionModeTracker>(
          SessionModeTracker()..isGuest = false);
      final bloc = stubBloc(const SyncCoordinatorState(
          status: SyncStatus.idle, pendingCount: 2));
      await pumpBadge(tester, bloc: bloc);

      expect(find.text('待同步 2'), findsOneWidget);
      // muted 语义令牌(OfflineBadge 同款 0.15 底)。
      expect((chipOf(tester).decoration as BoxDecoration).color,
          YucaiTheme.light().muted.withValues(alpha: 0.15));
      // 无交互:tap 不发任何事件。
      await tester.tap(find.byType(SyncStatusBadge));
      await tester.pump();
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('clean + N>0(clean 后新增离线写)→「待同步 1」', (tester) async {
      getIt.registerSingleton<SessionModeTracker>(
          SessionModeTracker()..isGuest = false);
      final bloc = stubBloc(const SyncCoordinatorState(
          status: SyncStatus.clean, pendingCount: 1));
      await pumpBadge(tester, bloc: bloc);
      expect(find.text('待同步 1'), findsOneWidget);
    });
  });

  group('syncing 态', () {
    testWidgets('syncing + N>0 → spinner+「同步中」,计数文本让位(优先级)',
        (tester) async {
      getIt.registerSingleton<SessionModeTracker>(
          SessionModeTracker()..isGuest = false);
      final bloc = stubBloc(const SyncCoordinatorState(
          status: SyncStatus.syncing, pendingCount: 5));
      await pumpBadge(tester, bloc: bloc);

      expect(find.text('同步中'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('待同步 5'), findsNothing); // 优先级:同步中优先于计数。
    });
  });

  group('failed 态', () {
    testWidgets('failed + N>0 → 失败态优先计数不叠加;tap → SyncRetryRequested',
        (tester) async {
      getIt.registerSingleton<SessionModeTracker>(
          SessionModeTracker()..isGuest = false);
      final bloc = stubBloc(const SyncCoordinatorState(
        status: SyncStatus.failed,
        pendingCount: 5,
        failureReason: '无法连接服务器',
      ));
      await pumpBadge(tester, bloc: bloc);

      // 原因文本可见(截断由 maxWidth+ellipsis 承担,短原因完整展示)。
      expect(find.text('同步失败:无法连接服务器'), findsOneWidget);
      expect(find.text('待同步 5'), findsNothing); // 优先级:失败优先,计数不叠加。
      // negative 语义令牌。
      expect((chipOf(tester).decoration as BoxDecoration).color,
          YucaiTheme.light().negative.withValues(alpha: 0.15));

      // FR-4:点击 = 手动重试。
      await tester.tap(find.byType(SyncStatusBadge));
      await tester.pump();
      final events = verify(() => bloc.add(captureAny())).captured;
      expect(events.single, isA<SyncRetryRequested>());
    });

    testWidgets('failed 原因为 null → 兜底文案「同步失败:」', (tester) async {
      getIt.registerSingleton<SessionModeTracker>(
          SessionModeTracker()..isGuest = false);
      final bloc = stubBloc(
          const SyncCoordinatorState(status: SyncStatus.failed, pendingCount: 1));
      await pumpBadge(tester, bloc: bloc);
      expect(find.text('同步失败:同步失败'), findsNothing); // 不得拼接空原因。
      expect(find.byType(SyncStatusBadge).evaluate(), isNotEmpty);
      expect(find.textContaining('同步失败'), findsOneWidget);
    });
  });

  group('令牌守门(R8)', () {
    test('源码静态检查:无裸色 Color(0x) / 无 legacy AppColors 引用', () {
      final src = File('lib/binding/presentation/widgets/sync_status_badge.dart')
          .readAsStringSync();
      expect(src.contains('Color(0x'), isFalse,
          reason: 'R8 禁 v1 硬编码色:颜色须经 context.yucai 语义令牌');
      expect(src.contains('AppColors'), isFalse,
          reason: 'R8:AppColors 为 legacy 过渡层,新增 UI 禁用');
    });
  });
}
