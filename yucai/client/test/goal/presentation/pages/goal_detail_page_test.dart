// Task 14 — widget tests for GoalDetailPage(header + linked + contribute +
// complete/delete/clone/edit + trend placeholder)。
//
// 驱动真实 GoalBloc(mocktail GoalRepository),seed GoalDetailLoaded。
// 验证(对齐 brief + budget detail_test 范式):
//   - header:Name + 类型徽章 + 进度环(UsagePct%)+ current/target + 还差 + deadline。
//   - 关联列表:linkedAccountIds / linkedDebtIds 显占位;空显「暂无关联」。
//   - 趋势占位:Text「趋势曲线 Phase 2」+ Phase 2 badge。
//   - loading → CircularProgressIndicator;error → message。
//   - 手动贡献 dialog:输入金额 → dispatch RecordContributionRequested。
//   - 完成 tap → dispatch CompleteGoalRequested。
//   - 删除 → confirm dialog → 确认 → dispatch DeleteGoalRequested + pop 回列表。
//   - 复制 tap → dispatch CloneGoalRequested。
//   - 编辑 tap → push '/goals/:id/edit'。
//
// 复用 budget_detail_page_test 的 harness 范式(plain MaterialApp + mock repo +
// GoRouter harness for edit/delete push/pop)。
import 'dart:async';

import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/goal/domain/repositories/goal_repository.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_bloc.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_event.dart';
import 'package:yucai_client/goal/presentation/pages/goal_detail_page.dart';

class _MockRepo extends Mock implements GoalRepository {}

GoalView _goal({
  required String id,
  required String name,
  GoalType type = GoalType.savings,
  required int target,
  int current = 0,
  String currency = 'CNY',
  DateTime? deadline,
  List<String> linkedAccountIds = const [],
  List<String> linkedDebtIds = const [],
  bool isCompleted = false,
}) =>
    GoalView(
      id: id,
      name: name,
      type: type,
      targetAmountCents: target,
      currentAmountCents: current,
      currencyCode: currency,
      deadline: deadline,
      linkedAccountIds: linkedAccountIds,
      linkedDebtIds: linkedDebtIds,
      isCompleted: isCompleted,
    );

/// harness:注入 GoalBloc(mock repo)。getGoal(any()) 固定返回 [goal]。
Widget _harness({required _MockRepo repo, required GoalView goal}) {
  return MaterialApp(
    home: BlocProvider<GoalBloc>(
      create: (_) => GoalBloc(repo),
      child: GoalDetailPage(id: goal.id),
    ),
  );
}

void _stubDetail(_MockRepo repo, GoalView goal) {
  when(() => repo.getGoal(any())).thenAnswer((_) async => dartz.Right(goal));
}

void main() {
  const desktop = Size(1400, 900);

  final goal = _goal(
    id: 'g1',
    name: '紧急备用金',
    type: GoalType.savings,
    target: 600000, // ¥6,000.00
    current: 240000, // ¥2,400.00 → 40%
    deadline: DateTime(2026, 12, 31),
    linkedAccountIds: const ['a1'],
    linkedDebtIds: const ['d1'],
  );

  void setDesktop(WidgetTester t) {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  group('header', () {
    testWidgets('renders name + type chip + ring + current/target + remaining',
        (t) async {
      setDesktop(t);
      final repo = _MockRepo();
      registerFallbackValue(const LoadListRequested());
      _stubDetail(repo, goal);

      await t.pumpWidget(_harness(repo: repo, goal: goal));
      await t.pumpAndSettle();

      // Name + 类型徽章。
      expect(find.text('紧急备用金'), findsOneWidget);
      expect(find.text('储蓄目标'), findsOneWidget);
      // 进度环 + UsagePct%。
      expect(find.byKey(const ValueKey('goalDetailRing')), findsOneWidget);
      expect(find.byKey(const ValueKey('goalDetailRingBar')), findsOneWidget);
      expect(find.byKey(const ValueKey('goalDetailUsagePct')), findsOneWidget);
      expect(find.text('40.0%'), findsOneWidget);
      // 还差(600000 - 240000 = 360000 → ¥3,600.00)。
      expect(find.textContaining('3,600.00'), findsOneWidget);
    });

    testWidgets('completed goal shows positive ring color + 已达成 status pill',
        (t) async {
      setDesktop(t);
      final repo = _MockRepo();
      registerFallbackValue(const LoadListRequested());
      final done = _goal(
        id: 'g2',
        name: '已完成目标',
        target: 100000,
        current: 100000,
        isCompleted: true,
      );
      _stubDetail(repo, done);

      await t.pumpWidget(_harness(repo: repo, goal: done));
      await t.pumpAndSettle();

      // 状态 pill「已完成」。
      expect(find.text('已完成'), findsAtLeast(1));
    });
  });

  group('linked entities', () {
    testWidgets('renders linked account + debt placeholder rows', (t) async {
      setDesktop(t);
      final repo = _MockRepo();
      registerFallbackValue(const LoadListRequested());
      _stubDetail(repo, goal);

      await t.pumpWidget(_harness(repo: repo, goal: goal));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('goalDetailLinkedTitle')), findsOneWidget);
      // account #a1 + debt #d1 占位(brief:account name lookup defer)。
      expect(find.text('账户 #a1'), findsOneWidget);
      expect(find.text('债务 #d1'), findsOneWidget);
    });

    testWidgets('shows 暂无关联 when no linked accounts/debts', (t) async {
      setDesktop(t);
      final repo = _MockRepo();
      registerFallbackValue(const LoadListRequested());
      final g = _goal(id: 'g3', name: '无关联目标', target: 50000);
      _stubDetail(repo, g);

      await t.pumpWidget(_harness(repo: repo, goal: g));
      await t.pumpAndSettle();

      expect(find.text('暂无关联'), findsOneWidget);
    });
  });

  group('trend placeholder', () {
    testWidgets('renders 趋势曲线 Phase 2 placeholder + badge', (t) async {
      setDesktop(t);
      final repo = _MockRepo();
      registerFallbackValue(const LoadListRequested());
      _stubDetail(repo, goal);

      await t.pumpWidget(_harness(repo: repo, goal: goal));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('goalDetailTrendPlaceholder')),
          findsOneWidget);
      expect(find.text('趋势曲线 Phase 2'), findsOneWidget);
      expect(find.byKey(const ValueKey('goalDetailTrendBadge')), findsOneWidget);
      expect(find.text('Phase 2'), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('loading state shows CircularProgressIndicator', (t) async {
      setDesktop(t);
      final repo = _MockRepo();
      registerFallbackValue(const LoadListRequested());
      final completer = Completer<dartz.Either<Failure, GoalView>>();
      when(() => repo.getGoal(any())).thenAnswer((_) => completer.future);
      await t.pumpWidget(_harness(repo: repo, goal: goal));
      await t.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('error state shows message', (t) async {
      setDesktop(t);
      final repo = _MockRepo();
      registerFallbackValue(const LoadListRequested());
      when(() => repo.getGoal(any())).thenAnswer(
          (_) async => const dartz.Left<Failure, GoalView>(ServerFailure('读取失败')));
      await t.pumpWidget(_harness(repo: repo, goal: goal));
      await t.pumpAndSettle();
      expect(find.textContaining('读取失败'), findsOneWidget);
    });
  });

  group('contribution dialog', () {
    testWidgets('dialog input → dispatch RecordContributionRequested', (t) async {
      setDesktop(t);
      final repo = _MockRepo();
      registerFallbackValue(const LoadListRequested());
      _stubDetail(repo, goal);
      // recordContribution stub(bloc 成功后 re-fetch via getGoal,已 stub)。
      when(() => repo.recordContribution(id: any(named: 'id'), amountCents: any(named: 'amountCents')))
          .thenAnswer((_) async => dartz.Right(goal));

      await t.pumpWidget(_harness(repo: repo, goal: goal));
      await t.pumpAndSettle();

      // 点底部「记一笔贡献」。
      await t.tap(find.byKey(const ValueKey('goalContributeBtn')));
      await t.pumpAndSettle();

      // dialog:输入 200.00 元。
      await t.enterText(
          find.byKey(const ValueKey('goalContributionInput')), '200');
      await t.tap(find.byKey(const ValueKey('goalContributionSubmit')));
      await t.pumpAndSettle();

      // 验证 dispatch:recordContribution(amountCents=20000)被调用 1 次。
      verify(() => repo.recordContribution(id: goal.id, amountCents: 20000))
          .called(1);
    });

    testWidgets('cancel does not dispatch', (t) async {
      setDesktop(t);
      final repo = _MockRepo();
      registerFallbackValue(const LoadListRequested());
      _stubDetail(repo, goal);

      await t.pumpWidget(_harness(repo: repo, goal: goal));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('goalContributeBtn')));
      await t.pumpAndSettle();

      await t.tap(find.text('取消'));
      await t.pumpAndSettle();

      verifyNever(() => repo.recordContribution(
          id: any(named: 'id'), amountCents: any(named: 'amountCents')));
    });
  });

  group('complete action', () {
    testWidgets('tap 标记完成 → dispatch CompleteGoalRequested', (t) async {
      setDesktop(t);
      final repo = _MockRepo();
      registerFallbackValue(const LoadListRequested());
      _stubDetail(repo, goal);
      when(() => repo.completeGoal(any()))
          .thenAnswer((_) async => const dartz.Right(null));

      await t.pumpWidget(_harness(repo: repo, goal: goal));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('goalCompleteBtn')));
      await t.pumpAndSettle();

      verify(() => repo.completeGoal(goal.id)).called(1);
    });
  });

  group('clone action', () {
    testWidgets('AppBar clone tap → dispatch CloneGoalRequested', (t) async {
      setDesktop(t);
      final repo = _MockRepo();
      registerFallbackValue(const LoadListRequested());
      _stubDetail(repo, goal);
      when(() => repo.cloneGoal(
              sourceId: any(named: 'sourceId'),
              targetAmountCents: any(named: 'targetAmountCents'),
              deadline: any(named: 'deadline'),
              name: any(named: 'name')))
          .thenAnswer((_) async => dartz.Right(goal));

      await t.pumpWidget(_harness(repo: repo, goal: goal));
      await t.pumpAndSettle();

      await t.tap(find.byTooltip('复制目标'));
      await t.pumpAndSettle();

      verify(() => repo.cloneGoal(
              sourceId: goal.id,
              targetAmountCents: any(named: 'targetAmountCents'),
              deadline: any(named: 'deadline'),
              name: any(named: 'name')))
          .called(1);
    });
  });

  group('edit action', () {
    testWidgets('AppBar edit tap pushes /goals/:id/edit', (t) async {
      setDesktop(t);
      final repo = _MockRepo();
      registerFallbackValue(const LoadListRequested());
      _stubDetail(repo, goal);

      String? pushed;
      final router = GoRouter(
        initialLocation: '/goals/${goal.id}',
        routes: [
          GoRoute(
            path: '/goals/:id',
            builder: (_, state) => BlocProvider<GoalBloc>(
              create: (_) => GoalBloc(repo),
              child: GoalDetailPage(id: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/goals/:id/edit',
            builder: (_, state) {
              pushed = state.pathParameters['id'];
              return const Scaffold(body: Center(child: Text('EDIT_STUB')));
            },
          ),
        ],
      );

      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();

      await t.tap(find.byTooltip('编辑'));
      await t.pumpAndSettle();

      expect(pushed, goal.id);
      expect(find.text('EDIT_STUB'), findsOneWidget);
    });
  });

  group('delete action', () {
    testWidgets('confirm dialog → dispatch DeleteGoalRequested + pop', (t) async {
      setDesktop(t);
      final repo = _MockRepo();
      registerFallbackValue(const LoadListRequested());
      _stubDetail(repo, goal);
      when(() => repo.deleteGoal(any()))
          .thenAnswer((_) async => const dartz.Right(null));
      when(() => repo.listGoals(type: any(named: 'type')))
          .thenAnswer((_) async => const dartz.Right([]));

      // GoRouter harness:list → detail 删除后 pop 回 list。
      final router = GoRouter(
        initialLocation: '/goals',
        routes: [
          GoRoute(
            path: '/goals',
            builder: (_, __) => BlocProvider<GoalBloc>(
              create: (_) => GoalBloc(repo),
              child: Scaffold(
                body: Center(
                  child: Builder(
                    builder: (ctx) => ElevatedButton(
                      key: const ValueKey('goDetail'),
                      onPressed: () => ctx.push('/goals/${goal.id}'),
                      child: const Text('进入详情'),
                    ),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/goals/:id',
            builder: (_, state) => BlocProvider<GoalBloc>(
              create: (_) => GoalBloc(repo),
              child: GoalDetailPage(id: state.pathParameters['id']!),
            ),
          ),
        ],
      );

      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('goDetail')));
      await t.pumpAndSettle();

      // 点删除 → confirm dialog。
      await t.tap(find.byTooltip('删除'));
      await t.pumpAndSettle();

      expect(find.text('删除目标'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);

      // 确认 → dispatch + pop 回列表。
      await t.tap(find.byKey(const ValueKey('goalDeleteConfirm')));
      await t.pumpAndSettle();

      verify(() => repo.deleteGoal(goal.id)).called(1);
      expect(find.text('进入详情'), findsOneWidget);
    });

    testWidgets('cancel does not dispatch', (t) async {
      setDesktop(t);
      final repo = _MockRepo();
      registerFallbackValue(const LoadListRequested());
      _stubDetail(repo, goal);

      await t.pumpWidget(_harness(repo: repo, goal: goal));
      await t.pumpAndSettle();

      await t.tap(find.byTooltip('删除'));
      await t.pumpAndSettle();

      await t.tap(find.text('取消'));
      await t.pumpAndSettle();

      verifyNever(() => repo.deleteGoal(any()));
    });
  });
}
