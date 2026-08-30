/// 演示数据种子(R7 用户验收辅助):`--dart-define=YUCAI_DEMO_SEED=1` 启用时,
/// 空库注入一套跨模块代表性数据 —— 全部走真实本地数据源代码路径(与 UI 写入
/// 同一条管道,顺带回归验证这些路径),不直插 schema。
library;


import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/budget/data/budget_local_ds.dart';
import 'package:yucai_client/core/localdb/app_database.dart' hide TransactionEntry;
import 'package:yucai_client/debt/data/debt_local_ds.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/goal/data/goal_local_ds.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

/// 仅 demo 构建调用;数据存在(已有持仓)则跳过,保证幂等。
///
/// 口径(手算 oracle,截图核对用):
///   储蓄卡:10,000 初始 +8,000 工资 −50 餐饮 +100,000 借入到账 −10,000 买入
///         = 107,950.00
///   投资账户余额(成本)= 10,000.00;持仓市值 @110 = 11,000.00(浮盈 +1,000)
///   负债:借款 100,000,已还 0
///   本地净资产 = 储蓄 107,950 + 投资余额 10,000 + 浮盈 1,000 − 负债 100,000
///             = 18,950.00
///   本月:收入 8,000 / 支出 50;预算 3,000(餐饮);目标 500,000
Future<void> seedDemoData(AppDatabase db) async {
  final existing = await db.select(db.holdings).get();
  if (existing.isNotEmpty) return;

  final txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
  final accounts = AccountLocalDataSource(db);
  final holdings = HoldingLocalDataSource(db, txns);
  final debts = DebtLocalDataSource(
      db, TransactionLocalDataSource(db, BalanceLocalUpdater(db)));
  final goals = GoalLocalDataSource(db, holdings);
  final budgets = BudgetLocalDataSource(db);

  final now = DateTime.now();
  String ym(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
  String day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---- 账户 ----
  final savings = await accounts.create(const CreateAccountParams(
    name: '储蓄卡',
    accountType: AccountType.asset,
    category: AccountCategory.savings,
    currencyCode: 'CNY',
    initialBalanceCents: 1000000, // 10,000.00
    ownership: Ownership.personal,
  ));
  final investment = await accounts.create(const CreateAccountParams(
    name: '证券账户',
    accountType: AccountType.asset,
    category: AccountCategory.investment,
    currencyCode: 'CNY',
    initialBalanceCents: 0,
    ownership: Ownership.personal,
  ));
  final salaryCat = await accounts.create(const CreateAccountParams(
    name: '工资收入',
    accountType: AccountType.income,
    category: AccountCategory.otherAsset,
    currencyCode: 'CNY',
    initialBalanceCents: 0,
    ownership: Ownership.personal,
  ));
  final diningCat = await accounts.create(const CreateAccountParams(
    name: '餐饮',
    accountType: AccountType.expense,
    category: AccountCategory.otherAsset,
    currencyCode: 'CNY',
    initialBalanceCents: 0,
    ownership: Ownership.personal,
  ));
  final loanAcc = await accounts.create(const CreateAccountParams(
    name: '招商银行贷款',
    accountType: AccountType.liability,
    category: AccountCategory.loan,
    currencyCode: 'CNY',
    initialBalanceCents: 0,
    ownership: Ownership.personal,
  ));

  // ---- 本月收支(复式:收入=借储蓄/贷收入;支出=借支出/贷储蓄)----
  await txns.recordTransaction(RecordTransactionParams(
    transactionDate: DateTime(now.year, now.month, 1),
    description: '工资',
    entries: [
      TransactionEntry(
          accountId: savings.id, debitCents: 800000, creditCents: 0),
      TransactionEntry(
          accountId: salaryCat.id, debitCents: 0, creditCents: 800000),
    ],
  ));
  await txns.recordTransaction(RecordTransactionParams(
    transactionDate: now,
    description: '午餐',
    entries: [
      TransactionEntry(accountId: diningCat.id, debitCents: 5000, creditCents: 0),
      TransactionEntry(accountId: savings.id, debitCents: 0, creditCents: 5000),
    ],
  ));

  // ---- 借入 100,000 / 10 年 / 5% 等额本金,到账储蓄卡(自动双记 +100,000)----
  await debts.create(
    accountId: loanAcc.id, // 债务挂负债账户(借贷分录:负债侧)
    counterparty: '招商银行',
    interestRate: 0.05,
    amortizationIndex: 1, // equalPrincipal
    startDate: DateTime(now.year, now.month, 1),
    dueDate: DateTime(now.year + 10, now.month, 1),
    totalPrincipalCents: 10000000,
    type: DebtType.borrowedIn,
    subtype: 'mortgage',
    sourceAccountId: savings.id, // 到账账户
  );

  // ---- 持仓:茅台 100 股@100,现价 110(浮盈 +1,000;资金从储蓄卡)----
  final sec = await holdings.createSecurity(
    symbol: '600519',
    name: '贵州茅台',
    type: SecurityType.stock,
    exchange: 'SSE',
    currency: 'CNY',
  );
  await holdings.buy(
    accountId: investment.id,
    securityId: sec.id,
    fromAccountId: savings.id,
    quantity: 100,
    priceCents: 10000,
    tradeDate: day(now.subtract(const Duration(days: 7))),
  );
  // 现价更新(演示直更;真实行情走 server 同步)。
  await db.referenceDao
      .updateSecurityPrice(sec.id, 11000);

  // ---- 预算 / 目标 ----
  await budgets.createBudget(
    name: '本月预算',
    month: ym(now),
    currencyCode: 'CNY',
    items: [(accountId: diningCat.id, plannedAmountCents: 300000, notes: null)],
  );
  await goals.createGoal(
    name: '购房首付',
    type: GoalType.savings,
    targetAmountCents: 50000000,
    linkedAccountIds: [savings.id],
  );
}
