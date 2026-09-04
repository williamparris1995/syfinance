import 'package:drift/drift.dart';

import '../app_database.dart';
import '../sync_state.dart' show SyncState;
import '../tables/budget_tables.dart';

part 'budget_dao.g.dart';

@DriftAccessor(tables: [Budgets, BudgetItems])
class BudgetDao extends DatabaseAccessor<AppDatabase> with _$BudgetDaoMixin {
  BudgetDao(super.db);

  Future<void> insertBudget(BudgetsCompanion entry) =>
      into(budgets).insert(entry);

  Future<Budget?> getBudgetById(String id) =>
      (select(budgets)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<Budget>> watchAllBudgets() => select(budgets).watch();

  Future<int> updateBudget(BudgetsCompanion entry) =>
      (update(budgets)..where((t) => t.id.equals(entry.id.value))).write(entry);


  Future<int> deleteAllBudgets() => delete(budgets).go();

  Future<int> deleteAllItems() => delete(budgetItems).go();
  Future<int> deleteBudgetById(String id) =>
      (delete(budgets)..where((t) => t.id.equals(id))).go();

  Future<void> insertItem(BudgetItemsCompanion entry) =>
      into(budgetItems).insert(entry);

  Stream<List<BudgetItem>> watchItemsByBudget(String budgetId) =>
      (select(budgetItems)..where((t) => t.budgetId.equals(budgetId))).watch();

  /// One-shot read for the seam's detail assembly.
  Future<List<BudgetItem>> getItemsByBudget(String budgetId) =>
      (select(budgetItems)..where((t) => t.budgetId.equals(budgetId))).get();

  /// Whole-entry-set replacement for updateBudget (design ADR-3).
  Future<int> deleteItemsByBudget(String budgetId) =>
      (delete(budgetItems)..where((t) => t.budgetId.equals(budgetId))).go();

  Future<int> deleteItemById(String id) =>
      (delete(budgetItems)..where((t) => t.id.equals(id))).go();

  // ---- F10 T2:syncState 支持(spec FR-3,design ADR-2/ADR-3) ----

  /// 镜像协调:delete-all 改为排除 pending(在线全 synced 等价 delete-all);
  /// 非 pending 头行删除时其预算项经 FK 级联清除。
  Future<int> deleteAllSyncedBudgets() =>
      (delete(budgets)
            ..where((t) => t.syncState.equals(SyncState.pending).not()))
          .go();

  /// 兜底清非 pending 预算的预算项(pending 头行的项保留);正常路径由
  /// FK 级联完成,悬挂行防御。
  Future<void> deleteItemsOfSyncedBudgets() => customStatement(
      'DELETE FROM budget_items WHERE budget_id NOT IN '
      '(SELECT id FROM budgets WHERE sync_state = ?)',
      [SyncState.pending]);

  /// T3 收集器:一次性读待上行预算头行。
  Future<List<Budget>> getPendingBudgets() =>
      (select(budgets)..where((t) => t.syncState.equals(SyncState.pending)))
          .get();

  /// T3 状态流(待同步计数):监听待上行预算头行。
  Stream<List<Budget>> watchPendingBudgets() =>
      (select(budgets)..where((t) => t.syncState.equals(SyncState.pending)))
          .watch();
}
