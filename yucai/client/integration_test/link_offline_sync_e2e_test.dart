/// F13 离线同步 e2e —— 消费方契约链路测试(CDC,spec FR-1/FR-2,design
/// ADR-1..4):断网记账 → pending → 回网翻转 → **真 gRPC 线协议**(真
/// GrpcOfflineSyncPort + 真 ClientChannel,127.0.0.1 临时端口)→ 进程内假
/// SyncService(SyncServiceBase 生成桩)→ 成功回写本地。与 F11 的提供方
/// 测试(Go 侧 sync_push_integration_test.go)夹同一份 wire 契约,组成
/// 完整 CDC;guest 既有链路零扰动(本文件自建 DI 覆写 + 每测试 reset,
/// 不泄漏)。
///
/// F18-T3 扩展(spec FR-5/FR-8,design ADR-5):fake 增冲突三能力(push
/// conflicts 可编程/listConflicts 真 backlog/resolveConflict 记录+移除),
/// 新增双设备冲突全链测试(A 断网写→push;模拟 B 独立编辑同实体→push 命中
/// fake 冲突→确认标记+状态携带→badge 冲突 chip→面板双栏→保留我的→fake
/// resolveConflict 被调+面板刷新空)。
///
/// 链路全景(全真件,仅 server 与三处 DI 边界为 fake):
/// 真 DI(repos 三态路由)/ 真 local DS / 真 drift 库 / 真 PendingCollector
/// / 真 envelope 编码 / 真 GrpcOfflineSyncPort / 真 grpc 通道 → 假
/// SyncService(记录 PushChangesRequest 原始 proto)。
///
/// 断言口径(ADR-4):wire 形态与 server T2 的 syncAccountRow /
/// syncTransactionRow / syncTagRow **逐字段一致**(键集逐字对齐,见
/// _t2*Keys);成功后本地经 DAO 断言 synced/墓碑清 + 数据仍在 —— 镜像
/// 刷新在此链路只走到「假 server 缺各模块 List 服务 → repo Left → mirror
/// no-op」即止(真镜像往返的 pending 保护已由 F10 管线单测钉),故
/// 「数据仍在」即上行闭环的本地断言口径。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争)。
/// 运行(跑前杀残留实例):
/// `flutter test integration_test/link_offline_sync_e2e_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
library;

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dartz/dartz.dart' as dz;
import 'package:drift/drift.dart' show Value;
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:grpc/grpc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as wkt;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as wt;

import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/auth/data/token_storage.dart';
import 'package:yucai_client/binding/data/pending_collector.dart';
import 'package:yucai_client/binding/data/pull_applier.dart';
import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/binding/presentation/bloc/conflict_list_bloc.dart';
import 'package:yucai_client/binding/presentation/bloc/sync_coordinator_bloc.dart';
import 'package:yucai_client/binding/presentation/pages/conflict_panel_page.dart';
import 'package:yucai_client/binding/presentation/widgets/sync_status_badge.dart';
import 'package:yucai_client/core/config/app_config.dart';
import 'package:yucai_client/core/connectivity/connectivity_gateway.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/sync_state.dart';
import 'package:yucai_client/core/network/auth_interceptor.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/core/theme/app_theme.dart';
import 'package:yucai_client/proto/common/v1/pagination.pb.dart' as commonpb;
import 'package:yucai_client/proto/sync/v1/sync.pb.dart' as pb;
import 'package:yucai_client/proto/sync/v1/sync.pbserver.dart' as pbsvc;
import 'package:yucai_client/tag/domain/repositories/tag_repository.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

import 'link_support.dart';

/// 假 server 可编程响应模式(ADR-1)。
enum _PushMode { ok, unavailable }

/// F13 ADR-1 + F17-T2 扩展:进程内假 SyncService —— extends SyncServiceBase
/// (sync.pbserver 生成桩);pushChanges 记录收到的 PushChangesRequest
/// **原始 proto**(含 payload bytes),响应按 [mode] 可编程(OK /
/// unavailable),OK 时每条 change 追加进内部 sync_log(版本 1..N)——
/// pullChanges 即按 since 过滤该 log 重放(server sync_log 语义的最小模拟,
/// 不需要真业务表);registerDevice 记录请求并按非空 device_id 幂等回显
/// (server Register 语义)。其余 3 方法 throw UnimplementedError(本链路
/// 不调用 —— wire 上也不会到达,见桥注册)。
class _FakeSyncService extends pbsvc.SyncServiceBase {
  final requests = <pb.PushChangesRequest>[];
  _PushMode mode = _PushMode.ok;

  /// F17-T2:registerDevice 记录面(双设备场景断言)。
  final deviceRegistrations = <pb.RegisterDeviceRequest>[];

  /// F17-T2:pullChanges 记录面(since 入参断言)。
  final pullRequests = <pb.PullChangesRequest>[];

  /// F17-T2:内部 sync_log —— push 追加(pushChanges OK 分支),pull 按
  /// version > since 过滤重放。entry = (version, 原始 SyncPayload)。
  final _log = <(int, pb.SyncPayload)>[];
  var _lastVersion = 0;

  /// F18-T3:push conflicts 可编程面 —— 预设「命中冲突的 entityId 集合」。
  /// push OK 分支逐条检查:entityId ∈ 集合 → 组 ConflictDTO 返回 + 入
  /// 待解决 backlog + **不落 log**(server T1 语义:冲突跳过落库)。
  ///
  /// 实现取舍(对 brief「直接返回预设 ConflictDTO」的最小变形):DTO 的
  /// server/client payload 取自**实际 wire bytes**(server 侧 = log 内该
  /// entity 既有 payload,client 侧 = 本次 push 的 payload),免测试手工
  /// 拼 envelope,面板解码走真行;版本比对检测不做(太重,非本链路被测点)。
  final conflictEntityIds = <String>{};

  /// F18-T3:待解决冲突 backlog(server conflict 行的最小模拟;resolve
  /// 时移除,listConflicts 全量返回)。
  final _conflictRows = <pb.ConflictDTO>[];
  var _conflictSeq = 0;

  /// F18-T3:resolveConflict 记录面(断言 resolution/conflictId)。
  final resolveRequests = <pb.ResolveConflictRequest>[];

  /// log 条目快照(测试断言用)。
  List<(int, pb.SyncPayload)> get logEntries => List.unmodifiable(_log);

  @override
  Future<pb.PushResponse> pushChanges(
      $pb.ServerContext ctx, pb.PushChangesRequest request) async {
    requests.add(request);
    switch (mode) {
      case _PushMode.unavailable:
        // 模拟 server 侧网络类故障:客户端 port 按 unavailable 收敛为
        // 失败(pending 保留),即 FR-2 的注入点。
        throw const GrpcError.unavailable('e2e fake outage');
      case _PushMode.ok:
        // F17-T2:落 sync_log(server PushChanges 语义:批内逐条按依赖序
        // 追加,version = LatestVersion+1..N;此处免序重排 —— e2e 断言对
        // 批内序不敏感)。
        // F18-T3:预设冲突面命中的条目不落 log,组 ConflictDTO 进响应与
        // backlog(server T1:冲突跳过落库,内容保进冲突行)。
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
  }

  /// log 内该 entity 的既有 payload(= server 侧权威版本;双设备场景 A
  /// 先推的那份)。无记录 → null(面板该栏收敛「(无法解析)」容错)。
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
    // 幂等回显(server:非 Nil device_id → 返回既有设备行)。
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
    // version 字段载 **log 版本**(server PayloadToDTO 直传 entry.Version,
    // 非 payload 内的实体版本)—— 分页游标契约。
    return pb.PullChangesResponse(
      changes: [
        for (final e in entries) (e.$2.deepCopy()..version = fixnum.Int64(e.$1))
      ],
      latestVersion: fixnum.Int64(_lastVersion),
      hasMore: false,
    );
  }

  // F18-T3:getSyncStatus 仍不实现(FR-7 YAGNI,面板计数走 ListConflicts
  // totalCount,不注册到 wire)。
  @override
  Future<pb.SyncStatusResponse> getSyncStatus(
          $pb.ServerContext ctx, pb.GetSyncStatusRequest request) =>
      throw UnimplementedError();

  /// F18-T3:ListConflicts —— backlog 全量返回(created_at DESC 序由
  /// push 时的入列序近似;totalCount = 剩余数,无分页(nextPageToken 空)。
  @override
  Future<pb.ListConflictsResponse> listConflicts(
      $pb.ServerContext ctx, pb.ListConflictsRequest request) async {
    return pb.ListConflictsResponse(
      conflicts: [for (final c in _conflictRows) c.deepCopy()],
      page: commonpb.PageResponse(
          nextPageToken: '', totalCount: _conflictRows.length),
    );
  }

  /// F18-T3:ResolveConflict —— 记录 + 从 backlog 移除。server T1 的
  /// client/merged 落库+写 log 语义**不模拟**(本链路被测点 = client 解决
  /// 面:调用 wire 形态 + 面板刷新;落库收敛由 server T1 集成测试钉)。
  @override
  Future<wkt.Empty> resolveConflict(
      $pb.ServerContext ctx, pb.ResolveConflictRequest request) async {
    resolveRequests.add(request);
    _conflictRows.removeWhere((c) => c.id == request.conflictId);
    return wkt.Empty();
  }
}

/// 测试专用桥(纯测试代码,零生产改动):SyncServiceBase 继承的是
/// **protobuf** 包的 GeneratedService(protoc_plugin 25 生成的 server 桩
/// 形态),而 grpc 5.x Server 挂载的是自家 Service($addMethod 注册)——
/// 桥在此把假服务按 wire 方法名接到 Server;服务/方法名取自 sync.pbgrpc
/// 的 @GrpcServiceName 与 client 方法 descriptor(同一 proto 的两侧)。
/// F13 注册 PushChanges;F17-T2 增 RegisterDevice/PullChanges(双设备场景
/// 的两方法);F18-T3 增 ListConflicts/ResolveConflict(冲突面板两方法)
/// —— getSyncStatus 走 grpc 天然 unimplemented(FR-7 YAGNI)。
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
    $addMethod(ServiceMethod<pb.RegisterDeviceRequest, pb.RegisterDeviceResponse>(
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
    // F18-T3:冲突面两方法(面板 bloc 的 listConflicts/resolveConflict)。
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

/// F13 ADR-2:可控 ConnectivityGateway fake —— 广播控制器驱动;bool 在线
/// 事件翻译成 connectivity_plus 结果列表(online=false → none),冷启动
/// initialCheck 返回 none(构造后 current 即 false)。
class _FakeConnectivityGateway extends ConnectivityGateway {
  _FakeConnectivityGateway(this.controller)
      : super(
          statusStream: controller.stream.map((online) => [
                online ? ConnectivityResult.wifi : ConnectivityResult.none
              ]),
          initialCheck: () async => [ConnectivityResult.none],
        );

  /// 测试手控口:broadcast 控制器,`add(true)` 即一次回网边沿。
  final StreamController<bool> controller;
}

/// F17-T1:TokenStorage fake —— deviceId 来源 = clientId(FR-2/ADR-1,
/// GrpcOfflineSyncPort 经 ClientIdProvider 缝读 readClientId),默认
/// 'e2e-device'(wire 断言钉该值;super 构造仅落一个永不被触碰的
/// secure-storage 引用)。F17-T2 双设备场景:clientId **可变**(换设备 =
/// 换身份,port 每次 RPC 现读,无需重建)。F13 时代注入的是 BoundMarker
/// fake(readTenantId),设备身份真实化后注入点随来源迁移。
class _FakeTokenStorage extends TokenStorage {
  _FakeTokenStorage();

  String clientId = 'e2e-device';

  @override
  Future<String?> readClientId() async => clientId;
}

/// server T2(yucai/server/tests/sync_push_integration_test.go)钉死的
/// syncAccountRow 键集 —— client 侧断言与之间**逐字一致**(CDC 同一份
/// 契约;生产侧由 envelope_codec 单一事实源保证实际产出同键集)。
const _t2AccountKeys = <String>{
  'ID', 'Name', 'AccountType', 'Category', 'CurrencyCode',
  'InitialBalanceCents', 'CurrentBalanceCents', 'Ownership', 'Icon', 'Color',
  'ChartCode', 'ParentID', 'IsSystem', 'SortOrder', 'Institution',
  'CreditLimitCents', 'CardNumberTail', 'Notes', 'OpeningDate',
  'InterestRate', 'CreditBillingDay', 'CreditRepaymentDay',
  'CreditAnnualFeeCents', 'InvestCostCents', 'InvestMarketValueCents',
  'InvestReturnYtd', 'FixedPrincipalCents', 'FixedStartDate',
  'FixedMaturityDate', 'FixedTermMonths', 'GoldProductType', 'GoldQuantity',
  'GoldBuyPriceCents', 'GoldCurrentPriceCents', 'EstatePurchasePriceCents',
  'EstateCurrentValueCents', 'EstatePurchaseDate', 'EstateDepreciationRate',
  'LoanOriginalCents', 'LoanRemainingCents', 'LoanMonthlyCents',
  'LoanNextPaymentDate', 'Status', 'Version', 'DeletedAt', 'CreatedAt',
  'UpdatedAt',
};

/// T2 syncTransactionRow 头行键集(分录嵌套在 Entries)。
const _t2TransactionKeys = <String>{
  'ID', 'TransactionDate', 'TransactionTime', 'Description', 'Entries',
  'Version', 'DeletedAt', 'CreatedAt', 'UpdatedAt',
};

/// T2 syncTransactionRow 内嵌 Entries 行键集。
const _t2EntryKeys = <String>{
  'ID', 'TransactionID', 'AccountID', 'ChartOfAccountCode', 'DebitCents',
  'CreditCents', 'Note',
};

/// T2 syncTagRow 键集。
const _t2TagKeys = <String>{
  'ID', 'Name', 'Color', 'Version', 'DeletedAt', 'CreatedAt', 'UpdatedAt',
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Server? server;
  _FakeSyncService? fakeSync;
  StreamController<bool>? onlineController;
  GrpcClient? grpcClient;
  SyncCoordinatorBloc? bloc;

  /// F17-T2:token fake 句柄(双设备场景换 clientId 用)。
  _FakeTokenStorage? tokenStorage;

  /// 纯 Future 收敛等待(design ADR-3:本文件无 UI,不 pump —— 轮询 +
  /// 超时断言,照 F10 管线测试的 until 先例)。
  Future<void> until(bool Function() cond, String reason) async {
    final sw = Stopwatch()..start();
    while (!cond() && sw.elapsed < const Duration(seconds: 10)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(cond(), isTrue, reason: reason);
  }

  setUp(() async {
    // —— ADR-2 DI 覆写 harness(零生产改动)——
    // 每测试 reset 局部重建:上一测试的覆写与 lazy 单例缓存(含已 close 的
    // bloc / 已 shutdown 的通道)全部清空,覆写不跨测试泄漏。
    await getIt.reset();
    await resetTestDb(); // 删测试库 → 重建 DI → 幂等种子(种子行恒 synced)

    // ADR-1:假 SyncService + 进程内 grpc Server 绑 127.0.0.1:0(OS 分配
    // 临时端口,无真实网络依赖、免端口冲突 —— NFR)。
    // socket 事件跑在守卫 zone:http2 包在客户端断开瞬间有一个关闭竞态的
    // 内部断言(debug asserts 下可见的已知噪声,见 tearDown 顺序注释),
    // 任其逸散会被测试框架当成未捕获错误污染已完成的测试 —— 守卫 zone
    // 内静默吞掉(纯收尾竞态,不影响任何被测行为)。
    final fake = _FakeSyncService();
    final srv = Server.create(services: [_SyncServiceGrpcBridge(fake)]);
    await runZonedGuarded(
      () => srv.serve(address: '127.0.0.1', port: 0),
      (_, __) {},
    );
    final port = srv.port!;

    // 覆写 GrpcClient:channel → 127.0.0.1:临时端口。AppConfig 是 const
    // 简单构造,直接造一份指向假 server 的配置即最小覆写路径(无需生产
    // 测试缝);AuthInterceptor 留空回调(tokenReader null → 不带 Bearer,
    // 假 server 不鉴权;AuthRetryCaller 仅 401 介入,本链路不触发)。
    final client = GrpcClient(
      AppConfig(serverHost: '127.0.0.1', serverPort: port, useTls: false),
      AuthInterceptor(),
    );

    // 覆写 ConnectivityGateway:可控广播流(offline 初值 → true 边沿)。
    final controller = StreamController<bool>.broadcast();
    final gateway = _FakeConnectivityGateway(controller);
    // 等 initialCheck(none)落定:gateway.current 必须已是 false,后续
    // add(true) 才构成 false→true 边沿(_update 按变化去重)。
    final sw = Stopwatch()..start();
    while (gateway.current && sw.elapsed < const Duration(seconds: 5)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(gateway.current, isFalse, reason: 'fake gateway 冷启动应离线');

    // 覆写=同类型重注册:configureDependencies 已注册过这些类型,开
    // allowReassignment 替换(design ADR-2 授权的库内覆写惯例)。均
    // lazy/待解析,替换后首个消费者(GrpcOfflineSyncPort / tracker /
    // SyncCoordinatorBloc / 各 remote DS)拿到的就是 fake。
    // F17-T1:deviceId 来源迁移 clientId —— 覆写对象由 BoundMarker 换成
    // TokenStorage(fake readClientId → 'e2e-device';configureDependencies
    // 的真实 TokenStorage 是 secure-storage 底,本环境不可读)。
    getIt.allowReassignment = true;
    getIt.registerSingleton<GrpcClient>(client);
    getIt.registerLazySingleton<ConnectivityGateway>(() => gateway);
    tokenStorage = _FakeTokenStorage();
    getIt.registerSingleton<TokenStorage>(tokenStorage!);

    // tracker 置 bound + offline(照 F10 管线测试先例直接驱动字段 ——
    // 消除 initialCheck 微任务竞态;构造本身已接 fake gateway 的流订阅,
    // 之后 add(true) 会同步把 online 翻回 true)。isGuest=false 即绑定态,
    // repo 三态路由落 boundOfflineLocal。
    getIt<SessionModeTracker>()
      ..isGuest = false
      ..online = false;

    server = srv;
    fakeSync = fake;
    onlineController = controller;
    grpcClient = client;
  });

  tearDown(() async {
    // 收尾(ADR-1):关协调器(连带计数聚合器)→ **先优雅关客户端通道** →
    // 停假 server → 关流 → 删测试库(link_support,先关库连接再删文件)。
    // 顺序关键:grpc 的 server.shutdown 会等已建 HTTP/2 连接的 peer 关闭,
    // 而客户端通道默认 idle 5 分钟才自动断 —— 不先关客户端会把整个
    // tearDown 挂到空闲超时(实测 5 分钟)。选 channel.shutdown(优雅
    // GOAWAY+关 socket)而非 terminate(强断):强断会让 server 侧 http2
    // 在流队列未空时触发内部断言,异步污染已完成的测试。
    try {
      await bloc?.close();
    } catch (_) {}
    try {
      await grpcClient?.channel.shutdown();
    } catch (_) {}
    try {
      // 限时兜底:任何残余等待(极端竞态)最多 5s,不拖垮文件级回归节奏。
      await server?.shutdown().timeout(const Duration(seconds: 5));
    } catch (_) {}
    try {
      await onlineController?.close();
    } catch (_) {}
    await deleteTestDb();
  });

  /// Either 展开帮助:离线写失败直接炸(夹具前置条件,非被测点)。
  T ok<T>(dz.Either<Failure, T> r) =>
      r.fold((f) => throw StateError('offline write failed: $f'), (v) => v);

  testWidgets(
      'FR-1 契约链路:bound 断网写 → 回网翻转 → 真 gRPC 上行 → 假 server '
      '收满 wire 契约批次 → synced/清墓碑/数据仍在', (t) async {
    final fake = fakeSync!;
    final online = onlineController!;
    final database = getIt<db.AppDatabase>();
    final accounts = getIt<AccountRepository>();
    final transactions = getIt<TransactionRepository>();
    final tags = getIt<TagRepository>();

    // ---- 步骤 1:bound+offline 经真 repo 路由写(三态落 boundOfflineLocal)
    //      account×2 + transaction×1(双分录)+ tag×2(删 1 → 墓碑)。
    final a1 = ok(await accounts.create(const CreateAccountParams(
      name: '离线现金',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 1000,
      ownership: Ownership.personal,
    )));
    final a2 = ok(await accounts.create(const CreateAccountParams(
      name: '离线储蓄',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 2000,
      ownership: Ownership.personal,
    )));
    final tagA = ok(await tags.create(name: '离线标签A', color: '#aa0000'));
    final tagB = ok(await tags.create(name: '离线标签B', color: '#00aa00'));
    ok<void>(await tags.delete(tagB.id));
    final txn = ok(await transactions.recordTransaction(
        RecordTransactionParams(
      transactionDate: DateTime.utc(2026, 9, 3),
      description: '离线转账',
      entries: [
        TransactionEntry(
            accountId: a1.id, debitCents: 500, creditCents: 0),
        TransactionEntry(
            accountId: a2.id, debitCents: 0, creditCents: 500),
      ],
    )));

    // DAO 断言:pending 头行 + 墓碑在库(路由确实走了本地落 pending)。
    expect(await database.accountDao.getPendingAccounts(), hasLength(2));
    expect(
        await database.transactionDao.getPendingTransactions(), hasLength(1));
    expect(await database.tagDao.getPendingTags(), hasLength(1));
    final tombs = await database.syncTombstoneDao.getAllTombstones();
    expect(tombs, hasLength(1));
    expect(tombs.single.module, SyncModule.tag);
    expect(tombs.single.entityId, tagB.id);

    // 版本快照(wire version 传递断言的参照:proto version 应逐行等于
    // drift 行乐观锁版本 —— 新建行均 v1)。
    final versionsById = <String, int>{
      for (final r in await database.accountDao.getPendingAccounts())
        r.id: r.version,
      for (final r in await database.transactionDao.getPendingTransactions())
        r.id: r.version,
      for (final r in await database.tagDao.getPendingTags()) r.id: r.version,
    };

    // ---- 步骤 2:覆写后 DI 构造协调器(offline 构造 → 补扫只计数不 push)
    //      → fake gateway 发 online true → 等收敛(纯 Future,ADR-3)。
    bloc = getIt<SyncCoordinatorBloc>();
    await until(() => bloc!.state.pendingCount == 5, '构造补扫/计数流收敛到 5');
    online.add(true); // 回网边沿
    await until(() => bloc!.state.status == SyncStatus.clean, '回网后同步收敛 clean');

    // ---- 步骤 3:假 server 断言(wire 契约,与 server T2 逐字段一致)。
    expect(fake.requests, hasLength(1), reason: '单次回网边沿恰好一次 PushChanges');
    final req = fake.requests.single;

    // 批次规模:2 账户 + 1 交易 + 1 标签 + 1 墓碑 = 5 条变更。
    expect(req.changes, hasLength(5));
    expect(req.changes.map((c) => c.entityType).toSet(),
        {SyncModule.account, SyncModule.transaction, SyncModule.tag});

    // 墓碑:DELETE + 空 payload + entityId;版本不载(server 对 DELETE 不
    // 消费版本);deviceId 同载。
    final tombstones = req.changes
        .where((c) => c.operation == pb.SyncOperation.SYNC_OPERATION_DELETE)
        .toList();
    expect(tombstones, hasLength(1));
    final tomb = tombstones.single;
    expect(tomb.entityType, SyncModule.tag);
    expect(tomb.entityId, tagB.id);
    expect(tomb.payload, isEmpty);
    expect(tomb.hasVersion(), isFalse);
    expect(tomb.deviceId, 'e2e-device');

    // 实体 op 区分(F18-T2 触达语义,测试语义更新):version==1 → CREATE
    //(首建),否则 UPDATE(本地编辑 bump)。本批:交易/标签首建 v1 → CREATE;
    // 两账户因转账记余额被 update 过(v2)→ UPDATE。单设备 upsert 语义下
    // 两类均为「本地最新全量行」,fake server 不按 op 分流(真 server 的
    // 存在性统一检测由 server T1 集成测试钉)。
    final entities = req.changes
        .where((c) => c.operation == pb.SyncOperation.SYNC_OPERATION_CREATE)
        .toList();
    expect(entities, hasLength(2));
    final updates = req.changes
        .where((c) => c.operation == pb.SyncOperation.SYNC_OPERATION_UPDATE)
        .toList();
    expect(updates, hasLength(2),
        reason: '两账户被转账记更新过(v2)→ UPDATE(F18-T2 区分语义)');
    final rows = [...entities, ...updates];

    Map<String, dynamic> rowOf(pb.SyncPayload c) =>
        jsonDecode(utf8.decode(c.payload)) as Map<String, dynamic>;

    for (final c in rows) {
      final row = rowOf(c);
      // deviceId = clientId(fake TokenStorage 注入,F17-T1)。
      expect(c.deviceId, 'e2e-device');
      // 每实体 payload.ID == entityId(同源 drift 主键不变量;server T1
      // 对不一致 fail-closed,此处消费方钉同一不变量)。
      expect(row['ID'], c.entityId);
      // 无 TenantID 键(鉴权 tenant 恒赢)、无本地私有 syncState 键。
      expect(row.containsKey('TenantID'), isFalse);
      expect(row.containsKey('SyncState'), isFalse);
      expect(row.containsKey('syncState'), isFalse);
      // 时间戳 RFC3339 显式 Z(Go time 精确往返);行内无软删。
      expect(row['CreatedAt'], isA<String>());
      expect(row['CreatedAt'] as String, endsWith('Z'));
      expect(row['DeletedAt'], isNull);
      // version 传递:proto version == drift 行版本快照。
      expect(c.version.toInt(), versionsById[c.entityId]);
    }

    // account 行:键集与 T2 syncAccountRow 逐字一致 + 枚举 int(T2 同值域:
    // asset=1/savings=1/personal=1/active=1)+ 名字回读。
    final accountRows = <String, Map<String, dynamic>>{};
    for (final c in rows.where((c) => c.entityType == SyncModule.account)) {
      final row = rowOf(c);
      expect(row.keys.toSet(), _t2AccountKeys,
          reason: 'account 行键集须与 server T2 syncAccountRow 逐字一致');
      expect(row['AccountType'], isA<int>());
      expect(row['AccountType'], 1);
      expect(row['Category'], isA<int>());
      expect(row['Category'], 1);
      expect(row['Ownership'], isA<int>());
      expect(row['Ownership'], 1);
      expect(row['Status'], isA<int>());
      expect(row['Status'], 1);
      accountRows[c.entityId] = row;
    }
    expect(accountRows[a1.id]!['Name'], '离线现金');
    expect(accountRows[a2.id]!['Name'], '离线储蓄');

    // transaction 行:键集 + 分录嵌套(T2 syncTransactionRow 同构:两条
    // 平衡分录随头行上行,分录锚回头行 id)。
    final txnChange = rows.singleWhere(
        (c) => c.entityType == SyncModule.transaction);
    final txnRow = rowOf(txnChange);
    expect(txnRow.keys.toSet(), _t2TransactionKeys);
    expect(txnRow['Description'], '离线转账');
    final txnEntries = txnRow['Entries'] as List<dynamic>;
    expect(txnEntries, hasLength(2));
    final debitSides = <int>[], creditSides = <int>[];
    for (final e in txnEntries.cast<Map<String, dynamic>>()) {
      expect(e.keys.toSet(), _t2EntryKeys);
      expect(e['TransactionID'], txn.id);
      (e['DebitCents'] as int) > 0
          ? debitSides.add(e['DebitCents'] as int)
          : creditSides.add(e['CreditCents'] as int);
    }
    expect(debitSides, [500]); // 借贷平衡:各 500(离线转账双分录)
    expect(creditSides, [500]);

    // tag 行:键集(T2 syncTagRow 同构)+ 内容回读。
    final tagChange =
        rows.singleWhere((c) => c.entityType == SyncModule.tag);
    final tagRow = rowOf(tagChange);
    expect(tagRow.keys.toSet(), _t2TagKeys);
    expect(tagRow['Name'], '离线标签A');
    expect(tagRow['Color'], '#aa0000');

    // ---- 步骤 4:OK 响应后本地断言:pending 清(synced)/墓碑清/数据仍在
    //      (ADR-4 简化:镜像刷新走到「假 server 缺各模块 List 服务 → repo
    //      Left → mirror no-op」即止,不真跑镜像往返 —— pending 已 synced
    //      无 refresh 也不丢;「数据仍在」即断言口径,refresh 的 pending
    //      保护已由 F10 管线单测钉)。
    expect(await database.accountDao.getPendingAccounts(), isEmpty);
    expect(await database.transactionDao.getPendingTransactions(), isEmpty);
    expect(await database.tagDao.getPendingTags(), isEmpty);
    expect(await database.syncTombstoneDao.getAllTombstones(), isEmpty);

    final allAccounts = await database.accountDao.getAllAccounts();
    final mine = allAccounts
        .where((a) => a.id == a1.id || a.id == a2.id)
        .toList();
    expect(mine, hasLength(2), reason: '上行成功后本地行仍在(未被误清)');
    expect(mine.every((a) => a.syncState == SyncState.synced), isTrue);
    final namesById = {for (final a in mine) a.id: a.name};
    expect(namesById[a1.id], '离线现金');
    expect(namesById[a2.id], '离线储蓄');

    final head = await database.transactionDao.getTransactionById(txn.id);
    expect(head, isNotNull);
    expect(head!.syncState, SyncState.synced);
    final headEntries = (await database.transactionDao.getAllEntries())
        .where((e) => e.transactionId == txn.id)
        .toList();
    expect(headEntries, hasLength(2), reason: '分录随头行仍在');

    final tagRowAfter = await database.tagDao.getTagById(tagA.id);
    expect(tagRowAfter, isNotNull);
    expect(tagRowAfter!.name, '离线标签A');
    // 被删 tag 未复活(墓碑清了,server 侧本就无此行)。
    expect(await database.tagDao.getTagById(tagB.id), isNull);
  });

  testWidgets(
      'FR-2 失败重试:unavailable → failed+pending 保留 → server 恢复 → '
      '手动重试收敛 clean,server 收到两次批次(重推幂等)', (t) async {
    final fake = fakeSync!;
    final online = onlineController!;
    final database = getIt<db.AppDatabase>();
    final accounts = getIt<AccountRepository>();

    // bound+offline 写 1 账户(本测试的待上行批次)。
    final a1 = ok(await accounts.create(const CreateAccountParams(
      name: '离线重试现金',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 3000,
      ownership: Ownership.personal,
    )));
    expect(await database.accountDao.getPendingAccounts(), hasLength(1));

    bloc = getIt<SyncCoordinatorBloc>();
    await until(() => bloc!.state.pendingCount == 1, '补扫计数收敛到 1');

    // 响应模式=unavailable → 回网翻转 → failed(网络类失败收敛,pending 保留)。
    fake.mode = _PushMode.unavailable;
    online.add(true);
    await until(() => bloc!.state.status == SyncStatus.failed, '失败路径收敛 failed');
    // port 对网络类失败的 reason 形态:'网络不可用(<codeName>),变更已保留待重试'
    // (grpc codeName 大写)。
    expect(bloc!.state.failureReason, contains('UNAVAILABLE'));
    // pending 保留(badge 状态语义级:下次触发重试补上行)。
    expect(await database.accountDao.getPendingAccounts(), hasLength(1));
    // 第一次批次已抵达 server(被拒 —— server 收到请求但回 unavailable)。
    expect(fake.requests, hasLength(1));

    // server 恢复 OK → 手动 add(SyncRetryRequested)→ 收敛 clean。
    fake.mode = _PushMode.ok;
    bloc!.add(SyncRetryRequested());
    await until(() => bloc!.state.status == SyncStatus.clean, '重试后收敛 clean');

    // 重推幂等语义:同一实体全量行重发,第二次才成功 —— server 恰收到两批,
    // 两批 entityId 一致。
    expect(fake.requests, hasLength(2));
    expect(fake.requests[0].changes.single.entityId, a1.id);
    expect(fake.requests[1].changes.single.entityId, a1.id);
    expect(fake.requests[1].changes.single.deviceId, 'e2e-device');

    // 成功后本地收敛:pending 清 + 数据仍在。
    expect(await database.accountDao.getPendingAccounts(), isEmpty);
    final after = (await database.accountDao.getAllAccounts())
        .where((a) => a.id == a1.id)
        .toList();
    expect(after, hasLength(1));
    expect(after.single.syncState, SyncState.synced);
    expect(after.single.name, '离线重试现金');
  });

  testWidgets(
      'F17-T2 FR-3/FR-6 双设备模拟:设备 A 断网写 → 回网 push(fake 落 log)→ '
      '同进程模拟设备 B(换 clientId+清本地行+游标归零)→ pull 触发 → '
      'envelope→drift 应用,A 的数据在 B 侧复现', (t) async {
    final fake = fakeSync!;
    final online = onlineController!;
    final database = getIt<db.AppDatabase>();
    final accounts = getIt<AccountRepository>();
    final tags = getIt<TagRepository>();

    // ---- 设备 A('e2e-device',setUp 缺省):bound+offline 写两模块。
    final a1 = ok(await accounts.create(const CreateAccountParams(
      name: '设备A账户',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 7000,
      ownership: Ownership.personal,
    )));
    final tagA = ok(await tags.create(name: '设备A标签', color: '#0a0a0a'));
    expect(await database.accountDao.getPendingAccounts(), hasLength(1));
    expect(await database.tagDao.getPendingTags(), hasLength(1));

    bloc = getIt<SyncCoordinatorBloc>();
    await until(() => bloc!.state.pendingCount == 2, '设备 A 补扫计数收敛到 2');
    online.add(true); // 回网边沿:pull 先行(log 空)→ push → push 后 pull(own-echo)
    await until(() => bloc!.state.status == SyncStatus.clean, '设备 A 收敛 clean');

    // fake 已落 2 条 log(A 的 push);A 的 push 后拉取把游标推进到页尾
    //(own-echo 过滤:回声不回灌,游标照走)。
    expect(fake.requests, hasLength(1));
    expect(fake.logEntries.map((e) => e.$2.entityId), containsAll([a1.id, tagA.id]));
    expect(await database.syncCursorDao.readLastPulledVersion(), 2);

    // ---- 同进程模拟设备 B('e2e-device-B'):
    //   库共享 = B 能看到 A 数据 → 先硬删 A 的行(模拟 B 的全新库没有这些行,
    //   DAO 裸删不走墓碑 —— B 从未拥有过它们,无上行语义)+ 游标归零
    //   (B 自己的库游标从 0 起)+ clientId 换 B(port 每次 RPC 现读)。
    //   取舍论证:库共享 ≠ 真双设备隔离(真 B 是独立 DB+独立安装),但
    //   envelope→drift 的下行应用路径被**真实覆盖**(payload 从 wire 反序列
    //   化、upsert 落库、syncState 收敛),隔离性差异只影响夹具构造方式,
    //   不影响被测链路本身。
    await database.accountDao.deleteAccountById(a1.id);
    await database.tagDao.deleteTagById(tagA.id);
    await database.syncCursorDao.writeLastPulledVersion(0);
    tokenStorage!.clientId = 'e2e-device-B';

    // B 注册设备行(FR-2:server 按非空 device_id 幂等回显)。
    await getIt<OfflineSyncPort>().registerDevice('windows-B');
    expect(fake.deviceRegistrations, hasLength(1));
    expect(fake.deviceRegistrations.single.deviceId, 'e2e-device-B');

    // 设备 B 的协调器:直接构造(绕过 lazySingleton —— 同进程第二实例),
    // 组件全走 DI 已覆写的真件(port=真 GrpcOfflineSyncPort→假 server)。
    final blocB = SyncCoordinatorBloc(
      getIt<OfflineSyncPort>(),
      getIt<PendingCollector>(),
      getIt<SessionModeTracker>(),
      database,
      online.stream, // 共享回网流:不再发边沿,触发走手动事件
      null, // 镜像不注入:本链路数据断言以 DAO 为准(镜像往返是 F10 链路的面)
      null, // 计数聚合器:bloc 自建
      PullApplier(database), // F17-T2 下行应用器(真件)
      tokenStorage!.readClientId, // own-echo 过滤:B 的身份
    );
    await bloc!.close();
    bloc = blocB; // tearDown 统一收尾

    blocB.add(SyncRetryRequested());
    await until(() => blocB.state.status == SyncStatus.clean, '设备 B 拉取收敛 clean');

    // B 拉了全量 log(since=0),A 的两条(deviceId='e2e-device' ≠ B)被应用。
    expect(fake.pullRequests, isNotEmpty);
    expect(fake.pullRequests.last.sinceVersion.toInt(), 0);
    final accB = await database.accountDao.getAccountById(a1.id);
    expect(accB, isNotNull, reason: '设备 A 的账户经 pull 在 B 侧复现');
    expect(accB!.name, '设备A账户');
    expect(accB.syncState, SyncState.synced);
    final tagB2 = await database.tagDao.getTagById(tagA.id);
    expect(tagB2, isNotNull);
    expect(tagB2!.name, '设备A标签');
    expect(tagB2.syncState, SyncState.synced);

    // B 无本地变更 → 不 push(fake 仍只收到 A 的那一批)。
    expect(fake.requests, hasLength(1));
    // B 的游标推进到 frontier。
    expect(await database.syncCursorDao.readLastPulledVersion(), 2);
  });

  testWidgets(
      'F18-T3 FR-5/FR-8 双设备冲突全链:A 断网写→push;模拟 B 独立编辑同 '
      '实体→push 命中 fake 冲突→本地标 synced(确认)+协调器 conflicts 携带'
      '→badge 冲突 chip onTap 进面板→双栏摘要→「保留我的」→fake '
      'resolveConflict(client)+面板刷新空', (t) async {
    final fake = fakeSync!;
    final online = onlineController!;
    final database = getIt<db.AppDatabase>();
    final accounts = getIt<AccountRepository>();

    // ---- 设备 A('e2e-device'):断网写 1 账户 → 回网 push 落 fake log。
    final a1 = ok(await accounts.create(const CreateAccountParams(
      name: '设备A账户',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 7000,
      ownership: Ownership.personal,
    )));
    bloc = getIt<SyncCoordinatorBloc>();
    await until(() => bloc!.state.pendingCount == 1, '设备 A 补扫计数收敛到 1');
    online.add(true); // 回网边沿:pull(空)→ push → clean
    await until(() => bloc!.state.status == SyncStatus.clean, '设备 A 收敛 clean');
    expect(fake.logEntries, hasLength(1), reason: 'A 的行已落 server(log)');
    expect(bloc!.state.conflictCount, 0);

    // ---- 模拟设备 B('e2e-device-B'):换 clientId + 硬删 A 行 + 种同 id
    //      不同内容行(模拟 B 独立编辑同实体;DAO 裸操作不走 repo 路由,
    //      行直接置 pending 供收集器上行)。
    final rowA = (await database.accountDao.getAccountById(a1.id))!;
    await database.accountDao.deleteAccountById(a1.id);
    await database.accountDao.insertAccount(
      rowA.toCompanion(true).copyWith(
            name: const Value('设备B账户'),
            currentBalanceCents: const Value(9900),
            syncState: const Value(SyncState.pending),
          ),
    );
    tokenStorage!.clientId = 'e2e-device-B';

    // fake 预设冲突面:该 entityId 的 push 命中「server 检测」的 fake 模拟
    //(版本比对不做,见 _FakeSyncService.conflictEntityIds 注释)。
    fake.conflictEntityIds.add(a1.id);

    // 设备 B 的协调器:同进程第二实例(照 F17-T2 双设备先例)。
    final blocB = SyncCoordinatorBloc(
      getIt<OfflineSyncPort>(),
      getIt<PendingCollector>(),
      getIt<SessionModeTracker>(),
      database,
      online.stream,
      null,
      null,
      PullApplier(database),
      tokenStorage!.readClientId,
    );
    await bloc!.close();
    bloc = blocB; // tearDown 统一收尾

    blocB.add(SyncRetryRequested());
    await until(() => blocB.state.status == SyncStatus.clean, '设备 B 收敛 clean');

    // ---- 断言 1:本地行标 synced(FR-2 确认语义;内容仍是 B 的版本)。
    final rowB = await database.accountDao.getAccountById(a1.id);
    expect(rowB, isNotNull, reason: '冲突确认不清行');
    expect(rowB!.syncState, SyncState.synced, reason: 'push 命中冲突 → 标 synced');
    expect(rowB.name, '设备B账户');

    // ---- 断言 2:协调器 conflicts 完整列表携带(FR-5 状态面)。
    expect(blocB.state.conflictCount, 1);
    final carried = blocB.state.conflicts.single;
    expect(carried.conflictId, isNotEmpty);
    expect(carried.module, SyncModule.account);
    expect(carried.entityId, a1.id);

    // ---- 断言 3:fake 侧冲突面 —— B 的冲突条未落 log(server 跳过语义)。
    expect(fake.logEntries, hasLength(1));

    // ---- 断言 4:badge 冲突态渲染 + onTap 进面板(FR-5)。
    //      最小 GoRouter harness:真 badge + 真 ConflictPanelPage + 真 bloc/
    //      port(DI 已指向假 server),不挂 AppShell(其依赖面与本链路无关)。
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => BlocProvider<SyncCoordinatorBloc>.value(
            value: blocB,
            child: const Scaffold(
              body: Align(
                  alignment: Alignment.centerLeft, child: SyncStatusBadge()),
            ),
          ),
        ),
        GoRoute(
          path: '/settings/conflicts',
          builder: (_, __) => BlocProvider<ConflictListBloc>(
            create: (_) => ConflictListBloc(getIt<OfflineSyncPort>()),
            child: const ConflictPanelPage(),
          ),
        ),
      ],
    );
    await t.pumpWidget(MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light(),
    ));

    // badge 冲突 chip(warn amber「冲突 1」)渲染。
    await _pumpUntil(t, () => find.text('冲突 1').evaluate().isNotEmpty,
        'badge 冲突 chip 渲染');

    // onTap 可达 → 进面板;面板经真 gRPC listConflicts 拉 fake backlog。
    await t.tap(find.text('冲突 1'));
    await _pumpUntil(t, () => find.text('同步冲突').evaluate().isNotEmpty,
        '面板打开');

    // ---- 断言 5:条目渲染双栏摘要(双 payload 均为真实 wire envelope bytes:
    //      server 栏 = A 的行,「我的」栏 = B 的行;模块徽章中文模块名)。
    await _pumpUntil(
        t, () => find.text('服务端版本').evaluate().isNotEmpty, '面板加载出条目');
    expect(find.text('账户'), findsOneWidget, reason: '模块徽章(中文模块名)');
    expect(find.text('名称:设备A账户'), findsOneWidget, reason: '服务端栏摘要');
    expect(find.text('名称:设备B账户'), findsOneWidget, reason: '我的栏摘要');
    expect(find.text('待处理 1 条'), findsOneWidget, reason: '总数(权威计数)');

    // ---- 断言 6:「保留我的」→ fake resolveConflict(client)被调 + 面板
    //      刷新空(FR-5 解决流闭环)。
    await t.tap(find.text('保留我的'));
    await _pumpUntil(t, () => find.text('无待处理冲突').evaluate().isNotEmpty,
        '解决后面板刷新为空');

    expect(fake.resolveRequests, hasLength(1));
    expect(fake.resolveRequests.single.conflictId, carried.conflictId);
    expect(fake.resolveRequests.single.resolution, 'client',
        reason: '「保留我的」→ resolution=client');

    // 收尾:harness 的面板 bloc 由 provider 拥有,随下一测试 DI reset 释放;
    // 此处显式停 pump 源(MaterialApp 由后续测试覆盖)。
  });
}

/// UI 收敛等待(集成测试的 pump 轮询:gRPC 真往返 + bloc 异步链,不定长;
/// 50ms 步进,10s 上限 —— 照本文件纯 Future until 的同款口径)。
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() cond,
  String reason,
) async {
  final sw = Stopwatch()..start();
  while (!cond() && sw.elapsed < const Duration(seconds: 10)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(cond(), isTrue, reason: reason);
}
