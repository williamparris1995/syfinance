import { useQuery } from '@tanstack/react-query';
import { ArrowUpRight, ArrowDownRight, Wallet, TrendingUp, Landmark, CalendarDays } from 'lucide-react';
import { useNavigate } from '@tanstack/react-router';
import { useTranslation } from 'react-i18next';
import { useMemo, useState } from 'react';
import { Bar, BarChart, CartesianGrid, Cell, Legend, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';

import { EmptyState } from '@/components/EmptyState';
import { listAccounts } from '@/lib/tauri/account';
import { listTransactions } from '@/lib/tauri/transaction';
import { listDebts, getUpcomingPayments } from '@/lib/tauri/debt';

export function HomePage() {
  const navigate = useNavigate();
  const { t } = useTranslation();

  type DateRangePreset = 'month' | 'quarter' | 'year' | 'custom';

  const [dateRangePreset, setDateRangePreset] = useState<DateRangePreset>('month');
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');

  const { data: accounts = [], isLoading: accountsLoading } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
  });

  const { data: transactions = [], isLoading: transactionsLoading } = useQuery({
    queryKey: ['transactions'],
    queryFn: listTransactions,
  });

  const { data: debts = [] } = useQuery({
    queryKey: ['debts'],
    queryFn: listDebts,
  });

  const { data: upcomingDebts = [] } = useQuery({
    queryKey: ['upcoming-payments'],
    queryFn: () => getUpcomingPayments(30),
  });

  const dateRange = useMemo(() => {
    if (dateRangePreset === 'custom') {
      return { start: startDate, end: endDate };
    }
    const now = new Date();
    const start = new Date();
    const end = new Date();
    switch (dateRangePreset) {
      case 'month':
        start.setDate(1);
        start.setHours(0, 0, 0, 0);
        break;
      case 'quarter':
        start.setMonth(Math.floor(now.getMonth() / 3) * 3, 1);
        start.setHours(0, 0, 0, 0);
        break;
      case 'year':
        start.setMonth(0, 1);
        start.setHours(0, 0, 0, 0);
        break;
    }
    return {
      start: start.toISOString().split('T')[0],
      end: end.toISOString().split('T')[0],
    };
  }, [dateRangePreset, startDate, endDate]);

  // Calculate total balance from all accounts
  const totalBalance = accounts.reduce((sum, account) => sum + Number(account.current_balance), 0);

  const FALLBACK_COLORS = ['#EF4444', '#F59E0B', '#10B981', '#3B82F6', '#8B5CF6', '#EC4899', '#06B6D4', '#84CC16'];
  const FALLBACK_COLORS_INCOME = ['#10B981', '#06B6D4', '#84CC16', '#3B82F6', '#14B8A6'];

  // Calculate income and expenses from transactions (filtered by date range)
  // Uses account-based lookup: Income/Expense are determined by the linked account's type
  const { monthlyIncome, monthlyExpenses, incomeByCategory, expenseByCategory } = useMemo(() => {
    let income = 0;
    let expenses = 0;
    const incomeMap = new Map<string, number>();
    const expenseMap = new Map<string, number>();

    transactions.forEach((transaction: any) => {
      const txDate = transaction.transaction_date;
      if (txDate >= dateRange.start && txDate <= dateRange.end) {
        transaction.entries.forEach((entry: any) => {
          const account = entry.account_id ? accounts.find((a: any) => a.id === entry.account_id) : null;
          if (!account) return;
          if (entry.debit_amount && account.account_type === 'Expense') {
            const amount = parseFloat(entry.debit_amount);
            expenses += amount;
            expenseMap.set(account.name, (expenseMap.get(account.name) || 0) + amount);
          }
          if (entry.credit_amount && account.account_type === 'Income') {
            const amount = parseFloat(entry.credit_amount);
            income += amount;
            incomeMap.set(account.name, (incomeMap.get(account.name) || 0) + amount);
          }
        });
      }
    });

    return {
      monthlyIncome: income,
      monthlyExpenses: expenses,
      incomeByCategory: Array.from(incomeMap.entries()).map(([name, amount]) => ({ name, amount })),
      expenseByCategory: Array.from(expenseMap.entries()).map(([name, amount]) => ({ name, amount })),
    };
  }, [transactions, accounts, dateRange]);

  const monthlySavings = monthlyIncome - monthlyExpenses;

  const debtSummary = useMemo(() => ({
    totalRemaining: debts.reduce((s, d) => s + parseFloat(d.remaining_principal), 0),
    activeCount: debts.filter(d => parseFloat(d.remaining_principal) > 0).length,
  }), [debts]);

  const ownAccountBalances = useMemo(() =>
    accounts.filter(a => a.ownership === 'own' && a.current_balance !== 0)
      .sort((a, b) => b.current_balance - a.current_balance),
  [accounts]);

  const upcomingPayments = useMemo(() =>
    upcomingDebts.flatMap(d =>
      d.payment_schedule.filter(p => !p.paid).map(p => ({
        account_name: d.account_name,
        counterparty: d.counterparty,
        payment_date: p.payment_date,
        amount: p.total_amount,
        currency_code: d.currency_code,
      }))
    ).sort((a, b) => new Date(a.payment_date).getTime() - new Date(b.payment_date).getTime())
    .slice(0, 5),
  [upcomingDebts]);

  const monthlyTrendData = useMemo(() => {
    const months: Record<string, any> = {};

    // Build month list from dateRange
    const startDate2 = new Date(dateRange.start);
    const endDate2 = new Date(dateRange.end);
    for (let d = new Date(startDate2.getFullYear(), startDate2.getMonth(), 1);
         d <= endDate2;
         d.setMonth(d.getMonth() + 1)) {
      const month = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
      months[month] = { month, income: 0, expenses: 0 };
    }

    transactions.forEach((tx: any) => {
      const month = tx.transaction_date?.substring(0, 7);
      if (!month || !months[month]) return;

      tx.entries.forEach((entry: any) => {
        const account = accounts.find((a: any) => a.id === entry.account_id);
        if (!account || account.ownership !== 'external') return;

        const amount = entry.debit_amount ? parseFloat(entry.debit_amount)
          : entry.credit_amount ? parseFloat(entry.credit_amount) : 0;

        if (account.account_type === 'Expense') {
          months[month][account.name] = ((months[month][account.name] as number) || 0) + amount;
          months[month].expenses += amount;
        } else if (account.account_type === 'Income') {
          months[month].income += amount;
        }
      });
    });

    return Object.values(months).sort((a: any, b: any) => a.month.localeCompare(b.month));
  }, [transactions, accounts, dateRange]);

  const expenseCategories = useMemo(() => {
    const cats = new Set<string>();
    monthlyTrendData.forEach((m: any) => {
      accounts.filter((a: any) => a.account_type === 'Expense' && a.ownership === 'external')
        .forEach((a: any) => { if (m[a.name] !== undefined) cats.add(a.name); });
    });
    return Array.from(cats);
  }, [monthlyTrendData, accounts]);

  const isLoading = accountsLoading || transactionsLoading;

  return (
    <div className="space-y-6 p-6">
      <div className="flex items-center justify-between">
        <h2 className="text-3xl font-bold">{t('dashboard.title')}</h2>
      </div>

      {/* Period Selector */}
      <Card>
        <CardContent className="pt-4">
          <div className="flex flex-wrap gap-2">
            <Button
              variant={dateRangePreset === 'month' ? 'default' : 'outline'}
              size="sm"
              onClick={() => setDateRangePreset('month')}
            >
              {t('reports.thisMonth')}
            </Button>
            <Button
              variant={dateRangePreset === 'quarter' ? 'default' : 'outline'}
              size="sm"
              onClick={() => setDateRangePreset('quarter')}
            >
              {t('reports.thisQuarter')}
            </Button>
            <Button
              variant={dateRangePreset === 'year' ? 'default' : 'outline'}
              size="sm"
              onClick={() => setDateRangePreset('year')}
            >
              {t('reports.thisYear')}
            </Button>
            <Button
              variant={dateRangePreset === 'custom' ? 'default' : 'outline'}
              size="sm"
              onClick={() => setDateRangePreset('custom')}
            >
              {t('reports.custom')}
            </Button>
            {dateRangePreset === 'custom' && (
              <div className="flex items-center gap-2 ml-2">
                <Input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} className="w-36 h-8 text-xs" />
                <span className="text-xs text-muted-foreground">—</span>
                <Input type="date" value={endDate} onChange={(e) => setEndDate(e.target.value)} className="w-36 h-8 text-xs" />
              </div>
            )}
          </div>
          <div className="mt-2 text-xs text-muted-foreground">
            {dateRange.start} — {dateRange.end}
          </div>
        </CardContent>
      </Card>

      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <div className="text-neutral-500">{t('dashboard.loadingDashboard')}</div>
        </div>
      ) : (
        <>
          {accounts.length > 0 && (
            <>
              <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-5">
                {/* Total Balance */}
                <Card className="bg-gradient-to-br from-card to-muted/20 border-border/50 shadow-sm">
                  <CardContent className="pt-4">
                    <div className="flex items-center gap-3 mb-3">
                      <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-primary/10">
                        <Wallet className="h-4 w-4 text-primary" />
                      </div>
                      <span className="text-xs font-medium text-muted-foreground">
                        {t('dashboard.totalBalance')}
                      </span>
                    </div>
                    <div className="text-2xl font-bold tracking-tight">
                      {totalBalance.toLocaleString('en-US', { style: 'currency', currency: 'CNY', currencyDisplay: 'narrowSymbol' })}
                    </div>
                  </CardContent>
                </Card>

                {/* Monthly Income */}
                <Card className="bg-gradient-to-br from-emerald-50/50 to-card border-emerald-200/50 shadow-sm dark:from-emerald-950/20 dark:to-card dark:border-emerald-800/30">
                  <CardContent className="pt-4">
                    <div className="flex items-center gap-3 mb-3">
                      <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-emerald-100 dark:bg-emerald-900/30">
                        <ArrowUpRight className="h-4 w-4 text-emerald-600 dark:text-emerald-400" />
                      </div>
                      <span className="text-xs font-medium text-muted-foreground">
                        {t('dashboard.monthlyIncome')}
                      </span>
                    </div>
                    <div className="text-2xl font-bold tracking-tight text-emerald-600 dark:text-emerald-400">
                      +{monthlyIncome.toLocaleString('en-US', { style: 'currency', currency: 'CNY', currencyDisplay: 'narrowSymbol' })}
                    </div>
                  </CardContent>
                </Card>

                {/* Monthly Expenses */}
                <Card className="bg-gradient-to-br from-red-50/50 to-card border-red-200/50 shadow-sm dark:from-red-950/20 dark:to-card dark:border-red-800/30">
                  <CardContent className="pt-4">
                    <div className="flex items-center gap-3 mb-3">
                      <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-red-100 dark:bg-red-900/30">
                        <ArrowDownRight className="h-4 w-4 text-red-600 dark:text-red-400" />
                      </div>
                      <span className="text-xs font-medium text-muted-foreground">
                        {t('dashboard.monthlyExpenses')}
                      </span>
                    </div>
                    <div className="text-2xl font-bold tracking-tight text-red-600 dark:text-red-400">
                      -{monthlyExpenses.toLocaleString('en-US', { style: 'currency', currency: 'CNY', currencyDisplay: 'narrowSymbol' })}
                    </div>
                  </CardContent>
                </Card>

                {/* Monthly Savings */}
                <Card className="bg-gradient-to-br from-blue-50/50 to-card border-blue-200/50 shadow-sm dark:from-blue-950/20 dark:to-card dark:border-blue-800/30">
                  <CardContent className="pt-4">
                    <div className="flex items-center gap-3 mb-3">
                      <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-blue-100 dark:bg-blue-900/30">
                        <TrendingUp className="h-4 w-4 text-blue-600 dark:text-blue-400" />
                      </div>
                      <span className="text-xs font-medium text-muted-foreground">
                        {t('dashboard.monthlySavings')}
                      </span>
                    </div>
                    <div className={`text-2xl font-bold tracking-tight ${monthlySavings >= 0 ? 'text-emerald-600 dark:text-emerald-400' : 'text-red-600 dark:text-red-400'}`}>
                      {monthlySavings >= 0 ? '+' : ''}{monthlySavings.toLocaleString('en-US', { style: 'currency', currency: 'CNY', currencyDisplay: 'narrowSymbol' })}
                    </div>
                  </CardContent>
                </Card>

                {/* Total Debt */}
                <Card className="bg-gradient-to-br from-red-50/50 to-card dark:from-red-950/20 dark:to-card border-red-200/50 dark:border-red-800/30">
                  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-sm font-medium text-muted-foreground">{t('dashboard.totalDebt')}</CardTitle>
                    <Landmark className="h-4 w-4 text-red-500" />
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold tracking-tight text-red-600 dark:text-red-400">
                      ¥{debtSummary.totalRemaining.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                    </div>
                    <p className="text-xs text-muted-foreground mt-1">
                      {t('dashboard.activeDebts')}: {debtSummary.activeCount}
                    </p>
                  </CardContent>
                </Card>
              </div>
            </>
          )}

          {/* Account Balances + Upcoming Payments */}
          {accounts.length > 0 && (
            <div className="grid gap-4 md:grid-cols-2">
              {/* Account Balances */}
              <Card>
                <CardHeader className="pb-2">
                  <CardTitle className="text-sm font-medium">{t('dashboard.perAccountBalances')}</CardTitle>
                </CardHeader>
                <CardContent className="space-y-2">
                  {ownAccountBalances.length === 0 ? (
                    <p className="text-sm text-muted-foreground">{t('dashboard.noAccountsDesc')}</p>
                  ) : (
                    ownAccountBalances.map((acc) => (
                      <div key={acc.id} className="flex items-center justify-between">
                        <div className="flex items-center gap-2">
                          <span>{acc.icon}</span>
                          <span className="text-sm font-medium">{acc.name}</span>
                          <Badge variant="outline" className="text-xs">{acc.account_type}</Badge>
                        </div>
                        <span className={`text-sm font-semibold ${acc.current_balance >= 0 ? 'text-emerald-600' : 'text-red-600'}`}>
                          {acc.current_balance.toLocaleString('en-US', { style: 'currency', currency: acc.currency_code || 'CNY', currencyDisplay: 'narrowSymbol' })}
                        </span>
                      </div>
                    ))
                  )}
                </CardContent>
              </Card>

              {/* Upcoming Debt Payments */}
              <Card>
                <CardHeader className="pb-2">
                  <CardTitle className="text-sm font-medium">{t('dashboard.upcomingDebtPayments')}</CardTitle>
                </CardHeader>
                <CardContent className="space-y-2">
                  {upcomingPayments.length === 0 ? (
                    <p className="text-sm text-muted-foreground">{t('dashboard.noUpcomingPayments')}</p>
                  ) : (
                    upcomingPayments.map((p, i) => (
                      <div key={i} className="flex items-center justify-between">
                        <div className="flex items-center gap-2">
                          <CalendarDays className="h-4 w-4 text-blue-500" />
                          <div>
                            <div className="text-sm font-medium">{p.account_name}</div>
                            <div className="text-xs text-muted-foreground">{new Date(p.payment_date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}</div>
                          </div>
                        </div>
                        <span className="text-sm font-semibold">
                          ¥{parseFloat(p.amount).toLocaleString('en-US', { minimumFractionDigits: 2 })}
                        </span>
                      </div>
                    ))
                  )}
                </CardContent>
              </Card>
            </div>
          )}

          {/* Charts Section */}
          {accounts.length > 0 && (expenseByCategory.length > 0 || incomeByCategory.length > 0) && (
            <div className="grid gap-4 md:grid-cols-2">
              {/* Expense Donut */}
              <Card>
                <CardHeader>
                  <CardTitle className="text-sm">{t('reports.expenseBreakdown')}</CardTitle>
                </CardHeader>
                <CardContent>
                  {expenseByCategory.length === 0 ? (
                    <p className="text-sm text-muted-foreground text-center py-8">{t('reports.noExpenses')}</p>
                  ) : (
                    <div className="flex flex-col items-center gap-3">
                      <ResponsiveContainer width={180} height={180}>
                        <PieChart>
                          <Pie
                            data={expenseByCategory}
                            dataKey="amount"
                            nameKey="name"
                            cx="50%"
                            cy="50%"
                            innerRadius={45}
                            outerRadius={70}
                            paddingAngle={2}
                          >
                            {expenseByCategory.map((entry, index) => {
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
                            formatter={(value, name) => [
                              `¥${Number(value).toLocaleString('en-US', { minimumFractionDigits: 2 })}`,
                              name,
                            ]}
                          />
                        </PieChart>
                      </ResponsiveContainer>
                      <div className="w-full space-y-1.5">
                        {expenseByCategory
                          .sort((a, b) => b.amount - a.amount)
                          .slice(0, 6)
                          .map((item, index) => {
                            const account = accounts.find(a => a.name === item.name && a.account_type === 'Expense');
                            const pct = monthlyExpenses > 0
                              ? ((item.amount / monthlyExpenses) * 100).toFixed(1)
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
                  {incomeByCategory.length === 0 ? (
                    <p className="text-sm text-muted-foreground text-center py-8">{t('reports.noIncome')}</p>
                  ) : (
                    <div className="flex flex-col items-center gap-3">
                      <ResponsiveContainer width={180} height={180}>
                        <PieChart>
                          <Pie
                            data={incomeByCategory}
                            dataKey="amount"
                            nameKey="name"
                            cx="50%"
                            cy="50%"
                            innerRadius={45}
                            outerRadius={70}
                            paddingAngle={2}
                          >
                            {incomeByCategory.map((entry, index) => {
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
                            formatter={(value, name) => [
                              `¥${Number(value).toLocaleString('en-US', { minimumFractionDigits: 2 })}`,
                              name,
                            ]}
                          />
                        </PieChart>
                      </ResponsiveContainer>
                      <div className="w-full space-y-1.5">
                        {incomeByCategory
                          .sort((a, b) => b.amount - a.amount)
                          .slice(0, 6)
                          .map((item, index) => {
                            const account = accounts.find(a => a.name === item.name && a.account_type === 'Income');
                            const pct = monthlyIncome > 0
                              ? ((item.amount / monthlyIncome) * 100).toFixed(1)
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
          )}

          {/* Monthly Trend Charts */}
          {accounts.length > 0 && monthlyTrendData.length > 0 && (
            <div className="grid gap-4 md:grid-cols-2">
              {/* Stacked Bar: Monthly Expense Trend */}
              <Card>
                <CardHeader>
                  <CardTitle className="text-sm">{t('reports.monthlyExpenseTrend')}</CardTitle>
                </CardHeader>
                <CardContent>
                  {expenseCategories.length === 0 ? (
                    <p className="text-sm text-muted-foreground text-center py-8">{t('reports.noData')}</p>
                  ) : (
                    <>
                      <ResponsiveContainer width="100%" height={220}>
                        <BarChart data={monthlyTrendData}>
                          <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
                          <XAxis dataKey="month" tick={{ fontSize: 11 }} tickFormatter={(v: string) => v.substring(5)} />
                          <YAxis tick={{ fontSize: 11 }} />
                          <Tooltip formatter={(value, name) => [
                            `¥${Number(value).toLocaleString('en-US', { minimumFractionDigits: 2 })}`, name,
                          ]} />
                          {expenseCategories.map((catName) => {
                            const account = accounts.find((a: any) => a.name === catName && a.account_type === 'Expense');
                            return (
                              <Bar key={catName} dataKey={catName} stackId="e" fill={account?.color || '#6B7280'} />
                            );
                          })}
                        </BarChart>
                      </ResponsiveContainer>
                      <div className="flex flex-wrap gap-3 mt-2 text-xs">
                        {expenseCategories.map((catName) => {
                          const account = accounts.find((a: any) => a.name === catName && a.account_type === 'Expense');
                          return (
                            <span key={catName} className="flex items-center gap-1">
                              <span className="w-2 h-2 rounded-sm" style={{ backgroundColor: account?.color || '#6B7280' }} />
                              {account?.icon || ''} {catName}
                            </span>
                          );
                        })}
                      </div>
                    </>
                  )}
                </CardContent>
              </Card>

              {/* Income vs Expense Bar */}
              <Card>
                <CardHeader>
                  <CardTitle className="text-sm">{t('reports.monthlyIncomeVsExpense')}</CardTitle>
                </CardHeader>
                <CardContent>
                  <ResponsiveContainer width="100%" height={220}>
                    <BarChart data={monthlyTrendData}>
                      <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
                      <XAxis dataKey="month" tick={{ fontSize: 11 }} tickFormatter={(v: string) => v.substring(5)} />
                      <YAxis tick={{ fontSize: 11 }} />
                      <Tooltip formatter={(value) => [
                        `¥${Number(value).toLocaleString('en-US', { minimumFractionDigits: 2 })}`,
                      ]} />
                      <Bar dataKey="income" fill="#10B981" radius={[4, 4, 0, 0]} name={t('reports.income')} />
                      <Bar dataKey="expenses" fill="#EF4444" radius={[4, 4, 0, 0]} name={t('reports.expenses')} />
                      <Legend />
                    </BarChart>
                  </ResponsiveContainer>
                </CardContent>
              </Card>
            </div>
          )}

          {/* Empty State for New Users */}
          {accounts.length === 0 && (
            <EmptyState
              icon={Wallet}
              title={t('dashboard.noAccounts')}
              description={t('dashboard.noAccountsDesc')}
              action={{
                label: t('dashboard.createAccount'),
                onClick: () => navigate({ to: '/accounts' }),
              }}
            />
          )}
        </>
      )}
    </div>
  );
}
