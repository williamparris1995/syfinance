# Reports Page Chart Redesign — Design Spec

**Date:** 2026-05-22
**Status:** Draft
**Approach:** C — Donut charts + bar charts (Monarch Money / Copilot style)

## Motivation

The current Reports page has a single bar chart comparing total income vs total expenses. It lacks category-level breakdown and trend visualization. Industry-leading apps (Monarch Money, Copilot) use donut charts for proportion + bar charts for trends.

## Design Principles

1. **Three-second comprehension** — user should instantly see: total income, total expenses, where money went
2. **Labels on chart** — no separate legend cross-referencing (Monarch Money pattern)
3. **Color from accounts** — chart colors use the external account's `color` field
4. **Icons from accounts** — labels include the external account's `icon` emoji
5. **Max 8 slices** — beyond that, merge into "其他"

## Layout

```
┌──────────────────────────────────────────────┐
│ [本月] [本季] [本年] [自定义]   2026-05-01..31 │  ← 周期选择器（已有）
├──────────┬──────────┬─────────────────────────┤
│  收入    │  支出    │  结余                    │  ← 摘要卡片
│ ¥15,000  │ ¥8,420  │  ¥6,580 (43.9%)         │
├──────────┴──────────┴─────────────────────────┤
│  ┌─────────────────┐ ┌──────────────────────┐ │
│  │ 支出分类(环形)   │ │ 月度支出趋势(堆叠柱) │ │  ← 图表行 1
│  │ 🍔 餐饮  ¥2,520 │ │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │ │
│  │ 🚗 交通  ¥1,680 │ │ ▓▓▓ 1月..5月        │ │
│  └─────────────────┘ └──────────────────────┘ │
│  ┌─────────────────┐ ┌──────────────────────┐ │
│  │ 收入来源(环形)   │ │ 月度收支对比(分组柱) │ │  ← 图表行 2
│  └─────────────────┘ └──────────────────────┘ │
│  ┌─────────────────────────────────────────┐  │
│  │ 支出明细表 分类 | 金额 | 占比 | 交易数   │  │  ← 明细
│  └─────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

## Components

### 1. Summary Cards (新增)

Three cards replacing the single total balance card:
- **Income** — green gradient card, total income, count of income transactions
- **Expenses** — red gradient card, total expenses, count of expense transactions
- **Net** — blue gradient card, net = income - expenses, savings rate %

Data source: derived from `incomeStatementData` (already computed).

### 2. Expense Donut Chart (新增)

- **Chart type**: `PieChart` with `innerRadius={60} outerRadius={90}` (donut style)
- **Center text**: "总支出 ¥X,XXX" (using Recharts `Label` or absolute-positioned div)
- **Slices**: each external account with `account_type === 'Expense'`
- **Color**: from account's `color` field (with fallback palette)
- **Label list**: rendered as a custom component beside the donut showing:
  - Color dot + emoji + name + amount + percentage
- **Max 8 slices**: if more than 8 expense accounts, top 7 + "其他" merged

Data: `incomeStatementData.expenses`

### 3. Stacked Bar Chart (新增)

- **Chart type**: `BarChart` with `stackId="expenses"`
- **Each bar**: one month, segmented by expense categories
- **X-axis**: month labels (1月, 2月, ... or Jan, Feb, ...)
- **Each stack segment**: colored by account's `color`
- **Top 5-6 categories**: rest merged into "其他"

Data: requires monthly aggregation. Compute from `filteredTransactions` grouped by month and external account.

### 4. Income Donut Chart (新增)

Same structure as expense donut, but for income accounts.
- **Center text**: "总收入 ¥X,XXX"
- Data: `incomeStatementData.income`

### 5. Income vs Expense Bar Chart (替换现有)

- **Chart type**: `BarChart` with two `Bar` components (no stack)
- **Green bar**: income, **Red bar**: expenses
- Per-month grouping

Data: monthly aggregation of income/expense totals.

### 6. Category Detail Table (已有, 保留)

Keep the existing income/expense tables. Add a "transaction count" column.

## Data Flow

```
transactions[] + accounts[] + dateRange
    │
    ├── incomeStatementData (已有)
    │   ├── .income[]  → Income Donut, Detail Table
    │   ├── .expenses[] → Expense Donut, Detail Table
    │   └── .totalIncome/.totalExpenses → Summary Cards
    │
    └── monthlyData (新增 useMemo)
        └── by month → Stacked Bar, Income/Expense Trend Bar
```

### New `monthlyTrendData` computation:

```typescript
const monthlyTrendData = useMemo(() => {
  const months: Record<string, Record<string, number>> = {};
  
  dateFilteredTransactions.forEach(tx => {
    const month = tx.transaction_date.substring(0, 7); // "2026-05"
    if (!months[month]) months[month] = {};
    
    tx.entries.forEach(entry => {
      const account = accounts.find(a => a.id === entry.account_id);
      if (!account || account.ownership !== 'external') return;
      
      const amount = entry.debit_amount ? parseFloat(entry.debit_amount) 
                   : entry.credit_amount ? parseFloat(entry.credit_amount) : 0;
      months[month][account.name] = (months[month][account.name] || 0) + amount;
    });
  });
  
  return Object.entries(months).map(([month, categories]) => ({
    month,
    ...categories,
  }));
}, [dateFilteredTransactions, accounts]);
```

## Color Mapping

Each external account has a `color` field (hex). Use it directly:
```tsx
<Cell key={name} fill={account.color || FALLBACK_COLORS[index % FALLBACK_COLORS.length]} />
```

Fallback palette if account has no color:
```typescript
const FALLBACK_COLORS = ['#EF4444','#F59E0B','#10B981','#3B82F6','#8B5CF6','#EC4899','#06B6D4','#84CC16'];
```

## Tech Stack

- **recharts** — already installed (`PieChart`, `BarChart`, `Cell`, `ResponsiveContainer`, `Tooltip`, `Legend`)
- **date-fns** or vanilla Date — month grouping (no new dependency needed)
- Tailwind CSS for card styling

## What Gets Removed

- The old simple bar chart (income vs expenses, single bar) — replaced by donut + stacked bar + trend bar
- Balance Sheet tab — UNCHANGED (keep asset/liability table)
- CSV export — UNCHANGED (keep existing export functionality)

## Scope

This is a **frontend-only** change. No backend API changes needed. All data is already available:
- `listAccounts` returns `AccountDto` with `color`, `icon`, `ownership`, `account_type`
- `listTransactions` returns `TransactionDto` with entries and dates
- Date filtering logic already exists in `ReportsPage`
