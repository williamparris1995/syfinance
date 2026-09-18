# Sprint 1 — R14 F33-F36 债务与账户一致性四件

> /sydusx-portfolio(2026-09-18)。

## Sprint Goal

债务分类全链路可编辑 + 9 类扩展;支出支付方式放开信用卡;贷款账户详情页还款计划面板;负债记账治本(方案 A)。

## Feature roster

- [ ] **feature F33** debt-subtype — subtype 全链路可编辑 + 9 类扩展(proto `UpdateDebtRequest` 加 `subtype`;server handler/params 接线;client UpdateDebtParams/repo/DS/表单 chips 解禁;sync envelope 补字段) — claimed: zcode-r14 2026-09-18(worktree .claude/worktrees/r14-f33)
- [ ] **feature F34** credit-card-payment — 支出支付方式放开信用卡/负债账户(transaction_form 账户选择器现硬过滤 asset-only)
- [ ] **feature F35** repayment-plan-panel — 贷款账户详情页接入还款计划面板(现「待 payment_schedule 模块接入」占位;按 accountId 关联债务复用 schedule 数据源)
- [ ] **feature F36** liability-posting — 负债记账治本方案 A(借入创建即入账/还款全额过账/余额=−未还本金不变式 + 存量 debt 关联账户余额修复)

## status: pending
