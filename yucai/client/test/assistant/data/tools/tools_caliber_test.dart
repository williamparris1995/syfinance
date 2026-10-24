// F64-T3 口径逐分断言(NFR-1):参数化全工具 —— 同一测试库种子 →
// 工具输出 vs 同库直查(drift 原始行独立重算)逐分相等。
// F65-T1 扩成八工具参数化(F64 三件 + 新五件)。
//
// 直查口径(Never import 工具实现的算法,测试内独立重算):
// - networth:assets = Σ type1 账户余额 + 持仓增益层(Σ round(qty×(现价
//   −成本)),现价>0 才计);liabilities = Σ borrowedIn 债(totalPrincipal
//   − Σ期次 paidCents)(NetWorthLocalDataSource 同算法);
// - accounts:分组小计 = Σ 可见户(type≠isSystem)余额;卡占用 = Σ
//   unpaid 且 paymentDate > today(UTC 日界)期次本金(F50/F58 口径);
// - debts:剩余 = Σ unpaid 期次本金(期表口径);
// - holdings:成本 = Σ round(qty×avgCost);市值 = round(qty×现价>0?现价:
//   avgCost);浮盈 = 现价口径市值−成本(无价 0)(面板 HoldingSummary
//   同式);
// - transactions:income = Σ type4 分录 credit;expense = Σ type5 分录
//   debit(TransactionSummary 同式);direction=io 按科目单边命中;
// - budgets:actual = 账户级月窗内 max(Σdebit,Σcredit)(读时 actuals
//   大边口径,budget_local_ds 同算法);
// - goals:savings current = 挂接账户行 currentBalance;无挂接 = 存储值;
// - performance_range:F43 既有区间测试同款手算 oracle(FR-6 成交回放,
//   holding_perf_range_passthrough_test 取数方式)。
// 夹具期次 interest=0 → networth 负债与 debts 剩余同数,可作跨工具链校验
// (利息口径差为已知接受差异,见 _toEntity 注释)。
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/data/account_remote_ds.dart';
import 'package:yucai_client/account/data/account_repository_impl.dart';
import 'package:yucai_client/assistant/data/tools/accounts_list_tool.dart';
import 'package:yucai_client/assistant/data/tools/budgets_status_tool.dart';
import 'package:yucai_client/assistant/data/tools/debts_list_tool.dart';
import 'package:yucai_client/assistant/data/tools/goals_list_tool.dart';
import 'package:yucai_client/assistant/data/tools/holdings_list_tool.dart';
import 'package:yucai_client/assistant/data/tools/networth_snapshot_tool.dart';
import 'package:yucai_client/assistant/data/tools/performance_range_tool.dart';
import 'package:yucai_client/assistant/data/tools/transactions_search_tool.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/assistant/domain/networth_port.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/assistant/domain/base_currency_port.dart';
import 'package:yucai_client/budget/data/budget_local_ds.dart';
import 'package:yucai_client/budget/data/budget_remote_ds.dart';
import 'package:yucai_client/budget/data/budget_repository_impl.dart';
import 'package:yucai_client/debt/data/debt_local_ds.dart';
import 'package:yucai_client/debt/data/debt_remote_ds.dart';
import 'package:yucai_client/debt/data/debt_repository_impl.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/goal/data/goal_local_ds.dart';
import 'package:yucai_client/goal/data/goal_remote_ds.dart';
import 'package:yucai_client/goal/data/goal_repository_impl.dart';
import 'package:yucai_client/holding/data/goal_view_ds.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart'
    show HoldingLocalDataSource, NetWorthLocalDataSource;
import 'package:yucai_client/holding/data/holding_remote_ds.dart';
import 'package:yucai_client/holding/data/holding_repository_impl.dart';
import 'package:yucai_client/holding/domain/entities/net_worth_entity.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/data/transaction_remote_ds.dart';
import 'package:yucai_client/transaction/data/transaction_repository_impl.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

class _MockAccountRemote extends Mock implements AccountRemoteDataSource {}

class _MockDebtRemote extends Mock implements DebtRemoteDataSource {}

class _MockHoldingRemote extends Mock implements HoldingRemoteDataSource {}

class _MockGoalViewDs extends Mock implements GoalViewDataSource {}

class _MockTxnRemote extends Mock implements TransactionRemoteDataSource {}

class _MockBudgetRemote extends Mock implements BudgetRemoteDataSource {}

class _MockGoalRemote extends Mock implements GoalRemoteDataSource {}

class _FakeBaseCurrency implements BaseCurrencySource {
  @override
  Future<String> getBaseCurrency() async => 'CNY';
}

/// DI 组合根同款适配:NetWorthSnapshotSource port → NetWorthLocalDataSource
/// (assistant 生产代码不 import holding/data;组合根/测试负责接线)。
class _NetWorthSourceAdapter implements NetWorthSnapshotSource {
  _NetWorthSourceAdapter(this._ds);
  final NetWorthLocalDataSource _ds;

  @override
  Future<NetWorthView> fetch({required String baseCurrency}) =>
      _ds.getNetWorth(baseCurrency: baseCurrency);
}

final _fixedNow = DateTime.utc(2026, 10, 23, 4);

void main() {
  late db.AppDatabase database;
  late NetWorthSnapshotTool networthTool;
  late AccountsListTool accountsTool;
  late DebtsListTool debtsTool;
  late HoldingsListTool holdingsTool;
  late TransactionsSearchTool transactionsTool;
  late BudgetsStatusTool budgetsTool;
  late GoalsListTool goalsTool;
  late PerformanceRangeTool performanceTool;

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    final tracker = SessionModeTracker()..isGuest = true;
    final txnsDs =
        TransactionLocalDataSource(database, BalanceLocalUpdater(database));
    final holdingDs = HoldingLocalDataSource(database, txnsDs);
    final accountsRepo = AccountRepositoryImpl(
      _MockAccountRemote(),
      AccountLocalDataSource(database),
      tracker,
    );
    final debtsRepo = DebtRepositoryImpl(
      _MockDebtRemote(),
      DebtLocalDataSource(database, txnsDs),
      tracker,
    );
    final holdingsRepo = HoldingRepositoryImpl(
      _MockHoldingRemote(),
      holdingDs,
      tracker,
      _MockGoalViewDs(),
    );
    final txnsRepo = TransactionRepositoryImpl(_MockTxnRemote(), txnsDs, tracker);
    final budgetsRepo = BudgetRepositoryImpl(
        _MockBudgetRemote(), BudgetLocalDataSource(database), tracker);
    final goalsRepo = GoalRepositoryImpl(
      _MockGoalRemote(),
      GoalLocalDataSource(database, holdingDs),
      tracker,
    );
    networthTool = NetWorthSnapshotTool(
        _NetWorthSourceAdapter(NetWorthLocalDataSource(database)),
        _FakeBaseCurrency());
    accountsTool = AccountsListTool(accountsRepo, debtsRepo, () => _fixedNow);
    debtsTool = DebtsListTool(debtsRepo, () => _fixedNow);
    holdingsTool = HoldingsListTool(holdingsRepo);
    transactionsTool = TransactionsSearchTool(txnsRepo, accountsRepo);
    budgetsTool = BudgetsStatusTool(budgetsRepo);
    goalsTool = GoalsListTool(goalsRepo);
    performanceTool = PerformanceRangeTool(holdingsRepo, () => _fixedNow);

    // ── 共享种子(账户)──
    Future<void> seedAccount(String id, String name,
        {required int type,
        required int category,
        required int balance,
        int creditLimitCents = 0,
        bool isSystem = false}) async {
      await database.accountDao.insertAccount(db.AccountsCompanion.insert(
        id: id,
        name: name,
        accountType: type,
        category: category,
        currencyCode: 'CNY',
        initialBalanceCents: balance,
        currentBalanceCents: balance,
        ownership: 1,
        icon: '',
        color: '',
        chartCode: '',
        isSystem: isSystem,
        sortOrder: 0,
        institution: '',
        cardNumberTail: '',
        notes: '',
        goldProductType: '',
        status: 1,
        version: 1,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
        creditLimitCents: Value(creditLimitCents),
      ));
    }

    await seedAccount('acc-cash', '现金',
        type: 1, category: 1, balance: 1234567);
    await seedAccount('acc-card', '招行信用卡',
        type: 2, category: 2, balance: 500500, creditLimitCents: 5000000);
    // 载体户:净资产/负债计入,accounts_list 出局。
    await seedAccount('acc-carrier', '平安卡贷载体',
        type: 2, category: 6, balance: 0, isSystem: true);
    // F65 五工具夹具增量:投资户/储蓄户/分类账户(category 8 = otherAsset)。
    await seedAccount('acc-inv', '投资账户',
        type: 1, category: 3, balance: 1000000);
    await seedAccount('acc-save2', '储蓄二号', type: 1, category: 1, balance: 0);
    await seedAccount('acc-food', '餐饮', type: 5, category: 8, balance: 0);
    await seedAccount('acc-salary', '工资', type: 4, category: 8, balance: 0);

    // ── 债务种子(F64 既有,原样)──
    Future<void> seedDebt(String id,
            {required int total,
            required int debtType,
            required String subtype,
            String? collectionAccountId}) =>
        database.debtDao.insertDebt(db.DebtsCompanion.insert(
          id: id,
          accountId: 'acc-carrier',
          counterparty: 'cp-$id',
          interestRate: 0.5,
          amortizationMethod: 1,
          startDate: DateTime.utc(2026, 8, 1),
          dueDate: DateTime.utc(2027, 8, 1),
          totalPrincipalCents: total,
          debtType: debtType,
          subtype: subtype,
          contact: '',
          contractRef: '',
          collectionAccountId: Value(collectionAccountId),
          version: 1,
          createdAt: DateTime.utc(2026, 8, 1),
          updatedAt: DateTime.utc(2026, 8, 1),
        ));

    Future<void> seedEntry(String debtId, String id, DateTime date,
            int principal, {bool paid = false}) =>
        database.debtDao.insertScheduleEntry(
            db.PaymentScheduleEntriesCompanion.insert(
          id: id,
          debtId: debtId,
          paymentDate: date,
          principalCents: principal,
          interestCents: 0,
          totalCents: principal,
          paidCents: paid ? principal : 0,
          paid: paid,
        ));

    // d1 挂卡卡贷:total = Σ期次本金(460000)。
    await seedDebt('d1',
        total: 460000,
        debtType: 1,
        subtype: DebtSubtypes.cardLoan,
        collectionAccountId: 'acc-card');
    await seedEntry('d1', 'e1', DateTime.utc(2026, 8, 1), 100000, paid: true);
    await seedEntry('d1', 'e2', DateTime.utc(2026, 9, 1), 110000);
    await seedEntry('d1', 'e3', DateTime.utc(2026, 11, 1), 120000);
    await seedEntry('d1', 'e4', DateTime.utc(2026, 12, 1), 130000);

    // d2 已结清普通债;total = 期次合计(净贡献 0)。
    await seedDebt('d2',
        total: 200000, debtType: 1, subtype: DebtSubtypes.creditLoan);
    await seedEntry('d2', 'e5', DateTime.utc(2026, 8, 1), 200000, paid: true);

    // d3 借出:净资产与 debts_list 均不计。
    await seedDebt('d3',
        total: 50000, debtType: 2, subtype: DebtSubtypes.creditLoan);
    await seedEntry('d3', 'e6', DateTime.utc(2026, 11, 1), 50000);

    // ── 证券 + 持仓 + 台账(holdings_list / performance_range)──
    // FR-6 oracle 成交(F43 区间测试同款):07-01 买 10@4,277(窗前)、
    // 08-02 买 10@4,777、08-15 卖 10@4,577 → [08-01, 08-31] 窗:
    // 期初 42,770 / 期末 45,770 / 净买入 2,000 / 估算收益 1,000。
    // h2(sec2,无台账)只喂 holdings_list 口径;台账回放 qty@start=0 →
    // 不渗入 performance_range 窗口。
    await database.referenceDao.insertSecurity(db.SecuritiesCompanion.insert(
      id: 'sec1',
      symbol: '600519',
      name: '贵州茅台',
      securityType: 'stock',
      exchange: '',
      currencyCode: 'CNY',
      currentPriceCents: 5000,
      createdAt: DateTime.now().toUtc(),
    ));
    await database.referenceDao.insertSecurity(db.SecuritiesCompanion.insert(
      id: 'sec2',
      symbol: '510300',
      name: '沪深300ETF',
      securityType: 'fund',
      exchange: '',
      currencyCode: 'CNY',
      currentPriceCents: 250,
      createdAt: DateTime.now().toUtc(),
    ));
    Future<void> seedHolding(
            String id, String secId, double qty, int avgCost) =>
        database.holdingDao.insertHolding(db.HoldingsCompanion.insert(
          id: id,
          accountId: 'acc-inv',
          securityId: secId,
          quantity: qty,
          avgCostCents: avgCost,
          version: 1,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ));
    await seedHolding('h1', 'sec1', 10, 4277);
    await seedHolding('h2', 'sec2', 100, 300);

    Future<void> seedTrade(String id, int tradeType, DateTime date,
            double qty, int price, int amount) =>
        database.holdingDao.insertHoldingTransaction(
            db.HoldingTransactionsCompanion.insert(
          id: id,
          accountId: 'acc-inv',
          securityId: 'sec1',
          tradeType: tradeType,
          quantity: qty,
          priceCents: price,
          amountCents: amount,
          feeCents: 0,
          realizedPnlCents: 0,
          tradeDate: date,
          notes: '',
          createdAt: DateTime.now().toUtc(),
        ));
    await seedTrade('ht1', 1, DateTime.utc(2026, 7, 1), 10, 4277, 42770);
    await seedTrade('ht2', 1, DateTime.utc(2026, 8, 2), 10, 4777, 47770);
    await seedTrade('ht3', 2, DateTime.utc(2026, 8, 15), 10, 4577, 45770);

    // ── 交易种子(transactions_search;真实写入路径)──
    // 9 月:两笔餐饮支出(5,000 + 12,000)+ 工资 800,000 + 转账 50,000;
    // 10 月:餐饮支出 3,000。金额与月份喂 budgets 口径(actuals 大边)。
    await txnsDs.recordExpense(RecordExpenseParams(
      transactionDate: DateTime(2026, 9, 5),
      expenseAccountId: 'acc-food',
      assetAccountId: 'acc-cash',
      amountCents: 5000,
      description: '九月外卖',
    ));
    await txnsDs.recordExpense(RecordExpenseParams(
      transactionDate: DateTime(2026, 9, 18),
      expenseAccountId: 'acc-food',
      assetAccountId: 'acc-cash',
      amountCents: 12000,
      description: '九月购物',
    ));
    await txnsDs.recordIncome(RecordIncomeParams(
      transactionDate: DateTime(2026, 9, 20),
      assetAccountId: 'acc-cash',
      incomeAccountId: 'acc-salary',
      amountCents: 800000,
      description: '九月工资',
    ));
    await txnsDs.recordTransfer(RecordTransferParams(
      transactionDate: DateTime(2026, 9, 25),
      fromAccountId: 'acc-cash',
      toAccountId: 'acc-save2',
      amountCents: 50000,
      description: '搬家',
    ));
    await txnsDs.recordExpense(RecordExpenseParams(
      transactionDate: DateTime(2026, 10, 3),
      expenseAccountId: 'acc-food',
      assetAccountId: 'acc-cash',
      amountCents: 3000,
      description: '十月外卖',
    ));

    // ── 预算种子(budgets_status;item 挂 acc-food 分类账户)──
    Future<void> seedBudget(String id, String name, String month,
            int totalAmount) =>
        database.budgetDao.insertBudget(db.BudgetsCompanion.insert(
          id: id,
          name: name,
          month: month,
          totalAmountCents: totalAmount,
          currencyCode: 'CNY',
          isActive: true,
          version: 1,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ));
    await seedBudget('b1', '九月预算', '2026-09', 30000);
    await database.budgetDao.insertItem(db.BudgetItemsCompanion.insert(
      id: 'bi1',
      budgetId: 'b1',
      accountId: 'acc-food',
      plannedAmountCents: 30000,
      actualAmountCents: 0,
      notes: '',
    ));
    await seedBudget('b2', '十月预算', '2026-10', 5000);
    await database.budgetDao.insertItem(db.BudgetItemsCompanion.insert(
      id: 'bi2',
      budgetId: 'b2',
      accountId: 'acc-food',
      plannedAmountCents: 5000,
      actualAmountCents: 0,
      notes: '',
    ));

    // ── 目标种子(goals_list)──
    // g1 savings 挂 acc-cash → 读时 actuals = 账户余额(测试内直查同行);
    // g2 无挂接手工目标 → 存储值直读。
    await database.goalDao.insertGoal(db.GoalsCompanion.insert(
      id: 'g1',
      name: '应急金',
      goalType: 1,
      targetAmountCents: 2000000,
      currentAmountCents: 0,
      currencyCode: 'CNY',
      notes: '',
      isCompleted: false,
      version: 1,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    ));
    await database.goalDao.insertAccountLink(
        db.GoalAccountLinksCompanion.insert(goalId: 'g1', linkedId: 'acc-cash'));
    await database.goalDao.insertGoal(db.GoalsCompanion.insert(
      id: 'g2',
      name: '旅行金',
      goalType: 1,
      targetAmountCents: 100000,
      currentAmountCents: 40000,
      currencyCode: 'CNY',
      notes: '',
      isCompleted: false,
      version: 1,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    ));
  });

  tearDown(() => database.close());

  test(
      'parameterized: every tool cent-exact vs same-db direct recomputation',
      () async {
    // ── 同库直查(drift 原始行,独立重算)──
    final accountRows = await database.accountDao.getAllAccounts();
    final debtRows = await database.debtDao.watchAllDebts().first;

    // 净资产直查 = Σ type1 余额 + 持仓增益层(Σ round(qty×(现价−成本)),
    // 现价>0 才计;NetWorthLocalDataSource.getNetWorth 同算法——F65 夹具
    // 增持持仓后必须带上该层)。
    final directSecurityPrices = {
      for (final s in await database.referenceDao.getAllSecurities())
        s.id: s.currentPriceCents
    };
    final directHoldingsGain = (await database.holdingDao.watchAllHoldings()
            .first)
        .where((h) => (directSecurityPrices[h.securityId] ?? 0) > 0)
        .fold(
            0,
            (s, h) =>
                s +
                (h.quantity *
                        (directSecurityPrices[h.securityId]! - h.avgCostCents))
                    .round());
    final directAssets = accountRows
            .where((r) => r.accountType == 1)
            .fold(0, (s, r) => s + r.currentBalanceCents) +
        directHoldingsGain;
    var directLiabilities = 0;
    final directDebtRemainingById = <String, int>{};
    for (final d in debtRows) {
      final schedule = await database.debtDao.getScheduleByDebt(d.id);
      if (d.debtType == 1) {
        final paid = schedule.fold(0, (s, e) => s + e.paidCents);
        directLiabilities += d.totalPrincipalCents - paid;
        directDebtRemainingById[d.id] =
            schedule.where((e) => !e.paid).fold(0, (s, e) => s + e.principalCents);
      }
    }
    final todayStart = DateTime.utc(2026, 10, 23);
    final directOccupation = (await database.debtDao.getScheduleByDebt('d1'))
        .where((e) => !e.paid && e.paymentDate.isAfter(todayStart))
        .fold(0, (s, e) => s + e.principalCents);

    // ── networth_snapshot ──
    final nw = (await networthTool.execute(const {}) as ToolData).json;
    expect(nw['totalAssetsCents'], directAssets, reason: 'networth assets');
    expect(nw['totalLiabilitiesCents'], directLiabilities,
        reason: 'networth liabilities');
    expect(nw['netWorthCents'], directAssets - directLiabilities,
        reason: 'networth = assets - liabilities');
    expect(nw['currency'], 'CNY');

    // ── accounts_list ──
    final al = (await accountsTool.execute(const {}) as ToolData).json;
    final visibleRows = accountRows.where((r) => !r.isSystem).toList();
    expect(al['totalCount'], visibleRows.length,
        reason: '载体户不计 total_count');
    for (final type in [1, 2]) {
      final direct = visibleRows
          .where((r) => r.accountType == type)
          .fold(0, (s, r) => s + r.currentBalanceCents);
      final groupType = type == 1 ? 'asset' : 'liability';
      final groups = (al['groups'] as List).cast<Map<String, Object?>>();
      expect(
          groups.firstWhere((g) => g['type'] == groupType)['subtotalCents'],
          direct,
          reason: 'accounts group subtotal ($groupType)');
    }
    final cardItem = (al['accounts'] as List)
        .cast<Map<String, Object?>>()
        .singleWhere((a) => a['name'] == '招行信用卡');
    expect(cardItem['usedCents'], 500500 + directOccupation,
        reason: '卡已用 = 欠款 + F50 未出账占用');
    expect(cardItem['availableCents'], 5000000 - 500500 - directOccupation,
        reason: '卡可用 = 限额 − 已用');

    // ── debts_list ──
    final dl = (await debtsTool.execute(const {}) as ToolData).json;
    final debtItems = (dl['debts'] as List).cast<Map<String, Object?>>();
    // 未结清 = d1(d2 已结清、d3 借出出局);逐分比对剩余本金。
    expect(debtItems, hasLength(1));
    expect(debtItems.single['remainingPrincipalCents'],
        directDebtRemainingById['d1'],
        reason: 'debts remaining = Σ unpaid principal (schedule caliber)');
    expect(debtItems.single['nextPaymentAmountCents'], 110000,
        reason: '下期 = 最早未还期次 e2');
    expect((dl['summary'] as Map)['totalRemainingCents'],
        directDebtRemainingById.values.fold(0, (a, b) => a + b),
        reason: '汇总 Σ剩余');

    // ── holdings_list(面板口径:Σ round(qty×avgCost) / Σ市值 / Σ浮盈)──
    final hl = (await holdingsTool.execute(const {}) as ToolData).json;
    final holdingRows = await database.holdingDao.watchAllHoldings().first;
    final securityRows = await database.referenceDao.getAllSecurities();
    final priceBySecurity = {
      for (final s in securityRows) s.id: s.currentPriceCents
    };
    var directCost = 0;
    var directMv = 0;
    var directPnl = 0;
    final directCostByHolding = <String, int>{};
    final directMvByHolding = <String, int>{};
    final directPnlByHolding = <String, int>{};
    for (final h in holdingRows) {
      final cost = (h.quantity * h.avgCostCents).round();
      final price = priceBySecurity[h.securityId] ?? 0;
      final mv = price > 0 ? (h.quantity * price).round() : cost;
      final pnl = price > 0 ? mv - cost : 0;
      directCost += cost;
      directMv += mv;
      directPnl += pnl;
      directCostByHolding[h.id] = cost;
      directMvByHolding[h.id] = mv;
      directPnlByHolding[h.id] = pnl;
    }
    final hlSummary = hl['summary'] as Map<String, Object?>;
    expect(hlSummary['totalCostCents'], directCost,
        reason: 'holdings Σcost = Σ round(qty×avgCost)');
    expect(hlSummary['totalMarketValueCents'], directMv,
        reason: 'holdings Σmv');
    expect(hlSummary['totalPnlCents'], directPnl, reason: 'holdings Σpnl');
    final hlItems = (hl['holdings'] as List).cast<Map<String, Object?>>();
    for (final item in hlItems) {
      // 行 id 不外露 → 按唯一 symbol 反查同库持仓行。
      final row = holdingRows.singleWhere(
          (h) => h.securityId == securityRows
              .singleWhere((s) => s.symbol == item['symbol']).id);
      expect(item['costCents'], directCostByHolding[row.id],
          reason: 'holdings item cost (${item['symbol']})');
      expect(item['marketValueCents'], directMvByHolding[row.id],
          reason: 'holdings item mv (${item['symbol']})');
      expect(item['unrealizedPnlCents'], directPnlByHolding[row.id],
          reason: 'holdings item pnl (${item['symbol']})');
    }

    // ── transactions_search(全量 + 过滤两态;科目单边口径)──
    final typeById = {
      for (final a in accountRows) a.id: a.accountType,
    };
    final txnHeads = await database.transactionDao.getAllTransactions();
    final txnEntries = await database.transactionDao.getAllEntries();
    // 交易头 → 分录(id 命中;holding 台账直插不产交易头,零干扰)。
    final entriesByTxn = <String, List<db.TransactionEntry>>{};
    for (final e in txnEntries) {
      entriesByTxn.putIfAbsent(e.transactionId, () => []).add(e);
    }

    int directIncome(Iterable<db.Transaction> heads) => heads.fold(
        0,
        (s, t) =>
            s +
            (entriesByTxn[t.id] ?? const [])
                .where((e) => typeById[e.accountId] == 4)
                .fold(0, (a, e) => a + e.creditCents));
    int directExpense(Iterable<db.Transaction> heads) => heads.fold(
        0,
        (s, t) =>
            s +
            (entriesByTxn[t.id] ?? const [])
                .where((e) => typeById[e.accountId] == 5)
                .fold(0, (a, e) => a + e.debitCents));
    bool headIsOut(db.Transaction t) => (entriesByTxn[t.id] ?? const [])
        .any((e) => typeById[e.accountId] == 5 && e.debitCents > 0);

    final ts = (await transactionsTool.execute(const {}) as ToolData).json;
    final tsSummary = ts['summary'] as Map<String, Object?>;
    expect(tsSummary['count'], txnHeads.length,
        reason: 'transactions 全量笔数');
    expect(tsSummary['incomeCents'], directIncome(txnHeads),
        reason: 'transactions income = Σ type4 credit 单边');
    expect(tsSummary['expenseCents'], directExpense(txnHeads),
        reason: 'transactions expense = Σ type5 debit 单边');
    expect(tsSummary['netCents'],
        directIncome(txnHeads) - directExpense(txnHeads));

    // 过滤态:direction=out + 9 月窗 + 账户(现金,任一分录涉及)。
    final sepStart = DateTime(2026, 9, 1);
    final sepEnd = DateTime(2026, 9, 30);
    final directOutSept = txnHeads.where((t) =>
        headIsOut(t) &&
        !t.transactionDate.isBefore(sepStart) &&
        !t.transactionDate.isAfter(sepEnd) &&
        (entriesByTxn[t.id] ?? const [])
            .any((e) => e.accountId == 'acc-cash'));
    final tsf = (await transactionsTool.execute({
      'start': '2026-09-01',
      'end': '2026-09-30',
      'direction': 'out',
      'account': '现金',
    }) as ToolData)
        .json;
    expect((tsf['summary'] as Map)['count'], directOutSept.length,
        reason: '过滤后笔数(9 月支出×现金)');
    expect((tsf['summary'] as Map)['expenseCents'], directExpense(directOutSept),
        reason: '过滤后支出合计');
    expect((tsf['summary'] as Map)['incomeCents'], 0,
        reason: 'direction=out → 收入 0');

    // ── budgets_status(读时 actuals = 账户级月窗大边)──
    final bs = (await budgetsTool.execute(const {}) as ToolData).json;
    final budgetRows = await database.budgetDao.watchAllBudgets().first;
    final dateOfHead = {for (final h in txnHeads) h.id: h.transactionDate};
    // (账户, y, m) → (Σdebit, Σcredit) 单遍累计(月窗 UTC,镜像 DS 算法)。
    final debitByKey = <String, int>{};
    final creditByKey = <String, int>{};
    for (final e in txnEntries) {
      final date = dateOfHead[e.transactionId];
      if (date == null) continue;
      final key =
          '${e.accountId}|${date.year}-${date.month.toString().padLeft(2, '0')}';
      debitByKey[key] = (debitByKey[key] ?? 0) + e.debitCents;
      creditByKey[key] = (creditByKey[key] ?? 0) + e.creditCents;
    }
    int largerSide(String accountId, String month) {
      final d = debitByKey['$accountId|$month'] ?? 0;
      final c = creditByKey['$accountId|$month'] ?? 0;
      return d > c ? d : c;
    }
    final bsBudgets = (bs['budgets'] as List).cast<Map<String, Object?>>();
    for (final b in budgetRows) {
      final itemRows =
          await database.budgetDao.watchItemsByBudget(b.id).first;
      final directActual = itemRows.fold(
          0, (s, i) => s + largerSide(i.accountId, b.month));
      final row = bsBudgets.singleWhere((r) => r['month'] == b.month);
      expect(row['actualCents'], directActual,
          reason: 'budget actual(${b.month})= 账户级月窗大边');
      expect(row['limitCents'], b.totalAmountCents);
    }
    final bsSummary = bs['summary'] as Map<String, Object?>;
    expect(bsSummary['count'], budgetRows.length);
    expect(bsSummary['totalLimitCents'],
        budgetRows.fold(0, (s, b) => s + b.totalAmountCents));

    // ── goals_list(savings current = 挂接账户行余额;无挂接 = 存储值)──
    final gl = (await goalsTool.execute(const {}) as ToolData).json;
    final goalRows = await database.goalDao.watchAllGoals().first;
    final glGoals = (gl['goals'] as List).cast<Map<String, Object?>>();
    final cashRow = accountRows.singleWhere((a) => a.id == 'acc-cash');
    final g1Row = glGoals.singleWhere((g) => g['name'] == '应急金');
    expect(g1Row['currentAmountCents'], cashRow.currentBalanceCents,
        reason: 'goal current(savings)= 挂接账户余额(同行直查)');
    final g2Row = glGoals.singleWhere((g) => g['name'] == '旅行金');
    final g2DbRow = goalRows.singleWhere((g) => g.id == 'g2');
    expect(g2Row['currentAmountCents'], g2DbRow.currentAmountCents,
        reason: 'goal current(无挂接)= 存储值直读');
    expect(g1Row['progressPct'],
        closeTo(cashRow.currentBalanceCents * 100 / 2000000, 0.001));
    final glSummary = gl['summary'] as Map<String, Object?>;
    expect(glSummary['count'], goalRows.length);
    expect(
        glSummary['totalCurrentCents'],
        cashRow.currentBalanceCents + g2DbRow.currentAmountCents,
        reason: 'goals Σcurrent');

    // ── performance_range(F43 既有区间测试 oracle,FR-6 手算取数)──
    final pr = (await performanceTool.execute({
      'start': '2026-08-01',
      'end': '2026-08-31',
    }) as ToolData)
        .json;
    expect(pr['beginMvCents'], 42770,
        reason: '期初 = 10×4,277(窗前 ffill 价)');
    expect(pr['endMvCents'], 45770, reason: '期末 = 10×4,577');
    expect(pr['netBuyCents'], 2000, reason: '净买入 = 47,770 − 45,770');
    expect(pr['estimatedGainCents'], 1000,
        reason: '估算收益 = 45,770 − 42,770 − 2,000');
    expect((pr['twrPct'] as num),
        closeTo(((47770 / 42770) * (91540 / 95540) * (45770 / 45770) - 1) * 100,
            0.001),
        reason: '区间 TWR = 现金流子期链(F43 同 oracle)');
    // 口径恒等式(FR-6 定义):gain ≡ end − begin − netBuy。
    expect(pr['estimatedGainCents'],
        (pr['endMvCents'] as int) -
            (pr['beginMvCents'] as int) -
            (pr['netBuyCents'] as int));

    // ── 跨工具链(夹具 interest=0,两口径同数)──
    expect(nw['totalLiabilitiesCents'],
        (dl['summary'] as Map)['totalRemainingCents'],
        reason: 'networth 负债与 debts 剩余在本夹具下逐分相等');
  });

  test('carrier account invisible in accounts_list on the shared fixture',
      () async {
    final al = (await accountsTool.execute(const {}) as ToolData).json;
    final names = (al['accounts'] as List)
        .cast<Map<String, Object?>>()
        .map((a) => a['name'])
        .toSet();
    expect(names.contains('平安卡贷载体'), isFalse,
        reason: '载体户不可见(spec FR-2 场景)');
    final rows = await database.accountDao.getAllAccounts();
    expect(al['totalCount'], rows.where((r) => !r.isSystem).length,
        reason: 'total_count = 全部非系统户(F65 夹具扩容后逐数)');
  });
}
