/// F10 T3(spec FR-5,design ADR-5):回网同步 port 与批次 DTO —— binding 域
/// 的跨模块上行抽象。
///
/// 语义走向对齐休眠的 sync proto(`lib/proto/sync/v1/sync.pb.dart`):
/// - `PushChangesRequest{ repeated SyncPayload changes }`,每条 payload 为
///   `{entityType, operation(CREATE/UPDATE/DELETE), payload bytes, version,
///   deviceId, entityId}`;
/// - 本文件的 `SyncEntityDto` 即 upsert(实体 CREATE/UPDATE 合并:单设备
///   语义下同为「本地最新全量行」),`SyncTombstoneDto` 即 DELETE;
/// - F11 的 gRPC 实现把 `fields` 编码进 payload bytes、module 写入
///   entityType;本任务以 Map 承载字段,避免提前绑死 proto 编码。
library;

/// 单条上行实体 DTO:drift 头表行的快照(module+entityId 定位,version 为
/// 乐观锁版本,fields 为行裸值 —— 对齐 SyncPayload 的 entityType/entityId/
/// version/payload 语义走向;含 syncState 列,F11 编码时剔除)。
class SyncEntityDto {
  const SyncEntityDto({
    required this.module,
    required this.entityId,
    required this.version,
    required this.fields,
  });

  /// 值域 = [SyncModule] 常量(core/localdb/sync_state.dart,与 MirrorModule
  /// 枚举名逐字一致)。
  final String module;

  /// 实体 id(各模块头表主键)。
  final String entityId;

  /// 行乐观锁版本(SyncPayload.version 走向)。
  final int version;

  /// drift 行 toJson 快照(列名 → 值)。
  final Map<String, dynamic> fields;
}

/// 上行墓碑 DTO(离线删除,对齐 SyncOperation.DELETE)。
class SyncTombstoneDto {
  const SyncTombstoneDto({
    required this.module,
    required this.entityId,
    required this.deletedAt,
  });

  final String module;
  final String entityId;

  /// 本地删除时刻(server 侧最终一致用)。
  final DateTime deletedAt;
}

/// 一次回网上行的增量批次:各模块 pending 实体按模块分桶 + 墓碑集合。
class SyncBatch {
  const SyncBatch({
    required this.entitiesByModule,
    required this.tombstones,
  });

  /// 按模块分桶的 pending 实体(空桶不落 key)。
  final Map<String, List<SyncEntityDto>> entitiesByModule;

  /// 待上行的墓碑集合。
  final List<SyncTombstoneDto> tombstones;

  /// 空批次感知(无 pending 无墓碑)。
  bool get isEmpty => entitiesByModule.isEmpty && tombstones.isEmpty;

  /// 批次变更总数(实体 + 墓碑;即 syncing(n) 状态对外展示的 n)。
  int get changeCount =>
      entitiesByModule.values
          .fold<int>(0, (sum, list) => sum + list.length) +
      tombstones.length;

  /// 批次涉及的模块集合(实体与墓碑并集;成功后按此回写/清墓碑/刷新镜像)。
  Set<String> get modules =>
      {...entitiesByModule.keys, ...tombstones.map((t) => t.module)};
}

/// push 结果:成功 / 失败(含原因)。
///
/// 单设备语义下批次原子(F10 本地管线一次收集一次上行;F11 的
/// PushResponse.conflicts 部分冲突同样收敛为整体失败 + 原因,pending 保留
/// 待下次触发重试)。
class SyncResult {
  const SyncResult.success()
      : ok = true,
        reason = null;

  const SyncResult.failure(String this.reason) : ok = false;

  final bool ok;

  /// 失败原因(展示给 F12 UI / 日志)。
  final String? reason;
}

/// 回网上行 port(binding 域抽象,design ADR-5):SyncCoordinator 经此把
/// 增量批次推向 server。
///
/// **F11 替换点**:当前生产注册 NoopOfflineSyncPort(binding/data,保 pending
/// 的安全占位);F11 落 gRPC PushChanges 实现(fake 换真实现,协调器零改动)。
abstract class OfflineSyncPort {
  Future<SyncResult> push(SyncBatch batch);
}
