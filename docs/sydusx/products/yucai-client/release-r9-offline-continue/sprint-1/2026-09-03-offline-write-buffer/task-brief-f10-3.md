# Task Brief F10-T3 — 回网同步管线(port+协调器+fake)

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r9-f10`,客户端 `yucai/client/`。**TDD。** T1(27ec26aa 三态路由/降级)+ T2(c0c13d05 pending/墓碑/DAO 靶点)已就绪。

## 先读(必读)

1. `docs/.../2026-09-03-offline-write-buffer/{spec.md FR-5,design.md ADR-5}`(OfflineSyncPort/SyncBatch/SyncCoordinator/状态流)
2. T2 交付的 DAO 靶点:各头表 `getPending*`/`watchPending*`、`SyncTombstoneDao`(getAll/getByModule/clearTombstone/clearAll)、`core/localdb/sync_state.dart`(SyncModule)
3. `lib/binding/data/mirror_mappers.dart`(实体→drift 行;**批次 DTO 的映射可参考其逆向**——上行需要实体/drift 行→DTO,形态自定)
4. `lib/core/connectivity/connectivity_gateway.dart`(online 流)+ `notifications_bootstrap.dart:68-77`(回网订阅先例)
5. 休眠契约面:`lib/proto/sync/v1/sync.pb.dart`(lastSyncVersion/lastSyncAt 字段;**本任务不接 gRPC**,F11 才实现——port 的 batch 形态设计时对齐该 proto 的语义走向,注释说明)

## 交付物

### 1. OfflineSyncPort + SyncBatch(binding/domain/)

- `SyncBatch`:各模块 pending 实体集合(8 模块;形态自定——推荐按模块分桶 `{module: List<实体DTO>}`)+墓碑集合(module+entityId)。DTO 形态:可用 drift 行的 Map/自定义轻类,**对齐 sync proto 语义走向并注释**。
- `OfflineSyncPort` 抽象:`Future<SyncResult> push(SyncBatch batch)`;`SyncResult`(成功/部分失败+原因)。dartdoc:F11 gRPC 实现替换点。

### 2. PendingCollector(binding/data/)

- 从 DAO 收集 pending 实体+墓碑 → 构造 SyncBatch(映射复用 mirror_mappers 逆向或直接 drift 行);空批次感知(无 pending 无墓碑→null/empty)。

### 3. SyncCoordinator(binding/presentation/bloc/ 或 data/,倾向 bloc 供 F12 UI 消费)

- 触发:ConnectivityGateway.online 流(true 边沿)+ 手动 retry 事件;进行中幂等(忽略重入);仅 bound 态生效(guest 不触发,注释)。
- 流程:collect → batch 空→clean 态;非空→syncing(n) → port.push → 成功:回写 synced(markAllSynced DAO 方法——T2 无则补)+清墓碑+刷新镜像(refreshAll 或按模块)→clean;失败:failed(reason)+保留 pending(下次触发重试)。
- 状态流:`SyncStatus{idle, clean, syncing(int pending), failed(String reason)}` 对外暴露(bloc state);命名照库内 ...Requested/...State 惯例。
- DI:port 注册 fake 实现(测试用)+ 真实现占位(F11 替换;占位可 `throw UnimplementedError('F11')` 但**不接线到生产路径**——生产注册 fake?不:生产注册一个「F11 未落地前 no-op+debugPrint」实现并注释,避免绑定时崩)。

### 4. 集成断言(核心验收)

单测级完整链(真 drift 内存库+真 DS+fake port):
1. bound-offline 写几笔(跨 2+ 模块)+删一笔(墓碑)→ pending/墓碑在库;
2. 触发 coordinator(手动事件或 fake online 流)→ fake port 收到 batch(断言内容:实体数/模块/墓碑);
3. push 成功 → synced 回写+墓碑清+镜像刷新调用(fake mirror 或真 mirror+fake repo remote);
4. **镜像刷新后数据仍在**(T2 保护语义闭环);
5. push 失败路径 → failed 态+pending 保留 → 再触发成功。

### 5. TDD 测试

- collector 单测(空/非空/跨模块/墓碑)。
- coordinator 单测(幂等/仅 bound/成功链/失败重试/状态流转)——fake port+fake connectivity(流注入)。
- 集成断言(上述 5 步)。

## 验证(全部执行并贴证据)

1. 新单测绿(先红后绿)
2. `flutter test` 全量不回归(≥1359)
3. `flutter analyze` 新文件 0 条

## 约束

不接 gRPC/不改 proto(F11);不动 T1/T2 已交付语义;中文注释;不 commit。完成后报告。
