// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'holding_dao.dart';

// ignore_for_file: type=lint
mixin _$HoldingDaoMixin on DatabaseAccessor<AppDatabase> {
  $HoldingsTable get holdings => attachedDatabase.holdings;
  $HoldingTransactionsTable get holdingTransactions =>
      attachedDatabase.holdingTransactions;
  HoldingDaoManager get managers => HoldingDaoManager(this);
}

class HoldingDaoManager {
  final _$HoldingDaoMixin _db;
  HoldingDaoManager(this._db);
  $$HoldingsTableTableManager get holdings =>
      $$HoldingsTableTableManager(_db.attachedDatabase, _db.holdings);
  $$HoldingTransactionsTableTableManager get holdingTransactions =>
      $$HoldingTransactionsTableTableManager(
        _db.attachedDatabase,
        _db.holdingTransactions,
      );
}
