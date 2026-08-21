// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'debt_dao.dart';

// ignore_for_file: type=lint
mixin _$DebtDaoMixin on DatabaseAccessor<AppDatabase> {
  $DebtsTable get debts => attachedDatabase.debts;
  $PaymentScheduleEntriesTable get paymentScheduleEntries =>
      attachedDatabase.paymentScheduleEntries;
  DebtDaoManager get managers => DebtDaoManager(this);
}

class DebtDaoManager {
  final _$DebtDaoMixin _db;
  DebtDaoManager(this._db);
  $$DebtsTableTableManager get debts =>
      $$DebtsTableTableManager(_db.attachedDatabase, _db.debts);
  $$PaymentScheduleEntriesTableTableManager get paymentScheduleEntries =>
      $$PaymentScheduleEntriesTableTableManager(
        _db.attachedDatabase,
        _db.paymentScheduleEntries,
      );
}
