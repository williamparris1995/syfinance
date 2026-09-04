// F10 T2(2026-09-04):syncState DAO 支持 + 墓碑 DAO(spec FR-3/FR-4,
// design ADR-2/ADR-4)。pending 查询(watchPending/getPending 供 T3 收集器)、
// deleteAllSynced*(镜像协调的 delete-all 排除 pending)、墓碑 get/clear。
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/localdb/sync_state.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  AccountsCompanion accountRow(String id, {String syncState = 'synced'}) =>
      AccountsCompanion.insert(
        id: id,
        name: 'n-$id',
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
        version: 1,
        createdAt: DateTime.utc(2026, 9, 4),
        updatedAt: DateTime.utc(2026, 9, 4),
        syncState: Value(syncState),
      );

  test('getPending/watchPending 只返回 pending 行', () async {
    await db.accountDao.insertAccount(accountRow('a-sync'));
    await db.accountDao.insertAccount(accountRow('a-pend', syncState: 'pending'));

    final pending = await db.accountDao.getPendingAccounts();
    expect(pending.map((a) => a.id), ['a-pend']);

    final watched = await db.accountDao.watchPendingAccounts().first;
    expect(watched.map((a) => a.id), ['a-pend']);
  });

  test('deleteAllSyncedAccounts 排除 pending(在线全 synced 等价 delete-all)',
      () async {
    await db.accountDao.insertAccount(accountRow('a-sync'));
    await db.accountDao.insertAccount(accountRow('a-pend', syncState: 'pending'));

    final deleted = await db.accountDao.deleteAllSyncedAccounts();

    expect(deleted, 1);
    final rest = await db.accountDao.getAllAccounts();
    expect(rest.map((a) => a.id), ['a-pend']);
    expect(rest.single.syncState, 'pending');
  });

  test('deleteAllSyncedTransactions:synced 头行+分录级联删,pending 保留',
      () async {
    Future<void> seedTxn(String id, String state) async {
      final now = DateTime.utc(2026, 9, 4);
      await db.transactionDao.insertTransaction(TransactionsCompanion.insert(
        id: id,
        transactionDate: now,
        description: 'd-$id',
        version: 1,
        createdAt: now,
        updatedAt: now,
        syncState: Value(state),
      ));
      await db.transactionDao.insertEntry(
          TransactionEntriesCompanion.insert(
        id: 'e-$id',
        transactionId: id,
        accountId: 'acc',
        chartOfAccountCode: '',
        debitCents: 100,
        creditCents: 0,
        note: '',
      ));
    }

    await seedTxn('t-sync', 'synced');
    await seedTxn('t-pend', 'pending');

    expect(await db.transactionDao.deleteAllSyncedTransactions(), 1);

    final heads = await db.transactionDao.getAllTransactions();
    expect(heads.map((t) => t.id), ['t-pend']);
    // pending 头行的分录随行保留(ADR-3:内容与存在性不变)。
    final entries =
        await db.transactionDao.watchEntriesByTransaction('t-pend').first;
    expect(entries, hasLength(1));
    expect(
        await db.transactionDao.watchEntriesByTransaction('t-sync').first,
        isEmpty);
  });

  group('SyncTombstoneDao', () {
    test('getByModule / clear 单条 / clearAll', () async {
      final dao = db.syncTombstoneDao;
      await dao.upsertTombstone(SyncTombstonesCompanion.insert(
          module: SyncModule.account,
          entityId: 'a1',
          deletedAt: DateTime.utc(2026, 9, 4)));
      await dao.upsertTombstone(SyncTombstonesCompanion.insert(
          module: SyncModule.transaction,
          entityId: 't1',
          deletedAt: DateTime.utc(2026, 9, 4)));

      expect((await dao.getTombstonesByModule(SyncModule.account))
          .map((t) => t.entityId), ['a1']);
      expect(await dao.getAllTombstones(), hasLength(2));

      expect(await dao.clearTombstone(SyncModule.account, 'a1'), 1);
      expect(await dao.getTombstonesByModule(SyncModule.account), isEmpty);
      expect(await dao.getAllTombstones(), hasLength(1));

      expect(await dao.clearAllTombstones(), 1);
      expect(await dao.getAllTombstones(), isEmpty);
    });
  });
}
