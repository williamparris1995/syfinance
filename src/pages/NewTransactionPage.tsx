import { useNavigate } from '@tanstack/react-router';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { SimpleTransactionForm } from '@/components/SimpleTransactionForm';
import { PageShell } from '@/components/patterns/layout/PageShell';
import { PageHeader } from '@/components/patterns/layout/PageHeader';
import { FormCard } from '@/components/patterns/forms/FormCard';
import { listAccounts, listAccountsByOwnership } from '@/lib/tauri/account';

export function NewTransactionPage() {
  const navigate = useNavigate();
  const { t } = useTranslation();
  const queryClient = useQueryClient();

  const { data: accounts = [] } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
  });

  const { data: externalAccounts = [] } = useQuery({
    queryKey: ['accounts', 'external'],
    queryFn: () => listAccountsByOwnership('external'),
  });

  return (
    <PageShell narrow>
      <PageHeader
        title={t('transactions.recordTransaction')}
        subtitle={t('transactions.recordTransactionDesc')}
      />
      <FormCard>
        <SimpleTransactionForm
          accounts={accounts}
          externalAccounts={externalAccounts}
          onSubmit={async () => {
            navigate({ to: '/transactions' });
            queryClient.invalidateQueries({ queryKey: ['transactions'] });
            queryClient.invalidateQueries({ queryKey: ['accounts'] });
            toast.success(t('transactions.recorded'));
          }}
          onCancel={() => navigate({ to: '/transactions' })}
        />
      </FormCard>
    </PageShell>
  );
}
