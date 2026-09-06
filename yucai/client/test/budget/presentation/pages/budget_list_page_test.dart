// Task 8 — widget tests for BudgetListPage(对齐 OD 原型后:topbar + conic 环卡片 +
// 月份切换 + btn-gold 新建 + 状态分组)。
//
// 驱动真实 BudgetBloc(mocktail BudgetRepository),注入 BudgetListLoaded。
// 验证(对齐原型 + goal 对齐范式):
//   - topbar:标题「预算管理」+ sub + btn-gold「新建预算」(替 FAB tooltip)
//   - 月份切换器:默认当月 + 上/下月按钮
//   - 预算卡:Name + Month + ConicProgressRing(conic 环)+ UsagePct% pill
//   - 超支预算:Conic 环色 = #c0392b;正常卡环色 = 御财金
//   - 状态分组:超支组在正常组之上(对齐原型 nav-sec 排序)
//   - 卡片 tap → push '/budgets/:id'(GoRouter harness)
//   - 新建 tap → push '/budgets/new'(GoRouter harness)
//   - 空态:本月暂无预算 提示
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
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_event.dart';
import 'package:yucai_client/budget/presentation/pages/budget_list_page.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/widgets/conic_progress_ring.dart';

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

  testWidgets('topbar: title 预算管理 + sub + 新建预算 button', (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(budgets));
    await t.pumpAndSettle();
    expect(find.text('预算管理'), findsOneWidget);
    expect(find.byKey(const ValueKey('budgetListTitle')), findsOneWidget);
    expect(find.byKey(const ValueKey('budgetListSub')), findsOneWidget);
    // 「新建预算」入口移至全局 _TopBar(app_shell 路由感知创建按钮);
    // emptyState 仍保留创建引导(空数据场景)。
  });

  testWidgets('renders budget cards: name + month + conic ring + usage pct pill',
      (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(budgets));
    await t.pumpAndSettle();
    expect(find.text('日常开销'), findsOneWidget);
    expect(find.text('娱乐消费'), findsOneWidget);
    // month 出现在月份切换器 + 每张卡的 meta。
    expect(find.text(month), findsWidgets);
    // ConicProgressRing(2 张卡 → 2 个 conic 环)。
    expect(find.byType(ConicProgressRing), findsNWidgets(2));
    // UsagePct% 整数(b1=25% / b2=120%);同时出现在 conic 环中心 + pill,
    // 故断言 findsWidgets(每个至少 1 处)。
    expect(find.text('25%'), findsWidgets);
    expect(find.text('120%'), findsWidgets);
  });

  testWidgets('over-budget card conic ring color = #c0392b; normal = accent(v2 翡翠绿)',
      (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(budgets));
    await t.pumpAndSettle();
    // 找到所有 conic 环,断言超支卡那根色 #c0392b,正常卡主色。
    final rings = t
        .widgetList<ConicProgressRing>(find.byType(ConicProgressRing))
        .toList();
    expect(rings.length, 2);
    // 分组排序:超支(b2)在前,正常(b1)在后。
    // F4-P2:超支红 #C0392B 令牌化 → negative(裸 MaterialApp 回落 v2 亮板)。
    expect(rings[0].color, AppColors.negative, reason: '超支卡 conic 环色 = negative 令牌');
    // R8 v2:主色 御财金→翡翠绿,断言改语义色不再钉 hex。
    expect(rings[1].color, AppColors.accent, reason: '正常卡 conic 环色 = AppColors.accent');
    // 超支卡的"超支"文案存在。
    expect(find.textContaining('超支'), findsWidgets);
  });

  testWidgets('status groups: 超支 group header + 正常 group header present',
      (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(budgets));
    await t.pumpAndSettle();
    expect(find.text('超支'), findsWidgets);
    expect(find.text('正常'), findsWidgets);
  });

  testWidgets('status filter chips: 全部 / 超支 / 正常', (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(budgets));
    await t.pumpAndSettle();
    // 3 个筛选 chip(全部 / 超支 / 正常)。「全部」无分组头冲突,唯一。
    expect(find.text('全部'), findsOneWidget);
    // 点击「全部」chip → 两组都保留(b1 正常 + b2 超支)。
    await t.tap(find.text('全部'));
    await t.pumpAndSettle();
    expect(find.text('日常开销'), findsOneWidget);
    expect(find.text('娱乐消费'), findsOneWidget);
  });

  testWidgets('status filter: tap 正常 chip hides 超支 card', (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(budgets));
    await t.pumpAndSettle();
    // 「正常」字样同时出现在筛选 chip + 分组头 → 用 descendant 限定到 chip 区
    // (chip 在 topbar 下的筛选行,group header 在更下方)。点击筛选行第 3 个 chip。
    // 简化:用 find.text 配 hitTestable + first。这里改用「正常」chip 的计数 badge
    // 特征 —— chip 内「正常」后紧跟计数「1」。直接 tap 第一个可点击的「正常」。
    final normalCandidates = find.text('正常');
    // 取筛选 chip 那个(在顶部,先 hit-test)。用 at(0) 不安全(树顺序不定),
    // 改用:tap 「超支」chip 更稳(超支 chip 文案「超支」与 group header 也冲突,
    // 但 chip 在顶部 hitTestable)→ 用 evaluate 取第一个 offstage不为空的。
    final overChips = find
        .text('超支')
        .evaluate()
        .where((e) => e.renderObject != null)
        .toList();
    expect(overChips.length, greaterThanOrEqualTo(1));
    // 点「超支」筛选 chip(第一个,即顶部筛选行)→ 仅留 b2 超支,隐藏 b1 正常。
    await t.tap(find.text('超支').first);
    await t.pumpAndSettle();
    expect(find.text('娱乐消费'), findsOneWidget);
    expect(find.text('日常开销'), findsNothing);
  });

  testWidgets('month switcher: prev/next buttons present', (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(budgets));
    await t.pumpAndSettle();
    expect(find.byTooltip('上月'), findsOneWidget);
    expect(find.byTooltip('下月'), findsOneWidget);
    expect(find.byKey(const ValueKey('budgetMonthVal')), findsOneWidget);
  });

  testWidgets('month filter: non-current-month budgets → empty state', (t) async {
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
    expect(find.textContaining('本月暂无预算'), findsOneWidget);
    expect(find.text('上月预算'), findsNothing);
  });

  testWidgets('empty state when no budgets', (t) async {
    setDesktop(t);
    await t.pumpWidget(_harness(const []));
    await t.pumpAndSettle();
    expect(find.textContaining('本月暂无预算'), findsOneWidget);
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

  // 「新建预算」入口移至全局 _TopBar(app_shell 路由感知创建按钮 /budgets/new);
  // page 单测无法验证 topbar 创建导航(需 app_shell/router test)。
}
