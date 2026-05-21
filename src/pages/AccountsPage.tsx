import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Trash2 } from 'lucide-react';
import { useState } from 'react';
import { toast } from 'sonner';
import { useTranslation } from 'react-i18next';
import { useNavigate } from '@tanstack/react-router';
import { AccountForm } from '../components/AccountForm';
import { Button } from '../components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '../components/ui/dialog';
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
import {
  createAccount,
  deleteAccount,
  listAccounts,
  type AccountDto,
  type CreateAccountDto,
} from '../lib/tauri/account';
import { useMediaQuery } from '../hooks/useMediaQuery';

export function AccountsPage() {
  const [isSheetOpen, setIsSheetOpen] = useState(false);
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  const navigate = useNavigate();
  const isWide = useMediaQuery('(min-width: 1024px)');

  const { data: accounts = [], isLoading } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
  });

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
    if (isWide) {
      setIsSheetOpen(true);
    } else {
      navigate({ to: '/accounts/new' });
    }
  };

  const handleCreateAccount = (data: CreateAccountDto) => {
    createMutation.mutate(data);
  };

  const handleDeleteAccount = (id: string) => {
    deleteMutation.mutate(id);
  };

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">{t('accounts.title')}</h1>
        <Button onClick={handleCreateClick}>{t('accounts.createAccount')}</Button>
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
                <TableHead>{t('common.name')}</TableHead>
                <TableHead>{t('common.type')}</TableHead>
                <TableHead>{t('common.currency')}</TableHead>
                <TableHead className="text-right">{t('common.balance')}</TableHead>
                <TableHead className="w-[100px]">{t('common.actions')}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {accounts.map((account: AccountDto) => (
                <TableRow key={account.id}>
                  <TableCell className="font-medium">{account.name}</TableCell>
                  <TableCell>{account.account_type}</TableCell>
                  <TableCell>{account.currency_code}</TableCell>
                  <TableCell className="text-right">
                    {account.balance.toLocaleString('en-US', {
                      minimumFractionDigits: 2,
                      maximumFractionDigits: 2,
                    })}
                  </TableCell>
                  <TableCell>
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

      <Sheet open={isSheetOpen} onOpenChange={setIsSheetOpen}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{t('accounts.createAccount')}</SheetTitle>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto -mx-4 px-4">
            <AccountForm
              onSubmit={handleCreateAccount}
              onCancel={() => setIsSheetOpen(false)}
              isLoading={createMutation.isPending}
            />
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
