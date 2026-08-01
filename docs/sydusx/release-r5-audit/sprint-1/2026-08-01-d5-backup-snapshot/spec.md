---
feature: 2026-08-01-d5-backup-snapshot
status: drafted
---

# Spec — D5 backup 快照隔离 + D18 OnConflict

> feature A(sprint-1)。源:audit 04 ticket D5/D18(resolved)。依赖 03 sqltx(已 done)。
> 纯 behavior,零实现代码(interface/tx 机制留 design.md)。

## ADDED Requirements

### Requirement: FR-1 备份快照一致性
- [ ] 系统 SHALL 在单个 `REPEATABLE READ` + `ReadOnly` 事务内导出所有业务模块数据,使备份反映某一一致时点的完整状态,而非跨时点撕裂(如"账户=T1 状态 + 交易=T2 状态")。

#### Scenario: 并发写下产生一致快照
- GIVEN 一个 tenant 的数据(账户/交易/holding/...)处于状态 S1,且一个写者正将数据改为 S2
- WHEN 触发备份(写者改写进行中)
- THEN 备份导出的全部模块数据对应 S1 或 S2 之一的完整状态,不出现跨模块的撕裂组合

### Requirement: FR-2 Export 共享同一事务
- [ ] 备份 SHALL 使各业务模块(account/transaction/debt/budget/goal/holding/currency/tag/template)的 Export 在同一事务内执行,共享同一快照,而非每个 Export 独立查询。

#### Scenario: 单事务贯穿 Export 循环
- GIVEN backup service 开始导出
- WHEN 依次调用各模块 Export
- THEN 所有 Export 在同一 `REPEATABLE READ` 事务内执行(共享快照)

### Requirement: FR-3 备份原子性(Export 失败)
- [ ] 任一模块 Export 失败时,系统 SHALL 使整个备份失败(事务 rollback,不产生部分备份),因部分备份=另一种撕裂。

#### Scenario: Export 失败致整备份失败
- GIVEN backup 导出进行中,某模块 Export 抛错
- WHEN 错误传播
- THEN 整个备份事务 rollback,不留下部分备份文件,调用方收到失败

### Requirement: FR-4 snapshot 重复 tick 容忍(D18)
- [ ] snapshot 持久化 SHALL 在唯一键冲突时保留首条(first-wins),而非硬错中断当日 snapshot。

#### Scenario: 重复 snapshot tick
- GIVEN 当日 snapshot 记录已存在
- WHEN scheduler 再次触发 snapshot(重复 tick / 重试)
- THEN 新 snapshot 被忽略(`OnConflictDoNothing`),当日 snapshot 不中断,保留首条时点语义

### Requirement: NFR-1 隔离级别(REPEATABLE READ)
- [ ] 备份 SHALL 使用 `REPEATABLE READ` 隔离级别(非 `Serializable`),因只读备份不写、不需 Serializable 的防写偏序开销。04 决策已定。

### Requirement: NFR-2 scope 排除项
- [ ] 备份 SHALL NOT 使用:`pg_dump`(整库导出不 fit per-tenant restore)/ 全局 maintenance mode(冻结所有 tenant,误伤)/ server-held DEK(私域单机威胁模型边际收益≈0)。04 决策已定。

## scope boundary

- **IN**: D5(REPEATABLE READ + 各 Export 共享 tx)+ D18(snapshot OnConflictDoNothing)+ Export 原子失败(FR-3,grill 新增)。
- **OUT**: D6 restore 原子(feature B)/ D12 写冻结(feature C)/ D13 加密分层(feature D)/ D19b recovery code(P2 backlog)。
- **依赖**: 03 sqltx(共享 `*sql.DB` + TxContext port,2026-07-26 done)。

## 测试策略(工程实现,非用户决策)

FR-1/FR-2 的 acceptance 用**真实 Postgres 并发事务测试**(非 mock):
- 两连接:连接 A 跑 backup(`REPEATABLE READ` tx 导出),连接 B 并发改数据。
- 断言:backup 导出数据不含连接 B 的写后状态(= 某写前时点的完整一致快照)。
- 理由:mock 无法验证 Postgres 真实隔离级别下的撕裂行为;只有真并发 tx 测试能抓 FR-1 回归。
- 具体 test 实现 + oracle 数据留 `test` 阶段。
