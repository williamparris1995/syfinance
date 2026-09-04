import 'package:drift/drift.dart';

/// F10 离线删除墓碑表(spec FR-4,design ADR-4):绑定态路由的删除在本地
/// 硬删行之外补一条墓碑 —— 无墓碑则下一次镜像 delete-all+rebuild 会把已删
/// 行复活;上行成功后由同步协调器清除(T3)。guest 删除不写墓碑(绑定走
/// 全量首传,ADR-4)。
///
/// module 取值见 `sync_state.dart` 的 [SyncModule](与 MirrorModule 枚举名
/// 逐字一致)。
class SyncTombstones extends Table {
  /// 值域:SyncModule 常量(account/transaction/debt/budget/goal/holding/
  /// tag/template)。
  TextColumn get module => text()();

  /// 被删实体 id(各模块头表主键)。
  TextColumn get entityId => text()();

  /// 本地删除时刻(上行批次可带上,server 侧最终一致用)。
  DateTimeColumn get deletedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {module, entityId};
}
