# Task Brief F18-T2 — client 触达+确认+applier 版本感知

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r10-f18`,客户端 `yucai/client/`。**TDD。** T1(8864ddee)已就绪(server 检测统一/Canonicalize 短路/解决落库/created_at)。

## 先读(必读)
1. `docs/.../2026-09-06-conflict-resolution/{spec.md FR-1/2/4,design.md ADR-1/2/4/6}`
2. `lib/binding/data/grpc_offline_sync_port.dart`(encodeRequest 恒 CREATE 处 :128-129+PushResponse 接收)/`lib/binding/domain/offline_sync_port.dart`(SyncConflictInfo/接口)/`lib/binding/presentation/bloc/sync_coordinator_bloc.dart`(writeBack/conflicts 计数)/`lib/binding/data/pull_applier.dart`(pending 一刀切跳过+整批事务)
3. Dart stub(F17/T1 regen 后字段齐:ConflictDTO createdAt/conflict_type/双 payload;ResolveConflictRequest.mergedPayload)

## 交付物
### 1. port 触达区分(ADR-1)
`encodeRequest`:`dto.version==1 → CREATE else UPDATE`(注释:首建恒 v1 本地 DS 语义;server 检测 op 无关[存在性检测]——区分主要为语义正确性与未来统计)。

### 2. port 接口扩展(ADR-6)
`OfflineSyncPort` 增:
- `listConflicts({String? pageToken}) → ConflictPage{items: List<SyncConflictInfo>, totalCount, nextPageToken?}`
- `resolveConflict(String conflictId, String resolution /*server|client*/, {List<int>? mergedPayload})`
- `SyncConflictInfo` 扩:conflictId/serverPayload/clientPayload/createdAt(DateTime?)(字段齐映射,proto ConflictDTO 7+1 字段全解码)。
Grpc 实现(经 _retry);Noop 空实现。

### 3. 协调器确认语义+完整列表(ADR-2)
- push 响应 conflicts → `_writeBack` 增:冲突 entityId 集 → markXSynced(版本守卫同款——内容在 server 冲突记录,防反复重推堆冲突;注释)。
- state 增 `conflicts: List<SyncConflictInfo>`(UnmodifiableListView 或 const [];clean 态携带=push 响应携带的;**权威计数=ListConflicts**——协调器 clean 后异步 listConflicts 刷新 conflictCount+conflicts?**最小**:仅 push 响应携带;面板 bloc 自己拉 ListConflicts——协调器不重复拉,注释分工)。

### 4. applier 版本感知+per-change(ADR-4)
- upsert 前:本地行存在且 pending 且 `local.version >= pulled.version` → skip(计数);`local.version < pulled.version` → 应用(server 已裁决/他设备胜出);非 pending 照常 upsert。**注意**:pulled.version 从 payload JSON probe(F18-T1 裁决警示:不用 DTO log version——PulledChange 若带 logVersion 与实体 version 两值,applier 用 payload 内实体 Version)。
- per-change try/catch:坏条目(未知模块/坏 payload)debugPrint+跳过,不回滚整批;游标前进。整批事务降级为 per-change 事务(或单批无事务逐条——drift 事务成本注释裁量);毒丸不再钉死。
- DELETE 照旧(不问版本)。

### 5. TDD
- port:CREATE/UPDATE 区分断言;listConflicts 请求/响应映射(conflictId/双 payload/createdAt);resolveConflict 参数。
- 协调器:conflicts 确认标记(markXSynced 携带冲突 id 集);完整列表 state;clean 态计数。
- applier:版本感知矩阵(pending 同版本 skip/pending 低版本应用[server 裁决]/非 pending upsert/DELETE 不问);per-change(毒丸条目跳过+后续条目应用+游标前进)。
- 既有测试适配:offline_sync_pipeline(确认语义后断言更新)/coordinator conflicts 测试(扩列表)。

## 验证
新单测绿(先红后绿)+`flutter test` 全量(≥1492)+analyze 0 新增+`go test ./...`(server 不动,保险)。

## 约束
中文注释;F17 语义零回归(除授权:applier 版本感知替换一刀切+per-change 降级);不动 UI(T3);不 commit。完成后报告。
