// Task 8 — widget tests for BudgetListPage(月份切换 + 卡片 + 进度 + 新建入口)。
//
// 驱动真实 BudgetBloc(mocktail BudgetRepository),注入 BudgetListLoaded。
// 验证(对齐 brief):
//   - AppBar:标题"预算" + 新建 action(lucide plus)
//   - 月份切换器:默认当月 + 上/下月按钮
//   - 预算卡:Name + Month + UsagePct% + 进度条
//   - 超支预算:UsagePct% + 剩余 显红色(#c0392b)
//   - 卡片 tap → push '/budgets/:id'(GoRouter harness)
//   - 新建 tap → push '/budgets/new'(GoRouter harness)
//   - 空态:暂无预算 提示
//   - 错误态 + 重试按钮
import 'dart:async';

import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/budget/domain/entities/budget_entity.dart';
import 'package:yucai_client/budget/domain/repositories/budget_repository.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_bloc.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_event.dart';
import 'package:yucai_client/budget/presentation/pages/budget_list_page.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/theme/app_design.dart';

class _MockRepo extends Mock implements BudgetRepository {}

BudgetView _budget({
  required String id,
  required String name,
  required String month,
  required int totalAmountCents,
  required int totalActualCents,
  required double usagePct,
  String currencyCode = 'CNY',
}) =>
    BudgetView(
      id: id,
      name: name,
      month: month,
      currencyCode: currencyCode,
      totalAmountCents: totalAmountCents,
      totalActualCents: totalActualCents,
      usagePct: usagePct,
    );

String _currentMonth() {
  final t = DateTime.now();
  return '${t.year}-${t.month.toString().padLeft(2, '0')}';
}

/// plain MaterialApp harness(无 GoRouter;用于非导航断言)。
Widget _harness(List<BudgetView> budgets) {
  final repo = _MockRepo();
  registerFallbackValue(const LoadListRequested());
  when(() => repo.listBudgets(activeOnly: any(named: 'activeOnly')))
      .thenAnswer((_) async => dartz.Right(budgets));
  return MaterialApp(
    home: BlocProvider<BudgetBloc>(
      create: (_) => BudgetBloc(repo),
      child: const BudgetListPage(),
    ),
  );
}

void main() {
  const desktop = Size(1400, 900);

  final month = _currentMonth();
  final budgets = [
    _budget(
      id: 'b1',
      name: '日常开销',
      month: month,
      totalAmountCents: 1000000, // ¥10,000.00
      totalActualCents: 250000, // ¥2,500.00 → 25%
      usagePct: 25.0,
    ),
    _budget(
      id: 'b2',
      name: '娱乐消费',
      month: month,
      totalAmountCents: 500000, // ¥5,000.00
      totalActualCents: 600000, // ¥6,000.00 → 120% 超支
      usagePct: 120.0,
    ),
  ];

  void setDesktop(WidgetTester t) {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
  }

  testWidgets('AppBar: title 预算 + new action (lucide plus)', (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(budgets));
    await t.pumpAndSettle();
    expect(find.text('预算'), findsOneWidget);
    // 新建 action tooltip。
    expect(find.byTooltip('新建'), findsOneWidget);
  });

  testWidgets('renders budget cards: name + month + usage pct', (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(budgets));
    await t.pumpAndSettle();
    expect(find.text('日常开销'), findsOneWidget);
    expect(find.text('娱乐消费'), findsOneWidget);
    // month 出现在月份切换器 + 每张卡的 meta。
    expect(find.text(month), findsWidgets);
    // UsagePct%:25.0% + 120.0%。
    expect(find.text('25.0%'), findsOneWidget);
    expect(find.text('120.0%'), findsOneWidget);
    // 进度条(2 张卡 → 2 根 LinearProgressIndicator)。
    expect(find.byKey(const ValueKey('budgetProgressBar')), findsNWidgets(2));
    // 实际/总额 meta(每张卡 1 个"实际")。
    expect(find.textContaining('实际'), findsNWidgets(2));
  });

  testWidgets('over-budget card: red progress bar (#c0392b)', (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(budgets));
    await t.pumpAndSettle();
    // 找到所有进度条,断言超支卡(b2)那根是红色 #c0392b。
    // 卡片顺序 = budgets 顺序(b2 第二张);用 widget 列表按布局顺序取。
    final bars = t
        .widgetList<LinearProgressIndicator>(
            find.byKey(const ValueKey('budgetProgressBar')))
        .toList();
    expect(bars.length, 2);
    final overColor =
        (bars[1].valueColor as AlwaysStoppedAnimation<Color>).value;
    expect(overColor, const Color(0xFFC0392B));
    // 正常卡(b1)是御财金 accent。
    final normalColor =
        (bars[0].valueColor as AlwaysStoppedAnimation<Color>).value;
    expect(normalColor, AppColors.accent);
    // 超支卡的"超支"meta 文案存在。
    expect(find.textContaining('超支'), findsOneWidget);
  });

  testWidgets('month switcher: prev/next buttons present', (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(budgets));
    await t.pumpAndSettle();
    expect(find.byTooltip('上月'), findsOneWidget);
    expect(find.byTooltip('下月'), findsOneWidget);
    // 默认当月显示在切换器中。
    expect(find.text(month), findsWidgets);
  });

  testWidgets('month filter: non-current-month budgets → empty state',
      (t) async {
    setDesktop(t);
    // 预算月份固定为 2025-12,与当月不一致 → 默认选中当月时 filter 后空态。
    final otherMonthBudgets = [
      _budget(
        id: 'b3',
        name: '上月预算',
        month: '2025-12',
        totalAmountCents: 800000,
        totalActualCents: 400000,
        usagePct: 50.0,
      ),
    ];
    await t.pumpWidget(_harness(otherMonthBudgets));
    await t.pumpAndSettle();
    expect(find.textContaining('暂无预算'), findsOneWidget);
    expect(find.text('上月预算'), findsNothing);
  });

  testWidgets('empty state when no budgets', (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(const []));
    await t.pumpAndSettle();
    expect(find.textContaining('暂无预算'), findsOneWidget);
  });

  testWidgets('loading state shows CircularProgressIndicator', (t) async {
    setDesktop(t);
    final repo = _MockRepo();
    registerFallbackValue(const LoadListRequested());
    // listBudgets 永不返回(用永不完成的 Completer,避免 Future.delayed 泄漏 Timer)。
    final completer = Completer<dartz.Either<Failure, List<BudgetView>>>();
    when(() => repo.listBudgets(activeOnly: any(named: 'activeOnly')))
        .thenAnswer((_) => completer.future);
    await t.pumpWidget(MaterialApp(
      home: BlocProvider<BudgetBloc>(
        create: (_) => BudgetBloc(repo),
        child: const BudgetListPage(),
      ),
    ));
    await t.pump(); // 触发 build + dispatch(不 settle,保持 loading)
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error state shows message + retry button', (t) async {
    setDesktop(t);
    final repo = _MockRepo();
    registerFallbackValue(const LoadListRequested());
    when(() => repo.listBudgets(activeOnly: any(named: 'activeOnly')))
        .thenAnswer((_) async =>
            const dartz.Left<Failure, List<BudgetView>>(
                ServerFailure('读取失败')));
    await t.pumpWidget(MaterialApp(
      home: BlocProvider<BudgetBloc>(
        create: (_) => BudgetBloc(repo),
        child: const BudgetListPage(),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.text('加载失败'), findsOneWidget);
    expect(find.textContaining('读取失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('card tap pushes /budgets/:id', (t) async {
    setDesktop(t);
    final repo = _MockRepo();
    registerFallbackValue(const LoadListRequested());
    when(() => repo.listBudgets(activeOnly: any(named: 'activeOnly')))
        .thenAnswer((_) async => dartz.Right(budgets));

    String? pushed;
    final router = GoRouter(
      initialLocation: '/budgets',
      routes: [
        GoRoute(
          path: '/budgets',
          builder: (_, __) => BlocProvider<BudgetBloc>(
            create: (_) => BudgetBloc(repo),
            child: const BudgetListPage(),
          ),
        ),
        GoRoute(
          path: '/budgets/new',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('NEW_STUB'))),
        ),
        GoRoute(
          path: '/budgets/:id',
          builder: (_, state) {
            pushed = state.pathParameters['id'];
            return Scaffold(body: Center(child: Text('DETAIL_${pushed ?? ''}')));
          },
        ),
      ],
    );

    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();

    // 点 b1 卡片(DataCard.onTap 包裹整张卡;tap Name 文本即可触发)。
    await t.tap(find.text('日常开销'));
    await t.pumpAndSettle();

    expect(pushed, 'b1');
    expect(find.text('DETAIL_b1'), findsOneWidget);
  });

  testWidgets('new action pushes /budgets/new', (t) async {
    setDesktop(t);
    final repo = _MockRepo();
    registerFallbackValue(const LoadListRequested());
    when(() => repo.listBudgets(activeOnly: any(named: 'activeOnly')))
        .thenAnswer((_) async => dartz.Right(budgets));

    final router = GoRouter(
      initialLocation: '/budgets',
      routes: [
        GoRoute(
          path: '/budgets',
          builder: (_, __) => BlocProvider<BudgetBloc>(
            create: (_) => BudgetBloc(repo),
            child: const BudgetListPage(),
          ),
        ),
        GoRoute(
          path: '/budgets/new',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('NEW_STUB'))),
        ),
        // :id 必须在 /new 之后(字面量优先匹配)。
        GoRoute(
          path: '/budgets/:id',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('ID_STUB'))),
        ),
      ],
    );

    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();

    await t.tap(find.byTooltip('新建'));
    await t.pumpAndSettle();

    expect(find.text('NEW_STUB'), findsOneWidget);
  });
}
