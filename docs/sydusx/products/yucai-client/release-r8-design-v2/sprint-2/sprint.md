# Sprint 2 — R8 E2E 全模块关联链路

> Sprint Goal + feature roster。`/sydusx-portfolio`(2026-09-02)。

## Sprint Goal

**一键 E2E 回归覆盖"每个模块 + 模块间关联性"**:在既有 client-e2e 基础设施(种子注入 → 无头跑 → 测后删库,commit 90d0f5c2)之上,补齐 4 组跨模块链路断言(订阅→自动记账、模板+标签、预算/目标联动、债权收回+备份往返),使 `make client-e2e` 成为模块修改后的标准回归入口(手动触发)。

## Feature roster(依赖排序)

- [x] **feature F6** 2026-09-02-e2e-module-links — E2E 全模块关联链路补全(订阅/模板标签/预算目标/债权备份) ✅ done(2026-09-03;merge `160c3f30`;10 管道链+2 条件裁决+11 UI 链双层入口[`make client-e2e` 47 测试默认回归 / `make client-e2e-ui` 17 测试手动,均支持 `F=` 单文件];holistic review PASS;附带修复仓库金图卫生地雷[.gitignore `*.png` 挡掉 3 金图,全新 checkout 必红];生产疑点 6 处只记未修见 code-ledger)

> F5 menu-anchor 由另一会话进行中(worktree `r8-f5`),不属本 sprint 追踪。

## defer

- 提交 hook 自动回归(用户拍板:保持手动 `make client-e2e`,不拖慢提交)
- OIDC 登录链路 E2E(离线无头环境不可测,guest 本地模式为准)
- 标签反查交易 + 报表标签维度(功能缺口非测试缺口,F6 design 决策 A → backlog,功能补齐后测试跟上)
- 交易列表 category 筛选接线(TxnFilterState.category 未进查询参数)+ 文本搜索(功能不存在)
- 生产疑点 6 处(见 F6 code-ledger;含**侧栏「订阅管理」路由被 /accounts/:id 捕获[真 bug]**、模板 endDate=null 兜底截今天、列表 pop 不回拉 ×2、typeFilter 粗分类、下拉异步空窗)
- 测试债:goPage helper 11 文件重复迁 link_support;既有三套件 tearDownAll 迁 deleteTestDb(Windows close 前删库实删不掉)

## status: done(F6 ✅ 2026-09-03)
