import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sync_tables.dart';

part 'sync_tombstone_dao.g.dart';

/// F10 T2 墓碑 DAO(spec FR-4,design ADR-4):绑定路由删除的实体墓碑写入/
/// 查询/清除。上行成功后由 T3 协调器清对应墓碑;clearAll 供调试/全量重传
/// 场景。
@DriftAccessor(tables: [SyncTombstones])
class SyncTombstoneDao extends DatabaseAccessor<AppDatabase>
    with _$SyncTombstoneDaoMixin {
  SyncTombstoneDao(super.db);

  /// 幂等写入:同 (module, entityId) 重复删除覆盖 deletedAt(主键 upsert)。
  Future<void> upsertTombstone(SyncTombstonesCompanion entry) =>
      into(syncTombstones).insertOnConflictUpdate(entry);

  Future<List<SyncTombstone>> getAllTombstones() =>
      select(syncTombstones).get();

  /// T3 收集器:按模块取墓碑集合(随增量批次上行)。
  Future<List<SyncTombstone>> getTombstonesByModule(String module) =>
      (select(syncTombstones)..where((t) => t.module.equals(module))).get();

  /// 上行成功后清除该实体墓碑。
  Future<int> clearTombstone(String module, String entityId) =>
      (delete(syncTombstones)
            ..where((t) =>
                t.module.equals(module) & t.entityId.equals(entityId)))
          .go();

  /// 清空全部墓碑(全量重传后/T3 调试)。
  Future<int> clearAllTombstones() => delete(syncTombstones).go();
}
