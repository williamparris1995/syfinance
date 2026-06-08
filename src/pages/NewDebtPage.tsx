import { useNavigate } from '@tanstack/react-router';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { DebtForm } from '@/components/DebtForm';
import { PageShell } from '@/components/patterns/layout/PageShell';
import { PageHeader } from '@/components/patterns/layout/PageHeader';
import { FormCard } from '@/components/patterns/forms/FormCard';
import { createDebt, type CreateDebtDto } from '@/lib/tauri/debt';
import { getUserFriendlyError } from '@/lib/error-handler';

export function NewDebtPage() {
  const navigate = useNavigate();
  const { t } = useTranslation();
  const queryClient = useQueryClient();

  const createMutation = useMutation({
    mutationFn: createDebt,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['debts'] });
      queryClient.invalidateQueries({ queryKey: ['upcoming-payments'] });
      navigate({ to: '/debts' });
      toast.success(t('debts.debtCreated'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });

  return (
    <PageShell narrow>
      <PageHeader title={t('debts.createDebt')} subtitle={t('debts.createDebtDesc')} />
      <FormCard>
        <DebtForm
          onSubmit={(data: CreateDebtDto) => createMutation.mutate(data)}
          onCancel={() => navigate({ to: '/debts' })}
          isLoading={createMutation.isPending}
        />
      </FormCard>
    </PageShell>
  );
}
