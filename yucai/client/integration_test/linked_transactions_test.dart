/// R7 关联交易链路 E2E(用户验收问题:「关联交易等都是正常的吗」)。
///
/// 每条链路经真实本地数据源(与 UI bloc 同一写管道),断言**跨模块联动**:
/// 账户余额 × 债务余本 × 期次状态 × 已实现浮盈。
///
/// 自包含夹具:全部用 `链路*` 前缀的独立账户/标的,与演示数据零耦合 ——
/// 与 app_pages_test 同跑互不干扰;断言用相对增量(前后差值)。
/// Windows 桌面注意:请单独运行本文件(两个集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/linked_transactions_test.dart -d windows`
library;

import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/demo/demo_seed.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/debt/data/debt_local_ds.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DebtLocalDataSource debts;
  late HoldingLocalDataSource holdings;
  late TransactionLocalDataSource txns;
  late AccountLocalDataSource accounts;

  late String cashId; // 链路储蓄
  late String investId; // 链路投资
  late String recvId; // 链路应收
  late String loanId; // 链路负债账户
  late String debtId; // 链路借款(10w/10y/5% 等额本金)
  late String secId; // 链路标的(100 股@100)

  setUpAll(() async {
    // 确定性起点:删除本地库(含种子/演示数据),随后按需重建。
    final support = await getApplicationSupportDirectory();
    final dbFile = File('${support.path}/yucai.db');
    if (await dbFile.exists()) await dbFile.delete();
    await configureDependencies();
    await seedDemoData(getIt<AppDatabase>()); // 幂等;夹具独立于演示数据
    db = getIt<AppDatabase>();
    txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
    debts = DebtLocalDataSource(db, txns);
    holdings = HoldingLocalDataSource(db, txns);
    accounts = AccountLocalDataSource(db);

    // ---- 自包含夹具 ----
    final cash = await accounts.create(const CreateAccountParams(
      name: '链路储蓄',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 20000000, // 200,000.00
      ownership: Ownership.personal,
    ));
    cashId = cash.id;
    final invest = await accounts.create(const CreateAccountParams(
      name: '链路投资',
      accountType: AccountType.asset,
      category: AccountCategory.investment,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    investId = invest.id;
    final recv = await accounts.create(const CreateAccountParams(
      name: '链路应收',
      accountType: AccountType.asset,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    recvId = recv.id;
    final loan = await accounts.create(const CreateAccountParams(
      name: '链路负债',
      accountType: AccountType.liability,
      category: AccountCategory.loan,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    loanId = loan.id;

    // 借款 100,000 / 10 年 / 5% 等额本金,到账链路储蓄(+100,000)
    final debt = await debts.create(
      accountId: loanId,
      counterparty: '链路银行',
      interestRate: 0.05,
      amortizationIndex: 1,
      startDate: DateTime(2026, 8, 1),
      dueDate: DateTime(2036, 8, 1),
      totalPrincipalCents: 10000000,
      type: DebtType.borrowedIn,
      subtype: 'mortgage',
      sourceAccountId: cashId,
    );
    debtId = debt.id;

    // 标的 + 买入 100 股@100(资金从链路储蓄,−10,000)
    final sec = await holdings.createSecurity(
      symbol: 'LINK01',
      name: '链路标的',
      type: SecurityType.stock,
      currency: 'CNY',
    );
    secId = sec.id;
    await holdings.buy(
      accountId: investId,
      securityId: secId,
      fromAccountId: cashId,
      quantity: 100,
      priceCents: 10000,
      tradeDate: '2026-08-30',
    );
  });

  Future<int> bal(String accountId) async {
    final row = await (db.select(db.accounts)
          ..where((a) => a.id.equals(accountId)))
        .getSingle();
    return row.currentBalanceCents;
  }

  testWidgets('链路①借款还款:储蓄 −1,250 / 期次已还持久化(复式入账)', (t) async {
    final before = await bal(cashId); // 290,000.00(200k+100k−10k)
    final schedule = await db.debtDao.getScheduleByDebt(debtId);
    final first = schedule.first; // 首期:本金 83,333 + 利息 41,667
    expect(first.totalCents, 125000, reason: '首期 = 10w/120 期 + 10w×5%/12');

    await debts.recordPayment(
      debtId: debtId,
      scheduleEntryId: first.id,
      fromAccountId: cashId,
    );

    expect(await bal(cashId), before - 125000,
        reason: '还款后链路储蓄应 −1,250.00');
    final scheduleAfter = await db.debtDao.getScheduleByDebt(debtId);
    expect(scheduleAfter.first.paid, isTrue, reason: '期次已还须持久化');
    expect(scheduleAfter.first.principalCents, 83333,
        reason: '首期本金 833.33(10w/120 期)');
    expect(scheduleAfter.first.interestCents, 41667,
        reason: '首期利息 416.67(10w×5%/12)');
  });

  testWidgets('链路②持仓卖出:FIFO 实现盈亏 +1,000 / 现金回链路储蓄 +6,000', (t) async {
    final before = await bal(cashId);

    await holdings.sell(
      accountId: investId,
      securityId: secId,
      fromAccountId: cashId,
      quantity: 50,
      priceCents: 12000,
      tradeDate: '2026-08-30',
    );

    // 台账行:卖出 realized = (120−100)×50 = 100,000 分(FIFO 成本 100/股)
    final sellRows = await (db.select(db.holdingTransactions)
          ..where((a) => a.securityId.equals(secId) &
              a.tradeType.equals(2)))
        .get();
    final latest = sellRows.reduce((a, b) =>
        a.createdAt.isAfter(b.createdAt) ? a : b);
    expect(latest.realizedPnlCents, 100000,
        reason: 'FIFO 实现盈利 1,000.00 应入台账');

    expect(await bal(cashId), before + 600000, reason: '卖出款 6,000.00 回储蓄');
  });

  testWidgets('链路③转账:链路储蓄 → 链路投资 双向余额联动', (t) async {
    final beforeCash = await bal(cashId);
    final beforeInvest = await bal(investId);

    await txns.recordTransfer(RecordTransferParams(
      transactionDate: DateTime.now(),
      fromAccountId: cashId,
      toAccountId: investId,
      amountCents: 100000, // 1,000.00
      description: '链路③转账',
    ));

    expect(await bal(cashId), beforeCash - 100000);
    expect(await bal(investId), beforeInvest + 100000);
  });

  testWidgets('链路④借出双写:资金账户 −5,000 / 应收账户 +5,000', (t) async {
    final before = await bal(cashId);

    await debts.create(
      accountId: recvId, // 应收账户(借出方向)
      counterparty: '链路借出人',
      interestRate: 0.03,
      amortizationIndex: 0, // lumpSum
      startDate: DateTime(2026, 9, 1),
      dueDate: DateTime(2026, 12, 1),
      totalPrincipalCents: 500000,
      type: DebtType.borrowedOut,
      sourceAccountId: cashId, // 资金出账户
    );

    expect(await bal(cashId), before - 500000, reason: '借出双写:资金 −本金');
    expect(await bal(recvId), 500000, reason: '借出双写:应收 +本金');
  });
}
