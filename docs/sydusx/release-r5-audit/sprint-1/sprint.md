# Sprint 1 — 04 备份恢复可靠性

> Sprint Goal + feature roster。`/sydusx-run` sprint planning(2026-08-01)。
> 源 ticket [.scratch/yucai-audit/issues/04](../../../../.scratch/yucai-audit/issues/04-backup-restore-reliability.md)。

## Sprint Goal

实施 audit 04 备份恢复可靠性:**快照一致 backup + 原子 restore + restore 期间写冻结 + 加密分层**。建立在 03 事务抽象(已 done)之上。

## Feature roster(依赖排序)

- [ ] **feature A** [2026-08-01-d5-backup-snapshot](2026-08-01-d5-backup-snapshot/feature.md) — D5 backup REPEATABLE READ 快照隔离 + TxContext 传播 Export + D18 OnConflict(基础,unblock B/D)
- [ ] **feature B** 2026-08-01-d6-restore-atomic — D6 restore purge+import 跨模块 tx 原子 + safety backup 快照一致(依赖 A)
- [ ] **feature C** 2026-08-01-d12-restore-freeze — D12 写冻结三件套(per-tenant mutex + middleware interceptor + scheduler 跳过)
- [ ] **feature D** 2026-08-01-d13-encryption-layering — D13 加密分层(safety 用户密码 / auto 明文+0600+UI 标注)+ D19a scrypt N 2^17 版本化 KDF header(依赖 B)

**defer**:D19b recovery code(进 map P2 backlog,需 DEK 重构)。

## status: pending
