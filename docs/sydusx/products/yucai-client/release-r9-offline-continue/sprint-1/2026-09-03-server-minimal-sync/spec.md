# Spec — F11 server 最小同步通路

> R9 sprint-1 · 2026-09-03 · analysis 产出(server 侧代码级查证;顶层决策"增量 dirty 上传"为用户 F10 grill 拍板)。

## 查证事实基线(设计输入)

- sync proto **非休眠半成品**:双端 stub 现行、service 已注册、sync 模块 DDD 全链在——`PushChanges` 已写 sync_log(逐条 append,非原子/无幂等)**但不落 8 个业务表**;`PullChanges` 仅回放 log;conflicts 恒空。
- ent 无 upsert codegen;backup 先例=purge 全删+insert(全量),单行 upsert 需手写 find-then-update/create。
- 各模块 repo `Save` 全字段 create + domain struct json 反序列化已验证(backup exporter Import 链)。
- 跨模块单事务基建 `sqltx.WithTx` 已验证(backup purgeAndImport);wire DI 手改 4 处镜像(约定在案)。
- payload(bytes)+entityType(string) 现有 proto 已能承载 F10 DTO(fields JSON + module)——**零 proto 改动可行**。
- deviceId 现状 fallback=tenantID;RegisterDevice client 未接。

## Requirements

- **FR-1 PushChanges 业务表落库**:8 模块分发(entityType→业务 repo);payload=fields JSON(drift 行 toJson,camelCase;剔除 syncState;枚举 int→server enum 映射);单行 upsert=手写 find-then-update/create(信任 client 版本,单设备语义;conflict 检测留 ticket 16,conflicts 维持恒空+注释);**批次原子**(业务表+sync_log 同一 `sqltx` 事务,任一失败整体回滚——对齐 client SyncResult 批次原子语义)。
- **FR-2 DELETE(墓碑)落库**:operation=DELETE → server 硬删对应实体(单设备语义统一硬删,server 软删列是 server 自有语义不在 sync 路径使用,注释钉死);依赖序删除(借 backup purge 顺序的逆推理:引用方先删)。
- **FR-3 幂等重推**:同批次重推不重复 append sync_log、不产生重复业务效果(按 entity_id 幂等 upsert 天然满足业务侧;log 侧按事务原子重写,重推=新版本号追加,注释可接受性——单设备重推仅在 client 未收到响应时发生,server 幂等由 upsert 保证)。
- **FR-4 client GrpcOfflineSyncPort**:实现 OfflineSyncPort 的 gRPC 版(fields→JSON bytes 编码+module→entityType+CREATE/UPDATE→upsert op+墓碑→DELETE op+deviceId 填充[v1=fallback tenantID,注释 ticket 16 接 RegisterDevice])替换 noop 注册;成功→SyncResult ok;grpc 错误→failed(网络类失败 client 侧保 pending 语义已就绪)。
- **FR-5 孤儿台账行(F10 S-1 ticket)**:PendingCollector 扩展——无持仓头行的裸分红台账行随 holding 模块批次上行(payload=台账行合成条目,entityType=holding_ledger 扩展约定)或合成 qty=0 头行(设计定形态);镜像协调侧同样收孤儿行(否则上行前被抹)。
- **FR-6 测试与门**:server 单测(Tier-A 内存 sqlite:PushChanges 单模块 upsert/跨模块批次原子回滚/DELETE 依赖序/重推幂等/tenant 隔离)+集成测试;client port 单测(fake grpc?按库内 grpc 测试先例——若无则 port 层用 fake channel/client mock)+全量门(go test 全绿+flutter test+client-e2e 基线);wire 手改 4 处镜像;契约 README 登记 sync PushChanges 语义 bullet(向后兼容,零 proto 改动)。

## NFR

- English structured logs(slog,operation/tenant_id/entity_type 键值;无 CJK)。
- DDD 边界:分发层落 sync 模块 application/driven(消费 8 模块 repo 经 port 抽象,照 backup TenantDataPort 模式新增 per-module SyncUpsertPort?——设计定形态,禁止 sync 直接 import 各模块 ent)。
- server 既有行为零回归(go test 全量)。

## Scope boundary

| 排除 | 理由 |
|---|---|
| PullChanges 业务表实现 | 单设备 client 不需要拉(镜像走既有 repo list RPC);留 ticket 16(多设备) |
| 冲突检测/ResolveConflict/ListConflicts | conflicts 恒空现状保持;ticket 16 |
| RegisterDevice 接入/deviceId 真实化 | v1 fallback tenantID(现状);ticket 16 |
| proto 改动/契约 bump | payload bytes 承载 fields JSON 零改动;仅 README 登记 |
| 非空账号绑定合并/存档上云 | ticket 16 线其余 |

## Grill record

| 决策 | 定案 |
|---|---|
| 补同步形态 | 用户拍板( F10):增量 dirty 上传——本 feature 落地其 server 侧 |
| payload 编码 | fields JSON bytes(零 proto 改动,零契约动作)——技术推荐,零争议 |
| 批次原子 | 对齐 client SyncResult 语义(F10 查证指出 server 现版非原子不一致)——必须 |
| DELETE 语义 | server 统一硬删(单设备;软删列不进 sync 路径)——技术推荐 |
| deviceId | v1 fallback tenantID(现状),RegisterDevice 留 ticket 16——技术推荐 |
| F11 含 client port 接线 | 是(否则 noop 换不掉/F13 e2e 断不通)——依赖链必然 |

## Feasibility

technical ✓(半成品骨架+backup 全链范式+sqltx 基建全在);economic ✓(单行 upsert 手写×8 模块为主要工作量);operational ✓(Tier-A harness+go test 门齐)。
