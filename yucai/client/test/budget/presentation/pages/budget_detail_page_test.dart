// Task 9 — widget tests for BudgetDetailPage(头部 + per-item + AppBar edit/delete)。
//
// 驱动真实 BudgetBloc(mocktail BudgetRepository),seed BudgetDetailLoaded。
// 验证(对齐 brief):
//   - 头部:Name + Month + 总进度环(UsagePct%)+ TotalActual/TotalAmount/Remaining。
//   - per-item 列表:每行 account 名 + Planned/Actual + 进度条 + 占比% + 超支标记。
//   - 2 items:一个 ~50% 正常(金),一个 ~120% 超支(红 + 超支 marker)。
//   - loading → CircularProgressIndicator;error → message。
//   - 编辑(lucide pencil)tap → push '/budgets/:id/edit'。
//   - 删除(lucide trash2)→ confirm dialog → 确认 → dispatch DeleteBudgetRequested +
//     pop 回列表。
//
// 复用 budget_list_page_test 的 harness 范式(plain MaterialApp + mock repo)。
// 与 holding_detail_page_test 不同:BudgetDetailPage 无 CurrencySettings 依赖
// (不做货币折算),故不需注册 fake CurrencySettings。
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
import 'package:yucai_client/budget/presentation/pages/budget_detail_page.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/theme/app_design.dart';

class _MockRepo extends Mock implements BudgetRepository {}

BudgetItemView _item({
  required String id,
  required String accountId,
  String? accountName,
  required int planned,
  required int actual,
}) =>
    BudgetItemView(
      id: id,
      accountId: accountId,
      accountName: accountName,
      plannedAmountCents: planned,
      actualAmountCents: actual,
    );

BudgetView _budget({
  required String id,
  required String name,
  required String month,
  required int totalAmount,
  required int totalActual,
  required double usagePct,
  List<BudgetItemView> items = const [],
  String currency = 'CNY',
}) =>
    BudgetView(
      id: id,
      name: name,
      month: month,
      currencyCode: currency,
      totalAmountCents: totalAmount,
      totalActualCents: totalActual,
      usagePct: usagePct,
      items: items,
    );

/// harness:注入 BudgetBloc(mock repo)。getBudget([id]) 固定返回 [budget];
/// deleteBudget 由测试内 stub 控制(默认 Right(void))。
Widget _harness({
  required _MockRepo repo,
  required BudgetView budget,
}) {
  return MaterialApp(
    home: BlocProvider<BudgetBloc>(
      create: (_) => BudgetBloc(repo),
      child: BudgetDetailPage(id: budget.id),
    ),
  );
}

void _stubDetail(_MockRepo repo, BudgetView budget) {
  when(() => repo.getBudget(any())).thenAnswer((_) async => dartz.Right(budget));
}

void main() {
  const desktop = Size(1400, 900);

  // 2 items:一个 ~50% 正常,一个 ~120% 超支(brief 指定)。
  final items = [
    _item(
      id: 'i1',
      accountId: 'a1',
      accountName: '餐饮',
      planned: 200000, // ¥2,000.00
      actual: 100000, // ¥1,000.00 → 50%
    ),
    _item(
      id: 'i2',
      accountId: 'a2',
      // accountName null → 占位 '分类账户'(brief Step 2 MVP)。
      planned: 100000, // ¥1,000.00
      actual: 120000, // ¥1,200.00 → 120% 超支
    ),
  ];
  final budget = _budget(
    id: 'b1',
    name: '日常开销',
    month: '2026-07',
    totalAmount: 300000, // ¥3,000.00
    totalActual: 220000, // ¥2,200.00 → ~73.3%
    usagePct: 73.3,
    items: items,
  );

  void setDesktop(WidgetTester t) {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets('renders header: name + month + ring + actual/total/remaining',
      (t) async {
    setDesktop(t);
    final repo = _MockRepo();
    registerFallbackValue(const LoadListRequested());
    _stubDetail(repo, budget);

    await t.pumpWidget(_harness(repo: repo, budget: budget));
    await t.pumpAndSettle();

    // Name + Month。
    expect(find.text('日常开销'), findsOneWidget);
    expect(find.byKey(const ValueKey('budgetDetailMonth')), findsOneWidget);
    expect(find.text('2026-07'), findsOneWidget);
    // 总进度环 + UsagePct%。
    expect(find.byKey(const ValueKey('budgetDetailRing')), findsOneWidget);
    expect(find.byKey(const ValueKey('budgetDetailRingBar')), findsOneWidget);
    expect(find.byKey(const ValueKey('budgetDetailUsagePct')), findsOneWidget);
    expect(find.text('73.3%'), findsOneWidget);
  });

  testWidgets('renders per-item rows: name + planned/actual + progress + pct',
      (t) async {
    setDesktop(t);
    final repo = _MockRepo();
    registerFallbackValue(const LoadListRequested());
    _stubDetail(repo, budget);

    await t.pumpWidget(_harness(repo: repo, budget: budget));
    await t.pumpAndSettle();

    // 2 item 行(LinearProgressIndicator 每行 1 根)。
    expect(find.byKey(const ValueKey('budgetDetailItemBar')), findsNWidgets(2));
    // account 名:i1 '餐饮'(accountName 填)+ i2 null → '分类账户' 占位。
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('分类账户'), findsOneWidget);
    // 占比%:50.0% + 120.0%。
    expect(find.text('50.0%'), findsOneWidget);
    expect(find.text('120.0%'), findsOneWidget);
    // 超支 marker(仅 i2 一项)。
    expect(find.byKey(const ValueKey('budgetDetailOverMarker')), findsOneWidget);
    expect(find.text('超支'), findsOneWidget);
  });

  testWidgets('over-budget item progress bar is red (#c0392b); normal is gold',
      (t) async {
    setDesktop(t);
    final repo = _MockRepo();
    registerFallbackValue(const LoadListRequested());
    _stubDetail(repo, budget);

    await t.pumpWidget(_harness(repo: repo, budget: budget));
    await t.pumpAndSettle();

    final bars = t
        .widgetList<LinearProgressIndicator>(
            find.byKey(const ValueKey('budgetDetailItemBar')))
        .toList();
    expect(bars.length, 2);
    // i1 正常(金)。
    final normalColor =
        (bars[0].valueColor as AlwaysStoppedAnimation<Color>).value;
    expect(normalColor, AppColors.accent);
    // i2 超支(#c0392b)。
    final overColor =
        (bars[1].valueColor as AlwaysStoppedAnimation<Color>).value;
    expect(overColor, const Color(0xFFC0392B));
  });

  testWidgets('loading state shows CircularProgressIndicator', (t) async {
    setDesktop(t);
    final repo = _MockRepo();
    registerFallbackValue(const LoadListRequested());
    // getBudget 永不完成 → 保持 BudgetLoading。
    final completer = Completer<dartz.Either<Failure, BudgetView>>();
    when(() => repo.getBudget(any())).thenAnswer((_) => completer.future);
    await t.pumpWidget(_harness(repo: repo, budget: budget));
    await t.pump(); // 触发 build + dispatch(不 settle)
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error state shows message', (t) async {
    setDesktop(t);
    final repo = _MockRepo();
    registerFallbackValue(const LoadListRequested());
    when(() => repo.getBudget(any())).thenAnswer(
        (_) async => const dartz.Left<Failure, BudgetView>(
            ServerFailure('读取失败')));
    await t.pumpWidget(_harness(repo: repo, budget: budget));
    await t.pumpAndSettle();
    expect(find.textContaining('读取失败'), findsOneWidget);
  });

  testWidgets('edit action pushes /budgets/:id/edit', (t) async {
    setDesktop(t);
    final repo = _MockRepo();
    registerFallbackValue(const LoadListRequested());
    _stubDetail(repo, budget);

    String? pushed;
    final router = GoRouter(
      initialLocation: '/budgets/${budget.id}',
      routes: [
        GoRoute(
          path: '/budgets/:id',
          builder: (_, state) => BlocProvider<BudgetBloc>(
            create: (_) => BudgetBloc(repo),
            child: BudgetDetailPage(id: state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/budgets/:id/edit',
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

    expect(pushed, budget.id);
    expect(find.text('EDIT_STUB'), findsOneWidget);
  });

  testWidgets('delete action: confirm dialog → dispatch DeleteBudgetRequested',
      (t) async {
    setDesktop(t);
    final repo = _MockRepo();
    registerFallbackValue(const LoadListRequested());
    _stubDetail(repo, budget);
    // deleteBudget stub(返回 Right(void));bloc 删除后发 LoadListRequested,
    // 需 stub listBudgets 防 MissingDummyError。
    when(() => repo.deleteBudget(any()))
        .thenAnswer((_) async => const dartz.Right(null));
    when(() => repo.listBudgets(activeOnly: any(named: 'activeOnly')))
        .thenAnswer((_) async => const dartz.Right([]));

    // 用 GoRouter harness(非 plain MaterialApp):_confirmDelete 确认后
    // context.pop() 需 GoRouter 祖先 + 非空 pop 栈。先停在列表页,点「进入详情」
    // 把 detail route push 入栈(模拟真实导航:list → detail),这样删除后 pop 能回 list。
    final router = GoRouter(
      initialLocation: '/budgets',
      routes: [
        GoRoute(
          path: '/budgets',
          builder: (_, __) => BlocProvider<BudgetBloc>(
            create: (_) => BudgetBloc(repo),
            child: Scaffold(
              body: Center(
                child: Builder(
                  builder: (ctx) => ElevatedButton(
                    key: const ValueKey('goDetail'),
                    onPressed: () =>
                        ctx.push('/budgets/${budget.id}'),
                    child: const Text('进入详情'),
                  ),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/budgets/:id',
          builder: (_, state) => BlocProvider<BudgetBloc>(
            create: (_) => BudgetBloc(repo),
            child: BudgetDetailPage(id: state.pathParameters['id']!),
          ),
        ),
      ],
    );

    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
    // push detail route 入栈(模拟 list → detail 导航)。
    await t.tap(find.byKey(const ValueKey('goDetail')));
    await t.pumpAndSettle();

    // 点删除 → confirm dialog。
    await t.tap(find.byTooltip('删除'));
    await t.pumpAndSettle();

    // dialog 出现:标题 + 取消/删除 actions。
    expect(find.text('删除预算'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);

    // 确认删除:点 dialog 内「删除」TextButton → dispatch + pop 回列表。
    await t.tap(find.text('删除'));
    await t.pumpAndSettle();

    // 验证 dispatch:repo.deleteBudget 被调用 1 次。
    verify(() => repo.deleteBudget(budget.id)).called(1);
    // pop 回列表:列表 stub 文案可见。
    expect(find.text('进入详情'), findsOneWidget);
  });

  testWidgets('delete cancel does not dispatch', (t) async {
    setDesktop(t);
    final repo = _MockRepo();
    registerFallbackValue(const LoadListRequested());
    _stubDetail(repo, budget);

    await t.pumpWidget(_harness(repo: repo, budget: budget));
    await t.pumpAndSettle();

    await t.tap(find.byTooltip('删除'));
    await t.pumpAndSettle();

    // 取消 → 不调用 deleteBudget(取消不 pop,plain MaterialApp 即可)。
    await t.tap(find.text('取消'));
    await t.pumpAndSettle();

    verifyNever(() => repo.deleteBudget(any()));
  });
}
