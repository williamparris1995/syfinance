import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate, useParams } from '@tanstack/react-router';
import { ArrowLeft } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';

import { AccountChangesDialog, type ChangeItem } from '@/components/AccountChangesDialog';
import { AccountForm } from '@/components/AccountForm';
import { Button } from '@/components/ui/button';
import { getUserFriendlyError } from '@/lib/error-handler';
import {
  type CreateAccountDto,
  getAccount,
  updateAccount,
  type PatchAccountDto,
  type AccountDto,
} from '@/lib/tauri/account';

function computeChanges(initial: AccountDto, dto: PatchAccountDto): ChangeItem[] {
  const changes: ChangeItem[] = [];

  const fieldMap: Array<{
    key: keyof PatchAccountDto;
    label: string;
    format?: (val: unknown) => string;
    significant?: boolean;
  }> = [
    { key: 'name', label: 'accounts.fields.name' },
    { key: 'initial_balance', label: 'accounts.fields.initialBalance', format: (v) => Number(v).toFixed(2), significant: true },
    { key: 'icon', label: 'accounts.fields.icon' },
    { key: 'color', label: 'accounts.fields.color' },
    { key: 'account_number', label: 'accounts.fields.accountNumber' },
    { key: 'institution', label: 'accounts.fields.institution' },
    { key: 'credit_limit', label: 'accounts.fields.creditLimit', format: (v) => Number(v).toFixed(2) },
    { key: 'billing_day', label: 'accounts.fields.billingDay', format: (v) => String(v) },
    { key: 'payment_due_day', label: 'accounts.fields.paymentDueDay', format: (v) => String(v) },
    { key: 'interest_rate', label: 'accounts.fields.interestRate', format: (v) => `${v}%` },
    { key: 'low_balance_threshold', label: 'accounts.fields.lowBalanceThreshold', format: (v) => Number(v).toFixed(2) },
  ];

  for (const field of fieldMap) {
    const oldValue = initial[field.key as keyof AccountDto];
    const newValue = dto[field.key];

    // Normalize: treat empty string and undefined as null
    const normalize = (val: unknown): unknown => {
      if (val === '' || val === undefined) return null;
      return val;
    };

    const oldNorm = normalize(oldValue);
    const newNorm = normalize(newValue);

    // Skip if both are null/undefined
    if (oldNorm == null && newNorm == null) continue;
    // Skip if equal
    if (oldNorm === newNorm) continue;

    const fmt = field.format ?? ((v: unknown) => (v == null ? '' : String(v)));

    changes.push({
      field: field.label,
      oldValue: fmt(oldNorm ?? oldValue),
      newValue: fmt(newNorm ?? newValue),
      significant: field.significant,
    });
  }

  return changes;
}

export function AccountEditPage() {
  const navigate = useNavigate();
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const { accountId } = useParams({ strict: false });

  const [pendingData, setPendingData] = useState<{ id: string; dto: PatchAccountDto } | null>(null);
  const [changes, setChanges] = useState<ChangeItem[]>([]);
  const [dialogOpen, setDialogOpen] = useState(false);

  const { data: account, isLoading, isError } = useQuery({
    queryKey: ['accounts', accountId],
    queryFn: () => getAccount(accountId!),
    enabled: !!accountId,
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, dto }: { id: string; dto: PatchAccountDto }) => updateAccount(id, dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      setDialogOpen(false);
      setPendingData(null);
      navigate({ to: '/accounts' });
      toast.success(t('accounts.accountUpdated'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });

  const handleSubmit = (data: CreateAccountDto | { id: string; dto: PatchAccountDto }) => {
    if (!('id' in data)) return;

    if (!account) return;

    const computedChanges = computeChanges(account, data.dto);

    if (computedChanges.length === 0) {
      toast.info(t('accounts.noChanges'));
      return;
    }

    setPendingData({ id: data.id, dto: data.dto });
    setChanges(computedChanges);
    setDialogOpen(true);
  };

  const handleConfirmSave = () => {
    if (pendingData) {
      updateMutation.mutate({ id: pendingData.id, dto: pendingData.dto });
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
      <AccountChangesDialog
        open={dialogOpen}
        onOpenChange={(open) => {
          setDialogOpen(open);
          if (!open) setPendingData(null);
        }}
        changes={changes}
        onConfirm={handleConfirmSave}
        isLoading={updateMutation.isPending}
      />
    </div>
  );
}
