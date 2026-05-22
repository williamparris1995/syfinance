# Reports Page Chart Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single bar chart on ReportsPage with summary cards, donut charts for category breakdown, stacked bar for monthly trends, and income-vs-expense trend bars.

**Architecture:** Frontend-only change to `ReportsPage.tsx`. Uses already-installed `recharts` (`PieChart`, `BarChart`, `Cell`, `ResponsiveContainer`, `Tooltip`). Data is derived from existing `accounts` + `transactions` + `dateRange` queries. No backend changes.

**Tech Stack:** React 19, TypeScript, recharts, Tailwind CSS, @tanstack/react-query

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `src/pages/ReportsPage.tsx` | Modify | All chart components, data logic, layout |
| `src/i18n/locales/en.json` | Modify | New translation keys |
| `src/i18n/locales/zh.json` | Modify | New translation keys |

No new files. The change is scoped to the ReportsPage component.

---

### Task 1: Add monthly trend data computation

**Files:**
- Modify: `src/pages/ReportsPage.tsx`

- [ ] **Step 1: Add monthlyTrendData useMemo**

Add after the existing `incomeStatementData` useMemo (around line 150):

```typescript
const monthlyTrendData = useMemo(() => {
  const months: Record<string, {
    month: string;
    income: number;
    expenses: number;
    [category: string]: number | string;
  }> = {};

  const filteredTransactions = transactions.filter((tx: TransactionDto) => {
    const txDate = tx.transaction_date;
    return txDate >= dateRange.start && txDate <= dateRange.end;
  });

  filteredTransactions.forEach((tx: TransactionDto) => {
    const month = tx.transaction_date.substring(0, 7);
    if (!months[month]) {
      months[month] = { month, income: 0, expenses: 0 };
    }

    tx.entries.forEach((entry) => {
      const account = accounts.find(a => a.id === entry.account_id);
      if (!account || account.ownership !== 'external') return;

      const amount = entry.debit_amount ? parseFloat(entry.debit_amount)
        : entry.credit_amount ? parseFloat(entry.credit_amount) : 0;

      if (account.account_type === 'Expense') {
        months[month][account.name] = ((months[month][account.name] as number) || 0) + amount;
        months[month].expenses += amount;
      } else if (account.account_type === 'Income') {
        months[month][account.name] = ((months[month][account.name] as number) || 0) + amount;
        months[month].income += amount;
      }
    });
  });

  return Object.values(months).sort((a, b) => a.month.localeCompare(b.month));
}, [transactions, dateRange, accounts]);
```

- [ ] **Step 2: Compute all-time category keys for consistent colors**

Add after `monthlyTrendData`:

```typescript
const expenseCategories = useMemo(() => {
  const cats = new Set<string>();
  monthlyTrendData.forEach(m => {
    accounts.filter(a => a.account_type === 'Expense' && a.ownership === 'external')
      .forEach(a => { if (m[a.name] !== undefined) cats.add(a.name); });
  });
  return Array.from(cats);
}, [monthlyTrendData, accounts]);

const incomeCategories = useMemo(() => {
  const cats = new Set<string>();
  monthlyTrendData.forEach(m => {
    accounts.filter(a => a.account_type === 'Income' && a.ownership === 'external')
      .forEach(a => { if (m[a.name] !== undefined) cats.add(a.name); });
  });
  return Array.from(cats);
}, [monthlyTrendData, accounts]);
```

- [ ] **Step 3: Commit**

```bash
git add src/pages/ReportsPage.tsx
git commit -m "feat: add monthly trend data computation for charts"
```

---

### Task 2: Add summary cards

**Files:**
- Modify: `src/pages/ReportsPage.tsx`
- Modify: `src/i18n/locales/en.json`
- Modify: `src/i18n/locales/zh.json`

- [ ] **Step 1: Replace old chart with summary cards**

Remove the old `chartData` useMemo (lines 152-157). Replace the old bar chart in the income-statement tab with summary cards section. Insert before the income/expense tables (around line 437):

```tsx
{/* Summary Cards */}
<div className="grid gap-4 md:grid-cols-3 mb-6">
  <Card className="bg-gradient-to-br from-emerald-50/50 to-card border-emerald-200/50 dark:from-emerald-950/20 dark:to-card dark:border-emerald-800/30">
    <CardContent className="pt-4">
      <div className="text-xs uppercase tracking-wider text-emerald-600 dark:text-emerald-400 mb-1">
        {t('reports.income')}
      </div>
      <div className="text-2xl font-bold text-emerald-700 dark:text-emerald-300">
        ¥{incomeStatementData.totalIncome.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
      </div>
      <div className="text-xs text-emerald-600/70 dark:text-emerald-400/70 mt-1">
        {incomeStatementData.income.length} {t('reports.categories')}
      </div>
    </CardContent>
  </Card>

  <Card className="bg-gradient-to-br from-red-50/50 to-card border-red-200/50 dark:from-red-950/20 dark:to-card dark:border-red-800/30">
    <CardContent className="pt-4">
      <div className="text-xs uppercase tracking-wider text-red-600 dark:text-red-400 mb-1">
        {t('reports.expenses')}
      </div>
      <div className="text-2xl font-bold text-red-700 dark:text-red-300">
        ¥{incomeStatementData.totalExpenses.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
      </div>
      <div className="text-xs text-red-600/70 dark:text-red-400/70 mt-1">
        {incomeStatementData.expenses.length} {t('reports.categories')}
      </div>
    </CardContent>
  </Card>

  <Card className={cn(
    "bg-gradient-to-br border to-card",
    incomeStatementData.netIncome >= 0
      ? "from-blue-50/50 border-blue-200/50 dark:from-blue-950/20 dark:border-blue-800/30"
      : "from-amber-50/50 border-amber-200/50 dark:from-amber-950/20 dark:border-amber-800/30"
  )}>
    <CardContent className="pt-4">
      <div className="text-xs uppercase tracking-wider text-blue-600 dark:text-blue-400 mb-1">
        {t('reports.netIncome')}
      </div>
      <div className={cn(
        "text-2xl font-bold",
        incomeStatementData.netIncome >= 0
          ? "text-blue-700 dark:text-blue-300"
          : "text-amber-700 dark:text-amber-300"
      )}>
        ¥{incomeStatementData.netIncome.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
      </div>
      <div className="text-xs text-blue-600/70 dark:text-blue-400/70 mt-1">
        {incomeStatementData.totalIncome > 0
          ? `${t('reports.savingsRate')} ${((incomeStatementData.netIncome / incomeStatementData.totalIncome) * 100).toFixed(1)}%`
          : '—'}
      </div>
    </CardContent>
  </Card>
</div>
```

Add `cn` import if not already present:
```typescript
import { cn } from '@/lib/utils';
```

- [ ] **Step 2: Add i18n keys**

In `src/i18n/locales/en.json`, add:
```json
"categories": "categories",
"savingsRate": "Savings rate",
```

In `src/i18n/locales/zh.json`, add:
```json
"categories": "个分类",
"savingsRate": "结余率",
```

- [ ] **Step 3: Commit**

```bash
git add src/pages/ReportsPage.tsx src/i18n/locales/en.json src/i18n/locales/zh.json
git commit -m "feat: add summary cards (income/expense/net) to reports page"
```

---

### Task 3: Add expense donut chart and income donut chart

**Files:**
- Modify: `src/pages/ReportsPage.tsx`

- [ ] **Step 1: Add ExpenseDonut component before the income tables section**

Add `Cell` to the recharts imports (line 5):
```typescript
import { Bar, BarChart, CartesianGrid, Cell, Legend, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
```

Insert the expense donut chart before the income table in the income-statement tab (after the summary cards, around where the old chart was):

```tsx
{/* Charts Row: Donuts + Trends */}
<div className="grid gap-4 md:grid-cols-2 mb-6">
  {/* Expense Donut */}
  <Card>
    <CardHeader>
      <CardTitle className="text-sm">{t('reports.expenseBreakdown')}</CardTitle>
    </CardHeader>
    <CardContent>
      {incomeStatementData.expenses.length === 0 ? (
        <p className="text-sm text-muted-foreground text-center py-8">{t('reports.noExpenses')}</p>
      ) : (
        <div className="flex items-center gap-4">
          <ResponsiveContainer width={160} height={160}>
            <PieChart>
              <Pie
                data={incomeStatementData.expenses}
                dataKey="amount"
                nameKey="name"
                cx="50%"
                cy="50%"
                innerRadius={48}
                outerRadius={76}
                paddingAngle={2}
              >
                {incomeStatementData.expenses.map((entry, index) => {
                  const account = accounts.find(a => a.name === entry.name && a.account_type === 'Expense');
                  return (
                    <Cell
                      key={entry.name}
                      fill={account?.color || FALLBACK_COLORS[index % FALLBACK_COLORS.length]}
                      stroke="none"
                    />
                  );
                })}
              </Pie>
              <Tooltip
                formatter={(value: number, name: string) => [
                  `¥${value.toLocaleString('en-US', { minimumFractionDigits: 2 })}`,
                  name,
                ]}
              />
            </PieChart>
          </ResponsiveContainer>
          <div className="flex-1 space-y-1.5 max-h-[160px] overflow-y-auto">
            {incomeStatementData.expenses
              .sort((a, b) => b.amount - a.amount)
              .map((item, index) => {
                const account = accounts.find(a => a.name === item.name && a.account_type === 'Expense');
                const pct = incomeStatementData.totalExpenses > 0
                  ? ((item.amount / incomeStatementData.totalExpenses) * 100).toFixed(1)
                  : '0';
                return (
                  <div key={item.name} className="flex items-center gap-2 text-xs">
                    <span
                      className="w-2.5 h-2.5 rounded-sm flex-shrink-0"
                      style={{ backgroundColor: account?.color || FALLBACK_COLORS[index % FALLBACK_COLORS.length] }}
                    />
                    <span className="truncate flex-1">
                      {account?.icon || ''} {item.name}
                    </span>
                    <span className="text-muted-foreground tabular-nums">¥{item.amount.toFixed(0)}</span>
                    <span className="text-muted-foreground/60 w-10 text-right tabular-nums">{pct}%</span>
                  </div>
                );
              })}
          </div>
        </div>
      )}
    </CardContent>
  </Card>

  {/* Income Donut */}
  <Card>
    <CardHeader>
      <CardTitle className="text-sm">{t('reports.incomeBreakdown')}</CardTitle>
    </CardHeader>
    <CardContent>
      {incomeStatementData.income.length === 0 ? (
        <p className="text-sm text-muted-foreground text-center py-8">{t('reports.noIncome')}</p>
      ) : (
        <div className="flex items-center gap-4">
          <ResponsiveContainer width={160} height={160}>
            <PieChart>
              <Pie
                data={incomeStatementData.income}
                dataKey="amount"
                nameKey="name"
                cx="50%"
                cy="50%"
                innerRadius={48}
                outerRadius={76}
                paddingAngle={2}
              >
                {incomeStatementData.income.map((entry, index) => {
                  const account = accounts.find(a => a.name === entry.name && a.account_type === 'Income');
                  return (
                    <Cell
                      key={entry.name}
                      fill={account?.color || FALLBACK_COLORS_INCOME[index % FALLBACK_COLORS_INCOME.length]}
                      stroke="none"
                    />
                  );
                })}
              </Pie>
              <Tooltip
                formatter={(value: number, name: string) => [
                  `¥${value.toLocaleString('en-US', { minimumFractionDigits: 2 })}`,
                  name,
                ]}
              />
            </PieChart>
          </ResponsiveContainer>
          <div className="flex-1 space-y-1.5 max-h-[160px] overflow-y-auto">
            {incomeStatementData.income
              .sort((a, b) => b.amount - a.amount)
              .map((item, index) => {
                const account = accounts.find(a => a.name === item.name && a.account_type === 'Income');
                const pct = incomeStatementData.totalIncome > 0
                  ? ((item.amount / incomeStatementData.totalIncome) * 100).toFixed(1)
                  : '0';
                return (
                  <div key={item.name} className="flex items-center gap-2 text-xs">
                    <span
                      className="w-2.5 h-2.5 rounded-sm flex-shrink-0"
                      style={{ backgroundColor: account?.color || FALLBACK_COLORS_INCOME[index % FALLBACK_COLORS_INCOME.length] }}
                    />
                    <span className="truncate flex-1">
                      {account?.icon || ''} {item.name}
                    </span>
                    <span className="text-muted-foreground tabular-nums">¥{item.amount.toFixed(0)}</span>
                    <span className="text-muted-foreground/60 w-10 text-right tabular-nums">{pct}%</span>
                  </div>
                );
              })}
          </div>
        </div>
      )}
    </CardContent>
  </Card>
</div>
```

Add fallback color constants at the top of the component (after the interface declarations, around line 31):

```typescript
const FALLBACK_COLORS = ['#EF4444', '#F59E0B', '#10B981', '#3B82F6', '#8B5CF6', '#EC4899', '#06B6D4', '#84CC16'];
const FALLBACK_COLORS_INCOME = ['#10B981', '#06B6D4', '#84CC16', '#3B82F6', '#14B8A6'];
```

- [ ] **Step 2: Commit**

```bash
git add src/pages/ReportsPage.tsx
git commit -m "feat: add expense and income donut charts with account colors"
```

---

### Task 4: Add stacked bar and income-vs-expense trend charts

**Files:**
- Modify: `src/pages/ReportsPage.tsx`

- [ ] **Step 1: Add trend charts below the donut row**

Insert after the donut charts row:

```tsx
{/* Trend Charts Row */}
<div className="grid gap-4 md:grid-cols-2 mb-6">
  {/* Stacked Bar: Monthly Expense Trend */}
  <Card>
    <CardHeader>
      <CardTitle className="text-sm">{t('reports.monthlyExpenseTrend')}</CardTitle>
    </CardHeader>
    <CardContent>
      {monthlyTrendData.length === 0 ? (
        <p className="text-sm text-muted-foreground text-center py-8">{t('reports.noData')}</p>
      ) : (
        <ResponsiveContainer width="100%" height={240}>
          <BarChart data={monthlyTrendData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
            <XAxis
              dataKey="month"
              tick={{ fontSize: 12 }}
              tickFormatter={(v: string) => v.substring(5)}
            />
            <YAxis tick={{ fontSize: 12 }} />
            <Tooltip
              formatter={(value: number, name: string) => [
                `¥${value.toLocaleString('en-US', { minimumFractionDigits: 2 })}`,
                name,
              ]}
            />
            {expenseCategories.map((catName) => {
              const account = accounts.find(a => a.name === catName && a.account_type === 'Expense');
              return (
                <Bar
                  key={catName}
                  dataKey={catName}
                  stackId="expenses"
                  fill={account?.color || '#6B7280'}
                  radius={[]}
                />
              );
            })}
          </BarChart>
        </ResponsiveContainer>
      )}
      {/* Legend */}
      {expenseCategories.length > 0 && (
        <div className="flex flex-wrap gap-3 mt-3 text-xs">
          {expenseCategories.map((catName) => {
            const account = accounts.find(a => a.name === catName && a.account_type === 'Expense');
            return (
              <span key={catName} className="flex items-center gap-1">
                <span
                  className="w-2.5 h-2.5 rounded-sm"
                  style={{ backgroundColor: account?.color || '#6B7280' }}
                />
                {account?.icon || ''} {catName}
              </span>
            );
          })}
        </div>
      )}
    </CardContent>
  </Card>

  {/* Income vs Expense Trend Bar */}
  <Card>
    <CardHeader>
      <CardTitle className="text-sm">{t('reports.monthlyIncomeVsExpense')}</CardTitle>
    </CardHeader>
    <CardContent>
      {monthlyTrendData.length === 0 ? (
        <p className="text-sm text-muted-foreground text-center py-8">{t('reports.noData')}</p>
      ) : (
        <ResponsiveContainer width="100%" height={240}>
          <BarChart data={monthlyTrendData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
            <XAxis
              dataKey="month"
              tick={{ fontSize: 12 }}
              tickFormatter={(v: string) => v.substring(5)}
            />
            <YAxis tick={{ fontSize: 12 }} />
            <Tooltip
              formatter={(value: number) => [
                `¥${value.toLocaleString('en-US', { minimumFractionDigits: 2 })}`,
              ]}
            />
            <Bar dataKey="income" fill="#10B981" radius={[4, 4, 0, 0]} name={t('reports.income')} />
            <Bar dataKey="expenses" fill="#EF4444" radius={[4, 4, 0, 0]} name={t('reports.expenses')} />
            <Legend />
          </BarChart>
        </ResponsiveContainer>
      )}
    </CardContent>
  </Card>
</div>
```

- [ ] **Step 2: Add i18n keys**

In `src/i18n/locales/en.json`:
```json
"expenseBreakdown": "Expense Breakdown",
"incomeBreakdown": "Income Breakdown",
"monthlyExpenseTrend": "Monthly Expense Trend",
"monthlyIncomeVsExpense": "Monthly Income vs Expense",
"noData": "No data for selected period",
```

In `src/i18n/locales/zh.json`:
```json
"expenseBreakdown": "支出分类占比",
"incomeBreakdown": "收入来源占比",
"monthlyExpenseTrend": "月度支出趋势",
"monthlyIncomeVsExpense": "月度收支对比",
"noData": "所选周期暂无数据",
```

- [ ] **Step 3: Remove old chart code**

Remove the old `chartData` useMemo (lines 152-157). Remove the old `BarChart` block (lines 535-548):
```tsx
{incomeStatementData.income.length > 0 || incomeStatementData.expenses.length > 0 ? (
  <div className="mt-6">
    <h3 className="text-lg font-semibold mb-3">{t('reports.incomeVsExpenses')}</h3>
    <ResponsiveContainer width="100%" height={300}>
      <BarChart data={chartData}>
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis dataKey="name" />
        <YAxis />
        <Tooltip />
        <Legend />
        <Bar dataKey="amount" fill="#3b82f6" />
      </BarChart>
    </ResponsiveContainer>
  </div>
) : null}
```

- [ ] **Step 4: Commit**

```bash
git add src/pages/ReportsPage.tsx src/i18n/locales/en.json src/i18n/locales/zh.json
git commit -m "feat: add stacked bar and income-vs-expense trend charts"
```

---

### Task 5: Add transaction count to detail tables and final polish

**Files:**
- Modify: `src/pages/ReportsPage.tsx`
- Modify: `src/i18n/locales/en.json`
- Modify: `src/i18n/locales/zh.json`

- [ ] **Step 1: Add transaction count column**

Add a table header "交易数" / "Count" to both income and expense detail tables. Compute the count from the filtered transactions:

```typescript
const categoryTransactionCount = useMemo(() => {
  const counts: Record<string, number> = {};
  dateFilteredTransactions.forEach((tx: TransactionDto) => {
    const accountIds = new Set(tx.entries.map(e => e.account_id));
    accountIds.forEach(id => {
      const account = accounts.find(a => a.id === id);
      if (account && account.ownership === 'external') {
        counts[account.name] = (counts[account.name] || 0) + 1;
      }
    });
  });
  return counts;
}, [dateFilteredTransactions, accounts]);
```

Note: `dateFilteredTransactions` is inside the `incomeStatementData` useMemo. Extract it to a separate useMemo so it can be reused. Or just compute the count inline.

Actually, let's compute it simply. Add a `count` field to the income/expense maps in `incomeStatementData`. Update the income/expense map to also track transaction counts.

Add to the income/expense table header: `<TableHead className="text-right">{t('reports.transactions')}</TableHead>`

And to each row, add count from `categoryTransactionCount[item.name] || 0`.

Since the refactor is getting complex, keep it simple: add a separate useMemo that computes counts, and reference it in the table rows.

- [ ] **Step 2: Commit**

```bash
git add src/pages/ReportsPage.tsx src/i18n/locales/en.json src/i18n/locales/zh.json
git commit -m "feat: add transaction count to detail tables"
```

---

### Task 6: TypeScript check and visual verification

- [ ] **Step 1: TypeScript type-check**

```bash
npx tsc --noEmit 2>&1
```

Expected: 0 errors in ReportsPage.tsx. Fix any type issues.

- [ ] **Step 2: Run dev server and verify**

```bash
npm run tauri dev 2>&1
```

Navigate to Reports page and verify:
- Period selector changes all charts
- Donut charts show correct category colors
- Stacked bar shows monthly breakdown
- Income vs expense bar shows trends
- Summary cards show correct totals
- Detail tables show transaction counts

- [ ] **Step 3: Commit any fixes**

```bash
git add -A
git commit -m "chore: fix type errors and polish charts"
```
