import { useMemo } from 'react';
import { zodResolver } from '@hookform/resolvers/zod';
import { useForm } from 'react-hook-form';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { z } from 'zod';
import { Button } from './ui/button';
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from './ui/form';
import { Input } from './ui/input';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from './ui/select';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from './ui/sheet';
import { listAccountsWithBalances, type AccountDto } from '@/lib/tauri/account';
import { topUp } from '@/lib/tauri/prepaid';
import { getUserFriendlyError } from '@/lib/error-handler';

interface TopUpDialogProps {
  accountId: string;
  accountName: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function TopUpDialog({ accountId, accountName, open, onOpenChange }: TopUpDialogProps) {
  const { t } = useTranslation();
  const queryClient = useQueryClient();

  const { data: accounts = [] } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccountsWithBalances,
  });

  const sourceAccounts = useMemo(
    () => accounts.filter(
      (a: AccountDto) =>
        a.ownership === 'own' &&
        (a.account_type === 'Cash' || a.account_type === 'Bank')
    ),
    [accounts]
  );

  const topUpFormSchema = z.object({
    source_account_id: z.string().min(1, t('prepaid.selectSourceAccount')),
    paid_amount: z.string().min(1, t('prepaid.amountRequired')).refine(
      (val) => !isNaN(parseFloat(val)) && parseFloat(val) > 0,
      t('prepaid.amountPositive')
    ),
    bonus_amount: z.string().optional().refine(
      (val) => !val || (!isNaN(parseFloat(val)) && parseFloat(val) >= 0),
      t('prepaid.bonusInvalid')
    ),
    top_up_date: z.string().min(1, t('prepaid.dateRequired')),
    expiry_date: z.string().optional(),
    description: z.string().optional(),
  });

  type TopUpFormValues = z.infer<typeof topUpFormSchema>;

  const form = useForm<TopUpFormValues>({
    resolver: zodResolver(topUpFormSchema),
    defaultValues: {
      source_account_id: sourceAccounts[0]?.id || '',
      paid_amount: '',
      bonus_amount: '',
      top_up_date: new Date().toISOString().split('T')[0],
      expiry_date: '',
      description: '',
    },
  });

  const paidAmount = form.watch('paid_amount');
  const bonusAmount = form.watch('bonus_amount');
  const totalCredited = useMemo(() => {
    const paid = parseFloat(paidAmount) || 0;
    const bonus = parseFloat(bonusAmount ?? '') || 0;
    return paid + bonus;
  }, [paidAmount, bonusAmount]);

  const topUpMutation = useMutation({
    mutationFn: topUp,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      queryClient.invalidateQueries({ queryKey: ['prepaid-detail'] });
      toast.success(t('prepaid.topUpSuccess'));
      onOpenChange(false);
      form.reset();
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });

  const handleSubmit = (values: TopUpFormValues) => {
    topUpMutation.mutate({
      account_id: accountId,
      source_account_id: values.source_account_id,
      paid_amount: parseFloat(values.paid_amount),
      bonus_amount: values.bonus_amount ? parseFloat(values.bonus_amount) : undefined,
      top_up_date: values.top_up_date,
      expiry_date: values.expiry_date || undefined,
      description: values.description || undefined,
    });
  };

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="right" className="w-full sm:max-w-lg">
        <SheetHeader>
          <SheetTitle>{t('prepaid.topUpTitle')} - {accountName}</SheetTitle>
        </SheetHeader>
        <div className="flex-1 overflow-y-auto -mx-4 px-4">
          <Form {...form}>
            <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-4 px-5">
              {/* Source account */}
              <FormField
                control={form.control}
                name="source_account_id"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                      {t('prepaid.sourceAccount')} <span className="text-red-500">*</span>
                    </FormLabel>
                    <Select value={field.value} onValueChange={field.onChange}>
                      <FormControl>
                        <SelectTrigger className="h-9">
                          <SelectValue placeholder={t('prepaid.selectSourceAccount')}>
                            {field.value ? (sourceAccounts.find(a => a.id === field.value)?.name || field.value) : null}
                          </SelectValue>
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        {sourceAccounts.map((acc) => (
                          <SelectItem key={acc.id} value={acc.id}>
                            {acc.name} ({acc.account_type})
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />

              {/* Amounts */}
              <div className="grid grid-cols-2 gap-3">
                <FormField
                  control={form.control}
                  name="paid_amount"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                        {t('prepaid.paidAmount')} <span className="text-red-500">*</span>
                      </FormLabel>
                      <FormControl>
                        <div className="flex items-center rounded-lg border overflow-hidden h-9">
                          <span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-r">¥</span>
                          <input
                            type="number"
                            step="0.01"
                            min="0.01"
                            className="flex-1 border-0 bg-transparent px-2.5 text-sm outline-none"
                            placeholder="100"
                            {...field}
                          />
                        </div>
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <FormField
                  control={form.control}
                  name="bonus_amount"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                        {t('prepaid.bonusAmount')}
                        <span className="text-muted-foreground/50 font-normal"> {t('common.optionalSuffix')}</span>
                      </FormLabel>
                      <FormControl>
                        <div className="flex items-center rounded-lg border overflow-hidden h-9">
                          <span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-r">¥</span>
                          <input
                            type="number"
                            step="0.01"
                            min="0"
                            className="flex-1 border-0 bg-transparent px-2.5 text-sm outline-none"
                            placeholder="0"
                            {...field}
                          />
                        </div>
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>

              {/* Total preview */}
              {(parseFloat(paidAmount) > 0 || parseFloat(bonusAmount ?? '') > 0) && (
                <div className="rounded-lg border border-emerald-200/50 bg-gradient-to-br from-emerald-50/50 to-card p-3 flex items-center justify-between dark:from-emerald-950/20 dark:to-card dark:border-emerald-800/30">
                  <span className="text-xs text-muted-foreground">{t('prepaid.totalCredited')}</span>
                  <span className="text-lg font-bold text-emerald-700 dark:text-emerald-300">
                    ¥{totalCredited.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                  </span>
                </div>
              )}

              {/* Dates */}
              <div className="grid grid-cols-2 gap-3">
                <FormField
                  control={form.control}
                  name="top_up_date"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                        {t('prepaid.topUpDate')} <span className="text-red-500">*</span>
                      </FormLabel>
                      <FormControl>
                        <Input type="date" className="h-9" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <FormField
                  control={form.control}
                  name="expiry_date"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                        {t('prepaid.expiryDate')}
                        <span className="text-muted-foreground/50 font-normal"> {t('common.optionalSuffix')}</span>
                      </FormLabel>
                      <FormControl>
                        <Input type="date" className="h-9" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>

              {/* Description */}
              <FormField
                control={form.control}
                name="description"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                      {t('prepaid.description')}
                      <span className="text-muted-foreground/50 font-normal"> {t('common.optionalSuffix')}</span>
                    </FormLabel>
                    <FormControl>
                      <Input
                        placeholder={t('prepaid.descriptionPlaceholder')}
                        className="h-9"
                        {...field}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <div className="flex justify-end gap-2 pt-4">
                <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
                  {t('common.cancel')}
                </Button>
                <Button type="submit" variant="default-gradient" disabled={topUpMutation.isPending}>
                  {topUpMutation.isPending ? t('common.saving') : t('prepaid.confirmTopUp')}
                </Button>
              </div>
            </form>
          </Form>
        </div>
      </SheetContent>
    </Sheet>
  );
}
