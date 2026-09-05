import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/tag/domain/repositories/tag_repository.dart';
import 'package:yucai_client/tag/presentation/bloc/tag_bloc.dart';
import 'package:yucai_client/tag/presentation/pages/tag_page.dart';

class _MockRepo extends Mock implements TagRepository {}

const _sample = Tag(id: 't1', name: '日常', color: '#b08d57', version: 1);

final getIt = GetIt.instance;

Widget _harness(TagRepository repo) => MaterialApp(
      home: BlocProvider<TagBloc>(create: (_) => TagBloc(repo), child: const TagPage()),
    );

void main() {
  setUp(getIt.reset);
  tearDown(getIt.reset);

  testWidgets('renders tag name when list non-empty', (t) async {
    final repo = _MockRepo();
    when(() => repo.list()).thenAnswer((_) async => const Right([_sample]));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();
    expect(find.text('日常'), findsOneWidget);
    expect(find.text('标签管理'), findsOneWidget);
  });

  testWidgets('renders empty state when no tags', (t) async {
    final repo = _MockRepo();
    when(() => repo.list()).thenAnswer((_) async => const Right([]));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();
    expect(find.textContaining('暂无标签'), findsOneWidget);
  });

  testWidgets('renders error state when load fails', (t) async {
    final repo = _MockRepo();
    when(() => repo.list()).thenAnswer((_) async => const Left(ServerFailure('boom')));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();
    expect(find.text('重试'), findsOneWidget);
  });

  // F8 FR-3/ADR-4:标签卡 onTap → 交易列表带 tagId 初始筛选(extra 携参,
  // GoRouter harness 捕获 push 的 extra 断言)。
  testWidgets('F8 FR-3: 点标签卡 → push /transactions 携 tagId extra', (t) async {
    final repo = _MockRepo();
    when(() => repo.list()).thenAnswer((_) async => const Right([_sample]));

    Object? capturedExtra;
    final router = GoRouter(
      initialLocation: '/settings/tags',
      routes: [
        GoRoute(
          path: '/settings/tags',
          builder: (_, __) => BlocProvider<TagBloc>(
            create: (_) => TagBloc(repo),
            child: const TagPage(),
          ),
        ),
        GoRoute(
          path: '/transactions',
          builder: (_, state) {
            capturedExtra = state.extra;
            return const Scaffold(body: Text('txns'));
          },
        ),
      ],
    );
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
    expect(find.text('日常'), findsOneWidget);

    await t.tap(find.text('日常'));
    await t.pumpAndSettle();

    // push 是指令式压栈:目标页渲染在栈顶(currentConfiguration 仍指向
    // 基座 location),断言以渲染结果为准。
    expect(find.text('txns'), findsOneWidget);
    expect(capturedExtra, isA<Map>(),
        reason: 'extra 按 /holdings/trade Map 先例携参');
    expect((capturedExtra as Map)['tagId'], 't1');
  });

  // O-1(fix round 1):boundRemote(在线绑定)态标签卡不可点入交易列表 ——
  // 与 filter_bar.tagFilterAvailable 同一论证:junction 本地私有 → 远端
  // proto 无标签维度 → tagId 被静默忽略 → 入口一并隐藏(onOpen = null)。
  testWidgets('boundRemote 态:标签卡 tap 不跳转(onOpen null)', (t) async {
    final repo = _MockRepo();
    when(() => repo.list()).thenAnswer((_) async => const Right([_sample]));
    final tracker = SessionModeTracker()
      ..isGuest = false
      ..online = true; // 绑定 + 在线 → boundRemote
    getIt.registerSingleton<SessionModeTracker>(tracker);

    var navigated = false;
    final router = GoRouter(
      initialLocation: '/settings/tags',
      routes: [
        GoRoute(
          path: '/settings/tags',
          builder: (_, __) => BlocProvider<TagBloc>(
            create: (_) => TagBloc(repo),
            child: const TagPage(),
          ),
        ),
        GoRoute(
          path: '/transactions',
          builder: (_, state) {
            navigated = true;
            return const Scaffold(body: Text('txns'));
          },
        ),
      ],
    );
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
    expect(find.text('日常'), findsOneWidget);

    await t.tap(find.text('日常'));
    await t.pumpAndSettle();

    expect(navigated, isFalse, reason: 'boundRemote 态入口应隐藏,不可点入');
    expect(find.text('标签管理'), findsOneWidget, reason: '仍停留在标签页');
  });
}
