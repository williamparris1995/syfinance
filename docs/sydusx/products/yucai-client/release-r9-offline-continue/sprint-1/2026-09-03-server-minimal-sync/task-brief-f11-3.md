# Task Brief F11-T3 — client 接线:GrpcOfflineSyncPort + 孤儿分红合成头行

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r9-f11`,客户端 `yucai/client/`。**TDD。** F10(全链)+ T1/T2(server)已就绪。server 侧接受的 wire 形态已被 T2 集成测试钉死(envelope 行同构:PascalCase/int 枚举/RFC3339 Z/未知字段容忍/无 tenant 键)。

## 先读(必读)

1. `docs/.../2026-09-03-server-minimal-sync/{spec.md FR-4/5,design.md ADR-2/5/6}`
2. F10 交付:`lib/binding/domain/offline_sync_port.dart`(SyncBatch/SyncEntityDto/SyncResult 语义)、`lib/binding/data/pending_collector.dart`(现为 drift 行 toJson 快照)、`lib/binding/data/noop_offline_sync_port.dart`(待替换)、`lib/binding/presentation/bloc/sync_coordinator_bloc.dart`
3. `lib/backup/data/local_snapshot_exporter.dart`(**行序列化事实源**:PascalCase 键的构造方式——ADR-2 要求抽取复用而非复制)
4. `lib/proto/sync/v1/sync.pbgrpc.dart`(SyncServiceClient.PushChanges)+ `lib/core/network/grpc_client.dart`/`auth_retry.dart`(gRPC 通道与重试封装,server 各 remote DS 的注入形态)
5. `lib/core/session_mode/bound_marker.dart`(tenant 串,deviceId fallback 来源)
6. `lib/holding/data/holding_local_ds.dart` recordDividend(ADR-6 合成头行落点,T2 review 后已有"已知缺口"注释)
7. server 侧 payload-id 一致性 fail-closed(T1 fix):**client 编码必须保证 DTO entityId 与 payload 内 id 一致**(天然同源,注释钉死)

## 交付物

### 1. 行序列化抽取(ADR-2)

- 从 local_snapshot_exporter 抽出可复用的 per-row 序列化 helper(8 模块;形态自定——如 `core/localdb/envelope_codec.dart` 或 backup/data 内公开函数;**单一事实源,exporter 改调它**,既有备份 e2e 断言守门);dartdoc 注明 F11 同步编码复用。

### 2. GrpcOfflineSyncPort(ADR-5)

- `lib/binding/data/grpc_offline_sync_port.dart`:注入 SyncServiceClient(经 AuthRetryCaller 包?照各 remote DS 形态——`_retry.call(() => _client.pushChanges(req))`)+BoundMarker。
- 编码:SyncBatch → `PushChangesRequest(changes:[...])`:实体→`SyncPayload{entityType: module 常量, operation: CREATE(或 UPDATE,单设备 upsert 语义——用 CREATE 注释合并语义), payload: 行序列化 bytes(jsonEncode), version: dto.version, deviceId: tenant 串(BoundMarker), entityId: dto.entityId}`;墓碑→`operation: DELETE, entityId, payload: 空`。
- 结果:grpc OK→SyncResult.ok(即使 conflicts 非空——单设备恒空,注释);grpc unavailable/网络类→SyncResult 失败(保 pending);其他 grpc 错误→失败(reason 带 code)。
- DI:替换 noop 注册(injection.dart 1h 段;noop 文件保留作测试/参考或删——自选注释)。

### 3. 孤儿分红合成头行(ADR-6)

- `holding_local_ds.recordDividend`:markPending 且无对应头行时,同事务合成 qty=0/avgCost=0 的 pending 持仓头行(替换现有"已知缺口"注释);镜像协调自动生效;补单测(离线裸分红→头行+台账都在且 pending→上行批次含两者)。

### 4. collector 适配

- 现为 drift 行 toJson 快照(fields);若 grpc port 直接复用行序列化 helper(从 drift 行→envelope 行形态),collector 可不动(port 内转换);**推荐**:SyncEntityDto.fields 保持 drift 行快照,port 编码时 drift 行→envelope 形态映射(复用 exporter 的映射逻辑——注意 exporter 是 domain 实体→envelope,而 collector 是 drift 行;**择一最小路径**:(a)collector 改产 domain 实体(port 用现有 exporter 序列化)或 (b)port 内 drift→envelope 映射。选 (a) 更贴单一事实源——collector 经各模块 local DS 读路径(getById/find)把 pending drift 行转 domain 实体,SyncEntityDto 持 domain 实体引用(fields 改为实体+版本)。改造面小,注释理由)。设计自由度给你,但**编码逻辑必须单一事实源**且 T2 钉死的 wire 形态有 client 侧断言。

### 5. TDD 测试

- port 单测:批次→PushChangesRequest 的字段级断言(entityType/payload bytes 解码后形态[PascalCase/枚举 int/无 tenant 键/剔 syncState]/version/deviceId/entityId;墓碑 DELETE);grpc 成功/网络失败/其他错误三态;**payload 内 id==entityId 一致性**(构造即保证,断言钉)。
- 孤儿分红:上述 3 的单测。
- collector(若改造):domain 实体产出+版本。
- 现有 sync_coordinator/offline_sync_pipeline 测试适配(fake port 不受影响应全绿)。

## 验证(全部执行并贴证据)

1. 新单测绿(先红后绿)
2. `flutter test` 全量不回归(≥1373)
3. `flutter analyze` 新文件 0 条
4. `cd yucai/server && go test ./... -count=1` 仍全绿(client 改动不触 server,保险)

## 约束

不改 server(T1/T2 已定);F10 语义不动(port 接口/协调器行为);中文注释;不 commit。完成后报告(含:编码路径选择 (a)/(b) 及理由)。
