import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate, useParams } from '@tanstack/react-router';
import { ArrowLeft } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';

import { AccountForm } from '@/components/AccountForm';
import { Button } from '@/components/ui/button';
import { getUserFriendlyError } from '@/lib/error-handler';
import {
  type CreateAccountDto,
  getAccount,
  updateAccount,
  type UpdateAccountDto,
} from '@/lib/tauri/account';

export function AccountEditPage() {
  const navigate = useNavigate();
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const { accountId } = useParams({ strict: false });

  const { data: account, isLoading, isError } = useQuery({
    queryKey: ['accounts', accountId],
    queryFn: () => getAccount(accountId!),
    enabled: !!accountId,
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, dto }: { id: string; dto: UpdateAccountDto }) => updateAccount(id, dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      navigate({ to: '/accounts' });
      toast.success(t('accounts.accountUpdated'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });

  const handleSubmit = (data: CreateAccountDto | { id: string; dto: UpdateAccountDto }) => {
    if ('id' in data) {
      updateMutation.mutate({ id: data.id, dto: data.dto });
    }
  };

  const header = (
    <div className="flex items-center gap-4 mb-6">
      <Button variant="ghost" size="icon" onClick={() => navigate({ to: '/accounts' })}>
        <ArrowLeft className="h-5 w-5" />
      </Button>
      <h1 className="text-2xl font-bold">{t('accounts.editAccount')}</h1>
    </div>
  );

  if (isLoading) {
    return (
      <div className="p-6 max-w-2xl mx-auto">
        {header}
        <div className="flex items-center justify-center py-12">
          <div className="text-neutral-500">{t('accounts.loadingAccounts')}</div>
        </div>
      </div>
    );
  }

  if (isError) {
    return (
      <div className="p-6 max-w-2xl mx-auto">
        {header}
        <div className="flex items-center justify-center py-12">
          <div className="text-red-500">{t('accounts.loadError')}</div>
        </div>
      </div>
    );
  }

  if (!account) {
    return (
      <div className="p-6 max-w-2xl mx-auto">
        {header}
        <div className="flex items-center justify-center py-12">
          <div className="text-neutral-500">{t('accounts.noAccounts')}</div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 max-w-2xl mx-auto">
      {header}
      <AccountForm
        mode="edit"
        initialData={account}
        onSubmit={handleSubmit}
        onCancel={() => navigate({ to: '/accounts' })}
        isLoading={updateMutation.isPending}
      />
    </div>
  );
}
