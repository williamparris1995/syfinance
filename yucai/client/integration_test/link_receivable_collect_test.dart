/// F6 FR-1 债权收回链 E2E(管道链路,真实本地数据源)。
///
/// 链路:借出建应收(borrowedOut 双写)→ 收回第一期(recordPayment 复式入账)
/// → 断言资金/应收双向余额联动 + 期次状态持久化 + 关联交易落位 + 重复收回守卫。
/// 模式照 linked_transactions_test:夹具独立前缀(收链*),断言用前后差值。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/link_receivable_collect_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/debt/data/debt_local_ds.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

import 'link_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DebtLocalDataSource debts;
  late AccountLocalDataSource accounts;

  late String fundsId; // 收链资金(CNY 储蓄,初始 200,000.00)
  late String recvId; // 收链应收(借出方向债权账户)
  late String debtId; // 收链债权(6,000 / 3 个月 / 3% 等额本息)
  late String firstEntryId; // 第一期期次 id(收回 + 重复收回守卫共用)

  setUpAll(() async {
    // 确定性起点:删测试库 → 重建 DI → 幂等种子(照 linked_transactions_test)。
    await resetTestDb();
    db = getIt<AppDatabase>();
    final txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
    debts = DebtLocalDataSource(db, txns);
    accounts = AccountLocalDataSource(db);

    // ---- 自包含夹具(收链* 前缀,与演示数据零耦合) ----
    fundsId = await fundsAccount('收链资金', 20000000); // 200,000.00
    final recv = await accounts.create(const CreateAccountParams(
      name: '收链应收',
      accountType: AccountType.asset,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    recvId = recv.id;
  });

  tearDownAll(deleteTestDb);

  testWidgets('收链①借出双写:收链资金 −6,000 / 收链应收 +6,000', (t) async {
    final beforeFunds = await balanceOf(db, fundsId); // 200,000.00
    final beforeRecv = await balanceOf(db, recvId); // 0.00

    // 借出 6,000(3 个月 / 3%,参数形态照 linked_transactions_test 借出链);
    // 相对日期以 fixedToday 为基准:起息 2026-09-01(= 今天 −1 天)、到期 2026-12-01。
    final debt = await debts.create(
      accountId: recvId, // 应收账户(借出方向)
      counterparty: '收链好友',
      interestRate: 0.03,
      amortizationIndex: 0, // 等额本息(AmortizationMethod.index)
      startDate: DateTime(fixedToday.year, fixedToday.month, fixedToday.day - 1),
      dueDate: DateTime(fixedToday.year, fixedToday.month + 3, 1),
      totalPrincipalCents: 600000, // 6,000.00
      type: DebtType.borrowedOut,
      sourceAccountId: fundsId, // 资金出账户
    );
    debtId = debt.id;

    // oracle:借出双写本金整额(无利息腿)—— 资金 −600,000 分 / 应收 +600,000 分。
    expect(await balanceOf(db, fundsId), beforeFunds - 600000,
        reason: '借出双写:资金 −本金');
    expect(await balanceOf(db, recvId), beforeRecv + 600000,
        reason: '借出双写:应收 +本金');

    // 等额本息 3 个月 → 3 期;期次总额 = 本金 + 利息(利息口径以生成的
    // entry.totalCents 为准做差值断言,不自行复利计算)。
    final schedule = await db.debtDao.getScheduleByDebt(debtId);
    schedule.sort((a, b) => a.paymentDate.compareTo(b.paymentDate));
    expect(schedule.length, 3, reason: '3 个月等额本息生成 3 期');
    expect(schedule.first.principalCents + schedule.first.interestCents,
        schedule.first.totalCents,
        reason: '期次总额 = 本金 + 利息');
  });

  testWidgets('收链②收回第一期:资金 +期次总额 / 应收 −期次总额 / 期次已还持久化',
      (t) async {
    final beforeFunds = await balanceOf(db, fundsId); // 194,000.00
    final beforeRecv = await balanceOf(db, recvId); // 6,000.00

    // 取第一个未付期次(按还款日排序后的首期)。oracle:等额本息月供 ≈ 2,010.01 元
    // (6,000 本金 / 3% 年息 / 3 期),利息口径以生成的 entry.totalCents 为准,不自算复利。
    final schedule = await db.debtDao.getScheduleByDebt(debtId);
    schedule.sort((a, b) => a.paymentDate.compareTo(b.paymentDate));
    final first = schedule.firstWhere((e) => !e.paid);
    firstEntryId = first.id;

    final paid = await debts.recordPayment(
      debtId: debtId,
      scheduleEntryId: first.id,
      fromAccountId: fundsId, // 收回到账账户
    );

    // 复式入账(borrowedOut 收回):debit 资金(+) + credit 应收(−)。
    expect(await balanceOf(db, fundsId), beforeFunds + first.totalCents,
        reason: '收回入账:资金 +期次总额');
    expect(await balanceOf(db, recvId), beforeRecv - first.totalCents,
        reason: '应收核销:应收 −期次总额');

    // 期次状态持久化 + 关联交易落位。
    final after = await db.debtDao.getScheduleByDebt(debtId);
    final entry = after.firstWhere((e) => e.id == firstEntryId);
    expect(entry.paid, isTrue, reason: '期次已还须持久化');
    expect(entry.paidCents, entry.totalCents, reason: '实还金额 = 期次总额');
    expect(entry.transactionId, isNotNull, reason: '期次关联交易 id 落位');
    expect(paid.paid, isTrue, reason: 'recordPayment 返回已还视图');
    expect(paid.paidCents, entry.totalCents);
    expect(paid.transactionId, isNotEmpty, reason: '返回的关联交易 id 非空');
  });

  testWidgets('收链③重复收回守卫:同一期次再还 → 抛「该期次已还款」', (t) async {
    // oracle:recordPayment 对已付期次有守卫,重复触发抛 ServerFailure(中文文案)。
    await expectLater(
      debts.recordPayment(
        debtId: debtId,
        scheduleEntryId: firstEntryId,
        fromAccountId: fundsId,
      ),
      throwsA(isA<ServerFailure>().having(
          (f) => f.message, 'message', '该期次已还款')),
    );
  });
}
