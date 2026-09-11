import 'package:drift/drift.dart';

import '../app_database.dart';
import '../sync_state.dart'
    show SyncState, chunked, syncWritebackChunkSize;
import '../tables/holding_tables.dart';

part 'holding_dao.g.dart';

@DriftAccessor(tables: [Holdings, HoldingTransactions])
class HoldingDao extends DatabaseAccessor<AppDatabase>
    with _$HoldingDaoMixin {
  HoldingDao(super.db);

  Future<void> insertHolding(HoldingsCompanion entry) =>
      into(holdings).insert(entry);

  Future<Holding?> getHoldingById(String id) =>
      (select(holdings)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<Holding>> watchAllHoldings() => select(holdings).watch();

  Future<int> updateHolding(HoldingsCompanion entry) =>
      (update(holdings)..where((t) => t.id.equals(entry.id.value)))
          .write(entry);


  Future<int> deleteAllHoldings() => delete(holdings).go();

  Future<int> deleteAllHoldingTransactions() =>
      delete(holdingTransactions).go();
  Future<int> deleteHoldingById(String id) =>
      (delete(holdings)..where((t) => t.id.equals(id))).go();

  Future<void> insertHoldingTransaction(HoldingTransactionsCompanion entry) =>
      into(holdingTransactions).insert(entry);

  /// F10 T2 fix(round 1):镜像 rebuild 专用 upsert —— pending pair 的台账
  /// 保留集含上一轮镜像写入的 server 台账行(server id),rebuild 再插同 id
  /// 撞 holding_transactions.id UNIQUE;改冲突覆盖(server 对 server-id 行
  /// 权威;离线 uuid 行 server 不含,永不冲突)。本地写路径仍走
  /// [insertHoldingTransaction]。
  Future<void> upsertHoldingTransaction(HoldingTransactionsCompanion entry) =>
      into(holdingTransactions).insertOnConflictUpdate(entry);

  Future<List<HoldingTransaction>> getAllHoldingTransactions() =>
      select(holdingTransactions).get();

  Stream<List<HoldingTransaction>> watchAllHoldingTransactions() =>
      select(holdingTransactions).watch();

  Future<HoldingTransaction?> getHoldingTransactionById(String id) =>
      (select(holdingTransactions)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Stream<List<HoldingTransaction>> watchTransactionsBySecurity(
          String securityId) =>
      (select(holdingTransactions)
            ..where((t) => t.securityId.equals(securityId)))
          .watch();

  // ---- F10 T2:syncState 支持(spec FR-3,design ADR-2/ADR-3) ----

  /// 镜像协调:delete-all 改为排除 pending(在线全 synced 等价 delete-all)。
  Future<int> deleteAllSyncedHoldings() =>
      (delete(holdings)
            ..where((t) => t.syncState.equals(SyncState.pending).not()))
          .go();

  /// 台账行无 syncState(子表):按 (account_id, security_id) 联动保留 ——
  /// pending 持仓的台账(离线买/卖/分红)不随镜像刷新抹掉,其余照常
  /// delete-all + rebuild。
  Future<void> deleteHoldingTransactionsOfSyncedHoldings() => customStatement(
      'DELETE FROM holding_transactions WHERE NOT EXISTS ('
      'SELECT 1 FROM holdings h WHERE h.account_id = '
      'holding_transactions.account_id AND h.security_id = '
      "holding_transactions.security_id AND h.sync_state = ?)",
      [SyncState.pending]);

  /// T3 收集器:一次性读待上行持仓头行。
  Future<List<Holding>> getPendingHoldings() =>
      (select(holdings)..where((t) => t.syncState.equals(SyncState.pending)))
          .get();

  /// T3 状态流(待同步计数):监听待上行持仓头行。
  Stream<List<Holding>> watchPendingHoldings() =>
      (select(holdings)..where((t) => t.syncState.equals(SyncState.pending)))
          .watch();

  /// F10 T3(fix round 1):上行成功回写 —— 批内实体 pending → synced,带
  /// **版本守卫**(仅当行当前 version 仍等于批次快照版本才回写,在途
  /// FR-1b 降级更新的行保持 pending 留下次上行;core 层不能 import binding
  /// 域 DTO,以 id→版本 Map 承载;T2 无此方法,T3 补)。
  ///
  /// F19-T1:OR 守卫按 [syncWritebackChunkSize] 分片逐句执行(SQLite 深嵌套
  /// OR 解析器栈溢出,见常量 doc);净效果与单句等价,返回影响行数求和。
  Future<int> markHoldingsSynced(Map<String, int> versionsById) async {
    if (versionsById.isEmpty) return 0;
    var updated = 0;
    for (final chunk
        in chunked(versionsById.entries, syncWritebackChunkSize)) {
      final guard = chunk
          .map(
              (e) => holdings.id.equals(e.key) & holdings.version.equals(e.value))
          .reduce((a, b) => a | b);
      updated += await (update(holdings)
            ..where((t) => guard & t.syncState.equals(SyncState.pending)))
          .write(const HoldingsCompanion(syncState: Value(SyncState.synced)));
    }
    return updated;
  }

  /// F19-T1(spec FR-2,design ADR-2):合并前全量标记 —— synced → pending,
  /// guest 期行由此进入 PendingCollector 通路(单条 UPDATE,非逐行)。仅动
  /// synced 行(pending 行原样),幂等;返回影响行数。guest 无墓碑(F10
  /// 语义:guest 删除不落墓碑),墓碑表无对应方法。
  Future<int> markAllPendingForSync() =>
      (update(holdings)..where((t) => t.syncState.equals(SyncState.synced)))
          .write(const HoldingsCompanion(syncState: Value(SyncState.pending)));
}
