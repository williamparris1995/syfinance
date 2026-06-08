import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Wallet, CalendarDays, Plus } from 'lucide-react';
import { useNavigate } from '@tanstack/react-router';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { useMemo, useState } from 'react';
import { Bar, BarChart, CartesianGrid, Cell, Legend, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet';
import { EmptyState } from '@/components/EmptyState';
import { SimpleTransactionForm } from '@/components/SimpleTransactionForm';
import { PageShell } from '@/components/patterns/layout/PageShell';
import { PageHeader } from '@/components/patterns/layout/PageHeader';
import { StatCard } from '@/components/patterns/cards/StatCard';
import { listAccountsWithBalances, listAccountsByOwnership } from '@/lib/tauri/account';
import { getDashboardSummary, getMonthlyTrend } from '@/lib/tauri/report';
import { getUpcomingPayments } from '@/lib/tauri/debt';
import { listHoldings } from '@/lib/tauri/holding';
import { calculateTotalBalanceInCNY, formatCurrencyWithDto, formatCurrency, getCurrencySymbol } from '@/lib/currency';
import { subtractDecimals, safeParseDecimal } from '@/lib/decimal';
import { useCurrencies } from '@/hooks/useCurrency';
export function HomePage() {
  const navigate = useNavigate();
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const [isSheetOpen, setIsSheetOpen] = useState(false);
  type DateRangePreset = 'month' | 'quarter' | 'year' | 'custom';

  const [dateRangePreset, setDateRangePreset] = useState<DateRangePreset>('month');
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');

  const { data: accounts = [], isLoading: accountsLoading } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccountsWithBalances,
  });

  const { data: currencies = [] } = useCurrencies();

  const { data: externalAccounts = [] } = useQuery({
    queryKey: ['accounts', 'external'],
    queryFn: () => listAccountsByOwnership('external'),
  });

  const { data: holdings = [] } = useQuery({ queryKey: ['holdings'], queryFn: listHoldings });

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

  // Dashboard summary from server-side aggregation
  const { data: dashboardSummary, isLoading: isDashboardLoading } = useQuery({
    queryKey: ['dashboard-summary', dateRange.start, dateRange.end],
    queryFn: () => getDashboardSummary(dateRange.start, dateRange.end),
  });

  // Calculate total balance from all accounts (converted to CNY)
  const totalBalance = calculateTotalBalanceInCNY(
    accounts.map(a => ({
      balance: Number(a.current_balance),
      currency_code: a.currency_code,
    })),
    currencies
  );

  const holdingsSummary = useMemo(() => {
    const totalMv = holdings.reduce((s, h) => s + (h.market_value || 0), 0);
    const totalPnl = holdings.reduce((s, h) => s + (h.unrealized_pnl || 0), 0);
    return { totalMv, totalPnl, count: holdings.length };
  }, [holdings]);

  const FALLBACK_COLORS = ['#EF4444', '#F59E0B', '#10B981', '#3B82F6', '#8B5CF6', '#EC4899', '#06B6D4', '#84CC16'];
  const FALLBACK_COLORS_INCOME = ['#10B981', '#06B6D4', '#84CC16', '#3B82F6', '#14B8A6'];

  // Use server-side aggregated summary data
  const monthlyIncome = parseFloat(dashboardSummary?.total_income ?? '0');
  const monthlyExpenses = parseFloat(dashboardSummary?.total_expenses ?? '0');
  const monthlySavings = parseFloat(subtractDecimals(
    safeParseDecimal(dashboardSummary?.total_income),
    safeParseDecimal(dashboardSummary?.total_expenses),
  ));

  const incomeByCategory = (dashboardSummary?.income_by_category ?? []).map(item => ({
    name: item.account_name,
    amount: parseFloat(item.amount),
  }));

  const expenseByCategory = (dashboardSummary?.expense_by_category ?? []).map(item => ({
    name: item.account_name,
    amount: parseFloat(item.amount),
  }));

  const ownAccountBalances = useMemo(() =>
    accounts.filter(a => (a.ownership === 'own' || a.ownership === 'liability') && a.current_balance !== 0)
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

  // Monthly trend data from server-side aggregation
  const { data: monthlyTrendRaw = [] } = useQuery({
    queryKey: ['monthly-trend', dateRange.start, dateRange.end],
    queryFn: () => getMonthlyTrend(dateRange.start, dateRange.end),
  });

  const chartData = useMemo(() =>
    monthlyTrendRaw.map(m => ({
      month: m.month,
      income: parseFloat(m.income),
      expenses: parseFloat(m.expenses),
      ...Object.fromEntries(
        Object.entries(m.expense_categories).map(([k, v]) => [k, parseFloat(v)])
      ),
    })),
  [monthlyTrendRaw]);

  const expenseCategories = useMemo(() => {
    const cats = new Set<string>();
    monthlyTrendRaw.forEach((m) => {
      Object.keys(m.expense_categories).forEach(c => cats.add(c));
    });
    return Array.from(cats);
  }, [monthlyTrendRaw]);

  const isLoading = accountsLoading || isDashboardLoading;

  const cnyDto = { id: '', code: 'CNY' as const, symbol: getCurrencySymbol('CNY'), name: t('common.cny'), exchange_rate: '1', is_active: true, updated_at: '' };

  return (
    <PageShell>
      <PageHeader
        title={t('dashboard.title')}
        subtitle={new Date().toLocaleDateString('zh-CN', { year: 'numeric', month: 'long', day: 'numeric', weekday: 'long' })}
        actions={
          <Button onClick={() => setIsSheetOpen(true)}>
            <Plus className="mr-1.5 h-4 w-4" />
            {t('transactions.recordTransaction')}
          </Button>
        }
      />

      {/* Period Selector */}
      <div className="rounded-[14px] border border-border bg-card p-5 mb-7">
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
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <div className="text-neutral-500">{t('dashboard.loadingDashboard')}</div>
        </div>
      ) : (
        <>
          {accounts.length > 0 && (
            <>
              <div className="grid grid-cols-2 lg:grid-cols-5 gap-3.5 mb-7">
                <StatCard label={t('dashboard.totalBalance')} value={formatCurrencyWithDto(totalBalance, cnyDto)} tagVariant="positive" />
                <StatCard label={t('dashboard.monthlyIncome')} value={`+${monthlyIncome.toLocaleString('en-US', { style: 'currency', currency: 'CNY', currencyDisplay: 'narrowSymbol' })}`} tagVariant="positive" />
                <StatCard label={t('dashboard.monthlyExpenses')} value={`-${monthlyExpenses.toLocaleString('en-US', { style: 'currency', currency: 'CNY', currencyDisplay: 'narrowSymbol' })}`} tagVariant="negative" />
                <StatCard label={t('dashboard.monthlySavings')} value={`${monthlySavings >= 0 ? '+' : ''}${monthlySavings.toLocaleString('en-US', { style: 'currency', currency: 'CNY', currencyDisplay: 'narrowSymbol' })}`} tagVariant={monthlySavings >= 0 ? 'positive' : 'negative'} />
                <StatCard label={t('dashboard.portfolioValue')} value={holdingsSummary.totalMv.toLocaleString('en-US', { style: 'currency', currency: 'CNY', currencyDisplay: 'narrowSymbol' })} tag={`${holdingsSummary.count} ${t('holding.positions')}`} />
              </div>
            </>
          )}

          {/* Account Balances + Upcoming Payments */}
          {accounts.length > 0 && (
            <div className="grid gap-4 md:grid-cols-2 mb-7">
              {/* Current Balance Chart */}
              <div className="rounded-[14px] border border-border bg-card p-5">
                <h3 className="text-sm font-medium mb-3">{t('accounts.currentBalance')}</h3>
                {ownAccountBalances.length === 0 ? (
                  <p className="text-sm text-muted-foreground">{t('dashboard.noAccountsDesc')}</p>
                ) : (
                  <ResponsiveContainer width="100%" height={220}>
                    <BarChart data={ownAccountBalances.map(a => ({ name: a.name, balance: a.current_balance }))} margin={{ top: 5, right: 20, left: 20, bottom: 5 }}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="name" tick={{ fontSize: 12 }} />
                      <YAxis tick={{ fontSize: 12 }} tickFormatter={(v) => `${getCurrencySymbol('CNY')}${(v / 1000).toFixed(0)}k`} />
                      <Tooltip formatter={(v) => `${getCurrencySymbol('CNY')}${Number(v).toLocaleString('en-US', { minimumFractionDigits: 2 })}`} />
                      <Bar dataKey="balance" name={t('accounts.currentBalance')} radius={[4, 4, 0, 0]}>
                        {ownAccountBalances.map((a, i) => (
                          <Cell key={i} fill={a.current_balance >= 0 ? '#10B981' : '#EF4444'} />
                        ))}
                      </Bar>
                    </BarChart>
                  </ResponsiveContainer>
                )}
              </div>

              {/* Balance Change Chart */}
              <div className="rounded-[14px] border border-border bg-card p-5">
                <h3 className="text-sm font-medium mb-3">{t('dashboard.change')}</h3>
                {ownAccountBalances.length === 0 ? (
                  <p className="text-sm text-muted-foreground">{t('dashboard.noAccountsDesc')}</p>
                ) : (
                  <ResponsiveContainer width="100%" height={220}>
                    <BarChart data={ownAccountBalances.map(a => ({ name: a.name, change: a.current_balance - a.initial_balance }))} margin={{ top: 5, right: 20, left: 20, bottom: 5 }}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="name" tick={{ fontSize: 12 }} />
                      <YAxis tick={{ fontSize: 12 }} tickFormatter={(v) => `${getCurrencySymbol('CNY')}${(v / 1000).toFixed(0)}k`} />
                      <Tooltip formatter={(v) => `${getCurrencySymbol('CNY')}${Number(v).toLocaleString('en-US', { minimumFractionDigits: 2 })}`} />
                      <Bar dataKey="change" name={t('dashboard.change')} radius={[4, 4, 0, 0]}>
                        {ownAccountBalances.map((a, i) => {
                          const change = a.current_balance - a.initial_balance;
                          return <Cell key={i} fill={change >= 0 ? '#3B82F6' : '#F59E0B'} />;
                        })}
                      </Bar>
                    </BarChart>
                  </ResponsiveContainer>
                )}
              </div>

              {/* Upcoming Debt Payments */}
              <div className="rounded-[14px] border border-border bg-card p-5">
                <h3 className="text-sm font-medium mb-3">{t('dashboard.upcomingDebtPayments')}</h3>
                <div className="space-y-2">
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
                          {formatCurrency(parseFloat(p.amount), 'CNY')}
                        </span>
                      </div>
                    ))
                  )}
                </div>
              </div>
            </div>
          )}

          {/* Charts Section */}
          {accounts.length > 0 && (expenseByCategory.length > 0 || incomeByCategory.length > 0) && (
            <div className="grid gap-4 md:grid-cols-2 mb-7">
              {/* Expense Donut */}
              <div className="rounded-[14px] border border-border bg-card p-5">
                <h3 className="text-sm font-medium mb-3">{t('reports.expenseBreakdown')}</h3>
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
                            `${getCurrencySymbol('CNY')}${Number(value).toLocaleString('en-US', { minimumFractionDigits: 2 })}`,
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
                              <span className="text-muted-foreground tabular-nums">{getCurrencySymbol('CNY')}{item.amount.toFixed(0)}</span>
                              <span className="text-muted-foreground/60 w-10 text-right tabular-nums">{pct}%</span>
                            </div>
                          );
                        })}
                    </div>
                  </div>
                )}
              </div>

              {/* Income Donut */}
              <div className="rounded-[14px] border border-border bg-card p-5">
                <h3 className="text-sm font-medium mb-3">{t('reports.incomeBreakdown')}</h3>
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
                            `${getCurrencySymbol('CNY')}${Number(value).toLocaleString('en-US', { minimumFractionDigits: 2 })}`,
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
                              <span className="text-muted-foreground tabular-nums">{getCurrencySymbol('CNY')}{item.amount.toFixed(0)}</span>
                              <span className="text-muted-foreground/60 w-10 text-right tabular-nums">{pct}%</span>
                            </div>
                          );
                        })}
                    </div>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Monthly Trend Charts */}
          {accounts.length > 0 && chartData.length > 0 && (
            <div className="grid gap-4 md:grid-cols-2 mb-7">
              {/* Stacked Bar: Monthly Expense Trend */}
              <div className="rounded-[14px] border border-border bg-card p-5">
                <h3 className="text-sm font-medium mb-3">{t('reports.monthlyExpenseTrend')}</h3>
                {expenseCategories.length === 0 ? (
                  <p className="text-sm text-muted-foreground text-center py-8">{t('reports.noData')}</p>
                ) : (
                  <>
                    <ResponsiveContainer width="100%" height={220}>
                      <BarChart data={chartData}>
                        <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
                        <XAxis dataKey="month" tick={{ fontSize: 11 }} tickFormatter={(v: string) => v.substring(5)} />
                        <YAxis tick={{ fontSize: 11 }} />
                        <Tooltip formatter={(value, name) => [
                          `${getCurrencySymbol('CNY')}${Number(value).toLocaleString('en-US', { minimumFractionDigits: 2 })}`, name,
                        ]} />
                        {expenseCategories.map((catName) => {
                          const account = accounts.find((a) => a.name === catName && a.account_type === 'Expense');
                          return (
                            <Bar key={catName} dataKey={catName} stackId="e" fill={account?.color || '#6B7280'} />
                          );
                        })}
                      </BarChart>
                    </ResponsiveContainer>
                    <div className="flex flex-wrap gap-3 mt-2 text-xs">
                      {expenseCategories.map((catName) => {
                        const account = accounts.find((a) => a.name === catName && a.account_type === 'Expense');
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
              </div>

              {/* Income vs Expense Bar */}
              <div className="rounded-[14px] border border-border bg-card p-5">
                <h3 className="text-sm font-medium mb-3">{t('reports.monthlyIncomeVsExpense')}</h3>
                <ResponsiveContainer width="100%" height={220}>
                  <BarChart data={chartData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
                    <XAxis dataKey="month" tick={{ fontSize: 11 }} tickFormatter={(v: string) => v.substring(5)} />
                    <YAxis tick={{ fontSize: 11 }} />
                    <Tooltip formatter={(value) => [
                      `${getCurrencySymbol('CNY')}${Number(value).toLocaleString('en-US', { minimumFractionDigits: 2 })}`,
                    ]} />
                    <Bar dataKey="income" fill="#10B981" radius={[4, 4, 0, 0]} name={t('reports.income')} />
                    <Bar dataKey="expenses" fill="#EF4444" radius={[4, 4, 0, 0]} name={t('reports.expenses')} />
                    <Legend />
                  </BarChart>
                </ResponsiveContainer>
              </div>
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

      {/* Quick Add Transaction FAB */}
      <Button
        className="fixed bottom-6 right-6 h-14 w-14 rounded-full shadow-lg z-50"
        size="icon"
        onClick={() => setIsSheetOpen(true)}
      >
        <Plus className="h-6 w-6" />
      </Button>

      {/* Quick Add Transaction Sheet */}
      <Sheet open={isSheetOpen} onOpenChange={setIsSheetOpen}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{t('transactions.recordTransaction')}</SheetTitle>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto -mx-4 px-4">
            <SimpleTransactionForm
              accounts={accounts}
              externalAccounts={externalAccounts}
              onSubmit={async () => {
                setIsSheetOpen(false);
                queryClient.invalidateQueries({ queryKey: ['transactions'] });
                queryClient.invalidateQueries({ queryKey: ['accounts'] });
                toast.success(t('transactions.recorded'));
              }}
              onCancel={() => setIsSheetOpen(false)}
            />
          </div>
        </SheetContent>
      </Sheet>
    </PageShell>
  );
}
