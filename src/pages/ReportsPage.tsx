import { cn } from '@/lib/utils';
import { useQuery } from '@tanstack/react-query';
import { Download } from 'lucide-react';
import { useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useNavigate } from '@tanstack/react-router';
import { Bar, BarChart, CartesianGrid, Cell, Legend, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { Button } from '../components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../components/ui/card';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../components/ui/select';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '../components/ui/table';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '../components/ui/tabs';
import { listAccounts, type AccountDto } from '../lib/tauri/account';
import {
  getYoyComparison,
  getBalanceSheet,
  getIncomeStatement,
  getMonthlyTrend,
} from '../lib/tauri/report';
import { AlertCircle } from 'lucide-react';
import { formatCurrency, getCurrencySymbol } from '../lib/currency';

type DateRangePreset = 'month' | 'quarter' | 'year' | 'custom';

export function ReportsPage() {
  const { t } = useTranslation();
  const [dateRangePreset, setDateRangePreset] = useState<DateRangePreset>('month');
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [yoyYear1, setYoyYear1] = useState(new Date().getFullYear() - 1);
  const [yoyYear2, setYoyYear2] = useState(new Date().getFullYear());
  const [yoyMode, setYoyMode] = useState<'expense' | 'income'>('expense');

  const { data: accounts = [], isLoading: isLoadingAccounts } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
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
      case 'quarter': {
        const currentMonth = now.getMonth();
        const quarterStartMonth = Math.floor(currentMonth / 3) * 3;
        start.setMonth(quarterStartMonth, 1);
        start.setHours(0, 0, 0, 0);
        break;
      }
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

  const { data: balanceSheet, isLoading: isLoadingBalanceSheet } = useQuery({
    queryKey: ['balance-sheet', dateRange.end],
    queryFn: () => getBalanceSheet(dateRange.end),
  });

  const { data: incomeStatement, isLoading: isLoadingIncomeStatement } = useQuery({
    queryKey: ['income-statement', dateRange.start, dateRange.end],
    queryFn: () => getIncomeStatement(dateRange.start, dateRange.end),
  });

  const { data: yoyData, isLoading: isLoadingYoy } = useQuery({
    queryKey: ['yoy-comparison', yoyYear1, yoyYear2],
    queryFn: () => getYoyComparison(yoyYear1, yoyYear2),
  });

  const navigate = useNavigate();

  const handleDrillDown = (accountName: string) => {
    const account = accounts.find((a) => a.name === accountName);
    if (account) {
      navigate({
        to: '/transactions',
        search: {
          accountId: account.id,
          startDate: dateRange.start,
          endDate: dateRange.end,
        },
      });
    }
  };

  // Monthly trend data from server-side aggregation
  const { data: monthlyTrendRaw = [] } = useQuery({
    queryKey: ['monthly-trend', dateRange.start, dateRange.end],
    queryFn: () => getMonthlyTrend(dateRange.start, dateRange.end),
  });

  const monthlyTrendData = useMemo(() =>
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


  const FALLBACK_COLORS = ['#EF4444', '#F59E0B', '#10B981', '#3B82F6', '#8B5CF6', '#EC4899', '#06B6D4', '#84CC16'];
  const FALLBACK_COLORS_INCOME = ['#10B981', '#06B6D4', '#84CC16', '#3B82F6', '#14B8A6'];

  const downloadCSV = (data: string[][], filename: string) => {
    const csvContent = data.map((row) => row.join(',')).join('\n');
    const blob = new Blob(['﻿' + csvContent], { type: 'text/csv;charset=utf-8;' });
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
      ...(balanceSheet?.assets ?? []).map((item) => [item.account_name, parseFloat(item.balance).toFixed(2), item.currency_code]),
      [t('reports.totalAssets'), parseFloat(balanceSheet?.total_assets ?? '0').toFixed(2), ''],
      [],
      [t('reports.liabilities')],
      [t('common.account'), t('common.balance'), t('common.currency')],
      ...(balanceSheet?.liabilities ?? []).map((item) => [item.account_name, parseFloat(item.balance).toFixed(2), item.currency_code]),
      [t('reports.totalLiabilities'), parseFloat(balanceSheet?.total_liabilities ?? '0').toFixed(2), ''],
      [],
      [t('reports.equity'), parseFloat(balanceSheet?.equity ?? '0').toFixed(2), ''],
    ];

    downloadCSV(data, `balance-sheet-${dateRange.end}.csv`);
  };

  const exportIncomeStatement = () => {
    const data: string[][] = [
      [t('reports.incomeStatement'), `${dateRange.start} to ${dateRange.end}`],
      [],
      [t('reports.income')],
      [t('common.account'), t('common.amount')],
      ...(incomeStatement?.income ?? []).map((item) => [item.account_name, parseFloat(item.amount).toFixed(2)]),
      [t('reports.totalIncome'), parseFloat(incomeStatement?.total_income ?? '0').toFixed(2)],
      [],
      [t('reports.expenses')],
      [t('common.account'), t('common.amount')],
      ...(incomeStatement?.expenses ?? []).map((item) => [item.account_name, parseFloat(item.amount).toFixed(2)]),
      [t('reports.totalExpenses'), parseFloat(incomeStatement?.total_expenses ?? '0').toFixed(2)],
      [],
      [t('reports.netIncome'), parseFloat(incomeStatement?.net_income ?? '0').toFixed(2)],
    ];

    downloadCSV(data, `income-statement-${dateRange.start}-to-${dateRange.end}.csv`);
  };

  const isLoading = isLoadingAccounts || isLoadingBalanceSheet || isLoadingIncomeStatement;

  return (
    <div className="p-4 sm:p-6">
      <div className="flex items-center justify-between mb-4 sm:mb-6">
        <h1 className="text-2xl font-bold sm:text-3xl">{t('reports.title')}</h1>
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
            {t('reports.dateRangeDisplay', { start: dateRange.start, end: dateRange.end })}
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
            <TabsTrigger value="year-over-year">{t('reports.yoyTitle')}</TabsTrigger>
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
                    {(balanceSheet?.assets ?? []).length === 0 ? (
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
                            {(balanceSheet?.assets ?? []).map((item, index) => (
                              <TableRow key={index}>
                                <TableCell className="font-medium">{item.account_name}</TableCell>
                                <TableCell className="text-right">
                                  {parseFloat(item.balance).toLocaleString('en-US', {
                                    minimumFractionDigits: 2,
                                    maximumFractionDigits: 2,
                                  })}
                                </TableCell>
                                <TableCell>{item.currency_code}</TableCell>
                              </TableRow>
                            ))}
                            <TableRow className="font-bold bg-muted/50">
                              <TableCell>{t('reports.totalAssets')}</TableCell>
                              <TableCell className="text-right">
                                {parseFloat(balanceSheet?.total_assets ?? '0').toLocaleString('en-US', {
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
                    {(balanceSheet?.liabilities ?? []).length === 0 ? (
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
                            {(balanceSheet?.liabilities ?? []).map((item, index) => (
                              <TableRow key={index}>
                                <TableCell className="font-medium">{item.account_name}</TableCell>
                                <TableCell className="text-right">
                                  {parseFloat(item.balance).toLocaleString('en-US', {
                                    minimumFractionDigits: 2,
                                    maximumFractionDigits: 2,
                                  })}
                                </TableCell>
                                <TableCell>{item.currency_code}</TableCell>
                              </TableRow>
                            ))}
                            <TableRow className="font-bold bg-muted/50">
                              <TableCell>{t('reports.totalLiabilities')}</TableCell>
                              <TableCell className="text-right">
                                {parseFloat(balanceSheet?.total_liabilities ?? '0').toLocaleString('en-US', {
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
                        {parseFloat(balanceSheet?.equity ?? '0').toLocaleString('en-US', {
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
            {/* Summary Cards */}
            <div className="grid gap-4 md:grid-cols-3 mb-6">
              <Card className="bg-gradient-to-br from-emerald-50/50 to-card border-emerald-200/50 dark:from-emerald-950/20 dark:to-card dark:border-emerald-800/30">
                <CardContent className="pt-4">
                  <div className="text-xs uppercase tracking-wider text-emerald-600 dark:text-emerald-400 mb-1">
                    {t('reports.income')}
                  </div>
                  <div className="text-2xl font-bold text-emerald-700 dark:text-emerald-300">
                    {formatCurrency(parseFloat(incomeStatement?.total_income ?? '0'), 'CNY')}
                  </div>
                  <div className="text-xs text-emerald-600/70 dark:text-emerald-400/70 mt-1">
                    {(incomeStatement?.income ?? []).length} {t('reports.categories')}
                  </div>
                </CardContent>
              </Card>

              <Card className="bg-gradient-to-br from-red-50/50 to-card border-red-200/50 dark:from-red-950/20 dark:to-card dark:border-red-800/30">
                <CardContent className="pt-4">
                  <div className="text-xs uppercase tracking-wider text-red-600 dark:text-red-400 mb-1">
                    {t('reports.expenses')}
                  </div>
                  <div className="text-2xl font-bold text-red-700 dark:text-red-300">
                    {formatCurrency(parseFloat(incomeStatement?.total_expenses ?? '0'), 'CNY')}
                  </div>
                  <div className="text-xs text-red-600/70 dark:text-red-400/70 mt-1">
                    {(incomeStatement?.expenses ?? []).length} {t('reports.categories')}
                  </div>
                </CardContent>
              </Card>

              <Card className={cn(
                "bg-gradient-to-br border to-card",
                parseFloat(incomeStatement?.net_income ?? '0') >= 0
                  ? "from-blue-50/50 border-blue-200/50 dark:from-blue-950/20 dark:border-blue-800/30"
                  : "from-amber-50/50 border-amber-200/50 dark:from-amber-950/20 dark:border-amber-800/30"
              )}>
                <CardContent className="pt-4">
                  <div className="text-xs uppercase tracking-wider text-blue-600 dark:text-blue-400 mb-1">
                    {t('reports.netIncome')}
                  </div>
                  <div className={cn(
                    "text-2xl font-bold",
                    parseFloat(incomeStatement?.net_income ?? '0') >= 0
                      ? "text-blue-700 dark:text-blue-300"
                      : "text-amber-700 dark:text-amber-300"
                  )}>
                    {formatCurrency(parseFloat(incomeStatement?.net_income ?? '0'), 'CNY')}
                  </div>
                  <div className="text-xs text-blue-600/70 dark:text-blue-400/70 mt-1">
                    {parseFloat(incomeStatement?.total_income ?? '0') > 0
                      ? `${t('reports.savingsRate')} ${((parseFloat(incomeStatement?.net_income ?? '0') / parseFloat(incomeStatement?.total_income ?? '0')) * 100).toFixed(1)}%`
                      : '—'}
                  </div>
                </CardContent>
              </Card>
            </div>

            {/* Charts Row: Donuts */}
            <div className="grid gap-4 md:grid-cols-2 mb-6">
              {/* Expense Donut */}
              <Card>
                <CardHeader>
                  <CardTitle className="text-sm">{t('reports.expenseBreakdown')}</CardTitle>
                </CardHeader>
                <CardContent>
                  {(incomeStatement?.expenses ?? []).length === 0 ? (
                    <p className="text-sm text-muted-foreground text-center py-8">{t('reports.noExpenses')}</p>
                  ) : (
                    <div className="flex items-center gap-4">
                      <ResponsiveContainer width={160} height={160}>
                        <PieChart>
                          <Pie
                            data={(incomeStatement?.expenses ?? []).map(e => ({ name: e.account_name, amount: parseFloat(e.amount) }))}
                            dataKey="amount"
                            nameKey="name"
                            cx="50%"
                            cy="50%"
                            innerRadius={48}
                            outerRadius={76}
                            paddingAngle={2}
                            onClick={(_, index) => {
                              const item = (incomeStatement?.expenses ?? [])[index];
                              if (item) handleDrillDown(item.account_name);
                            }}
                            style={{ cursor: 'pointer' }}
                          >
                            {(incomeStatement?.expenses ?? []).map((entry, index) => {
                              const account = accounts.find(a => a.name === entry.account_name && a.account_type === 'Expense');
                              return (
                                <Cell
                                  key={entry.account_name}
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
                      <div className="flex-1 space-y-1.5 max-h-[160px] overflow-y-auto">
                        {(incomeStatement?.expenses ?? [])
                          .map(e => ({ ...e, parsedAmount: parseFloat(e.amount) }))
                          .sort((a, b) => b.parsedAmount - a.parsedAmount)
                          .map((item, index) => {
                            const account = accounts.find(a => a.name === item.account_name && a.account_type === 'Expense');
                            const totalExpenses = parseFloat(incomeStatement?.total_expenses ?? '0');
                            const pct = totalExpenses > 0
                              ? ((item.parsedAmount / totalExpenses) * 100).toFixed(1)
                              : '0';
                            return (
                              <div key={item.account_name} className="flex items-center gap-2 text-xs">
                                <span
                                  className="w-2.5 h-2.5 rounded-sm flex-shrink-0"
                                  style={{ backgroundColor: account?.color || FALLBACK_COLORS[index % FALLBACK_COLORS.length] }}
                                />
                                <span className="truncate flex-1">
                                  {account?.icon || ''} {item.account_name}
                                </span>
                                <span className="text-muted-foreground tabular-nums">{getCurrencySymbol('CNY')}{item.parsedAmount.toFixed(0)}</span>
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
                  {(incomeStatement?.income ?? []).length === 0 ? (
                    <p className="text-sm text-muted-foreground text-center py-8">{t('reports.noIncome')}</p>
                  ) : (
                    <div className="flex items-center gap-4">
                      <ResponsiveContainer width={160} height={160}>
                        <PieChart>
                          <Pie
                            data={(incomeStatement?.income ?? []).map(e => ({ name: e.account_name, amount: parseFloat(e.amount) }))}
                            dataKey="amount"
                            nameKey="name"
                            cx="50%"
                            cy="50%"
                            innerRadius={48}
                            outerRadius={76}
                            paddingAngle={2}
                            onClick={(_, index) => {
                              const item = (incomeStatement?.income ?? [])[index];
                              if (item) handleDrillDown(item.account_name);
                            }}
                            style={{ cursor: 'pointer' }}
                          >
                            {(incomeStatement?.income ?? []).map((entry, index) => {
                              const account = accounts.find(a => a.name === entry.account_name && a.account_type === 'Income');
                              return (
                                <Cell
                                  key={entry.account_name}
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
                      <div className="flex-1 space-y-1.5 max-h-[160px] overflow-y-auto">
                        {(incomeStatement?.income ?? [])
                          .map(e => ({ ...e, parsedAmount: parseFloat(e.amount) }))
                          .sort((a, b) => b.parsedAmount - a.parsedAmount)
                          .map((item, index) => {
                            const account = accounts.find(a => a.name === item.account_name && a.account_type === 'Income');
                            const totalIncome = parseFloat(incomeStatement?.total_income ?? '0');
                            const pct = totalIncome > 0
                              ? ((item.parsedAmount / totalIncome) * 100).toFixed(1)
                              : '0';
                            return (
                              <div key={item.account_name} className="flex items-center gap-2 text-xs">
                                <span
                                  className="w-2.5 h-2.5 rounded-sm flex-shrink-0"
                                  style={{ backgroundColor: account?.color || FALLBACK_COLORS_INCOME[index % FALLBACK_COLORS_INCOME.length] }}
                                />
                                <span className="truncate flex-1">
                                  {account?.icon || ''} {item.account_name}
                                </span>
                                <span className="text-muted-foreground tabular-nums">{getCurrencySymbol('CNY')}{item.parsedAmount.toFixed(0)}</span>
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
                    <>
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
                            formatter={(value, name) => [
                              `${getCurrencySymbol('CNY')}${Number(value).toLocaleString('en-US', { minimumFractionDigits: 2 })}`,
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
                                onClick={() => handleDrillDown(catName)}
                                style={{ cursor: 'pointer' }}
                              />
                            );
                          })}
                        </BarChart>
                      </ResponsiveContainer>
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
                    </>
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
                          formatter={(value) => [
                            `${getCurrencySymbol('CNY')}${Number(value).toLocaleString('en-US', { minimumFractionDigits: 2 })}`,
                          ]}
                        />
                        <Bar dataKey="income" fill="#10B981" radius={[4, 4, 0, 0]} name={t('reports.income')} style={{ cursor: 'pointer' }} />
                        <Bar dataKey="expenses" fill="#EF4444" radius={[4, 4, 0, 0]} name={t('reports.expenses')} style={{ cursor: 'pointer' }} />
                        <Legend />
                      </BarChart>
                    </ResponsiveContainer>
                  )}
                </CardContent>
              </Card>
            </div>

            <Card>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <div>
                    <CardTitle>{t('reports.incomeStatement')}</CardTitle>
                    <CardDescription>
                      {t('reports.dateRangeDisplay', { start: dateRange.start, end: dateRange.end })}
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
                    {(incomeStatement?.income ?? []).length === 0 ? (
                      <p className="text-sm text-muted-foreground">{t('reports.noIncome')}</p>
                    ) : (
                      <div className="border rounded-lg">
                        <Table>
                          <TableHeader>
                            <TableRow>
                              <TableHead>{t('common.account')}</TableHead>
                              <TableHead className="text-right">{t('common.amount')}</TableHead>
                              <TableHead className="text-right w-16">{t('reports.transactions')}</TableHead>
                            </TableRow>
                          </TableHeader>
                          <TableBody>
                            {(incomeStatement?.income ?? []).map((item, index) => (
                              <TableRow key={index}>
                                <TableCell className="font-medium">{item.account_name}</TableCell>
                                <TableCell className="text-right">
                                  {parseFloat(item.amount).toLocaleString('en-US', {
                                    minimumFractionDigits: 2,
                                    maximumFractionDigits: 2,
                                  })}
                                </TableCell>
                                <TableCell className="text-right text-muted-foreground">
                                  {item.transaction_count}
                                </TableCell>
                              </TableRow>
                            ))}
                            <TableRow className="font-bold bg-muted/50">
                              <TableCell>{t('reports.totalIncome')}</TableCell>
                              <TableCell className="text-right">
                                {parseFloat(incomeStatement?.total_income ?? '0').toLocaleString('en-US', {
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
                    {(incomeStatement?.expenses ?? []).length === 0 ? (
                      <p className="text-sm text-muted-foreground">{t('reports.noExpenses')}</p>
                    ) : (
                      <div className="border rounded-lg">
                        <Table>
                          <TableHeader>
                            <TableRow>
                              <TableHead>{t('common.account')}</TableHead>
                              <TableHead className="text-right">{t('common.amount')}</TableHead>
                              <TableHead className="text-right w-16">{t('reports.transactions')}</TableHead>
                            </TableRow>
                          </TableHeader>
                          <TableBody>
                            {(incomeStatement?.expenses ?? []).map((item, index) => (
                              <TableRow key={index}>
                                <TableCell className="font-medium">{item.account_name}</TableCell>
                                <TableCell className="text-right">
                                  {parseFloat(item.amount).toLocaleString('en-US', {
                                    minimumFractionDigits: 2,
                                    maximumFractionDigits: 2,
                                  })}
                                </TableCell>
                                <TableCell className="text-right text-muted-foreground">
                                  {item.transaction_count}
                                </TableCell>
                              </TableRow>
                            ))}
                            <TableRow className="font-bold bg-muted/50">
                              <TableCell>{t('reports.totalExpenses')}</TableCell>
                              <TableCell className="text-right">
                                {parseFloat(incomeStatement?.total_expenses ?? '0').toLocaleString('en-US', {
                                  minimumFractionDigits: 2,
                                  maximumFractionDigits: 2,
                                })}
                              </TableCell>
                              <TableCell />
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
                          parseFloat(incomeStatement?.net_income ?? '0') >= 0 ? 'text-green-600' : 'text-red-600'
                        }
                      >
                        {parseFloat(incomeStatement?.net_income ?? '0').toLocaleString('en-US', {
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

          <TabsContent value="year-over-year" className="space-y-4">
            <Card>
              <CardHeader>
                <CardTitle>{t('reports.yoyTitle')}</CardTitle>
              </CardHeader>
              <CardContent>
                {/* Year selectors */}
                <div className="flex flex-wrap items-center gap-4 mb-6">
                  <div className="flex items-center gap-2">
                    <Label className="text-sm">{t('reports.year')}</Label>
                    <Select value={String(yoyYear1)} onValueChange={(v) => setYoyYear1(Number(v))}>
                      <SelectTrigger className="w-24"><SelectValue /></SelectTrigger>
                      <SelectContent>
                        {Array.from({ length: 5 }, (_, i) => new Date().getFullYear() - i).map((y) => (
                          <SelectItem key={y} value={String(y)}>{y}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <span className="text-muted-foreground">{t('reports.vs')}</span>
                  <div className="flex items-center gap-2">
                    <Label className="text-sm">{t('reports.year')}</Label>
                    <Select value={String(yoyYear2)} onValueChange={(v) => setYoyYear2(Number(v))}>
                      <SelectTrigger className="w-24"><SelectValue /></SelectTrigger>
                      <SelectContent>
                        {Array.from({ length: 5 }, (_, i) => new Date().getFullYear() - i).map((y) => (
                          <SelectItem key={y} value={String(y)}>{y}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  {/* Toggle income/expense */}
                  <div className="flex gap-1 ml-auto">
                    <Button
                      variant={yoyMode === 'expense' ? 'default' : 'outline'}
                      size="sm"
                      onClick={() => setYoyMode('expense')}
                    >
                      {t('reports.expenses')}
                    </Button>
                    <Button
                      variant={yoyMode === 'income' ? 'default' : 'outline'}
                      size="sm"
                      onClick={() => setYoyMode('income')}
                    >
                      {t('reports.income')}
                    </Button>
                  </div>
                </div>

                {/* Chart */}
                {isLoadingYoy ? (
                  <div className="text-center py-8 text-muted-foreground">{t('common.loading')}</div>
                ) : yoyData ? (
                  <ResponsiveContainer width="100%" height={400}>
                    <BarChart data={yoyData.months}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="month" tickFormatter={(m: number) => `${m}${t('reports.monthSuffix')}`} />
                      <YAxis tickFormatter={(v: number) => `${v}`} />
                      <Tooltip
                        formatter={(value) => [value, '']}
                        labelFormatter={(m) => `${m}${t('reports.monthSuffix')}`}
                      />
                      <Legend />
                      <Bar
                        dataKey={yoyMode === 'expense' ? 'year1_expense' : 'year1_income'}
                        name={String(yoyYear1)}
                        fill="#94a3b8"
                      />
                      <Bar
                        dataKey={yoyMode === 'expense' ? 'year2_expense' : 'year2_income'}
                        name={String(yoyYear2)}
                        fill="#3b82f6"
                      />
                    </BarChart>
                  </ResponsiveContainer>
                ) : null}
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      )}

      {/* Prepaid Account Summary */}
      {(() => {
        const prepaidAccounts = accounts.filter((a: AccountDto) => a.account_type === 'Prepaid');
        if (prepaidAccounts.length === 0) return null;
        return (
          <Card className="mt-6">
            <CardHeader>
              <CardTitle>{t('prepaid.summaryTitle')}</CardTitle>
              <CardDescription>{t('prepaid.summaryDesc')}</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="border rounded-lg">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t('common.name')}</TableHead>
                      <TableHead className="text-right">{t('accounts.currentBalance')}</TableHead>
                      <TableHead className="text-right">{t('prepaid.lowBalanceThreshold')}</TableHead>
                      <TableHead>{t('debts.status')}</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {prepaidAccounts.map((account: AccountDto) => {
                      const balance = Number(account.current_balance);
                      const threshold = account.low_balance_threshold != null ? Number(account.low_balance_threshold) : null;
                      const isLow = threshold != null && balance < threshold;
                      return (
                        <TableRow key={account.id}>
                          <TableCell className="font-medium">{account.name}</TableCell>
                          <TableCell className="text-right">
                            {balance.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                          </TableCell>
                          <TableCell className="text-right">
                            {threshold != null
                              ? threshold.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
                              : '-'}
                          </TableCell>
                          <TableCell>
                            {isLow ? (
                              <span className="inline-flex items-center gap-1 text-xs text-red-600 font-medium">
                                <AlertCircle className="h-3 w-3" />
                                {t('prepaid.lowBalanceWarning')}
                              </span>
                            ) : (
                              <span className="text-xs text-emerald-600 font-medium">{t('prepaid.normalBalance')}</span>
                            )}
                          </TableCell>
                        </TableRow>
                      );
                    })}
                  </TableBody>
                </Table>
              </div>
            </CardContent>
          </Card>
        );
      })()}
    </div>
  );
}
