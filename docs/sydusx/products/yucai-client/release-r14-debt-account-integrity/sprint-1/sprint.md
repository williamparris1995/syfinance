# Sprint 1 — R14 F33-F36 债务与账户一致性四件

> /sydusx-portfolio(2026-09-18)。

## Sprint Goal

债务分类全链路可编辑 + 9 类扩展;支出支付方式放开信用卡;贷款账户详情页还款计划面板;负债记账治本(方案 A)。

## Feature roster

- [x] **feature F33** debt-subtype — subtype 全链路可编辑 + 9 类扩展(proto `UpdateDebtRequest` 加 `subtype`;server handler/params 接线;client UpdateDebtParams/repo/DS/表单 chips 解禁;sync envelope 补字段) ✅ done(2026-09-18,合并 `fd3be313`;grill 三轮+spec 四 FR 两 NFR+prototype v3 用户定稿;T1-T7 全绿:go 全绿/flutter 1849/analyze 437≤439/client-e2e 14/14;ledger 勘误 3 条:服务端 update DTO 原无字段、gRPC 更新链原缺 SetSubtype、update 镜像本已有 Subtype)
- [x] **feature F34** credit-card-payment — 支出支付方式放开信用卡/负债账户(transaction_form 账户选择器现硬过滤 asset-only) ✅ done(2026-09-18,合并 `c45127bb`;paymentAccounts=asset∪信用卡类/类型切换清空守卫/卡详情记账预选;4 新测;1855 全绿+analyze 438≤439+e2e 14/14;转账/收入 asset-only 为 NonGoal) — worktree 已清,分支已删
- [x] **feature F35** repayment-plan-panel — 贷款账户详情页接入还款计划面板 ✅ done(2026-09-18,合并 `e9b6d94a`;AccountRepaymentPlanPanel 只读面板(counterparty+剩余本金+未还期次前 3+跳转债务详情)/空态隐藏退役旧占位/RouteAware+didPopNext 重拉补齐;3 新测;1858 全绿+analyze 438≤439+e2e 14/14;范围=loan 类,otherLiability 扩展 backlog) — worktree 已清,分支已删
- [x] **feature F36** liability-posting — 负债记账治本方案 A ✅ done(2026-09-19,合并 `d81a3539`;spec 3 决策点用户「按推荐」拍板;T1 client 三缺口分录/T2 server 创建·改额·清账入账[RunWriteTx 同事务+AccountLookup 最小扩展]/T3 余额修复迁移[repairs 管道化+app_meta 幂等,经交易管道联动余额];不变式矩阵 13 测[client 7+server 3+repair 3];1871 全绿+analyze 438≤439+go 全绿+e2e 14/14;存储口径不变式 balance==+Σ剩余;已知边界:改总额 server 透传待 proto 字段) — worktree 已清,分支已删

## status: done(F33/F34/F35/F36 全 done,R14 release 功能收官,deploy 待用户)
