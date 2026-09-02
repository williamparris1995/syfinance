# Sprint 2 — R8 E2E 全模块关联链路

> Sprint Goal + feature roster。`/sydusx-portfolio`(2026-09-02)。

## Sprint Goal

**一键 E2E 回归覆盖"每个模块 + 模块间关联性"**:在既有 client-e2e 基础设施(种子注入 → 无头跑 → 测后删库,commit 90d0f5c2)之上,补齐 4 组跨模块链路断言(订阅→自动记账、模板+标签、预算/目标联动、债权收回+备份往返),使 `make client-e2e` 成为模块修改后的标准回归入口(手动触发)。

## Feature roster(依赖排序)

- [ ] **feature F6** 2026-09-02-e2e-module-links — E2E 全模块关联链路补全(订阅/模板标签/预算目标/债权备份)(claimed: zcode-r8-f6 2026-09-02)

> F5 menu-anchor 由另一会话进行中(worktree `r8-f5`),不属本 sprint 追踪。

## defer

- 提交 hook 自动回归(用户拍板:保持手动 `make client-e2e`,不拖慢提交)
- OIDC 登录链路 E2E(离线无头环境不可测,guest 本地模式为准)

## status: pending
