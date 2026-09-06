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

/// F17-T2(spec FR-3,design ADR-3)拉取游标表:单行记录本地已拉尽的
/// sync_log 版本(页尾版本;`since` 入参)。游标选本地存储而非 server 设备
/// 行:读 server 行需 GetSyncStatus 往返,本地读写零成本且 since 错小 =
/// 幂等重拉无害(design ADR-3 论证)。清库/重装 → 默认 0 → 全量重拉,
/// 应用路径幂等(upsert 按 id / DELETE 幂等),无一致性风险。
class SyncCursors extends Table {
  /// 单行主键,恒 'sync'(DAO 封装,业务不触其他值)。
  TextColumn get id => text()();

  /// 已拉尽的最末 sync_log 版本(= PullChanges 请求的 since_version)。
  IntColumn get lastPulledVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
