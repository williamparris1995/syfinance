# Code Plan — F50

> 源:[spec.md](spec.md) + [design.md](design.md)。全部命令在 worktree `.claude/worktrees/r17-f50` 内执行。零 proto/server 改动。

## Tasks

- [x] **TA debt 垂直片**(serial 先行)
  - `debt/domain/entities/debt_entity.dart`:+`countsTowardCardLimit`(bool,默认 true)
  - `debt/domain/debt_query.dart`:+`cardLoanOccupationCents(List<Debt>, String cardId)`(过滤 subtype==card_loan ∧ collectionAccountId==cardId ∧ countsTowardCardLimit;Σ remainingPrincipalCents)
  - `core/localdb/app_database.dart`:schemaVersion 12→13 + debts 表 `counts_toward_card_limit`(NOT NULL DEFAULT true)迁移
  - `debt/data/debt_local_ds.dart` + mappers:行↔实体双向透出;**sync 重建债行的路径 keep-existing**(定位 debt 的 proto→local applier,新列不在 proto,不得覆写;新拉取行默认 true)
  - 测试:纯函数四 fixtures(平安 11,271.70/38,728.30;e招贷零占用;开关关排除;广发组合)+ applier 列保持回归
- [x] **TB 债表单开关**(与 TC 并行)
  - `debt/presentation/pages/debt_form_page.dart`:卡贷且挂接卡(collectionAccountId 非空)时显示「计入挂接卡额度占用」开关,默认开 + helper(备用金类独立额度置关);详情页只读展示(顺手)
  - 测试:挂接才显示/默认态/切换持久化(widget 或 bloc 级)
- [x] **TC 两页显示注入**(与 TB 并行)
  - `account/presentation/pages/accounts_page.dart`:`occupationFor` 闭包注入(参照 `git show 794bc677` diff,口径改仅剩余本金);creditCard 卡片已用/利用率计入
  - `account/presentation/pages/account_detail_page.dart`:四卡 已用=abs(balance)+occupation、可用=limit−已用(替换 7245465c 的 limit−欠款)
  - 测试:两页数值断言 + **display-only**(开关切换前后负债总额/净资产逐分不变)
- [x] **TD 校准与全量门**(收口;e2e 12/13,1 失败=main 既有环境性,双点复跑排除因果)
  - FR-5 校准用例(平安真值 38,728.30)进测试套件
  - 全量 `flutter test` 绿 + `flutter analyze` ≤ 基线 + `make client-e2e`
- [ ] **TS4 修复 runbook 执行**(非代码,用户 app 操作)
  - 四笔补记:35k→2026-06-12 ¥1,630.46 / 25k→2024-12-24 ¥1,081.18 / 9.1k→2025-09-25 ¥447.44 / 5k→2026-08-02 ¥319.63
  - 修复后核验:四笔剩余==银行真值(±2.00);平安卡显示可用 == ¥38,728.30;35k 开关置关

## 执行序

TA(serial)→ TB ∥ TC(并行子任务)→ TD(收口)→ TS4(runbook,交付时用户执行)。每 task:RED→GREEN→重构 + 完成即单文件测试 + 两轴评审。
