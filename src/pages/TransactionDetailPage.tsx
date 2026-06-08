import { useParams, useNavigate } from '@tanstack/react-router';
import { useTranslation } from 'react-i18next';
import { useQuery } from '@tanstack/react-query';
import { ArrowDownUp, ArrowUpRight, ArrowDownRight, BadgeDollarSign } from 'lucide-react';
import { cn } from '@/lib/utils';
import { PageShell } from '@/components/patterns/layout/PageShell';
import { HeroCard } from '@/components/patterns/cards/HeroCard';
import { StatCard } from '@/components/patterns/cards/StatCard';
import { DetailTwoCol } from '@/components/patterns/detail/DetailTwoCol';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Separator } from '@/components/ui/separator';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { getTransaction } from '@/lib/tauri/transaction';
import { listAccounts, listAccountsByOwnership } from '@/lib/tauri/account';
import { addDecimals, safeParseDecimal } from '@/lib/decimal';

type TransactionType = 'expense' | 'income' | 'transfer';

export function TransactionDetailPage() {
  const { transactionId } = useParams({ strict: false }) as { transactionId: string };
  const navigate = useNavigate();
  const { t } = useTranslation();

  const { data: transaction, isLoading } = useQuery({
    queryKey: ['transaction', transactionId],
    queryFn: () => getTransaction(transactionId),
    enabled: !!transactionId,
  });

  const { data: accounts = [] } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
  });

  const { data: externalAccounts = [] } = useQuery({
    queryKey: ['accounts', 'external'],
    queryFn: () => listAccountsByOwnership('external'),
  });

  const getAccountName = (accountId: string) => {
    const account = accounts.find((a) => a.id === accountId);
    return account ? account.name : accountId;
  };

  const getTransactionType = (): TransactionType => {
    if (!transaction) return 'transfer';
    const externalAccountIds = externalAccounts.map((a) => a.id);
    const txExternalEntries = transaction.entries.filter((e) =>
      externalAccountIds.includes(e.account_id),
    );
    if (txExternalEntries.length === 0) return 'transfer';
    const incomeCount = txExternalEntries.filter((e) =>
      externalAccounts.find((a) => a.id === e.account_id && a.account_type === 'Income'),
    ).length;
    const expenseCount = txExternalEntries.filter((e) =>
      externalAccounts.find((a) => a.id === e.account_id && a.account_type === 'Expense'),
    ).length;
    if (incomeCount > 0 && expenseCount === 0) return 'income';
    if (expenseCount > 0 && incomeCount === 0) return 'expense';
    return 'transfer';
  };

  const getTransactionAmount = () => {
    if (!transaction) return 0;
    let total = '0.00';
    transaction.entries.forEach((entry) => {
      if (entry.debit_amount) {
        total = addDecimals(total, safeParseDecimal(entry.debit_amount));
      }
    });
    return parseFloat(total);
  };

  const getTransactionAccounts = () => {
    if (!transaction) return '';
    const accountNames = transaction.entries.map((entry) => getAccountName(entry.account_id));
    return [...new Set(accountNames)].join(', ');
  };

  if (isLoading) {
    return (
      <PageShell>
        <div className="flex items-center justify-center py-12">
          <div className="text-muted-foreground">{t('common.loading')}</div>
        </div>
      </PageShell>
    );
  }

  if (!transaction) {
    return (
      <PageShell>
        <div className="flex items-center justify-center py-12">
          <div className="text-muted-foreground">{t('common.noResults')}</div>
        </div>
      </PageShell>
    );
  }

  const txType = getTransactionType();
  const amount = getTransactionAmount();
  const accountNames = getTransactionAccounts();
  const currency = transaction.entries[0]?.currency_code || 'CNY';
  const isExpense = txType === 'expense';
  const isIncome = txType === 'income';

  const typeIcon =
    txType === 'expense' ? (
      <ArrowDownRight className="h-5 w-5" />
    ) : txType === 'income' ? (
      <ArrowUpRight className="h-5 w-5" />
    ) : (
      <ArrowDownUp className="h-5 w-5" />
    );

  const typeLabel =
    txType === 'expense'
      ? t('transaction.expense')
      : txType === 'income'
        ? t('transaction.income')
        : t('transaction.transfer');

  return (
    <PageShell>
      <HeroCard
        icon={typeIcon}
        name={transaction.description || t('transactions.untitled')}
        subtitle={transaction.transaction_date}
      >
        <div
          className={cn(
            'font-display text-4xl font-semibold',
            isExpense
              ? 'text-expense'
              : isIncome
                ? 'text-income'
                : 'text-foreground',
          )}
        >
          {isExpense ? '-' : ''}
          {amount.toFixed(2)} {currency}
        </div>
        <Badge variant="secondary" className="mt-2">
          {typeLabel}
        </Badge>
      </HeroCard>

      <div className="grid grid-cols-4 gap-3.5 mb-7">
        <StatCard label={t('transactions.date')} value={transaction.transaction_date} />
        <StatCard label={t('transactions.type')} value={typeLabel} />
        <StatCard label={t('transactions.accounts')} value={accountNames} />
        <StatCard
          label={t('transactions.entries')}
          value={String(transaction.entries.length)}
        />
      </div>

      <DetailTwoCol
        main={
          <div className="rounded-[14px] border border-border bg-card overflow-hidden">
            <h3 className="px-5 pt-5 pb-3 text-sm font-semibold">
              {t('transactions.entryDetails')}
            </h3>
            <Table>
              <TableHeader>
                <TableRow className="bg-muted/50">
                  <TableHead>{t('transactions.account')}</TableHead>
                  <TableHead>{t('transactions.debit')}</TableHead>
                  <TableHead>{t('transactions.credit')}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {transaction.entries.map((entry, i) => (
                  <TableRow key={i}>
                    <TableCell>{getAccountName(entry.account_id)}</TableCell>
                    <TableCell>{entry.debit_amount || '—'}</TableCell>
                    <TableCell>{entry.credit_amount || '—'}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        }
        side={
          <div className="rounded-[14px] border border-border bg-card p-5 space-y-4">
            <div>
              <div className="text-xs text-muted-foreground">{t('transactions.createdAt')}</div>
              <div className="text-sm">
                {new Date(transaction.created_at).toLocaleString()}
              </div>
            </div>
            <div>
              <div className="text-xs text-muted-foreground">{t('transactions.updatedAt')}</div>
              <div className="text-sm">
                {new Date(transaction.updated_at).toLocaleString()}
              </div>
            </div>
            {transaction.description && (
              <div>
                <div className="text-xs text-muted-foreground">
                  {t('transactions.description')}
                </div>
                <div className="text-sm">{transaction.description}</div>
              </div>
            )}
            <Separator />
            <Button
              variant="outline"
              className="w-full"
              onClick={() => navigate({ to: '/transactions' })}
            >
              {t('common.back')}
            </Button>
          </div>
        }
      />
    </PageShell>
  );
}
