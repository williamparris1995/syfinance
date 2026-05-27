import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { Card, CardContent } from './ui/card';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from './ui/sheet';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from './ui/table';
import { Tabs, TabsList, TabsTrigger } from './ui/tabs';
import { getPrepaidDetail, getTopUpRecords } from '@/lib/tauri/prepaid';
import { getTransactionsByAccount, type TransactionDto } from '@/lib/tauri/transaction';

interface PrepaidDetailPanelProps {
  accountId: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

function formatCurrency(amount: string | number, currencyCode: string) {
  const num = typeof amount === 'string' ? parseFloat(amount) : amount;
  const symbols: Record<string, string> = { CNY: '¥', USD: '$', EUR: '€' };
  const symbol = symbols[currencyCode] || currencyCode;
  return `${symbol}${num.toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

export function PrepaidDetailPanel({ accountId, open, onOpenChange }: PrepaidDetailPanelProps) {
  const { t } = useTranslation();
  const [activeTab, setActiveTab] = useState<'topup' | 'consumption'>('topup');

  const { data: detail, isLoading: isLoadingDetail, error: detailError } = useQuery({
    queryKey: ['prepaid-detail', accountId],
    queryFn: () => getPrepaidDetail(accountId),
    enabled: open && !!accountId,
  });

  const { data: topUpRecords = [], error: topUpError } = useQuery({
    queryKey: ['top-up-records', accountId],
    queryFn: () => getTopUpRecords(accountId),
    enabled: open && !!accountId,
  });

  const { data: transactions = [], error: txError } = useQuery({
    queryKey: ['account-transactions', accountId],
    queryFn: () => getTransactionsByAccount(accountId),
    enabled: open && !!accountId,
  });

  const consumptionRecords = useMemo(() => {
    // Filter transactions to show credit entries (consumption from the prepaid account)
    const records: {
      id: string;
      date: string;
      description: string;
      amount: string;
    }[] = [];

    transactions.forEach((tx: TransactionDto) => {
      tx.entries.forEach((entry) => {
        // Consumption = credit from prepaid account (balance decreases)
        if (entry.account_id === accountId && entry.credit_amount && parseFloat(entry.credit_amount) > 0) {
          records.push({
            id: tx.id,
            date: tx.transaction_date,
            description: tx.description,
            amount: entry.credit_amount,
          });
        }
      });
    });

    return records.sort((a, b) => b.date.localeCompare(a.date));
  }, [transactions, accountId]);

  const isLowBalance = useMemo(() => {
    if (!detail?.low_balance_threshold) return false;
    return parseFloat(detail.balance) < parseFloat(detail.low_balance_threshold);
  }, [detail]);

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="right" className="w-full sm:max-w-2xl">
        <SheetHeader>
          <SheetTitle>{t('prepaid.detailTitle')} - {detail?.account_name || ''}</SheetTitle>
        </SheetHeader>
        <div className="flex-1 overflow-y-auto -mx-4 px-4">
          {isLoadingDetail ? (
            <div className="flex items-center justify-center py-12">
              <div className="text-neutral-500">{t('common.loading')}</div>
            </div>
          ) : detailError || topUpError || txError ? (
            <div className="flex flex-col items-center justify-center py-12 text-center space-y-2">
              {detailError && <p className="text-sm text-red-500">Detail: {String(detailError)}</p>}
              {topUpError && <p className="text-sm text-red-500">TopUp: {String(topUpError)}</p>}
              {txError && <p className="text-sm text-red-500">Transactions: {String(txError)}</p>}
            </div>
          ) : detail ? (
            <div className="space-y-4 px-5 pt-4">
              {/* Stat cards */}
              <div className="grid grid-cols-3 gap-3">
                <Card className="bg-gradient-to-br from-blue-50/50 to-card border-blue-200/50 dark:from-blue-950/20 dark:to-card dark:border-blue-800/30">
                  <CardContent className="pt-3 pb-3 px-4">
                    <div className="text-xs uppercase tracking-wider text-blue-600 dark:text-blue-400 mb-1">
                      {t('prepaid.currentBalance')}
                    </div>
                    <div className={`text-lg font-bold ${isLowBalance ? 'text-red-600' : 'text-blue-700 dark:text-blue-300'}`}>
                      {formatCurrency(detail.balance, detail.currency_code)}
                    </div>
                    {isLowBalance && (
                      <div className="text-xs text-red-500 mt-1">{t('prepaid.lowBalanceWarning')}</div>
                    )}
                  </CardContent>
                </Card>

                <Card className="bg-gradient-to-br from-emerald-50/50 to-card border-emerald-200/50 dark:from-emerald-950/20 dark:to-card dark:border-emerald-800/30">
                  <CardContent className="pt-3 pb-3 px-4">
                    <div className="text-xs uppercase tracking-wider text-emerald-600 dark:text-emerald-400 mb-1">
                      {t('prepaid.totalTopUps')}
                    </div>
                    <div className="text-lg font-bold text-emerald-700 dark:text-emerald-300">
                      {formatCurrency(detail.total_credited, detail.currency_code)}
                    </div>
                  </CardContent>
                </Card>

                <Card className="bg-gradient-to-br from-red-50/50 to-card border-red-200/50 dark:from-red-950/20 dark:to-card dark:border-red-800/30">
                  <CardContent className="pt-3 pb-3 px-4">
                    <div className="text-xs uppercase tracking-wider text-red-600 dark:text-red-400 mb-1">
                      {t('prepaid.totalConsumption')}
                    </div>
                    <div className="text-lg font-bold text-red-700 dark:text-red-300">
                      {formatCurrency(detail.total_consumption, detail.currency_code)}
                    </div>
                  </CardContent>
                </Card>
              </div>

              {/* Low balance threshold */}
              {detail.low_balance_threshold && (
                <div className="text-xs text-muted-foreground bg-muted/50 rounded-lg p-2">
                  {t('prepaid.lowBalanceThreshold')}: {formatCurrency(detail.low_balance_threshold, detail.currency_code)}
                </div>
              )}

              {/* Tabs */}
              <Tabs value={activeTab} onValueChange={(v) => setActiveTab(v as 'topup' | 'consumption')}>
                <TabsList>
                  <TabsTrigger value="topup">{t('prepaid.topUpRecords')}</TabsTrigger>
                  <TabsTrigger value="consumption">{t('prepaid.consumptionRecords')}</TabsTrigger>
                </TabsList>

                {activeTab === 'topup' && (
                  <div className="mt-4">
                    {topUpRecords.length === 0 ? (
                      <p className="text-sm text-muted-foreground text-center py-8">{t('prepaid.noTopUpRecords')}</p>
                    ) : (
                      <div className="border rounded-lg">
                        <Table>
                          <TableHeader>
                            <TableRow>
                              <TableHead>{t('common.date')}</TableHead>
                              <TableHead>{t('common.description')}</TableHead>
                              <TableHead className="text-right">{t('prepaid.paidAmount')}</TableHead>
                              <TableHead className="text-right">{t('prepaid.bonusAmount')}</TableHead>
                              <TableHead className="text-right">{t('prepaid.totalCredited')}</TableHead>
                              <TableHead>{t('prepaid.expiryDate')}</TableHead>
                            </TableRow>
                          </TableHeader>
                          <TableBody>
                            {topUpRecords.map((record) => (
                              <TableRow key={record.id}>
                                <TableCell className="text-xs">{record.top_up_date}</TableCell>
                                <TableCell className="text-xs">{record.description || '-'}</TableCell>
                                <TableCell className="text-xs text-right">
                                  {formatCurrency(record.paid_amount, detail.currency_code)}
                                </TableCell>
                                <TableCell className="text-xs text-right">
                                  {parseFloat(record.bonus_amount) > 0
                                    ? formatCurrency(record.bonus_amount, detail.currency_code)
                                    : '-'}
                                </TableCell>
                                <TableCell className="text-xs text-right font-medium">
                                  {formatCurrency(record.total_credited, detail.currency_code)}
                                </TableCell>
                                <TableCell className="text-xs">{record.expiry_date || '-'}</TableCell>
                              </TableRow>
                            ))}
                          </TableBody>
                        </Table>
                      </div>
                    )}
                  </div>
                )}

                {activeTab === 'consumption' && (
                  <div className="mt-4">
                    {consumptionRecords.length === 0 ? (
                      <p className="text-sm text-muted-foreground text-center py-8">{t('prepaid.noConsumptionRecords')}</p>
                    ) : (
                      <div className="border rounded-lg">
                        <Table>
                          <TableHeader>
                            <TableRow>
                              <TableHead>{t('common.date')}</TableHead>
                              <TableHead>{t('common.description')}</TableHead>
                              <TableHead className="text-right">{t('common.amount')}</TableHead>
                            </TableRow>
                          </TableHeader>
                          <TableBody>
                            {consumptionRecords.map((record) => (
                              <TableRow key={record.id}>
                                <TableCell className="text-xs">{record.date}</TableCell>
                                <TableCell className="text-xs">{record.description}</TableCell>
                                <TableCell className="text-xs text-right font-medium text-red-600">
                                  -{formatCurrency(record.amount, detail.currency_code)}
                                </TableCell>
                              </TableRow>
                            ))}
                          </TableBody>
                        </Table>
                      </div>
                    )}
                  </div>
                )}
              </Tabs>
            </div>
          ) : null}
        </div>
      </SheetContent>
    </Sheet>
  );
}
