# Task Brief T6 — 冲突警示条 + 9 类图标

## 任务
`lib/debt/presentation/pages/debt_form_page.dart`（+ 测试同文件 test/debt/presentation/pages/debt_form_page_test.dart）；另排查两处图标漏项：`lib/core/widgets/debt_list_widgets.dart`、`lib/debt/presentation/pages/debt_detail_page.dart`。

1. **冲突警示条（FR-4，prototype v3 定稿）**：subtype radio 行下方，`DebtSubtypeAffinity.isConflict(_selectedAccount?.category.name, _subtypeKey)` 为 true 时渲染——形态复用 design-v2「callout.warn 提示卡」语义（warn 软底 `context.yucai.warn` 10-12% 混 surface、warn 图标、标题 + 正文 + 「可照常保存」pill；照 prototype/v3/ui/subtype-affinity.html 的视觉结构，Flutter 侧用既有令牌组合，勿造新色值）。文案（prototype 定稿）：
   - 标题：`分类与关联账户通常不一致`＋ pill `可照常保存`
   - 正文：`「{分类名}」一般不挂在当前类型的账户下。如属特殊情况(如房抵消费贷),忽略本提示继续即可。`
   - 非阻断：`_submit()` 校验路径零改动；账户未选(category null)或 subtype=other 永不显示；实时随选择出现/消失。
2. **4 新类图标**：`_debtTypeIcon` switch 补——credit_loan→`LucideIcons.handCoins`、cash_installment→`LucideIcons.calendarClock`、consumption_loan→`LucideIcons.shoppingBag`、business_loan→`LucideIcons.briefcase`（以 lucide_icons_flutter 包内实际命名为准，先 `grep -n "handCoins\|calendarClock\|shoppingBag\|briefcase"` 包源或 IDE 补全验证，名字对不上就用最接近的既有图标并在报告说明）。同时排查 debt_list_widgets / debt_detail_page 是否存在按 subtype 取图标的 switch（grep `DebtSubtypes.mortgage` 全 lib），有则同步补 4 类，无则在报告说明「列表/详情无 subtype 级图标，仅 chips labels 走 labels 迭代」。

## TDD 周期（sydusx-tdd）
测试沿用 debt_form_page_test.dart 风格。RED：
1. conflict 显示：选贷款账户 + 点「亲友借款」→ pump 后 expect(find.textContaining('分类与关联账户'), findsOneWidget)。
2. 兼容不显示：贷款账户 + 信用贷款 → findsNothing。
3. other 永不显示：任意账户 + 其他 → findsNothing。
4. 非阻断：conflict 态下照常提交成功（bloc 捕获 CreateDebtRequested/UpdateDebtRequested）。
5. 图标：9 张卡各自图标 key 存在（或按现有图标断言先例）。
GREEN 后回归 `flutter test test/debt/` + `dart analyze lib/debt/` 零新增。

## 约束
- **禁止 git stash/checkout/restore**；只动上述文件；勿提交 git。
- 警示条勿用阻断 dialog；勿改 _submit 校验；色值必须走 context.yucai 令牌（NFR/design-v2,禁裸 hex）。
- 工作目录：`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r14-f33`
完成后报告：改动文件、图标命名核对结果、RED→GREEN 证据、回归与 analyze 结果；BLOCKED 即停。
