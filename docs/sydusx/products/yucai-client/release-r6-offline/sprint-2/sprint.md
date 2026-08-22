# Sprint 2 — 全模块本地读写

> Sprint Goal + feature roster。`/sydusx-portfolio` sprint planning(2026-08-20)。

## Sprint Goal

按 sprint-1 定型的 seam 范式,把本地读写复制到**全部业务模块**(核心记账 + 资产类),并保证离线**写路径完整性**(本地事务/引用完整/断网 UX)。完成后游客模式达到「可分发的单机可用」成色。

## Feature roster(依赖排序)

- [ ] **feature D** 2026-08-20-core-modules-local — 核心记账模块本地化:transaction/category/tag/template/currency(依赖 C 的 seam 范式) `claimed: zcode-main 2026-08-22`
- [ ] **feature E** 2026-08-20-portfolio-modules-local — 资产类模块本地化:holding/budget/goal/debt/receivable/report/networth(依赖 D 的关联链路)
- [ ] **feature F** 2026-08-20-offline-write-integrity — 离线写完整性:本地事务原子性 + 引用完整性(级联/约束)+ 断网/恢复 UX(依赖 D,E)

**defer**:绑定后离线续写 outbox(ticket 16)。

## status: pending
