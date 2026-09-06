// F10 T3(2026-09-04):PendingCollector(spec FR-5,design ADR-5)。
// - 空库(无 pending 无墓碑)→ null(空批次感知);
// - synced 行不进批次,pending 行进(实体 id/版本/字段快照);
// - 跨模块 pending → 按 SyncModule 常量分桶;
// - 仅墓碑(无 pending 实体)→ 仍是非空批次。
// F11 T3(2026-09-05)适配:fields 由 drift 行 toJson 改为 envelope_codec
// 产出的 server 兼容行形态(PascalCase/剔 syncState/子表嵌套 —— port 编码
// payload bytes 的直接输入,单一事实源与备份导出共享)。
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/binding/data/pending_collector.dart';
import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/sync_state.dart';

void main() {
  late db.AppDatabase database;
  late PendingCollector collector;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    collector = PendingCollector(database);
  });
  tearDown(() => database.close());

  Future<void> seedTag(String id,
      {String syncState = SyncState.synced, String name = '标签', int version = 3}) async {
    await database.tagDao.insertTag(db.TagsCompanion.insert(
      id: id,
      name: name,
      color: '#112233',
      version: version,
      createdAt: DateTime.utc(2026, 9, 4),
      updatedAt: DateTime.utc(2026, 9, 4),
      syncState: Value(syncState),
    ));
  }

  Future<void> seedAccount(String id,
      {String syncState = SyncState.synced, String name = '账户'}) async {
    await database.accountDao.insertAccount(db.AccountsCompanion.insert(
      id: id,
      name: name,
      accountType: 1,
      category: 2,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: 1,
      icon: '',
      color: '',
      chartCode: '',
      isSystem: false,
      sortOrder: 0,
      institution: '',
      cardNumberTail: '',
      notes: '',
      goldProductType: '',
      status: 1,
      version: 5,
      createdAt: DateTime.utc(2026, 9, 4),
      updatedAt: DateTime.utc(2026, 9, 4),
      syncState: Value(syncState),
    ));
  }

  Future<void> seedPendingTransactionWithEntries(String id) async {
    await database.transactionDao.insertTransaction(
        db.TransactionsCompanion.insert(
      id: id,
      transactionDate: DateTime.utc(2026, 9, 4),
      description: '离线记账',
      version: 2,
      createdAt: DateTime.utc(2026, 9, 4),
      updatedAt: DateTime.utc(2026, 9, 4),
      syncState: const Value(SyncState.pending),
    ));
    await database.transactionDao.insertEntry(
        db.TransactionEntriesCompanion.insert(
      id: 'e-$id',
      transactionId: id,
      accountId: 'acc-any',
      chartOfAccountCode: '1001',
      debitCents: 500,
      creditCents: 0,
      note: '',
    ));
  }

  Future<void> seedTombstone(String module, String entityId) async {
    await database.syncTombstoneDao.upsertTombstone(
        db.SyncTombstonesCompanion.insert(
            module: module, entityId: entityId, deletedAt: DateTime.utc(2026, 9, 4)));
  }

  test('空库(无 pending 无墓碑)→ collect 返回 null', () async {
    expect(await collector.collect(), isNull);
  });

  test('synced 行不进批次;pending 行进(实体 id/版本/字段快照)', () async {
    await seedTag('t-synced');
    await seedTag('t-pending', syncState: SyncState.pending, name: '离线标签', version: 7);

    final batch = await collector.collect();

    expect(batch, isNotNull);
    expect(batch!.entitiesByModule.keys, [SyncModule.tag]);
    final dtos = batch.entitiesByModule[SyncModule.tag]!;
    expect(dtos.map((e) => e.entityId), ['t-pending']);
    // 版本随行携带(对齐 sync proto SyncPayload.version)。
    expect(dtos.single.version, 7);
    // 字段快照 = envelope 行形态(F11:port 编码 payload bytes 的直接输入;
    // PascalCase、剔 syncState、ID 与 entityId 同源)。
    expect(dtos.single.fields['ID'], 't-pending');
    expect(dtos.single.fields['Name'], '离线标签');
    expect(dtos.single.fields['Color'], '#112233');
    expect(dtos.single.fields['Version'], 7);
    expect(dtos.single.fields.containsKey('syncState'), isFalse);
    expect(batch.tombstones, isEmpty);
    expect(batch.changeCount, 1);
  });

  test('pending 交易头行 → 分录子表随行嵌套(Entries)', () async {
    await seedPendingTransactionWithEntries('txn-pending');

    final batch = await collector.collect();

    final dto = batch!.entitiesByModule[SyncModule.transaction]!.single;
    expect(dto.entityId, 'txn-pending');
    expect(dto.version, 2);
    final entries = dto.fields['Entries'] as List;
    expect(entries, hasLength(1));
    expect(entries.single['ID'], 'e-txn-pending');
    expect(entries.single['DebitCents'], 500);
    expect(dto.fields['TransactionDate'], '2026-09-04T00:00:00.000Z');
  });

  test('跨模块 pending → 按 SyncModule 常量分桶', () async {
    await seedAccount('a-pending', syncState: SyncState.pending);
    await seedTag('t-pending', syncState: SyncState.pending);

    final batch = await collector.collect();

    expect(batch, isNotNull);
    expect(batch!.entitiesByModule.keys.toSet(),
        {SyncModule.account, SyncModule.tag});
    expect(batch.entitiesByModule[SyncModule.account]!.single.entityId, 'a-pending');
    expect(batch.entitiesByModule[SyncModule.tag]!.single.entityId, 't-pending');
    expect(batch.modules, {SyncModule.account, SyncModule.tag});
    expect(batch.changeCount, 2);
  });

  test('仅墓碑(无 pending 实体)→ 仍是非空批次;墓碑字段齐全', () async {
    await seedTag('t-synced');
    await seedTombstone(SyncModule.tag, 't-deleted');

    final batch = await collector.collect();

    expect(batch, isNotNull);
    expect(batch!.entitiesByModule, isEmpty);
    expect(batch.tombstones, hasLength(1));
    final t = batch.tombstones.single;
    expect(t.module, SyncModule.tag);
    expect(t.entityId, 't-deleted');
    expect(t.deletedAt, DateTime.utc(2026, 9, 4));
    expect(batch.isEmpty, isFalse);
    expect(batch.changeCount, 1);
  });

  test('空批次感知:无墓碑但 entitiesByModule 空 → isEmpty 为真(防御)', () async {
    const batch = SyncBatch(entitiesByModule: {}, tombstones: []);
    expect(batch.isEmpty, isTrue);
    expect(batch.changeCount, 0);
  });

  // ---- F17-T2(ADR-4 台账查证裁决=实施):holding_ledger 台账联动上行 ----

  Future<void> seedHolding(String id, String accountId, String securityId,
      {String syncState = SyncState.pending}) async {
    await database.holdingDao.insertHolding(db.HoldingsCompanion.insert(
      id: id,
      accountId: accountId,
      securityId: securityId,
      quantity: 100,
      avgCostCents: 12,
      version: 1,
      createdAt: DateTime.utc(2026, 9, 4),
      updatedAt: DateTime.utc(2026, 9, 4),
      syncState: Value(syncState),
    ));
  }

  Future<void> seedLedgerTxn(String id, String accountId, String securityId,
      {int tradeType = 3}) async {
    await database.holdingDao.insertHoldingTransaction(
        db.HoldingTransactionsCompanion.insert(
      id: id,
      accountId: accountId,
      securityId: securityId,
      tradeType: tradeType,
      quantity: 100,
      priceCents: 12,
      amountCents: 1200,
      feeCents: 0,
      realizedPnlCents: 0,
      tradeDate: DateTime.utc(2026, 9, 1),
      notes: '离线分红',
      createdAt: DateTime.utc(2026, 9, 1),
    ));
  }

  test('F17-T2:pending 持仓头行 → 同 (account,security) pair 的台账行随批上行'
      '(entityType=holding_ledger,行形态=envelope 台账行)', () async {
    await seedHolding('h-pending', 'acc-inv', 'sec-1');
    await seedLedgerTxn('tr-1', 'acc-inv', 'sec-1'); // 分红(同 pair)
    await seedLedgerTxn('tr-2', 'acc-inv', 'sec-2'); // 异 pair:不收

    final batch = await collector.collect();

    // 头行照常进 holding 桶;台账行进第 9 桶 holding_ledger。
    expect(batch!.entitiesByModule[SyncModule.holding]!.single.entityId,
        'h-pending');
    final ledger = batch.entitiesByModule[SyncModule.holdingLedger]!;
    expect(ledger.map((e) => e.entityId), ['tr-1']);
    // 行形态 = envelope_codec 的台账行(PascalCase/int TradeType/RFC3339)。
    final fields = ledger.single.fields;
    expect(fields['ID'], 'tr-1');
    expect(fields['AccountID'], 'acc-inv');
    expect(fields['SecurityID'], 'sec-1');
    expect(fields['TradeType'], 3);
    expect(fields['Notes'], '离线分红');
    expect(fields['TradeDate'], '2026-09-01T00:00:00.000Z');
    expect(fields.containsKey('syncState'), isFalse);
    // 台账 append-only 无乐观锁版本 → DTO version 恒 1(客户端恒 CREATE,
    // server 对 CREATE 不做冲突检查;墓碑面不适用)。
    expect(ledger.single.version, 1);
    expect(batch.modules, {SyncModule.holding, SyncModule.holdingLedger});
  });

  test('F17-T2:无 pending 持仓头行 → 台账行不收(头行是收集锚);'
      '重收集幂等(server 按 id upsert,重复行无害)', () async {
    await seedHolding('h-synced', 'acc-inv', 'sec-1',
        syncState: SyncState.synced);
    await seedLedgerTxn('tr-1', 'acc-inv', 'sec-1');

    expect(await collector.collect(), isNull); // 头行 synced:无锚不收台账

    // 头行转 pending(如再买/卖)→ 台账全量重收(含已上行过的旧行):
    // server upsert 按 id 幂等,重复上行无害(ADR-4 关联口径论证)。
    await database.holdingDao.updateHolding(const db.HoldingsCompanion(
      id: Value('h-synced'),
      syncState: Value(SyncState.pending),
    ));
    final batch = await collector.collect();
    expect(
        batch!.entitiesByModule[SyncModule.holdingLedger]!.map((e) => e.entityId),
        ['tr-1']);
  });
}
