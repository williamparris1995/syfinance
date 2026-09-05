// F11 T3(spec FR-5,design ADR-6):孤儿分红合成头行。
// 离线(markPending)裸分红 —— 无对应持仓头行 —— 时,recordDividend 同事务
// 合成 qty=0/avgCost=0 的 pending 持仓头行:
// - 头行是 pending 锚:镜像协调(_refreshHoldings)按 (accountId, securityId)
//   联动保留台账行,上行批次(PendingCollector)经 holding 头行携带;
// - 台账数据本身上行 = holding_ledger entityType(server HoldingWriter 注释
//   明示 append-only 台账走该未来类型;server 对未注册 entityType fail-closed
//   —— T2 钉死),ticket 16;本任务以头行锚定「不丢、不抹」。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/binding/data/pending_collector.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/sync_state.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

void main() {
  late db.AppDatabase database;
  late HoldingLocalDataSource ds;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    ds = HoldingLocalDataSource(
        database, TransactionLocalDataSource(database, BalanceLocalUpdater(database)));
  });
  tearDown(() => database.close());

  Future<void> recordOrphan({required bool markPending}) => ds.recordDividend(
        accountId: 'acc-inv',
        securityId: 'sec-1',
        quantity: 10,
        cashPerShareCents: 5,
        totalAmountCents: 50,
        tradeDate: '2026-09-05',
        notes: '裸分红',
        markPending: markPending,
      );

  test('离线裸分红 → 同事务合成 qty=0/avgCost=0 的 pending 头行 + 台账行在',
      () async {
    await recordOrphan(markPending: true);

    // 合成头行:qty=0/avgCost=0/version=1/pending(纯分红持仓占位)。
    final holdings = await database.holdingDao.watchAllHoldings().first;
    expect(holdings, hasLength(1));
    final head = holdings.single;
    expect(head.accountId, 'acc-inv');
    expect(head.securityId, 'sec-1');
    expect(head.quantity, 0);
    expect(head.avgCostCents, 0);
    expect(head.version, 1);
    expect(head.syncState, SyncState.pending);

    // 台账行(分红事实)在库。
    final ledger = await database.holdingDao.getAllHoldingTransactions();
    expect(ledger, hasLength(1));
    expect(ledger.single.accountId, 'acc-inv');
    expect(ledger.single.securityId, 'sec-1');
    expect(ledger.single.amountCents, 50);
  });

  test('离线裸分红 → 上行批次含合成头行(holding 模块桶;台账由头行锚定)',
      () async {
    await recordOrphan(markPending: true);

    final batch = await PendingCollector(database).collect();

    expect(batch, isNotNull);
    final dtos = batch!.entitiesByModule[SyncModule.holding];
    expect(dtos, isNotNull);
    final head = (await database.holdingDao.watchAllHoldings().first).single;
    expect(dtos!.single.entityId, head.id);
    // payload 内容 = envelope 单持仓行形态(codec 单一事实源)。
    expect(dtos.single.fields['ID'], head.id);
    expect(dtos.single.fields['Quantity'], 0);
    expect(dtos.single.version, head.version);
  });

  test('已有头行 → 不合成新头行,原头行置 pending(既有行为不回归)', () async {
    await database.holdingDao.insertHolding(db.HoldingsCompanion.insert(
      id: 'h-existing',
      accountId: 'acc-inv',
      securityId: 'sec-1',
      quantity: 100,
      avgCostCents: 20,
      version: 3,
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    ));

    await recordOrphan(markPending: true);

    final holdings = await database.holdingDao.watchAllHoldings().first;
    expect(holdings, hasLength(1)); // 无第二行
    expect(holdings.single.id, 'h-existing');
    expect(holdings.single.quantity, 100); // 数量不被分红改动
    expect(holdings.single.syncState, SyncState.pending);
  });

  test('guest 裸分红(markPending=false)→ 不合成头行(无上行语义)', () async {
    await recordOrphan(markPending: false);

    expect(await database.holdingDao.watchAllHoldings().first, isEmpty);
    expect(await database.holdingDao.getAllHoldingTransactions(), hasLength(1));
  });
}
