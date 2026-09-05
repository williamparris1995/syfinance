# Task Brief F13-T1 — 契约链路测试(消费方 CDC)

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r9-f13`,客户端 `yucai/client/`。

## 先读(必读)

1. `docs/.../2026-09-03-offline-e2e/{spec.md,design.md}`(全部 ADR)
2. `lib/proto/sync/v1/sync.pbserver.dart`(SyncServiceBase)+ `sync.pbgrpc.dart`(PushChangesRequest/PushResponse 形态)
3. `lib/core/network/grpc_client.dart`(AppConfig 端口来源——DI 覆写点)+ `app_config.dart`
4. F10/F11/F12 交付:`offline_sync_pipeline_test.dart`(test/binding/——**最近的链路测试先例**,DI 驱动方式照抄)、`grpc_offline_sync_port.dart`、`pending_collector.dart`、`session_mode_tracker.dart`
5. `integration_test/link_support.dart` + 任一 `link_*_test.dart`(文件结构/守卫/删库惯例)
6. F11 T2 server 侧钉的 wire 契约(`yucai/server/tests/sync_push_integration_test.go` 的 syncAccountRow 形态——client 断言须与之逐字段一致)

## 交付物

### 1. `integration_test/link_offline_sync_e2e_test.dart`(新)

**Harness(design ADR-1/2)**:
- resetTestDb() 后 DI 覆写:FakeConnectivityGateway(StreamController.broadcast 可控)+ GrpcClient(channel→127.0.0.1:临时端口;看 AppConfig/GrpcClient 构造选最小覆写路径)+ BoundMarker fake(返回 'e2e-device');tracker 置 bound。
- FakeSyncService extends SyncServiceBase:记录 PushChangesRequest 原始 proto;可编程响应模式(OK/unavailable);其余 5 方法 throw UnimplementedError(不调用)。grpc Server 绑 localhost:0 取端口 → 覆写 GrpcClient 用该端口。tearDown:server.shutdown + 删库。

**FR-1 链路(主测试)**:
1. bound+offline(fake gateway online=false)→ 经真 local DS(repo 路由)写:account×2+transaction×1+tag×1+删 1 tag(墓碑)→ DAO 断言 pending/墓碑。
2. `getIt<SyncCoordinatorBloc>()`(覆写后 DI)→ fake gateway 发 online true → 等待收敛(Completer/轮询 clean 态,纯 Future 无 UI——design ADR-3)。
3. **假 server 断言**(wire 契约,与 server T2 逐字段一致):changes 数=5;entityType 集合;payload jsonDecode:account 行 PascalCase 键集/无 TenantID 无 syncState/枚举 int;墓碑=DELETE+空 payload+entityId;deviceId='e2e-device';每实体 payload.ID==entityId;version 传递。
4. OK 响应后本地断言:pending 清(synced)/墓碑清/数据仍在(ADR-4 简化:不真跑镜像,断言本地行内容未动)。

**FR-2 失败重试(第二测试)**:响应模式 unavailable → 状态 failed+pending 保留 → 切 OK → 手动 add(SyncRetryRequested)→ 收敛 clean+server 收到两次批次(重推幂等语义——第二次才成功)。

### 2. Makefile:E2E_FILES 尾追加。

## 验证(全部执行并贴证据)

1. 单文件跑绿(-d windows --dart-define=YUCAI_DB_FILE=yucai_test.db,杀残留)
2. `make client-e2e` 全量(含新文件)绿
3. `flutter test` 全量不回归
4. `flutter analyze` 新文件 0 条;测后删库确认

## 约束

不改生产代码(若 DI 覆写需要生产代码加测试缝——最小且注释,报告说明);中文注释;不 commit。完成后报告。
