// Task 12 — widget tests for GoalListPage(3 type 卡片 + 分组 + 进度环 + 倒计时)。
//
// 驱动真实 GoalBloc(mocktail GoalRepository),注入 GoalListLoaded。
// 验证(对齐 brief + OD 原型):
//   - AppBar:标题"目标" + 新建 action(lucide plus)
//   - 类型徽章:3 type 各自图标 + 文案(储蓄/债务清偿/投资)
//   - 进度环:CircularProgressIndicator value clamp[0,1] + 中心 pct%
//   - 倒计时:deadline 倒计时"剩 X 天" + 完成态"已达成"
//   - 分组:进行中 + 已完成 两 section header
//   - 卡片 tap → push '/goals/:id'(GoRouter harness)
//   - 新建 tap → push '/goals/new'(GoRouter harness)
//   - 空态:还没有目标 提示
//   - 错误态 + 重试按钮
import 'dart:async';

import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/widgets/conic_progress_ring.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/goal/domain/repositories/goal_repository.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_bloc.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_event.dart';
import 'package:yucai_client/goal/presentation/pages/goal_list_page.dart';

class _MockRepo extends Mock implements GoalRepository {}

GoalView _goal({
  required String id,
  required String name,
  required GoalType type,
  required int targetAmountCents,
  int currentAmountCents = 0,
  String currencyCode = 'CNY',
  DateTime? deadline,
  bool isCompleted = false,
  String? notes,
}) =>
    GoalView(
      id: id,
      name: name,
      type: type,
      targetAmountCents: targetAmountCents,
      currentAmountCents: currentAmountCents,
      currencyCode: currencyCode,
      deadline: deadline,
      isCompleted: isCompleted,
      notes: notes,
    );

/// 30 天后的 DateTime(用于 deadline 倒计时测试,避免今日边界波动)。
DateTime _inDays(int d) =>
    DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
        .add(Duration(days: d));

/// plain MaterialApp harness(无 GoRouter;用于非导航断言)。
Widget _harness(List<GoalView> goals) {
  final repo = _MockRepo();
  registerFallbackValue(const LoadListRequested());
  when(() => repo.listGoals(type: any(named: 'type'), completed: any(named: 'completed')))
      .thenAnswer((_) async => dartz.Right(goals));
  return MaterialApp(
    home: BlocProvider<GoalBloc>(
      create: (_) => GoalBloc(repo),
      child: const GoalListPage(),
    ),
  );
}

void main() {
  const desktop = Size(1400, 900);

  final goals = [
    // 进行中 · savings · 25%。
    _goal(
      id: 'g1',
      name: '应急基金',
      type: GoalType.savings,
      targetAmountCents: 6000000, // ¥60,000.00
      currentAmountCents: 1500000, // ¥15,000.00 → 25%
      deadline: _inDays(45),
    ),
    // 进行中 · debtPayoff · 50%。
    _goal(
      id: 'g2',
      name: '还清信用卡',
      type: GoalType.debtPayoff,
      targetAmountCents: 2000000,
      currentAmountCents: 1000000, // 50%
      deadline: _inDays(200),
    ),
    // 进行中 · investment · 80%。
    _goal(
      id: 'g3',
      name: '美股养老金',
      type: GoalType.investment,
      targetAmountCents: 10000000,
      currentAmountCents: 8000000, // 80%
      deadline: _inDays(500), // >365 → 月份文案
    ),
    // 已完成 · savings。
    _goal(
      id: 'g4',
      name: '买车基金',
      type: GoalType.savings,
      targetAmountCents: 3000000,
      currentAmountCents: 3000000, // 100%
      isCompleted: true,
      deadline: _inDays(-10),
    ),
  ];

  void setDesktop(WidgetTester t) {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
  }

  testWidgets('AppBar: title 目标 + new action (lucide plus)', (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(goals));
    await t.pumpAndSettle();
    expect(find.text('目标'), findsOneWidget);
    // 「新建目标」入口移至全局 _TopBar(app_shell 路由感知);page 单测不验。
  });

  testWidgets('renders 3 type chips with correct labels', (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(goals));
    await t.pumpAndSettle();
    expect(find.text('储蓄目标'), findsWidgets); // g1 + g4 卡片徽章
    // 债务清偿 / 投资目标 出现在「类型筛选 chip」+「卡片类型徽章」至少 1 处。
    expect(find.text('债务清偿'), findsNWidgets(2)); // 筛选 chip + g2 徽章
    expect(find.text('投资目标'), findsOneWidget); // g3 徽章(筛选 chip 是「投资」)
  });

  testWidgets('renders goal names + current/target amounts', (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(goals));
    await t.pumpAndSettle();
    expect(find.text('应急基金'), findsOneWidget);
    expect(find.text('还清信用卡'), findsOneWidget);
    expect(find.text('美股养老金'), findsOneWidget);
    expect(find.text('买车基金'), findsOneWidget);
    // 目标金额文案(每张卡 1 个"目标 ¥…",精确文本避免与 AppBar 标题/chip 冲突)。
    expect(find.text('目标 ¥60,000.00'), findsOneWidget);
    expect(find.text('目标 ¥20,000.00'), findsOneWidget);
    expect(find.text('目标 ¥100,000.00'), findsOneWidget);
    expect(find.text('目标 ¥30,000.00'), findsOneWidget);
  });

  testWidgets('progress ring: ConicProgressRing progress clamps pct', (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(goals));
    await t.pumpAndSettle();
    final rings = t
        .widgetList<ConicProgressRing>(find.byKey(const ValueKey('goalRing')))
        .toList();
    expect(rings.length, 4);
    // g1 25% → 0.25;g2 50% → 0.5;g3 80% → 0.8;g4 100% → 1.0。
    expect((rings[0].progress * 100).round(), 25);
    expect((rings[1].progress * 100).round(), 50);
    expect((rings[2].progress * 100).round(), 80);
    expect((rings[3].progress * 100).round(), 100);
    // 中心 pct label。
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('completed card ring is positive green', (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(goals));
    await t.pumpAndSettle();
    final rings = t
        .widgetList<ConicProgressRing>(find.byKey(const ValueKey('goalRing')))
        .toList();
    // g4(已完成)是第 4 张卡(已完成分组),颜色应为 AppColors.positive。
    expect(rings[3].color, const Color(0xFF2D8A6E)); // AppColors.positive
  });

  testWidgets('deadline countdown: days / months / 已达成', (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(goals));
    await t.pumpAndSettle();
    // g1 剩 45 天。g2 剩 200 天。g3 >365 → 月份。g4 完成 → 已达成。
    expect(find.textContaining('剩 45 天'), findsOneWidget);
    expect(find.textContaining('剩 200 天'), findsOneWidget);
    expect(find.textContaining('个月'), findsOneWidget);
    expect(find.text('已达成'), findsOneWidget);
  });

  testWidgets('groups: 进行中 + 已完成 headers with counts', (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(goals));
    await t.pumpAndSettle();
    expect(find.text('进行中'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    // 计数 badge(分组头紧随标题/图标的 count pill):进行中 3 / 已完成 1。
    // 用 ancestor 匹配分组头行内的 count,避免与类型筛选 chip 计数冲突。
    final doingHeader = find.ancestor(
        of: find.text('进行中'), matching: find.byType(Row));
    expect(
      find.descendant(of: doingHeader, matching: find.text('3')),
      findsOneWidget,
    );
    final doneHeader = find.ancestor(
        of: find.text('已完成'), matching: find.byType(Row));
    expect(
      find.descendant(of: doneHeader, matching: find.text('1')),
      findsOneWidget,
    );
  });

  testWidgets('type filter chips: all/savings/debt/investment with counts',
      (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(goals));
    await t.pumpAndSettle();
    // 4 chips:全部(4)/ 储蓄(2)/ 债务清偿(1)/ 投资(1)。
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('储蓄'), findsOneWidget);
    expect(find.text('债务清偿'), findsNWidgets(2)); // chip + 类型徽章
    expect(find.text('投资'), findsOneWidget);
  });

  testWidgets('type filter chips filter the list', (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(goals));
    await t.pumpAndSettle();
    // 初始:4 张卡。
    expect(find.byKey(const ValueKey('goalRing')), findsNWidgets(4));
    // 点「投资」chip → 只剩 g3。
    await t.tap(find.text('投资'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('goalRing')), findsOneWidget);
    expect(find.text('美股养老金'), findsOneWidget);
  });

  testWidgets('empty state when no goals', (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(const []));
    await t.pumpAndSettle();
    expect(find.text('还没有目标'), findsOneWidget);
    // 不应渲染分组头。
    expect(find.text('进行中'), findsNothing);
    expect(find.text('已完成'), findsNothing);
  });

  testWidgets('loading state shows CircularProgressIndicator', (t) async {
    setDesktop(t);
    final repo = _MockRepo();
    registerFallbackValue(const LoadListRequested());
    // listGoals 永不返回(用永不完成的 Completer,避免 Future.delayed 泄漏 Timer)。
    final completer = Completer<dartz.Either<Failure, List<GoalView>>>();
    when(() => repo.listGoals(
            type: any(named: 'type'), completed: any(named: 'completed')))
        .thenAnswer((_) => completer.future);
    await t.pumpWidget(MaterialApp(
      home: BlocProvider<GoalBloc>(
        create: (_) => GoalBloc(repo),
        child: const GoalListPage(),
      ),
    ));
    await t.pump(); // 触发 build + dispatch(不 settle,保持 loading)
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error state shows message + retry button', (t) async {
    setDesktop(t);
    final repo = _MockRepo();
    registerFallbackValue(const LoadListRequested());
    when(() => repo.listGoals(
            type: any(named: 'type'), completed: any(named: 'completed')))
        .thenAnswer((_) async =>
            const dartz.Left<Failure, List<GoalView>>(ServerFailure('读取失败')));
    await t.pumpWidget(MaterialApp(
      home: BlocProvider<GoalBloc>(
        create: (_) => GoalBloc(repo),
        child: const GoalListPage(),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.text('加载失败'), findsOneWidget);
    expect(find.textContaining('读取失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('card tap pushes /goals/:id', (t) async {
    setDesktop(t);
    final repo = _MockRepo();
    registerFallbackValue(const LoadListRequested());
    when(() => repo.listGoals(
            type: any(named: 'type'), completed: any(named: 'completed')))
        .thenAnswer((_) async => dartz.Right(goals));

    String? pushed;
    final router = GoRouter(
      initialLocation: '/goals',
      routes: [
        GoRoute(
          path: '/goals',
          builder: (_, __) => BlocProvider<GoalBloc>(
            create: (_) => GoalBloc(repo),
            child: const GoalListPage(),
          ),
        ),
        GoRoute(
          path: '/goals/new',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('NEW_STUB'))),
        ),
        GoRoute(
          path: '/goals/:id',
          builder: (_, state) {
            pushed = state.pathParameters['id'];
            return Scaffold(body: Center(child: Text('DETAIL_${pushed ?? ''}')));
          },
        ),
      ],
    );

    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();

    // 点 g1 卡片(DataCard.onTap 包裹整张卡;tap Name 文本即可触发)。
    await t.tap(find.text('应急基金'));
    await t.pumpAndSettle();

    expect(pushed, 'g1');
    expect(find.text('DETAIL_g1'), findsOneWidget);
  });

  // 「新建目标」入口移至全局 _TopBar(app_shell 路由感知创建按钮 /goals/new);
  // page 单测无法验证 topbar 创建导航(需 app_shell/router test)。
}
