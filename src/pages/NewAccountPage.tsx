import { useNavigate } from '@tanstack/react-router';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { useMutation, useQueryClient } from '@tanstack/react-query';

import { AccountForm } from '@/components/AccountForm';
import { PageShell } from '@/components/patterns/layout/PageShell';
import { PageHeader } from '@/components/patterns/layout/PageHeader';
import { FormCard } from '@/components/patterns/forms/FormCard';
import { createAccount } from '@/lib/tauri/account';
import { getUserFriendlyError } from '@/lib/error-handler';

export function NewAccountPage() {
  const navigate = useNavigate();
  const { t } = useTranslation();
  const queryClient = useQueryClient();

  const createMutation = useMutation({
    mutationFn: createAccount,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      navigate({ to: '/accounts' });
      toast.success(t('accounts.accountCreated'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });

  return (
    <PageShell narrow>
      <PageHeader
        title={t('accounts.createAccount')}
        subtitle={t('accountForm.createAccountDesc')}
      />
      <FormCard>
        <AccountForm
          onSubmit={(data) => { if ('account_type' in data) createMutation.mutate(data); }}
          onCancel={() => navigate({ to: '/accounts' })}
          isLoading={createMutation.isPending}
        />
      </FormCard>
    </PageShell>
  );
}
