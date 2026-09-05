// TDD RED → GREEN:F8 T2 标签维度的 UI widget 层(spec FR-2,design ADR-3)。
//
// 覆盖:
//   - TxnFilterState.tagId 纯 Dart:copyWith 哨兵(设置/保留/清空)+ isDefault;
//   - TxnTagPicker 标签下拉(F8 FR-2/ADR-3):选项 = TagRepository.list 实时
//     (initState 预取);选择回调;「全部标签」清空;初始 tagId 在选项未载入
//     时不触发 Dropdown 的「value 必须在 items 中」断言崩溃,载入后正确回显;
//   - boundRemote 隐藏(F8 交付物 4,T1 review 观察 1):标签↔交易 junction
//     本地私有、远端 proto 无标签维度,在线绑定态 tagId 被远端静默忽略 ——
//     控件隐藏;guest/boundOffline 本地管道完整生效,正常展示。
//
// 主题:AppTheme.light() 注入 R8 语义令牌(context.yucai),禁裸色。
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/core/theme/app_theme.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/tag/domain/repositories/tag_repository.dart';
import 'package:yucai_client/transaction/presentation/widgets/filter_bar.dart';

class _MockTagRepo extends Mock implements TagRepository {}

const _tags = [
  Tag(id: 'tag-1', name: '日常', color: '#b08d57', version: 1),
  Tag(id: 'tag-2', name: '旅行', color: '#2d8a6e', version: 1),
];

final getIt = GetIt.instance;

Widget _harness(Widget child,
    {TagRepository? tagRepo, Size size = const Size(1440, 900)}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: RepositoryProvider<TagRepository>.value(
        value: tagRepo ?? _MockTagRepo(),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  setUp(getIt.reset);
  tearDown(getIt.reset);

  group('TxnFilterState.tagId 纯 Dart (FR-2)', () {
    test('copyWith tagId:设置/哨兵保留/清空', () {
      const s0 = TxnFilterState();
      expect(s0.tagId, isNull);

      // 设置。
      final s1 = s0.copyWith(tagId: 'tag-1');
      expect(s1.tagId, 'tag-1');
      // 哨兵:不传 tagId 的 copyWith 保留原值(与 accountId/category 同模式)。
      final s2 = s1.copyWith(searchText: '午餐');
      expect(s2.tagId, 'tag-1', reason: '无关字段变更不应清掉标签筛选');
      // 显式清空(传 null)。
      final s3 = s1.copyWith(tagId: null);
      expect(s3.tagId, isNull);
    });

    test('isDefault:tagId 非空 → 非默认(重置钮可点)', () {
      expect(const TxnFilterState().isDefault, isTrue);
      expect(const TxnFilterState(tagId: 'tag-1').isDefault, isFalse);
    });
  });

  group('TxnTagPicker 标签下拉 (FR-2/ADR-3)', () {
    testWidgets('选项 = TagRepository.list 实时(initState 预取)+ 全部标签清空态',
        (tester) async {
      final repo = _MockTagRepo();
      when(() => repo.list()).thenAnswer((_) async => const Right(_tags));
      await tester.pumpWidget(_harness(
          TxnTagPicker(value: null, onChanged: (_) {}),
          tagRepo: repo));
      await tester.pumpAndSettle();

      // 按钮初始显示「全部标签」;打开后选项 = 全部标签 + 日常 + 旅行。
      expect(find.text('全部标签'), findsOneWidget);
      await tester.tap(find.text('全部标签'));
      await tester.pumpAndSettle();
      expect(find.text('日常'), findsOneWidget);
      expect(find.text('旅行'), findsOneWidget);
    });

    testWidgets('选择标签 → onChanged 携标签 id', (tester) async {
      final repo = _MockTagRepo();
      when(() => repo.list()).thenAnswer((_) async => const Right(_tags));
      String? captured;
      await tester.pumpWidget(_harness(
          TxnTagPicker(value: null, onChanged: (v) => captured = v),
          tagRepo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('全部标签'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('旅行'));
      await tester.pumpAndSettle();

      expect(captured, 'tag-2', reason: 'value 口径是标签 id(与下拉 value 一致)');
    });

    testWidgets('「全部标签」→ onChanged(null) 清空', (tester) async {
      final repo = _MockTagRepo();
      when(() => repo.list()).thenAnswer((_) async => const Right(_tags));
      String? captured = 'sentinel';
      await tester.pumpWidget(_harness(
          TxnTagPicker(value: 'tag-1', onChanged: (v) => captured = v),
          tagRepo: repo));
      await tester.pumpAndSettle();
      expect(find.text('日常'), findsOneWidget, reason: '初始选中回显');

      await tester.tap(find.text('日常'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('全部标签'));
      await tester.pumpAndSettle();

      expect(captured, isNull, reason: '全部标签 = 清空态(与账户/分类下拉口径一致)');
    });

    testWidgets('初始 tagId 在选项未载入时不崩(Dropdown value∈items 断言),载入后回显',
        (tester) async {
      final repo = _MockTagRepo();
      when(() => repo.list()).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return const Right(_tags);
      });
      await tester.pumpWidget(_harness(
          TxnTagPicker(value: 'tag-1', onChanged: (_) {}),
          tagRepo: repo));

      // 选项未载入:选项集只含「全部标签」,value(tag-1)暂不可解析 —— 不应
      // 触发 DropdownButton「value 必须在 items 中」断言,先显示清空态。
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('全部标签'), findsOneWidget);

      // 选项载入后正确回显标签名。
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('日常'), findsOneWidget);
    });
  });

  group('boundRemote 态隐藏 (F8 交付物 4,T1 review 观察 1)', () {
    testWidgets('route==boundRemote(在线绑定)→ TxnTagPicker 隐藏', (tester) async {
      final repo = _MockTagRepo();
      when(() => repo.list()).thenAnswer((_) async => const Right(_tags));
      final tracker = SessionModeTracker()
        ..isGuest = false
        ..online = true; // 绑定 + 在线 → boundRemote
      getIt.registerSingleton<SessionModeTracker>(tracker);

      await tester.pumpWidget(_harness(
          TxnTagPicker(value: null, onChanged: (_) {}),
          tagRepo: repo));
      await tester.pumpAndSettle();

      expect(find.text('全部标签'), findsNothing,
          reason: 'junction 本地私有 + 远端 proto 无标签维度,'
              '在线绑定态选了没反应 → 隐藏');
    });

    testWidgets('guest / boundOffline(本地管道)→ 正常展示', (tester) async {
      final repo = _MockTagRepo();
      when(() => repo.list()).thenAnswer((_) async => const Right(_tags));
      final tracker = SessionModeTracker()
        ..isGuest = false
        ..online = false; // 绑定 + 离线 → boundOfflineLocal
      getIt.registerSingleton<SessionModeTracker>(tracker);

      await tester.pumpWidget(_harness(
          TxnTagPicker(value: null, onChanged: (_) {}),
          tagRepo: repo));
      await tester.pumpAndSettle();

      expect(find.text('全部标签'), findsOneWidget,
          reason: '离线绑定走本地镜像管道,标签过滤完整生效');
    });

    testWidgets('boundRemote → TxnFilterBar 不含标签下拉(guest → 含)',
        (tester) async {
      final repo = _MockTagRepo();
      when(() => repo.list()).thenAnswer((_) async => const Right(_tags));
      final tracker = SessionModeTracker()
        ..isGuest = false
        ..online = true;
      getIt.registerSingleton<SessionModeTracker>(tracker);
      late StateSetter setBarState;

      await tester.pumpWidget(_harness(
          StatefulBuilder(
            builder: (context, setState) {
              setBarState = setState;
              // 翻转后需显式重建(生产路径由 AuthBloc 发射驱动整树重建,
              // tracker 本身不通知;测试手动触发同语义)。
              return TxnFilterBar(
                state: const TxnFilterState(),
                onChanged: (_) {},
              );
            },
          ),
          tagRepo: repo));
      await tester.pumpAndSettle();
      expect(find.text('全部标签'), findsNothing);

      // 切回 guest + 触发重建:控件出现。
      tracker.isGuest = true;
      setBarState(() {});
      await tester.pumpAndSettle();
      expect(find.text('全部标签'), findsOneWidget);
    });
  });

  group('TxnFilterBar 集成 (FR-2)', () {
    testWidgets('标签下拉选择 → onChanged 回传携带 tagId 的新 state',
        (tester) async {
      final repo = _MockTagRepo();
      when(() => repo.list()).thenAnswer((_) async => const Right(_tags));
      TxnFilterState? captured;
      await tester.pumpWidget(_harness(
          TxnFilterBar(
            state: const TxnFilterState(),
            onChanged: (s) => captured = s,
          ),
          tagRepo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('全部标签').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('日常'));
      await tester.pumpAndSettle();

      expect(captured?.tagId, 'tag-1');
      // 其它字段不动(只动 tagId 维度)。
      expect(captured?.accountId, isNull);
      expect(captured?.searchText, isNull);
    });

    testWidgets('重置钮 → tagId 一并清空(isDefault 口径)', (tester) async {
      final repo = _MockTagRepo();
      when(() => repo.list()).thenAnswer((_) async => const Right(_tags));
      TxnFilterState? captured;
      await tester.pumpWidget(_harness(
          TxnFilterBar(
            state: const TxnFilterState(tagId: 'tag-1'),
            onChanged: (s) => captured = s,
          ),
          tagRepo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();

      expect(captured?.tagId, isNull);
      expect(captured?.isDefault, isTrue);
    });
  });
}
