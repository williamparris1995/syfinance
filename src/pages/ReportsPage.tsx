import { useQuery } from '@tanstack/react-query';
import { Download } from 'lucide-react';
import { useMemo, useState } from 'react';
import { Bar, BarChart, CartesianGrid, Legend, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { Button } from '../components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../components/ui/card';
import { Input } from '../components/ui/input';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '../components/ui/table';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '../components/ui/tabs';
import { listAccounts, type AccountDto } from '../lib/tauri/account';
import { listTransactions, type TransactionDto } from '../lib/tauri/transaction';
import { listCategories, type CategoryDto } from '../lib/tauri/category';

type DateRangePreset = 'month' | 'quarter' | 'year' | 'custom';

interface BalanceSheetData {
  assets: { name: string; balance: number; currency: string }[];
  liabilities: { name: string; balance: number; currency: string }[];
  totalAssets: number;
  totalLiabilities: number;
  equity: number;
}

interface IncomeStatementData {
  income: { name: string; amount: number }[];
  expenses: { name: string; amount: number }[];
  totalIncome: number;
  totalExpenses: number;
  netIncome: number;
}

export function ReportsPage() {
  const [dateRangePreset, setDateRangePreset] = useState<DateRangePreset>('month');
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');

  const { data: accounts = [], isLoading: isLoadingAccounts } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
  });

  const { data: transactions = [], isLoading: isLoadingTransactions } = useQuery({
    queryKey: ['transactions'],
    queryFn: listTransactions,
  });

  const { data: categories = [], isLoading: isLoadingCategories } = useQuery({
    queryKey: ['categories'],
    queryFn: listCategories,
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
        const currentMonth = now.getMonth();
        const quarterStartMonth = Math.floor(currentMonth / 3) * 3;
        start.setMonth(quarterStartMonth, 1);
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

  const balanceSheetData = useMemo((): BalanceSheetData => {
    const assets: { name: string; balance: number; currency: string }[] = [];
    const liabilities: { name: string; balance: number; currency: string }[] = [];

    accounts.forEach((account: AccountDto) => {
      const balance = account.balance;

      if (['Cash', 'Bank', 'Investment'].includes(account.account_type)) {
        if (balance > 0) {
          assets.push({
            name: account.name,
            balance,
            currency: account.currency_code,
          });
        }
      } else if (['CreditCard', 'Loan'].includes(account.account_type)) {
        if (balance < 0) {
          liabilities.push({
            name: account.name,
            balance: Math.abs(balance),
            currency: account.currency_code,
          });
        }
      }
    });

    const totalAssets = assets.reduce((sum, item) => sum + item.balance, 0);
    const totalLiabilities = liabilities.reduce((sum, item) => sum + item.balance, 0);
    const equity = totalAssets - totalLiabilities;

    return { assets, liabilities, totalAssets, totalLiabilities, equity };
  }, [accounts]);

  const incomeStatementData = useMemo((): IncomeStatementData => {
    const incomeMap = new Map<string, number>();
    const expenseMap = new Map<string, number>();

    const filteredTransactions = transactions.filter((transaction: TransactionDto) => {
      const txDate = transaction.transaction_date;
      return txDate >= dateRange.start && txDate <= dateRange.end;
    });

    filteredTransactions.forEach((transaction: TransactionDto) => {
      transaction.entries.forEach((entry) => {
        // Find category for this entry
        const category = entry.category_id ? categories.find(c => c.id === entry.category_id) : null;
        
        if (!category) return; // Skip entries without category

        // Income categories
        if (category.category_type === 'Income') {
          const amount = entry.credit_amount ? parseFloat(entry.credit_amount) : 0;
          incomeMap.set(category.name, (incomeMap.get(category.name) || 0) + amount);
        }

        // Expense categories
        if (category.category_type === 'Expense') {
          const amount = entry.debit_amount ? parseFloat(entry.debit_amount) : 0;
          expenseMap.set(category.name, (expenseMap.get(category.name) || 0) + amount);
        }
      });
    });

    const income = Array.from(incomeMap.entries()).map(([name, amount]) => ({ name, amount }));
    const expenses = Array.from(expenseMap.entries()).map(([name, amount]) => ({ name, amount }));

    const totalIncome = income.reduce((sum, item) => sum + item.amount, 0);
    const totalExpenses = expenses.reduce((sum, item) => sum + item.amount, 0);
    const netIncome = totalIncome - totalExpenses;

    return { income, expenses, totalIncome, totalExpenses, netIncome };
  }, [transactions, dateRange, categories]);

  const chartData = useMemo(() => {
    return [
      { name: 'Income', amount: incomeStatementData.totalIncome },
      { name: 'Expenses', amount: incomeStatementData.totalExpenses },
    ];
  }, [incomeStatementData]);

  const downloadCSV = (data: string[][], filename: string) => {
    const csvContent = data.map((row) => row.join(',')).join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    const url = URL.createObjectURL(blob);
    link.setAttribute('href', url);
    link.setAttribute('download', filename);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const exportBalanceSheet = () => {
    const data: string[][] = [
      ['Balance Sheet', `As of ${dateRange.end}`],
      [],
      ['Assets'],
      ['Account', 'Balance', 'Currency'],
      ...balanceSheetData.assets.map((item) => [item.name, item.balance.toFixed(2), item.currency]),
      ['Total Assets', balanceSheetData.totalAssets.toFixed(2), ''],
      [],
      ['Liabilities'],
      ['Account', 'Balance', 'Currency'],
      ...balanceSheetData.liabilities.map((item) => [item.name, item.balance.toFixed(2), item.currency]),
      ['Total Liabilities', balanceSheetData.totalLiabilities.toFixed(2), ''],
      [],
      ['Equity', balanceSheetData.equity.toFixed(2), ''],
    ];

    downloadCSV(data, `balance-sheet-${dateRange.end}.csv`);
  };

  const exportIncomeStatement = () => {
    const data: string[][] = [
      ['Income Statement', `${dateRange.start} to ${dateRange.end}`],
      [],
      ['Income'],
      ['Account', 'Amount'],
      ...incomeStatementData.income.map((item) => [item.name, item.amount.toFixed(2)]),
      ['Total Income', incomeStatementData.totalIncome.toFixed(2)],
      [],
      ['Expenses'],
      ['Account', 'Amount'],
      ...incomeStatementData.expenses.map((item) => [item.name, item.amount.toFixed(2)]),
      ['Total Expenses', incomeStatementData.totalExpenses.toFixed(2)],
      [],
      ['Net Income', incomeStatementData.netIncome.toFixed(2)],
    ];

    downloadCSV(data, `income-statement-${dateRange.start}-to-${dateRange.end}.csv`);
  };

  const isLoading = isLoadingAccounts || isLoadingTransactions || isLoadingCategories;

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">Reports</h1>
      </div>

      <Card className="mb-6">
        <CardHeader>
          <CardTitle>Date Range</CardTitle>
          <CardDescription>Select a date range for the reports</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex flex-wrap gap-4">
            <div className="flex gap-2">
              <Button
                variant={dateRangePreset === 'month' ? 'default' : 'outline'}
                onClick={() => setDateRangePreset('month')}
              >
                This Month
              </Button>
              <Button
                variant={dateRangePreset === 'quarter' ? 'default' : 'outline'}
                onClick={() => setDateRangePreset('quarter')}
              >
                This Quarter
              </Button>
              <Button
                variant={dateRangePreset === 'year' ? 'default' : 'outline'}
                onClick={() => setDateRangePreset('year')}
              >
                This Year
              </Button>
              <Button
                variant={dateRangePreset === 'custom' ? 'default' : 'outline'}
                onClick={() => setDateRangePreset('custom')}
              >
                Custom
              </Button>
            </div>

            {dateRangePreset === 'custom' && (
              <div className="flex items-center gap-2">
                <label htmlFor="start-date" className="text-sm font-medium">
                  From:
                </label>
                <Input
                  id="start-date"
                  type="date"
                  value={startDate}
                  onChange={(e) => setStartDate(e.target.value)}
                  className="w-40"
                />
                <label htmlFor="end-date" className="text-sm font-medium">
                  To:
                </label>
                <Input
                  id="end-date"
                  type="date"
                  value={endDate}
                  onChange={(e) => setEndDate(e.target.value)}
                  className="w-40"
                />
              </div>
            )}
          </div>

          <div className="mt-4 text-sm text-muted-foreground">
            Selected range: {dateRange.start} to {dateRange.end}
          </div>
        </CardContent>
      </Card>

      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <div className="text-neutral-500">Loading reports...</div>
        </div>
      ) : (
        <Tabs defaultValue="balance-sheet" className="w-full">
          <TabsList className="grid w-full max-w-md grid-cols-2">
            <TabsTrigger value="balance-sheet">Balance Sheet</TabsTrigger>
            <TabsTrigger value="income-statement">Income Statement</TabsTrigger>
          </TabsList>

          <TabsContent value="balance-sheet" className="space-y-4">
            <Card>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <div>
                    <CardTitle>Balance Sheet</CardTitle>
                    <CardDescription>As of {dateRange.end}</CardDescription>
                  </div>
                  <Button onClick={exportBalanceSheet} variant="outline" size="sm">
                    <Download className="h-4 w-4 mr-2" />
                    Export CSV
                  </Button>
                </div>
              </CardHeader>
              <CardContent>
                <div className="space-y-6">
                  <div>
                    <h3 className="text-lg font-semibold mb-3">Assets</h3>
                    {balanceSheetData.assets.length === 0 ? (
                      <p className="text-sm text-muted-foreground">No assets found</p>
                    ) : (
                      <div className="border rounded-lg">
                        <Table>
                          <TableHeader>
                            <TableRow>
                              <TableHead>Account</TableHead>
                              <TableHead className="text-right">Balance</TableHead>
                              <TableHead>Currency</TableHead>
                            </TableRow>
                          </TableHeader>
                          <TableBody>
                            {balanceSheetData.assets.map((item, index) => (
                              <TableRow key={index}>
                                <TableCell className="font-medium">{item.name}</TableCell>
                                <TableCell className="text-right">
                                  {item.balance.toLocaleString('en-US', {
                                    minimumFractionDigits: 2,
                                    maximumFractionDigits: 2,
                                  })}
                                </TableCell>
                                <TableCell>{item.currency}</TableCell>
                              </TableRow>
                            ))}
                            <TableRow className="font-bold bg-muted/50">
                              <TableCell>Total Assets</TableCell>
                              <TableCell className="text-right">
                                {balanceSheetData.totalAssets.toLocaleString('en-US', {
                                  minimumFractionDigits: 2,
                                  maximumFractionDigits: 2,
                                })}
                              </TableCell>
                              <TableCell>CNY</TableCell>
                            </TableRow>
                          </TableBody>
                        </Table>
                      </div>
                    )}
                  </div>

                  <div>
                    <h3 className="text-lg font-semibold mb-3">Liabilities</h3>
                    {balanceSheetData.liabilities.length === 0 ? (
                      <p className="text-sm text-muted-foreground">No liabilities found</p>
                    ) : (
                      <div className="border rounded-lg">
                        <Table>
                          <TableHeader>
                            <TableRow>
                              <TableHead>Account</TableHead>
                              <TableHead className="text-right">Balance</TableHead>
                              <TableHead>Currency</TableHead>
                            </TableRow>
                          </TableHeader>
                          <TableBody>
                            {balanceSheetData.liabilities.map((item, index) => (
                              <TableRow key={index}>
                                <TableCell className="font-medium">{item.name}</TableCell>
                                <TableCell className="text-right">
                                  {item.balance.toLocaleString('en-US', {
                                    minimumFractionDigits: 2,
                                    maximumFractionDigits: 2,
                                  })}
                                </TableCell>
                                <TableCell>{item.currency}</TableCell>
                              </TableRow>
                            ))}
                            <TableRow className="font-bold bg-muted/50">
                              <TableCell>Total Liabilities</TableCell>
                              <TableCell className="text-right">
                                {balanceSheetData.totalLiabilities.toLocaleString('en-US', {
                                  minimumFractionDigits: 2,
                                  maximumFractionDigits: 2,
                                })}
                              </TableCell>
                              <TableCell>CNY</TableCell>
                            </TableRow>
                          </TableBody>
                        </Table>
                      </div>
                    )}
                  </div>

                  <div className="border-t pt-4">
                    <div className="flex justify-between items-center text-lg font-bold">
                      <span>Equity (Assets - Liabilities)</span>
                      <span>
                        {balanceSheetData.equity.toLocaleString('en-US', {
                          minimumFractionDigits: 2,
                          maximumFractionDigits: 2,
                        })}{' '}
                        CNY
                      </span>
                    </div>
                  </div>

                  <div className="mt-4 p-4 bg-muted/50 rounded-lg text-sm text-muted-foreground">
                    <strong>Note:</strong> Multi-currency conversion not yet implemented. All amounts are
                    displayed in their original currency. Future updates will include automatic conversion to
                    base currency (CNY).
                  </div>
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="income-statement" className="space-y-4">
            <Card>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <div>
                    <CardTitle>Income Statement</CardTitle>
                    <CardDescription>
                      {dateRange.start} to {dateRange.end}
                    </CardDescription>
                  </div>
                  <Button onClick={exportIncomeStatement} variant="outline" size="sm">
                    <Download className="h-4 w-4 mr-2" />
                    Export CSV
                  </Button>
                </div>
              </CardHeader>
              <CardContent>
                <div className="space-y-6">
                  <div>
                    <h3 className="text-lg font-semibold mb-3">Income</h3>
                    {incomeStatementData.income.length === 0 ? (
                      <p className="text-sm text-muted-foreground">No income found for this period</p>
                    ) : (
                      <div className="border rounded-lg">
                        <Table>
                          <TableHeader>
                            <TableRow>
                              <TableHead>Account</TableHead>
                              <TableHead className="text-right">Amount</TableHead>
                            </TableRow>
                          </TableHeader>
                          <TableBody>
                            {incomeStatementData.income.map((item, index) => (
                              <TableRow key={index}>
                                <TableCell className="font-medium">{item.name}</TableCell>
                                <TableCell className="text-right">
                                  {item.amount.toLocaleString('en-US', {
                                    minimumFractionDigits: 2,
                                    maximumFractionDigits: 2,
                                  })}
                                </TableCell>
                              </TableRow>
                            ))}
                            <TableRow className="font-bold bg-muted/50">
                              <TableCell>Total Income</TableCell>
                              <TableCell className="text-right">
                                {incomeStatementData.totalIncome.toLocaleString('en-US', {
                                  minimumFractionDigits: 2,
                                  maximumFractionDigits: 2,
                                })}
                              </TableCell>
                            </TableRow>
                          </TableBody>
                        </Table>
                      </div>
                    )}
                  </div>

                  <div>
                    <h3 className="text-lg font-semibold mb-3">Expenses</h3>
                    {incomeStatementData.expenses.length === 0 ? (
                      <p className="text-sm text-muted-foreground">No expenses found for this period</p>
                    ) : (
                      <div className="border rounded-lg">
                        <Table>
                          <TableHeader>
                            <TableRow>
                              <TableHead>Account</TableHead>
                              <TableHead className="text-right">Amount</TableHead>
                            </TableRow>
                          </TableHeader>
                          <TableBody>
                            {incomeStatementData.expenses.map((item, index) => (
                              <TableRow key={index}>
                                <TableCell className="font-medium">{item.name}</TableCell>
                                <TableCell className="text-right">
                                  {item.amount.toLocaleString('en-US', {
                                    minimumFractionDigits: 2,
                                    maximumFractionDigits: 2,
                                  })}
                                </TableCell>
                              </TableRow>
                            ))}
                            <TableRow className="font-bold bg-muted/50">
                              <TableCell>Total Expenses</TableCell>
                              <TableCell className="text-right">
                                {incomeStatementData.totalExpenses.toLocaleString('en-US', {
                                  minimumFractionDigits: 2,
                                  maximumFractionDigits: 2,
                                })}
                              </TableCell>
                            </TableRow>
                          </TableBody>
                        </Table>
                      </div>
                    )}
                  </div>

                  <div className="border-t pt-4">
                    <div className="flex justify-between items-center text-lg font-bold">
                      <span>Net Income (Income - Expenses)</span>
                      <span
                        className={
                          incomeStatementData.netIncome >= 0 ? 'text-green-600' : 'text-red-600'
                        }
                      >
                        {incomeStatementData.netIncome.toLocaleString('en-US', {
                          minimumFractionDigits: 2,
                          maximumFractionDigits: 2,
                        })}{' '}
                        CNY
                      </span>
                    </div>
                  </div>

                  {incomeStatementData.income.length > 0 || incomeStatementData.expenses.length > 0 ? (
                    <div className="mt-6">
                      <h3 className="text-lg font-semibold mb-3">Income vs Expenses</h3>
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

                  <div className="mt-4 p-4 bg-muted/50 rounded-lg text-sm text-muted-foreground">
                    <strong>Note:</strong> Multi-currency conversion not yet implemented. All amounts are
                    displayed in their original currency. Future updates will include automatic conversion to
                    base currency (CNY).
                  </div>
                </div>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      )}
    </div>
  );
}
