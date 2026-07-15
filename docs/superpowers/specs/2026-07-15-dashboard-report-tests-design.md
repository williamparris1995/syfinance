# Dashboard/Report 测试补全 · 设计 spec

- **日期**: 2026-07-15
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: `holding-asset-management`
- **范围**: 为已实现的 dashboard-report(代码 commit `68508b2..4440f77`)补齐 widget 测试,兑现 [`2026-07-15-dashboard-report-design.md`](2026-07-15-dashboard-report-design.md) §6。**生产代码零改动**。
- **测试粒度**: 标准覆盖(用户拍板)—— Report 集成(success/error/period 切换 verify)+ 3 chart 单测(渲染+空态+图例)+ Home 5 panel(投资/固定资产值 + panels 非空态 + 快捷操作 onTap verify)

## 1. 背景

dashboard-report 代码已实现并 commit,但 spec §6 承诺的 widget test 从未补:

- **report 模块零测试**(codegraph 确认:`DailySummary` no covering tests)
- **home_page_test.dart 仅测 `_NetWorthCard`**(Task 11 holding-D,3 case:CNY/USD/error);dashboard 新增 5 panel(投资/固定资产/快捷操作/近期交易/资产配置/即将到期)**完全未覆盖**

测试范式已在 home_page_test.dart 建立:`mocktail`(`class _MockX extends Mock implements X`)+ `getIt.registerSingleton` 注入 + `when/verify` + `pumpAndSettle` + `_textContaining` helper(跨 RichText 文本查找)。

## 2. 关键决策

| # | 决策 | 理由 |
|---|---|---|
| 1 | **ReportPage 测试按 FutureBuilder 写(非 Bloc)** | 实际实现是 `getIt<TransactionRepository>.summary()` + FutureBuilder;spec §4 写的 `ReportBloc` 未落地。测试追**实际实现**,不追 spec |
| 2 | **chart widget 单测,纯数据 fixture** | 3 chart 都是 StatelessWidget,入参简单(byDay/slices/months);单测不需 mock getIt,直接构造 `MonthlySummary`/`DailySummary`/`CategoryTotal` fixture |
| 3 | **Home 扩充现有 home_page_test.dart(不新建)** | `_harness` 已 mock 4 repo(返回空);dashboard 5 panel 测试只需喂**非空数据** + 断言非空态。复用第一 |
| 4 | **`_harness` 改造为可注入 mock 数据** | 现有 `_harness` 把空返回写死。改为参数注入(accounts/txns/holdings/debts),现有 3 NetWorth test 传空,新 dashboard test 传非空 |
| 5 | **快捷操作 onTap 用独立 router harness** | `_QuickActions` 私有 + 硬编码 `context.go(route)`,verify 导航必须 `MaterialApp.router + GoRouter + MockNavigatorObserver`。新建独立 harness,不动现有 NetWorth harness(隔离) |
| 6 | **`_textContaining` helper 复制到 report test** | 跨 RichText 文本查找;小函数,report/home 各持一份(YAGNI);若第 3 处需要再提 `test/helpers/` |
| 7 | **mocktail any() fallback:SummaryScope + int** | `summary(year, month, scope:)` 用 any() 统一 stub;`registerFallbackValue(SummaryScope.month)` + 现有 `ListTransactionsParams` |

## 3. 测试文件清单

### 新建(report 模块,4 文件)

**`test/report/presentation/pages/report_page_test.dart`** — ReportPage 集成(mock `getIt<TransactionRepository>.summary`)
- ✅ success:summary 返非空 byDay(≥2 点含 income/expense)→ 汇总条(收入/支出/结余/日均 label + 金额)+ 3 section 标题("收支趋势"/"支出分类占比"/"近 6 月对比")+ `LineChart` 类型出现
- ✅ period 切换:点"年" segmented → `verify(repo.summary(any(), any(), scope: SummaryScope.year))` 被调用(排除 month 背景调用的 6 次 `_loadMonthlyComparison`)
- ✅ error:summary 返 `Left(Failure)` → 显示"加载失败" + 重试 TextButton

**`test/report/presentation/widgets/income_expense_trend_chart_test.dart`**
- 有数据(byDay 2+ 点含正 income/expense)→ `find.byType(LineChart)` + 图例"收入"/"支出"
- 空数据(byDay < 2 或全零)→ "所选区间暂无收支记录" + 无 LineChart

**`test/report/presentation/widgets/category_breakdown_pie_test.dart`**
- 有 slices(经 `aggregateCategorySlices`)→ `find.byType(PieChart)` + 分类图例(name)
- 空 slices → 空态

**`test/report/presentation/widgets/monthly_comparison_bar_test.dart`**
- 有 months(6 个 MonthlySummary)→ `find.byType(BarChart)`
- 空 months → 空态

### 扩充(`home_page_test.dart`,新增 test cases)

> `_harness` 改造为可注入(决策 4)。现有 3 NetWorth case 不动(传空);新增 case 传非空。

- ✅ **投资/固定资产真实值**:`AccountRepo.list` 返 investment + fixedDeposit/goldFx/realEstate 账户(非零 currentBalanceCents)→ 断言"投资资产"/"固定资产"卡显示汇总金额(`_formatCents` 后的 grouped yuan,非 "¥ 0.00")
- ✅ **近期交易非空态**:`TxnRepo.list` 返 1+ 笔 txn → 断言 txn.description 出现(非"暂无交易记录")
- ✅ **资产配置非空态**:`HoldingRepo.listHoldings` 返 1+ 持仓(含 securityType)→ 断言 `HoldingPieChart` 渲染(非"暂无持仓数据")
- ✅ **即将到期非空态**:`DebtRepo.upcomingPayments` 返 1+ 债务 → 断言 debt.counterparty 出现(非"暂无待办账单")
- ✅ **快捷操作 onTap(独立 router harness)**:`MaterialApp.router + GoRouter + MockNavigatorObserver`,tap"生成报表"tile → observer verify 导航 `/reports`

## 4. fixture 策略

`MonthlySummary`/`DailySummary`/`CategoryTotal` 都是普通不可变类(构造器字段全 optional 除 year/month/date/categoryId),fixture 直接构造:

```dart
MonthlySummary(
  year: 2026, month: 7, incomeCents: 100000, expenseCents: 60000,
  byDay: [
    DailySummary(date: '2026-07-01', byCategory: [
      CategoryTotal(categoryId: 'c1', name: '工资', accountType: 'income', amountCents: 100000),
      CategoryTotal(categoryId: 'c2', name: '餐饮', accountType: 'expense', amountCents: 60000),
    ]),
    DailySummary(date: '2026-07-02', byCategory: [...]),
  ],
  scope: SummaryScope.month,
)
```

income/expense 经 `CategoryTotal.accountType='income'/'expense'` 区分(对齐 `_incomeOf`/`_expenseOf` 逻辑)。

## 5. 回归

- `flutter test` 全量:基线 **1 预存 fail**(account_detail_page_test + receivable_detail_page_test 漂移,out-of-scope);**新测试全绿**
- `flutter analyze`:基线 22 error 全 `*.pbserver.dart`(客户端未用),不受影响

## 6. 风险

1. **快捷操作 onTap router harness 复杂度**(决策 5)—— `_QuickActions`/`_QuickTile` 私有,onTap 硬编码 `context.go`;需 `MaterialApp.router + GoRouter(routes: /home /reports /transactions/new /holdings/new)+ MockNavigatorObserver`。若 plan 阶段发现 router harness 与 home_page 现有 `context.read<AccountBloc>`/`getIt` 注入冲突,**降级**:仅断言 4 tile 渲染(`find.text` 记一笔/转账/买入投资/生成报表)+ tap 不抛(放弃 verify 路由路径)
2. **period 切换 verify 的背景调用干扰** —— `ReportPage.initState` 的 `_loadMonthlyComparison` 并发 6 次 summary(month scope);verify year scope 调用需 `registerFallbackValue` + 精确 matcher,排除 month 背景
3. **fl_chart test 环境渲染** —— LineChart/PieChart/BarChart 是纯 dart 绘制(无 GPU),`find.byType` + `pumpAndSettle` 可达;若 chart 内部有未完成动画/timer,改用 `pump`(对齐 CLAUDE.md "永不完成的 Future 用 pump")
4. **Home 5 panel 在同一 HomePage pump 内并发** —— `_SplitLayout` 内 3 panel + `_QuickActions` 各自 FutureBuilder/Bloc,pumpAndSettle 需等全部 done;若 interleave 卡住,按 panel 拆分 test 或 pump 固定时长
