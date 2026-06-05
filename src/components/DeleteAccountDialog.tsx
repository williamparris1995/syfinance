import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from './ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from './ui/dialog';
import { getUserFriendlyError } from '../lib/error-handler';
import { deleteAccount, type AccountDto } from '../lib/tauri/account';

interface DeleteAccountDialogProps {
  account: AccountDto | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function DeleteAccountDialog({ account, open, onOpenChange }: DeleteAccountDialogProps) {
  const { t } = useTranslation();
  const queryClient = useQueryClient();

  const deleteMutation = useMutation({
    mutationFn: deleteAccount,
    onMutate: async (accountId) => {
      await queryClient.cancelQueries({ queryKey: ['accounts'] });
      const previousAccounts = queryClient.getQueryData<AccountDto[]>(['accounts']);
      if (previousAccounts) {
        queryClient.setQueryData<AccountDto[]>(
          ['accounts'],
          previousAccounts.filter((a) => a.id !== accountId)
        );
      }
      return { previousAccounts };
    },
    onSuccess: () => {
      toast.success(t('accounts.accountDeleted'));
      onOpenChange(false);
    },
    onError: (error, _accountId, context) => {
      if (context?.previousAccounts) {
        queryClient.setQueryData(['accounts'], context.previousAccounts);
      }
      toast.error(t('accounts.deleteFailed') + ': ' + getUserFriendlyError(error));
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
    },
  });

  if (!account) return null;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('accounts.deleteAccount')}</DialogTitle>
          <DialogDescription>
            {t('accounts.deleteConfirmMessage', { name: account.name, count: 0 })}
          </DialogDescription>
        </DialogHeader>
        <div className="flex justify-end gap-2 pt-4">
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button
            variant="destructive"
            onClick={() => deleteMutation.mutate(account.id)}
            disabled={deleteMutation.isPending}
          >
            {deleteMutation.isPending ? t('accounts.deleting') : t('accounts.deleteConfirmButton')}
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}