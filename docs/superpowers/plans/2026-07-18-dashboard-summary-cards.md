# Dashboard 补 3 摘要卡 · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`).

**Goal:** home_page 补 3 摘要卡（本月收支/预算/目标 progress bar），照 OD 原型 `yucai-dashboard-home-a2fc`。

**Architecture:** client-only。home_page StatefulWidget 加 3 Future field（summary + getBudgetByMonth + listGoals）+ initState 并发调。build Column 插 3 FutureBuilder widget（`_IncomeExpenseCard` / `_BudgetCard` / `_GoalCard`），位置 `_NetWorthCard` 后 `_SummaryRow` 前。降级：fail/无数据 → 隐藏卡。零 server/proto/schema。

**Tech Stack:** Flutter flutter_bloc + getIt · TDD

---

## Global Constraints

1. **OD 原型 `yucai-dashboard-home-a2fc`** 作设计源（index.html + styles.css）。implementer 读 OD 原型 CSS（`get_artifact` 或 `get_file`）对齐 Flutter widget 样式（颜色/字号/间距 token）。
2. **数据 API 已 ready**：`TransactionRepository.summary` / `BudgetRepository.getBudgetByMonth` / `GoalRepository.listGoals`（getIt 注入，照现有 `_netWorthDs` 模式）。
3. **降级**：RPC fail → 隐藏卡（不 crash，照 home_page 现有 best-effort）；当月无预算 → 预算卡隐藏；无 active goal → 目标卡隐藏。
4. **金额格式化**：复用 `_formatCents`（home_page 现有）。
5. **零 server/proto/schema/wire**。commit multi `-m`。

---

## File Structure

| 文件 | 改动 |
|---|---|
| [home_page.dart](../../yucai/client/lib/auth/presentation/pages/home_page.dart) | +3 Future field + initState 调 + build Column 插 3 widget + 3 `_SummaryCard` 私有 widget |
| home_page_test.dart | +3 卡显示/降级/隐藏测 |

---

## Task 1: home_page 补 3 摘要卡

**Files:**
- Modify: [home_page.dart](../../yucai/client/lib/auth/presentation/pages/home_page.dart)
- Modify: [home_page_test.dart](../../yucai/client/test/...)（grep 现有 home_page test）

- [ ] **Step 1: 读 OD 原型样式**

`get_artifact(project="yucai-dashboard-home-a2fc", entry="index.html")` 或 `get_file(path="styles.css")`。提取 3 卡样式 token：
- 收支：`.ie-rows` / `.ie-row` / `.ie-dot` / `.ie-amt`(income #4a9d6e / expense #d4726e) / `.ie-total`
- 预算/目标：`.prog-amt` / `.progress`(8px height pill) / `.progress-bar.accent`(#b08d57) / `.progress-bar.goal`(#4a9d6e) / `.prog-foot`
- 间距/字号：照 `:root` token（`--s-12/16/20` / `--fs-13/16/20`）

- [ ] **Step 2: 加 3 Future field + initState**

`_HomePageState` 加：
```dart
late final TransactionRepository _txnRepo = getIt<TransactionRepository>();
late final BudgetRepository _budgetRepo = getIt<BudgetRepository>();
late final GoalRepository _goalRepo = getIt<GoalRepository>();

Future<MonthlySummary>? _summaryFuture;
Future<BudgetView?>? _budgetFuture;  // null = no budget this month
Future<List<GoalView>>? _goalsFuture;
```

initState 加（并发 3 调）：
```dart
final now = DateTime.now();
final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
_summaryFuture = _txnRepo.summary(now.year, now.month).then((r) => r.fold((_) => MonthlySummary(year: now.year, month: now.month, scope: SummaryScope.month), (s) => s));
_budgetFuture = _budgetRepo.getBudgetByMonth(month).then((r) => r.fold((_) => null, (b) => b));
_goalsFuture = _goalRepo.listGoals(completed: false).then((r) => r.fold((_) => <GoalView>[], (g) => g));
```

- [ ] **Step 3: build Column 插 3 widget**

在 `_NetWorthCard` 后、`_SummaryRow` 前（home_page.dart ~L193）插入：
```dart
const SizedBox(height: AppSpacing.md),
// 3 摘要卡(照 OD 原型)
FutureBuilder<MonthlySummary>(
  future: _summaryFuture,
  builder: (ctx, snap) => snap.hasData
    ? _IncomeExpenseCard(summary: snap.data!, format: _formatCents)
    : const SizedBox.shrink(),  // loading/fail → 隐藏
),
FutureBuilder<BudgetView?>(
  future: _budgetFuture,
  builder: (ctx, snap) => (snap.hasData && snap.data != null)
    ? _BudgetCard(budget: snap.data!, format: _formatCents)
    : const SizedBox.shrink(),  // loading/fail/no budget → 隐藏
),
FutureBuilder<List<GoalView>>(
  future: _goalsFuture,
  builder: (ctx, snap) => (snap.hasData && snap.data!.isNotEmpty)
    ? _GoalCard(goals: snap.data!, format: _formatCents)
    : const SizedBox.shrink(),  // loading/fail/no goals → 隐藏
),
```

- [ ] **Step 4: 实现 3 私有 widget**

照 OD 原型 CSS 对齐 Flutter widget（implementer 读 OD styles.css 提取 token）：

**`_IncomeExpenseCard`**：收支卡（收入 +¥ 绿 / 支出 −¥ 红 / 结余 ¥ serif bold）。
**`_BudgetCard`**：预算卡（progress bar 金色 usagePct% + ¥actual/planned + foot）。
**`_GoalCard`**：目标卡（top goal progress bar 绿 + ¥current/target · % + foot）。

样式 token（从 OD `:root`）：
- 卡片：白底 `#fff` + 圆角 10 + border `#E8E4DC` + padding 20
- label：13px / 600 / fg
- period：11px / muted / mono
- 收支金额：16px / 600 / mono tabular / income `#4a9d6e` / expense `#d4726e`
- 结余：20px / 700 / serif display
- progress bar：8px height / pill / accent `#b08d57`（预算）/ income `#4a9d6e`（目标）
- prog-amt：20px / 600 / mono
- prog-foot：11px / muted

- [ ] **Step 5: test**

widget test：home_page 有数据 → 3 卡显示；fail/mock error → 隐藏（SizedBox.shrink）；无预算 → 预算卡隐藏；无目标 → 目标卡隐藏。mocktail TransactionRepository / BudgetRepository / GoalRepository。

- [ ] **Step 6: analyze + test + build**

Run: `cd yucai/client && flutter analyze`(22 基线无新增)
Run: `cd yucai/client && flutter test test/`(新测过,基线 4 fail 不引入新)
Run: `cd yucai/client && flutter build windows --debug`

- [ ] **Step 7: Commit**

```bash
cd e:/projects/syfinance
git add yucai/client/lib/auth/presentation/pages/home_page.dart yucai/client/test/...
git commit -m "feat(dashboard): 3 summary cards (income/budget/goal) — P0-1" -m "home_page 补 3 摘要卡(本月收支/预算/目标 progress bar). 照 OD 原型 yucai-dashboard-home-a2fc. TransactionRepository.summary + BudgetRepository.getBudgetByMonth + GoalRepository.listGoals. 降级: fail/无数据 -> 隐藏卡. client-only, zero server/proto/schema."
```
