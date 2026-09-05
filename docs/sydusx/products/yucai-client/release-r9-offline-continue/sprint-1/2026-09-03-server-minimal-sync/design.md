# Design — F11 server 最小同步通路

> R9 sprint-1 · 2026-09-03。spec 六决策在案;查证事实为其输入。

## Decisions (ADRs)

- **ADR-1 分发层=消费方 port 模式(照 backup TenantDataPort 范式)**:sync 模块定义 `SyncEntityWriter{ Name() string; Upsert(ctx, tenantID, payload []byte) error; Delete(ctx, tenantID, entityID string) error }`;8 实现落 `sync/adapter/driven/entitywriter/`(import 各模块 repo——backup exporter 同款被接受形态);DI `provideSyncEntityWriters` 聚合 `map[string]SyncEntityWriter`(照 provideBackupExporters L666);wire 4 处手改镜像(providers→wire.go→wire_gen.go→app.go,依赖方之后声明)。
- **ADR-2 payload 编码=复用 backup envelope 行序列化(单一事实源)**:client 侧把 `local_snapshot_exporter` 的 per-row 序列化(domain 实体→server 兼容 JSON)抽为可复用 helper;collector 产出 domain 实体(各 local DS 读取路径已有 drift→domain),gRPC port 编码=helper 序列化→bytes。server writer=`json.Unmarshal(payload, &domain.X)`+repo 写(backup Import 同链)。枚举/字段名兼容由既有 envelope 契约保证(F6 备份往返 e2e 已验证)。
- **ADR-3 批次原子事务**:service.PushChanges 重构——`sqltx.WithTx` 包「8 模块 writer 分发(upsert/delete 按 payload op)+ sync_log 批量 append + 事务内取 LatestVersion 递增(修现状非事务查询)」;任一失败整体回滚(对齐 client SyncResult 批次原子)。
- **ADR-4 DELETE 依赖序**:固定删除序=backup `orderedPortsForPurge()` 的模块序(引用方在前);writer.Delete 内部处理模块内级联(如 transaction 头删带 entries)。
- **ADR-5 client GrpcOfflineSyncPort**:`binding/data/grpc_offline_sync_port.dart` 注入 `SyncServiceClient`;批次→PushChangesRequest(changes:实体 upsert op+墓碑 DELETE op);deviceId=BoundMarker 的 tenant 串(fallback 语义同 server 现状,注释 ticket 16);grpc 异常→SyncResult 失败(client 侧保 pending 语义已就绪);DI 替换 noop 注册。
- **ADR-6 孤儿分红=合成 qty=0 头行(最小)**:`holding_local_ds.recordDividend` markPending 且无对应头行时,同事务合成 qty=0/avgCost=0 的 pending 持仓头行——镜像协调/收集/上行全链自动生效(S-1 ticket 闭环);注释语义(纯分红持仓,server upsert 后与台账并存)。

## HLD 改动面

- server:`internal/sync/`(domain port + application service 事务化 + driven entitywriter ×8 + dto)+ wire 4 处 + main.go(已注册零改)+ 契约 README bullet。
- client:`local_snapshot_exporter` 行序列化抽取 + `binding/data/grpc_offline_sync_port.dart` + collector(domain 实体产出)+ holding_local_ds 合成头行 + injection(替换 noop)。

## LLD 要点

- writer.Upsert:find(by id+tenant)→有则 update 全字段+version=client 版本;无则 create(id=client uuid,tenant 注入)——手写 upsert(ent 无 codegen)。
- 删除序(borrow purge 序):transaction→debt→budget→goal→holding→tag→template→account(实现时以 orderedPortsForPurge 实际序为准)。
- log 幂等:事务内 append;重推=新版本号追加(可接受,注释:client 仅在未收响应时重推,业务侧 upsert 幂等)。
- slog 键:operation="sync_push"/tenant_id/entity_type/count/error(英文)。

## Risks

| 风险 | 缓解 |
|---|---|
| 8 模块 upsert 手写面广 | 照 account_repo.Save 范式同构;Tier-A 每模块 1 测 |
| 字段映射漂移 | ADR-2 单一事实源(备份 e2e 已验证的 envelope 序列化) |
| wire 手改错位 | 4 处镜像清单在 brief;providers_test 兜底 |
| 事务死锁/依赖 | 单事务按固定序;sqltx backup 先例 |

## Open Questions

- collector 产 domain 实体的具体取数(各 DS 已有 getPending 返回 drift 行→再经 DS 读路径转 domain?或 DAO 直接 join)——T3 实现时选最小改造路径并注释。
