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
///   PushResponse.conflicts 的最小映射;解决流留给 F18);
/// - F17-T2(FR-3/ADR-3):新增下行 [OfflineSyncPort.pull] + [PullBatch]/
///   [PulledChange](sync_log 重放面的原始 payload 流;游标编排归协调器);
/// - F18-T2(FR-2/FR-5,ADR-2/ADR-6):[SyncConflictInfo] 扩 conflictId+双
///   payload+createdAt(ConflictDTO 7+1 字段全解码);新增冲突解决面
///   [OfflineSyncPort.listConflicts]/[OfflineSyncPort.resolveConflict]
///   (协调器不消费 —— F18 冲突面板 bloc 的数据源,权威计数=ListConflicts)。
library;

import 'dart:typed_data';

import 'package:equatable/equatable.dart';

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

/// 一条上行冲突:server `PushResponse.conflicts` / `ListConflicts` 里
/// ConflictDTO 的完整映射。
///
/// 演进:F17-T1 最小面只携带 module/entityId/conflictType 三键(状态透传);
/// **F18-T2(FR-2,ADR-2)扩全量字段** —— conflictId(解决流 ResolveConflict
/// 的定位键)、serverPayload/clientPayload(envelope 行 JSON bytes,面板
/// 双栏对照解码)、createdAt(冲突记录时刻,面板最新序排序)。新字段全部
/// 可选命名参数:F17 时代的构造点(测试替身/无 server 冲突面的场景)零改动。
///
/// 值相等(Equatable):协调器 state 经 Equatable 去重时列表按元素 == 深比
/// (Uint8List 为恒等 ==,仅影响等值发射去重的精度,不影响正确性)。
class SyncConflictInfo extends Equatable {
  const SyncConflictInfo({
    required this.module,
    required this.entityId,
    required this.conflictType,
    this.conflictId,
    this.serverPayload,
    this.clientPayload,
    this.createdAt,
  });

  /// 冲突实体模块(= SyncModule 常量;proto entityType)。
  final String module;

  /// 冲突实体 id。
  final String entityId;

  /// 冲突类型(F16 起值域:"version_conflict";细化分类随 F18)。
  final String conflictType;

  /// 冲突记录 id(server ConflictDTO.id;ResolveConflict 的定位键;push
  /// 响应与 ListConflicts 均携带 —— F18-T2 起恒有值,可选仅为 F17 兼容)。
  final String? conflictId;

  /// 服务端版本 payload(envelope 行 JSON bytes;面板「服务端版本」栏)。
  final Uint8List? serverPayload;

  /// 客户端版本 payload(envelope 行 JSON bytes;面板「我的版本」栏;解决
  /// 「保留我的」时 server 侧落库的内容即此份)。
  final Uint8List? clientPayload;

  /// 冲突记录时刻(server created_at;面板最新序排序;缺省 null)。
  final DateTime? createdAt;

  @override
  List<Object?> get props =>
      [module, entityId, conflictType, conflictId, serverPayload, clientPayload, createdAt];
}

/// 一页待解决冲突(F18-T2 FR-5/ADR-6):ListConflicts 的 keyset 分页结果。
///
/// 分工注释:协调器 push 后**不**异步拉 ListConflicts 刷新状态(最小面 ——
/// push 响应携带的 conflicts 已够 badge 计数);**权威计数 = ListConflicts 的
/// [totalCount]**,由 F18 冲突面板 bloc 自己拉取/翻页/解决后重取(协调器
/// 与面板两消费方各取所需,不重复拉)。
class ConflictPage {
  const ConflictPage({
    required this.items,
    required this.totalCount,
    this.nextPageToken,
  });

  /// 本页冲突条目(server 按 created_at DESC,id DESC 最新序)。
  final List<SyncConflictInfo> items;

  /// 待解决冲突总数(权威计数;跨页恒定)。
  final int totalCount;

  /// 下一页游标(空/最后一页 = null;透传回 [OfflineSyncPort.listConflicts])。
  final String? nextPageToken;
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

/// 一条下行变更(F17-T2 FR-3/ADR-3):server sync_log 重放面的**原始
/// payload 流**条目 —— port 不解码 payload(envelope 行 JSON 的 decode 与
/// drift 应用归 PullApplier,单一职责),只拆出编排需要的元数据。
class PulledChange {
  const PulledChange({
    required this.module,
    required this.entityId,
    required this.isDelete,
    required this.payload,
    required this.logVersion,
    required this.deviceId,
  });

  /// 模块(entityType;值域 = SyncModule 常量,含 holding_ledger)。
  final String module;

  /// 实体 id。
  final String entityId;

  /// 是否 DELETE(墓碑下行;payload 为空)。
  final bool isDelete;

  /// 原始 payload bytes(CREATE/UPDATE = envelope 行 jsonEncode;DELETE 空)。
  final Uint8List payload;

  /// **sync_log 版本**(tenant 单调递增,分页游标)—— 注意与上行
  /// SyncEntityDto.version(实体乐观锁版本)语义不同:pull 面的 wire
  /// version 字段载的是日志版本(server PayloadToDTO 直传 entry.Version)。
  final int logVersion;

  /// 来源设备(push 时的 deviceId;协调器 own-echo 过滤用 —— 自设备的
  /// 推送回声不回灌应用,防墓碑回写死循环,见协调器注释)。
  final String deviceId;
}

/// 一页拉取结果(FR-3/ADR-3):changes 按 logVersion 升序(server 契约:
/// 客户端必须按序应用);[latestVersion] = tenant log frontier(**非**页内
/// 游标);[hasMore] = 是否仍有更早于 frontier 的条目 —— 续拉用
/// since = 本页最末条目的 logVersion(非 latestVersion,server ADR-3)。
class PullBatch {
  const PullBatch({
    required this.changes,
    required this.latestVersion,
    required this.hasMore,
  });

  final List<PulledChange> changes;
  final int latestVersion;
  final bool hasMore;
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

  /// 拉取一页变更(F17-T2 FR-3/ADR-3):sinceVersion 起的 sync_log 重放
  /// (entityTypes/pageSize 可选过滤,server 缺省 500/上限 1000)。
  ///
  /// **失败抛出**(与 push 的结果形态不同):调用方是协调器的
  /// 失败容忍编排(拉失败 log 后照常 push,不破状态),异常即「本页没拉
  /// 到、游标不动」——幂等重拉无害(since 不变,下次触发重试)。
  Future<PullBatch> pull(int sinceVersion,
      {List<String>? entityTypes, int? pageSize});

  /// 拉一页待解决冲突(F18-T2 FR-5/ADR-6):server ListConflicts 的 keyset
  /// 分页(created_at DESC 最新序;[pageToken] 透传续页,首页 null;server
  /// 缺省页大小 20)。
  ///
  /// **失败抛出**(同 [pull] 契约):调用方是 F18 冲突面板 bloc(自行收敛
  /// 为加载失败态);协调器不消费此方法(分工见 [ConflictPage] doc)。
  Future<ConflictPage> listConflicts({String? pageToken});

  /// 解决一条冲突(F18-T2 FR-3/ADR-3):[resolution] 值域 "server"|"client"
  /// (v1 二选一;"merged" 通道 proto/API 保留,[mergedPayload] 仅该分支消费,
  /// server 空校验 fail-closed)。
  ///
  /// 语义(server 侧 T1 落地):server → 仅标记(服务端行已权威);client/
  /// merged → 落库 + 写 sync_log(败方设备经 pull 收敛)。**失败抛出**(同
  /// [pull]):调用方(面板 bloc)自行收敛;成功无返回体。
  Future<void> resolveConflict(String conflictId, String resolution,
      {List<int>? mergedPayload});
}
