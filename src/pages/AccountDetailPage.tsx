import { useState } from 'react';
import { useParams, useNavigate } from '@tanstack/react-router';
import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import {
  Pencil,
  Trash2,
  Wallet,
  Landmark,
  CreditCard,
  TrendingUp,
  HandCoins,
  ArrowRightLeft,
  PiggyBank,
  Layers,
  Banknote,
  Receipt,
} from 'lucide-react';
import { AreaChart, Area, ResponsiveContainer, YAxis } from 'recharts';

import { PageShell } from '@/components/patterns/layout/PageShell';
import { HeroCard } from '@/components/patterns/cards/HeroCard';
import { StatCard } from '@/components/patterns/cards/StatCard';
import { DetailTwoCol } from '@/components/patterns/detail/DetailTwoCol';
import { PageHeader } from '@/components/patterns/layout/PageHeader';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Separator } from '@/components/ui/separator';
import { TransactionList } from '@/components/TransactionList';
import { DeleteAccountDialog } from '@/components/DeleteAccountDialog';
import {
  getAccount,
} from '@/lib/tauri/account';
import { getTransactionsByAccount } from '@/lib/tauri/transaction';
import { useAccountBalanceHistory } from '@/hooks/useAccountBalanceHistory';
import { formatCurrency } from '@/lib/currency';

/* ------------------------------------------------------------------ */
/*  Icon mapping                                                       */
/* ------------------------------------------------------------------ */

const typeIcons: Record<string, React.ReactNode> = {
  Cash: <Wallet className="h-6 w-6" />,
  Bank: <Landmark className="h-6 w-6" />,
  CreditCard: <CreditCard className="h-6 w-6" />,
  Investment: <TrendingUp className="h-6 w-6" />,
  BorrowedOut: <HandCoins className="h-6 w-6" />,
  BorrowedIn: <ArrowRightLeft className="h-6 w-6" />,
  Prepaid: <PiggyBank className="h-6 w-6" />,
  Income: <Banknote className="h-6 w-6" />,
  Expense: <Receipt className="h-6 w-6" />,
  Other: <Layers className="h-6 w-6" />,
};

/* ------------------------------------------------------------------ */
/*  Badge colours                                                      */
/* ------------------------------------------------------------------ */

const typeBadgeColors: Record<string, string> = {
  Cash: 'bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-300',
  Bank: 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300',
  CreditCard: 'bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-300',
  Investment: 'bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-300',
  BorrowedOut: 'bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-300',
  BorrowedIn: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300',
  Prepaid: 'bg-teal-100 text-teal-800 dark:bg-teal-900 dark:text-teal-300',
  Income: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300',
  Expense: 'bg-pink-100 text-pink-800 dark:bg-pink-900 dark:text-pink-300',
  Other: 'bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-300',
};

/* ------------------------------------------------------------------ */
/*  i18n key for account type labels                                   */
/* ------------------------------------------------------------------ */

const typeLabels: Record<string, string> = {
  Cash: 'accountForm.cash',
  Bank: 'accountForm.bank',
  CreditCard: 'accountForm.creditCard',
  Investment: 'accountForm.investment',
  BorrowedOut: 'accountForm.borrowedOut',
  BorrowedIn: 'accountForm.borrowedIn',
  Prepaid: 'accountForm.prepaid',
  Income: 'accountForm.income',
  Expense: 'accountForm.expense',
  Other: 'accountForm.other',
};

/* ------------------------------------------------------------------ */
/*  Balance sparkline chart                                            */
/* ------------------------------------------------------------------ */

function DetailBalanceChart({ accountId }: { accountId: string }) {
  const { t } = useTranslation();
  const { data } = useAccountBalanceHistory(accountId, 30);
  if (!data || data.length < 2) {
    return (
      <div className="flex h-[60px] items-center justify-center text-xs text-muted-foreground">
        {t('accounts.noTransactions')}
      </div>
    );
  }

  const chartData = data.map((d) => ({ ...d, balance: Number(d.balance) }));
  const first = chartData[0]?.balance ?? 0;
  const last = chartData[chartData.length - 1]?.balance ?? 0;
  const isPositive = last >= first;

  // Use CSS-variable-based semantic colours
  const strokeColor = isPositive ? 'oklch(var(--income))' : 'oklch(var(--expense))';

  return (
    <ResponsiveContainer width="100%" height={80}>
      <AreaChart data={chartData}>
        <defs>
          <linearGradient id={`gradient-${accountId}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor={strokeColor} stopOpacity={0.25} />
            <stop offset="95%" stopColor={strokeColor} stopOpacity={0} />
          </linearGradient>
        </defs>
        <YAxis domain={['dataMin', 'dataMax']} hide />
        <Area
          type="monotone"
          dataKey="balance"
          stroke={strokeColor}
          strokeWidth={1.5}
          fill={`url(#gradient-${accountId})`}
          dot={false}
        />
      </AreaChart>
    </ResponsiveContainer>
  );
}

/* ------------------------------------------------------------------ */
/*  Page                                                               */
/* ------------------------------------------------------------------ */

export function AccountDetailPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { accountId } = useParams({ strict: false });

  const [deleteOpen, setDeleteOpen] = useState(false);

  /* ---- Fetch account ---- */
  const {
    data: account,
    isLoading,
    isError,
  } = useQuery({
    queryKey: ['accounts', accountId],
    queryFn: () => getAccount(accountId!),
    enabled: !!accountId,
  });

  /* ---- Fetch transactions ---- */
  const { data: transactions = [], isLoading: isLoadingTx } = useQuery({
    queryKey: ['account-transactions', accountId],
    queryFn: () => getTransactionsByAccount(accountId!),
    enabled: !!accountId,
  });

  /* ---- Loading / error states ---- */
  if (isLoading) {
    return (
      <PageShell>
        <div className="flex items-center justify-center py-20">
          <div className="text-muted-foreground">{t('accounts.loadingAccounts')}</div>
        </div>
      </PageShell>
    );
  }

  if (isError || !account) {
    return (
      <PageShell>
        <PageHeader title={t('accounts.detailTitle')} />
        <div className="flex items-center justify-center py-20">
          <div className="text-red-500">{t('accounts.loadError')}</div>
        </div>
      </PageShell>
    );
  }

  /* ---- Helpers ---- */
  const balanceNum =
    typeof account.current_balance === 'string'
      ? parseFloat(account.current_balance)
      : account.current_balance;
  const balanceColor =
    balanceNum > 0
      ? 'text-income'
      : balanceNum < 0
        ? 'text-expense'
        : 'text-muted-foreground';

  const initialNum =
    typeof account.initial_balance === 'string'
      ? parseFloat(account.initial_balance)
      : account.initial_balance;

  /* ---- Render ---- */
  return (
    <PageShell>
      {/* Header */}
      <PageHeader
        title={t('accounts.detailTitle')}
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => navigate({ to: '/accounts/$accountId/edit', params: { accountId: account.id } })}
            >
              <Pencil className="mr-1.5 h-4 w-4" />
              {t('common.edit')}
            </Button>
            <Button
              variant="outline"
              size="sm"
              className="text-destructive hover:bg-destructive/10"
              onClick={() => setDeleteOpen(true)}
            >
              <Trash2 className="mr-1.5 h-4 w-4" />
              {t('common.delete')}
            </Button>
          </div>
        }
      />

      {/* Hero card */}
      <HeroCard
        icon={typeIcons[account.account_type] || typeIcons.Other}
        name={account.name}
        subtitle={account.institution || undefined}
      >
        <div className="text-right">
          <div className="text-xs text-muted-foreground">{t('accounts.currentBalance')}</div>
          <div className={`font-display text-3xl font-semibold tracking-tight ${balanceColor}`}>
            {formatCurrency(balanceNum, account.currency_code)}
          </div>
        </div>
      </HeroCard>

      {/* Balance chart */}
      <div className="mb-5 rounded-[14px] border border-border bg-card p-5">
        <div className="mb-3 text-xs font-medium text-muted-foreground">{t('accounts.trend')}</div>
        <DetailBalanceChart accountId={account.id} />
      </div>

      {/* Stat cards */}
      <div className="mb-5 grid grid-cols-2 gap-4 md:grid-cols-4">
        <StatCard label={t('accounts.initialBalance')} value={formatCurrency(initialNum, account.currency_code)} />
        <StatCard label={t('common.currency')} value={account.currency_code} />
        <StatCard
          label={t('accountForm.accountNumber')}
          value={account.account_number || '—'}
        />
        <StatCard
          label={t('accountForm.institution')}
          value={account.institution || '—'}
        />
      </div>

      {/* Two-column layout */}
      <DetailTwoCol
        main={
          <div className="rounded-[14px] border border-border bg-card p-5">
            <h3 className="mb-3 text-sm font-medium">{t('accounts.accountTransactions')}</h3>
            <TransactionList
              transactions={transactions}
              accountId={account.id}
              currencyCode={account.currency_code}
              isLoading={isLoadingTx}
            />
          </div>
        }
        side={
          <div className="space-y-4 rounded-[14px] border border-border bg-card p-5">
            {/* Type badge */}
            <div>
              <div className="mb-1 text-xs text-muted-foreground">{t('accounts.accountType')}</div>
              <Badge className={typeBadgeColors[account.account_type] || typeBadgeColors.Other}>
                {t(typeLabels[account.account_type] || typeLabels.Other)}
              </Badge>
            </div>

            <Separator />

            {/* Status */}
            <div>
              <div className="mb-1 text-xs text-muted-foreground">{t('common.type')}</div>
              <div className="text-sm font-medium">
                {t(`account.status.${account.status}`, account.status)}
              </div>
            </div>

            {/* Credit card fields */}
            {account.account_type === 'CreditCard' && (
              <>
                <Separator />
                {account.credit_limit != null && (
                  <div>
                    <div className="mb-1 text-xs text-muted-foreground">
                      {t('accounts.fields.creditLimit')}
                    </div>
                    <div className="text-sm font-medium">
                      {formatCurrency(account.credit_limit, account.currency_code)}
                    </div>
                  </div>
                )}
                {account.billing_day != null && (
                  <div>
                    <div className="mb-1 text-xs text-muted-foreground">
                      {t('accounts.fields.billingDay')}
                    </div>
                    <div className="text-sm font-medium">{account.billing_day}</div>
                  </div>
                )}
                {account.payment_due_day != null && (
                  <div>
                    <div className="mb-1 text-xs text-muted-foreground">
                      {t('accounts.fields.paymentDueDay')}
                    </div>
                    <div className="text-sm font-medium">{account.payment_due_day}</div>
                  </div>
                )}
              </>
            )}

            {/* Interest rate */}
            {account.interest_rate != null && (
              <>
                <Separator />
                <div>
                  <div className="mb-1 text-xs text-muted-foreground">
                    {t('accounts.fields.interestRate')}
                  </div>
                  <div className="text-sm font-medium">{account.interest_rate}%</div>
                </div>
              </>
            )}
          </div>
        }
      />

      {/* Delete dialog */}
      <DeleteAccountDialog
        account={account}
        open={deleteOpen}
        onOpenChange={(open) => {
          setDeleteOpen(open);
          if (!open) {
            navigate({ to: '/accounts' });
          }
        }}
      />
    </PageShell>
  );
}
