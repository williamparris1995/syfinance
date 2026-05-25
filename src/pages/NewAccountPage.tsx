import { useNavigate } from '@tanstack/react-router';
import { ArrowLeft } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { AccountForm } from '@/components/AccountForm';
import { Button } from '@/components/ui/button';
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
    <div className="p-6 max-w-2xl mx-auto">
      <div className="flex items-center gap-4 mb-6">
        <Button variant="ghost" size="icon" onClick={() => navigate({ to: '/accounts' })}>
          <ArrowLeft className="h-5 w-5" />
        </Button>
        <h1 className="text-2xl font-bold">{t('accounts.createAccount')}</h1>
      </div>
      <AccountForm
        onSubmit={(data) => { if ('account_type' in data) createMutation.mutate(data); }}
        onCancel={() => navigate({ to: '/accounts' })}
        isLoading={createMutation.isPending}
      />
    </div>
  );
}
