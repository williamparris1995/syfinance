// F11 T3(2026-09-05):GrpcOfflineSyncPort(spec FR-4,design ADR-5)。
// 批次 → PushChangesRequest 的字段级断言(entityType/payload bytes 解码后
// 形态/operation/version/deviceId/entityId;墓碑 DELETE)钉死 T2 集成测试
// 确立的 server 接受 wire 形态;push 三态(成功/网络失败/其他错误)。
// F17-T1(2026-09-06)增:deviceId=clientId(FR-2/ADR-1,注入
// ClientIdProvider 缝断言)、registerDevice wire(deviceId+deviceName)、
// PushResponse.conflicts → SyncResult.conflicts 映射(FR-5/ADR-5)。
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/binding/data/grpc_offline_sync_port.dart';
import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/core/localdb/sync_state.dart';
import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/proto/sync/v1/sync.pb.dart' as pb;
import 'package:yucai_client/proto/sync/v1/sync.pbgrpc.dart' as grpc;

class _MockGrpcClient extends Mock implements GrpcClient {}

class _MockSyncClient extends Mock implements grpc.SyncServiceClient {}

/// ResponseFuture 构造需要一个 ClientCall;mock 其 response 流即可让
/// 真实 ResponseFuture 携带我们的 PushResponse(port 侧仅 await)。
class _MockClientCall extends Mock
    implements ClientCall<dynamic, pb.PushResponse> {}

/// ResponseFuture(RegisterDevice 路径同理,pb.RegisterDeviceResponse)。
class _MockRegisterCall extends Mock
    implements ClientCall<dynamic, pb.RegisterDeviceResponse> {}

/// ResponseFuture(PullChanges 路径,pb.PullChangesResponse)。
class _MockPullCall extends Mock
    implements ClientCall<dynamic, pb.PullChangesResponse> {}

void main() {
  late _MockGrpcClient grpcClient;
  late _MockSyncClient syncClient;
  late AuthRetryCaller retry;

  setUp(() {
    grpcClient = _MockGrpcClient();
    syncClient = _MockSyncClient();
    retry = AuthRetryCaller();
    registerFallbackValue(grpc.PushChangesRequest());
    registerFallbackValue(grpc.RegisterDeviceRequest());
  });

  /// F17-T1:deviceId 来源 = ClientIdProvider(TokenStorage.readClientId 的
  /// 函数缝);默认注入现成 clientId 串(生产启动时已生成并持久化)。
  GrpcOfflineSyncPort buildPort({String? clientId = 'client-uuid-1'}) =>
      GrpcOfflineSyncPort(
          grpcClient, retry, () async => clientId,
          syncClient: syncClient);

  /// 一个 envelope 形态的账户行(collector 经 envelope_codec 产出的形态)。
  Map<String, dynamic> accountFields(String id, {int version = 5}) => {
        'ID': id,
        'Name': '现金',
        'AccountType': 1, // int 枚举
        'Version': version,
        'CreatedAt': '2026-09-03T08:30:00.000Z', // RFC3339 Z
        'DeletedAt': null,
      };

  SyncBatch batch() => SyncBatch(
        entitiesByModule: {
          SyncModule.account: [
            SyncEntityDto(
              module: SyncModule.account,
              entityId: 'acc-1',
              version: 5,
              fields: accountFields('acc-1'),
            ),
          ],
          SyncModule.tag: [
            const SyncEntityDto(
              module: SyncModule.tag,
              entityId: 'tag-1',
              version: 3,
              fields: {'ID': 'tag-1', 'Name': '餐饮', 'Version': 3},
            ),
          ],
        },
        tombstones: [
          SyncTombstoneDto(
            module: SyncModule.tag,
            entityId: 'tag-2',
            deletedAt: DateTime.utc(2026, 9, 4),
          ),
        ],
      );

  group('encodeRequest(批次 → PushChangesRequest 字段级)', () {
    test('实体:entityType/CREATE/payload bytes/version/deviceId/entityId',
        () async {
      final req = await buildPort().encodeRequest(batch());

      // 墓碑在前 + 两实体 = 3 条(server 侧本就按依赖序重排,客户端序不敏感)。
      expect(req.changes, hasLength(3));

      final acc = req.changes[1];
      expect(acc.entityType, SyncModule.account);
      expect(acc.operation, pb.SyncOperation.SYNC_OPERATION_CREATE);
      expect(acc.version, Int64(5));
      expect(acc.entityId, 'acc-1');
      // F17-T1:deviceId = clientId(uuid 串,server parseUUID 合法)。
      expect(acc.deviceId, 'client-uuid-1');

      // payload bytes 解码 = envelope 行(PascalCase/int 枚举/RFC3339 Z)。
      final decoded =
          jsonDecode(utf8.decode(acc.payload)) as Map<String, dynamic>;
      expect(decoded['ID'], 'acc-1');
      expect(decoded['Name'], '现金');
      expect(decoded['AccountType'], 1);
      expect(decoded['CreatedAt'], '2026-09-03T08:30:00.000Z');
      // 无 tenant 键(鉴权 tenant 恒赢)且无本地私有列。
      expect(decoded.containsKey('TenantID'), isFalse);
      expect(decoded.containsKey('syncState'), isFalse);

      // T1 fail-closed 一致性:payload 内 ID 必须等于 DTO entityId。
      expect(decoded['ID'], acc.entityId);
    });

    test('墓碑:DELETE + 空 payload + entityId 携带', () async {
      final req = await buildPort().encodeRequest(batch());

      final tomb = req.changes.first;
      expect(tomb.entityType, SyncModule.tag);
      expect(tomb.operation, pb.SyncOperation.SYNC_OPERATION_DELETE);
      expect(tomb.entityId, 'tag-2');
      expect(tomb.deviceId, 'client-uuid-1');
      expect(tomb.payload, isEmpty); // 墓碑不载实体数据(server 归一化为空)
    });

    test('deviceId:clientId 缺失(null)→ 空串(防御;server 侧 fail-closed)',
        () async {
      final req = await buildPort(clientId: null).encodeRequest(batch());
      expect(req.changes.first.deviceId, '');
    });
  });

  group('registerDevice(FR-2/ADR-1:绑定流程幂等注册)', () {
    List<grpc.RegisterDeviceRequest> stubRegister(String deviceName) {
      final captured = <grpc.RegisterDeviceRequest>[];
      final resp = pb.RegisterDeviceResponse(
          deviceId: 'client-uuid-1', lastSyncVersion: Int64(0));
      final call = _MockRegisterCall();
      when(() => call.response).thenAnswer((_) => Stream.value(resp));
      when<dynamic>(() => syncClient.registerDevice(any())).thenAnswer((inv) {
        captured.add(inv.positionalArguments[0] as grpc.RegisterDeviceRequest);
        return ResponseFuture(call);
      });
      return captured; // 先注册 stub,调用后读 single。
    }

    test('wire:deviceId=clientId + deviceName 透传', () async {
      final captured = stubRegister('windows');

      await buildPort().registerDevice('windows');

      expect(captured, hasLength(1));
      expect(captured.single.deviceId, 'client-uuid-1');
      expect(captured.single.deviceName, 'windows');
    });

    test('失败:异常透传(调用方[BindingBloc]fire-and-forget 容错)',
        () async {
      when<dynamic>(() => syncClient.registerDevice(any()))
          .thenThrow(const GrpcError.unavailable('network down'));

      await expectLater(
          buildPort().registerDevice('windows'), throwsA(isA<GrpcError>()));
    });
  });

  group('push 三态', () {
    test('grpc OK → SyncResult.ok + conflicts 映射(FR-5/ADR-5:ok 语义不变)',
        () async {
      final captured = <grpc.PushChangesRequest>[];
      final resp = pb.PushResponse(
        syncedVersion: Int64(3),
        conflicts: [
          pb.ConflictDTO(
              id: 'c-1',
              entityType: 'tag',
              entityId: 'tag-2',
              conflictType: 'version_conflict'),
          pb.ConflictDTO(
              id: 'c-2',
              entityType: 'holding',
              entityId: 'h-9',
              conflictType: 'version_conflict'),
        ],
      );
      // 生成的客户端桩签名要求 ResponseFuture:用 mock ClientCall 的 response
      // 流构造真实 ResponseFuture 携带应答(mock 运行时透传给 port)。
      final call = _MockClientCall();
      when(() => call.response).thenAnswer((_) => Stream.value(resp));
      when<dynamic>(() => syncClient.pushChanges(any())).thenAnswer((inv) {
        captured.add(inv.positionalArguments[0] as grpc.PushChangesRequest);
        return ResponseFuture(call);
      });

      final result = await buildPort().push(batch());

      expect(result.ok, isTrue); // conflicts 非空仍 ok(单设备无感,信息已携带)
      // 映射:恰好 2 条,module/entityId/conflictType 逐字段。
      expect(result.conflicts, hasLength(2));
      expect(result.conflictCount, 2);
      expect(result.conflicts[0].module, 'tag');
      expect(result.conflicts[0].entityId, 'tag-2');
      expect(result.conflicts[0].conflictType, 'version_conflict');
      expect(result.conflicts[1].module, 'holding');
      expect(result.conflicts[1].entityId, 'h-9');
      // 请求真的经 retry 包装发出,且内容 = encodeRequest 产物。
      expect(captured, hasLength(1));
      expect(captured.single.changes, hasLength(3));
      expect(captured.single.changes[1].entityType, SyncModule.account);
    });

    test('grpc unavailable(网络类)→ 失败(保 pending 由协调器语义保证)', () async {
      when<dynamic>(() => syncClient.pushChanges(any()))
          .thenThrow(const GrpcError.unavailable('network down'));

      final result = await buildPort().push(batch());

      expect(result.ok, isFalse);
      expect(result.reason!.toLowerCase(), contains('unavailable'));
    });

    test('其他 grpc 错误 → 失败(reason 带 code)', () async {
      when<dynamic>(() => syncClient.pushChanges(any()))
          .thenThrow(const GrpcError.internal('boom'));

      final result = await buildPort().push(batch());

      expect(result.ok, isFalse);
      expect(result.reason!.toLowerCase(), contains('internal'));
    });

    test('非 grpc 异常 → 失败(收敛为失败态,pending 保留)', () async {
      when<dynamic>(() => syncClient.pushChanges(any()))
          .thenThrow(StateError('encode blew up'));

      final result = await buildPort().push(batch());

      expect(result.ok, isFalse);
      expect(result.reason, isNotNull);
    });
  });

  group('pull(F17-T2 FR-3/ADR-3:PullChanges 消费)', () {
    test('wire:sinceVersion/entityTypes/pageSize 透传;响应逐字段映射 DTO',
        () async {
      final captured = <grpc.PullChangesRequest>[];
      final resp = pb.PullChangesResponse(
        changes: [
          pb.SyncPayload(
            entityType: SyncModule.account,
            entityId: 'acc-9',
            operation: pb.SyncOperation.SYNC_OPERATION_CREATE,
            payload: utf8.encode('{"ID":"acc-9"}'),
            version: Int64(11), // 拉取面 = sync_log 版本(分页游标)
            deviceId: 'device-A',
          ),
          pb.SyncPayload(
            entityType: SyncModule.holdingLedger,
            entityId: 'tr-1',
            operation: pb.SyncOperation.SYNC_OPERATION_DELETE,
            version: Int64(12),
            deviceId: 'device-B',
          ),
        ],
        latestVersion: Int64(12),
        hasMore: true,
      );
      final call = _MockPullCall();
      when(() => call.response).thenAnswer((_) => Stream.value(resp));
      registerFallbackValue(grpc.PullChangesRequest());
      when<dynamic>(() => syncClient.pullChanges(any())).thenAnswer((inv) {
        captured.add(inv.positionalArguments[0] as grpc.PullChangesRequest);
        return ResponseFuture(call);
      });

      final batch = await buildPort()
          .pull(7, entityTypes: [SyncModule.account], pageSize: 50);

      // 请求参数映射。
      expect(captured, hasLength(1));
      expect(captured.single.sinceVersion, Int64(7));
      expect(captured.single.entityTypes, [SyncModule.account]);
      expect(captured.single.pageSize, 50);

      // 响应 DTO 映射:原始 payload 流 + frontier + hasMore。
      expect(batch.latestVersion, 12);
      expect(batch.hasMore, isTrue);
      expect(batch.changes, hasLength(2));
      final upsert = batch.changes[0];
      expect(upsert.module, SyncModule.account);
      expect(upsert.entityId, 'acc-9');
      expect(upsert.isDelete, isFalse);
      expect(utf8.decode(upsert.payload), '{"ID":"acc-9"}');
      expect(upsert.logVersion, 11);
      expect(upsert.deviceId, 'device-A');
      final tomb = batch.changes[1];
      expect(tomb.isDelete, isTrue);
      expect(tomb.module, SyncModule.holdingLedger);
      expect(tomb.logVersion, 12);
    });

    test('失败:异常透抛(调用方[协调器]容忍,拉失败不阻断 push 流)', () async {
      registerFallbackValue(grpc.PullChangesRequest());
      when<dynamic>(() => syncClient.pullChanges(any()))
          .thenThrow(const GrpcError.unavailable('network down'));

      await expectLater(
          buildPort().pull(0), throwsA(isA<GrpcError>()));
    });
  });
}
