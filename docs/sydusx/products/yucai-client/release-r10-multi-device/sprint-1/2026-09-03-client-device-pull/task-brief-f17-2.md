# Task Brief F17-T2 — PullApplier + 拉取编排 + 台账查证裁决

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r10-f17`。**TDD。** T1(82e43334)已就绪(clientId/registerDevice/conflicts 消费/Dart stub 齐备)。

## 先读(必读)
1. `docs/.../2026-09-03-client-device-pull/{spec.md FR-3/4,design.md ADR-2/3/4}`
2. `lib/backup/data/archive_importer.dart`(**envelope 行→drift 写入的底料**——注意它是 purge+全量 insert,applier 需要的是**单行 upsert**,抽取或参考其行映射;mirror_mappers 是 domain→drift 反向)
3. `lib/binding/presentation/bloc/sync_coordinator_bloc.dart`(编排挂点:回网边沿/push 成功后/构造补扫)、`lib/binding/data/grpc_offline_sync_port.dart`(T1 后形态)
4. `integration_test/link_offline_sync_e2e_test.dart`(fake 的 registerDevice/pullChanges UnimplementedError 桩 :87-97 + bridge 仅注册 PushChanges :113-124——扩展点)
5. **台账查证(ADR-4 前置)**:server 侧 holding 台账存储现状——`server/internal/holding/` 的 repo/ent 是否有 holding_transactions 表与写入路径?binding mirror `_refreshHoldings` 的 `listHoldingTransactions` 走哪个 RPC、server 端实现在哪、数据从哪来?裁决:server 有台账存储→实施 holding_ledger 上行+writer;无→**整块 defer 到 sprint-2**(spec 措辞"视查证"授权,记 ledger 即可)。

## 交付物
### 1. 台账查证裁决(先做)
按第 5 节查证,产出裁决(注释+ledger 记账):实施或 defer。

### 2. PullApplier(ADR-2)
`lib/binding/data/pull_applier.dart`:
- 输入:PullChangesResponse 的 changes(SyncPayload 流)。
- 逐条:`CREATE/UPDATE`→payload jsonDecode→envelope 行→drift upsert(**复用 archive_importer 的行映射——抽取共享 helper 或最小 adapter,单一事实源策略注释**;**同 id 本地 pending→跳过+计 skipped**);`DELETE`→本地硬删+**写墓碑**(SymmetricTombstones;照上行对称,幂等无害注释)。
- 8 模块覆盖(importer 已有 8 模块映射,applier 大部分是接线);台账视裁决。
- 事务:整批 drift 事务(原子应用)。
- guest 态:不应用(协调器门控;applier 本身可无门控,注释)。

### 3. 游标存储+拉取编排(ADR-3)
- 游标:本地(drift 单行——查库内既有 kv/primitive 表先例,没有则 `sync_cursor` 表一行;读写 helper)。
- `OfflineSyncPort` 扩 `pull(sinceVersion, entityTypes?, pageSize?) → PullBatch{changes(原始 payload 流), latestVersion, hasMore}`(domain DTO;Grpc 实现;Noop no-op 返回空)。
- 协调器:`_pullAndApply()`——**回网时 pull 先于 push**(收最新再发);**push 成功后 pull**(他设备变更感知);分页循环(since=游标→应用→游标=页尾→hasMore 续);失败容忍(拉失败不阻断 push 流,log+状态不破);构造补扫 online 分支同样先 pull。
- applier skipped 与 pending 保护语义注释钉死(与 mirror ADR-3 同族)。

### 4. e2e fake 扩展+双设备场景
- fake:registerDevice(记录+返回 deviceId)/pullChanges(可编程:基于已收 push 的 sync_log 模拟——**fake 内部维护 log 列表**:push 时 append,pull 时按 since 过滤返回;轻量,不需要真业务表);bridge 注册 2 方法。
- **双设备模拟测试**(F13 文件扩展或新 e2e 文件):设备 A(clientId-A)断网写→回网 push(fake 落 log);**重置 DI/第二套?——同进程模拟设备 B**:换 ClientIdProvider 返回 clientId-B+清 pending(设备 B 无本地未同步)→构造协调器→pull 触发→断言 drift 中出现设备 A 的数据(envelope→drift 应用)。取舍:同一测试库内模拟(库共享=设备 B 能看到 A 数据,断言即"应用后数据在");注释论证与真双设备的差距(库共享≠隔离,但 applier 应用路径被真实覆盖)。

### 5. TDD
- applier 单测:upsert 应用(8 模块抽 3 深+其余轻)/DELETE+墓碑/pending 跳过/原子性。
- port pull:请求参数映射/响应 DTO/分页。
- 协调器:回网先拉后推/push 后拉/拉失败不破/游标推进/分页续拉。
- e2e:双设备场景。

## 验证
1. 新单测绿(先红后绿)
2. `flutter test` 全量(≥1468)
3. F13 e2e 单文件跑绿(杀残留)
4. `flutter analyze` 0 新增;`go test`(server 若动)

## 约束
中文注释;F10-F13/T1 语义零回归;不 commit。完成后报告(含台账裁决)。
