import { useQuery } from '@tanstack/react-query';
import { ArrowUpRight, ArrowDownRight, Wallet, TrendingUp, Receipt, CreditCard, BarChart3, Plus } from 'lucide-react';
import { useNavigate } from '@tanstack/react-router';
import { useTranslation } from 'react-i18next';
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
  const totalBalance = accounts.reduce((sum, account) => sum + account.balance, 0);

  // Calculate income and expenses from transactions (current month)
  // Uses account-based lookup: Income/Expense are determined by the linked account's type
  const now = new Date();
  const currentMonthStart = new Date(now.getFullYear(), now.getMonth(), 1);

  let monthlyIncome = 0;
  let monthlyExpenses = 0;

  transactions.forEach((transaction) => {
    const transactionDate = new Date(transaction.transaction_date);
    if (transactionDate >= currentMonthStart) {
      transaction.entries.forEach((entry) => {
        const account = entry.account_id ? accounts.find(a => a.id === entry.account_id) : null;
        if (!account) return;

        if (entry.debit_amount && account.account_type === 'Expense') {
          monthlyExpenses += parseFloat(entry.debit_amount);
        }
        if (entry.credit_amount && account.account_type === 'Income') {
          monthlyIncome += parseFloat(entry.credit_amount);
        }
      });
    }
  });

  const monthlySavings = monthlyIncome - monthlyExpenses;

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

          {/* Quick Actions */}
          <Card>
            <CardHeader>
              <CardTitle>{t('dashboard.quickActions')}</CardTitle>
            </CardHeader>
            <CardContent>
              <QuickActions
                actions={[
                  {
                    id: 'new-transaction',
                    label: t('dashboard.recordTransaction'),
                    icon: Receipt,
                    onClick: () => navigate({ to: '/transactions' }),
                  },
                  {
                    id: 'new-account',
                    label: t('dashboard.createAccount'),
                    icon: Plus,
                    onClick: () => navigate({ to: '/accounts' }),
                  },
                  {
                    id: 'view-reports',
                    label: t('dashboard.viewReports'),
                    icon: BarChart3,
                    onClick: () => navigate({ to: '/reports' }),
                  },
                  {
                    id: 'manage-debts',
                    label: t('dashboard.manageDebts'),
                    icon: CreditCard,
                    onClick: () => navigate({ to: '/debts' }),
                  },
                ]}
                layout="grid"
              />
            </CardContent>
          </Card>

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
