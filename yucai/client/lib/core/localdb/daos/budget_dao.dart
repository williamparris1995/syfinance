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

  Future<int> deleteBudgetById(String id) =>
      (delete(budgets)..where((t) => t.id.equals(id))).go();

  Future<void> insertItem(BudgetItemsCompanion entry) =>
      into(budgetItems).insert(entry);

  Stream<List<BudgetItem>> watchItemsByBudget(String budgetId) =>
      (select(budgetItems)..where((t) => t.budgetId.equals(budgetId))).watch();
}
