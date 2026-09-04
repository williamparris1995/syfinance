import 'package:drift/drift.dart';

import '../app_database.dart';
import '../sync_state.dart' show SyncState;
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
}
