// Task 14 — widget tests for GoalDetailPage(header + linked + contribute +
// complete/delete/clone/edit + trend placeholder)。
//
// Phase 1.5:关联卡 account/debt name lookup(mocktail AccountRepository +
// DebtRepository,通过 GetIt 注册;seed 已知 name → 验真名显示;Left → 回退 #id)。
//
// 驱动真实 GoalBloc(mocktail GoalRepository),seed GoalDetailLoaded。
// 验证(对齐 brief + budget detail_test 范式):
//   - header:Name + 类型徽章 + 进度环(UsagePct%)+ current/target + 还差 + deadline。
//   - 关联列表:linkedAccountIds / linkedDebtIds resolve 真名(Phase 1.5);空显「暂无关联」。
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
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/goal/domain/repositories/goal_repository.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_bloc.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_event.dart';
import 'package:yucai_client/goal/presentation/pages/goal_detail_page.dart';

class _MockRepo extends Mock implements GoalRepository {}
class _MockAccountRepo extends Mock implements AccountRepository {}
class _MockDebtRepo extends Mock implements DebtRepository {}

/// 测试用 Account(seed name 供关联卡 resolve 真名)。
Account _account({required String id, required String name}) => Account(
      id: id,
      name: name,
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      version: 1,
    );

/// 测试用 Debt(seed counterparty 供关联卡 resolve 真名)。
Debt _debt({required String id, required String counterparty}) => Debt(
      id: id,
      accountId: 'acc-debt',
      counterparty: counterparty,
      type: DebtType.borrowedIn,
      interestRate: 5.0,
      amortization: AmortizationMethod.equalPrincipalInterest,
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2027, 1, 1),
      totalPrincipalCents: 100000,
      remainingPrincipalCents: 100000,
      version: 1,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

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

/// harness:注入 GoalBloc(mock repo)+ 注册 Account/Debt repo(Phase 1.5
/// 关联卡 name lookup 经 GetIt)。getGoal(any()) 固定返回 [goal]。
/// accountRepo/debtRepo 默认 null → 注册返回空 list 的 mock(关联卡回退 #id);
/// 传入自定义 repo 时由测试方自行 stub list()(harness 不覆盖)。
/// Task 3:GoalDetailPage initState 经 GetIt 拉 GoalRepository.getProgressHistory
/// → harness 注册 [repo] 本身为 GoalRepository,并 stub 默认空 history(测试方可
/// 重 stub 为真实 points)。updater 注册 GoalRepository(与 detail page lazy
/// _historyFuture 取的 GetIt 同一容器)。
Widget _harness({
  required _MockRepo repo,
  required GoalView goal,
  _MockAccountRepo? accountRepo,
  _MockDebtRepo? debtRepo,
}) {
  final getIt = GetIt.instance;
  if (getIt.isRegistered<AccountRepository>()) getIt.unregister<AccountRepository>();
  if (getIt.isRegistered<DebtRepository>()) getIt.unregister<DebtRepository>();
  // 默认注册返回空 list 的 mock(lookup 未命中 → 回退 #id)。
  // 自定义 repo 由调用方 stub,harness 不覆盖(mocktail: 后 stub 覆盖前,
  // 但调用方 stub 在 pumpWidget 前 → harness 不会重 stub 自定义 repo)。
  final ar = accountRepo ?? _MockAccountRepo();
  final dr = debtRepo ?? _MockDebtRepo();
  if (accountRepo == null) {
    when(() => ar.list())
        .thenAnswer((_) async => const dartz.Right(<Account>[]));
  }
  if (debtRepo == null) {
    when(() => dr.list())
        .thenAnswer((_) async => const dartz.Right(<Debt>[]));
  }
  getIt.registerSingleton<AccountRepository>(ar);
  getIt.registerSingleton<DebtRepository>(dr);
  // 注册 [repo] 为 GoalRepository + 默认空 history(GoRouter harness 测试方
  // 用 _registerGoalRepo 自行注册)。
  _registerGoalRepo(repo);
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

/// 注册 [repo] 为 GoalRepository 到 GetIt(供 detail page lazy
/// _historyFuture 拉),并 stub 默认空 history(测试方可重 stub)。
/// GoRouter harness 测试未走 _harness → 手动调用此函数。
void _registerGoalRepo(_MockRepo repo) {
  final getIt = GetIt.instance;
  if (getIt.isRegistered<GoalRepository>()) {
    getIt.unregister<GoalRepository>();
  }
  getIt.registerSingleton<GoalRepository>(repo);
  when(() => repo.getProgressHistory(
          goalId: any(named: 'goalId'),
          from: any(named: 'from'),
          to: any(named: 'to')))
      .thenAnswer((_) async => const dartz.Right(<GoalProgressPoint>[]));
}

/// stub getProgressHistory(任何 goalId/from/to)返回 [points]。
void _stubHistory(_MockRepo repo, List<GoalProgressPoint> points) {
  when(() => repo.getProgressHistory(
          goalId: any(named: 'goalId'),
          from: any(named: 'from'),
          to: any(named: 'to')))
      .thenAnswer((_) async => dartz.Right(points));
}

void main() {
  const desktop = Size(1400, 900);

  // 每个测试前重置 GetIt(防止上个测试注册的 singleton 泄漏)。
  setUp(() {
    GetIt.instance.reset();
  });

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
      // 进度环(ConicProgressRing)+ UsagePct%。
      expect(find.byKey(const ValueKey('goalDetailRing')), findsOneWidget);
      expect(find.byKey(const ValueKey('conicRingPct')), findsOneWidget);
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
    testWidgets('resolves real account + debt names via repos (Phase 1.5)',
        (t) async {
      setDesktop(t);
      final repo = _MockRepo();
      registerFallbackValue(const LoadListRequested());
      _stubDetail(repo, goal);

      // seed account a1=招商储蓄 + debt d1=花呗 → 关联卡显真名。
      final accountRepo = _MockAccountRepo();
      final debtRepo = _MockDebtRepo();
      when(() => accountRepo.list()).thenAnswer((_) async =>
          dartz.Right(<Account>[_account(id: 'a1', name: '招商储蓄')]));
      when(() => debtRepo.list()).thenAnswer((_) async =>
          dartz.Right(<Debt>[_debt(id: 'd1', counterparty: '花呗')]));

      await t.pumpWidget(_harness(
        repo: repo,
        goal: goal,
        accountRepo: accountRepo,
        debtRepo: debtRepo,
      ));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('goalDetailLinkedTitle')), findsOneWidget);
      // Phase 1.5:resolve 真名(account.name / debt.counterparty),不再 #id 占位。
      expect(find.text('招商储蓄'), findsOneWidget);
      expect(find.text('花呗'), findsOneWidget);
      expect(find.text('账户 #a1'), findsNothing);
      expect(find.text('债务 #d1'), findsNothing);
    });

    testWidgets('best-effort fallback to #id when lookup returns empty list',
        (t) async {
      setDesktop(t);
      final repo = _MockRepo();
      registerFallbackValue(const LoadListRequested());
      _stubDetail(repo, goal);
      // 默认 harness 注册返回空 list 的 repo → 未命中 → 回退 #id。

      await t.pumpWidget(_harness(repo: repo, goal: goal));
      await t.pumpAndSettle();

      expect(find.text('账户 #a1'), findsOneWidget);
      expect(find.text('债务 #d1'), findsOneWidget);
    });

    testWidgets('best-effort fallback to #id when lookup fails (Left)',
        (t) async {
      setDesktop(t);
      final repo = _MockRepo();
      registerFallbackValue(const LoadListRequested());
      _stubDetail(repo, goal);

      final accountRepo = _MockAccountRepo();
      final debtRepo = _MockDebtRepo();
      // repo 抛 Left(ServerFailure)→ map 空 → 回退 #id。
      when(() => accountRepo.list()).thenAnswer((_) async =>
          const dartz.Left<Failure, List<Account>>(ServerFailure('网络错误')));
      when(() => debtRepo.list()).thenAnswer((_) async =>
          const dartz.Left<Failure, List<Debt>>(ServerFailure('网络错误')));

      await t.pumpWidget(_harness(
        repo: repo,
        goal: goal,
        accountRepo: accountRepo,
        debtRepo: debtRepo,
      ));
      await t.pumpAndSettle();

      expect(find.text('账户 #a1'), findsOneWidget);
      expect(find.text('债务 #d1'), findsOneWidget);
      // 不崩(无异常 widget)。
      expect(find.byType(FlutterError), findsNothing);
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

  group('trend chart', () {
    testWidgets('renders fl_chart LineChart when history has points', (t) async {
      setDesktop(t);
      final repo = _MockRepo();
      registerFallbackValue(const LoadListRequested());
      _stubDetail(repo, goal);
      final app = _harness(repo: repo, goal: goal);
      // harness 注册 GoalRepository + 默认空 history stub;此处重 stub 为真实 3 点
      // (mocktail 后 stub 覆盖前,在 pumpWidget 前重 stub → _historyFuture 用新值)。
      _stubHistory(repo, [
        GoalProgressPoint(
            date: DateTime(2026, 6, 1), currentAmountCents: 100000),
        GoalProgressPoint(
            date: DateTime(2026, 6, 15), currentAmountCents: 180000),
        GoalProgressPoint(
            date: DateTime(2026, 6, 30), currentAmountCents: 240000),
      ]);

      await t.pumpWidget(app);
      await t.pumpAndSettle();

      // 御财金近 30 天 badge(替 Phase 1 占位的 Phase 2 badge)。
      expect(find.byKey(const ValueKey('goalDetailTrendBadge')), findsOneWidget);
      expect(find.text('近 30 天'), findsOneWidget);
      // 占位文本已移除(Phase 1 退场)。
      expect(find.text('趋势曲线 Phase 2'), findsNothing);
      expect(find.byKey(const ValueKey('goalDetailTrendPlaceholder')),
          findsNothing);
      // fl_chart LineChart 渲染。
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.byKey(const ValueKey('goalDetailTrendChart')), findsOneWidget);
    });

    testWidgets('shows empty state when history is empty', (t) async {
      setDesktop(t);
      final repo = _MockRepo();
      registerFallbackValue(const LoadListRequested());
      _stubDetail(repo, goal);
      // harness 默认 stub 空 history → 直接 pumpWidget 即可验空态。

      await t.pumpWidget(_harness(repo: repo, goal: goal));
      await t.pumpAndSettle();

      // 空态文案 + 空 LineChart(不应有)。
      expect(find.byKey(const ValueKey('goalDetailTrendEmpty')), findsOneWidget);
      expect(find.text('暂无趋势数据'), findsOneWidget);
      expect(find.text('(scheduler 每日记录)'), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('shows empty state when history repo returns Left (failure)',
        (t) async {
      setDesktop(t);
      final repo = _MockRepo();
      registerFallbackValue(const LoadListRequested());
      _stubDetail(repo, goal);
      final app = _harness(repo: repo, goal: goal);
      // 重 stub 返 Left(ServerFailure)→ 空态(不崩)。
      when(() => repo.getProgressHistory(
              goalId: any(named: 'goalId'),
              from: any(named: 'from'),
              to: any(named: 'to')))
          .thenAnswer((_) async =>
              const dartz.Left<Failure, List<GoalProgressPoint>>(
                  ServerFailure('history 读取失败')));

      await t.pumpWidget(app);
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('goalDetailTrendEmpty')), findsOneWidget);
      expect(find.text('暂无趋势数据'), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('shows loading indicator before history resolves', (t) async {
      setDesktop(t);
      final repo = _MockRepo();
      registerFallbackValue(const LoadListRequested());
      _stubDetail(repo, goal);
      final app = _harness(repo: repo, goal: goal);
      // 重 stub getProgressHistory 永不 resolve → 停留 loading 态。
      final completer =
          Completer<dartz.Either<Failure, List<GoalProgressPoint>>>();
      when(() => repo.getProgressHistory(
              goalId: any(named: 'goalId'),
              from: any(named: 'from'),
              to: any(named: 'to')))
          .thenAnswer((_) => completer.future);

      await t.pumpWidget(app);
      await t.pump(); // 不 settle(等 history future)。

      // 趋势区 loading:goal detail loaded 后历史 FutureBuilder 仍 pending。
      // (bloc getGoal 已 Right 同步 → goal 主体渲染;history 还在 pending。)
      // 至少有一个 CircularProgressIndicator(可能 detail loading 或 trend loading)。
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      completer.complete(const dartz.Right(<GoalProgressPoint>[]));
      await t.pumpAndSettle();
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
      // detail page initState 经 GetIt 拉 GoalRepository(GoRouter harness 未
      // 走 _harness → 手动注册 + stub 空 history)。
      _registerGoalRepo(repo);

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
      // detail page initState 经 GetIt 拉 GoalRepository(GoRouter harness 未
      // 走 _harness → 手动注册 + stub 空 history)。
      _registerGoalRepo(repo);

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
