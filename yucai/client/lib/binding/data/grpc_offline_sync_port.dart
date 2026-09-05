import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';

import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/core/session_mode/bound_marker.dart';
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
/// - 实体 → `SyncPayload{entityType: module 常量, operation: CREATE,
///   payload: envelope 行 jsonEncode bytes, version, deviceId, entityId}`;
///   operation 恒 CREATE —— 单设备 upsert 语义下 server 把 CREATE/UPDATE
///   合并为按 entityId 的幂等 upsert(FR-1),本地无从区分也无须区分。
/// - payload 内容 = collector 经 envelope_codec 产出的 server 兼容行
///   (PascalCase/int 枚举/RFC3339 Z/子表嵌套/无 tenant 键)——单一事实源,
///   与备份导出共用同一份映射(ADR-2)。
/// - **payload 内 `ID` == DTO entityId**:两者同源于 drift 行主键(构造即
///   保证);server 侧 T1 已对不一致 fail-closed,此处注释钉死该不变量。
/// - 墓碑 → `operation: DELETE, entityId, payload 空`(server 硬删 + 归一化
///   空 payload;version 不载,server 对 DELETE 不消费版本)。
/// - deviceId = BoundMarker 的绑定标记串(当前生产值为 'bound' 字面量而非
///   tenant uuid;server parseUUID 得 Nil 仅影响 sync_log 日志列与 device
///   版本 bump no-op,无害;ticket 16 RegisterDevice 真实化时一并处理;
///   标记未写入时传空串,server 回退鉴权 tenant)。
///
/// 结果映射:grpc OK → ok(即使 conflicts 非空也视为成功 —— 单设备语义下
/// server 恒空,F10 定义的「部分冲突收敛为整体失败」留给 ticket 16 多设备);
/// unavailable 等网络类 → 失败(pending 保留,协调器语义);其他 grpc 错误 →
/// 失败(reason 带 code);编码等非 grpc 异常同样收敛为失败。
class GrpcOfflineSyncPort implements OfflineSyncPort {
  GrpcOfflineSyncPort(
    GrpcClient grpcClient,
    this._retry,
    this._boundMarker, {
    grpc.SyncServiceClient? syncClient,
  }) : _client = syncClient ??
            grpc.SyncServiceClient(
              grpcClient.channel,
              interceptors: [grpcClient.authInterceptor],
            );

  final AuthRetryCaller _retry;
  final BoundMarker _boundMarker;
  final grpc.SyncServiceClient _client;

  @override
  Future<SyncResult> push(SyncBatch batch) async {
    try {
      final request = await encodeRequest(batch);
      // 闭包内先 await 再交 retry 包装(与各 remote DS 的 `_retry.call(() async
      // => ...)` 同构):T 推断为 PushResponse,而不是 ResponseFuture 桩类型。
      await _retry.call(() async => await _client.pushChanges(request));
      return const SyncResult.success();
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
            operation: pb.SyncOperation.SYNC_OPERATION_CREATE,
            payload: utf8.encode(jsonEncode(dto.fields)),
            version: Int64(dto.version),
            deviceId: deviceId,
            entityId: dto.entityId,
          ),
    ];
    return grpc.PushChangesRequest(changes: changes);
  }

  /// deviceId = 绑定标记串(当前生产值为 'bound' 字面量而非 tenant uuid;
  /// server parseUUID 得 Nil 仅影响 sync_log 日志列与 device 版本 bump
  /// no-op,无害;ticket 16 RegisterDevice 真实化时一并处理)。未绑定 →
  /// 空串(server 端对空 DeviceId 回退鉴权 tenant)。
  Future<String> _deviceId() async =>
      await _boundMarker.readTenantId() ?? '';
}
