/// F10 T3(spec FR-5,design ADR-5):回网同步 port 与批次 DTO —— binding 域
/// 的跨模块上行抽象。
///
/// 语义对齐休眠的 sync proto(`lib/proto/sync/v1/sync.pb.dart`):
/// - `PushChangesRequest{ repeated SyncPayload changes }`,每条 payload 为
///   `{entityType, operation(CREATE/UPDATE/DELETE), payload bytes, version,
///   deviceId, entityId}`;
/// - 本文件的 `SyncEntityDto` 即 upsert(实体 CREATE/UPDATE 合并:单设备
///   语义下同为「本地最新全量行」),`SyncTombstoneDto` 即 DELETE;
/// - F11 已落地 gRPC 实现(GrpcOfflineSyncPort):`fields` 编码进 payload
///   bytes(jsonEncode)、module 写入 entityType、CREATE 表 upsert 语义;
/// - F17-T1(FR-2/ADR-1):deviceId 来源 = 安装级 clientId
///   (TokenStorage.readClientId 的函数缝,见 [ClientIdProvider]);新增
///   [OfflineSyncPort.registerDevice](绑定流程幂等注册设备行);
/// - F17-T1(FR-5/ADR-5):push 结果携带 [SyncResult.conflicts](server
///   PushResponse.conflicts 的最小映射;解决流留给 F18)。
library;

/// 设备身份来源缝(FR-2/ADR-1):`() => clientId`(TokenStorage.readClientId
/// 的 tear-off 形态)。
///
/// 选函数 typedef 而非注入 TokenStorage 具体类/自定义接口,照库内 DI 惯例
/// (injection.dart 的 UrlLauncherFn、AuthInterceptor.tokenReader 均为函数
/// 缝):DI 组合根接线 `getIt<TokenStorage>().readClientId`,binding 域零
/// 对 auth/data 的跨模块 import(消费方不 import 生产方);测试/e2e 直接
/// 传闭包或覆写 TokenStorage。
typedef ClientIdProvider = Future<String?> Function();

/// 单条上行实体 DTO:待上行头表的 server 兼容行快照(module+entityId 定位,
/// version 为乐观锁版本 —— 对齐 SyncPayload 的 entityType/entityId/version/
/// payload 语义)。
///
/// **F11 T3 起的 `fields` 语义**:PendingCollector 经 core/localdb 的
/// envelope_codec(与备份导出共享的行序列化单一事实源,ADR-2)产出的
/// PascalCase 行形态 —— 子表随头行嵌套、时间戳 RFC3339 Z、无 tenant 键、
/// 无 syncState 本地私有列;`fields['ID']` 与 [entityId] 同源 drift 主键。
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

  /// server 兼容行快照(envelope_codec 产出;形态见类 doc)。
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

/// 一条上行冲突(FR-5/ADR-5 最小面):server `PushResponse.conflicts` 里
/// ConflictDTO 的三个关键字段。**不含** server/client payload 与 resolution
/// —— 解决流是 F18 的面,这里只携带「哪个模块的哪个实体、什么冲突类型」
/// 供协调器状态透传(F12 badge / F18 面板消费)。
class SyncConflictInfo {
  const SyncConflictInfo({
    required this.module,
    required this.entityId,
    required this.conflictType,
  });

  /// 冲突实体模块(= SyncModule 常量;proto entityType)。
  final String module;

  /// 冲突实体 id。
  final String entityId;

  /// 冲突类型(F16 起值域:"version_conflict";细化分类随 F18)。
  final String conflictType;
}

/// push 结果:成功 / 失败(含原因)。
///
/// 单设备语义下批次原子(F10 本地管线一次收集一次上行)。F17-T1(FR-5/
/// ADR-5)成功态新增 [conflicts]:**ok 语义不变** —— conflicts 非空仍视为
/// 成功(单设备 server 恒空;多设备下信息已携带,批次上行本身落库),仅
/// 状态面多带一份数据(解决流 F18)。既有 `const SyncResult.success()`
/// 调用点零改动(conflicts 默认空)。
class SyncResult {
  const SyncResult.success({this.conflicts = const []})
      : ok = true,
        reason = null;

  const SyncResult.failure(String this.reason)
      : ok = false,
        conflicts = const [];

  final bool ok;

  /// 失败原因(展示给 F12 UI / 日志)。
  final String? reason;

  /// push 命中的冲突详情(成功态携带;失败态恒空)。
  final List<SyncConflictInfo> conflicts;

  /// 冲突条数(= conflicts.length;协调器状态透传的计数形态)。
  int get conflictCount => conflicts.length;
}

/// 回网上行 port(binding 域抽象,design ADR-5):SyncCoordinator 经此把
/// 增量批次推向 server。
///
/// **F11 已接线**:生产注册 GrpcOfflineSyncPort(binding/data,gRPC
/// PushChanges 实现);NoopOfflineSyncPort 保留作测试替身/参考。
abstract class OfflineSyncPort {
  Future<SyncResult> push(SyncBatch batch);

  /// 设备注册(FR-2/ADR-1):deviceId 由实现自取 clientId(见
  /// [ClientIdProvider]),deviceName 由调用方给(绑定流程传平台名)。
  /// server 侧按非空 device_id 幂等(重复注册返回既有设备行)——失败抛出,
  /// 由调用方(BindingBloc)fire-and-forget 容错。
  Future<void> registerDevice(String deviceName);
}
