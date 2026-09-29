// T4(F43 R16 sprint-1)—— ReportAssemblyService 汇编编排(fake store +
// mock holding repo,oracle 全手算):
//
// - 四阶段回调顺序(FR-8 进度契约:loadingLedger→replaying→assembling→
//   performance);
// - 六章节快照逐数值 oracle(总览/资产负债/收支+prior/现金流/预算/投资);
// - 自适应隐藏(无预算/无持仓)+ excludedSections 附注(FR-3);
// - 外币折 CNY 两级汇率(历史→现值→缺失跳过+注记);
// - budget actuals conformance(同 drift 种子对照 budget_local_ds);
// - T2(F44):MD&A supplement 接线 → doc.mda(手算 oracle)。
import 'package:dartz/dartz.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/budget/data/budget_local_ds.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/holding/domain/entities/performance_entity.dart';
import 'package:yucai_client/holding/domain/entities/period_performance.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/report/data/report_ledger_store_impl.dart';
import 'package:yucai_client/report/domain/expense_basis.dart';
import 'package:yucai_client/report/domain/mda/mda_engine.dart';
import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/report_assembly_service.dart';
import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/domain/report_ledger_store.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

import 'mda/mda_fixtures.dart';

// ---- fakes ----

/// 内存 port 替身:行数据直填;汇率按 (code, 时点) 回调查表。
class FakeStore implements ReportLedgerStore {
  FakeStore({
    this.accountList = const [],
    this.entryList = const [],
    this.budgetList = const [],
    this.rateFor,
    this.templateList = const [],
    this.transactionList = const [],
  });

  final List<AccountRow> accountList;
  final List<LedgerEntryRow> entryList;
  final List<BudgetRow> budgetList;
  final RateQuote? Function(String code, DateTime on)? rateFor;

  /// F44:MD&A supplement 输入(期内数据由测试自行构造,fake 原样回)。
  final List<TemplateRowVO> templateList;
  final List<LargeTxnVO> transactionList;

  @override
  Future<List<AccountRow>> accounts() async => accountList;

  @override
  Future<List<LedgerEntryRow>> entries() async => entryList;

  @override
  Future<List<BudgetRow>> budgetRows() async => budgetList;

  @override
  Future<RateQuote> rateToCny(String currencyCode, DateTime on) async =>
      rateFor?.call(currencyCode, on) ?? const RateQuote();

  @override
  Future<List<TemplateRowVO>> templateRows(ReportPeriod period) async =>
      templateList;

  @override
  Future<List<LargeTxnVO>> transactions(ReportPeriod period) async =>
      transactionList;
}

class _MockHoldingRepo extends Mock implements HoldingRepository {}

/// 便捷行构造(LedgerEntryRow 参数多,测试里以位置参数收紧)。
LedgerEntryRow _leg(
  String txnId,
  AccountRow account,
  DateTime date,
  int debit,
  int credit,
) =>
    LedgerEntryRow(
      transactionId: txnId,
      accountId: account.id,
      accountType: account.type,
      category: account.category,
      date: date,
      debitCents: debit,
      creditCents: credit,
);

/// 双腿交易(借贷各一条,共享 txnId)。
List<LedgerEntryRow> _doubleEntry(
  String txnId,
  AccountRow debitSide,
  AccountRow creditSide,
  DateTime date,
  int amount,
) =>
    [
      _leg(txnId, debitSide, date, amount, 0),
      _leg(txnId, creditSide, date, 0, amount),
    ];

/// 常用账户集(cents;id 即语义名)。
AccountRow _acct(
  String id,
  int type,
  String? category, {
  int initial = 0,
  String currency = 'CNY',
  String? name,
}) =>
    AccountRow(
      id: id,
      type: type,
      category: category,
      initialBalanceCents: initial,
      currencyCode: currency,
      name: name,
);

PortfolioPerformance _perf(PeriodPerformance? period) => PortfolioPerformance(
      realizedCents: 0,
      unrealizedCents: 0,
      totalCents: 0,
      period: period,
    );

/// mock holding repo:仅 stub getPortfolioPerformance(其余成员不被调用)。
_MockHoldingRepo _repoWith(PeriodPerformance? period) {
  final repo = _MockHoldingRepo();
  when(() => repo.getPortfolioPerformance(
        range: any(named: 'range'),
        accountId: any(named: 'accountId'),
        includeBenchmark: any(named: 'includeBenchmark'),
        baseCurrency: any(named: 'baseCurrency'),
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      )).thenAnswer((_) async => Right(_perf(period)));
  return repo;
}

ReportAssemblyService _service(
  FakeStore store, {
  ExpenseBasis basis = const CashExpenseBasis(),
  PeriodPerformance? perf,
}) =>
    ReportAssemblyService(store, basis, _repoWith(perf), const MdaEngine());

// ---- 共享账本 fixture(2026-08 月报;oracle 全手算,见各断言)----
//
// 账户:cash(savings 资产,期初建账 1,000,000)/ invest(investment 资产)/
// card(creditCard 负债)/ food+transport(expense 科目)/ salary(income 科目)。
// 分录:
//   07-05 支出 food 20,000(借 food/贷 cash)      ┐
//   07-10 收入 salary 300,000(借 cash/贷 salary)  ├ 7 月(prior 环比期)
//   07-20 刷卡 food 8,000(借 food/贷 card,不涉现金)┘
//   08-02 收入 salary 500,000(借 cash/贷 salary)
//   08-06 支出 food 30,000(借 food/贷 cash)
//   08-09 支出 transport 10,000(借 transport/贷 cash)
//   08-20 投资转入 80,000(借 invest/贷 cash,投资活动流出)
//   08-25 信用卡还款 5,000(借 card/贷 cash,融资活动流出)
// 现金回放:start = 1,000,000+300,000−20,000 = 1,280,000;
//           end = 1,280,000+500,000−30,000−10,000−80,000−5,000 = 1,655,000。
// card 回放:start = 8,000;end = 8,000−5,000 = 3,000。
class _Ledger {
  _Ledger()
      : cash = _acct('cash', 1, 'savings', initial: 1000000),
        invest = _acct('invest', 1, 'investment'),
        card = _acct('card', 2, 'creditCard'),
        // T5-R1:收支科目带账户名(汇编层按 id→name 挂入构成行)。
        food = _acct('food', 5, 'otherAsset', name: '餐饮'),
        transport = _acct('transport', 5, 'otherAsset', name: '交通'),
        // income/expense 科目账户 category 无意义,真实写路径恒 otherAsset
        // (category_bloc/demo_seed 同款)——不得用 savings,否则被现金
        // 口径误判(classifier _isCash 仅看 category)。
        salary = _acct('salary', 4, 'otherAsset', name: '工资');

  final AccountRow cash;
  final AccountRow invest;
  final AccountRow card;
  final AccountRow food;
  final AccountRow transport;
  final AccountRow salary;

  List<AccountRow> get accounts =>
      [cash, invest, card, food, transport, salary];

  List<LedgerEntryRow> get entries => [
        ..._doubleEntry('t1', cash, salary, DateTime(2026, 7, 10), 300000),
        ..._doubleEntry('t2', food, cash, DateTime(2026, 7, 5), 20000),
        ..._doubleEntry('t3', food, card, DateTime(2026, 7, 20), 8000),
        ..._doubleEntry('t4', cash, salary, DateTime(2026, 8, 2), 500000),
        ..._doubleEntry('t5', food, cash, DateTime(2026, 8, 6), 30000),
        ..._doubleEntry('t6', transport, cash, DateTime(2026, 8, 9), 10000),
        ..._doubleEntry('t7', invest, cash, DateTime(2026, 8, 20), 80000),
        ..._doubleEntry('t8', card, cash, DateTime(2026, 8, 25), 5000),
      ];
}

/// FR-7 接口测试替身:支出减半口径(默认构成 × ½,四舍五入)——验证
/// 汇编服务经构造注入消费 [ExpenseBasis] 且章节结构不随实现变化
/// (spec FR-7 scenario;R17 待摊 basis 接入点的契约钉子)。
class _HalvedExpenseBasis implements ExpenseBasis {
  const _HalvedExpenseBasis();

  @override
  List<CategoryAmount> expenseByCategory(
    List<LedgerEntryRow> entries,
    ReportPeriod period,
  ) {
    final base = const CashExpenseBasis().expenseByCategory(entries, period);
    final total = base.fold<int>(0, (s, c) => s + (c.amountCents / 2).round());
    return [
      for (final c in base)
        CategoryAmount.create(
          category: c.category,
          amountCents: (c.amountCents / 2).round(),
          totalCents: total,
        ),
    ];
  }

  @override
  int totalExpense(List<LedgerEntryRow> entries, ReportPeriod period) =>
      (const CashExpenseBasis().totalExpense(entries, period) / 2).round();
}

// 章节数值签名:VO 无 ==,抽取原始值树后深比较(FR-7 (b) 逐位一致)。
List<Object?> _bsSig(BalanceSheetSection s) => [
      s.assetsTotalCents,
      s.liabilitiesTotalCents,
      s.debtRatioPct,
      [
        for (final c in s.assets) (c.category, c.name, c.amountCents, c.pct),
      ],
      [
        for (final c in s.liabilities)
          (c.category, c.name, c.amountCents, c.pct),
      ],
      [
        for (final c in s.changes)
          (c.category, c.startCents, c.endCents, c.deltaCents),
      ],
    ];

List<Object?> _cfSig(CashFlowSection s) => [
      (s.operating.inflowCents, s.operating.outflowCents,
          s.operating.netCents),
      (s.investing.inflowCents, s.investing.outflowCents,
          s.investing.netCents),
      (s.financing.inflowCents, s.financing.outflowCents,
          s.financing.netCents),
      (s.netDeltaCents, s.reconciled),
    ];

List<Object?> _budgetSig(BudgetSection s) => [
      for (final i in s.items)
        (i.name, i.actualCents, i.limitCents, i.pct, i.overran),
    ];

Object? _investmentSig(InvestmentSection s) =>
    (s.mvStartCents, s.mvEndCents, s.netBuyCents, s.estGainCents, s.twr);

void main() {
  test('generate:四阶段回调顺序钉死,文档期与生成时刻回填', () async {
    final service = _service(FakeStore(), perf: null);
    final phases = <ReportPhase>[];

    final doc = await service.generate(
      ReportPeriod.monthly(2026, 8),
      onPhase: phases.add,
    );

    expect(
      phases,
      [
        ReportPhase.loadingLedger,
        ReportPhase.replaying,
        ReportPhase.assembling,
        ReportPhase.performance,
      ],
    );
    expect(doc.period, ReportPeriod.monthly(2026, 8));
    expect(doc.generatedAt, isA<DateTime>());
  });

  test('总览:income=income 科目 credit 单边,expense 经 basis,结余/储蓄率/现金净变动手算', () async {
    final l = _Ledger();
    final service = _service(
      FakeStore(accountList: l.accounts, entryList: l.entries),
      perf: null, // 无持仓 → 投资章节隐藏,mv 贡献 0
    );

    final doc = await service.generate(ReportPeriod.monthly(2026, 8));

    final ov = doc.overview;
    expect(ov.incomeCents, 500000); // 仅 08-02 salary credit 单边
    expect(ov.expenseCents, 40000); // food 30,000 + transport 10,000(debit 单边)
    expect(ov.surplusCents, 460000);
    expect(ov.savingsRate, 92.0); // 460,000/500,000
    expect(ov.cashDeltaCents, 375000); // 1,655,000 − 1,280,000
  });

  test('总览:净资产=Σ资产回放+持仓时点市值−Σ负债回放(无持仓 mv=0)', () async {
    final l = _Ledger();

    // 有持仓:mv 期初 70,000/期末 90,000(fake holding 引擎)。
    final withMv = await _service(
      FakeStore(accountList: l.accounts, entryList: l.entries),
      perf: const PeriodPerformance(
        beginMvCents: 70000,
        endMvCents: 90000,
        netBuyCents: 80000,
        estimatedGainCents: -60000,
        twrPct: 25.0,
      ),
    ).generate(ReportPeriod.monthly(2026, 8));
    // start = (1,280,000 + 0) + 70,000 − 8,000;end = (1,655,000+80,000)
    // + 90,000 − 3,000。
    expect(withMv.overview.netWorthStartCents, 1342000);
    expect(withMv.overview.netWorthEndCents, 1822000);

    // 无持仓(period=null)→ mv 贡献 0,投资章节隐藏。
    final noMv = await _service(
      FakeStore(accountList: l.accounts, entryList: l.entries),
      perf: null,
    ).generate(ReportPeriod.monthly(2026, 8));
    expect(noMv.overview.netWorthStartCents, 1272000); // 1,280,000−8,000
    expect(noMv.overview.netWorthEndCents, 1732000); // 1,735,000−3,000
  });

  test('资产负债:期末按 category 构成(pct/降序)+期初期末变动行', () async {
    final l = _Ledger();
    final doc = await _service(
      FakeStore(accountList: l.accounts, entryList: l.entries),
      perf: null,
    ).generate(ReportPeriod.monthly(2026, 8));

    final bs = doc.balanceSheet;
    // 资产期末:savings 1,655,000 + investment 80,000 = 1,735,000。
    expect(bs.assets, hasLength(2));
    expect(bs.assets.first.category, 'savings');
    expect(bs.assets.first.amountCents, 1655000);
    expect(bs.assets.first.pct, 95.4); // 1,655,000/1,735,000
    expect(bs.assets[1].category, 'investment');
    expect(bs.assets[1].amountCents, 80000);
    expect(bs.assets[1].pct, 4.6);

    expect(bs.liabilities, hasLength(1));
    expect(bs.liabilities.first.category, 'creditCard');
    expect(bs.liabilities.first.amountCents, 3000);
    expect(bs.liabilities.first.pct, 100.0);

    // 变动行(资产∪负债分类并集,期初/期末/差额)。
    final changes = {for (final c in bs.changes) c.category: c};
    expect(changes.keys, containsAll(['savings', 'investment', 'creditCard']));
    expect(changes['savings']!.startCents, 1280000);
    expect(changes['savings']!.endCents, 1655000);
    expect(changes['savings']!.deltaCents, 375000);
    expect(changes['investment']!.startCents, 0);
    expect(changes['investment']!.deltaCents, 80000);
    expect(changes['creditCard']!.startCents, 8000);
    expect(changes['creditCard']!.endCents, 3000);
    expect(changes['creditCard']!.deltaCents, -5000);
  });

  test('收支:income/expense 构成+日均支出(自然天数口径)+月报环比上月支出', () async {
    final l = _Ledger();
    final doc = await _service(
      FakeStore(accountList: l.accounts, entryList: l.entries),
      perf: null,
    ).generate(ReportPeriod.monthly(2026, 8));

    final stmt = doc.incomeStatement;
    expect(stmt.income, hasLength(1));
    expect(stmt.income.first.category, 'salary');
    expect(stmt.income.first.amountCents, 500000);
    expect(stmt.income.first.pct, 100.0);
    // T5-R1 分类名称契约:收支构成行携带科目账户名(id 保留在 category)。
    expect(stmt.income.first.name, '工资');

    expect(stmt.expense, hasLength(2)); // 金额降序
    expect(stmt.expense.first.category, 'food');
    expect(stmt.expense.first.amountCents, 30000);
    expect(stmt.expense.first.pct, 75.0);
    expect(stmt.expense.first.name, '餐饮');
    expect(stmt.expense[1].category, 'transport');
    expect(stmt.expense[1].amountCents, 10000);
    expect(stmt.expense[1].pct, 25.0);
    expect(stmt.expense[1].name, '交通');

    // 日均支出 = 40,000 ~/ 31 自然日 = 1,290(截断;视觉对齐批次口径,
    // 原型「日均支出 ¥570.00」= 支出/自然天数同式)。
    expect(stmt.dailyAvgCents, 1290);

    // 环比上月支出:7 月 expense 28,000;(40,000−28,000)/28,000 = 42.9%。
    expect(stmt.priorComparison, isNotNull);
    expect(stmt.priorComparison!.label, '环比上月支出');
    expect(stmt.priorComparison!.deltaPct, 42.9);
  });

  test('收支:年报环比上年支出;对比期无数据 → priorComparison null', () async {
    final l = _Ledger();
    // 2025 年对比期数据:06-15 收入 400,000(借 cash/贷 salary)+
    // 06-20 支出 food 50,000(借 food/贷 cash,现金口径)。
    final entries = [
      ..._doubleEntry('p1', l.cash, l.salary, DateTime(2025, 6, 15), 400000),
      ..._doubleEntry('p2', l.food, l.cash, DateTime(2025, 6, 20), 50000),
      ...l.entries,
    ];

    final doc = await _service(
      FakeStore(accountList: l.accounts, entryList: entries),
      perf: null,
    ).generate(ReportPeriod.yearly(2026));
    // 2026 年度 expense 68,000;环比上年支出 (68,000−50,000)/50,000 =
    // 36.0%(视觉对齐批次:口径从结余换为支出)。
    final stmt = doc.incomeStatement;
    expect(stmt.priorComparison, isNotNull);
    expect(stmt.priorComparison!.label, '环比上年支出');
    expect(stmt.priorComparison!.deltaPct, 36.0);

    // 首期无对比数据(2025 报告,2024 无分录)→ null。
    final first = await _service(
      FakeStore(accountList: l.accounts, entryList: entries),
      perf: null,
    ).generate(ReportPeriod.yearly(2025));
    // 2025 自身有数据,但 2024 无 → prior 无对比数据。
    expect(first.incomeStatement.priorComparison, isNull);
  });

  test('现金流:三类活动流(经营/投资/融资)+净变动勾稽,期外与不涉现金不计', () async {
    final l = _Ledger();
    final doc = await _service(
      FakeStore(accountList: l.accounts, entryList: l.entries),
      perf: null,
    ).generate(ReportPeriod.monthly(2026, 8));

    final cf = doc.cashFlow;
    expect(cf.operating.inflowCents, 500000); // 08-02 工资
    expect(cf.operating.outflowCents, 40000); // 08-06 food + 08-09 transport
    expect(cf.operating.netCents, 460000);
    expect(cf.investing.inflowCents, 0);
    expect(cf.investing.outflowCents, 80000); // 08-20 投资转入
    expect(cf.investing.netCents, -80000);
    expect(cf.financing.inflowCents, 0);
    expect(cf.financing.outflowCents, 5000); // 08-25 信用卡还款
    expect(cf.financing.netCents, -5000);
    expect(cf.netDeltaCents, 375000); // == 期末−期初现金(classifier assert)
    expect(cf.reconciled, true);
    expect(doc.overview.cashDeltaCents, cf.netDeltaCents); // 同源勾稽
  });

  test('现金流明细:分类器按对手方分类聚合 counterpartyCents(明细列数据源)',
      () async {
    // 视觉对齐批次(2026-09-29,原型 v9 .cf-det「明细」列):投资/融资
    // 活动的对手分类净额(category → signed cents,正=现金流入侧)。
    final l = _Ledger();
    final doc = await _service(
      FakeStore(accountList: l.accounts, entryList: l.entries),
      perf: null,
    ).generate(ReportPeriod.monthly(2026, 8));

    final cf = doc.cashFlow;
    // 投资:对手 invest(investment)净 −80,000(08-20 投资转入流出)。
    expect(cf.investing.counterpartyCents['investment'], -80000);
    // 融资:对手 card(creditCard)净 −5,000(08-25 信用卡还款)。
    expect(cf.financing.counterpartyCents['creditCard'], -5000);
    // 经营:对手 = 收支科目(category 无语义)→ 不聚合,明细走语义文案。
    expect(cf.operating.counterpartyCents, isEmpty);
    // 不涉现金的对手(07-20 刷卡 food↔card)不计入任何活动。
    expect(cf.financing.counterpartyCents['otherAsset'], isNull);
  });

  test('预算执行:月报=当月各 item(actuals=max(Σd,Σc)),他月预算不计', () async {
    final l = _Ledger();
    BudgetRow row(
      String budgetId,
      String month,
      String itemId,
      AccountRow acct,
      int planned,
    ) =>
        BudgetRow(
          budgetId: budgetId,
          month: month,
          itemId: itemId,
          accountId: acct.id,
          accountCategory: acct.category,
          accountName: acct.id,
          plannedCents: planned,
        );

    final doc = await _service(
      FakeStore(
        accountList: l.accounts,
        entryList: l.entries,
        budgetList: [
          row('b0', '2026-07', 'i0', l.food, 99999), // 期外预算不计
          row('b1', '2026-08', 'i1', l.food, 50000),
          row('b1', '2026-08', 'i2', l.transport, 8000),
        ],
      ),
      perf: null,
    ).generate(ReportPeriod.monthly(2026, 8));

    final budget = doc.budget!;
    expect(budget.items, hasLength(2));
    final foodItem = budget.items.firstWhere((i) => i.name == 'food');
    expect(foodItem.actualCents, 30000); // 08-06 debit 30,000 → max(30000,0)
    expect(foodItem.limitCents, 50000);
    expect(foodItem.pct, 60.0);
    expect(foodItem.overran, isFalse);
    final transportItem = budget.items.firstWhere((i) => i.name == 'transport');
    expect(transportItem.actualCents, 10000);
    expect(transportItem.limitCents, 8000);
    expect(transportItem.pct, 125.0);
    expect(transportItem.overran, isTrue);
    // 有预算 → 不披露预算项(fixture perf=null,投资另计)。
    expect(
      doc.excludedSections,
      isNot(contains('预算执行(本期无预算)')),
    );
  });

  test('预算执行:无预算 → 章节 null + excluded 文案(FR-3)', () async {
    final l = _Ledger();
    final doc = await _service(
      FakeStore(accountList: l.accounts, entryList: l.entries),
      perf: null,
    ).generate(ReportPeriod.monthly(2026, 8));

    expect(doc.budget, isNull);
    expect(doc.excludedSections, contains('预算执行(本期无预算)'));
  });

  test('预算执行:年报=年内各月逐月汇总(限额/实际跨月累加),他年不计', () async {
    final l = _Ledger();
    BudgetRow row(String month, String itemId, AccountRow acct, int planned) =>
        BudgetRow(
          budgetId: 'b-$month',
          month: month,
          itemId: itemId,
          accountId: acct.id,
          accountCategory: acct.category,
          accountName: acct.id,
          plannedCents: planned,
        );

    final doc = await _service(
      FakeStore(
        accountList: l.accounts,
        entryList: l.entries,
        budgetList: [
          row('2025-12', 'x0', l.food, 777777), // 他年不计
          row('2026-01', 'i1', l.food, 10000),
          row('2026-08', 'i2', l.food, 50000),
          row('2026-08', 'i3', l.transport, 8000),
          row('2026-09', 'i4', l.food, 10000),
        ],
      ),
      perf: null,
    ).generate(ReportPeriod.yearly(2026));

    final budget = doc.budget!;
    final foodItem = budget.items.firstWhere((i) => i.name == 'food');
    // 限额跨月累加 10,000+50,000+10,000;实际 = 各月 max(Σd,Σc) 之和
    // = 0(1 月)+30,000(8 月)+0(9 月)。
    expect(foodItem.limitCents, 70000);
    expect(foodItem.actualCents, 30000);
    expect(foodItem.pct, 42.9); // 30,000/70,000 = 42.857 → 42.9
    final transportItem = budget.items.firstWhere((i) => i.name == 'transport');
    expect(transportItem.limitCents, 8000);
    expect(transportItem.actualCents, 10000);
    expect(transportItem.pct, 125.0);
  });

  test('投资绩效:PeriodPerformance 五要素映射(估算收益构造时算)', () async {
    final l = _Ledger();
    final doc = await _service(
      FakeStore(accountList: l.accounts, entryList: l.entries),
      perf: const PeriodPerformance(
        beginMvCents: 70000,
        endMvCents: 90000,
        netBuyCents: 80000,
        estimatedGainCents: -60000,
        twrPct: 25.0,
      ),
    ).generate(ReportPeriod.monthly(2026, 8));

    final inv = doc.investment!;
    expect(inv.mvStartCents, 70000);
    expect(inv.mvEndCents, 90000);
    expect(inv.netBuyCents, 80000);
    expect(inv.estGainCents, -60000); // 90,000−70,000−80,000(FR-6)
    expect(inv.twr, 25.0);
    // 有持仓 → 不披露投资项(fixture 无预算,预算另计)。
    expect(
      doc.excludedSections,
      isNot(contains('投资绩效(本期无持仓)')),
    );
  });

  test('投资绩效:period null(坏价)或期内全零(无持仓)→ null+excluded(FR-3)', () async {
    final l = _Ledger();
    // period=null(坏价降级)。
    final badPrice = await _service(
      FakeStore(accountList: l.accounts, entryList: l.entries),
      perf: null,
    ).generate(ReportPeriod.monthly(2026, 8));
    expect(badPrice.investment, isNull);
    expect(badPrice.excludedSections, contains('投资绩效(本期无持仓)'));

    // period 全零(期内期初期末市值与净买入均为 0 = 期内无持仓)。
    final zero = await _service(
      FakeStore(accountList: l.accounts, entryList: l.entries),
      perf: const PeriodPerformance(
        beginMvCents: 0,
        endMvCents: 0,
        netBuyCents: 0,
        estimatedGainCents: 0,
        twrPct: 0,
      ),
    ).generate(ReportPeriod.monthly(2026, 8));
    expect(zero.investment, isNull);
    expect(zero.excludedSections, contains('投资绩效(本期无持仓)'));
  });

  test('外币折 CNY:期初历史汇率/期末现值回退,无汇率账户跳过+注记;现金流原币', () async {
    final l = _Ledger();
    final usdCash = _acct('usdCash', 1, 'savings', initial: 100000, currency: 'USD');
    final usdFixed = _acct('usdFixed', 1, 'fixedDeposit', currency: 'USD');
    final jpyCash = _acct('jpyCash', 1, 'savings', initial: 30000, currency: 'JPY');
    final accounts = [...l.accounts, usdCash, usdFixed, jpyCash];
    // 08-12 USD 内部转定存:借 usdFixed / 贷 usdCash 50,000(USD 原币,
    // 现金→投资类非现金资产 → 投资活动流出)。
    final entries = [
      ...l.entries,
      ..._doubleEntry('t9', usdFixed, usdCash, DateTime(2026, 8, 12), 50000),
    ];

    final doc = await _service(
      FakeStore(
        accountList: accounts,
        entryList: entries,
        rateFor: (code, on) {
          if (code == 'USD') {
            // 期初(08-01)有历史汇率;期末(08-31)历史缺失 → 现值回退。
            return on.day == 1
                ? const RateQuote(asOfRate: 7.0)
                : const RateQuote(currentRate: 7.2);
          }
          return const RateQuote(); // JPY:双缺失 → 跳过折算
        },
      ),
      perf: null,
    ).generate(ReportPeriod.monthly(2026, 8));

    // 净资产(折 CNY):CNY 1,272,000/1,732,000 + USD 合计 100,000
    // (usdCash 50,000 + usdFixed 50,000)×7.0/×7.2;JPY 跳过。
    expect(doc.overview.netWorthStartCents, 1272000 + 700000);
    expect(doc.overview.netWorthEndCents, 1732000 + 720000);

    // 资产负债(折 CNY):savings 期末 = CNY 1,655,000 + USD 50,000×7.2;
    // fixedDeposit 新增 360,000;JPY 不进构成。
    final savings = doc.balanceSheet.assets
        .firstWhere((c) => c.category == 'savings');
    expect(savings.amountCents, 1655000 + 360000);
    final fixed = doc.balanceSheet.assets
        .firstWhere((c) => c.category == 'fixedDeposit');
    expect(fixed.amountCents, 360000);
    // 期初变动行 = 1,280,000 + 100,000×7.0。
    final savingsChange = doc.balanceSheet.changes
        .firstWhere((c) => c.category == 'savings');
    expect(savingsChange.startCents, 1280000 + 700000);
    expect(savingsChange.deltaCents, 35000);

    // 现金流与现金净变动:**账本原币口径**(多币种直加,勾稽同单位,
    // 不折 CNY)——投资流出 = CNY 80,000 + USD 50,000;现金净变动 =
    // CNY +375,000 − USD 50,000 = 325,000(附注第 2 条钉此口径)。
    expect(doc.cashFlow.investing.outflowCents, 130000);
    expect(doc.cashFlow.netDeltaCents, 325000);
    expect(doc.overview.cashDeltaCents, 325000);

    // 附注披露跳过币种 + 口径分工(时点数折算/现金流原币)。
    final note = doc.overview.notes
        .firstWhere((n) => n.title == '口径说明');
    expect(note.lines.any((line) => line.contains('JPY') && line.contains('未折算')), isTrue);
    expect(note.lines[1], contains('原币'));
  });

  test('附注:口径说明三条固定 + 未包含项按 excluded 生成(无排除则无该附注)', () async {
    final l = _Ledger();

    // 全齐(有预算有持仓)→ 仅口径说明,无未包含项附注。
    BudgetRow foodBudget(
      String month,
      String itemId,
      AccountRow acct,
      int planned,
    ) =>
        BudgetRow(
          budgetId: 'b1',
          month: month,
          itemId: itemId,
          accountId: acct.id,
          accountCategory: acct.category,
          accountName: acct.id,
          plannedCents: planned,
        );

    final full = await _service(
      FakeStore(
        accountList: l.accounts,
        entryList: l.entries,
        budgetList: [foodBudget('2026-08', 'i1', l.food, 50000)],
      ),
      perf: const PeriodPerformance(
        beginMvCents: 70000,
        endMvCents: 90000,
        netBuyCents: 80000,
        estimatedGainCents: -60000,
        twrPct: 25.0,
      ),
    ).generate(ReportPeriod.monthly(2026, 8));

    expect(full.overview.notes, hasLength(1));
    final basis = full.overview.notes.first;
    expect(basis.title, '口径说明');
    expect(basis.lines, hasLength(3));
    // 三条口径:回放近似/历史汇率近似/现金及等价物范围。
    expect(basis.lines[0], contains('回放'));
    expect(basis.lines[0], contains('差额'));
    expect(basis.lines[1], contains('汇率'));
    expect(basis.lines[2], contains('savings'));
    expect(basis.lines[2], contains('定期存款'));

    // 双隐藏 → 未包含项附注逐条披露(FR-3 文案)。
    final empty = await _service(
      FakeStore(accountList: l.accounts, entryList: l.entries),
      perf: null,
    ).generate(ReportPeriod.monthly(2026, 8));
    final excludedNote = empty.overview.notes
        .firstWhere((n) => n.title == '未包含项');
    expect(excludedNote.lines, [
      '未包含:预算执行(本期无预算)',
      '未包含:投资绩效(本期无持仓)',
    ]);
  });

  test('全链 fixture:六章节齐全(有预算有持仓),各章节数值手算 oracle', () async {
    final l = _Ledger();
    BudgetRow row(
      String budgetId,
      String month,
      String itemId,
      AccountRow acct,
      int planned,
    ) =>
        BudgetRow(
          budgetId: budgetId,
          month: month,
          itemId: itemId,
          accountId: acct.id,
          accountCategory: acct.category,
          accountName: acct.id,
          plannedCents: planned,
        );

    final phases = <ReportPhase>[];
    final doc = await ReportAssemblyService(
      FakeStore(
        accountList: l.accounts,
        entryList: l.entries,
        budgetList: [
          row('b1', '2026-08', 'i1', l.food, 50000),
          row('b1', '2026-08', 'i2', l.transport, 8000),
        ],
      ),
      const CashExpenseBasis(),
      _repoWith(const PeriodPerformance(
        beginMvCents: 70000,
        endMvCents: 90000,
        netBuyCents: 80000,
        estimatedGainCents: -60000,
        twrPct: 25.0,
      )),
      const MdaEngine(),
    ).generate(ReportPeriod.monthly(2026, 8), onPhase: phases.add);

    // phase 顺序在全链下同样钉死。
    expect(phases, [
      ReportPhase.loadingLedger,
      ReportPhase.replaying,
      ReportPhase.assembling,
      ReportPhase.performance,
    ]);

    // 总览:1,342,000/1,822,000;500,000/40,000/460,000/92.0/375,000。
    final ov = doc.overview;
    expect(ov.netWorthStartCents, 1342000);
    expect(ov.netWorthEndCents, 1822000);
    expect(ov.incomeCents, 500000);
    expect(ov.surplusCents, 460000);
    expect(ov.savingsRate, 92.0);
    expect(ov.cashDeltaCents, 375000);

    // 资产负债:期末资产 1,735,000(savings+investment)、负债 3,000。
    expect(
      doc.balanceSheet.assets.fold<int>(0, (s, c) => s + c.amountCents),
      1735000,
    );
    expect(
      doc.balanceSheet.liabilities.fold<int>(0, (s, c) => s + c.amountCents),
      3000,
    );

    // 收支:prior 支出环比 42.9%(40,000 vs 28,000);现金流净 375,000。
    expect(doc.incomeStatement.priorComparison!.deltaPct, 42.9);
    expect(doc.cashFlow.netDeltaCents, 375000);

    // 预算:food 30,000/50,000;transport 10,000/8,000(超支)。
    expect(doc.budget, isNotNull);
    expect(doc.budget!.items, hasLength(2));
    // 投资:五要素。
    expect(doc.investment!.mvStartCents, 70000);
    expect(doc.investment!.estGainCents, -60000);
    expect(doc.investment!.twr, 25.0);

    // 全齐:无未包含项,附注仅口径说明。
    expect(doc.excludedSections, isEmpty);
    expect(doc.overview.notes, hasLength(1));
    expect(doc.overview.notes.first.title, '口径说明');
  });

  test('预算执行:月报同月同账户多 item → actual 账户级只计一次、限额分别展示', () async {
    final l = _Ledger();
    BudgetRow row(String itemId, AccountRow acct, int planned) => BudgetRow(
          budgetId: 'b1',
          month: '2026-08',
          itemId: itemId,
          accountId: acct.id,
          accountCategory: acct.category,
          accountName: acct.id,
          plannedCents: planned,
        );

    final doc = await _service(
      FakeStore(
        accountList: l.accounts,
        entryList: l.entries,
        budgetList: [
          row('i1', l.food, 50000),
          row('i2', l.food, 20000), // 同月同账户第二 item
        ],
      ),
      perf: null,
    ).generate(ReportPeriod.monthly(2026, 8));

    // budget_local_ds BudgetItemView 同构:每 item 一行,actual 取账户级
    // 大边(8 月 food = 30,000)——两行同为 30,000,**不相加翻倍**;
    // 限额各自展示(50,000 / 20,000)。
    final items = doc.budget!.items;
    expect(items, hasLength(2));
    expect(items[0].actualCents, 30000);
    expect(items[0].limitCents, 50000);
    expect(items[0].pct, 60.0);
    expect(items[0].overran, isFalse);
    expect(items[1].actualCents, 30000); // 不翻倍(旧缺陷=60,000)
    expect(items[1].limitCents, 20000);
    expect(items[1].pct, 150.0);
    expect(items[1].overran, isTrue);
  });

  test('预算执行:年报同月同账户多 item → (账户,月) 去重只计一份,limit 按 item 累加', () async {
    final l = _Ledger();
    BudgetRow row(String month, String itemId, AccountRow acct, int planned) =>
        BudgetRow(
          budgetId: 'b-$month-$itemId',
          month: month,
          itemId: itemId,
          accountId: acct.id,
          accountCategory: acct.category,
          accountName: acct.id,
          plannedCents: planned,
        );

    final doc = await _service(
      FakeStore(
        accountList: l.accounts,
        entryList: l.entries,
        budgetList: [
          row('2026-08', 'i1', l.food, 50000),
          row('2026-08', 'i2', l.food, 20000), // 同月同账户:actual 去重
          row('2026-09', 'i3', l.food, 10000), // 异月:正常并入
        ],
      ),
      perf: null,
    ).generate(ReportPeriod.yearly(2026));

    final items = doc.budget!.items;
    expect(items, hasLength(1)); // 年报按账户并入
    // actual = max(food,08)=30,000(仅一份)+ max(food,09)=0;
    // limit = 50,000+20,000+10,000(item 累加)。
    expect(items[0].actualCents, 30000);
    expect(items[0].limitCents, 80000);
    expect(items[0].pct, 37.5);
  });

  test('收支:一月月报 prior 回上年 12 月(跨年环比分支)', () async {
    final cash = _acct('cash', 1, 'savings');
    final income = _acct('income', 4, 'otherAsset');
    final expense = _acct('expense', 5, 'otherAsset');
    final entries = [
      ..._doubleEntry('p1', cash, income, DateTime(2025, 12, 20), 100000),
      ..._doubleEntry('p0', expense, cash, DateTime(2025, 12, 25), 40000),
      ..._doubleEntry('t1', cash, income, DateTime(2026, 1, 10), 200000),
      ..._doubleEntry('t2', expense, cash, DateTime(2026, 1, 15), 50000),
    ];

    final doc = await _service(
      FakeStore(accountList: [cash, income, expense], entryList: entries),
      perf: null,
    ).generate(ReportPeriod.monthly(2026, 1));

    // 1 月 expense 50,000;prior = 2025 年 12 月 expense 40,000
    // → 支出环比 +25.0%(视觉对齐批次:口径从结余换为支出)。
    final prior = doc.incomeStatement.priorComparison!;
    expect(prior.label, '环比上月支出');
    expect(prior.deltaPct, 25.0);
  });

  test('收支:年报 dailyAvg=全年支出/当年自然天数(定案口径)', () async {
    final l = _Ledger();
    final doc = await _service(
      FakeStore(accountList: l.accounts, entryList: l.entries),
      perf: null,
    ).generate(ReportPeriod.yearly(2026));

    // 2026 年支出 68,000 / 365 天 = 186(截断)。
    // 报告定案口径 = 日均支出/自然天数(视觉对齐批次起月/年统一)。
    expect(doc.incomeStatement.dailyAvgCents, 186);
  });

  test('现金流:income 科目误挂 savings 账类 → 现金谓词单点不炸勾稽', () async {
    // 异常数据回归:income 科目账户被误挂 savings 账类(T2 adapter 测试
    // 同款旧数据形态)。现金判定=type 1 且 savings 单点谓词,两侧一致
    // → 收入计入经营流入,勾稽通过(旧缺陷:分类器仅看 category,收入
    // 腿被当现金抵消 → netDelta≠cashDelta → StateError 炸穿整份报告)。
    final cash = _acct('cash', 1, 'savings', initial: 50000);
    final oddIncome = _acct('oddIncome', 4, 'savings'); // 误挂账类
    final entries = [
      ..._doubleEntry('t1', cash, oddIncome, DateTime(2026, 8, 5), 100000),
    ];

    final doc = await _service(
      FakeStore(accountList: [cash, oddIncome], entryList: entries),
      perf: null,
    ).generate(ReportPeriod.monthly(2026, 8));

    expect(doc.cashFlow.operating.inflowCents, 100000);
    expect(doc.cashFlow.netDeltaCents, 100000);
    expect(doc.overview.cashDeltaCents, 100000);
  });

  test('FR-7:假 basis(支出减半)替换 → 支出聚合走注入口径,其余章节逐位不变', () async {
    final l = _Ledger();
    BudgetRow row(String itemId, AccountRow acct, int planned) => BudgetRow(
          budgetId: 'b1',
          month: '2026-08',
          itemId: itemId,
          accountId: acct.id,
          accountCategory: acct.category,
          accountName: acct.id,
          plannedCents: planned,
        );
    final store = FakeStore(
      accountList: l.accounts,
      entryList: l.entries,
      budgetList: [
        row('i1', l.food, 50000),
        row('i2', l.transport, 8000),
      ],
    );
    const perf = PeriodPerformance(
      beginMvCents: 70000,
      endMvCents: 90000,
      netBuyCents: 80000,
      estimatedGainCents: -60000,
      twrPct: 25.0,
    );

    final def =
        await _service(store, perf: perf).generate(ReportPeriod.monthly(2026, 8));
    final faked = await _service(store, basis: const _HalvedExpenseBasis(), perf: perf)
        .generate(ReportPeriod.monthly(2026, 8));

    // (a) 支出聚合走注入 basis:默认 40,000 vs fake 20,000(手算:food
    // 30,000/2=15,000 + transport 10,000/2=5,000);构成逐项减半;
    // 结余/储蓄率随之(480,000 / 96.0)。
    expect(def.overview.expenseCents, 40000);
    expect(faked.overview.expenseCents, 20000);
    expect(
      [
        for (final c in faked.incomeStatement.expense)
          (c.category, c.amountCents),
      ],
      [('food', 15000), ('transport', 5000)],
    );
    expect(faked.overview.surplusCents, 480000);
    expect(faked.overview.savingsRate, 96.0);

    // (b) 其余章节(资产负债/现金流/预算/投资/排除项)结构与数值和
    // 默认 basis 运行逐位一致(签名树深比较)。
    expect(_bsSig(faked.balanceSheet), _bsSig(def.balanceSheet));
    expect(_cfSig(faked.cashFlow), _cfSig(def.cashFlow));
    expect(_budgetSig(faked.budget!), _budgetSig(def.budget!));
    expect(_investmentSig(faked.investment!), _investmentSig(def.investment!));
    expect(faked.excludedSections, def.excludedSections);

    // (c) 现金流勾稽不受 basis 替换影响(分类与余额同源 entries,不经
    // basis):勾稽标记 + 净变动 == cashDelta + 手算 375,000。
    expect(faked.cashFlow.reconciled, isTrue);
    expect(faked.cashFlow.netDeltaCents, faked.overview.cashDeltaCents);
    expect(faked.cashFlow.netDeltaCents, 375000);
  });

  // ---- budget actuals conformance(ADR-2 护栏:同 drift 种子对照
  // budget_local_ds 读时 actuals 口径;测试内 import data 层允许)----

  test('budget actuals conformance:同种子对照 budget_local_ds(max(Σd,Σc))', () async {
    final database = db.AppDatabase(NativeDatabase.memory());
    final accountsDs = AccountLocalDataSource(database);
    final txnsDs = TransactionLocalDataSource(
      database,
      BalanceLocalUpdater(database),
    );
    final budgetsDs = BudgetLocalDataSource(database);
    addTearDown(database.close);

    Future<Account> createAccount(
      String name,
      AccountType type,
      AccountCategory category,
    ) =>
        accountsDs.create(CreateAccountParams(
          name: name,
          accountType: type,
          category: category,
          currencyCode: 'CNY',
          initialBalanceCents: 0,
          ownership: Ownership.personal,
        ));

    final cash = await createAccount('现金', AccountType.asset, AccountCategory.savings);
    final food = await createAccount('餐饮', AccountType.expense, AccountCategory.otherAsset);
    final transport = await createAccount('交通', AccountType.expense, AccountCategory.otherAsset);

    await budgetsDs.createBudget(
      name: '八月预算',
      month: '2026-08',
      currencyCode: 'CNY',
      items: [
        (accountId: food.id, plannedAmountCents: 50000, notes: null),
        (accountId: transport.id, plannedAmountCents: 6000, notes: null),
      ],
    );

    // food:支出 30,000 + 退款 22,000(借现金/贷 food)→ max(30k, 22k) = 30k。
    await txnsDs.recordExpense(RecordExpenseParams(
      transactionDate: DateTime(2026, 8, 6),
      expenseAccountId: food.id,
      assetAccountId: cash.id,
      amountCents: 30000,
    ));
    await txnsDs.recordTransaction(RecordTransactionParams(
      transactionDate: DateTime(2026, 8, 20),
      entries: [
        TransactionEntry(accountId: cash.id, debitCents: 22000, creditCents: 0),
        TransactionEntry(accountId: food.id, debitCents: 0, creditCents: 22000),
      ],
    ));
    // transport:支出 5,000 + 冲回 9,000(借现金/贷 transport,贷方大边)
    // → max(5k, 9k) = 9k(大边规则,借方小不冲抵)。
    await txnsDs.recordExpense(RecordExpenseParams(
      transactionDate: DateTime(2026, 8, 7),
      expenseAccountId: transport.id,
      assetAccountId: cash.id,
      amountCents: 5000,
    ));
    await txnsDs.recordTransaction(RecordTransactionParams(
      transactionDate: DateTime(2026, 8, 21),
      entries: [
        TransactionEntry(accountId: cash.id, debitCents: 9000, creditCents: 0),
        TransactionEntry(accountId: transport.id, debitCents: 0, creditCents: 9000),
      ],
    ));
    // 期外分录(7 月)不计入 8 月预算窗口。
    await txnsDs.recordExpense(RecordExpenseParams(
      transactionDate: DateTime(2026, 7, 31),
      expenseAccountId: food.id,
      assetAccountId: cash.id,
      amountCents: 9999,
    ));

    // 对照侧:budget_local_ds 读时 actuals(budget 页/服务端口径)。
    final view = await budgetsDs.getBudgetByMonth('2026-08');
    final theirs = {
      for (final i in view.items) i.accountName!: i.actualAmountCents,
    };

    // 报告侧:真 adapter 行喂入服务(fake store 仅做传递)。
    final adapter = ReportLedgerStoreImpl(database);
    final doc = await ReportAssemblyService(
      FakeStore(
        accountList: await adapter.accounts(),
        entryList: await adapter.entries(),
        budgetList: await adapter.budgetRows(),
      ),
      const CashExpenseBasis(),
      _repoWith(null),
      const MdaEngine(),
    ).generate(ReportPeriod.monthly(2026, 8));
    final mine = {
      for (final i in doc.budget!.items) i.name: i.actualCents,
    };

    expect(mine, theirs);
    expect(mine, {'餐饮': 30000, '交通': 9000}); // 手算字面量(独立 oracle)
  });

  // ---- T2(F44 R16 sprint-1)追加:MD&A supplement 接线 → doc.mda ----
  //
  // fixture(_Ledger + 07-08 transport 4,000):
  //   8 月:income 500,000 / expense 40,000(food 30,000 + transport 10,000);
  //   7 月(prior):expense 32,000(food 28,000 + transport 4,000);
  //   现金回放:start 1,276,000 / end 1,651,000。

  test('MD&A:supplement 全链 → doc.mda 随快照生成(R4/H1/H2 warn + R5×2 info 手算)', () async {
    final l = _Ledger();
    // prior 期(7 月)transport 4,000 → H2 环比基准(10,000 vs 4,000)。
    final entries = [
      ..._doubleEntry('t0', l.transport, l.cash, DateTime(2026, 7, 8), 4000),
      ...l.entries,
    ];
    final doc = await _service(
      FakeStore(
        accountList: l.accounts,
        entryList: entries,
        // 闲置订阅:期内应扣 08-10,从未记账,nextDate 09-20 超出 7 天
        // grace → R4 报(月度等价 ¥25.00)。
        templateList: [
          expenseTemplate(
            id: 'tpl-1',
            name: '闲置会员',
            amountCents: 2500,
            nextDate: DateTime(2026, 9, 20),
            expectedDates: [DateTime(2026, 8, 10)],
          ),
        ],
        // R5 候选:总支出 40,000 / 31 天 → 日均 ¥129.03,×3 = ¥387.10;
        // 20% = ¥8,000。t5 ¥300.00(75%)与 t6 ¥100.00(25%)均过双门槛;
        // 期外/小额不喂(fake 契约:测试自行构造期内候选)。
        transactionList: [
          txn('t5', DateTime(2026, 8, 6), '食品大采购', 30000),
          txn('t6', DateTime(2026, 8, 9), '通勤', 10000),
        ],
      ),
      perf: null,
    ).generate(ReportPeriod.monthly(2026, 8));

    // ADR-6:mda 恒非空(健康态也是章节);severity 排序 + 同级规则表序。
    final mda = doc.mda!;
    expect(mda.riskCount, 0);
    expect(mda.warnCount, 3);
    expect(mda.infoCount, 2);
    expect(mda.findings.map((f) => f.ruleId), ['R4', 'H1', 'H2', 'R5', 'R5']);
    expect(mda.findings.take(3).map((f) => f.severity),
        everyElement(MdaSeverity.warn));
    expect(mda.findings.skip(3).map((f) => f.severity),
        everyElement(MdaSeverity.info));

    // R4(手算):月度等价 = ¥25.00;疑问式文案 + 跳订阅中心。
    final r4 = mda.findings[0];
    expect(r4.conclusion, contains('闲置会员'));
    expect(r4.conclusion, contains('¥25.00'));
    expect(r4.actionLink, '/accounts/subscriptions');

    // H1(手算):餐饮 30,000 / 40,000 = 75.0% ≥ 40%。
    final h1 = mda.findings[1];
    expect(h1.conclusion, contains('「餐饮」'));
    expect(h1.conclusion, contains('75.0%'));

    // H2(手算,priorExpense=上一期构成 oracle):交通 10,000 vs 4,000
    // = +150.0%,增加 ¥60.00 占 15.0%。
    final h2 = mda.findings[2];
    expect(h2.conclusion, contains('「交通」'));
    expect(h2.conclusion, contains('+150.0%'));
    expect(h2.conclusion, contains('¥60.00'));
    expect(h2.conclusion, contains('15.0%'));

    // R5×2(手算):占比门槛 75.0% / 25.0%;文案带年付语境句。
    expect(mda.findings[3].conclusion, contains('食品大采购'));
    expect(mda.findings[3].conclusion, contains('¥300.00'));
    expect(mda.findings[3].conclusion, contains('75.0%'));
    expect(mda.findings[4].conclusion, contains('¥100.00'));
    expect(mda.findings[4].conclusion, contains('25.0%'));
    expect(mda.findings[4].conclusion, contains('年付'));
  });

  test('MD&A:trailing3m = period.start 前三个完整月支出(R6 月均÷3 oracle)', () async {
    // 现金 60,000;支出 5/6/7 月各 10,000(trailing3m=30,000,月均 10,000)
    // + 8 月 5,000 → cashEnd = 25,000 → runway 2.5 个月(1≤2.5<3 → warn)。
    final cash = _acct('cash', 1, 'savings', initial: 60000);
    final food = _acct('food', 5, 'otherAsset');
    final entries = [
      ..._doubleEntry('m1', food, cash, DateTime(2026, 5, 15), 10000),
      ..._doubleEntry('m2', food, cash, DateTime(2026, 6, 15), 10000),
      ..._doubleEntry('m3', food, cash, DateTime(2026, 7, 15), 10000),
      ..._doubleEntry('a1', food, cash, DateTime(2026, 8, 5), 5000),
    ];
    final doc = await _service(
      FakeStore(accountList: [cash, food], entryList: entries),
      perf: null,
    ).generate(ReportPeriod.monthly(2026, 8));

    // 8 月不计入 trailing3m(只取 5/6/7 月);月均 = 30,000÷3 = ¥100.00;
    // 25,000 ÷ 10,000 = 2.5 个月。H1(food 100%)另计 warn。
    final mda = doc.mda!;
    final r6 = mda.findings.firstWhere((f) => f.ruleId == 'R6');
    expect(r6.severity, MdaSeverity.warn);
    expect(r6.conclusion, contains('2.5 个月'));
    expect(r6.conclusion, contains('¥250.00'));
    expect(r6.conclusion, contains('¥100.00'));
    // T3 评审 round 1:健康摘要 runway 同口径随快照(cashEnd 25,000 ÷
    // 月均 10,000 = 2.5)。
    expect(mda.healthyRunwayMonths, 2.5);
  });

  test('MD&A:2 月报 trailing3m 跨年回卷(2025-11/12 + 2026-01 手算 oracle)', () async {
    // monthly(2026,2):循环首个回卷月 = 2026-01,再 1→0 回卷跨年取
    // 2025-12、2025-11;2025-10(期窗外沿)与 2026-02(报告期)均不计。
    // 现金 167,000;支出:10-31 40,000(诱饵)/ 11-10 11,000 / 12-10
    // 22,000 / 01-10 33,000 / 02-05 6,000(期内)。
    final cash = _acct('cash', 1, 'savings', initial: 167000);
    final food = _acct('food', 5, 'otherAsset');
    final entries = [
      ..._doubleEntry('d0', food, cash, DateTime(2025, 10, 31), 40000),
      ..._doubleEntry('n1', food, cash, DateTime(2025, 11, 10), 11000),
      ..._doubleEntry('n2', food, cash, DateTime(2025, 12, 10), 22000),
      ..._doubleEntry('j1', food, cash, DateTime(2026, 1, 10), 33000),
      ..._doubleEntry('f1', food, cash, DateTime(2026, 2, 5), 6000),
    ];
    final doc = await _service(
      FakeStore(accountList: [cash, food], entryList: entries),
      perf: null,
    ).generate(ReportPeriod.monthly(2026, 2));

    // trailing3m = 11,000+22,000+33,000 = 66,000 → 月均 ¥220.00;
    // cashEnd = 167,000−106,000−6,000 = 55,000(¥550.00)→ 2.5 个月 warn。
    // (诱饵若误入:月均 106,000÷3 ≈ ¥353.33 → 1.6 个月,oracle 区分。)
    final mda = doc.mda!;
    final r6 = mda.findings.firstWhere((f) => f.ruleId == 'R6');
    expect(r6.severity, MdaSeverity.warn);
    expect(r6.conclusion, contains('2.5 个月'));
    expect(r6.conclusion, contains('¥550.00'));
    expect(r6.conclusion, contains('¥220.00'));
  });

  test('MD&A:年报 trailing3m 跨年(2025-10..12);健康输入 → mda 恒非空零发现', () async {
    // 年报 2026:trailing3m = 2025-10/11/12(跨年回看,不含 2026-01)。
    final cash = _acct('cash', 1, 'savings', initial: 60000);
    final food = _acct('food', 5, 'otherAsset');
    final entries = [
      ..._doubleEntry('q1', food, cash, DateTime(2025, 9, 30), 7000), // 期外
      ..._doubleEntry('q2', food, cash, DateTime(2025, 10, 15), 10000),
      ..._doubleEntry('q3', food, cash, DateTime(2025, 11, 15), 10000),
      ..._doubleEntry('q4', food, cash, DateTime(2025, 12, 15), 10000),
    ];
    final doc = await _service(
      FakeStore(accountList: [cash, food], entryList: entries),
      perf: null,
    ).generate(ReportPeriod.yearly(2026));

    // trailing3m = 30,000(10-12 月;9 月 7,000 不计)→ 月均 ¥100.00;
    // cashEnd = 60,000−37,000 = 23,000 → 2.3 个月 warn。2026 年内无支出
    // → H1 无构成、R1 收入 0、R5 总支出 0 → 仅 R6。
    final mda = doc.mda!;
    expect(mda.findings.map((f) => f.ruleId), ['R6']);
    expect(mda.findings.single.conclusion, contains('2.3 个月'));

    // 健康输入(空账本):mda 仍非空,零发现(ADR-6 健康态也是章节)。
    final healthy = await _service(FakeStore(), perf: null)
        .generate(ReportPeriod.monthly(2026, 8));
    expect(healthy.mda, isNotNull);
    expect(healthy.mda!.findings, isEmpty);
    expect(
      healthy.mda!.riskCount +
          healthy.mda!.warnCount +
          healthy.mda!.infoCount,
      0,
    );
  });
}
