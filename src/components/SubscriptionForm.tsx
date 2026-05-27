import { useEffect } from 'react';
import { zodResolver } from '@hookform/resolvers/zod';
import { useForm } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import { useQuery } from '@tanstack/react-query';
import { z } from 'zod';
import { cn } from '@/lib/utils';
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
import { Switch } from './ui/switch';
import { Textarea } from './ui/textarea';
import { Separator } from './ui/separator';
import { listAccounts, type AccountDto } from '@/lib/tauri/account';
import type {
  CreateSubscriptionDto,
  UpdateSubscriptionDto,
  SubscriptionDto,
} from '@/lib/tauri/subscription';

interface SubscriptionFormProps {
  onSubmit: (data: CreateSubscriptionDto | UpdateSubscriptionDto) => void;
  onCancel: () => void;
  initialValues?: SubscriptionDto | null;
  isLoading?: boolean;
}

export function SubscriptionForm({
  onSubmit,
  onCancel,
  initialValues,
  isLoading,
}: SubscriptionFormProps) {
  const { t } = useTranslation();
  const isEdit = !!initialValues;

  const { data: accounts = [] } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
  });

  const ownAccounts = accounts.filter(
    (a: AccountDto) => a.ownership === 'own'
  );

  const subscriptionFormSchema = z
    .object({
      name: z.string().min(1, t('subscription.name')),
      direction: z.enum(['expense', 'income']),
      amount: z.string().min(1, 'Amount is required').refine(
        (val) => {
          const num = parseFloat(val);
          return !isNaN(num) && num > 0;
        },
        { message: 'Amount must be greater than 0' }
      ),
      cycle: z.enum(['weekly', 'monthly', 'yearly', 'custom']),
      cycle_days: z.string().optional(),
      billing_day: z.string().optional(),
      source_account_id: z.string().min(1, 'Account is required'),
      auto_record: z.boolean().default(true),
      next_billing_date: z.string().min(1, 'Next billing date is required'),
      start_date: z.string().min(1, 'Start date is required'),
      end_date: z.string().optional(),
      description: z.string().optional(),
    })
    .refine(
      (data) => {
        if (data.cycle === 'custom') {
          const num = parseInt(data.cycle_days || '');
          return !isNaN(num) && num > 0;
        }
        return true;
      },
      { message: 'Cycle days must be a positive number', path: ['cycle_days'] }
    )
    .refine(
      (data) => {
        if (data.cycle === 'monthly' || data.cycle === 'yearly') {
          const num = parseInt(data.billing_day || '');
          return !isNaN(num) && num >= 1 && num <= 31;
        }
        return true;
      },
      { message: 'Billing day must be between 1 and 31', path: ['billing_day'] }
    );

  type SubscriptionFormValues = z.infer<typeof subscriptionFormSchema>;

  const form = useForm<SubscriptionFormValues>({
    resolver: zodResolver(subscriptionFormSchema),
    defaultValues: {
      name: initialValues?.name || '',
      direction: initialValues?.direction || 'expense',
      amount: initialValues?.amount != null ? String(initialValues.amount) : '',
      cycle: initialValues?.cycle || 'monthly',
      cycle_days: initialValues?.cycle_days != null ? String(initialValues.cycle_days) : '',
      billing_day: initialValues?.billing_day != null ? String(initialValues.billing_day) : '',
      source_account_id: initialValues?.source_account_id || '',
      auto_record: initialValues?.auto_record ?? true,
      next_billing_date: initialValues?.next_billing_date || '',
      start_date:
        initialValues?.start_date ||
        new Date().toISOString().split('T')[0],
      end_date: initialValues?.end_date || '',
      description: initialValues?.description || '',
    },
  });

  const watchedCycle = form.watch('cycle');
  const watchedDirection = form.watch('direction');

  // Reset conditional fields when cycle changes
  useEffect(() => {
    if (watchedCycle !== 'custom') {
      form.setValue('cycle_days', '');
    }
    if (watchedCycle !== 'monthly' && watchedCycle !== 'yearly') {
      form.setValue('billing_day', '');
    }
  }, [watchedCycle, form]);

  const handleSubmit = (values: SubscriptionFormValues) => {
    const baseData = {
      name: values.name,
      direction: values.direction,
      amount: parseFloat(values.amount),
      cycle: values.cycle,
      cycle_days: values.cycle === 'custom' ? parseInt(values.cycle_days!) : null,
      billing_day:
        values.cycle === 'monthly' || values.cycle === 'yearly'
          ? parseInt(values.billing_day!)
          : null,
      next_billing_date: values.next_billing_date,
      start_date: values.start_date,
      end_date: values.end_date || null,
      auto_record: values.auto_record,
      source_account_id: values.source_account_id,
      description: values.description || null,
    };

    if (isEdit && initialValues) {
      onSubmit({ id: initialValues.id, ...baseData } as UpdateSubscriptionDto);
    } else {
      onSubmit(baseData as CreateSubscriptionDto);
    }
  };

  return (
    <div className="space-y-6">
      <Form {...form}>
        <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-4 px-5">
          {/* Direction pill toggle */}
          <div className="flex justify-center">
            <div className="inline-flex gap-1 rounded-full bg-muted p-1">
              <button
                type="button"
                onClick={() => form.setValue('direction', 'expense')}
                className={cn(
                  'rounded-full px-4 py-1.5 text-xs font-medium transition-all',
                  watchedDirection === 'expense'
                    ? 'bg-background text-foreground shadow-sm'
                    : 'text-muted-foreground hover:text-foreground'
                )}
              >
                {t('subscription.expense')}
              </button>
              <button
                type="button"
                onClick={() => form.setValue('direction', 'income')}
                className={cn(
                  'rounded-full px-4 py-1.5 text-xs font-medium transition-all',
                  watchedDirection === 'income'
                    ? 'bg-background text-foreground shadow-sm'
                    : 'text-muted-foreground hover:text-foreground'
                )}
              >
                {t('subscription.income')}
              </button>
            </div>
          </div>

          {/* Name */}
          <FormField
            control={form.control}
            name="name"
            render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('subscription.name')} <span className="text-red-500">*</span>
                </FormLabel>
                <FormControl>
                  <Input placeholder="Netflix, Spotify..." className="h-9" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />

          {/* Amount */}
          <FormField
            control={form.control}
            name="amount"
            render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('subscription.amount')} <span className="text-red-500">*</span>
                </FormLabel>
                <FormControl>
                  <div className="flex items-center rounded-md border bg-background overflow-hidden h-9">
                    <span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-r">
                      ¥
                    </span>
                    <input
                      type="number"
                      step="0.01"
                      min="0.01"
                      className="flex-1 border-0 bg-transparent px-2.5 text-sm outline-none"
                      placeholder="0.00"
                      {...field}
                    />
                  </div>
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />

          {/* Cycle */}
          <FormField
            control={form.control}
            name="cycle"
            render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('subscription.cycle')} <span className="text-red-500">*</span>
                </FormLabel>
                <Select value={field.value} onValueChange={field.onChange}>
                  <FormControl>
                    <SelectTrigger className="h-9">
                      <SelectValue placeholder={t('subscription.cycle')}>
                        {field.value ? t(`subscription.${field.value}`) : null}
                      </SelectValue>
                    </SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    <SelectItem value="weekly">{t('subscription.weekly')}</SelectItem>
                    <SelectItem value="monthly">{t('subscription.monthly')}</SelectItem>
                    <SelectItem value="yearly">{t('subscription.yearly')}</SelectItem>
                    <SelectItem value="custom">{t('subscription.custom')}</SelectItem>
                  </SelectContent>
                </Select>
                <FormMessage />
              </FormItem>
            )}
          />

          {/* Cycle days (only when custom) */}
          {watchedCycle === 'custom' && (
            <FormField
              control={form.control}
              name="cycle_days"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                    {t('subscription.cycleDays')} <span className="text-red-500">*</span>
                  </FormLabel>
                  <FormControl>
                    <Input
                      type="number"
                      min="1"
                      placeholder="30"
                      className="h-9"
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
          )}

          {/* Billing day (only when monthly or yearly) */}
          {(watchedCycle === 'monthly' || watchedCycle === 'yearly') && (
            <FormField
              control={form.control}
              name="billing_day"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                    {t('subscription.billingDay')} <span className="text-red-500">*</span>
                  </FormLabel>
                  <FormControl>
                    <Input
                      type="number"
                      min="1"
                      max="31"
                      placeholder="1-31"
                      className="h-9"
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
          )}

          {/* Source account */}
          <FormField
            control={form.control}
            name="source_account_id"
            render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {watchedDirection === 'expense'
                    ? t('subscription.sourceAccount')
                    : t('subscription.receiveAccount')}{' '}
                  <span className="text-red-500">*</span>
                </FormLabel>
                <Select value={field.value} onValueChange={field.onChange}>
                  <FormControl>
                    <SelectTrigger className="h-9">
                      <SelectValue placeholder={t('subscription.sourceAccount')}>
                        {field.value
                          ? ownAccounts.find((a) => a.id === field.value)?.name ||
                            field.value
                          : null}
                      </SelectValue>
                    </SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    {ownAccounts.length === 0 ? (
                      <div className="px-2 py-4 text-sm text-muted-foreground text-center">
                        No accounts available
                      </div>
                    ) : (
                      ownAccounts.map((acc) => (
                        <SelectItem key={acc.id} value={acc.id}>
                          {acc.name} ({acc.account_type})
                        </SelectItem>
                      ))
                    )}
                  </SelectContent>
                </Select>
                <FormMessage />
              </FormItem>
            )}
          />

          <Separator />

          {/* Auto record switch */}
          <FormField
            control={form.control}
            name="auto_record"
            render={({ field }) => (
              <FormItem className="flex items-center justify-between rounded-lg border p-3">
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('subscription.autoRecord')}
                </FormLabel>
                <FormControl>
                  <Switch
                    checked={field.value}
                    onCheckedChange={field.onChange}
                  />
                </FormControl>
              </FormItem>
            )}
          />

          {/* Next billing date */}
          <FormField
            control={form.control}
            name="next_billing_date"
            render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('subscription.nextBillingDate')} <span className="text-red-500">*</span>
                </FormLabel>
                <FormControl>
                  <Input type="date" className="h-9" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />

          {/* Start date */}
          <FormField
            control={form.control}
            name="start_date"
            render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('subscription.startDate')} <span className="text-red-500">*</span>
                </FormLabel>
                <FormControl>
                  <Input type="date" className="h-9" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />

          {/* End date */}
          <FormField
            control={form.control}
            name="end_date"
            render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('subscription.endDate')}
                  <span className="text-muted-foreground/50 font-normal">
                    {' '}
                    — {t('common.optional')}
                  </span>
                </FormLabel>
                <FormControl>
                  <Input type="date" className="h-9" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />

          {/* Description */}
          <FormField
            control={form.control}
            name="description"
            render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('subscription.description')}
                  <span className="text-muted-foreground/50 font-normal">
                    {' '}
                    — {t('common.optional')}
                  </span>
                </FormLabel>
                <FormControl>
                  <Textarea
                    placeholder={t('subscription.description')}
                    className="resize-none h-20"
                    {...field}
                  />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />

          {/* Actions */}
          <div className="flex justify-end gap-2 pt-4">
            <Button type="button" variant="outline" onClick={onCancel} disabled={isLoading}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" variant="default-gradient" disabled={isLoading}>
              {isLoading
                ? t('common.saving')
                : isEdit
                  ? t('common.save')
                  : t('common.create')}
            </Button>
          </div>
        </form>
      </Form>
    </div>
  );
}
