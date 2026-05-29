import { useNavigate } from '@tanstack/react-router';
import { ArrowLeft } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { SimpleTransactionForm } from '@/components/SimpleTransactionForm';
import { Button } from '@/components/ui/button';
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
    <div className="p-6 max-w-2xl mx-auto">
      <div className="flex items-center gap-4 mb-6">
        <Button variant="ghost" size="icon" onClick={() => navigate({ to: '/transactions' })}>
          <ArrowLeft className="h-5 w-5" />
        </Button>
        <h1 className="text-2xl font-bold">{t('transactions.recordTransaction')}</h1>
      </div>
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
    </div>
  );
}
