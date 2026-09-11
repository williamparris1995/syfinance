import 'package:drift/drift.dart';

import '../app_database.dart';
import '../sync_state.dart'
    show SyncState, chunked, syncWritebackChunkSize;
import '../tables/account_tables.dart';

part 'account_dao.g.dart';

/// DAO boundary = backup module boundary (design ADR-4): the seam in feature C
/// wires repositories to these accessors.
@DriftAccessor(tables: [Accounts, ChartOfAccounts])
class AccountDao extends DatabaseAccessor<AppDatabase> with _$AccountDaoMixin {
  AccountDao(super.db);

  Future<void> insertAccount(AccountsCompanion entry) =>
      into(accounts).insert(entry);

  Future<Account?> getAccountById(String id) =>
      (select(accounts)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<Account>> watchAllAccounts() => select(accounts).watch();

  /// One-shot read for non-reactive callers (seam list paths).
  Future<List<Account>> getAllAccounts() => select(accounts).get();

  Future<int> updateAccount(AccountsCompanion entry) =>
      (update(accounts)..where((t) => t.id.equals(entry.id.value))).write(entry);


  Future<int> deleteAllAccounts() => delete(accounts).go();
  Future<int> deleteAccountById(String id) =>
      (delete(accounts)..where((t) => t.id.equals(id))).go();

  // ---- F10 T2:syncState 支持(spec FR-3,design ADR-2/ADR-3) ----

  /// 镜像协调:镜像 delete-all 改为排除 pending —— 在线全 synced 场景无
  /// pending 行,条件对 synced 行等价于 delete-all(行为逐位不变)。
  Future<int> deleteAllSyncedAccounts() =>
      (delete(accounts)
            ..where((t) => t.syncState.equals(SyncState.pending).not()))
          .go();

  /// T3 收集器:一次性读待上行行。
  Future<List<Account>> getPendingAccounts() =>
      (select(accounts)..where((t) => t.syncState.equals(SyncState.pending)))
          .get();

  /// T3 状态流(待同步计数):监听待上行行。
  Stream<List<Account>> watchPendingAccounts() =>
      (select(accounts)..where((t) => t.syncState.equals(SyncState.pending)))
          .watch();

  /// F10 T3(fix round 1):上行成功回写 —— 批内实体 pending → synced,带
  /// **版本守卫**:仅当行当前 version 仍等于批次快照版本才回写。push 在途
  /// 期间行被 FR-1b 再次降级更新(置 pending+版本推进)时,陈旧快照不把它
  /// 误标 synced(该行保持 pending 留下次上行)。形态说明:core 层不能
  /// import binding 域的 SyncEntityDto(依赖方向),以 id→版本 Map 承载
  /// 守卫所需最小信息;条件仍限定 pending,重复回写幂等。
  ///
  /// F19-T1:OR 守卫按 [syncWritebackChunkSize] 分片逐句执行(SQLite 深嵌套
  /// OR 解析器栈溢出,见常量 doc);净效果与单句等价,返回影响行数求和。
  Future<int> markAccountsSynced(Map<String, int> versionsById) async {
    if (versionsById.isEmpty) return 0;
    var updated = 0;
    for (final chunk
        in chunked(versionsById.entries, syncWritebackChunkSize)) {
      final guard = chunk
          .map((e) =>
              accounts.id.equals(e.key) & accounts.version.equals(e.value))
          .reduce((a, b) => a | b);
      updated += await (update(accounts)
            ..where((t) => guard & t.syncState.equals(SyncState.pending)))
          .write(const AccountsCompanion(syncState: Value(SyncState.synced)));
    }
    return updated;
  }

  /// F19-T1(spec FR-2,design ADR-2):合并前全量标记 —— synced → pending,
  /// guest 期行由此进入 PendingCollector 通路(单条 UPDATE,非逐行)。仅动
  /// synced 行(pending 行原样),幂等;返回影响行数。guest 无墓碑(F10
  /// 语义:guest 删除不落墓碑),墓碑表无对应方法。
  Future<int> markAllPendingForSync() =>
      (update(accounts)..where((t) => t.syncState.equals(SyncState.synced)))
          .write(const AccountsCompanion(syncState: Value(SyncState.pending)));

  // Chart of accounts (local-owned reference).
  Future<void> insertChartOfAccount(ChartOfAccountsCompanion entry) =>
      into(chartOfAccounts).insert(entry);

  Stream<List<ChartOfAccount>> watchAllChartOfAccounts() =>
      select(chartOfAccounts).watch();
}
