# Task Brief T2 — 建户置位:并入模式 isSystem=true(FR-1)

## 上下文
worktree:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r17-f49`;客户端 `yucai/client`(pub get 已做)。
先读 feature 目录 `spec.md`(FR-1 两场景)与 `design.md`(单元2)。T1 已落:`CreateAccountParams` 有可选 `isSystem=false`,drift/实体/mapper 全链透传。

## 任务(TDD)
`debt/presentation/pages/debt_form_page.dart` 建户分支(约 742-775 行,`AccountRepository.create` 调用处):
- 并入模式(`!_cardLoanIndependent`)→ `isSystem: true`
- 独立账单模式 → 不传(缺省 false)
- 表单注释标明语义边界(并入=账务载体隐藏;独立=真实账户)。

测试(`test/debt/presentation/pages/` 既有 debt_form 测试文件或新文件,照既有范式):
- 场景1:guest 建信用卡分期(并入,选挂接卡)→ 自动建户 isSystem=true 且 notes 含自动创建标记
- 场景2:独立账单模式 → isSystem=false 且 creditBillingDay/RepaymentDay 写入

## 约束
只动 debt_form_page 与其测试;禁碰 accounts_page/repairs/account 模块。编辑路径(UpdateDebtRequested)零改动——存量由 T3 repair 负责。
每步:analyze → 单文件测 → debt 表单相关测。

## 完成判据
两场景测绿;analyze 零新增;报告改动清单+测试尾行。
