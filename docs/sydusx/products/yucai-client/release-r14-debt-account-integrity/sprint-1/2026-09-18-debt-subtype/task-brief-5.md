# Task Brief T5 — 表单 chips 解禁 + 创建自动归位

## 任务
`lib/debt/presentation/pages/debt_form_page.dart`（+ 测试 `test/debt/presentation/pages/debt_form_page_test.dart`）：

1. **编辑模式 chips 解禁**：移除 subtype radio 的只读分支（`:939` 附近，T4 已把注释改为"不传(空串=不修改)"）；编辑保存时 `UpdateDebtParams` 显式携带 `subtype: _subtypeKey`（T4 已给 params 加了该字段，两个编辑调用点目前刻意不传——现在改为传入）。表单的「确认提交」确认框(:1195 subtypeLabel)无需改。
2. **创建自动归位**（design.md LLD ②状态机）：
   - 新增 `bool _subtypeTouched = false;`；subtype radio `onChanged`（创建+编辑都置 true）。
   - `_onAccountChanged`：置 `_accountId` + `_refillCreditCardFields()`（现状不动）之后，**仅创建模式且 `!_subtypeTouched`** 时：`final d = DebtSubtypeAffinity.defaultSubtypeFor(account.category.name); if (d != null) setState(() => _subtypeKey = d);`
   - 编辑模式**不归位**（存量修正靠编辑自由改）。
   - `DebtSubtypeAffinity` API（T3 已落地）：`defaultSubtypeFor(String? category)` / `isConflict(String? category, String subtypeKey)`，category 传 `AccountCategory.name` 字符串。
3. **勿动**：警示条（T6 做）、图标 switch（T6 做）、信用卡专属字段区逻辑（`_refillCreditCardFields`/`_persistCreditCardFieldsIfNeeded` 现状保持）。

## TDD 周期（sydusx-tdd）
测试文件沿用 `debt_form_page_test.dart` 既有风格（T3 刚把计数断言同步为 9）。RED：
1. 编辑模式：打开编辑表单 → 切换 subtype 卡 → 提交 → 捕获 bloc `UpdateDebtRequested` 的 params.subtype == 新值。
2. 创建归位：新建表单（未碰 subtype）→ 选账户「个人待还款」(category=otherLiability) → 期望选中变为 family。
3. 触碰不覆盖：先手动点「信用贷款」→ 再切账户 → 选中仍为 credit_loan。
4. 编辑模式改账户：选中不联动。
GREEN 后回归：`flutter test test/debt/` 全绿 + `dart analyze lib/debt/` 零新增 info。

## 约束
- 账户下拉现有 `_visibleAccounts` 行为（subtype=credit_card 时过滤信用卡账户）保持不变；归位与过滤的交互序列（选贷款账户→归位 credit_loan→手动切 credit_card→下拉突变）需有一条测试覆盖最终状态一致。
- 勿提交 git；勿动其他文件。
- 工作目录：`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r14-f33`
完成后报告：改动文件、RED→GREEN 证据、每条测试名与结果、analyze 结果；BLOCKED 即停。
