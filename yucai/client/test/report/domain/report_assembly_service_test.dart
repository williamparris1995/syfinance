// T4(F43 R16 sprint-1)—— ReportAssemblyService 汇编编排(fake store +
// mock holding repo,oracle 全手算):
//
// - 四阶段回调顺序(FR-8 进度契约:loadingLedger→replaying→assembling→
//   performance);
// - 六章节快照逐数值 oracle(总览/资产负债/收支+prior/现金流/预算/投资);
// - 自适应隐藏(无预算/无持仓)+ excludedSections 附注(FR-3);
// - 外币折 CNY 两级汇率(历史→现值→缺失跳过+注记);
// - budget actuals conformance(同 drift 种子对照 budget_local_ds)。
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
import 'package:yucai_client/report/domain/report_assembly_service.dart';
import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/domain/report_ledger_store.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

// ---- fakes ----

/// 内存 port 替身:行数据直填;汇率按 (code, 时点) 回调查表。
class FakeStore implements ReportLedgerStore {
  FakeStore({
    this.accountList = const [],
    this.entryList = const [],
    this.budgetList = const [],
    this.rateFor,
  });

  final List<AccountRow> accountList;
  final List<LedgerEntryRow> entryList;
  final List<BudgetRow> budgetList;
  final RateQuote? Function(String code, DateTime on)? rateFor;

  @override
  Future<List<AccountRow>> accounts() async => accountList;

  @override
  Future<List<LedgerEntryRow>> entries() async => entryList;

  @override
  Future<List<BudgetRow>> budgetRows() async => budgetList;

  @override
  Future<RateQuote> rateToCny(String currencyCode, DateTime on) async =>
      rateFor?.call(currencyCode, on) ?? const RateQuote();
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
}) =>
    AccountRow(
      id: id,
      type: type,
      category: category,
      initialBalanceCents: initial,
      currencyCode: currency,
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
    ReportAssemblyService(store, basis, _repoWith(perf));

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
        food = _acct('food', 5, 'otherAsset'),
        transport = _acct('transport', 5, 'otherAsset'),
        // income/expense 科目账户 category 无意义,真实写路径恒 otherAsset
        // (category_bloc/demo_seed 同款)——不得用 savings,否则被现金
        // 口径误判(classifier _isCash 仅看 category)。
        salary = _acct('salary', 4, 'otherAsset');

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

  test('收支:income/expense 构成+日均(活跃日口径)+月报环比上月', () async {
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

    expect(stmt.expense, hasLength(2)); // 金额降序
    expect(stmt.expense.first.category, 'food');
    expect(stmt.expense.first.amountCents, 30000);
    expect(stmt.expense.first.pct, 75.0);
    expect(stmt.expense[1].category, 'transport');
    expect(stmt.expense[1].amountCents, 10000);
    expect(stmt.expense[1].pct, 25.0);

    // 活跃日 = 有 income/expense 分录的日(08-02/06/09;08-20 投资与
    // 08-25 还款不涉收支科目):460,000 ~/ 3 = 153,333(截断,summary 同款)。
    expect(stmt.dailyAvgCents, 153333);

    // 环比上月:7 月 surplus = 300,000−28,000 = 272,000;
    // (460,000−272,000)/272,000 = 69.1%。
    expect(stmt.priorComparison, isNotNull);
    expect(stmt.priorComparison!.label, '较 2026 年 7 月');
    expect(stmt.priorComparison!.deltaPct, 69.1);
  });

  test('收支:年报同比上年;对比期无数据 → priorComparison null', () async {
    final l = _Ledger();
    // 2025 年对比期数据:06-15 收入 400,000(借 cash/贷 salary)。
    final entries = [
      ..._doubleEntry('p1', l.cash, l.salary, DateTime(2025, 6, 15), 400000),
      ...l.entries,
    ];

    final doc = await _service(
      FakeStore(accountList: l.accounts, entryList: entries),
      perf: null,
    ).generate(ReportPeriod.yearly(2026));
    // 2026 年度:income 800,000 / expense 68,000 → surplus 732,000;
    // 同比 2025 surplus 400,000 → (732,000−400,000)/400,000 = 83.0%。
    final stmt = doc.incomeStatement;
    expect(stmt.priorComparison, isNotNull);
    expect(stmt.priorComparison!.label, '较 2025 年度');
    expect(stmt.priorComparison!.deltaPct, 83.0);

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

    // 收支:prior 环比 69.1%;现金流净 375,000。
    expect(doc.incomeStatement.priorComparison!.deltaPct, 69.1);
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
      ..._doubleEntry('t1', cash, income, DateTime(2026, 1, 10), 200000),
      ..._doubleEntry('t2', expense, cash, DateTime(2026, 1, 15), 50000),
    ];

    final doc = await _service(
      FakeStore(accountList: [cash, income, expense], entryList: entries),
      perf: null,
    ).generate(ReportPeriod.monthly(2026, 1));

    // 1 月 surplus = 150,000;prior=2025 年 12 月 surplus = 100,000
    // → +50.0%。
    final prior = doc.incomeStatement.priorComparison!;
    expect(prior.label, '较 2025 年 12 月');
    expect(prior.deltaPct, 50.0);
  });

  test('收支:年报 dailyAvg=全年支出/当年自然天数(定案口径)', () async {
    final l = _Ledger();
    final doc = await _service(
      FakeStore(accountList: l.accounts, entryList: l.entries),
      perf: null,
    ).generate(ReportPeriod.yearly(2026));

    // 2026 年支出 68,000 / 365 天 = 186(截断)。
    // 非 TransactionSummary 月 scope 规则(结余/活跃日):报告年报口径
    // 定案为日均支出/自然天数,差异理由见服务注释。
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
    ).generate(ReportPeriod.monthly(2026, 8));
    final mine = {
      for (final i in doc.budget!.items) i.name: i.actualCents,
    };

    expect(mine, theirs);
    expect(mine, {'餐饮': 30000, '交通': 9000}); // 手算字面量(独立 oracle)
  });
}
