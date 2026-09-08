// F11 T3(2026-09-05):GrpcOfflineSyncPort(spec FR-4,design ADR-5)。
// 批次 → PushChangesRequest 的字段级断言(entityType/payload bytes 解码后
// 形态/operation/version/deviceId/entityId;墓碑 DELETE)钉死 T2 集成测试
// 确立的 server 接受 wire 形态;push 三态(成功/网络失败/其他错误)。
// F17-T1(2026-09-06)增:deviceId=clientId(FR-2/ADR-1,注入
// ClientIdProvider 缝断言)、registerDevice wire(deviceId+deviceName)、
// PushResponse.conflicts → SyncResult.conflicts 映射(FR-5/ADR-5)。
// F18-T2(2026-09-08)增:encodeRequest 的 CREATE/UPDATE 触达区分(FR-1/
// ADR-1:version==1 首建 → CREATE,>1 → UPDATE)、conflicts 全字段映射
// (conflictId/双 payload/createdAt,FR-2/ADR-2)、listConflicts 请求/响应
// 映射与 resolveConflict 参数(FR-5/ADR-6)。
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart'
    as wkt_empty;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as wkt_ts;

import 'package:yucai_client/binding/data/grpc_offline_sync_port.dart';
import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/core/localdb/sync_state.dart';
import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/proto/common/v1/pagination.pb.dart' as common;
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

/// ResponseFuture(ListConflicts 路径,pb.ListConflictsResponse)。
class _MockListConflictsCall extends Mock
    implements ClientCall<dynamic, pb.ListConflictsResponse> {}

/// ResponseFuture(ResolveConflict 路径,wkt.Empty)。
class _MockResolveCall extends Mock implements ClientCall<dynamic, wkt_empty.Empty> {}

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
    registerFallbackValue(grpc.PullChangesRequest());
    registerFallbackValue(grpc.ListConflictsRequest());
    registerFallbackValue(grpc.ResolveConflictRequest());
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
    test('实体:entityType/payload bytes/version/deviceId/entityId + '
        'F18-T2 触达区分(version>1 → UPDATE)', () async {
      final req = await buildPort().encodeRequest(batch());

      // 墓碑在前 + 两实体 = 3 条(server 侧本就按依赖序重排,客户端序不敏感)。
      expect(req.changes, hasLength(3));

      final acc = req.changes[1];
      expect(acc.entityType, SyncModule.account);
      // F18-T2(FR-1/ADR-1):batch() 的 account version=5(编辑过)→ UPDATE
      // (F11 时代恒 CREATE;server T1 起检测为 op 无关的存在性检测,区分
      // 主要为语义正确性与未来统计 —— 断言钉 wire 不回退)。
      expect(acc.operation, pb.SyncOperation.SYNC_OPERATION_UPDATE);
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

      // tag(version=3)同为 UPDATE;墓碑 DELETE 不受影响(见下一测)。
      expect(req.changes[2].operation, pb.SyncOperation.SYNC_OPERATION_UPDATE);
    });

    test('F18-T2 触达区分:version==1(本地首建)→ CREATE', () async {
      const b = SyncBatch(
        entitiesByModule: {
          SyncModule.tag: [
            SyncEntityDto(
              module: SyncModule.tag,
              entityId: 'tag-new',
              version: 1,
              fields: {'ID': 'tag-new', 'Name': '新建', 'Version': 1},
            ),
          ],
        },
        tombstones: [],
      );

      final req = await buildPort().encodeRequest(b);

      // 首建恒 v1 的本地 DS 语义:该行从未被同步过 → CREATE。
      expect(req.changes.single.operation, pb.SyncOperation.SYNC_OPERATION_CREATE);
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
    test('grpc OK → SyncResult.ok + conflicts 全字段映射(FR-5/ADR-5 + '
        'F18-T2 FR-2/ADR-2:ok 语义不变)', () async {
      final captured = <grpc.PushChangesRequest>[];
      final createdAt = DateTime.utc(2026, 9, 6, 1, 2, 3);
      final resp = pb.PushResponse(
        syncedVersion: Int64(3),
        conflicts: [
          pb.ConflictDTO(
              id: 'c-1',
              entityType: 'tag',
              entityId: 'tag-2',
              serverPayload: utf8.encode('{"ID":"tag-2","Name":"服务端版本"}'),
              clientPayload: utf8.encode('{"ID":"tag-2","Name":"我的版本"}'),
              conflictType: 'version_conflict',
              createdAt: wkt_ts.Timestamp.fromDateTime(createdAt)),
          pb.ConflictDTO(
            id: 'c-2',
            entityType: 'holding',
            entityId: 'h-9',
            conflictType: 'version_conflict',
          ),
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
      // 映射:恰好 2 条;F18-T2 起逐字段全量(conflictId/双 payload/createdAt)。
      expect(result.conflicts, hasLength(2));
      expect(result.conflictCount, 2);
      final c1 = result.conflicts[0];
      expect(c1.conflictId, 'c-1');
      expect(c1.module, 'tag');
      expect(c1.entityId, 'tag-2');
      expect(c1.conflictType, 'version_conflict');
      expect(utf8.decode(c1.serverPayload!), contains('服务端版本'));
      expect(utf8.decode(c1.clientPayload!), contains('我的版本'));
      expect(c1.createdAt, createdAt);
      // 缺省字段(created_at 未载)→ null,不炸。
      final c2 = result.conflicts[1];
      expect(c2.conflictId, 'c-2');
      expect(c2.module, 'holding');
      expect(c2.entityId, 'h-9');
      expect(c2.serverPayload, isNull);
      expect(c2.clientPayload, isNull);
      expect(c2.createdAt, isNull);
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

  group('listConflicts(F18-T2 FR-5/ADR-6:冲突面板数据源)', () {
    test('wire:pageToken 透传 PageRequest;响应逐字段映射'
        '(conflictId/module/entityId/conflictType/双 payload/createdAt/分页)',
        () async {
      final captured = <grpc.ListConflictsRequest>[];
      final createdAt = DateTime.utc(2026, 9, 6, 7, 8, 9);
      final resp = pb.ListConflictsResponse(
        conflicts: [
          pb.ConflictDTO(
            id: 'c-1',
            entityType: SyncModule.tag,
            entityId: 'tag-2',
            serverPayload: utf8.encode('{"ID":"tag-2","Name":"服务端版本"}'),
            clientPayload: utf8.encode('{"ID":"tag-2","Name":"我的版本"}'),
            conflictType: 'version_conflict',
            createdAt: wkt_ts.Timestamp.fromDateTime(createdAt),
          ),
        ],
        page: common.PageResponse(nextPageToken: 'tok-9', totalCount: 7),
      );
      final call = _MockListConflictsCall();
      when(() => call.response).thenAnswer((_) => Stream.value(resp));
      when<dynamic>(() => syncClient.listConflicts(any())).thenAnswer((inv) {
        captured.add(inv.positionalArguments[0] as grpc.ListConflictsRequest);
        return ResponseFuture(call);
      });

      final page = await buildPort().listConflicts(pageToken: 'tok-3');

      // 请求映射:pageToken 进 PageRequest(首页 null → 缺省空串,server 同义)。
      expect(captured, hasLength(1));
      expect(captured.single.page.pageToken, 'tok-3');

      // 响应条目映射:ConflictDTO 7+1 字段全解码。
      final item = page.items.single;
      expect(item.conflictId, 'c-1');
      expect(item.module, SyncModule.tag);
      expect(item.entityId, 'tag-2');
      expect(item.conflictType, 'version_conflict');
      expect(utf8.decode(item.serverPayload!), contains('服务端版本'));
      expect(utf8.decode(item.clientPayload!), contains('我的版本'));
      expect(item.createdAt, createdAt);

      // 分页元数据:权威计数 + 下一页游标。
      expect(page.totalCount, 7);
      expect(page.nextPageToken, 'tok-9');
    });

    test('首页无 token + 末页(nextPageToken 空)→ pageToken 空串/null',
        () async {
      final captured = <grpc.ListConflictsRequest>[];
      final resp = pb.ListConflictsResponse(
        conflicts: [],
        page: common.PageResponse(nextPageToken: '', totalCount: 0),
      );
      final call = _MockListConflictsCall();
      when(() => call.response).thenAnswer((_) => Stream.value(resp));
      when<dynamic>(() => syncClient.listConflicts(any())).thenAnswer((inv) {
        captured.add(inv.positionalArguments[0] as grpc.ListConflictsRequest);
        return ResponseFuture(call);
      });

      final page = await buildPort().listConflicts();

      expect(captured.single.page.pageToken, '');
      expect(page.items, isEmpty);
      expect(page.totalCount, 0);
      expect(page.nextPageToken, isNull); // 空 token → null(续页终止语义)
    });

    test('失败:异常透抛(调用方=面板 bloc 自行收敛失败态)', () async {
      when<dynamic>(() => syncClient.listConflicts(any()))
          .thenThrow(const GrpcError.unavailable('network down'));

      await expectLater(
          buildPort().listConflicts(), throwsA(isA<GrpcError>()));
    });
  });

  group('resolveConflict(F18-T2 FR-3/ADR-6:二选一 + merged 通道)', () {
    test('wire:conflictId/resolution 透传;mergedPayload 可选(缺省不载)',
        () async {
      final captured = <grpc.ResolveConflictRequest>[];
      final call = _MockResolveCall();
      when(() => call.response).thenAnswer((_) => Stream.value(wkt_empty.Empty()));
      when<dynamic>(() => syncClient.resolveConflict(any())).thenAnswer((inv) {
        captured.add(inv.positionalArguments[0] as grpc.ResolveConflictRequest);
        return ResponseFuture(call);
      });

      await buildPort().resolveConflict('c-1', 'client');

      expect(captured, hasLength(1));
      expect(captured.first.conflictId, 'c-1');
      expect(captured.first.resolution, 'client');
      expect(captured.first.hasMergedPayload(), isFalse); // 二选一不带 merged

      // merged 通道(v1 无 UI,proto/API 保留):mergedPayload 透传。
      await buildPort().resolveConflict('c-2', 'merged',
          mergedPayload: utf8.encode('{"ID":"x","Version":9}'));

      expect(captured, hasLength(2));
      expect(captured.last.conflictId, 'c-2');
      expect(captured.last.resolution, 'merged');
      expect(captured.last.mergedPayload, utf8.encode('{"ID":"x","Version":9}'));
    });

    test('失败:异常透抛(面板 bloc 收敛;server InvalidArgument 同形态)',
        () async {
      when<dynamic>(() => syncClient.resolveConflict(any()))
          .thenThrow(const GrpcError.invalidArgument('empty merged payload'));

      await expectLater(
          buildPort().resolveConflict('c-1', 'merged', mergedPayload: const []),
          throwsA(isA<GrpcError>()));
    });
  });
}
