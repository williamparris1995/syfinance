import { useQuery } from '@tanstack/react-query';
import { ArrowUpRight, ArrowDownRight, Wallet, TrendingUp, Receipt, CreditCard, BarChart3, Plus } from 'lucide-react';
import { useNavigate } from '@tanstack/react-router';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { QuickActions } from '@/components/QuickActions';
import { EmptyState } from '@/components/EmptyState';
import { listAccounts } from '@/lib/tauri/account';
import { listTransactions } from '@/lib/tauri/transaction';
import { listCategories } from '@/lib/tauri/category';

export function HomePage() {
  const navigate = useNavigate();
  
  const { data: accounts = [], isLoading: accountsLoading } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
  });

  const { data: transactions = [], isLoading: transactionsLoading } = useQuery({
    queryKey: ['transactions'],
    queryFn: listTransactions,
  });

  const { data: categories = [], isLoading: categoriesLoading } = useQuery({
    queryKey: ['categories'],
    queryFn: listCategories,
  });

  // Calculate total balance from all accounts
  const totalBalance = accounts.reduce((sum, account) => sum + account.balance, 0);

  // Calculate income and expenses from transactions (current month)
  const now = new Date();
  const currentMonthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  
  let monthlyIncome = 0;
  let monthlyExpenses = 0;

  transactions.forEach((transaction) => {
    const transactionDate = new Date(transaction.transaction_date);
    if (transactionDate >= currentMonthStart) {
      transaction.entries.forEach((entry) => {
        // Find category for this entry
        const category = entry.category_id ? categories.find(c => c.id === entry.category_id) : null;
        
        if (entry.debit_amount) {
          const amount = parseFloat(entry.debit_amount);
          // If category is Expense type, it's an expense
          if (category && category.category_type === 'Expense') {
            monthlyExpenses += amount;
          }
        }
        if (entry.credit_amount) {
          const amount = parseFloat(entry.credit_amount);
          // If category is Income type, it's income
          if (category && category.category_type === 'Income') {
            monthlyIncome += amount;
          }
        }
      });
    }
  });

  const monthlySavings = monthlyIncome - monthlyExpenses;

  const isLoading = accountsLoading || transactionsLoading || categoriesLoading;

  return (
    <div className="space-y-6 p-6">
      <div className="flex items-center justify-between">
        <h2 className="text-3xl font-bold">Dashboard</h2>
      </div>
      
      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <div className="text-neutral-500">Loading dashboard...</div>
        </div>
      ) : (
        <>
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Total Balance</CardTitle>
                <Wallet className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">
                  ¥{totalBalance.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </div>
                <p className="text-xs text-muted-foreground mt-1">
                  Across {accounts.length} account{accounts.length !== 1 ? 's' : ''}
                </p>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Monthly Income</CardTitle>
                <ArrowUpRight className="h-4 w-4 text-green-600" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-green-600">
                  +¥{monthlyIncome.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </div>
                <p className="text-xs text-muted-foreground mt-1">
                  {now.toLocaleString('en-US', { month: 'long', year: 'numeric' })}
                </p>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Monthly Expenses</CardTitle>
                <ArrowDownRight className="h-4 w-4 text-red-600" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-red-600">
                  -¥{monthlyExpenses.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </div>
                <p className="text-xs text-muted-foreground mt-1">
                  {now.toLocaleString('en-US', { month: 'long', year: 'numeric' })}
                </p>
              </CardContent>
            </Card>
            
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Monthly Savings</CardTitle>
                <TrendingUp className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className={`text-2xl font-bold ${monthlySavings >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                  {monthlySavings >= 0 ? '+' : ''}¥{monthlySavings.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </div>
                <p className="text-xs text-muted-foreground mt-1">
                  Income - Expenses
                </p>
              </CardContent>
            </Card>
          </div>

          {/* Quick Actions */}
          <Card>
            <CardHeader>
              <CardTitle>Quick Actions</CardTitle>
            </CardHeader>
            <CardContent>
              <QuickActions
                actions={[
                  {
                    id: 'new-transaction',
                    label: 'Record Transaction',
                    icon: Receipt,
                    onClick: () => navigate({ to: '/transactions' }),
                  },
                  {
                    id: 'new-account',
                    label: 'Create Account',
                    icon: Plus,
                    onClick: () => navigate({ to: '/accounts' }),
                  },
                  {
                    id: 'view-reports',
                    label: 'View Reports',
                    icon: BarChart3,
                    onClick: () => navigate({ to: '/reports' }),
                  },
                  {
                    id: 'manage-debts',
                    label: 'Manage Debts',
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
              title="No accounts yet"
              description="Create your first account to start tracking your finances"
              action={{
                label: 'Create Account',
                onClick: () => navigate({ to: '/accounts' }),
              }}
            />
          )}
        </>
      )}
    </div>
  );
}
