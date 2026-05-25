import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { ArrowDown, ArrowUp, Copy, Pencil, Search, Trash2 } from 'lucide-react';
import { useMemo, useState } from 'react';
import { toast } from 'sonner';
import { useTranslation } from 'react-i18next';
import { AccountForm } from '../components/AccountForm';
import { Button } from '../components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '../components/ui/dialog';
import { Input } from '../components/ui/input';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../components/ui/select';
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
import { Tabs, TabsList, TabsTrigger } from '../components/ui/tabs';
import { getUserFriendlyError } from '../lib/error-handler';
import {
  createAccount,
  deleteAccount,
  listAccounts,
  listAccountsWithBalances,
  updateAccount,
  type AccountDto,
  type CreateAccountDto,
  type UpdateAccountDto,
} from '../lib/tauri/account';

export function AccountsPage() {
  const [isSheetOpen, setIsSheetOpen] = useState(false);
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);
  const [editingAccount, setEditingAccount] = useState<AccountDto | null>(null);
  const [copyingAccount, setCopyingAccount] = useState<AccountDto | null>(null);
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  const [ownershipTab, setOwnershipTab] = useState<'all' | 'own' | 'external'>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [typeFilter, setTypeFilter] = useState<string>('all');
  const [sortColumn, setSortColumn] = useState<'name' | 'type' | 'initialBalance' | 'balance'>('name');
  const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('asc');

  const { data: accounts = [], isLoading } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccountsWithBalances,
  });

  const filteredAndSortedAccounts = useMemo(() => {
    let result = accounts;

    // Tab filter (ownership)
    if (ownershipTab !== 'all') {
      result = result.filter((a) => a.ownership === ownershipTab);
    }

    // Search filter (name)
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      result = result.filter((a) => a.name.toLowerCase().includes(q));
    }

    // Type filter
    if (typeFilter !== 'all') {
      result = result.filter((a) => a.account_type === typeFilter);
    }

    // Sort
    result = [...result].sort((a, b) => {
      let cmp = 0;
      if (sortColumn === 'name') {
        cmp = a.name.localeCompare(b.name);
      } else if (sortColumn === 'type') {
        cmp = a.account_type.localeCompare(b.account_type);
      } else if (sortColumn === 'initialBalance') {
        cmp = a.initial_balance - b.initial_balance;
      } else if (sortColumn === 'balance') {
        cmp = a.current_balance - b.current_balance;
      }
      return sortDirection === 'asc' ? cmp : -cmp;
    });

    return result;
  }, [accounts, ownershipTab, searchQuery, typeFilter, sortColumn, sortDirection]);

  const createMutation = useMutation({
    mutationFn: createAccount,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      setIsSheetOpen(false);
      toast.success(t('accounts.accountCreated'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, dto }: { id: string; dto: UpdateAccountDto }) => updateAccount(id, dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      setIsSheetOpen(false);
      setEditingAccount(null);
      toast.success(t('accounts.accountUpdated'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });

  const deleteMutation = useMutation({
    mutationFn: deleteAccount,
    onMutate: async (accountId) => {
      await queryClient.cancelQueries({ queryKey: ['accounts'] });
      const previousAccounts = queryClient.getQueryData<AccountDto[]>(['accounts']);
      if (previousAccounts) {
        queryClient.setQueryData<AccountDto[]>(
          ['accounts'],
          previousAccounts.filter((account) => account.id !== accountId)
        );
      }
      return { previousAccounts };
    },
    onSuccess: () => {
      setDeleteConfirmId(null);
      toast.success(t('accounts.accountDeleted'));
    },
    onError: (error, _accountId, context) => {
      if (context?.previousAccounts) {
        queryClient.setQueryData(['accounts'], context.previousAccounts);
      }
      toast.error(getUserFriendlyError(error));
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
    },
  });

  const handleCreateClick = () => {
    setEditingAccount(null);
    setCopyingAccount(null);
    setIsSheetOpen(true);
  };

  const handleCreateAccount = (data: CreateAccountDto | { id: string; dto: UpdateAccountDto }) => {
    if ('account_type' in data) {
      createMutation.mutate(data);
    }
  };

  const handleEditClick = (account: AccountDto) => {
    setEditingAccount(account);
    setIsSheetOpen(true);
  };

  const handleCopyClick = (account: AccountDto) => {
    setEditingAccount(null);
    setCopyingAccount(account);
    setIsSheetOpen(true);
  };

  const handleEditSubmit = (data: CreateAccountDto | { id: string; dto: UpdateAccountDto }) => {
    if ('id' in data) {
      updateMutation.mutate({ id: data.id, dto: data.dto });
    }
  };

  const handleDeleteAccount = (id: string) => {
    deleteMutation.mutate(id);
  };

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">{t('accounts.title')}</h1>
        <Button variant="default-gradient" onClick={handleCreateClick}>{t('accounts.createAccount')}</Button>
      </div>

      <Tabs value={ownershipTab} onValueChange={(v) => setOwnershipTab(v as typeof ownershipTab)} className="mb-4">
        <TabsList>
          <TabsTrigger value="all">{t('common.all')}</TabsTrigger>
          <TabsTrigger value="own">{t('accountForm.ownAccount')}</TabsTrigger>
          <TabsTrigger value="external">{t('accountForm.externalAccount')}</TabsTrigger>
        </TabsList>
      </Tabs>

      <div className="flex items-center gap-3 mb-4">
        <div className="relative flex-1 max-w-xs">
          <Search className="absolute left-2 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground" />
          <Input
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder={t('accounts.searchPlaceholder')}
            className="pl-7 h-8 text-sm"
          />
        </div>
        <Select value={typeFilter} onValueChange={(v) => setTypeFilter(v ?? 'all')}>
          <SelectTrigger className="w-36 h-8 text-sm">
            <SelectValue placeholder={t('accounts.filterByType')} />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">{t('common.all')}</SelectItem>
            <SelectItem value="Cash">{t('accountForm.cash')}</SelectItem>
            <SelectItem value="Bank">{t('accountForm.bank')}</SelectItem>
            <SelectItem value="CreditCard">{t('accountForm.creditCard')}</SelectItem>
            <SelectItem value="Investment">{t('accountForm.investment')}</SelectItem>
            <SelectItem value="Loan">{t('accountForm.loan')}</SelectItem>
            <SelectItem value="Income">{t('accountForm.income')}</SelectItem>
            <SelectItem value="Expense">{t('accountForm.expense')}</SelectItem>
            <SelectItem value="Other">{t('accountForm.other')}</SelectItem>
          </SelectContent>
        </Select>
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <div className="text-neutral-500">{t('accounts.loadingAccounts')}</div>
        </div>
      ) : accounts.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <p className="text-neutral-500 mb-4">{t('accounts.noAccounts')}</p>
          <Button onClick={handleCreateClick}>{t('accounts.noAccountsDesc')}</Button>
        </div>
      ) : (
        <div className="border rounded-lg">
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
                <TableHead
                  className="cursor-pointer select-none"
                  onClick={() => {
                    if (sortColumn === 'type') {
                      setSortDirection(d => d === 'asc' ? 'desc' : 'asc');
                    } else {
                      setSortColumn('type');
                      setSortDirection('asc');
                    }
                  }}
                >
                  <span className="inline-flex items-center gap-1">
                    {t('common.type')}
                    {sortColumn === 'type' && (
                      sortDirection === 'asc' ? <ArrowUp className="h-3 w-3" /> : <ArrowDown className="h-3 w-3" />
                    )}
                  </span>
                </TableHead>
                <TableHead>{t('common.currency')}</TableHead>
                <TableHead
                  className="cursor-pointer select-none text-right"
                  onClick={() => {
                    if (sortColumn === 'initialBalance') {
                      setSortDirection(d => d === 'asc' ? 'desc' : 'asc');
                    } else {
                      setSortColumn('initialBalance');
                      setSortDirection('asc');
                    }
                  }}
                >
                  <span className="inline-flex items-center gap-1">
                    {t('accounts.initialBalance')}
                    {sortColumn === 'initialBalance' && (
                      sortDirection === 'asc' ? <ArrowUp className="h-3 w-3" /> : <ArrowDown className="h-3 w-3" />
                    )}
                  </span>
                </TableHead>
                <TableHead
                  className="cursor-pointer select-none text-right"
                  onClick={() => {
                    if (sortColumn === 'balance') {
                      setSortDirection(d => d === 'asc' ? 'desc' : 'asc');
                    } else {
                      setSortColumn('balance');
                      setSortDirection('asc');
                    }
                  }}
                >
                  <span className="inline-flex items-center gap-1">
                    {t('accounts.currentBalance')}
                    {sortColumn === 'balance' && (
                      sortDirection === 'asc' ? <ArrowUp className="h-3 w-3" /> : <ArrowDown className="h-3 w-3" />
                    )}
                  </span>
                </TableHead>
                <TableHead className="w-[100px]">{t('common.actions')}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filteredAndSortedAccounts.map((account: AccountDto) => (
                <TableRow key={account.id}>
                  <TableCell className="font-medium">{account.name}</TableCell>
                  <TableCell>{account.account_type}</TableCell>
                  <TableCell>{account.currency_code}</TableCell>
                  <TableCell className="text-right">
                    {Number(account.initial_balance).toLocaleString('en-US', {
                      minimumFractionDigits: 2,
                      maximumFractionDigits: 2,
                    })}
                  </TableCell>
                  <TableCell className="text-right">
                    {Number(account.current_balance).toLocaleString('en-US', {
                      minimumFractionDigits: 2,
                      maximumFractionDigits: 2,
                    })}
                  </TableCell>
                  <TableCell>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => handleCopyClick(account)}
                      title={t('accounts.copyToCreate')}
                    >
                      <Copy className="h-4 w-4 text-gray-500" />
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => handleEditClick(account)}
                    >
                      <Pencil className="h-4 w-4 text-blue-500" />
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => setDeleteConfirmId(account.id)}
                    >
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}

      <Sheet open={isSheetOpen && !editingAccount} onOpenChange={(open) => { setIsSheetOpen(open); if (!open) { setEditingAccount(null); setCopyingAccount(null); } }}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{copyingAccount ? t('accounts.copyToCreate') : t('accounts.createAccount')}</SheetTitle>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto -mx-4 px-4">
            <AccountForm
              initialData={copyingAccount ?? undefined}
              onSubmit={handleCreateAccount}
              onCancel={() => { setIsSheetOpen(false); setEditingAccount(null); setCopyingAccount(null); }}
              isLoading={createMutation.isPending}
            />
          </div>
        </SheetContent>
      </Sheet>

      {/* Edit Sheet */}
      <Sheet open={isSheetOpen && !!editingAccount} onOpenChange={(open) => { setIsSheetOpen(open); if (!open) setEditingAccount(null); }}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{t('accounts.editAccount')}</SheetTitle>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto -mx-4 px-4">
            {editingAccount && (
              <AccountForm
                mode="edit"
                initialData={editingAccount}
                onSubmit={handleEditSubmit}
                onCancel={() => { setIsSheetOpen(false); setEditingAccount(null); }}
                isLoading={updateMutation.isPending}
              />
            )}
          </div>
        </SheetContent>
      </Sheet>

      <Dialog open={!!deleteConfirmId} onOpenChange={() => setDeleteConfirmId(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('accounts.deleteAccount')}</DialogTitle>
            <DialogDescription>
              {t('accounts.deleteConfirm')}
            </DialogDescription>
          </DialogHeader>
          <div className="flex justify-end gap-2 pt-4">
            <Button variant="outline" onClick={() => setDeleteConfirmId(null)}>
              {t('common.cancel')}
            </Button>
            <Button
              variant="destructive"
              onClick={() => deleteConfirmId && handleDeleteAccount(deleteConfirmId)}
              disabled={deleteMutation.isPending}
            >
              {deleteMutation.isPending ? t('accounts.deleting') : t('common.delete')}
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}
