/// F6 FR-7 持仓买入链 E2E(管道链路,真实本地数据源)。
///
/// 链路:建资金账户 + 投资账户 + 标的 → buy(一个 drift 事务 = 持仓 upsert
/// 均价含费用化 fee + HoldingLots 插入 + HoldingTransactions 台账 +
/// 复式现金腿 debit 投资账户 / credit 资金账户)。
///
/// 反直觉语义(LD 风险表,照实钉死):现金腿金额 = price×quantity,
/// fee 不走现金腿 —— 资金账户余额只减 price×qty,fee 资本化进持仓成本
/// (均价与 lot 单价)。测试显式断言该语义;若视为产品缺陷另立 ticket。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/link_holding_buy_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

import 'link_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late HoldingLocalDataSource holdings;

  late String fundsId; // 买链资金(CNY 储蓄,初始 10,000.00)
  late String investId; // 买链证券账户(asset investment,初始 0)
  late String securityId; // 买链成长混合(基金标的)

  setUpAll(() async {
    // 确定性起点:删测试库 → 重建 DI → 幂等种子(照 link_receivable_collect_test.dart)。
    await resetTestDb();
    db = getIt<AppDatabase>();
    final txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
    holdings = HoldingLocalDataSource(db, txns);

    // ---- 自包含夹具(买链* 前缀,与演示数据零耦合) ----
    fundsId = await fundsAccount('买链资金', 1000000); // 10,000.00
    final accounts = AccountLocalDataSource(db);
    final invest = await accounts.create(const CreateAccountParams(
      name: '买链证券账户',
      accountType: AccountType.asset, // 投资账户(与资金账户不同 id)
      category: AccountCategory.investment,
      currencyCode: 'CNY', // 同币种(buy 前置校验)
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    investId = invest.id;
    final sec = await holdings.createSecurity(
      symbol: 'F6BUY01',
      name: '买链成长混合',
      type: SecurityType.fund,
      exchange: 'CN',
      currency: 'CNY',
    );
    securityId = sec.id;
  });

  tearDownAll(deleteTestDb);

  // raw drift 全表行数(守卫测试的差值断言,独立于被测 DS)。
  Future<int> txnRowCount() async =>
      (await db.select(db.transactions).get()).length;

  testWidgets('买链①买入:资金 −price×qty(fee 不走现金腿),持仓均价含 fee,two 行落位',
      (t) async {
    final beforeFunds = await balanceOf(db, fundsId); // 10,000.00

    // 买入 100 份 @10.00 元,fee 50.00 元。
    final trade = await holdings.buy(
      accountId: investId,
      securityId: securityId,
      fromAccountId: fundsId,
      quantity: 100,
      priceCents: 1000,
      feeCents: 5000,
      tradeDate: '2026-09-01',
    );

    // oracle:现金腿金额 = 1,000×100 = 100,000 分(price×qty);
    // fee 5,000 分**不减现金余额** —— 资本化进持仓成本(反直觉,照实断言)。
    expect(await balanceOf(db, fundsId), beforeFunds - 100000,
        reason: '资金 −price×qty;fee 不走现金腿(LLD-8 显式语义)');
    // oracle:投资账户 debit 100,000(asset:debit−credit)→ 0 + 100,000。
    expect(await balanceOf(db, investId), 100000,
        reason: '投资账户入账成本 basis(现金腿 debit 侧)');

    // 持仓:数量 100;均价 = (100,000 + 5,000)/100 = 1,050 分(fee 摊入)。
    final holdingRows = await holdings.listHoldings(accountId: investId);
    expect(holdingRows, hasLength(1), reason: '首笔买入建仓 1 行');
    final h = holdingRows.single;
    expect(h.quantity, 100);
    expect(h.avgCostCents, 1050, reason: '均价 = (amount+fee)/qty = 1,050');

    // FIFO lot 1 行:单价 = (amount+fee)/qty = 1,050,数量/剩余 = 100/100。
    final lots = await db.derivedDao.getLotsByHolding(h.id);
    expect(lots, hasLength(1));
    expect(lots.single.priceCents, 1050, reason: 'lot 单价含费用化 fee');
    expect(lots.single.quantity, 100);
    expect(lots.single.remainingQuantity, 100);

    // 台账(HoldingTransactions)1 行,方向为买。
    final ledger = await holdings.listHoldingTransactions(
        accountId: investId, securityId: securityId);
    expect(ledger, hasLength(1));
    final row = ledger.single;
    expect(row.tradeType, TradeType.buy, reason: '台账方向为买');
    expect(row.quantity, 100);
    expect(row.priceCents, 1000);
    expect(row.amountCents, 100000, reason: '台账金额 = price×qty');
    expect(row.feeCents, 5000);
    expect(row.tradeDate, '2026-09-01');

    // buy 返回视图与库内一致。
    expect(trade.id, row.id);
    expect(trade.tradeType, TradeType.buy);
    expect(trade.amountCents, 100000);
  });

  testWidgets('买链②余额不足守卫:抛「资金账户余额不足」,库内零残留(差值断言)', (t) async {
    // 夹具后现状:资金 900,000 分(① 的 10,000.00 − 1,000.00)。
    final beforeFunds = await balanceOf(db, fundsId); // 9,000.00
    final beforeTxnRows = await txnRowCount();
    final beforeHoldings =
        (await holdings.listHoldings(accountId: investId)).length;
    final beforeLedger = (await holdings.listHoldingTransactions(
            accountId: investId, securityId: securityId))
        .length;

    // oracle:12,000 分(120.00 元)× 100 = 1,200,000 分(12,000.00 元)
    // > 余额 900,000 分(9,000.00 元)→ 守卫。
    // 读代码确认:余额校验在 drift 事务开启**之前**(holding_local_ds._trade),
    // 抛 ServerFailure 时一个字节都没写 —— 差值断言照旧钉死"零残留"。
    await expectLater(
      holdings.buy(
        accountId: investId,
        securityId: securityId,
        fromAccountId: fundsId,
        quantity: 100,
        priceCents: 12000,
        tradeDate: '2026-09-01',
      ),
      throwsA(isA<ServerFailure>()
          .having((f) => f.message, 'message', '资金账户余额不足')),
    );

    expect(await balanceOf(db, fundsId), beforeFunds, reason: '余额不动');
    expect(await txnRowCount(), beforeTxnRows,
        reason: '无新复式交易(事务未开启/回滚)');
    expect((await holdings.listHoldings(accountId: investId)).length,
        beforeHoldings,
        reason: '持仓行数不变');
    expect(
        (await holdings.listHoldingTransactions(
                accountId: investId, securityId: securityId))
            .length,
        beforeLedger,
        reason: '台账行数不变');
  });

  testWidgets('买链③第二笔不同价买入:加权均价 + FIFO lots 两行(加权口径)', (t) async {
    final beforeFunds = await balanceOf(db, fundsId); // 9,000.00(① 之后)

    // 第二笔:100 份 @13.00 元,fee 30.00 元。
    await holdings.buy(
      accountId: investId,
      securityId: securityId,
      fromAccountId: fundsId,
      quantity: 100,
      priceCents: 1300,
      feeCents: 3000,
      tradeDate: '2026-09-02',
    );

    // oracle:现金腿 = 1,300×100 = 130,000 分(fee 同样不走现金腿)。
    expect(await balanceOf(db, fundsId), beforeFunds - 130000,
        reason: '资金 −price×qty(两笔合计 1,000,000−100,000−130,000)');

    // oracle(加权均价):新成本 = 旧数量×旧均价 + amount + fee
    //   = 100×1,050 + 130,000 + 3,000 = 238,000 分
    // 新数量 = 200 → 均价 = 238,000/200 = 1,190 分。
    final holdingRows = await holdings.listHoldings(accountId: investId);
    expect(holdingRows, hasLength(1), reason: '同账户同标的 upsert,仍 1 行');
    final h = holdingRows.single;
    expect(h.quantity, 200);
    expect(h.avgCostCents, 1190, reason: '加权均价 = (Σ成本+Σfee)/Σ数量');

    // FIFO lots 2 行:lot① 1,050×100;lot② = (130,000+3,000)/100 = 1,330×100。
    final lots = await db.derivedDao.getLotsByHolding(h.id);
    expect(lots, hasLength(2), reason: '两笔不同价买入 → 两行 lots');
    final prices = lots.map((l) => l.priceCents).toSet();
    expect(prices, {1050, 1330});
    expect(lots.fold<double>(0, (a, l) => a + l.remainingQuantity), 200,
        reason: '剩余数量合计 = 总数量');

    // 台账 2 行,全为买。
    final ledger = await holdings.listHoldingTransactions(
        accountId: investId, securityId: securityId);
    expect(ledger, hasLength(2));
    expect(ledger.every((r) => r.tradeType == TradeType.buy), isTrue);
  });
}
