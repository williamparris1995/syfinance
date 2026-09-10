/// F19-T2 合并全链 e2e —— 绑定向导合并执行链的消费方契约测试(spec
/// FR-6,design ADR-5):四场景钉「非空账号绑定合并」的端到端语义 ——
/// ①空账号绑定=纯上传(ADR-1 统一路径)/②非空合并不同 id 并集/③同 id
/// 残留冲突(确认+透传)/④批间失败断点续传(ADR-3)。
///
/// 链路全景(照 link_offline_sync_e2e_test.dart 的 F13 基座,全真件,
/// 仅 server 与 DI 边界为 fake):
/// 真 DI(guest 路由种数据)/ 真 drift 库 / 真 markAllPendingForSync×8 /
/// 真 PendingCollector / 真 splitSyncBatch(200 拆批)/ 真 BindingBloc 合并链
/// (版本守卫回写)/ 真 GrpcOfflineSyncPort + 真 ClientChannel(127.0.0.1
/// 临时端口)→ 进程内假 SyncService(F13/F18 基座 + 本任务 presetServerRows /
/// 按序号 unavailable 两点扩展,见 [_FakeSyncService] 注释)。
///
/// 驱动方式取舍(brief 定案):**直接驱动 BindingBloc**(构造注入),不做
/// UI 驱动 —— 向导 UI 面(readyToMerge 卡/确认 dialog/进度/成功失败态)已
/// 由 T1 的 binding_page_test widget 测试覆盖,本文件聚焦合并**执行链**的
/// 全真链路;守卫三 facet(repo 读面)用 mocktail 替身注入,因为假 server
/// 只挂 sync 服务、各模块 List RPC 不在 wire 上(守卫行为本身已由 T1 bloc
/// 单测钉死,e2e 只需可控的 server 摘要输入)。BoundMarker 同理用记录桩
/// (secure-storage 底在本环境不可写)。
///
/// 并集断言口径(场景②):合并链尾的 mirror.refreshAll 在假 server 缺各
/// 模块 List 服务下走「repo Left → mirror no-op / 本地恒等重建」即止(F13
/// 同款简化,真镜像往返的 pending 保护已由 F10 管线单测钉);两端并集的
/// 收敛由**真实下行链**驱动(PullChanges → PullApplier,与生产镜像拉回
/// 等价的 wire 往返,F17-T2 设备 B 同款验证面)。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争)。
/// 运行(跑前杀残留实例):
/// `flutter test integration_test/link_bind_merge_e2e_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
library;

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dartz/dartz.dart' as dz;
import 'package:drift/drift.dart' show Value;
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as wkt;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as wt;

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/auth/data/token_storage.dart';
import 'package:yucai_client/binding/data/pending_collector.dart';
import 'package:yucai_client/binding/data/pull_applier.dart';
import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/binding/presentation/bloc/binding_bloc.dart';
import 'package:yucai_client/binding/presentation/bloc/conflict_list_bloc.dart';
import 'package:yucai_client/core/config/app_config.dart';
import 'package:yucai_client/core/connectivity/connectivity_gateway.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/envelope_codec.dart';
import 'package:yucai_client/core/localdb/sync_state.dart';
import 'package:yucai_client/core/network/auth_interceptor.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/core/session_mode/bound_marker.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/proto/common/v1/pagination.pb.dart' as commonpb;
import 'package:yucai_client/proto/sync/v1/sync.pb.dart' as pb;
import 'package:yucai_client/proto/sync/v1/sync.pbserver.dart' as pbsvc;
import 'package:yucai_client/tag/domain/repositories/tag_repository.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

import 'link_support.dart';

/// F19-T2 假 SyncService —— 基座逐字取自 link_offline_sync_e2e_test.dart
/// (F13 ADR-1 + F17-T2 + F18-T3 三代累积的 push 落 log / pull 重放 /
/// registerDevice 幂等回显 / conflicts 可编程面 / listConflicts backlog /
/// resolveConflict 记录移除),本任务扩展两点:
///
/// 1. [presetServerRows](brief「预置 server 数据」):初始化注入「设备 X
///    曾绑同账号并已推过」的 server 起点 —— 行直接落 sync_log(version 递增),
///    pullChanges 即可重放(场景②并集下行 / 场景③ serverPayload 来源)。
///    **push 存在性模拟取舍**(brief 授权两机制选一):预置 log 行 +
///    [conflictEntityIds](F18-T3 既有机制)而非完整的存在性检测 —— 不同 id
///    天然不冲突(冲突面为空,push 照常落 log);同 id 不同 payload 由测试
///    显式 add 进冲突面命中(serverPayload 经 _serverPayloadOf 取预置行);
///    版本比对检测与「同 id 同 payload 短路」不做(该语义由 server 侧
///    sync_push_integration_test.go 钉,client e2e 只需可编程的触发面)。
/// 2. [unavailableAtPushOrdinals]:按 push 序号(0 基)注入 unavailable ——
///    场景④「第 2 批网络故障」的注入点。取代 F13 的全局单 mode:合并链
///    批间连续 push,测试线程无法在批间翻转全局开关,序号编程是唯一精准
///    注入方式(请求先记录再抛,即「server 收到该批但回网络故障」)。
class _FakeSyncService extends pbsvc.SyncServiceBase {
  final requests = <pb.PushChangesRequest>[];

  /// F19-T2:按序号注入批间网络故障(场景④)。
  final unavailableAtPushOrdinals = <int>{};

  /// F17-T2:registerDevice 记录面(设备注册断言)。
  final deviceRegistrations = <pb.RegisterDeviceRequest>[];

  /// F17-T2:pullChanges 记录面。
  final pullRequests = <pb.PullChangesRequest>[];

  /// 内部 sync_log —— push 追加(OK 分支),pull 按 version > since 过滤
  /// 重放;entry = (version, 原始 SyncPayload)。
  final _log = <(int, pb.SyncPayload)>[];
  var _lastVersion = 0;

  /// F18-T3:push conflicts 可编程面(预设「命中冲突的 entityId 集合」;
  /// DTO 双 payload 取自实际 wire bytes,见基座注释)。
  final conflictEntityIds = <String>{};

  /// F18-T3:待解决冲突 backlog(listConflicts 全量返回,resolve 移除)。
  final _conflictRows = <pb.ConflictDTO>[];
  var _conflictSeq = 0;

  /// F18-T3:resolveConflict 记录面。
  final resolveRequests = <pb.ResolveConflictRequest>[];

  /// log 条目快照(测试断言用)。
  List<(int, pb.SyncPayload)> get logEntries => List.unmodifiable(_log);

  /// F19-T2:预置 server 侧已收数据(见类 doc 扩展点 1)。
  void presetServerRows(Iterable<pb.SyncPayload> rows) {
    for (final r in rows) {
      _lastVersion++;
      _log.add((_lastVersion, r));
    }
  }

  @override
  Future<pb.PushResponse> pushChanges(
      $pb.ServerContext ctx, pb.PushChangesRequest request) async {
    requests.add(request);
    // F19-T2:序号命中 → 网络类故障(批已抵达 server,回 unavailable;
    // port 收敛为失败 + pending 保留,即断点续传注入点)。
    if (unavailableAtPushOrdinals.contains(requests.length - 1)) {
      throw const GrpcError.unavailable('e2e fake batch outage');
    }
    // OK 分支(F18-T3 语义):冲突面命中的条目不落 log,组 ConflictDTO 进
    // 响应与 backlog(server T1:冲突跳过落库,内容保进冲突行)。
    final conflicts = <pb.ConflictDTO>[];
    for (final c in request.changes) {
      if (conflictEntityIds.contains(c.entityId)) {
        _conflictSeq++;
        conflicts.add(pb.ConflictDTO(
          id: 'e2e-conflict-$_conflictSeq',
          entityType: c.entityType,
          entityId: c.entityId,
          serverPayload: _serverPayloadOf(c.entityId),
          clientPayload: c.payload,
          conflictType: 'version_conflict',
          createdAt: wt.Timestamp.fromDateTime(DateTime.now().toUtc()),
        ));
        continue;
      }
      _lastVersion++;
      _log.add((_lastVersion, c));
    }
    _conflictRows.addAll(conflicts);
    return pb.PushResponse(
      syncedVersion: fixnum.Int64(_lastVersion),
      conflicts: conflicts,
    );
  }

  /// log 内该 entity 的既有 payload(= server 侧权威版本;场景③ 即预置行)。
  List<int> _serverPayloadOf(String entityId) {
    for (final e in _log) {
      if (e.$2.entityId == entityId) return e.$2.payload;
    }
    return [];
  }

  @override
  Future<pb.RegisterDeviceResponse> registerDevice(
      $pb.ServerContext ctx, pb.RegisterDeviceRequest request) async {
    deviceRegistrations.add(request);
    return pb.RegisterDeviceResponse(
        deviceId: request.deviceId, lastSyncVersion: fixnum.Int64(0));
  }

  @override
  Future<pb.PullChangesResponse> pullChanges(
      $pb.ServerContext ctx, pb.PullChangesRequest request) async {
    pullRequests.add(request);
    final since = request.sinceVersion.toInt();
    final entries = _log.where((e) => e.$1 > since).toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
    return pb.PullChangesResponse(
      changes: [
        for (final e in entries) (e.$2.deepCopy()..version = fixnum.Int64(e.$1))
      ],
      latestVersion: fixnum.Int64(_lastVersion),
      hasMore: false,
    );
  }

  @override
  Future<pb.SyncStatusResponse> getSyncStatus(
          $pb.ServerContext ctx, pb.GetSyncStatusRequest request) =>
      throw UnimplementedError();

  @override
  Future<pb.ListConflictsResponse> listConflicts(
      $pb.ServerContext ctx, pb.ListConflictsRequest request) async {
    return pb.ListConflictsResponse(
      conflicts: [for (final c in _conflictRows) c.deepCopy()],
      page: commonpb.PageResponse(
          nextPageToken: '', totalCount: _conflictRows.length),
    );
  }

  @override
  Future<wkt.Empty> resolveConflict(
      $pb.ServerContext ctx, pb.ResolveConflictRequest request) async {
    resolveRequests.add(request);
    _conflictRows.removeWhere((c) => c.id == request.conflictId);
    return wkt.Empty();
  }
}

/// 测试专用桥(基座逐字复制):SyncServiceBase(protobuf 包生成桩)接到
/// grpc 5.x Server —— 五方法按 wire 方法名注册(getSyncStatus 走天然
/// unimplemented)。
class _SyncServiceGrpcBridge extends Service {
  _SyncServiceGrpcBridge(this._impl) {
    $addMethod(ServiceMethod<pb.PushChangesRequest, pb.PushResponse>(
      'PushChanges',
      (ServiceCall call, Future<pb.PushChangesRequest> request) async =>
          _impl.pushChanges($pb.ServerContext(), await request),
      false,
      false,
      pb.PushChangesRequest.fromBuffer,
      (pb.PushResponse r) => r.writeToBuffer(),
    ));
    $addMethod(
        ServiceMethod<pb.RegisterDeviceRequest, pb.RegisterDeviceResponse>(
      'RegisterDevice',
      (ServiceCall call, Future<pb.RegisterDeviceRequest> request) async =>
          _impl.registerDevice($pb.ServerContext(), await request),
      false,
      false,
      pb.RegisterDeviceRequest.fromBuffer,
      (pb.RegisterDeviceResponse r) => r.writeToBuffer(),
    ));
    $addMethod(ServiceMethod<pb.PullChangesRequest, pb.PullChangesResponse>(
      'PullChanges',
      (ServiceCall call, Future<pb.PullChangesRequest> request) async =>
          _impl.pullChanges($pb.ServerContext(), await request),
      false,
      false,
      pb.PullChangesRequest.fromBuffer,
      (pb.PullChangesResponse r) => r.writeToBuffer(),
    ));
    $addMethod(ServiceMethod<pb.ListConflictsRequest, pb.ListConflictsResponse>(
      'ListConflicts',
      (ServiceCall call, Future<pb.ListConflictsRequest> request) async =>
          _impl.listConflicts($pb.ServerContext(), await request),
      false,
      false,
      pb.ListConflictsRequest.fromBuffer,
      (pb.ListConflictsResponse r) => r.writeToBuffer(),
    ));
    $addMethod(ServiceMethod<pb.ResolveConflictRequest, wkt.Empty>(
      'ResolveConflict',
      (ServiceCall call, Future<pb.ResolveConflictRequest> request) async =>
          _impl.resolveConflict($pb.ServerContext(), await request),
      false,
      false,
      pb.ResolveConflictRequest.fromBuffer,
      (wkt.Empty r) => r.writeToBuffer(),
    ));
  }

  final _FakeSyncService _impl;

  @override
  String get $name => 'yucai.sync.v1.SyncService';
}

/// 可控 ConnectivityGateway fake(基座逐字复制):广播控制器驱动,冷启动
/// initialCheck 返回 none(构造后 current 即 false)。本文件不发回网边沿
/// (合并链不监听 connectivity),仅保证 tracker 构造确定性。
class _FakeConnectivityGateway extends ConnectivityGateway {
  _FakeConnectivityGateway(this.controller)
      : super(
          statusStream: controller.stream.map((online) => [
                online ? ConnectivityResult.wifi : ConnectivityResult.none
              ]),
          initialCheck: () async => [ConnectivityResult.none],
        );

  final StreamController<bool> controller;
}

/// TokenStorage fake(基座逐字复制):deviceId 来源 = clientId;本文件恒
/// 'e2e-device'(预置行属设备 X,直接载 wire 字段)。
class _FakeTokenStorage extends TokenStorage {
  _FakeTokenStorage();

  String clientId = 'e2e-device';

  @override
  Future<String?> readClientId() async => clientId;
}

/// 守卫 facet 替身(mocktail,T1 bloc 单测同款面):bloc 构造注入 ——
/// 假 server 只挂 sync 服务,各模块 List RPC 不在 wire 上;守卫是读面,
/// e2e 用可控摘要输入(空 → readyToUpload / 计数 → readyToMerge)。
class _MockAccounts extends Mock implements AccountRepository {}

class _MockTxns extends Mock implements TransactionRepository {}

class _MockHoldings extends Mock implements HoldingRepository {}

/// BoundMarker 记录桩(secure-storage 底在本环境不可写):markBound 调用
/// 序列即断言面(合并链尾收尾;断点续传重试会幂等重入,见场景④)。
class _RecordingBoundMarker extends Fake implements BoundMarker {
  final boundValues = <String>[];

  @override
  Future<bool> isBound() async => false;

  @override
  Future<void> markBound(String tenantId) async => boundValues.add(tenantId);
}

/// 守卫摘要里的「server 账户」domain 替身(仅计数被消费)。
const _serverAccountStub = Account(
  id: 'srv-acc-x',
  name: 'x',
  accountType: AccountType.asset,
  category: AccountCategory.savings,
  currencyCode: 'CNY',
  initialBalanceCents: 0,
  currentBalanceCents: 0,
  ownership: Ownership.personal,
  status: AccountStatus.active,
);

/// 清演示种子(resetTestDb 的幂等种子落跨模块行,全部 synced):本文件
/// 要对**批计数**做精确断言(200 拆分序/断点续传只推剩余),markAll-
/// PendingForSync 会把全部 synced 行翻 pending —— 不清则批计数含种子且
/// 随种子内容漂移。逐句复用镜像刷新的 deleteAllSynced* DAO 面(生产既有
/// 方法,零新面;子表 FK cascade + 显式子表清理双保险)。
Future<void> _wipeSeededRows(db.AppDatabase d) async {
  await d.transactionDao.deleteEntriesOfSyncedTransactions();
  await d.transactionDao.deleteAllSyncedTransactions();
  await d.debtDao.deleteScheduleOfSyncedDebts();
  await d.debtDao.deleteAllSyncedDebts();
  await d.budgetDao.deleteItemsOfSyncedBudgets();
  await d.budgetDao.deleteAllSyncedBudgets();
  await d.goalDao.deleteLinksOfSyncedGoals();
  await d.goalDao.deleteAllSyncedGoals();
  await d.holdingDao.deleteHoldingTransactionsOfSyncedHoldings();
  await d.holdingDao.deleteAllSyncedHoldings();
  await d.referenceDao.deleteSecuritiesNotReferencedByPendingHoldings();
  await d.tagDao.deleteTransactionTagsOfSyncedTags();
  await d.tagDao.deleteAllSyncedTags();
  await d.templateDao.deleteAllSyncedTemplates();
  await d.accountDao.deleteAllSyncedAccounts();
}

/// DAO 直插显式 id 的 guest 账户行(synced = guest 期写入语义;repo
/// create 不可指定 id —— 场景③同 id 对撞与预置行构造的夹具手法,
/// F18-T3/T1 单测同款)。companion 形状取自 T1 binding_bloc_test 种子。
Future<void> _seedExplicitAccount(
  db.AppDatabase database, {
  required String id,
  required String name,
}) async {
  final now = DateTime.utc(2026, 9, 11);
  await database.accountDao.insertAccount(db.AccountsCompanion.insert(
    id: id,
    name: name,
    accountType: 1,
    category: 2,
    currencyCode: 'CNY',
    initialBalanceCents: 0,
    currentBalanceCents: 0,
    ownership: 1,
    icon: '',
    color: '',
    chartCode: '',
    isSystem: false,
    sortOrder: 0,
    institution: '',
    cardNumberTail: '',
    notes: '',
    goldProductType: '',
    status: 1,
    version: 1,
    createdAt: now,
    updatedAt: now,
    syncState: const Value(SyncState.synced),
  ));
}

/// 构造 server 侧预置行的 wire payload:插临时行 → envelope_codec(与上行
/// 同一序列化事实源,ADR-2)→ 读行编码 → 删行。免手写 45 键 JSON 漂移;
/// 产出即 PullApplier 可应用 / _serverPayloadOf 可回读的真实 wire 形态。
Future<List<int>> _wirePayloadOf(
  db.AppDatabase database, {
  required String id,
  required String name,
}) async {
  await _seedExplicitAccount(database, id: id, name: name);
  final row = await database.accountDao.getAccountById(id);
  final payload = utf8.encode(jsonEncode(accountRowToEnvelope(row!)));
  await database.accountDao.deleteAccountById(id);
  return payload;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(const ListTransactionsParams());

  Server? server;
  _FakeSyncService? fakeSync;
  StreamController<bool>? onlineController;
  GrpcClient? grpcClient;
  BindingBloc? bindingBloc;
  ConflictListBloc? panelBloc;
  _RecordingBoundMarker? marker;

  /// 纯 Future 收敛等待(本文件无 UI 驱动面,不 pump —— 轮询 + 超时断言,
  /// 照 F13/F10 先例)。
  Future<void> until(bool Function() cond, String reason) async {
    final sw = Stopwatch()..start();
    while (!cond() && sw.elapsed < const Duration(seconds: 10)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(cond(), isTrue, reason: reason);
  }

  setUp(() async {
    // —— DI 覆写 harness(照 F13 基座,每测试 reset 重建,零生产改动)——
    await getIt.reset();
    await resetTestDb(); // 删测试库 → 重建 DI → 幂等演示种子
    // 清演示种子:批计数断言需要空库起点(见 _wipeSeededRows doc)。
    await _wipeSeededRows(getIt<db.AppDatabase>());

    // 假 SyncService + 进程内 grpc Server(127.0.0.1:0 临时端口)。socket
    // 关闭竞态噪声由守卫 zone 吞掉(F13 同款,见 tearDown 顺序注释)。
    final fake = _FakeSyncService();
    final srv = Server.create(services: [_SyncServiceGrpcBridge(fake)]);
    await runZonedGuarded(
      () => srv.serve(address: '127.0.0.1', port: 0),
      (_, __) {},
    );
    final port = srv.port!;

    // 覆写 GrpcClient:channel → 127.0.0.1:临时端口(假 server 不鉴权)。
    final client = GrpcClient(
      AppConfig(serverHost: '127.0.0.1', serverPort: port, useTls: false),
      AuthInterceptor(),
    );

    // 覆写 ConnectivityGateway(可控广播流;冷启动离线)。
    final controller = StreamController<bool>.broadcast();
    final gateway = _FakeConnectivityGateway(controller);
    final sw = Stopwatch()..start();
    while (gateway.current && sw.elapsed < const Duration(seconds: 5)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(gateway.current, isFalse, reason: 'fake gateway 冷启动应离线');

    getIt.allowReassignment = true;
    getIt.registerSingleton<GrpcClient>(client);
    getIt.registerLazySingleton<ConnectivityGateway>(() => gateway);
    getIt.registerSingleton<TokenStorage>(_FakeTokenStorage());
    // tracker 不在此触碰:保持 guest 缺省 —— 测试先经真 repo(guest 路由)
    // 种本地 synced 数据,种完再翻绑定态(见各场景)。

    server = srv;
    fakeSync = fake;
    onlineController = controller;
    grpcClient = client;
    marker = _RecordingBoundMarker();
  });

  tearDown(() async {
    // 收尾顺序(F13 基座):关 bloc → 先优雅关客户端通道 → 停假 server →
    // 关流 → 删测试库(channel.shutdown 而非 terminate:强断会触发 server
    // 侧 http2 内部断言,异步污染已完成的测试)。
    try {
      await bindingBloc?.close();
    } catch (_) {}
    try {
      await panelBloc?.close();
    } catch (_) {}
    try {
      await grpcClient?.channel.shutdown();
    } catch (_) {}
    try {
      await server?.shutdown().timeout(const Duration(seconds: 5));
    } catch (_) {}
    try {
      await onlineController?.close();
    } catch (_) {}
    await deleteTestDb();
  });

  /// Either 展开帮助:guest 写失败直接炸(夹具前置条件,非被测点)。
  T ok<T>(dz.Either<Failure, T> r) =>
      r.fold((f) => throw StateError('guest write failed: $f'), (v) => v);

  /// guest 路由建账户(tracker guest 缺省 → guestLocal → 行落 synced,
  /// 即 FR-2 全量标记的被测前提:guest 期行不在 pending 通路上)。
  Future<String> createGuestAccount(String name, int cents) async {
    final a = ok(await getIt<AccountRepository>().create(CreateAccountParams(
          name: name,
          accountType: AccountType.asset,
          category: AccountCategory.savings,
          currencyCode: 'CNY',
          initialBalanceCents: cents,
          ownership: Ownership.personal,
        )));
    return a.id;
  }

  /// 守卫三 facet 桩:计数决定 readyToUpload(全 0)/readyToMerge(任一
  /// 非空);list 内容仅计数被消费。持仓 facet 恒空桩(四场景不涉及持仓
  /// 模块,bloc 只消费计数;交易面同理由 totalCount 表达)。
  void stubGuard(_MockAccounts a, _MockTxns t, _MockHoldings h,
      {int accounts = 0, int transactions = 0}) {
    when(() => a.list()).thenAnswer((_) async => dz.Right(
        List.generate(accounts, (_) => _serverAccountStub)));
    when(() => t.list(any())).thenAnswer((_) async => dz.Right(
        ListTransactionsResult(transactions: [], totalCount: transactions)));
    when(() => h.listHoldings(accountId: any(named: 'accountId')))
        .thenAnswer((_) async => const dz.Right(<Holding>[]));
  }

  testWidgets(
    'FR-6 场景① 空账号绑定=纯上传:本地 208 行 guest 数据 → guard(空摘要)'
    '→readyToUpload→confirm → markAll 全量入批 → fake 收满 200+8 拆分批次'
    '(全 CREATE/本机 deviceId)→ 本地全 synced → markBound+设备注册',
    (t) async {
      final fake = fakeSync!;
      final database = getIt<db.AppDatabase>();
      final tags = getIt<TagRepository>();

      // ---- 本地种数据(guest 路由,行落 synced):205 账户 + 3 标签
      //      = 208 条变更 → 拆 200 + 8 两批(拆分序断言)。
      final accountIds = <String>[
        for (var i = 0; i < 205; i++) await createGuestAccount('批量账户-$i', 100 + i)
      ];
      final tagIds = <String>[
        for (final n in ['批量标签一', '批量标签二', '批量标签三'])
          ok(await tags.create(name: n, color: '#001100')).id
      ];
      // guest 期行不在 pending 通路上(缺口①前提):全 synced。
      expect(await database.accountDao.getPendingAccounts(), isEmpty);
      final seededAccounts = await database.accountDao.getAllAccounts();
      expect(seededAccounts, hasLength(205));
      expect(seededAccounts.every((a) => a.syncState == SyncState.synced), isTrue);

      // 种完翻绑定态(合并链/镜像的路由姿态;已落 guest 行不受影响)。
      getIt<SessionModeTracker>()
        ..isGuest = false
        ..online = false;

      // ---- 守卫(空摘要)→ readyToUpload(ADR-1:空时合并=纯上传)。
      final guardAccounts = _MockAccounts();
      final guardTxns = _MockTxns();
      final guardHoldings = _MockHoldings();
      stubGuard(guardAccounts, guardTxns, guardHoldings);

      bindingBloc = BindingBloc(
        guardAccounts,
        guardTxns,
        guardHoldings,
        database,
        marker!,
        getIt<OfflineSyncPort>(), // 真 GrpcOfflineSyncPort → 假 server
        getIt<PendingCollector>(), // 真收集器(与生产同一 DI 实例)
      );
      final bloc = bindingBloc!;
      bloc.add(BindingStarted());
      await until(
          () => bloc.state.status == BindingStatus.readyToUpload, '空账号守卫收敛');
      expect(bloc.state.serverSummary!.isEmpty, isTrue);

      // ---- 确认 → 合并链全真执行(markAll → collect → 拆批 → push →
      //      回写 → mirror → markBound → register → success)。
      bloc.add(BindingUploadConfirmed());
      await until(() => bloc.state.status == BindingStatus.success, '合并链收敛 success');

      // ---- fake 侧:全量批次(200 拆分序,FR-3)。
      expect(fake.requests.map((r) => r.changes.length), [200, 8],
          reason: '208 条变更按 200/批拆分为 200 + 8');
      final firstBatch = fake.requests.first.changes;
      final lastBatch = fake.requests.last.changes;
      // 桶序切分:收集器 account 桶在前 → 首批全账户;次批 = 余 5 账户 + 3 标签。
      expect(
          firstBatch.every((c) => c.entityType == SyncModule.account), isTrue);
      expect(lastBatch.where((c) => c.entityType == SyncModule.account),
          hasLength(5));
      expect(lastBatch.where((c) => c.entityType == SyncModule.tag), hasLength(3));
      // 全量不重不漏:两批 entityId 并集 = 本地全部行 id。
      final pushedIds = <String>{
        for (final c in firstBatch) c.entityId,
        for (final c in lastBatch) c.entityId,
      };
      expect(pushedIds, {...accountIds, ...tagIds});
      // wire 形态:guest 首建行 v1 → 全 CREATE;deviceId=clientId;无墓碑
      //(guest 删除不记墓碑,本场景无删除)。
      for (final c in [...firstBatch, ...lastBatch]) {
        expect(c.operation, pb.SyncOperation.SYNC_OPERATION_CREATE);
        expect(c.deviceId, 'e2e-device');
        final row = jsonDecode(utf8.decode(c.payload)) as Map<String, dynamic>;
        expect(row['ID'], c.entityId, reason: 'payload.ID == entityId(不变量)');
        expect(c.version.toInt(), 1, reason: 'guest 首建行乐观锁 v1');
      }
      // 名字回读抽样(按 id 定位,免序依赖)。
      final sample = [...firstBatch, ...lastBatch]
          .firstWhere((c) => c.entityId == accountIds[0]);
      expect(
          (jsonDecode(utf8.decode(sample.payload))
              as Map<String, dynamic>)['Name'],
          '批量账户-0');

      // ---- 本地侧:全 synced(markAll → 推 → 版本守卫回写闭环,FR-2)。
      final after = await database.accountDao.getAllAccounts();
      expect(after, hasLength(205));
      expect(after.every((a) => a.syncState == SyncState.synced), isTrue);
      expect(await database.accountDao.getPendingAccounts(), isEmpty);
      expect(await database.tagDao.getPendingTags(), isEmpty);

      // ---- success 摘要 + 绑定收尾。
      expect(bloc.state.uploadedEntities, 208);
      expect(bloc.state.conflictCount, 0);
      expect(marker!.boundValues, ['bound'], reason: 'markBound(绑定标记)');
      await until(() => fake.deviceRegistrations.length == 1, '设备注册抵达 fake');
      expect(fake.deviceRegistrations.single.deviceId, 'e2e-device');
      expect(fake.deviceRegistrations.single.deviceName, 'windows');
    },
  );

  testWidgets(
    'FR-6 场景② 非空合并(不同 id 并集):fake 预置设备 X 账户行 → guard '
    'readyToMerge(摘要含 server 计数)→ confirm → push 全量不同 id 不冲突'
    '→ 真实下行(pull→PullApplier)后本地=两端并集 → success',
    (t) async {
      final fake = fakeSync!;
      final database = getIt<db.AppDatabase>();
      final tags = getIt<TagRepository>();

      // ---- fake 预置 server 端账户行(设备 X 曾绑同账号已推过)。
      final presetPayload =
          await _wirePayloadOf(database, id: 'srv-acc-x', name: '设备X账户');
      fake.presetServerRows([
        pb.SyncPayload(
          entityType: SyncModule.account,
          operation: pb.SyncOperation.SYNC_OPERATION_CREATE,
          payload: presetPayload,
          version: fixnum.Int64(1),
          deviceId: 'e2e-device-X',
          entityId: 'srv-acc-x',
        ),
      ]);
      expect(fake.logEntries, hasLength(1), reason: '预置行已落 server log');

      // ---- 本地种不同 id 数据(guest 路由,uuid 主键不与 srv-acc-x 相撞)。
      final a1 = await createGuestAccount('本机账户A', 1000);
      final a2 = await createGuestAccount('本机账户B', 2000);
      final tag = ok(await tags.create(name: '本机标签', color: '#000011')).id;

      getIt<SessionModeTracker>()
        ..isGuest = false
        ..online = false;

      // ---- 守卫:server 有 1 账户 → readyToMerge(摘要含 server 计数,FR-1)。
      final guardAccounts = _MockAccounts();
      final guardTxns = _MockTxns();
      final guardHoldings = _MockHoldings();
      stubGuard(guardAccounts, guardTxns, guardHoldings, accounts: 1);

      bindingBloc = BindingBloc(
        guardAccounts,
        guardTxns,
        guardHoldings,
        database,
        marker!,
        getIt<OfflineSyncPort>(),
        getIt<PendingCollector>(),
      );
      final bloc = bindingBloc!;
      bloc.add(BindingStarted());
      await until(
          () => bloc.state.status == BindingStatus.readyToMerge, '非空守卫收敛');
      expect(bloc.state.serverSummary!.accountCount, 1,
          reason: '摘要含 server 计数');
      expect(bloc.state.serverSummary!.isEmpty, isFalse);

      // ---- 合并确认 → 全量 push(不同 id 不冲突:预置行不在本批)。
      bloc.add(BindingMergeConfirmed());
      await until(() => bloc.state.status == BindingStatus.success, '合并收敛 success');

      expect(fake.requests, hasLength(1));
      final pushed = fake.requests.single.changes;
      expect(pushed, hasLength(3));
      expect(pushed.map((c) => c.entityId).toSet(), {a1, a2, tag});
      expect(pushed.every((c) => c.deviceId == 'e2e-device'), isTrue);
      // server log = 预置 1 + 推 3(不同 id 零冲突全落)。
      expect(fake.logEntries, hasLength(4));
      expect(bloc.state.conflictCount, 0);
      expect(bloc.state.uploadedEntities, 3);

      // ---- refreshAll 后本地=两端并集:镜像在假 server 缺 List 服务下
      //      恒等/no-op(类 doc 取舍),并集收敛由真实下行链驱动 ——
      //      pull(0) 重放 server log(预置行 + own-echo)→ PullApplier 应用
      //      (own-echo 同 id 同内容 upsert 幂等)。
      final pulled = await getIt<OfflineSyncPort>().pull(0);
      expect(pulled.changes, hasLength(4));
      expect(pulled.changes.map((c) => c.entityId).toSet(),
          {'srv-acc-x', a1, a2, tag});
      final applied = await PullApplier(database).apply(pulled.changes);
      expect(applied.applied, 4);

      // 并集断言:server 行(设备 X 的)与本机行都在,全 synced。
      final rows = await database.accountDao.getAllAccounts();
      expect(rows, hasLength(3), reason: '本地 = 两端并集(1 server + 2 本机)');
      final srvRow = await database.accountDao.getAccountById('srv-acc-x');
      expect(srvRow, isNotNull, reason: 'server 行经下行在本机复现');
      expect(srvRow!.name, '设备X账户');
      expect(srvRow.syncState, SyncState.synced);
      final names = {for (final r in rows) r.id: r.name};
      expect(names[a1], '本机账户A');
      expect(names[a2], '本机账户B');
      expect(rows.every((r) => r.syncState == SyncState.synced), isTrue);
      final tagAfter = await database.tagDao.getTagById(tag);
      expect(tagAfter, isNotNull);
      expect(tagAfter!.name, '本机标签');

      // 绑定收尾。
      expect(marker!.boundValues, ['bound']);
      await until(() => fake.deviceRegistrations.length == 1, '设备注册抵达 fake');
    },
  );

  testWidgets(
    'FR-6 场景③ 残留冲突(同 id 不同内容):fake 预置同 id 异 payload 行+'
    '冲突面 → confirm → push 命中 fake 冲突机制 → 本地行标 synced(确认)'
    '+success 带冲突计数 → 冲突面板权威计数=1(badge 冲突态数据源)',
    (t) async {
      final fake = fakeSync!;
      final database = getIt<db.AppDatabase>();

      // ---- fake 预置与本地同 id 不同 payload 的行(模拟曾绑同账号的
      //      server 残留;payload 经 envelope_codec 事实源构造)。
      const conflictId = 'acc-conflict';
      final presetPayload = await _wirePayloadOf(database,
          id: conflictId, name: '服务端旧账户(设备X)');
      fake.presetServerRows([
        pb.SyncPayload(
          entityType: SyncModule.account,
          operation: pb.SyncOperation.SYNC_OPERATION_CREATE,
          payload: presetPayload,
          version: fixnum.Int64(1),
          deviceId: 'e2e-device-X',
          entityId: conflictId,
        ),
      ]);
      // push 存在性检测的 fake 模拟:该 id 命中冲突面(取舍见
      // _FakeSyncService.presetServerRows doc —— 最小机制,brief 授权)。
      fake.conflictEntityIds.add(conflictId);

      // ---- 本地:2 笔 repo 建 + 1 笔同 id 不同内容行(DAO 直插显式 id,
      //      synced = guest 语义)。
      await createGuestAccount('本机账户A', 3000);
      await createGuestAccount('本机账户B', 4000);
      await _seedExplicitAccount(database,
          id: conflictId, name: '本地新账户(当前设备)');

      getIt<SessionModeTracker>()
        ..isGuest = false
        ..online = false;

      final guardAccounts = _MockAccounts();
      final guardTxns = _MockTxns();
      final guardHoldings = _MockHoldings();
      stubGuard(guardAccounts, guardTxns, guardHoldings, accounts: 1);

      bindingBloc = BindingBloc(
        guardAccounts,
        guardTxns,
        guardHoldings,
        database,
        marker!,
        getIt<OfflineSyncPort>(),
        getIt<PendingCollector>(),
      );
      final bloc = bindingBloc!;
      bloc.add(BindingStarted());
      await until(
          () => bloc.state.status == BindingStatus.readyToMerge, '非空守卫收敛');
      bloc.add(BindingMergeConfirmed());
      await until(() => bloc.state.status == BindingStatus.success, '合并收敛 success');

      // ---- push 命中 fake 冲突机制:3 条全推,1 条入冲突。
      expect(fake.requests, hasLength(1));
      expect(fake.requests.single.changes, hasLength(3));
      // 冲突条不落 log(server 跳过落库语义);log = 预置 1 + 正常落 2。
      expect(fake.logEntries, hasLength(3));
      // 冲突 DTO 双 payload:server 栏 = 预置行,client 栏 = 本次推的行
      //(经真 port.listConflicts 拉 fake backlog 断言)。
      final backlog = await getIt<OfflineSyncPort>().listConflicts();
      expect(backlog.totalCount, 1);
      final conflict = backlog.items.single;
      expect(conflict.entityId, conflictId);
      expect(conflict.conflictId, isNotEmpty);
      expect(utf8.decode(conflict.serverPayload!), contains('服务端旧账户'));
      expect(utf8.decode(conflict.clientPayload!), contains('本地新账户'));

      // ---- 本地行标 synced(F18-T2 确认语义:冲突实体与正常实体一并
      //      版本守卫标记,防重推堆冲突)+ 内容仍是本地版本。
      final conflictedRow = await database.accountDao.getAccountById(conflictId);
      expect(conflictedRow, isNotNull, reason: '冲突确认不清行');
      expect(conflictedRow!.syncState, SyncState.synced,
          reason: 'push 命中冲突 → 标 synced(确认)');
      expect(conflictedRow.name, '本地新账户(当前设备)');
      final after = await database.accountDao.getAllAccounts();
      expect(after, hasLength(3));
      expect(after.every((a) => a.syncState == SyncState.synced), isTrue);

      // ---- success 带冲突计数(F18 冲突面板零接线,badge 自然出现的数据面)。
      expect(bloc.state.conflictCount, 1);
      expect(bloc.state.uploadedEntities, 3);
      expect(marker!.boundValues, ['bound']);
      await until(() => fake.deviceRegistrations.length == 1, '设备注册抵达 fake');

      // ---- badge 冲突态数据:权威计数源 ListConflicts(真 bloc + 真 wire,
      //      SyncStatusBadge 冲突 chip / 冲突面板共用的数据链)。
      panelBloc = ConflictListBloc(getIt<OfflineSyncPort>());
      panelBloc!.add(const ConflictListLoadRequested());
      await until(() => panelBloc!.state.status == ConflictListStatus.loaded,
          '面板 bloc 加载收敛');
      expect(panelBloc!.state.totalCount, 1);
      expect(panelBloc!.state.items.single.entityId, conflictId);
    },
  );

  testWidgets(
    'FR-6 场景④ 断点续传:第 1 批成功+第 2 批 unavailable → failed'
    '(canResume)→ fake 恢复 → retry 只推剩余(批序列 200+1+1)→ success',
    (t) async {
      final fake = fakeSync!;
      final database = getIt<db.AppDatabase>();

      // ---- 本地 201 行 guest 数据 → 拆 200 + 1 两批。
      final accountIds = <String>[
        for (var i = 0; i < 201; i++) await createGuestAccount('续传账户-$i', 500 + i)
      ];

      getIt<SessionModeTracker>()
        ..isGuest = false
        ..online = false;

      // 第 2 批(0 基序号 1)unavailable:网络类批间故障注入。
      fake.unavailableAtPushOrdinals.add(1);

      final guardAccounts = _MockAccounts();
      final guardTxns = _MockTxns();
      final guardHoldings = _MockHoldings();
      stubGuard(guardAccounts, guardTxns, guardHoldings);

      bindingBloc = BindingBloc(
        guardAccounts,
        guardTxns,
        guardHoldings,
        database,
        marker!,
        getIt<OfflineSyncPort>(),
        getIt<PendingCollector>(),
      );
      final bloc = bindingBloc!;
      bloc.add(BindingStarted());
      await until(
          () => bloc.state.status == BindingStatus.readyToUpload, '空账号守卫收敛');
      bloc.add(BindingUploadConfirmed());
      await until(() => bloc.state.status == BindingStatus.failed, '批间失败收敛 failed');

      // ---- failed(canResume)+ 网络类 reason(port 收敛形态)。
      expect(bloc.state.canResume, isTrue, reason: '链内失败 → 重试续传');
      expect(bloc.state.failureMessage, contains('UNAVAILABLE'));

      // ---- 第 1 批成功已回写:200 synced + 1 pending(断点粒度=批)。
      var synced = 0;
      var pending = 0;
      for (final a in await database.accountDao.getAllAccounts()) {
        a.syncState == SyncState.synced ? synced++ : pending++;
      }
      expect(synced, 200);
      expect(pending, 1);
      final remainingId =
          (await database.accountDao.getPendingAccounts()).single.id;
      expect(accountIds.contains(remainingId), isTrue);

      // ---- fake 侧批序列:200(成功)+ 1(被拒)。
      expect(fake.requests.map((r) => r.changes.length), [200, 1]);

      // ---- fake 恢复 → retry:跳过全量标记,collect 只收剩余 pending →
      //      只推剩余 1 条(重试批不含首批 200 实体 = markAll 被跳过的证明:
      //      若重跑全量标记,200 已 synced 行会再翻 pending 重推)。
      fake.unavailableAtPushOrdinals.clear();
      bloc.add(BindingRetryRequested());
      await until(() => bloc.state.status == BindingStatus.success, '重试收敛 success');

      expect(fake.requests.map((r) => r.changes.length), [200, 1, 1],
          reason: '断点续传只推剩余(fake 批序列)');
      final retryChange = fake.requests.last.changes.single;
      expect(retryChange.entityId, remainingId);
      final first200 = fake.requests.first.changes.map((c) => c.entityId).toSet();
      expect(first200.contains(remainingId), isFalse);
      expect(first200.length, 200);

      // ---- 收敛:本地全 synced。
      expect((await database.accountDao.getAllAccounts())
          .every((a) => a.syncState == SyncState.synced), isTrue);
      // 末轮上行计数(断点续传后 = 剩余 1 条,state 契约见 uploadedEntities doc)。
      expect(bloc.state.uploadedEntities, 1);
      expect(bloc.state.conflictCount, 0);

      // ---- 收尾语义:失败链在 markBound 前即 return(未完成的绑定不落
      //      标记/不注册设备 —— failed 态可见),重试收敛后收尾恰一次。
      expect(marker!.boundValues, ['bound']);
      await until(() => fake.deviceRegistrations.length == 1, '重试收敛后设备注册抵达');
    },
  );
}
