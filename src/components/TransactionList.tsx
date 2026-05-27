import { useTranslation } from 'react-i18next';
import { Receipt } from 'lucide-react';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from './ui/table';
import type { TransactionDto } from '@/lib/tauri/transaction';

interface TransactionListProps {
  transactions: TransactionDto[];
  accountId?: string;
  currencyCode?: string;
  isLoading?: boolean;
}

function formatAmount(amount: string | number, currencyCode?: string) {
  const num = typeof amount === 'string' ? parseFloat(amount) : amount;
  if (isNaN(num)) return '-';
  const symbols: Record<string, string> = { CNY: '¥', USD: '$', EUR: '€' };
  const symbol = currencyCode ? (symbols[currencyCode] || currencyCode) : '';
  return `${symbol}${num.toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

export function TransactionList({ transactions, accountId, currencyCode, isLoading }: TransactionListProps) {
  const { t } = useTranslation();

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-8">
        <div className="text-muted-foreground">{t('common.loading')}</div>
      </div>
    );
  }

  if (transactions.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-8 text-center">
        <Receipt className="h-8 w-8 text-muted-foreground/50 mb-2" />
        <p className="text-sm text-muted-foreground">{t('accounts.noTransactions') || '暂无交易记录'}</p>
      </div>
    );
  }

  const sorted = [...transactions].sort(
    (a, b) => b.transaction_date.localeCompare(a.transaction_date)
  );

  return (
    <div className="border rounded-lg">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead className="w-[100px]">{t('common.date')}</TableHead>
            <TableHead>{t('common.description')}</TableHead>
            <TableHead className="text-right w-[120px]">{t('common.amount')}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {sorted.map((tx) => {
            let amount = '';
            let isDebit = false;

            if (accountId) {
              const entry = tx.entries.find((e) => e.account_id === accountId);
              if (entry) {
                if (entry.debit_amount && parseFloat(entry.debit_amount) > 0) {
                  amount = entry.debit_amount;
                  isDebit = true;
                } else if (entry.credit_amount && parseFloat(entry.credit_amount) > 0) {
                  amount = entry.credit_amount;
                  isDebit = false;
                }
              }
            } else {
              const debitEntry = tx.entries.find(
                (e) => e.debit_amount && parseFloat(e.debit_amount) > 0
              );
              const creditEntry = tx.entries.find(
                (e) => e.credit_amount && parseFloat(e.credit_amount) > 0
              );
              if (debitEntry) {
                amount = debitEntry.debit_amount!;
                isDebit = true;
              } else if (creditEntry) {
                amount = creditEntry.credit_amount!;
                isDebit = false;
              }
            }

            return (
              <TableRow key={tx.id}>
                <TableCell className="text-xs text-muted-foreground">
                  {tx.transaction_date}
                </TableCell>
                <TableCell className="text-xs">
                  {tx.description || '-'}
                </TableCell>
                <TableCell className={`text-xs text-right font-medium ${isDebit ? 'text-red-600' : 'text-emerald-600'}`}>
                  {amount ? `${isDebit ? '-' : '+'}${formatAmount(amount, currencyCode)}` : '-'}
                </TableCell>
              </TableRow>
            );
          })}
        </TableBody>
      </Table>
    </div>
  );
}
