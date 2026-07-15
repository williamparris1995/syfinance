# Dashboard 占位修复 + 报表分析页 · 设计 spec

- **日期**: 2026-07-15
- **状态**: spec(plan mode 产物,待 writing-plans)
- **分支**: `holding-asset-management`
- **范围**: Home/Dashboard 占位修复(连接现有模块:投资/固定资产/快捷操作/近期交易/资产配置/即将到期)+ 报表分析页(新:收支趋势 LineChart + 分类占比 PieChart + 月度对比 BarChart)

## 1. 背景

御财 home/dashboard 大面积占位:投资/固定资产"待接入"、快捷操作不可点击、3 面板(近期交易/资产配置/即将到期)全空。sidebar "报表分析" 禁用。但后端模块全上线(holdings/transactions/debts),TransactionSummary byDay/byCategory 数据已拉前端却无 chart 消费。

## 2. 目标

Home: 5 个占位修复(连接现有 RPC + module data → real content)。Report: 新页 3 charts(复用 TransactionSummary data + fl_chart)。

## 3. 范围边界

| 在范围 | 不在范围(defer) |
|---|---|
| Home 投资资产/固定资产(account category 汇总) | 深色模式 |
| Home 快捷操作可点击(导航现有 routes) | Dashboard widget 自选布局 |
| Home 近期交易 panel(最近 5 笔) | 交易全文搜索 |
| Home 资产配置 panel(复用 HoldingPieChart) | 银行账单 CSV 导入 |
| Home 即将到期 panel(upcoming payments) | |
| Report 收支趋势(LineChart byDay) | |
| Report 分类占比(PieChart byCategory) | |
| Report 月度对比(BarChart 6 月) | |

零 proto/server 改动(复用 NetWorth/TransactionSummary/GetUpcomingPayments/ListHoldings RPC)。

## 4. 架构

### Part A: Home 修复(改现有 home_page.dart)

| panel | 数据源 | 复用 widget |
|---|---|---|
| 投资资产 | AccountBloc accounts filter(category=investment) sum currentBalance | _SummaryData(改值) |
| 固定资产 | AccountBloc accounts filter(category in [fixed_asset,gold,real_estate]) sum | _SummaryData(改值) |
| 快捷操作 | context.go routes | _QuickTile(加 onTap) |
| 近期交易 | TransactionRepository.list(pageSize:5) | mini txn card(简化 TxnRow) |
| 资产配置 | HoldingBloc load → holdings by SecurityType | HoldingPieChart(复用) |
| 即将到期 | DebtRepository.upcomingPayments(30) | payment mini list |

### Part B: Report 新页(lib/report/ DDD 四层)

| 层 | 组件 |
|---|---|
| domain | 复用 MonthlySummary(已有 byDay/byCategory) |
| data | 复用 TransactionRemoteDataSource.summary |
| presentation | ReportBloc(LoadSummaryRequested) + ReportPage(period tab + 3 charts) |
| widgets | IncomeExpenseTrendChart(LineChart) + CategoryBreakdownPie(PieChart) + MonthlyComparisonBar(BarChart) |
| core | router /reports + sidebar enable + DI |

## 5. Report charts 设计

### 5.1 收支趋势(LineChart)
- X 轴:日期(byDay);Y 轴:金额(cents→元)
- 2 条线:收入(绿 positive)+ 支出(红 negative)
- fl_chart LineChart(对齐 PerfCurveChart 范式)

### 5.2 分类占比(PieChart)
- byCategory data → PieChart sections(per category)
- 颜色:御财 token 系列(accent/positive/negative + 几色)
- fl_chart PieChart(对齐 HoldingPieChart 范式)

### 5.3 月度对比(BarChart)
- 6 个月 income vs expense 并排柱
- 需 6 次 TransactionSummary(month) RPC(Future.wait 并发)
- fl_chart BarChart(**首次使用**)

## 6. 测试
- Home: widget test(投资/固定资产真实值 + 快捷操作 onTap verify + panels 非空态)
- Report: widget test(3 charts 渲染 + period tab 切换)
- 回归: flutter test(3 预存 fail)+ analyze

## 7. 风险
1. Home 投资资产汇总需 AccountBloc accounts 有 category 字段(确认 Account entity 有 category)
2. 近期交易 panel 需 TransactionRepository(确认 getIt 可注入 home page)
3. MonthlyComparisonBar 6 次 RPC(并发 Future.wait,server 无 batch)
4. fl_chart BarChart 首次使用(对齐 fl_chart 1.2.0 API)
