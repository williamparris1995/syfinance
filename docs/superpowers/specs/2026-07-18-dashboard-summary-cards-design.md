# Dashboard 补 3 摘要卡(收支/预算/目标)· 设计 spec

- **日期**: 2026-07-18
- **状态**: spec(OD 原型 `yucai-dashboard-home-a2fc` 作设计源,待用户审 → writing-plans → subagent)
- **分支**: 待定(main-driven,从 main 最新 `cad4d57`)
- **范围**: home_page 补 3 摘要卡(本月收支 / 本月预算 / 目标进度)。**client-only**(数据 API 已 ready,零 server/proto/schema)。

## 1. 背景

home_page([home_page.dart](../../yucai/client/lib/auth/presentation/pages/home_page.dart))现有:净资产大卡 + 资产分解 4 卡 + 快捷操作 + 近期交易 + 资产配置饼图 + 到期还款。**缺 budget 执行 / goal 进度 / 月度收支摘要**(P0 核心缺失,用户第一眼看不到预算/目标/收支)。

OD 原型 `yucai-dashboard-home-a2fc` 已设计 3 卡(收支 ie-rows / 预算+目标 progress bar,御财 token 严格)。

## 2. 目标

home_page 补 3 摘要卡,位置:净资产 → **收支** → **预算** → **目标** → 资产分解 → 快捷 → 近期交易 → 饼图 → 到期。照 OD 原型样式。

## 3. 数据源(client API 已 ready)

| 卡 | 数据源 | 字段 |
|---|---|---|
| 本月收支 | `TransactionRepository.summary(year, month, scope: month)` → `MonthlySummary` | incomeCents / expenseCents / netCents |
| 本月预算 | `BudgetRepository.getBudgetByMonth('yyyy-MM')` → `BudgetView` | totalAmountCents / totalActualCents / usagePct |
| 目标进度 | `GoalRepository.listGoals(completed: false)` → `List<GoalView>` | top goal currentAmountCents / targetAmountCents + progress% |

## 4. 设计(照 OD 原型)

### 收支卡
- 收入(+¥X 绿 #4a9d6e bold)/ 支出(−¥Y 红 #d4726e bold)/ 结余(¥Z serif bold)
- period label "2026 年 7 月"

### 预算卡
- progress bar(金色 #b08d57,usagePct%)+ ¥actual/planned + "剩余 ¥X / 还剩 N 天"

### 目标卡
- progress bar(绿 #4a9d6e,progress%)+ ¥current/target · % + "距目标 ¥X / 预计达成"

### 降级
- 收支/预算/目标 RPC fail → 卡片隐藏或 "—" 降级(照 home_page 现有 best-effort 模式)
- 无预算(当月无 budget)→ 预算卡隐藏
- 无目标(active goals 空)→ 目标卡隐藏

## 5. 范围边界

| 在范围 | 不在范围 |
|---|---|
| home_page 加 3 摘要卡 widget(照 OD 原型) | server/proto/schema(零改) |
| 收支:TransactionRepository.summary 调 + 卡 | report 历史日期切换(P0-2 独立) |
| 预算:BudgetRepository.getBudgetByMonth 调 + progress bar | holding client stale 注释清理(P1) |
| 目标:GoalRepository.listGoals 调 + progress bar | 新 bloc(复用现有 repo 直调 or home bloc 扩展) |

## 6. 实现(home_page)

home_page `_body` Column 在 净资产卡 后、资产分解前 插入 3 卡:

- **数据获取**:home_page initState 或 build 时 `FutureBuilder` 并发调 3 repo(summary + getBudgetByMonth + listGoals)。或扩展现有 home 数据加载(如有 HomeBloc)。
- **widget**:3 新 `_SummaryCard`(收支/预算/目标),照 OD 原型 CSS 对应 Flutter widget(收支 Row + 预算/目标 ProgressBar)。
- **格式化**:金额 cents → currencySymbol(currency) + 千分位 + 2 位小数(复用 home_page 现有 `_formatCents`)。

## 7. 测试

- widget test:home_page 显示 3 卡(有数据时);RPC fail → 降级(隐藏/—);无预算/目标 → 隐藏卡。
- 数据 mock:mocktail TransactionRepository.summary / BudgetRepository.getBudgetByMonth / GoalRepository.listGoals。

## 8. 风险

1. **数据获取并发**:3 repo 调(summary + getBudgetByMonth + listGoals)并发 or 串行?FutureBuilder 并发(Future.wait)或分开 FutureBuilder。plan 决定。
2. **home_page 现有结构**:home_page 可能用 FutureBuilder 或 BlocBuilder。plan 确认现有数据加载模式(NetWorthDataSource / TransactionRepository.list / DebtRepository.upcomingPayments 怎么调)。
3. **预算当月无 budget**:getBudgetByMonth 返 NotFound/error → 预算卡隐藏(不 crash)。
4. **目标多个**:listGoals 返多 goal → 显示 top 1(progress 最高 or currentAmount 最大)?或总 progress(Σ current / Σ target)?plan 决定。

## 9. 参考

- OD 原型:OD 项目 `yucai-dashboard-home-a2fc`(index.html + styles.css + tablet/mobile)
- home_page:[home_page.dart](../../yucai/client/lib/auth/presentation/pages/home_page.dart)(现有结构)
- 数据源:[TransactionRepository.summary](../../yucai/client/lib/transaction/domain/repositories/transaction_repository.dart) / [BudgetRepository.getBudgetByMonth](../../yucai/client/lib/budget/domain/repositories/budget_repository.dart) / [GoalRepository.listGoals](../../yucai/client/lib/goal/domain/repositories/goal_repository.dart)
