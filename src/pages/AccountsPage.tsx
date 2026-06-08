import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from '@tanstack/react-router';
import {
  Copy, Pencil, Search, Trash2, Wallet,
  Landmark, HandCoins, ArrowRightLeft, PiggyBank,
  Layers, Banknote, Receipt, CreditCard, TrendingUp, PlusCircle,
  Archive, EyeOff, RotateCcw,
} from 'lucide-react';
import { useMemo, useState } from 'react';
import { toast } from 'sonner';
import { useTranslation } from 'react-i18next';
import { AccountForm } from '../components/AccountForm';
import { AccountWizard } from '../components/AccountWizard';
import { DeleteAccountDialog } from '../components/DeleteAccountDialog';
import { TopUpDialog } from '../components/TopUpDialog';
import { PrepaidDetailPanel } from '../components/PrepaidDetailPanel';
import { Button } from '../components/ui/button';
import { LineChart, Line, ResponsiveContainer } from 'recharts';
import { useAccountBalanceHistory } from '../hooks/useAccountBalanceHistory';
import { Input } from '../components/ui/input';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from '../components/ui/sheet';
import { getUserFriendlyError } from '../lib/error-handler';
import { formatCurrencyWithDto } from '../lib/currency';
import { useCurrencies } from '../hooks/useCurrency';
import {
  createAccount,
  listAccountsWithBalances,
  archiveAccount,
  hideAccount,
  reactivateAccount,
  type AccountDto,
  type CreateAccountDto,
} from '../lib/tauri/account';
import type { CurrencyDto } from '../lib/tauri/currency';
import { PageShell } from '../components/patterns/layout/PageShell';
import { PageHeader } from '../components/patterns/layout/PageHeader';
import { StatCard } from '../components/patterns/cards/StatCard';
import { FilterBar } from '../components/patterns/layout/FilterBar';
import { DataCard } from '../components/patterns/cards/DataCard';

const TYPE_ORDER: { key: string; labelKey: string; icon: React.ReactNode }[] = [
  { key: 'Cash', labelKey: 'accountForm.cashWithChinese', icon: <Wallet className="h-4 w-4" /> },
  { key: 'Bank', labelKey: 'accountForm.bankWithChinese', icon: <Landmark className="h-4 w-4" /> },
  { key: 'CreditCard', labelKey: 'accountForm.creditCardWithChinese', icon: <CreditCard className="h-4 w-4" /> },
  { key: 'Investment', labelKey: 'accountForm.investmentWithChinese', icon: <TrendingUp className="h-4 w-4" /> },
  { key: 'BorrowedOut', labelKey: 'accountForm.borrowedOutWithChinese', icon: <HandCoins className="h-4 w-4" /> },
  { key: 'BorrowedIn', labelKey: 'accountForm.borrowedInWithChinese', icon: <ArrowRightLeft className="h-4 w-4" /> },
  { key: 'Prepaid', labelKey: 'accountForm.prepaidWithChinese', icon: <PiggyBank className="h-4 w-4" /> },
  { key: 'Other', labelKey: 'accountForm.otherWithChinese', icon: <Layers className="h-4 w-4" /> },
  { key: 'Income', labelKey: 'accountForm.incomeWithChinese', icon: <Banknote className="h-4 w-4" /> },
  { key: 'Expense', labelKey: 'accountForm.expenseWithChinese', icon: <Receipt className="h-4 w-4" /> },
];

function BalanceSparkline({ accountId }: { accountId: string }) {
  const { data } = useAccountBalanceHistory(accountId, 30);
  if (!data || data.length < 2) return null;

  const chartData = data.map(d => ({ ...d, balance: Number(d.balance) }));
  const first = chartData[0]?.balance ?? 0;
  const last = chartData[chartData.length - 1]?.balance ?? 0;
  const color = last >= first ? '#10B981' : '#EF4444';

  return (
    <ResponsiveContainer width={80} height={30}>
      <LineChart data={chartData}>
        <Line type="monotone" dataKey="balance" stroke={color} dot={false} strokeWidth={1.5} />
      </LineChart>
    </ResponsiveContainer>
  );
}

function AccountGroupCards({
  title,
  icon,
  accounts,
  currencies,
  onEdit,
  onCopy,
  onDelete,
  onNavigateToDetail,
  onTopUp,
  onRecordTransaction,
  onArchive,
  onHide,
  onReactivate,
  t,
}: {
  title: string;
  icon: React.ReactNode;
  accounts: AccountDto[];
  currencies: CurrencyDto[];
  onEdit: (a: AccountDto) => void;
  onCopy: (a: AccountDto) => void;
  onDelete: (a: AccountDto) => void;
  onNavigateToDetail: (id: string) => void;
  onTopUp: (id: string) => void;
  onRecordTransaction?: (accountId: string) => void;
  onArchive: (id: string) => void;
  onHide: (id: string) => void;
  onReactivate: (id: string) => void;
  t: (k: string) => string;
}) {
  if (accounts.length === 0) return null;

  return (
    <div className="mb-8">
      <div className="flex items-center justify-between border-b border-border pb-2.5 mb-3.5">
        <h2 className="flex items-center gap-2 text-base font-semibold">
          <span className="text-primary">{icon}</span>
          {title}
        </h2>
        <span className="font-mono text-sm text-muted-foreground">
          {accounts.length}
        </span>
      </div>
      <div className="grid grid-cols-[repeat(auto-fill,minmax(280px,1fr))] gap-3.5">
        {accounts.map((account) => {
          const currency = currencies.find(c => c.code === account.currency_code) || {
            id: '', code: account.currency_code, name: account.currency_code,
            symbol: account.currency_code, exchange_rate: '1', is_active: true, updated_at: '',
          };
          return (
            <DataCard
              key={account.id}
              onClick={() => onNavigateToDetail(account.id)}
            >
              <div className="flex items-start justify-between mb-3">
                <div className="flex items-center gap-2.5">
                  <span className="text-2xl">{account.icon}</span>
                  <div>
                    <div className="font-medium text-sm">{account.name}</div>
                    <div className="text-[11px] text-muted-foreground">
                      {t(`accountForm.${account.account_type.toLowerCase()}`)}
                      {account.status !== 'active' && (
                        <span className="ml-1.5 text-amber-600">
                          ({account.status === 'archived' ? t('accounts.archived') : t('accounts.hidden')})
                        </span>
                      )}
                    </div>
                  </div>
                </div>
                <span className="text-[11px] font-mono text-muted-foreground">{account.currency_code}</span>
              </div>
              <div className="mb-3">
                <div className="font-display text-[22px] font-semibold tracking-tight">
                  {formatCurrencyWithDto(Number(account.current_balance), currency)}
                </div>
                <div className="mt-1 h-8">
                  <BalanceSparkline accountId={account.id} />
                </div>
              </div>
              <div className="flex items-center gap-1 pt-2 border-t border-border">
                {onRecordTransaction && (
                  <Button variant="ghost" size="sm" className="h-7 w-7 p-0"
                    onClick={(e) => { e.stopPropagation(); onRecordTransaction(account.id); }}
                    title={t('transactions.recordTransaction')}>
                    <PlusCircle className="h-3.5 w-3.5 text-income" />
                  </Button>
                )}
                {account.account_type === 'Prepaid' && (
                  <Button variant="ghost" size="sm" className="h-7 w-7 p-0"
                    onClick={(e) => { e.stopPropagation(); onTopUp(account.id); }}
                    title={t('prepaid.topUpTitle')}>
                    <Wallet className="h-3.5 w-3.5 text-income" />
                  </Button>
                )}
                <Button variant="ghost" size="sm" className="h-7 w-7 p-0"
                  onClick={(e) => { e.stopPropagation(); onCopy(account); }}
                  title={t('accounts.copyToCreate')}>
                  <Copy className="h-3.5 w-3.5 text-muted-foreground" />
                </Button>
                {account.status === 'active' && (
                  <>
                    <Button variant="ghost" size="sm" className="h-7 w-7 p-0"
                      onClick={(e) => { e.stopPropagation(); onArchive(account.id); }}
                      title={t('accounts.archiveAccount')}>
                      <Archive className="h-3.5 w-3.5 text-amber-600" />
                    </Button>
                    <Button variant="ghost" size="sm" className="h-7 w-7 p-0"
                      onClick={(e) => { e.stopPropagation(); onHide(account.id); }}
                      title={t('accounts.hideAccount')}>
                      <EyeOff className="h-3.5 w-3.5 text-muted-foreground" />
                    </Button>
                  </>
                )}
                {(account.status === 'archived' || account.status === 'hidden') && (
                  <Button variant="ghost" size="sm" className="h-7 w-7 p-0"
                    onClick={(e) => { e.stopPropagation(); onReactivate(account.id); }}
                    title={t('accounts.reactivateAccount')}>
                    <RotateCcw className="h-3.5 w-3.5 text-income" />
                  </Button>
                )}
                <Button variant="ghost" size="sm" className="h-7 w-7 p-0 ml-auto"
                  onClick={(e) => { e.stopPropagation(); onEdit(account); }}
                  title={t('accounts.editAccount')}>
                  <Pencil className="h-3.5 w-3.5 text-muted-foreground" />
                </Button>
                <Button variant="ghost" size="sm" className="h-7 w-7 p-0"
                  onClick={(e) => { e.stopPropagation(); onDelete(account); }}
                  title={t('common.delete')}>
                  <Trash2 className="h-3.5 w-3.5 text-expense" />
                </Button>
              </div>
            </DataCard>
          );
        })}
      </div>
    </div>
  );
}

export function AccountsPage() {
  const navigate = useNavigate();
  const [isSheetOpen, setIsSheetOpen] = useState(false);
  const [showWizard, setShowWizard] = useState(false);
  const [deletingAccount, setDeletingAccount] = useState<AccountDto | null>(null);
  const [copyingAccount, setCopyingAccount] = useState<AccountDto | null>(null);
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  const [searchQuery, setSearchQuery] = useState('');
  const [typeFilter, setTypeFilter] = useState<string>('all');
  const [showArchivedHidden, setShowArchivedHidden] = useState(false);

  // Prepaid-specific state
  const [topUpAccountId, setTopUpAccountId] = useState<string | null>(null);
  const [detailAccountId, setDetailAccountId] = useState<string | null>(null);

  const { data: accounts = [], isLoading } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccountsWithBalances,
  });

  const { data: currencies = [] } = useCurrencies();

  const summary = useMemo(() => {
    const ownAccounts = accounts.filter((a) => a.ownership === 'own');
    const liabilityAccounts = accounts.filter((a) => a.ownership === 'liability');
    const totalAssets = ownAccounts.reduce((sum, a) => sum + Number(a.current_balance), 0);
    const totalLiabilities = liabilityAccounts.reduce((sum, a) => sum + Number(a.current_balance), 0);
    const netWorth = totalAssets + totalLiabilities;
    return { totalAssets, totalLiabilities, netWorth };
  }, [accounts]);

  const primaryCurrency = currencies[0] || { id: '', code: 'CNY', name: 'CNY', symbol: '¥', exchange_rate: '1', is_active: true, updated_at: '' };

  const typeGroups = useMemo(() => {
    let filtered = accounts;

    if (!showArchivedHidden) {
      filtered = filtered.filter((a) => a.status === 'active');
    }

    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      filtered = filtered.filter((a) => a.name.toLowerCase().includes(q));
    }

    if (typeFilter !== 'all') {
      filtered = filtered.filter((a) => a.account_type === typeFilter);
    }

    const sorted = [...filtered].sort((a, b) => a.name.localeCompare(b.name));

    // Group by account_type
    const groups = new Map<string, AccountDto[]>();
    for (const account of sorted) {
      const list = groups.get(account.account_type) ?? [];
      list.push(account);
      groups.set(account.account_type, list);
    }

    return groups;
  }, [accounts, searchQuery, typeFilter, showArchivedHidden]);

  const copyCreateMutation = useMutation({
    mutationFn: createAccount,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      setIsSheetOpen(false);
      setCopyingAccount(null);
      toast.success(t('accounts.accountCreated'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });

  const archiveMutation = useMutation({
    mutationFn: archiveAccount,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      toast.success(t('accounts.archived'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });

  const hideMutation = useMutation({
    mutationFn: hideAccount,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      toast.success(t('accounts.hidden'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });

  const reactivateMutation = useMutation({
    mutationFn: reactivateAccount,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      toast.success(t('accounts.reactivated'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });

  const handleCreateClick = () => {
    setShowWizard(true);
  };

  const handleEditClick = (account: AccountDto) => {
    navigate({ to: '/accounts/$accountId/edit', params: { accountId: account.id } });
  };

  const handleCopyClick = (account: AccountDto) => {
    setCopyingAccount(account);
    setIsSheetOpen(true);
  };

  const filterOptions = useMemo(() => [
    { label: t('common.all'), value: 'all' },
    ...TYPE_ORDER.map(type => ({
      label: t(type.labelKey),
      value: type.key,
    })),
  ], [t]);

  if (isLoading) {
    return (
      <PageShell>
        <PageHeader
          title={t('accounts.title')}
          actions={
            <Button onClick={handleCreateClick}>
              <PlusCircle className="mr-1.5 h-4 w-4" />
              {t('accounts.createAccount')}
            </Button>
          }
        />
        <div className="flex items-center justify-center py-12">
          <div className="text-neutral-500">{t('accounts.loadingAccounts')}</div>
        </div>
      </PageShell>
    );
  }

  return (
    <PageShell>
      <PageHeader
        title={t('accounts.title')}
        actions={
          <Button onClick={handleCreateClick}>
            <PlusCircle className="mr-1.5 h-4 w-4" />
            {t('accounts.createAccount')}
          </Button>
        }
      />

      {/* Summary Cards */}
      {accounts.length > 0 && (
        <div className="grid grid-cols-3 gap-3.5 mb-7">
          <StatCard
            label={t('accounts.totalAssets')}
            value={formatCurrencyWithDto(summary.totalAssets, primaryCurrency)}
            tagVariant="positive"
          />
          <StatCard
            label={t('accounts.totalLiabilities')}
            value={formatCurrencyWithDto(summary.totalLiabilities, primaryCurrency)}
            tagVariant="negative"
          />
          <StatCard
            label={t('accounts.netWorth')}
            value={formatCurrencyWithDto(summary.netWorth, primaryCurrency)}
          />
        </div>
      )}

      {/* Search + Archive toggle */}
      <div className="flex items-center gap-3 mb-4">
        <div className="relative max-w-xs w-full">
          <Search className="absolute left-2 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground" />
          <Input
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder={t('accounts.searchPlaceholder')}
            className="pl-7 h-8 text-sm"
          />
        </div>
        <Button
          variant={showArchivedHidden ? 'default' : 'outline'}
          size="sm"
          className="h-8 text-xs shrink-0"
          onClick={() => setShowArchivedHidden(!showArchivedHidden)}
        >
          <Archive className="h-3.5 w-3.5 mr-1" />
          {showArchivedHidden ? t('accounts.hideArchived') : t('accounts.showArchived')}
        </Button>
      </div>

      {/* Type filter */}
      <FilterBar
        options={filterOptions}
        value={typeFilter}
        onChange={setTypeFilter}
      />

      {accounts.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <p className="text-neutral-500 mb-4">{t('accounts.noAccounts')}</p>
          <Button onClick={handleCreateClick}>{t('accounts.noAccountsDesc')}</Button>
        </div>
      ) : typeGroups.size === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <p className="text-neutral-500">{t('common.noResults')}</p>
        </div>
      ) : (
        <>
          {TYPE_ORDER.map((type) => {
            const groupAccounts = typeGroups.get(type.key);
            if (!groupAccounts || groupAccounts.length === 0) return null;
            return (
              <AccountGroupCards
                key={type.key}
                title={t(type.labelKey)}
                icon={type.icon}
                accounts={groupAccounts}
                currencies={currencies}
                onEdit={handleEditClick}
                onCopy={handleCopyClick}
                onDelete={setDeletingAccount}
                onNavigateToDetail={(id) => navigate({ to: '/accounts/$accountId', params: { accountId: id } })}
                onTopUp={setTopUpAccountId}
                onRecordTransaction={(accountId) => navigate({ to: '/transactions/new', search: { accountId } })}
                onArchive={(id) => archiveMutation.mutate(id)}
                onHide={(id) => hideMutation.mutate(id)}
                onReactivate={(id) => reactivateMutation.mutate(id)}
                t={t}
              />
            );
          })}
        </>
      )}

      {/* Create Wizard */}
      <AccountWizard open={showWizard} onOpenChange={setShowWizard} />

      {/* Copy Sheet */}
      <Sheet open={isSheetOpen && !!copyingAccount} onOpenChange={(open) => { setIsSheetOpen(open); if (!open) { setCopyingAccount(null); } }}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{t('accounts.copyToCreate')}</SheetTitle>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto -mx-4 px-4">
            {copyingAccount && (
              <AccountForm
                initialData={copyingAccount}
                onSubmit={(data) => {
                  if ('account_type' in data) {
                    copyCreateMutation.mutate(data as CreateAccountDto);
                  }
                }}
                onCancel={() => { setIsSheetOpen(false); setCopyingAccount(null); }}
                isLoading={copyCreateMutation.isPending}
              />
            )}
          </div>
        </SheetContent>
      </Sheet>

      {/* Delete Account Dialog */}
      <DeleteAccountDialog
        account={deletingAccount}
        open={!!deletingAccount}
        onOpenChange={(open) => { if (!open) setDeletingAccount(null); }}
      />

      {/* Prepaid: Top Up Dialog */}
      {topUpAccountId && (
        <TopUpDialog
          accountId={topUpAccountId}
          accountName={accounts.find(a => a.id === topUpAccountId)?.name || ''}
          open={!!topUpAccountId}
          onOpenChange={(open) => { if (!open) setTopUpAccountId(null); }}
        />
      )}

      {/* Prepaid: Detail Panel */}
      {detailAccountId && (
        <PrepaidDetailPanel
          accountId={detailAccountId}
          open={!!detailAccountId}
          onOpenChange={(open) => { if (!open) setDetailAccountId(null); }}
        />
      )}
    </PageShell>
  );
}
