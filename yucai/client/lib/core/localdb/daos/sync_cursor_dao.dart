import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sync_tables.dart';

part 'sync_cursor_dao.g.dart';

/// F17-T2(spec FR-3,design ADR-3)拉取游标 DAO:sync_cursor 单行读写。
/// 恒定主键 'sync'(单行);读缺省 = 0(since=0 全量重拉,应用幂等无害);
/// 写 = 主键 upsert 覆盖。协调器 `_pullAndApply` 的唯一消费者。
@DriftAccessor(tables: [SyncCursors])
class SyncCursorDao extends DatabaseAccessor<AppDatabase>
    with _$SyncCursorDaoMixin {
  SyncCursorDao(super.db);

  /// 游标单行主键(表内恒此一行)。
  static const _singleRowId = 'sync';

  /// 读已拉尽的最末 sync_log 版本;未写入(新库/清库)返回 0。
  Future<int> readLastPulledVersion() async {
    final row = await (select(syncCursors)
          ..where((t) => t.id.equals(_singleRowId)))
        .getSingleOrNull();
    return row?.lastPulledVersion ?? 0;
  }

  /// 覆盖写游标(主键 upsert;分页逐页推进,页尾版本见协调器注释)。
  Future<void> writeLastPulledVersion(int version) async {
    await into(syncCursors).insertOnConflictUpdate(
        SyncCursorsCompanion.insert(
            id: _singleRowId, lastPulledVersion: Value(version)));
  }
}
