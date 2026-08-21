// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reference_dao.dart';

// ignore_for_file: type=lint
mixin _$ReferenceDaoMixin on DatabaseAccessor<AppDatabase> {
  $CurrenciesTable get currencies => attachedDatabase.currencies;
  $RateHistoriesTable get rateHistories => attachedDatabase.rateHistories;
  $SecuritiesTable get securities => attachedDatabase.securities;
  $SecurityPriceHistoriesTable get securityPriceHistories =>
      attachedDatabase.securityPriceHistories;
  ReferenceDaoManager get managers => ReferenceDaoManager(this);
}

class ReferenceDaoManager {
  final _$ReferenceDaoMixin _db;
  ReferenceDaoManager(this._db);
  $$CurrenciesTableTableManager get currencies =>
      $$CurrenciesTableTableManager(_db.attachedDatabase, _db.currencies);
  $$RateHistoriesTableTableManager get rateHistories =>
      $$RateHistoriesTableTableManager(_db.attachedDatabase, _db.rateHistories);
  $$SecuritiesTableTableManager get securities =>
      $$SecuritiesTableTableManager(_db.attachedDatabase, _db.securities);
  $$SecurityPriceHistoriesTableTableManager get securityPriceHistories =>
      $$SecurityPriceHistoriesTableTableManager(
        _db.attachedDatabase,
        _db.securityPriceHistories,
      );
}
