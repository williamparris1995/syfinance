---
feature: 2026-08-23-f2-delete-account-guard
current_stage: finish
status: done
---

# State — F2 DeleteAccount 引用拒绝

## stages
- analysis: done(2026-08-23;spec.md;引用面 6 模块盘点[含 ticket 未列的 goal/template,排除派生 snapshot 表];version CAS grep:7 模块确认,holding/backup 无 CAS 记 accepted)
- design: done(2026-08-23;design.md;4 ADR:port 方向反转 / edge-able 用 HasXxxWith / fail-closed 三层 / wire 后置接线[accountService 早建于 auth 链])
- execute: done(2026-08-23;worktree r5-del-guard;port+六 repo count+guard+wireAccountReferenceSources[providers+wire_gen 手编]+单测 5 + 集成[7 模块单 DB 真 wiring])
- review: done(2026-08-23;agent PASS-with-nits;1 MAJOR[租户隔离测试空转→真引用同 account]+3 MINOR+2 NIT 全修:FailedPrecondition 映射 / DeleteByTenant 冒烟 / 分支矩阵补全[debt collection·template source·裸 trade·goal linked·软删 budget] / 名词化)
- test: done(2026-08-23;62 包全绿;guard 矩阵 6 集成 + 5 单测)
- finish: done(2026-08-23;merge → main)

## notes
- 跨模块 port 首次反向使用:account 消费方(镜像 goal.AccountBalanceSource)。
- E 的 entries/items edge 立即回本(HasEntriesWith/HasItemsWith 计数)。
- 软删父不阻断(transaction/budget)——语义:用户不可见即不构成引用。
- DeleteByTenant 不变(灾难清理,D6 purge 依赖)。
