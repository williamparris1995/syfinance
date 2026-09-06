# Design — F17 client 设备身份与拉取

> R10 sprint-1 · 2026-09-03。查证事实为输入;spec 三决策内嵌推荐。

## ADRs

- **ADR-1 设备身份=clientId 直用**:`GrpcOfflineSyncPort` 构造增 `TokenStorage` 注入;`_deviceId()=clientId`(uuid 串,server parseUUID 合法);`binding_bloc` 上传成功后 `RegisterDevice(deviceId=clientId)`(幂等,失败不阻断绑定流程——log warn,下次 push 时 server 侧自动补?**不**:server Register 才建设备行,push 只 bump——绑定后补扫触发 push 前 try Register 一次亦可;最小:绑定流程 fire-and-forget Register,失败容忍,注释)。BoundMarker 职责不变(绑定标记),'bound' 串退役为纯标记值(deviceId 不再取它)。
- **ADR-2 PullApplier=增量下行**:新 `binding/data/pull_applier.dart`——逐 change:`CREATE/UPDATE`→envelope 行→drift upsert(复用 archive_importer 的行→drift 映射,抽取共享或最小复制+注释单一事实源策略;**同 id 且本地 pending→跳过**(保护,记 skipped 数);`DELETE`→本地硬删+**写墓碑**(防上行复活,照上行对称;但注意:这是"server 说删"——墓碑上行后 server 再删幂等,无害);applier 与 mirror 并存(mirror=全量重建场景:登录/绑定;applier=运行时增量:push 成功后/回网)。
- **ADR-3 拉取编排**:SyncCoordinatorBloc 扩展——push 成功后 `_pullAndApply()`(since=本地游标;**游标本地存**(drift 单行 kv 或 SecureStorage——server 设备行也可,但 client 读它需 GetSyncStatus 往返;本地存简单,since 错小=幂等重拉无害),推荐 drift `sync_cursor` 表或复用既有 kv 机制——查证后选);回网时 pull 先于 push(先收后发);分页循环(has_more→since=页尾 version 续);conflicts 变更不在 log(F16 跳过不记)——拉到的是 server 现行,天然一致。
- **ADR-4 holding_ledger**:server writer(第 9 个)——payload=envelope 台账行形态;upsert 按 id;CurrentState 按 id;**client collector 扩展**:pending holding 头行收集时,同 (account,security) 的离线台账行(该头行事务内产生的)随批上行(entityType=holding_ledger);关联口径:台账行无 syncState——按"头行 pending ⇒ 其 (account,security) pair 的台账全收"?会收旧台账——**收 origin 判定**:台账 id 在头行 pending 期间新增(recordDividend/买入卖出台账均同事务)…… 买入卖出已有头行 pending(非合成),台账是否需要上行?**查证决策留给 T2 实现**:server 侧台账已有别的事实源吗(holding list API 含台账?)——mirror `_refreshHoldings` 从 server list 拉台账,说明 server 存台账(经什么写?F11 push 的 holding payload 是单行——**不含台账**;server 台账从哪来?——查证:server holding repo 的 Save 是否写台账/或 ledger 仅 client 概念)。T2 简报将先查证 server 台账存储现状再定上行范围(可能整块 defer 到 sprint-2 若 server 无台账存储)。
- **ADR-5 conflicts 消费最小面**:`SyncResult` 扩 `conflicts: List<SyncConflictInfo>`(module/entityId/conflictType);port 接 PushResponse 映射;协调器失败原因链新增"冲突 N 项"提示(F12 badge failed 文案携带;冲突面板=F18)。

## HLD 改动面

- gen-dart(2 message)+ AGENTS.md 修正
- `binding/data/`(grpc port[clientId+RegisterDevice+response 接]/pull_applier 新/collector[ledger 视查证])、`binding/presentation/bloc/`(binding_bloc Register/coordinator pull 编排+conflicts)、`core/localdb/`(游标存储)
- server:`entitywriter/holding_ledger.go`(视 T2 查证)
- 测试:port/applier/coordinator 单测 + e2e fake 双方法+双设备场景

## Risks

| 风险 | 缓解 |
|---|---|
| applier 与 mirror 语义打架(下行覆盖未上行) | pending 跳过保护+墓碑对称;e2e 双设备场景钉 |
| 台账 server 存储现状不明 | ADR-4:T2 先查证再定(可 defer) |
| 游标回退(重装/清库) | since=0 全量重拉,幂等无害 |
| gen-dart 全量 regen 引入意外 diff | diff 面断言恰 2 message;异常即停 |

## Open Questions

- 游标存储落点(drift kv vs SecureStorage)——T1 实现时按库内既有 kv 先例选。
