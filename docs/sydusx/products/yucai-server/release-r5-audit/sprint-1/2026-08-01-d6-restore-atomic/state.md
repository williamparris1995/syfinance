---
feature: 2026-08-01-d6-restore-atomic
current_stage: design
status: design-done
---

# State — D6 restore purge+import 跨模块 tx 原子

## stages
- analysis: done(2026-08-05;output: spec.md;grill 三问收敛:safety backup 维持现状 / 隔离级别 Read Committed / D6-only scope。核心张力 = restore 原子后 safety success-removed 与人为错误兜底语义,本 feature 维持 04 决策现状 accepted,见 spec NFR-2)

## notes
- 御财适配:main 直接工作流(非 worktree)。feature docs 在本目录。
- 业务决策源:04 audit ticket D6(resolved)+ 2026-08-05 grill。
- 依赖:03 sqltx(done)+ feature A(D5 done,Service db/dialect 字段已有 + safety backup 走 RR)。
- 范式复用:镜像 feature A 的 `sqltx.WithTx` + `clientFor(ctx)` 模式,应用到 `restoreNoSafety` 的 purge+import 两循环。
- **pending**:design 阶段(HLD/LLD:tx 包 purge+import 循环 + 各 repo DeleteByTenant/Save tx-aware 验证 + safety backup tx 不嵌套确认)。
