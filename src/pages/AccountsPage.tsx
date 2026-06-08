import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from '@tanstack/react-router';
import {
  ArrowDown, ArrowUp, Copy, Pencil, Search, Trash2, Wallet, Eye,
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
import { AccountDetailPanel } from '../components/AccountDetailPanel';
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
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '../components/ui/table';
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

function AccountGroupTable({
  title,
  icon,
  accounts,
  currencies,
  onEdit,
  onCopy,
  onDelete,
  onView,
  onTopUp,
  onDetail,
  onRecordTransaction,
  onArchive,
  onHide,
  onReactivate,
  sortColumn,
  sortDirection,
  setSortColumn,
  setSortDirection,
  t,
}: {
  title: string;
  icon: React.ReactNode;
  accounts: AccountDto[];
  currencies: CurrencyDto[];
  onEdit: (a: AccountDto) => void;
  onCopy: (a: AccountDto) => void;
  onDelete: (a: AccountDto) => void;
  onView: (a: AccountDto) => void;
  onTopUp: (id: string) => void;
  onDetail: (id: string) => void;
  onRecordTransaction?: (accountId: string) => void;
  onArchive: (id: string) => void;
  onHide: (id: string) => void;
  onReactivate: (id: string) => void;
  sortColumn: string;
  sortDirection: 'asc' | 'desc';
  setSortColumn: (c: 'name' | 'type' | 'initialBalance' | 'balance') => void;
  setSortDirection: React.Dispatch<React.SetStateAction<'asc' | 'desc'>>;
  t: (k: string) => string;
}) {
  if (accounts.length === 0) return null;

  return (
    <div className="mb-6">
      <div className="flex items-center gap-2 mb-3">
        {icon}
        <h2 className="text-sm font-semibold uppercase tracking-wider text-muted-foreground">{title}</h2>
        <span className="text-xs text-muted-foreground">({accounts.length})</span>
      </div>
      <div className="border rounded-lg overflow-x-auto">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead
                className="cursor-pointer select-none"
                onClick={() => {
                  if (sortColumn === 'name') {
                    setSortDirection(d => d === 'asc' ? 'desc' : 'asc');
                  } else {
                    setSortColumn('name');
                    setSortDirection('asc');
                  }
                }}
              >
                <span className="inline-flex items-center gap-1">
                  {t('common.name')}
                  {sortColumn === 'name' && (
                    sortDirection === 'asc' ? <ArrowUp className="h-3 w-3" /> : <ArrowDown className="h-3 w-3" />
                  )}
                </span>
              </TableHead>
              <TableHead>{t('common.type')}</TableHead>
              <TableHead>{t('common.currency')}</TableHead>
              <TableHead className="text-right">{t('accounts.currentBalance')}</TableHead>
              <TableHead>{t('accounts.trend')}</TableHead>
              <TableHead className="w-[100px]">{t('common.actions')}</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {accounts.map((account: AccountDto) => (
              <TableRow key={account.id}>
                <TableCell className="font-medium">
                  <div className="flex items-center gap-2">
                    <span className="text-lg">{account.icon}</span>
                    <span>{account.name}</span>
                    {account.status === 'archived' && (
                      <span className="text-xs text-amber-600 bg-amber-50 dark:bg-amber-950/20 px-1.5 py-0.5 rounded">
                        {t('accounts.archived')}
                      </span>
                    )}
                    {account.status === 'hidden' && (
                      <span className="text-xs text-gray-500 bg-gray-100 dark:bg-gray-800 px-1.5 py-0.5 rounded">
                        {t('accounts.hidden')}
                      </span>
                    )}
                    {account.account_type === 'Prepaid' && account.low_balance_threshold != null && Number(account.current_balance) < Number(account.low_balance_threshold) && (
                      <span className="text-xs text-red-500 font-normal">
                        {t('prepaid.lowBalanceWarning')}
                      </span>
                    )}
                  </div>
                </TableCell>
                <TableCell>{t(`accountForm.${account.account_type.toLowerCase()}`)}</TableCell>
                <TableCell>{account.currency_code}</TableCell>
                <TableCell className="text-right">
                  {formatCurrencyWithDto(
                    Number(account.current_balance),
                    currencies.find(c => c.code === account.currency_code) || {
                      id: '',
                      code: account.currency_code,
                      name: account.currency_code,
                      symbol: account.currency_code,
                      exchange_rate: '1',
                      is_active: true,
                      updated_at: '',
                    }
                  )}
                </TableCell>
                <TableCell>
                  <BalanceSparkline accountId={account.id} />
                </TableCell>
                <TableCell>
                  <div className="flex gap-1">
                    {onRecordTransaction && (
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => onRecordTransaction(account.id)}
                        title={t('transactions.recordTransaction')}
                      >
                        <PlusCircle className="h-4 w-4 text-emerald-600" />
                      </Button>
                    )}
                    {account.account_type === 'Prepaid' ? (
                      <>
                        <Button variant="ghost" size="sm" onClick={() => onTopUp(account.id)} title={t('prepaid.topUpTitle')}>
                          <Wallet className="h-4 w-4 text-emerald-500" />
                        </Button>
                        <Button variant="ghost" size="sm" onClick={() => onDetail(account.id)} title={t('prepaid.detailTitle')}>
                          <Eye className="h-4 w-4 text-purple-500" />
                        </Button>
                      </>
                    ) : (
                      <Button variant="ghost" size="sm" onClick={() => onView(account)} title={t('debts.view')}>
                        <Eye className="h-4 w-4 text-purple-500" />
                      </Button>
                    )}
                    <Button variant="ghost" size="sm" onClick={() => onCopy(account)} title={t('accounts.copyToCreate')}>
                      <Copy className="h-4 w-4 text-gray-500" />
                    </Button>
                    {account.status === 'active' && (
                      <>
                        <Button variant="ghost" size="sm" onClick={() => onArchive(account.id)} title={t('accounts.archiveAccount')}>
                          <Archive className="h-4 w-4 text-amber-600" />
                        </Button>
                        <Button variant="ghost" size="sm" onClick={() => onHide(account.id)} title={t('accounts.hideAccount')}>
                          <EyeOff className="h-4 w-4 text-gray-400" />
                        </Button>
                      </>
                    )}
                    {(account.status === 'archived' || account.status === 'hidden') && (
                      <Button variant="ghost" size="sm" onClick={() => onReactivate(account.id)} title={t('accounts.reactivateAccount')}>
                        <RotateCcw className="h-4 w-4 text-emerald-500" />
                      </Button>
                    )}
                    <Button variant="ghost" size="sm" onClick={() => onEdit(account)}>
                      <Pencil className="h-4 w-4 text-blue-500" />
                    </Button>
                    <Button variant="ghost" size="sm" onClick={() => onDelete(account)}>
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  </div>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
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
  const [sortColumn, setSortColumn] = useState<'name' | 'type' | 'initialBalance' | 'balance'>('name');
  const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('asc');
  const [showArchivedHidden, setShowArchivedHidden] = useState(false);

  // Prepaid-specific state
  const [topUpAccountId, setTopUpAccountId] = useState<string | null>(null);
  const [detailAccountId, setDetailAccountId] = useState<string | null>(null);
  const [detailAccount, setDetailAccount] = useState<AccountDto | null>(null);

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

    const sorted = [...filtered].sort((a, b) => {
      let cmp = 0;
      if (sortColumn === 'name') cmp = a.name.localeCompare(b.name);
      else if (sortColumn === 'type') cmp = a.account_type.localeCompare(b.account_type);
      else if (sortColumn === 'initialBalance') cmp = a.initial_balance - b.initial_balance;
      else if (sortColumn === 'balance') cmp = a.current_balance - b.current_balance;
      return sortDirection === 'asc' ? cmp : -cmp;
    });

    // Group by account_type
    const groups = new Map<string, AccountDto[]>();
    for (const account of sorted) {
      const list = groups.get(account.account_type) ?? [];
      list.push(account);
      groups.set(account.account_type, list);
    }

    return groups;
  }, [accounts, searchQuery, typeFilter, sortColumn, sortDirection, showArchivedHidden]);

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

  if (isLoading) {
    return (
      <div className="p-4 sm:p-6">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between mb-4 sm:mb-6">
          <h1 className="text-2xl font-bold sm:text-3xl">{t('accounts.title')}</h1>
          <Button variant="default-gradient" onClick={handleCreateClick}>{t('accounts.createAccount')}</Button>
        </div>
        <div className="flex items-center justify-center py-12">
          <div className="text-neutral-500">{t('accounts.loadingAccounts')}</div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-4 sm:p-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between mb-4 sm:mb-6">
        <h1 className="text-2xl font-bold sm:text-3xl">{t('accounts.title')}</h1>
        <Button variant="default-gradient" onClick={handleCreateClick}>{t('accounts.createAccount')}</Button>
      </div>

      {/* Summary Cards */}
      {accounts.length > 0 && (
        <div className="grid grid-cols-3 gap-3 mb-4">
          <div className="rounded-lg border bg-emerald-50 dark:bg-emerald-950/20 p-3">
            <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('accounts.totalAssets')}</div>
            <div className="text-xl font-bold text-emerald-600 dark:text-emerald-400">
              {formatCurrencyWithDto(summary.totalAssets, primaryCurrency)}
            </div>
          </div>
          <div className="rounded-lg border bg-red-50 dark:bg-red-950/20 p-3">
            <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('accounts.totalLiabilities')}</div>
            <div className="text-xl font-bold text-red-600 dark:text-red-400">
              {formatCurrencyWithDto(summary.totalLiabilities, primaryCurrency)}
            </div>
          </div>
          <div className="rounded-lg border bg-blue-50 dark:bg-blue-950/20 p-3">
            <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('accounts.netWorth')}</div>
            <div className="text-xl font-bold text-blue-600 dark:text-blue-400">
              {formatCurrencyWithDto(summary.netWorth, primaryCurrency)}
            </div>
          </div>
        </div>
      )}

      {/* Search */}
      <div className="relative max-w-xs w-full mb-4">
        <Search className="absolute left-2 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground" />
        <Input
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder={t('accounts.searchPlaceholder')}
          className="pl-7 h-8 text-sm"
        />
      </div>

      {/* Type filter */}
      <div className="flex flex-wrap gap-1.5 mb-4">
        <Button
          variant={typeFilter === 'all' ? 'default' : 'outline'}
          size="sm"
          className="h-7 text-xs"
          onClick={() => setTypeFilter('all')}
        >
          {t('common.all')}
        </Button>
        {TYPE_ORDER.map((type) => {
          const count = typeGroups.get(type.key)?.length ?? 0;
          if (count === 0 && typeFilter === 'all') return null;
          return (
            <Button
              key={type.key}
              variant={typeFilter === type.key ? 'default' : 'outline'}
              size="sm"
              className="h-7 text-xs"
              onClick={() => setTypeFilter(typeFilter === type.key ? 'all' : type.key)}
            >
              {type.icon}
              <span className="ml-1">{t(type.labelKey)}</span>
              <span className="ml-1 text-[10px] opacity-70">({count})</span>
            </Button>
          );
        })}
        <Button
          variant={showArchivedHidden ? 'default' : 'outline'}
          size="sm"
          className="h-7 text-xs ml-auto"
          onClick={() => setShowArchivedHidden(!showArchivedHidden)}
        >
          <Archive className="h-3.5 w-3.5 mr-1" />
          {showArchivedHidden ? t('accounts.hideArchived') : t('accounts.showArchived')}
        </Button>
      </div>

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
              <AccountGroupTable
                key={type.key}
                title={t(type.labelKey)}
                icon={type.icon}
                accounts={groupAccounts}
                currencies={currencies}
                onEdit={handleEditClick}
                onCopy={handleCopyClick}
                onDelete={setDeletingAccount}
                onView={setDetailAccount}
                onTopUp={setTopUpAccountId}
                onDetail={setDetailAccountId}
                onRecordTransaction={(accountId) => navigate({ to: '/transactions/new', search: { accountId } })}
                onArchive={(id) => archiveMutation.mutate(id)}
                onHide={(id) => hideMutation.mutate(id)}
                onReactivate={(id) => reactivateMutation.mutate(id)}
                sortColumn={sortColumn}
                sortDirection={sortDirection}
                setSortColumn={setSortColumn}
                setSortDirection={setSortDirection}
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

      {/* Account Detail Panel */}
      {detailAccount && (
        <AccountDetailPanel
          account={detailAccount}
          open={!!detailAccount}
          onOpenChange={(open) => { if (!open) setDetailAccount(null); }}
        />
      )}
    </div>
  );
}
