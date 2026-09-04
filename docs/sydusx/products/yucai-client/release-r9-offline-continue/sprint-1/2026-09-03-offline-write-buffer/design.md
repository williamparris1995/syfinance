# Design — F10 离线写语义与缓冲

> R9 sprint-1 · 2026-09-03。spec 两决策(增量上传/F10 修路由 bug)+ 墓碑方案经确认。查证事实见 spec「事实基线」。

## Decisions (ADRs)

- **ADR-1 三态路由**:SessionModeTracker 增 `resolveDataRoute() → DataRoute{guestLocal, boundRemote, boundOfflineLocal}`(由 isGuest × auth 态 × ConnectivityGateway.online 组合);8 repo 的 `_useLocal` 分叉统一替换为 `route == guestLocal || route == boundOfflineLocal` 读本地/写本地;**写降级助手** `_writeWithFallback(remote, local)`(core 共享):boundRemote 写遇 NetworkFailure → 落本地置 pending(FR-1b 双保险)。OfflineAuthenticated 归 boundOfflineLocal(修 bug)。
- **ADR-2 syncState 列**:8 头表加 `syncState TEXT NOT NULL DEFAULT 'synced'`(synced/pending 两值),schemaVersion 2→3 migration 加列回填;guest 写入行=synced(无上行语义);绑定镜像行=synced;离线/降级写=pending;上行成功回 synced。DAO 增 `pendingOf(module)` 查询。
- **ADR-3 镜像协调(语义钉死)**:bound_mirror refreshModule 的 delete-all 改为**排除 pending 行**(delete where syncState!='pending');rebuild 插入遇同 id pending 行**跳过**(保本地内容与存在性)。单设备语义下 server 行=pending 前镜像,跳过安全。
- **ADR-4 墓碑表**:新表 `SyncTombstones(module TEXT, entityId TEXT, deletedAt DATETIME, PRIMARY KEY(module, entityId))`;**仅 bound 路由的删除**写墓碑(guest 删除不写——绑定走全量首传);上行成功清对应墓碑。
- **ADR-5 同步 port 与协调器**:`OfflineSyncPort`(binding/domain 抽象):`pushBatch(SyncBatch)→SyncResult`;SyncBatch=各模块 pending 实体(镜像 mapper 复用)+墓碑集合;`SyncCoordinator`(binding/data 或 core,bloc 或服务):listen ConnectivityGateway.online → 收集 → pushBatch → 成功回 synced/清墓碑 → 状态流(`SyncStatus{idle, syncing(n), failed(reason), clean}`)对外(F12 UI 消费)。F10 交付 port + fake + coordinator;F11 换 gRPC 实现。
- **ADR-6 测试策略 TDD**:单测(路由解析/写降级/pending 标记/镜像保 pending/墓碑/协调器 fake 全流程)+ 集成断言(断网写→pending→fake 上行→synced→mirror 刷新不抹);全量 e2e 离线链路归 F13。

## HLD 改动面

- `core/session_mode/`(tracker 扩展+DataRoute)、`core/connectivity/`(消费)、`auth/presentation/bloc/auth_bloc.dart`(OfflineAuthenticated 修复)
- 8 个 `*_repository_impl.dart`(路由+降级助手)、`core/` 共享写降级 helper
- `core/localdb/`(表+迁移 schemaVersion 3)、各 local DS(写路径置 pending/删除墓碑——route 感知)
- `binding/`(OfflineSyncPort+SyncCoordinator+状态流)、`binding/data/bound_mirror.dart`(pending 保护)
- DI 接线

## LLD 要点

- 降级判定:`GrpcError(unavailable)`(NetworkFailure)→ 降级;其他失败(校验/权限)不降级照常 Left。
- route 解析时机:每写/读调用现算(tracker 持 online 快照,connectivity 流更新);auth 态变化即时生效。
- SyncCoordinator 幂等:进行中忽略再次触发;失败保留 pending(下次 online/手动重触发)。
- 迁移兼容:旧库加列默认 synced;墓碑表 create。

## Risks

| 风险 | 缓解 |
|---|---|
| 8 repo 改造面广 | ADR-1 共享 helper+统一模式;每 repo 单测同构 |
| mirror 改动伤在线语义 | pending 排除只影响含 pending 行场景;在线(全 synced)路径行为逐位不变(断言) |
| connectivity 误报 | FR-1b 远端失败双保险兜底 |
| 迁移丢数据 | schemaVersion 3 仅加列/建表;e2e 基线含旧库升级断言(execute 补) |

## Open Questions

- SyncCoordinator 形态(bloc vs 纯服务+stream)——T3 实现按 F12 UI 消费形态定,倾向 bloc。
