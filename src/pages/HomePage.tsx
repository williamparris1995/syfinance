import { useQuery } from '@tanstack/react-query';
import { ArrowUpRight, ArrowDownRight, Wallet, TrendingUp, Receipt, CreditCard, BarChart3, Plus } from 'lucide-react';
import { useNavigate } from '@tanstack/react-router';
import { useTranslation } from 'react-i18next';
import { useMemo } from 'react';
import { Bar, BarChart, CartesianGrid, Cell, Legend, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { QuickActions } from '@/components/QuickActions';
import { EmptyState } from '@/components/EmptyState';
import { listAccounts } from '@/lib/tauri/account';
import { listTransactions } from '@/lib/tauri/transaction';

export function HomePage() {
  const navigate = useNavigate();
  const { t } = useTranslation();
  
  const { data: accounts = [], isLoading: accountsLoading } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
  });

  const { data: transactions = [], isLoading: transactionsLoading } = useQuery({
    queryKey: ['transactions'],
    queryFn: listTransactions,
  });

  // Calculate total balance from all accounts
  const totalBalance = accounts.reduce((sum, account) => sum + Number(account.balance), 0);

  const FALLBACK_COLORS = ['#EF4444', '#F59E0B', '#10B981', '#3B82F6', '#8B5CF6', '#EC4899', '#06B6D4', '#84CC16'];
  const FALLBACK_COLORS_INCOME = ['#10B981', '#06B6D4', '#84CC16', '#3B82F6', '#14B8A6'];

  // Calculate income and expenses from transactions (current month)
  // Uses account-based lookup: Income/Expense are determined by the linked account's type
  const { monthlyIncome, monthlyExpenses, incomeByCategory, expenseByCategory } = useMemo(() => {
    const now = new Date();
    const currentMonthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    let income = 0;
    let expenses = 0;
    const incomeMap = new Map<string, number>();
    const expenseMap = new Map<string, number>();

    transactions.forEach((transaction: any) => {
      const transactionDate = new Date(transaction.transaction_date);
      if (transactionDate >= currentMonthStart) {
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
  }, [transactions, accounts]);

  const monthlySavings = monthlyIncome - monthlyExpenses;

  const monthlyTrendData = useMemo(() => {
    const months: Record<string, any> = {};
    const now = new Date();
    // Last 6 months
    for (let i = 5; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
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
  }, [transactions, accounts]);

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
      
      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <div className="text-neutral-500">{t('dashboard.loadingDashboard')}</div>
        </div>
      ) : (
        <>
          {accounts.length > 0 && (
            <>
              <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
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
              </div>
            </>
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
