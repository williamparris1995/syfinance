// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_dao.dart';

// ignore_for_file: type=lint
mixin _$BudgetDaoMixin on DatabaseAccessor<AppDatabase> {
  $BudgetsTable get budgets => attachedDatabase.budgets;
  $BudgetItemsTable get budgetItems => attachedDatabase.budgetItems;
  BudgetDaoManager get managers => BudgetDaoManager(this);
}

class BudgetDaoManager {
  final _$BudgetDaoMixin _db;
  BudgetDaoManager(this._db);
  $$BudgetsTableTableManager get budgets =>
      $$BudgetsTableTableManager(_db.attachedDatabase, _db.budgets);
  $$BudgetItemsTableTableManager get budgetItems =>
      $$BudgetItemsTableTableManager(_db.attachedDatabase, _db.budgetItems);
}
