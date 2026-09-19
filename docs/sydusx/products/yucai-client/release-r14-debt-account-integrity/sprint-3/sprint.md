# Sprint 3 — R14 备份增强(F39/F40)

> /sydusx 流程(2026-09-19)。用户问「是否每日定期备份/能否选备份恢复」后推进:
> 绑定侧自动备份+选档恢复已齐(默认关,设置页开);本 sprint 补齐 guest 本地闭环与保留策略。

## Sprint Goal

guest 模式本地快照闭环(每日自动+应用内列表恢复);server 自动备份保留策略(防列表无限增长)。

## Feature roster

- [ ] **feature F39** local-snapshot — guest 本地快照闭环(每日启动快照+保留 7 份+设置页列表恢复/删除/立即快照)
- [ ] **feature F40** backup-retention — server 自动备份保留策略(每租户自动备份保留最近 30 份,调度 pass 内清理) — claimed: zcode-r14 2026-09-19(worktree .claude/worktrees/r14-f40)

## status: pending
