// Task 7 — TDD widget tests for ReceivablesPage (债权列表 + 三端响应式 + progress)。
//
// _OverviewCard + _ReceivableCard 私有,故测试通过公开 ReceivablesPage 驱动:
// 用 mocktail 的 DebtRepository 构造真实 DebtBloc,注入 DebtsLoaded 状态。
// 验证(BorrowedOut 语义 = 应收 / 收款,非 负债 / 还款):
//   - 总应收概览:总应收 / 剩余应收 / 本金收回进度 progress bar
//   - 债权卡:债务人 counterparty / 类型 badge / 剩余应收 / 收回进度 progress / 利率 / 到期
//   - 列表无「收款」按钮(收款在详情页 schedule 行内处理)
//   - 三端 viewport:mobile 单列 Column / tablet 2 列 / desktop ≥3 列 GridView
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/debt/presentation/pages/receivables_page.dart';

class _MockRepo extends Mock implements DebtRepository {}

/// Fake CurrencyBloc(与 debts_page_test 同模式)。
class _FakeCurrencyBloc extends Fake implements CurrencyBloc {
  _FakeCurrencyBloc(this._state);
  final CurrencyState _state;
  @override
  CurrencyState get state => _state;
  @override
  Stream<CurrencyState> get stream => Stream.value(_state);
}

Debt _debt({
  required String id,
  required String counterparty,
  required double interestRate,
  required AmortizationMethod amortization,
  required DateTime dueDate,
  required int totalPrincipalCents,
  required int remainingPrincipalCents,
}) =>
    Debt(
      id: id,
      accountId: 'a-$id',
      counterparty: counterparty,
      interestRate: interestRate,
      amortization: amortization,
      startDate: DateTime(2026, 1, 1),
      dueDate: dueDate,
      totalPrincipalCents: totalPrincipalCents,
      remainingPrincipalCents: remainingPrincipalCents,
      version: 1,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Widget _harness(List<Debt> debts) {
  final repo = _MockRepo();
  registerFallbackValue(const CreateDebtParams(
    accountId: '',
    counterparty: '',
    interestRate: 0,
    amortizationIndex: 0,
    startDateOption: null,
    dueDateOption: null,
    totalPrincipalCents: 0,
  ));
  // mock 对任意 typeFilter 返回 debts(页面会带 borrowedOut 过滤拉取)。
  when(() => repo.list(typeFilter: any(named: 'typeFilter')))
      .thenAnswer((_) async => dartz.Right(debts));
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<DebtBloc>(create: (_) => DebtBloc(repo)),
        BlocProvider<CurrencyBloc>.value(
          value: _FakeCurrencyBloc(const CurrencyState())),
      ],
      child: const ReceivablesPage(),
    ),
  );
}

void main() {
  // desktop 宽视口,确保完整布局(概览 + 卡片)。
  const desktop = Size(1400, 900);
  const tablet = Size(900, 1200);
  const mobile = Size(390, 844);

  final receivables = [
    _debt(
      id: 'r1',
      counterparty: '张三',
      interestRate: 0.00,
      amortization: AmortizationMethod.equalPrincipal,
      dueDate: DateTime(2026, 8, 15),
      totalPrincipalCents: 5000000, // 5 万
      remainingPrincipalCents: 3000000, // 剩 3 万 → 已收 40%
    ),
    _debt(
      id: 'r2',
      counterparty: '李四',
      interestRate: 8.00,
      amortization: AmortizationMethod.equalPrincipalInterest,
      dueDate: DateTime(2027, 2, 15),
      totalPrincipalCents: 10000000,
      remainingPrincipalCents: 7574200,
    ),
  ];

  testWidgets('overview: 总应收 + 剩余应收 + 本金收回进度 progress bar',
      (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness(receivables));
    await t.pumpAndSettle();
    // 概览标签:应收语义(非 负债/还款)
    expect(find.textContaining('总应收'), findsWidgets);
    expect(find.textContaining('剩余应收'), findsWidgets);
    expect(find.textContaining('本金收回进度'), findsWidgets);
    // 概览的 LinearProgressIndicator 存在。
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    // 总应收 = sum(total) = 500 万 + 1000 万 = ¥150,000.00
    expect(find.textContaining('¥150,000.00'), findsWidgets);
    // 误用「负债/总负债」不应出现 —— 语义互斥校验。
    expect(find.text('总负债'), findsNothing);
    expect(find.textContaining('剩余本金'), findsNothing);
  });

  testWidgets('overview: 收回进度 ratio = totalCollected/totalPrincipal',
      (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness(receivables));
    await t.pumpAndSettle();
    // r1: 已收 2000000;r2: 已收 2425800;sum=4425800
    // total sum=15000000 → 4425800/15000000 = 0.29505... → 29.5%
    expect(find.textContaining('29.5%'), findsWidgets);
  });

  testWidgets('receivable card: 债务人 + 剩余应收 + 利率 + 到期', (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness(receivables));
    await t.pumpAndSettle();
    expect(find.text('张三'), findsOneWidget);
    expect(find.text('李四'), findsOneWidget);
    // 剩余应收(r1 = ¥30,000.00)
    expect(find.textContaining('¥30,000.00'), findsOneWidget);
    expect(find.textContaining('剩余应收'), findsWidgets);
    // 利率
    expect(find.textContaining('0.00%'), findsOneWidget);
    expect(find.textContaining('8.00%'), findsOneWidget);
    // 到期(yyyy-MM-dd)。r1 的 2026-08-15 同时是 overview「下次收款」(最早到期)
    // 与 r1 卡「到期」→ 出现 2 次;r2 的 2027-02-15 仅在 r2 卡 → 1 次。
    expect(find.textContaining('2026-08-15'), findsNWidgets(2));
    expect(find.textContaining('2027-02-15'), findsOneWidget);
    // 下次收款 = min(dueDate) = 2026-08-15(r1 最早到期)—— 概览行
    expect(find.textContaining('下次收款'), findsWidgets);
  });

  testWidgets('receivable card: 收回进度 progress bar 用金色 accent',
      (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([receivables.first]));
    await t.pumpAndSettle();
    // r1 卡片进度 = 0.4
    final bars = t.widgetList<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator));
    final cardBar = bars.firstWhere(
      (b) => (b.value ?? 0) > 0.39 && (b.value ?? 0) < 0.41,
    );
    expect((cardBar.valueColor as AlwaysStoppedAnimation<Color?>?)?.value,
        AppColors.accent);
  });

  testWidgets('receivable card: 列表无「收款」按钮(收款在详情页处理)', (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness(receivables));
    await t.pumpAndSettle();
    // 收款按钮已从列表移除(详情页 schedule 行内确认收款)。
    expect(find.text('收款'), findsNothing);
    // 详情 / 更多 按钮仍在。
    expect(find.text('详情'), findsNWidgets(2));
    expect(find.text('更多'), findsNWidgets(2));
    // 误用「记账」不应出现。
    expect(find.text('记账'), findsNothing);
  });

  testWidgets('已结清: 默认「进行中」隐藏,切「全部」显示「已结清 ✓」badge', (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    final settled = _debt(
      id: 's1',
      counterparty: '赵六',
      interestRate: 0.00,
      amortization: AmortizationMethod.lumpSum,
      dueDate: DateTime(2025, 1, 1), // 过去(本会逾期)
      totalPrincipalCents: 5000000,
      remainingPrincipalCents: 0, // 已结清
    );
    await t.pumpWidget(_harness([settled]));
    await t.pumpAndSettle();
    // 默认「进行中」→ 已结清不在列表。
    expect(find.text('赵六'), findsNothing);
    // 切「全部」→ 已结清卡显示 + 精确 badge「已结清 ✓」(区别于 segmented「已结清 1」)。
    await t.tap(find.byKey(const ValueKey('listFilter-全部')));
    await t.pumpAndSettle();
    expect(find.text('赵六'), findsOneWidget);
    expect(find.text('已结清 ✓'), findsOneWidget);
    // 已结清优先,不显示逾期 badge。
    expect(find.text('逾期'), findsNothing);
  });

  testWidgets('筛选 segmented: 计数 + 切换(默认进行中隐藏已结清)', (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    final mixed = [
      ...receivables, // r1 张三 / r2 李四(进行中)
      _debt(
        id: 's1',
        counterparty: '赵六',
        interestRate: 0.00,
        amortization: AmortizationMethod.lumpSum,
        dueDate: DateTime(2025, 1, 1),
        totalPrincipalCents: 5000000,
        remainingPrincipalCents: 0, // 已结清
      ),
    ];
    await t.pumpWidget(_harness(mixed));
    await t.pumpAndSettle();
    // segmented 计数:全部 3 / 进行中 2 / 已结清 1。
    expect(find.text('全部 3'), findsOneWidget);
    expect(find.text('进行中 2'), findsOneWidget);
    expect(find.text('已结清 1'), findsOneWidget);
    // 默认进行中 → 赵六(已结清)不显示,张三/李四显示。
    expect(find.text('赵六'), findsNothing);
    expect(find.text('张三'), findsOneWidget);
    // 切「已结清」→ 只赵六,张三/李四排除。
    await t.tap(find.byKey(const ValueKey('listFilter-已结清')));
    await t.pumpAndSettle();
    expect(find.text('赵六'), findsOneWidget);
    expect(find.text('张三'), findsNothing);
  });

  testWidgets('mobile: single-column Column (no GridView)', (t) async {
    t.view.physicalSize = mobile;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness(receivables));
    await t.pumpAndSettle();
    expect(find.byType(GridView), findsNothing);
    expect(find.text('张三'), findsOneWidget);
    expect(find.text('李四'), findsOneWidget);
  });

  testWidgets('tablet: 2-column GridView', (t) async {
    t.view.physicalSize = tablet;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness(receivables));
    await t.pumpAndSettle();
    final grid = t.widget<GridView>(find.byType(GridView).first);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
  });

  testWidgets('desktop: GridView with >=3 columns', (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([
      ...receivables,
      _debt(
        id: 'r3',
        counterparty: '王五',
        interestRate: 0.00,
        amortization: AmortizationMethod.equalPrincipal,
        dueDate: DateTime(2026, 8, 15),
        totalPrincipalCents: 2000000,
        remainingPrincipalCents: 1000000,
      ),
    ]));
    await t.pumpAndSettle();
    final grid = t.widget<GridView>(find.byType(GridView).first);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, greaterThanOrEqualTo(3));
  });

  testWidgets('FAB present (创建债权)', (t) async {
    t.view.physicalSize = mobile;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness(receivables));
    await t.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('empty state when no receivables', (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness(const []));
    await t.pumpAndSettle();
    expect(find.textContaining('还没有债权'), findsOneWidget);
  });

  testWidgets('LoadDebtsRequested(typeFilter: borrowedOut) dispatched on init',
      (t) async {
    final repo = _MockRepo();
    registerFallbackValue(const CreateDebtParams(
      accountId: '',
      counterparty: '',
      interestRate: 0,
      amortizationIndex: 0,
      startDateOption: null,
      dueDateOption: null,
      totalPrincipalCents: 0,
    ));
    final calls = <DebtType?>[];
    when(() => repo.list(typeFilter: any(named: 'typeFilter')))
        .thenAnswer((inv) async {
      calls.add(inv.namedArguments[#typeFilter] as DebtType?);
      return const dartz.Right([]);
    });
    await t.pumpWidget(MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<DebtBloc>(create: (_) => DebtBloc(repo)),
          BlocProvider<CurrencyBloc>.value(
              value: _FakeCurrencyBloc(const CurrencyState())),
        ],
        child: const ReceivablesPage(),
      ),
    ));
    await t.pumpAndSettle();
    // 页面必须以 borrowedOut 过滤拉取(非 null / 非 borrowedIn)。
    expect(calls, isNotEmpty);
    expect(calls.last, DebtType.borrowedOut);
  });
}
