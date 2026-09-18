import 'package:drift/drift.dart';

import '../app_database.dart';
import '../sync_state.dart'
    show SyncState, chunked, syncWritebackChunkSize;
import '../tables/debt_tables.dart';

part 'debt_dao.g.dart';

@DriftAccessor(tables: [Debts, PaymentScheduleEntries])
class DebtDao extends DatabaseAccessor<AppDatabase> with _$DebtDaoMixin {
  DebtDao(super.db);

  Future<void> insertDebt(DebtsCompanion entry) => into(debts).insert(entry);

  Future<Debt?> getDebtById(String id) =>
      (select(debts)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<Debt>> watchAllDebts() => select(debts).watch();

  Future<int> updateDebt(DebtsCompanion entry) =>
      (update(debts)..where((t) => t.id.equals(entry.id.value))).write(entry);


  Future<int> deleteAllDebts() => delete(debts).go();

  Future<int> deleteAllSchedule() => delete(paymentScheduleEntries).go();
  Future<int> deleteDebtById(String id) =>
      (delete(debts)..where((t) => t.id.equals(id))).go();

  Future<void> insertScheduleEntry(PaymentScheduleEntriesCompanion entry) =>
      into(paymentScheduleEntries).insert(entry);

  /// 删除单个期次行(周期规则编辑重排:未冻结期次逐条删除)。
  Future<int> deleteScheduleEntry(String id) =>
      (delete(paymentScheduleEntries)..where((t) => t.id.equals(id))).go();

  Stream<List<PaymentScheduleEntry>> watchScheduleByDebt(String debtId) =>
      (select(paymentScheduleEntries)
            ..where((t) => t.debtId.equals(debtId)))
          .watch();

  /// One-shot read for the seam's assembly paths.
  Future<List<PaymentScheduleEntry>> getScheduleByDebt(String debtId) =>
      (select(paymentScheduleEntries)
            ..where((t) => t.debtId.equals(debtId)))
          .get();

  Future<PaymentScheduleEntry?> getScheduleEntryById(String id) =>
      (select(paymentScheduleEntries)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<int> updateScheduleEntry(PaymentScheduleEntriesCompanion entry) =>
      (update(paymentScheduleEntries)
            ..where((t) => t.id.equals(entry.id.value)))
          .write(entry);

  // ---- F10 T2:syncState 支持(spec FR-3,design ADR-2/ADR-3) ----

  /// 镜像协调:delete-all 改为排除 pending(在线全 synced 等价 delete-all);
  /// 非 pending 头行删除时其期次经 FK 级联清除(pending 债务的离线还款
  /// 事实保留)。
  Future<int> deleteAllSyncedDebts() =>
      (delete(debts)
            ..where((t) => t.syncState.equals(SyncState.pending).not()))
          .go();

  /// 兜底清非 pending 债务的期次(pending 头行的期次保留);正常路径由
  /// FK 级联完成,悬挂行防御。
  Future<void> deleteScheduleOfSyncedDebts() => customStatement(
      'DELETE FROM payment_schedule_entries WHERE debt_id NOT IN '
      '(SELECT id FROM debts WHERE sync_state = ?)',
      [SyncState.pending]);

  /// T3 收集器:一次性读待上行债务头行。
  Future<List<Debt>> getPendingDebts() =>
      (select(debts)..where((t) => t.syncState.equals(SyncState.pending)))
          .get();

  /// T3 状态流(待同步计数):监听待上行债务头行。
  Stream<List<Debt>> watchPendingDebts() =>
      (select(debts)..where((t) => t.syncState.equals(SyncState.pending)))
          .watch();

  /// F10 T3(fix round 1):上行成功回写 —— 批内实体 pending → synced,带
  /// **版本守卫**(仅当行当前 version 仍等于批次快照版本才回写,在途
  /// FR-1b 降级更新的行保持 pending 留下次上行;core 层不能 import binding
  /// 域 DTO,以 id→版本 Map 承载;T2 无此方法,T3 补)。
  ///
  /// F19-T1:OR 守卫按 [syncWritebackChunkSize] 分片逐句执行(SQLite 深嵌套
  /// OR 解析器栈溢出,见常量 doc);净效果与单句等价,返回影响行数求和。
  Future<int> markDebtsSynced(Map<String, int> versionsById) async {
    if (versionsById.isEmpty) return 0;
    var updated = 0;
    for (final chunk
        in chunked(versionsById.entries, syncWritebackChunkSize)) {
      final guard = chunk
          .map((e) => debts.id.equals(e.key) & debts.version.equals(e.value))
          .reduce((a, b) => a | b);
      updated += await (update(debts)
            ..where((t) => guard & t.syncState.equals(SyncState.pending)))
          .write(const DebtsCompanion(syncState: Value(SyncState.synced)));
    }
    return updated;
  }

  /// F19-T1(spec FR-2,design ADR-2):合并前全量标记 —— synced → pending,
  /// guest 期行由此进入 PendingCollector 通路(单条 UPDATE,非逐行)。仅动
  /// synced 行(pending 行原样),幂等;返回影响行数。guest 无墓碑(F10
  /// 语义:guest 删除不落墓碑),墓碑表无对应方法。
  Future<int> markAllPendingForSync() =>
      (update(debts)..where((t) => t.syncState.equals(SyncState.synced)))
          .write(const DebtsCompanion(syncState: Value(SyncState.pending)));
}
