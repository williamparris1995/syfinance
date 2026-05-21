import { useNavigate } from '@tanstack/react-router';
import { ArrowLeft } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { DebtForm } from '@/components/DebtForm';
import { Button } from '@/components/ui/button';
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
    <div className="p-6 max-w-2xl mx-auto">
      <div className="flex items-center gap-4 mb-6">
        <Button variant="ghost" size="icon" onClick={() => navigate({ to: '/debts' })}>
          <ArrowLeft className="h-5 w-5" />
        </Button>
        <h1 className="text-2xl font-bold">{t('debts.createDebt')}</h1>
      </div>
      <DebtForm
        onSubmit={(data: CreateDebtDto) => createMutation.mutate(data)}
        onCancel={() => navigate({ to: '/debts' })}
        isLoading={createMutation.isPending}
      />
    </div>
  );
}
