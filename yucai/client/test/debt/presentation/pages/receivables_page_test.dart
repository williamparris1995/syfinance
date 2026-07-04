// Task 9 — widget tests for ReceivablesPage(债权列表 OD 对齐 L1-L4)。
//
// _OverviewCard / _StatStrip / _ReceivableCard 私有,故测试通过公开 ReceivablesPage
// 驱动:用 mocktail DebtRepository 构造真实 DebtBloc + getIt 注册 mock
// ReceivablesSummaryRepository(返回固定 summary),注入 DebtsLoaded 状态。
// 验(L1-L4 OD 对齐):
//   - L1: avatar tile 渲染(债务人首字)
//   - L2: stat strip 4 卡(笔数 / 已收本息 / 待收利息 / 逾期应收)
//   - L3: 横向 row foot callout(下次收款 · 第 N 期 + 收款 CTA)
//   - L4: overview trend(较上月)+ 含待收利息 breakdown + 下次收款 callout
//   - L4: 筛选 4-seg(全部/进行中/已结清/逾期)
//   - 三端 viewport 仍:mobile 单列 Column / tablet 2 列 / desktop ≥3 列 GridView
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/entities/receivables_summary.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/repositories/receivables_summary_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/debt/presentation/pages/receivables_page.dart';

class _MockRepo extends Mock implements DebtRepository {}

class _MockSummaryRepo extends Mock implements ReceivablesSummaryRepository {}

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
  DateTime? nextPaymentDate,
  int nextPaymentAmountCents = 0,
  int nextPaymentPeriodNo = 0,
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
      nextPaymentDate: nextPaymentDate,
      nextPaymentAmountCents: nextPaymentAmountCents,
      nextPaymentPeriodNo: nextPaymentPeriodNo,
    );

ReceivablesSummary _summary({
  int totalPrincipalCents = 15000000,
  int totalRemainingCents = 10574200,
  int totalCollectedCents = 4425800,
  int pendingInterestCents = 320000,
  int count = 2,
  int overdueCount = 0,
  int overdueAmountCents = 0,
  int principalTrendCents = 0,
  int remainingTrendCents = 0,
  DateTime? nextPaymentDate,
  int nextPaymentAmountCents = 0,
  String nextPaymentCounterparty = '',
  int nextPaymentPeriodNo = 0,
}) =>
    ReceivablesSummary(
      totalPrincipalCents: totalPrincipalCents,
      totalRemainingCents: totalRemainingCents,
      totalCollectedCents: totalCollectedCents,
      pendingInterestCents: pendingInterestCents,
      count: count,
      overdueCount: overdueCount,
      overdueAmountCents: overdueAmountCents,
      principalTrendCents: principalTrendCents,
      remainingTrendCents: remainingTrendCents,
      nextPaymentDate: nextPaymentDate,
      nextPaymentAmountCents: nextPaymentAmountCents,
      nextPaymentCounterparty: nextPaymentCounterparty,
      nextPaymentPeriodNo: nextPaymentPeriodNo,
    );

Widget _harness(List<Debt> debts, {ReceivablesSummary? summary}) {
  final repo = _MockRepo();
  final summaryRepo = _MockSummaryRepo();
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
  // summary mock:default 返回固定 summary;null 传则模拟失败(Left)。
  if (summary != null) {
    when(() => summaryRepo.fetch())
        .thenAnswer((_) async => dartz.Right(summary));
  } else {
    when(() => summaryRepo.fetch())
        .thenAnswer((_) async => const dartz.Left(ServerFailure('summary load failed')));
  }
  // getIt 注册 mock summary repo(页面 initState 走 getIt<ReceivablesSummaryRepository>())。
  GetIt.instance.registerSingleton<ReceivablesSummaryRepository>(summaryRepo);
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
  // 每个 test 后重置 getIt,避免重复注册 summaryRepo。
  tearDown(() => GetIt.instance.reset());

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
      nextPaymentDate: DateTime(2026, 8, 15),
      nextPaymentAmountCents: 250000,
      nextPaymentPeriodNo: 5,
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

  testWidgets('overview: 总借出本金 + 剩余应收 + 本金收回进度 progress bar', (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness(receivables));
    await t.pumpAndSettle();
    // OD .ov 3-col grid:cell1 总借出本金 / cell2 剩余应收（本金）/ cell3 本金收回进度。
    expect(find.textContaining('总借出本金'), findsOneWidget);
    expect(find.textContaining('剩余应收'), findsWidgets);
    expect(find.textContaining('本金收回进度'), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    // cell1 大字总借出本金 = sum(total) = 500 万 + 1000 万 = 150,000.00
    // (OD .ov-amt-num 把 cur 与数字拆 span,故只匹配数字部分)。
    expect(find.textContaining('150,000.00'), findsWidgets);
    expect(find.text('总负债'), findsNothing);
    expect(find.textContaining('剩余本金'), findsNothing);
  });

  testWidgets('overview: 收回进度 ratio = totalCollected/totalPrincipal', (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness(receivables));
    await t.pumpAndSettle();
    // r1: 已收 2000000;r2: 已收 2425800;sum=4425800
    // total sum=15000000 → 4425800/15000000 = 0.29505... → 29.5%
    expect(find.textContaining('29.5%'), findsWidgets);
  });

  testWidgets('L1: avatar tile 渲染债务人首字', (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness(receivables));
    await t.pumpAndSettle();
    // 张三 / 李四 的 avatar 首字渲染(各 1)。
    expect(find.text('张'), findsOneWidget);
    expect(find.text('李'), findsOneWidget);
  });

  testWidgets('L2: stat strip 4 卡(笔数 / 已收本息 / 待收利息 / 逾期应收)',
      (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    final s = _summary(
      totalCollectedCents: 4425800,
      pendingInterestCents: 320000,
      overdueCount: 1,
      overdueAmountCents: 7574200,
      count: 2,
    );
    await t.pumpWidget(_harness(receivables, summary: s));
    await t.pumpAndSettle();
    // 4 个 label 渲染。
    expect(find.text('债权笔数'), findsOneWidget);
    expect(find.text('已收本息'), findsOneWidget);
    expect(find.text('待收利息'), findsOneWidget);
    expect(find.text('逾期应收'), findsOneWidget);
    // 值:count=2 / 已收 ¥44,258.00(overview 累计已收也显此值,故 ≥2)/
    // 待收利息 ¥3,200.00 / 逾期 1 笔。
    expect(find.text('2'), findsWidgets);
    expect(find.textContaining('¥44,258.00'), findsWidgets);
    expect(find.textContaining('¥3,200.00'), findsWidgets);
    expect(find.text('1 笔'), findsOneWidget);
  });

  testWidgets('L2: summary null → stat strip 显 —(loading,不阻塞列表)', (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness(receivables, summary: null));
    await t.pumpAndSettle();
    // 4 卡 label 渲染 + 值显 —(loading 占位)。
    expect(find.text('已收本息'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(4));
    // 列表仍渲染(张三 / 李四)。
    expect(find.text('张三'), findsOneWidget);
    expect(find.text('李四'), findsOneWidget);
  });

  testWidgets('L3: 横向 row foot callout(下次收款 · 第 N 期 + 收款 CTA)',
      (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness(receivables));
    await t.pumpAndSettle();
    // r1 有 nextPayment(第 5 期 · 2026-08-15 · ¥2,500.00)→ foot callout 渲染。
    expect(find.textContaining('下次收款'), findsWidgets);
    expect(find.textContaining('第 5 期'), findsOneWidget);
    expect(find.textContaining('¥2,500.00'), findsOneWidget);
    // 收款 CTA(列表 row foot 内,L3 重引入)。
    expect(find.text('收款'), findsWidgets);
  });

  testWidgets('L4: overview trend(较上月)+ 含待收利息 breakdown', (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    final s = _summary(
      principalTrendCents: 500000, // +¥5,000.00 较上月
      pendingInterestCents: 320000,
    );
    await t.pumpWidget(_harness(receivables, summary: s));
    await t.pumpAndSettle();
    // trend:较上月 +¥5,000.00(正绿)。
    expect(find.textContaining('较上月'), findsOneWidget);
    expect(find.textContaining('¥5,000.00'), findsOneWidget);
    // breakdown:含待收利息 ¥3,200.00
    expect(find.textContaining('含待收利息'), findsOneWidget);
  });

  testWidgets('L4: overview 下次收款 callout(对方 + 期数 + 查看收款计划 CTA)',
      (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    final s = _summary(
      nextPaymentDate: DateTime(2026, 8, 15),
      nextPaymentAmountCents: 250000,
      nextPaymentCounterparty: '张三',
      nextPaymentPeriodNo: 5,
    );
    await t.pumpWidget(_harness(receivables, summary: s));
    await t.pumpAndSettle();
    // overview foot callout:第 5 期 + 张三 + ¥2,500.00 + CTA。
    expect(find.textContaining('第 5 期'), findsWidgets);
    expect(find.text('查看收款计划'), findsOneWidget);
  });

  testWidgets('L4: 筛选 4-seg(全部/进行中/已结清/逾期)+ 逾期 tab 过滤',
      (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    final mixed = [
      ...receivables, // r1 张三(到期 2026-08-15 未来)/ r2 李四(到期 2027 未来)
      _debt(
        id: 's1',
        counterparty: '赵六',
        interestRate: 0.00,
        amortization: AmortizationMethod.lumpSum,
        dueDate: DateTime(2025, 1, 1), // 过去 → 逾期
        totalPrincipalCents: 5000000,
        remainingPrincipalCents: 0, // 已结清(已结清优先,不算逾期)
      ),
      _debt(
        id: 'o1',
        counterparty: '王五',
        interestRate: 5.00,
        amortization: AmortizationMethod.lumpSum,
        dueDate: DateTime(2025, 6, 1), // 过去 + 未结清 → 逾期
        totalPrincipalCents: 8000000,
        remainingPrincipalCents: 4000000,
      ),
    ];
    await t.pumpWidget(_harness(mixed));
    await t.pumpAndSettle();
    // segmented:全部 4 / 进行中 3(张三/李四/王五)/ 已结清 1 / 逾期 1(王五)。
    expect(find.text('全部 4'), findsOneWidget);
    expect(find.text('进行中 3'), findsOneWidget);
    expect(find.text('已结清 1'), findsOneWidget);
    expect(find.text('逾期 1'), findsOneWidget);
    // 默认进行中 → 王五(逾期但未结清)仍显示(进行中 = !settled)。
    expect(find.text('王五'), findsOneWidget);
    // 切「逾期」→ 只王五,张三/李四/赵六 排除。
    await t.tap(find.byKey(const ValueKey('listFilter-逾期')));
    await t.pumpAndSettle();
    expect(find.text('王五'), findsOneWidget);
    expect(find.text('张三'), findsNothing);
    expect(find.text('李四'), findsNothing);
    expect(find.text('赵六'), findsNothing);
  });

  testWidgets('receivable card: 债务人 + 剩余应收 + 利率 + 到期', (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness(receivables));
    await t.pumpAndSettle();
    expect(find.text('张三'), findsOneWidget);
    expect(find.text('李四'), findsOneWidget);
    expect(find.textContaining('¥30,000.00'), findsOneWidget);
    expect(find.textContaining('剩余应收'), findsWidgets);
    expect(find.textContaining('0.00%'), findsOneWidget);
    expect(find.textContaining('8.00%'), findsOneWidget);
    expect(find.textContaining('2026-08-15'), findsWidgets);
    expect(find.textContaining('2027-02-15'), findsOneWidget);
  });

  testWidgets('receivable card: 收回进度 progress bar 用金色 accent', (t) async {
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
    expect(find.text('赵六'), findsNothing);
    await t.tap(find.byKey(const ValueKey('listFilter-全部')));
    await t.pumpAndSettle();
    expect(find.text('赵六'), findsOneWidget);
    expect(find.text('已结清 ✓'), findsOneWidget);
    expect(find.text('逾期'), findsNothing);
  });

  testWidgets('筛选 segmented: 计数 + 切换(默认进行中隐藏已结清)', (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    final mixed = [
      ...receivables,
      _debt(
        id: 's1',
        counterparty: '赵六',
        interestRate: 0.00,
        amortization: AmortizationMethod.lumpSum,
        dueDate: DateTime(2025, 1, 1),
        totalPrincipalCents: 5000000,
        remainingPrincipalCents: 0,
      ),
    ];
    await t.pumpWidget(_harness(mixed));
    await t.pumpAndSettle();
    expect(find.text('全部 3'), findsOneWidget);
    expect(find.text('进行中 2'), findsOneWidget);
    expect(find.text('已结清 1'), findsOneWidget);
    expect(find.text('逾期 0'), findsOneWidget);
    expect(find.text('赵六'), findsNothing);
    expect(find.text('张三'), findsOneWidget);
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
    // mobile 卡也含 avatar(L1)。
    expect(find.text('张'), findsOneWidget);
    expect(find.text('李'), findsOneWidget);
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
    final summaryRepo = _MockSummaryRepo();
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
    when(() => summaryRepo.fetch())
        .thenAnswer((_) async => dartz.Right(_summary()));
    GetIt.instance.registerSingleton<ReceivablesSummaryRepository>(summaryRepo);
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
    expect(calls, isNotEmpty);
    expect(calls.last, DebtType.borrowedOut);
  });
}
