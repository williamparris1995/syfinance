# Task Brief F17-T1 — gen-dart 地基 + 设备身份真实化

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r10-f17`,客户端 `yucai/client/`,proto `yucai/proto/`。**TDD。**

## 先读(必读)
1. `docs/.../2026-09-03-client-device-pull/{spec.md FR-1/2/5,design.md ADR-1/5}`
2. 查证锚点:`lib/auth/data/token_storage.dart:12-21`(clientId 现成)、`lib/core/di/injection.dart:130-136`(生成)、`lib/binding/data/grpc_offline_sync_port.dart:109-110`(_deviceId 现状+'bound')、`lib/binding/presentation/bloc/binding_bloc.dart:103`(markBound('bound'))、`proto/gen-dart.sh`(工具链)
3. 既有测试:`test/binding/data/grpc_offline_sync_port_test.dart`(mock 形态)、`test/binding/presentation/bloc/binding_bloc_test.dart`(绑定流程)

## 交付物
### 1. gen-dart 前置(FR-1)
1. `dart pub global activate protoc_plugin`(实测未装;AGENTS.md 声明失实——**装好后顺手修 AGENTS.md:10** 的表述为实际可验证事实)。
2. `cd yucai && make gen-dart` → **diff 面断言**:恰好 `lib/proto/sync/v1/sync.pb.dart`+`sync.pbjson.dart` 变化(GetSyncStatusRequest.deviceId + ConflictDTO.conflictType);**其他 proto 文件零变化**——若有意外的全量漂移,停下分析(逐文件 diff,与 protoc 版本差异相关的格式抖动要能解释或还原)。
3. `dart analyze lib/proto/` 干净。

### 2. 设备身份真实化(FR-2, ADR-1)
1. `GrpcOfflineSyncPort` 构造注入 `TokenStorage`(或最小接口 `ClientIdProvider`——按库内 DI 惯例选,注释);`_deviceId()=await tokenStorage.clientId()`(uuid 串)。
2. `binding_bloc`:上传成功+markBound 后,fire-and-forget `RegisterDevice(deviceId=clientId, deviceName=设备名[平台名或'Windows desktop'——取 Platform 简单值,注释])`;失败 log warn 不阻断绑定(幂等,下次绑定或 F17-T2 拉取时重试亦可——注释);**RegisterDeviceRequest wire 无 deviceId 字段**(查证)——server 幂等键=device 行 id=deviceId:**proto RegisterDeviceRequest 加 `string device_id = 1`**?查证 server handler 读什么——若 server 只从 context/metadata 取,client 经 `x-client-id` header 已送(每 RPC 都带)——**先查 server RegisterDevice handler 的 deviceId 来源再定 proto 是否要改**;最小路径优先(header 已有则零 proto 改动,注释论证)。
3. `_NoopBoundMarker`/fakes 适配;所有 'bound' 相关注释更新(F16 过渡容忍句改为已闭环)。

### 3. PushResponse 接收+conflicts 映射(FR-5 最小面, ADR-5)
1. port `push()` 接 `PushResponse`;conflicts 非空→映射 `List<SyncConflictInfo>`(domain DTO 扩展:module/entityId/conflictType——`offline_sync_port.dart` 增类);`SyncResult` 扩 `conflicts`(默认空,既有构造兼容);**ok 语义不变**(conflicts 非空仍 ok——单设备无感,多设备信息已携带)。
2. 协调器:`_onTriggered` 成功路径把 conflicts 透传到状态(F12 badge 的 failureReason 通道或新字段——最小面:`SyncCoordinatorState.conflictCount`(默认 0)+failed/clean 均可携带;badge F12 组件**不改**(F18 面板),仅状态携带——注释)。

### 4. TDD
- port:deviceId=clientId 断言(mock TokenStorage);RegisterDevice 调用(mock);conflicts 映射(PushResponse 含 2 conflict→SyncResult.conflicts 恰 2 条)。
- binding_bloc:成功流程发 RegisterDevice(fire-and-forget 容错:Register 抛错→绑定仍 success)。
- 协调器:conflicts 透传断言。
- **F13 契约 e2e 适配**:`link_offline_sync_e2e_test` 的 `_FakeBoundMarker`('e2e-device')——deviceId 现从 TokenStorage 取,fake 注入点改 TokenStorage(或 provider 接口);断言值更新;确认仍绿。

## 验证
1. `flutter test` 全量(≥1464;含 F13 契约文件单跑:杀残留+`flutter test integration_test/link_offline_sync_e2e_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`)
2. `flutter analyze` 0 新增
3. gen-dart diff 面证据(第 1 节第 2 点)
4. `go test ./... -count=1`(server 若 proto 动了则 regen Go 同步;预计零 proto 改动则跳过)

## 约束
中文注释;F10-F13 语义零回归;不 commit。完成后报告(含 RegisterDevice deviceId 来源查证结论)。
