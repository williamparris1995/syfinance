import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';

import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/proto/common/v1/pagination.pb.dart' as common;
import 'package:yucai_client/proto/sync/v1/sync.pb.dart' as pb;
import 'package:yucai_client/proto/sync/v1/sync.pbgrpc.dart' as grpc;

/// F11 T3(spec FR-4,design ADR-5):OfflineSyncPort 的 gRPC PushChanges
/// 生产实现,替换 NoopOfflineSyncPort 的 DI 注册(injection.dart 1h)。
///
/// 接线形态照各 remote data source:持有 GrpcClient(通道 + AuthInterceptor)
/// 与 AuthRetryCaller(401 透明刷新 + 单次重试),RPC 经
/// `_retry.call(() => _client.pushChanges(req))` 发出。
///
/// 编码契约(wire 形态由 server T2 集成测试钉死,client 侧断言见本类测试):
/// - 实体 → `SyncPayload{entityType: module 常量, operation: CREATE|UPDATE
///   (F18-T2 按 version 区分,见 [encodeRequest]), payload: envelope 行
///   jsonEncode bytes, version, deviceId, entityId}`;
/// - payload 内容 = collector 经 envelope_codec 产出的 server 兼容行
///   (PascalCase/int 枚举/RFC3339 Z/子表嵌套/无 tenant 键)——单一事实源,
///   与备份导出共用同一份映射(ADR-2)。
/// - **payload 内 `ID` == DTO entityId**:两者同源于 drift 行主键(构造即
///   保证);server 侧 T1 已对不一致 fail-closed,此处注释钉死该不变量。
/// - 墓碑 → `operation: DELETE, entityId, payload 空`(server 硬删 + 归一化
///   空 payload;version 不载,server 对 DELETE 不消费版本)。
///
/// deviceId = clientId(F17-T1,FR-2/ADR-1):
/// - 来源 [ClientIdProvider](TokenStorage.readClientId 的函数缝,DI 组合根
///   接线)—— uuid v4 安装级标识,启动即生成持久化(injection.dart 3a),
///   与 x-client-id header 同源;server parseUUID 合法,设备行 id=clientId
///   (RegisterDevice 幂等键),push 的版本 bump 落到本设备行。
/// - F10-F16 的过渡形态(deviceId=BoundMarker 'bound' 字面量,server 容忍为
///   uuid.Nil)已闭环退役:'bound' 回归纯绑定标记值(BoundMarker 职责单一
///   化,tenant 标记与设备身份分离)。
/// - clientId 理论缺失(null)→ 空串防御(server F16 起对空 deviceId
///   fail-closed InvalidArgument,loud 不静默)。
///
/// 结果映射(FR-5/ADR-5):grpc OK → ok + conflicts 映射(**ok 语义不变**,
/// conflicts 非空仍成功 —— 单设备 server 恒空;多设备下信息携带给协调器
/// 状态,确认/解决流见 F18);unavailable 等网络类 → 失败(pending 保留,
/// 协调器语义);其他 grpc 错误 → 失败(reason 带 code);编码等非 grpc
/// 异常同样收敛为失败。
class GrpcOfflineSyncPort implements OfflineSyncPort {
  GrpcOfflineSyncPort(
    GrpcClient grpcClient,
    this._retry,
    this._clientIdProvider, {
    grpc.SyncServiceClient? syncClient,
  }) : _client = syncClient ??
            grpc.SyncServiceClient(
              grpcClient.channel,
              interceptors: [grpcClient.authInterceptor],
            );

  final AuthRetryCaller _retry;

  /// 设备身份缝:DI 接 `getIt<TokenStorage>().readClientId`(选择理由见
  /// domain/offline_sync_port.dart 的 ClientIdProvider doc)。
  final ClientIdProvider _clientIdProvider;
  final grpc.SyncServiceClient _client;

  @override
  Future<SyncResult> push(SyncBatch batch) async {
    try {
      final request = await encodeRequest(batch);
      // 闭包内先 await 再交 retry 包装(与各 remote DS 的 `_retry.call(() async
      // => ...)` 同构):T 推断为 PushResponse,而不是 ResponseFuture 桩类型。
      final response =
          await _retry.call(() async => await _client.pushChanges(request));
      // F18-T2(FR-2/ADR-2):conflicts 全字段映射(ok 不变;ConflictDTO
      // 7+1 字段全解码 —— conflictId 供解决流定位,双 payload/createdAt 供
      // 面板对照展示;解决流本体在面板 bloc,协调器只透传)。
      return SyncResult.success(conflicts: [
        for (final c in response.conflicts) _conflictOf(c),
      ]);
    } on GrpcError catch (e) {
      if (e.code == StatusCode.unavailable ||
          e.code == StatusCode.deadlineExceeded) {
        // 网络类失败:协调器保持 pending,下次回网/手动重试补上行。
        return SyncResult.failure('网络不可用(${e.codeName}),变更已保留待重试');
      }
      return SyncResult.failure('同步失败(gRPC ${e.codeName})');
    } catch (e) {
      // 编码/未知异常:同样收敛为失败(pending 保留),不让异常炸穿协调器。
      return SyncResult.failure('同步失败($e)');
    }
  }

  @override
  Future<void> registerDevice(String deviceName) async {
    // 闭包内先构造(读 clientId)再交 retry:401 刷新路径同样覆盖注册 RPC。
    final request = grpc.RegisterDeviceRequest(
      deviceId: await _deviceId(),
      deviceName: deviceName,
    );
    await _retry.call(
        () async => await _client.registerDevice(request));
    // 失败(含 grpc 错误)直接抛出:调用方 BindingBloc fire-and-forget 容错
    // (log warn 不阻断绑定);server 按非空 device_id 幂等,下次绑定或
    // F17-T2 拉取前重试无害。
  }

  /// 批次 → PushChangesRequest(编码独立可见,测试钉 wire 形态)。
  ///
  /// 墓碑排在实体前(纯约定;server 按依赖序重排,对客户端序不敏感)。
  Future<grpc.PushChangesRequest> encodeRequest(SyncBatch batch) async {
    final deviceId = await _deviceId();
    final changes = <pb.SyncPayload>[
      for (final t in batch.tombstones)
        pb.SyncPayload(
          entityType: t.module,
          operation: pb.SyncOperation.SYNC_OPERATION_DELETE,
          deviceId: deviceId,
          entityId: t.entityId,
        ),
      for (final entities in batch.entitiesByModule.values)
        for (final dto in entities)
          pb.SyncPayload(
            entityType: dto.module,
            // F18-T2(spec FR-1,design ADR-1)触达区分:version==1 → CREATE,
            // 否则 UPDATE。依据:本地 DS 的首建行恒 v1、每次编辑 bump
            // (collector 的 version 来自 drift 行)—— v1 即「该行从未被
            // 同步过」的首建语义,>1 即已同步后的编辑。server 侧 T1 起检测
            // 为 **op 无关的存在性检测**(存在即按 payload/版本规则裁决),
            // 故该区分对落库结果无影响 —— 主要价值是 wire 语义正确性与
            // 未来按 op 的统计/审计(F11 时代恒 CREATE 是检测不可达的
            // 阻断级根因之一,现按真实语义发出)。
            operation: dto.version == 1
                ? pb.SyncOperation.SYNC_OPERATION_CREATE
                : pb.SyncOperation.SYNC_OPERATION_UPDATE,
            payload: utf8.encode(jsonEncode(dto.fields)),
            version: Int64(dto.version),
            deviceId: deviceId,
            entityId: dto.entityId,
          ),
    ];
    return grpc.PushChangesRequest(changes: changes);
  }

  /// deviceId = clientId(uuid 串;来源与缺失防御见类 doc F17-T1 段)。
  Future<String> _deviceId() async => await _clientIdProvider() ?? '';

  /// F17-T2(FR-3/ADR-3):PullChanges 消费 —— sinceVersion 起的 sync_log
  /// 重放页。请求参数逐项透传(server 缺省:entityTypes 空=全模块,
  /// pageSize<=0 → 500);响应按 [PulledChange]/[PullBatch] 映射,**payload
  /// 不解码**(原始 bytes 流交 PullApplier,单一职责)。
  ///
  /// **失败透抛**(契约见 port doc):grpc 网络/服务端错误原样抛给协调器
  /// 的容忍编排(拉失败不阻断 push 流;游标不动,幂等重拉无害)。
  @override
  Future<PullBatch> pull(int sinceVersion,
      {List<String>? entityTypes, int? pageSize}) async {
    final request = grpc.PullChangesRequest(
      sinceVersion: Int64(sinceVersion),
      entityTypes: entityTypes ?? const [],
      pageSize: pageSize ?? 0,
    );
    final response =
        await _retry.call(() async => await _client.pullChanges(request));
    return PullBatch(
      changes: [
        for (final c in response.changes)
          PulledChange(
            module: c.entityType,
            entityId: c.entityId,
            isDelete: c.operation == pb.SyncOperation.SYNC_OPERATION_DELETE,
            // proto bytes 字段读面是 List<int> —— 拷贝收窄为 Uint8List
            // (行级小对象,拷贝可忽略;下游 applier jsonDecode 直接消费)。
            payload: Uint8List.fromList(c.payload),
            logVersion: c.version.toInt(),
            deviceId: c.deviceId,
          ),
      ],
      latestVersion: response.latestVersion.toInt(),
      hasMore: response.hasMore,
    );
  }

  /// F18-T2(FR-5/ADR-6):拉一页待解决冲突 —— ListConflicts 的 keyset 分页
  /// (server created_at DESC,id DESC 最新序;缺省页大小 20)。失败透抛
  /// (契约见 port doc:调用方=面板 bloc 自行收敛)。
  @override
  Future<ConflictPage> listConflicts({String? pageToken}) async {
    final request = grpc.ListConflictsRequest(
      page: common.PageRequest(pageToken: pageToken ?? ''),
    );
    final response =
        await _retry.call(() async => await _client.listConflicts(request));
    return ConflictPage(
      items: [for (final c in response.conflicts) _conflictOf(c)],
      totalCount: response.page.totalCount,
      // 空 token = 末页 → null(port 契约:续页终止语义,消费方判 null 即止)。
      nextPageToken:
          response.page.nextPageToken.isEmpty ? null : response.page.nextPageToken,
    );
  }

  /// F18-T2(FR-3/ADR-6):解决一条冲突。resolution 值域 "server"|"client"
  /// (v1 二选一);"merged" 通道保留 —— [mergedPayload] 仅该分支透传(server
  /// 空校验 fail-closed InvalidArgument)。失败透抛(面板 bloc 收敛)。
  @override
  Future<void> resolveConflict(String conflictId, String resolution,
      {List<int>? mergedPayload}) async {
    final request = grpc.ResolveConflictRequest(
      conflictId: conflictId,
      resolution: resolution,
      mergedPayload: mergedPayload ?? const [],
    );
    await _retry.call(
        () async => await _client.resolveConflict(request));
  }

  /// ConflictDTO(7+1 字段)→ [SyncConflictInfo] 的单一映射点:push 响应与
  /// ListConflicts 共用,防两处字段漂移。bytes 字段读面拷贝收窄为
  /// Uint8List(行级小对象,拷贝可忽略;与 pull 的 payload 处理同构)。
  SyncConflictInfo _conflictOf(pb.ConflictDTO c) => SyncConflictInfo(
        conflictId: c.id,
        module: c.entityType,
        entityId: c.entityId,
        conflictType: c.conflictType,
        serverPayload: c.hasServerPayload()
            ? Uint8List.fromList(c.serverPayload)
            : null,
        clientPayload: c.hasClientPayload()
            ? Uint8List.fromList(c.clientPayload)
            : null,
        // created_at 为非破坏新增(F18 FR-6):旧 server 未载 → hasCreatedAt
        // false → null;Timestamp → DateTime 的 UTC 微秒往返。
        createdAt: c.hasCreatedAt() ? c.createdAt.toDateTime() : null,
      );
}
