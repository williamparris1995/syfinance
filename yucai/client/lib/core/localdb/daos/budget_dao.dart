import 'package:drift/drift.dart';

import '../app_database.dart';
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
}
