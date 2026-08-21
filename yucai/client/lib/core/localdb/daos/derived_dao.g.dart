// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'derived_dao.dart';

// ignore_for_file: type=lint
mixin _$DerivedDaoMixin on DatabaseAccessor<AppDatabase> {
  $DebtProgressSnapshotsTable get debtProgressSnapshots =>
      attachedDatabase.debtProgressSnapshots;
  $GoalProgressSnapshotsTable get goalProgressSnapshots =>
      attachedDatabase.goalProgressSnapshots;
  $HoldingSnapshotsTable get holdingSnapshots =>
      attachedDatabase.holdingSnapshots;
  $HoldingLotsTable get holdingLots => attachedDatabase.holdingLots;
  DerivedDaoManager get managers => DerivedDaoManager(this);
}

class DerivedDaoManager {
  final _$DerivedDaoMixin _db;
  DerivedDaoManager(this._db);
  $$DebtProgressSnapshotsTableTableManager get debtProgressSnapshots =>
      $$DebtProgressSnapshotsTableTableManager(
        _db.attachedDatabase,
        _db.debtProgressSnapshots,
      );
  $$GoalProgressSnapshotsTableTableManager get goalProgressSnapshots =>
      $$GoalProgressSnapshotsTableTableManager(
        _db.attachedDatabase,
        _db.goalProgressSnapshots,
      );
  $$HoldingSnapshotsTableTableManager get holdingSnapshots =>
      $$HoldingSnapshotsTableTableManager(
        _db.attachedDatabase,
        _db.holdingSnapshots,
      );
  $$HoldingLotsTableTableManager get holdingLots =>
      $$HoldingLotsTableTableManager(_db.attachedDatabase, _db.holdingLots);
}
