---
feature: 2026-08-01-d6-restore-atomic
status: drafted
---

# Spec — D6 restore purge+import 跨模块 tx 原子

> feature B(sprint-1)。源:audit 04 ticket D6(resolved)+ 2026-08-05 grill。依赖 03 sqltx(已 done)+ feature A(D5 已 done,Service 已有 db/dialect + safety backup 走 RR 快照)。
> 纯 behavior,零实现代码(tx 机制留 design.md)。

## ADDED Requirements

### Requirement: FR-1 restore 原子性(purge+import 单事务)
- [ ] 系统 SHALL 在单个跨模块事务内执行 restore 的 purge + import,使 restore 要么完整成功(全部模块替换为新备份数据),要么完整回滚(全部模块回到 restore 前状态),不出现半 purge 的中间丢失状态。

#### Scenario: import 中途失败 → 整 restore 回滚
- GIVEN 一个 tenant 有状态 S0(账户/交易/holding/...),一份备份文件 B(状态 S1),其中某模块(如 holding)的 Import 会失败(损坏/约束冲突)
- WHEN 触发 restore(B)
- THEN 已 purge 的模块 + 已 import 的模块全部回滚到 S0,tenant 数据 = S0(非半 purge 状态),调用方收到失败

#### Scenario: restore 完整成功
- GIVEN tenant 状态 S0,备份 B(状态 S1)完整有效
- WHEN 触发 restore(B)
- THEN purge + import 在单 tx 内全部成功提交,tenant 数据 = S1

### Requirement: FR-2 Purge/Import 共享同一事务
- [ ] 各业务模块(account/transaction/debt/budget/goal/holding/tag/template)的 Purge + Import SHALL 在同一事务内执行(经 TxContext 传播),而非各自独立连接。

> 注:同 feature A 的 Export 模块列表(8 个;currency 是 seed/reference 不进 backup)。Purge 顺序 dependents→account,Import 顺序 account→dependents(现有 orderedPortsForPurge/Import),单 tx 内顺序不变。

#### Scenario: purge + import 循环共享 tx
- GIVEN restore 开始 purge+import
- WHEN 依次执行 purge 循环 + import 循环
- THEN 两个循环内所有 Purge/Import 调用绑定同一 tx driver(经 context 传播),任一失败 → 整 tx rollback

### Requirement: FR-3 import 失败回滚 purge
- [ ] import 阶段任一模块失败时,系统 SHALL 使先前已执行的 purge 自动回滚(tx rollback),purge 不成既实,数据不丢失。

#### Scenario: import 失败 → purge 回滚
- GIVEN purge 循环已完成(删了 transaction/holding/...),import 循环到某模块失败
- WHEN import 错误传播
- THEN tx rollback,purge 删除全部撤销,tenant 数据回到 restore 前一致状态

### Requirement: NFR-1 隔离级别(Read Committed)
- [ ] restore 的 purge+import 事务 SHALL 使用默认隔离级别(Read Committed)。restore 原子性由 tx rollback 保证(非快照隔离);purge+import 是全量替换,不需 REPEATABLE READ 的快照语义。并发写冻结属 D12(feature C)。

### Requirement: NFR-2 safety backup 定位(维持现状)
- [ ] pre-restore safety backup SHALL 保留(restore 前由 CreateBackup 产生,已走 RR 快照一致 —— feature A 收益),其加密分层(D13)归 feature D。
- [ ] safety backup 删除时机 SHALL 维持现状(restore tx 成功 → 删;失败 → 留)。tx 原子性防事务失败(import 抛错 → rollback);safety backup 不再防事务失败(已由 tx 覆盖)。

> **已知张力(accepted,2026-08-05 grill)**:restore tx 成功提交后 safety 被删,若用户选错备份文件(tx 成功但内容错),safety 已删 → 人为错误不可逆。本 feature 维持 04 决策现状(不扩 scope);真正的「保留 safety 作人为错误兜底」需清理策略(保留 N 个 / 手动删),defer 后续。

### Requirement: NFR-3 scope 排除项
- [ ] restore SHALL NOT 做:D12 写冻结(per-tenant mutex + middleware + scheduler skip,feature C)/ D13 加密分层(safety/auto 加密,feature D)/ D19b recovery code(P2 backlog)。

## scope boundary

- **IN**: D6(purge+import 单跨模块 tx + rollback 原子 + 各 repo Purge/Import tx-aware)。
- **OUT**: D12 写冻结(feature C)/ D13 加密分层(feature D)/ D19b(P2 backlog)。safety backup 快照一致(A 已给)+ 加密(D)。
- **依赖**: 03 sqltx(共享 `*sql.DB` + TxContext,done)+ feature A(Service 已有 `db`/`dialect` 字段 + safety backup 走 RR)。

## Open Questions(留 design)

1. **各 repo DeleteByTenant + Import Save 的 tx-aware 验证**:feature A 验证了 FindAllForBackup(读路径)clientFor;restore 用 DeleteByTenant(purge)+ Import 的 Save/SaveOrUpdate(写路径)是否都 tx-aware,design/code 第一步全量验证 8 模块(镜像 A 的 R1)。
2. **safety backup tx 与 restore tx 不嵌套**:safety backup(CreateBackup,自开 RR tx)在 restore tx 之前独立调用,不嵌套进 restore tx。design 确认无 join-existing-tx 误用(CreateBackup 的 ctx 不应携带 restore tx)。
3. **safety backup 人为错误张力**:见 NFR-2 accepted;后续独立改进 defer。

## 测试策略(工程实现,非用户决策)

FR-1/FR-3 acceptance 用**真实 Postgres 测试**(非 mock):
- 模拟 import 中途失败(注入某模块 Import 返回 err / 备份含约束冲突数据),验证 tx rollback 后 tenant 数据 = restore 前一致状态(非半 purge)。
- 理由:mock 无法验证跨模块 tx 的真实 rollback 行为;只有真 tx 测试能抓 FR-1/FR-3 回归。
- 具体 test 实现 + oracle 数据留 `test` 阶段(镜像 feature A 的 Tier B PG e2e,复用 tests/ PG helper)。
