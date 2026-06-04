import { useEffect, useMemo } from 'react';
import { zodResolver } from '@hookform/resolvers/zod';
import { useForm } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import { useQuery } from '@tanstack/react-query';
import { z } from 'zod';
import { cn } from '@/lib/utils';
import { getCurrencySymbol } from '@/lib/currency';
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
  CreateTransactionTemplateDto,
  UpdateTransactionTemplateDto,
  TransactionTemplateDto,
} from '@/lib/tauri/transactionTemplate';

interface TransactionTemplateFormProps {
  onSubmit: (data: CreateTransactionTemplateDto | UpdateTransactionTemplateDto) => void;
  onCancel: () => void;
  initialValues?: TransactionTemplateDto | null;
  isLoading?: boolean;
}

export function TransactionTemplateForm({
  onSubmit,
  onCancel,
  initialValues,
  isLoading,
}: TransactionTemplateFormProps) {
  const { t } = useTranslation();
  const isEdit = !!initialValues;

  const { data: accounts = [] } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
  });

  const ownAccounts = accounts.filter(
    (a: AccountDto) => a.ownership === 'own'
  );

  const templateFormSchema = z
    .object({
      name: z.string().min(1, t('transactionTemplate.nameRequired')),
      direction: z.enum(['expense', 'income', 'transfer']),
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
      destination_account_id: z.string().optional(),
      auto_record: z.boolean().default(true),
      next_date: z.string().min(1, 'Next date is required'),
      start_date: z.string().min(1, 'Start date is required'),
      end_date: z.string().optional(),
      description: z.string().optional(),
      category: z.string().optional(),
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
    )
    .refine(
      (data) => {
        if (data.direction === 'transfer') {
          return !!data.destination_account_id;
        }
        return true;
      },
      { message: 'Destination account is required for transfers', path: ['destination_account_id'] }
    );

  type TemplateFormValues = z.infer<typeof templateFormSchema>;

  const form = useForm<TemplateFormValues>({
    resolver: zodResolver(templateFormSchema),
    defaultValues: {
      name: initialValues?.name || '',
      direction: initialValues?.direction || 'expense',
      amount: initialValues?.amount != null ? String(initialValues.amount) : '',
      cycle: initialValues?.cycle || 'monthly',
      cycle_days: initialValues?.cycle_days != null ? String(initialValues.cycle_days) : '',
      billing_day: initialValues?.billing_day != null ? String(initialValues.billing_day) : '',
      source_account_id: initialValues?.source_account_id || '',
      destination_account_id: initialValues?.destination_account_id || '',
      auto_record: initialValues?.auto_record ?? true,
      next_date: initialValues?.next_date || '',
      start_date:
        initialValues?.start_date ||
        new Date().toISOString().split('T')[0],
      end_date: initialValues?.end_date || '',
      description: initialValues?.description || '',
      category: initialValues?.category || '',
    },
  });

  const watchedCycle = form.watch('cycle');
  const watchedDirection = form.watch('direction');
  const watchedSourceAccount = form.watch('source_account_id');

  const templateCurrency = useMemo(() => {
    return accounts.find(a => a.id === watchedSourceAccount)?.currency_code || 'CNY';
  }, [accounts, watchedSourceAccount]);

  // Reset conditional fields when cycle changes
  useEffect(() => {
    if (watchedCycle !== 'custom') {
      form.setValue('cycle_days', '');
    }
    if (watchedCycle !== 'monthly' && watchedCycle !== 'yearly') {
      form.setValue('billing_day', '');
    }
  }, [watchedCycle, form]);

  const handleSubmit = (values: TemplateFormValues) => {
    const baseData = {
      name: values.name,
      description: values.description || null,
      amount: values.amount,
      direction: values.direction,
      source_account_id: values.source_account_id,
      destination_account_id:
        values.direction === 'transfer' ? values.destination_account_id || null : null,
      cycle: values.cycle,
      cycle_days: values.cycle === 'custom' ? parseInt(values.cycle_days!) : null,
      billing_day:
        values.cycle === 'monthly' || values.cycle === 'yearly'
          ? parseInt(values.billing_day!)
          : null,
      next_date: values.next_date,
      start_date: values.start_date,
      end_date: values.end_date || null,
      auto_record: values.auto_record,
      category: values.category || null,
    };

    if (isEdit && initialValues) {
      onSubmit({ id: initialValues.id, ...baseData } as UpdateTransactionTemplateDto);
    } else {
      onSubmit(baseData as CreateTransactionTemplateDto);
    }
  };

  return (
    <div className="space-y-6">
      <Form {...form}>
        <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-4 px-5">
          {/* Direction pill toggle */}
          <div className="flex justify-center">
            <div className="inline-flex gap-1 rounded-full bg-muted p-1">
              {(['expense', 'income', 'transfer'] as const).map((dir) => (
                <button
                  key={dir}
                  type="button"
                  onClick={() => form.setValue('direction', dir)}
                  className={cn(
                    'rounded-full px-4 py-1.5 text-xs font-medium transition-all',
                    watchedDirection === dir
                      ? 'bg-background text-foreground shadow-sm'
                      : 'text-muted-foreground hover:text-foreground'
                  )}
                >
                  {t(`transactionTemplate.${dir}`)}
                </button>
              ))}
            </div>
          </div>

          {/* Name */}
          <FormField
            control={form.control}
            name="name"
            render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('transactionTemplate.name')} <span className="text-red-500">*</span>
                </FormLabel>
                <FormControl>
                  <Input placeholder={t('transactionTemplate.namePlaceholder')} className="h-9" {...field} />
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
                  {t('transactionTemplate.amount')} <span className="text-red-500">*</span>
                </FormLabel>
                <FormControl>
                  <div className="flex items-center rounded-md border bg-background overflow-hidden h-9">
                    <span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-r">
                      {getCurrencySymbol(templateCurrency)}
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
                  {t('transactionTemplate.cycle')} <span className="text-red-500">*</span>
                </FormLabel>
                <Select value={field.value} onValueChange={field.onChange}>
                  <FormControl>
                    <SelectTrigger className="h-9">
                      <SelectValue placeholder={t('transactionTemplate.cycle')}>
                        {field.value ? t(`transactionTemplate.${field.value}`) : null}
                      </SelectValue>
                    </SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    <SelectItem value="weekly">{t('transactionTemplate.weekly')}</SelectItem>
                    <SelectItem value="monthly">{t('transactionTemplate.monthly')}</SelectItem>
                    <SelectItem value="yearly">{t('transactionTemplate.yearly')}</SelectItem>
                    <SelectItem value="custom">{t('transactionTemplate.custom')}</SelectItem>
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
                    {t('transactionTemplate.cycleDays')} <span className="text-red-500">*</span>
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
                    {t('transactionTemplate.billingDay')} <span className="text-red-500">*</span>
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
                    ? t('transactionTemplate.sourceAccount')
                    : watchedDirection === 'income'
                      ? t('transactionTemplate.receiveAccount')
                      : t('transactionTemplate.fromAccount')}{' '}
                  <span className="text-red-500">*</span>
                </FormLabel>
                <Select value={field.value} onValueChange={field.onChange}>
                  <FormControl>
                    <SelectTrigger className="h-9">
                      <SelectValue placeholder={t('transactionTemplate.selectAccount')}>
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
                        {t('transactionTemplate.noAccounts')}
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

          {/* Destination account (only for transfer) */}
          {watchedDirection === 'transfer' && (
            <FormField
              control={form.control}
              name="destination_account_id"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                    {t('transactionTemplate.toAccount')} <span className="text-red-500">*</span>
                  </FormLabel>
                  <Select value={field.value} onValueChange={field.onChange}>
                    <FormControl>
                      <SelectTrigger className="h-9">
                        <SelectValue placeholder={t('transactionTemplate.selectAccount')}>
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
                          {t('transactionTemplate.noAccounts')}
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
          )}

          <Separator />

          {/* Auto record switch */}
          <FormField
            control={form.control}
            name="auto_record"
            render={({ field }) => (
              <FormItem className="flex items-center justify-between rounded-lg border p-3">
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('transactionTemplate.autoRecord')}
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

          {/* Next date */}
          <FormField
            control={form.control}
            name="next_date"
            render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('transactionTemplate.nextDate')} <span className="text-red-500">*</span>
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
                  {t('transactionTemplate.startDate')} <span className="text-red-500">*</span>
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
                  {t('transactionTemplate.endDate')}
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
                  {t('transactionTemplate.description')}
                  <span className="text-muted-foreground/50 font-normal">
                    {' '}
                    — {t('common.optional')}
                  </span>
                </FormLabel>
                <FormControl>
                  <Textarea
                    placeholder={t('transactionTemplate.descriptionPlaceholder')}
                    className="resize-none h-20"
                    {...field}
                  />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />

          {/* Category */}
          <FormField
            control={form.control}
            name="category"
            render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('transactionTemplate.category')}
                  <span className="text-muted-foreground/50 font-normal">
                    {' '}
                    — {t('common.optional')}
                  </span>
                </FormLabel>
                <FormControl>
                  <Input
                    placeholder={t('transactionTemplate.categoryPlaceholder')}
                    className="h-9"
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
