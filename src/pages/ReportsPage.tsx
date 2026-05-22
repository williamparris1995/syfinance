import { useQuery } from '@tanstack/react-query';
import { Download } from 'lucide-react';
import { useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Bar, BarChart, CartesianGrid, Legend, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { Button } from '../components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../components/ui/card';
import { Input } from '../components/ui/input';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '../components/ui/table';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '../components/ui/tabs';
import { listAccounts, type AccountDto } from '../lib/tauri/account';
import { listTransactions, type TransactionDto } from '../lib/tauri/transaction';

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
  const { t } = useTranslation();
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
      const balance = Number(account.balance);

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
        // Find account for this entry (replaces old category-based lookup)
        const account = entry.account_id ? accounts.find(a => a.id === entry.account_id) : null;
        if (!account) return;

        // Income accounts
        if (account.account_type === 'Income') {
          const amount = entry.credit_amount ? parseFloat(entry.credit_amount) : 0;
          incomeMap.set(account.name, (incomeMap.get(account.name) || 0) + amount);
        }

        // Expense accounts
        if (account.account_type === 'Expense') {
          const amount = entry.debit_amount ? parseFloat(entry.debit_amount) : 0;
          expenseMap.set(account.name, (expenseMap.get(account.name) || 0) + amount);
        }
      });
    });

    const income = Array.from(incomeMap.entries()).map(([name, amount]) => ({ name, amount }));
    const expenses = Array.from(expenseMap.entries()).map(([name, amount]) => ({ name, amount }));

    const totalIncome = income.reduce((sum, item) => sum + item.amount, 0);
    const totalExpenses = expenses.reduce((sum, item) => sum + item.amount, 0);
    const netIncome = totalIncome - totalExpenses;

    return { income, expenses, totalIncome, totalExpenses, netIncome };
  }, [transactions, dateRange, accounts]);

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

  const chartData = useMemo(() => {
    return [
      { name: t('reports.income'), amount: incomeStatementData.totalIncome },
      { name: t('reports.expenses'), amount: incomeStatementData.totalExpenses },
    ];
  }, [incomeStatementData, t]);

  const downloadCSV = (data: string[][], filename: string) => {
    const csvContent = data.map((row) => row.join(',')).join('\n');
    const blob = new Blob(['\ufeff' + csvContent], { type: 'text/csv;charset=utf-8;' });
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
      [t('reports.balanceSheet'), `${t('reports.asOf')} ${dateRange.end}`],
      [],
      [t('reports.assets')],
      [t('common.account'), t('common.balance'), t('common.currency')],
      ...balanceSheetData.assets.map((item) => [item.name, item.balance.toFixed(2), item.currency]),
      [t('reports.totalAssets'), balanceSheetData.totalAssets.toFixed(2), ''],
      [],
      [t('reports.liabilities')],
      [t('common.account'), t('common.balance'), t('common.currency')],
      ...balanceSheetData.liabilities.map((item) => [item.name, item.balance.toFixed(2), item.currency]),
      [t('reports.totalLiabilities'), balanceSheetData.totalLiabilities.toFixed(2), ''],
      [],
      [t('reports.equity'), balanceSheetData.equity.toFixed(2), ''],
    ];

    downloadCSV(data, `balance-sheet-${dateRange.end}.csv`);
  };

  const exportIncomeStatement = () => {
    const data: string[][] = [
      [t('reports.incomeStatement'), `${dateRange.start} to ${dateRange.end}`],
      [],
      [t('reports.income')],
      [t('common.account'), t('common.amount')],
      ...incomeStatementData.income.map((item) => [item.name, item.amount.toFixed(2)]),
      [t('reports.totalIncome'), incomeStatementData.totalIncome.toFixed(2)],
      [],
      [t('reports.expenses')],
      [t('common.account'), t('common.amount')],
      ...incomeStatementData.expenses.map((item) => [item.name, item.amount.toFixed(2)]),
      [t('reports.totalExpenses'), incomeStatementData.totalExpenses.toFixed(2)],
      [],
      [t('reports.netIncome'), incomeStatementData.netIncome.toFixed(2)],
    ];

    downloadCSV(data, `income-statement-${dateRange.start}-to-${dateRange.end}.csv`);
  };

  const isLoading = isLoadingAccounts || isLoadingTransactions;

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">{t('reports.title')}</h1>
      </div>

      <Card className="mb-6">
        <CardHeader>
          <CardTitle>{t('reports.dateRange')}</CardTitle>
          <CardDescription>{t('reports.selectDateRange')}</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex flex-wrap gap-4">
            <div className="flex gap-2">
              <Button
                variant={dateRangePreset === 'month' ? 'default' : 'outline'}
                onClick={() => setDateRangePreset('month')}
              >
                {t('reports.thisMonth')}
              </Button>
              <Button
                variant={dateRangePreset === 'quarter' ? 'default' : 'outline'}
                onClick={() => setDateRangePreset('quarter')}
              >
                {t('reports.thisQuarter')}
              </Button>
              <Button
                variant={dateRangePreset === 'year' ? 'default' : 'outline'}
                onClick={() => setDateRangePreset('year')}
              >
                {t('reports.thisYear')}
              </Button>
              <Button
                variant={dateRangePreset === 'custom' ? 'default' : 'outline'}
                onClick={() => setDateRangePreset('custom')}
              >
                {t('reports.custom')}
              </Button>
            </div>

            {dateRangePreset === 'custom' && (
              <div className="flex items-center gap-2">
                <label htmlFor="start-date" className="text-sm font-medium">
                  {t('reports.from')}:
                </label>
                <Input
                  id="start-date"
                  type="date"
                  value={startDate}
                  onChange={(e) => setStartDate(e.target.value)}
                  className="w-40"
                />
                <label htmlFor="end-date" className="text-sm font-medium">
                  {t('reports.to')}:
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
            {t('reports.selectedRange')}: {dateRange.start} to {dateRange.end}
          </div>
        </CardContent>
      </Card>

      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <div className="text-neutral-500">{t('reports.loadingReports')}</div>
        </div>
      ) : (
        <Tabs defaultValue="balance-sheet" className="w-full">
          <TabsList variant="line" className="w-full">
            <TabsTrigger value="balance-sheet">{t('reports.balanceSheet')}</TabsTrigger>
            <TabsTrigger value="income-statement">{t('reports.incomeStatement')}</TabsTrigger>
          </TabsList>

          <TabsContent value="balance-sheet" className="space-y-4">
            <Card>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <div>
                    <CardTitle>{t('reports.balanceSheet')}</CardTitle>
                    <CardDescription>{t('reports.asOf')} {dateRange.end}</CardDescription>
                  </div>
                  <Button onClick={exportBalanceSheet} variant="outline" size="sm">
                    <Download className="h-4 w-4 mr-2" />
                    {t('reports.exportCSV')}
                  </Button>
                </div>
              </CardHeader>
              <CardContent>
                <div className="space-y-6">
                  <div>
                    <h3 className="text-lg font-semibold mb-3">{t('reports.assets')}</h3>
                    {balanceSheetData.assets.length === 0 ? (
                      <p className="text-sm text-muted-foreground">{t('reports.noAssets')}</p>
                    ) : (
                      <div className="border rounded-lg">
                        <Table>
                          <TableHeader>
                            <TableRow>
                              <TableHead>{t('common.account')}</TableHead>
                              <TableHead className="text-right">{t('common.balance')}</TableHead>
                              <TableHead>{t('common.currency')}</TableHead>
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
                              <TableCell>{t('reports.totalAssets')}</TableCell>
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
                    <h3 className="text-lg font-semibold mb-3">{t('reports.liabilities')}</h3>
                    {balanceSheetData.liabilities.length === 0 ? (
                      <p className="text-sm text-muted-foreground">{t('reports.noLiabilities')}</p>
                    ) : (
                      <div className="border rounded-lg">
                        <Table>
                          <TableHeader>
                            <TableRow>
                              <TableHead>{t('common.account')}</TableHead>
                              <TableHead className="text-right">{t('common.balance')}</TableHead>
                              <TableHead>{t('common.currency')}</TableHead>
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
                              <TableCell>{t('reports.totalLiabilities')}</TableCell>
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
                      <span>{t('reports.equity')}</span>
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
                    <strong>{t('common.note')}:</strong> {t('reports.multiCurrencyNote')}
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
                    <CardTitle>{t('reports.incomeStatement')}</CardTitle>
                    <CardDescription>
                      {dateRange.start} to {dateRange.end}
                    </CardDescription>
                  </div>
                  <Button onClick={exportIncomeStatement} variant="outline" size="sm">
                    <Download className="h-4 w-4 mr-2" />
                    {t('reports.exportCSV')}
                  </Button>
                </div>
              </CardHeader>
              <CardContent>
                <div className="space-y-6">
                  <div>
                    <h3 className="text-lg font-semibold mb-3">{t('reports.income')}</h3>
                    {incomeStatementData.income.length === 0 ? (
                      <p className="text-sm text-muted-foreground">{t('reports.noIncome')}</p>
                    ) : (
                      <div className="border rounded-lg">
                        <Table>
                          <TableHeader>
                            <TableRow>
                              <TableHead>{t('common.account')}</TableHead>
                              <TableHead className="text-right">{t('common.amount')}</TableHead>
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
                              <TableCell>{t('reports.totalIncome')}</TableCell>
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
                    <h3 className="text-lg font-semibold mb-3">{t('reports.expenses')}</h3>
                    {incomeStatementData.expenses.length === 0 ? (
                      <p className="text-sm text-muted-foreground">{t('reports.noExpenses')}</p>
                    ) : (
                      <div className="border rounded-lg">
                        <Table>
                          <TableHeader>
                            <TableRow>
                              <TableHead>{t('common.account')}</TableHead>
                              <TableHead className="text-right">{t('common.amount')}</TableHead>
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
                              <TableCell>{t('reports.totalExpenses')}</TableCell>
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
                      <span>{t('reports.netIncome')}</span>
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

                  <div className="mt-4 p-4 bg-muted/50 rounded-lg text-sm text-muted-foreground">
                    <strong>{t('common.note')}:</strong> {t('reports.multiCurrencyNote')}
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
