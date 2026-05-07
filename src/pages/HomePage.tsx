import { useQuery } from '@tanstack/react-query';
import { ArrowUpRight, ArrowDownRight, Wallet, TrendingUp } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { listAccounts } from '@/lib/tauri/account';
import { listTransactions } from '@/lib/tauri/transaction';

export function HomePage() {
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
  const now = new Date();
  const currentMonthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  
  let monthlyIncome = 0;
  let monthlyExpenses = 0;

  transactions.forEach((transaction) => {
    const transactionDate = new Date(transaction.transaction_date);
    if (transactionDate >= currentMonthStart) {
      transaction.entries.forEach((entry) => {
        if (entry.debit_amount) {
          const amount = parseFloat(entry.debit_amount);
          // Debit in expense accounts = expense
          if (entry.chart_of_account_code.startsWith('5')) {
            monthlyExpenses += amount;
          }
        }
        if (entry.credit_amount) {
          const amount = parseFloat(entry.credit_amount);
          // Credit in income accounts = income
          if (entry.chart_of_account_code.startsWith('4')) {
            monthlyIncome += amount;
          }
        }
      });
    }
  });

  const monthlySavings = monthlyIncome - monthlyExpenses;

  const isLoading = accountsLoading || transactionsLoading;

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

          {accounts.length === 0 && (
            <Card>
              <CardContent className="flex flex-col items-center justify-center py-12">
                <p className="text-neutral-500 mb-4">No accounts yet</p>
                <Button onClick={() => window.location.href = '/accounts'}>
                  Create your first account
                </Button>
              </CardContent>
            </Card>
          )}
        </>
      )}
    </div>
  );
}
