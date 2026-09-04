// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_tombstone_dao.dart';

// ignore_for_file: type=lint
mixin _$SyncTombstoneDaoMixin on DatabaseAccessor<AppDatabase> {
  $SyncTombstonesTable get syncTombstones => attachedDatabase.syncTombstones;
  SyncTombstoneDaoManager get managers => SyncTombstoneDaoManager(this);
}

class SyncTombstoneDaoManager {
  final _$SyncTombstoneDaoMixin _db;
  SyncTombstoneDaoManager(this._db);
  $$SyncTombstonesTableTableManager get syncTombstones =>
      $$SyncTombstonesTableTableManager(
        _db.attachedDatabase,
        _db.syncTombstones,
      );
}
