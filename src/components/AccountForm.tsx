import React, { useState } from 'react';
import { zodResolver } from '@hookform/resolvers/zod';
import { useForm } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
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
import { TrendingUp, BarChart3, Layers, Landmark, Coins, GitBranch, Wallet } from 'lucide-react';
import { INVESTMENT_TEMPLATES } from '@/lib/tauri/account';
import type { AccountType, AccountDto, CreateAccountDto, PatchAccountDto, Ownership } from '@/lib/tauri/account';
import { useCurrencies } from '@/hooks/useCurrency';
import { formatCurrency, getCurrencySymbol } from '@/lib/currency';

const createAccountFormSchema = (t: (key: string) => string) => z.object({
  name: z.string().min(1, t('accountForm.nameRequired')),
  account_type: z.enum(['Cash', 'Bank', 'CreditCard', 'Investment', 'BorrowedOut', 'BorrowedIn', 'Prepaid', 'Other', 'Income', 'Expense'], {
    required_error: t('accountForm.accountTypeRequired'),
  }),
  ownership: z.enum(['own', 'liability', 'external'], {
    required_error: t('accountForm.ownershipRequired'),
  }),
  currency_code: z.string().min(3, t('accountForm.currencyRequired')).max(3, t('accountForm.currencyLength')),
  initial_balance: z.string().min(1, t('accountForm.balanceRequired')).refine(
    (val) => !isNaN(parseFloat(val)),
    t('accountForm.balanceInvalid')
  ),
  account_number: z.string().optional(),
  institution: z.string().optional(),
  credit_limit: z.string().optional().refine(
    (val) => !val || !isNaN(parseFloat(val)),
    t('accountForm.creditLimitInvalid')
  ),
  billing_day: z.string().optional().refine(
    (val) => !val || (!isNaN(parseInt(val)) && parseInt(val) >= 1 && parseInt(val) <= 31),
    t('accountForm.billingDayInvalid')
  ),
  payment_due_day: z.string().optional().refine(
    (val) => !val || (!isNaN(parseInt(val)) && parseInt(val) >= 1 && parseInt(val) <= 31),
    t('accountForm.paymentDueDayInvalid')
  ),
  interest_rate: z.string().optional().refine(
    (val) => !val || !isNaN(parseFloat(val)),
    t('accountForm.interestRateInvalid')
  ),
  low_balance_threshold: z.string().optional().refine(
    (val) => !val || !isNaN(parseFloat(val)),
    t('accountForm.lowBalanceThresholdInvalid')
  ),
  icon: z.string().default('💰'),
  color: z.string().default('#10B981'),
  chart_code: z.string().optional().nullable(),
  parent_id: z.string().optional().nullable(),
});

interface AccountFormProps {
  onSubmit: (data: CreateAccountDto | { id: string; dto: PatchAccountDto }) => void;
  onCancel: () => void;
  isLoading?: boolean;
  initialData?: AccountDto;
  mode?: 'create' | 'edit';
}

export function AccountForm({ onSubmit, onCancel, isLoading, initialData, mode = 'create' }: AccountFormProps) {
  const { t } = useTranslation();
  const accountFormSchema = createAccountFormSchema(t);
  type AccountFormValues = z.infer<typeof accountFormSchema>;
  const isEditMode = mode === 'edit';
  const [selectedTemplate, setSelectedTemplate] = useState<number | null>(null);
  const { data: currencies = [] } = useCurrencies();

  const form = useForm<AccountFormValues>({
    resolver: zodResolver(accountFormSchema),
    defaultValues: initialData
      ? {
          name: initialData.name,
          account_type: initialData.account_type,
          ownership: initialData.ownership,
          currency_code: initialData.currency_code,
          initial_balance: String(initialData.initial_balance),
          account_number: initialData.account_number ?? '',
          institution: initialData.institution ?? '',
          credit_limit: initialData.credit_limit != null ? String(initialData.credit_limit) : '',
          billing_day: initialData.billing_day != null ? String(initialData.billing_day) : '',
          payment_due_day: initialData.payment_due_day != null ? String(initialData.payment_due_day) : '',
          interest_rate: initialData.interest_rate != null ? String(initialData.interest_rate) : '',
          low_balance_threshold: initialData.low_balance_threshold != null ? String(initialData.low_balance_threshold) : '',
          icon: initialData.icon || '📁',
          color: initialData.color || '#6B7280',
          chart_code: initialData.chart_code ?? '',
          parent_id: initialData.parent_id ?? undefined as string | undefined,
        }
      : {
          name: '',
          account_type: 'Bank',
          ownership: 'own',
          currency_code: 'CNY',
          initial_balance: '0.00',
          account_number: '',
          institution: '',
          credit_limit: '',
          billing_day: '',
          payment_due_day: '',
          interest_rate: '',
          low_balance_threshold: '',
          icon: '📁',
          color: '#6B7280',
          chart_code: '',
          parent_id: undefined as string | undefined,
        },
  });

  const accountType = form.watch('account_type');
  const ownership = form.watch('ownership');
  const selectedCurrencyCode = form.watch('currency_code');

  // Auto-set chart_code for Prepaid accounts
  React.useEffect(() => {
    if (accountType === 'Prepaid' && !form.getValues('chart_code')) {
      form.setValue('chart_code', '1123');
    }
  }, [accountType, form]);

  const handleSubmit = (values: AccountFormValues) => {
    if (isEditMode && initialData) {
      const dto: PatchAccountDto = {
        name: values.name,
        initial_balance: parseFloat(values.initial_balance),
      };

      if (values.icon) dto.icon = values.icon || '📁';
      if (values.color) dto.color = values.color || '#6B7280';
      // PatchAccountDto: null = clear, value = set, omitted = no change
      dto.account_number = values.account_number || null;
      dto.institution = values.institution || null;
      dto.chart_code = values.chart_code || null;
      if (values.credit_limit) dto.credit_limit = parseFloat(values.credit_limit);
      else dto.credit_limit = null;
      if (values.billing_day) dto.billing_day = parseInt(values.billing_day);
      else dto.billing_day = null;
      if (values.payment_due_day) dto.payment_due_day = parseInt(values.payment_due_day);
      else dto.payment_due_day = null;
      if (values.interest_rate) dto.interest_rate = parseFloat(values.interest_rate);
      else dto.interest_rate = null;
      if (values.low_balance_threshold) dto.low_balance_threshold = parseFloat(values.low_balance_threshold);
      else dto.low_balance_threshold = null;

      onSubmit({ id: initialData.id, dto });
      return;
    }

    const dto: CreateAccountDto = {
      name: values.name,
      account_type: values.account_type as AccountType,
      ownership: values.ownership as Ownership,
      currency_code: values.currency_code,
      initial_balance: parseFloat(values.initial_balance),
      icon: values.icon || '📁',
      color: values.color || '#6B7280',
    };

    if (values.chart_code) dto.chart_code = values.chart_code;
    if (values.parent_id) dto.parent_id = values.parent_id;
    if (values.account_number) dto.account_number = values.account_number;
    if (values.institution) dto.institution = values.institution;
    if (values.credit_limit) dto.credit_limit = parseFloat(values.credit_limit);
    if (values.billing_day) dto.billing_day = parseInt(values.billing_day);
    if (values.payment_due_day) dto.payment_due_day = parseInt(values.payment_due_day);
    if (values.interest_rate) dto.interest_rate = parseFloat(values.interest_rate);
    if (values.low_balance_threshold) dto.low_balance_threshold = parseFloat(values.low_balance_threshold);

    onSubmit(dto);
  };

  const typeLabelMap: Record<string, string> = {
    Cash: t('accountForm.cashWithChinese'),
    Bank: t('accountForm.bankWithChinese'),
    CreditCard: t('accountForm.creditCardWithChinese'),
    Investment: t('accountForm.investmentWithChinese'),
    BorrowedOut: t('accountForm.borrowedOutWithChinese'),
    BorrowedIn: t('accountForm.borrowedInWithChinese'),
    Prepaid: t('accountForm.prepaidWithChinese'),
    Other: t('accountForm.otherWithChinese'),
    Income: t('accountForm.incomeWithChinese'),
    Expense: t('accountForm.expenseWithChinese'),
  };

  const currencyLabelMap: Record<string, string> = Object.fromEntries(
    currencies.map((c) => [c.code, `${c.symbol} ${c.name} (${c.code})`])
  );

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-4 px-5">
        {/* Core fields */}
        <div className="space-y-4">
          {/* Ownership Toggle */}
          <FormField
            control={form.control}
            name="ownership"
            render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('accountForm.ownershipLabelText')} <span className="text-red-500">*</span>
                </FormLabel>
                <div className="flex gap-2">
                  <button
                    type="button"
                    onClick={() => !isEditMode && field.onChange('own')}
                    disabled={isEditMode}
                    className={cn(
                      "flex-1 rounded-lg border px-3 py-2 text-sm font-medium transition-all",
                      field.value === 'own'
                        ? "bg-emerald-50 border-emerald-300 text-emerald-700 dark:bg-emerald-950 dark:border-emerald-700 dark:text-emerald-400"
                        : "bg-background border-input text-muted-foreground hover:text-foreground",
                      isEditMode && "opacity-50 cursor-not-allowed"
                    )}
                  >
                    {t('accountForm.ownAccountEmoji')}
                  </button>
                  <button
                    type="button"
                    onClick={() => !isEditMode && field.onChange('liability')}
                    disabled={isEditMode}
                    className={cn(
                      "flex-1 rounded-lg border px-3 py-2 text-sm font-medium transition-all",
                      field.value === 'liability'
                        ? "bg-red-50 border-red-300 text-red-700 dark:bg-red-950 dark:border-red-700 dark:text-red-400"
                        : "bg-background border-input text-muted-foreground hover:text-foreground",
                      isEditMode && "opacity-50 cursor-not-allowed"
                    )}
                  >
                    {t('accountForm.liabilityAccountEmoji')}
                  </button>
                  <button
                    type="button"
                    onClick={() => !isEditMode && field.onChange('external')}
                    disabled={isEditMode}
                    className={cn(
                      "flex-1 rounded-lg border px-3 py-2 text-sm font-medium transition-all",
                      field.value === 'external'
                        ? "bg-amber-50 border-amber-300 text-amber-700 dark:bg-amber-950 dark:border-amber-700 dark:text-amber-400"
                        : "bg-background border-input text-muted-foreground hover:text-foreground",
                      isEditMode && "opacity-50 cursor-not-allowed"
                    )}
                  >
                    {t('accountForm.externalAccountEmoji')}
                  </button>
                </div>
                <FormMessage />
              </FormItem>
            )}
          />

          {/* Investment Template Picker */}
          {!isEditMode && accountType === 'Investment' && (
            <FormItem>
              <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                {t('accountForm.selectTemplate')}
                <span className="text-muted-foreground/50 font-normal"> {t('common.optionalSuffix')}</span>
              </FormLabel>
              <div className="grid grid-cols-4 gap-2">
                {INVESTMENT_TEMPLATES.map((template, index) => {
                  const IconComponent = [TrendingUp, BarChart3, Layers, Landmark, Coins, GitBranch, Wallet][index];
                  return (
                    <button
                      key={template.name}
                      type="button"
                      onClick={() => {
                        setSelectedTemplate(index);
                        form.setValue('name', template.name);
                        form.setValue('icon', template.icon);
                        form.setValue('color', template.color);
                        form.setValue('chart_code', template.chart_code);
                      }}
                      className={cn(
                        "flex flex-col items-center gap-1 rounded-lg border p-2 text-xs transition-all",
                        selectedTemplate === index
                          ? "border-primary bg-primary/10 ring-1 ring-primary"
                          : "border-input hover:border-primary/50 hover:bg-muted"
                      )}
                    >
                      <IconComponent
                        className="h-4 w-4"
                        style={{ color: template.color }}
                      />
                      <span className="truncate w-full text-center">{t(`accounts.templates.${template.name}`)}</span>
                    </button>
                  );
                })}
              </div>
            </FormItem>
          )}

          {/* Name */}
          <FormField
            control={form.control}
            name="name"
            render={({ field }) => (
            <FormItem>
              <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                {t('accountForm.accountName')} <span className="text-red-500">*</span>
              </FormLabel>
              <FormControl>
                <Input placeholder={t('accountForm.accountNamePlaceholder')} className="h-9" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
            )}
          />

          {/* Type + Balance — single column */}
          <div className="space-y-4">
            <FormField
              control={form.control}
              name="account_type"
              render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('accountForm.accountType')} <span className="text-red-500">*</span>
                </FormLabel>
                <Select value={field.value} onValueChange={field.onChange} disabled={isEditMode}>
                  <FormControl><SelectTrigger className="h-9"><SelectValue placeholder={t('accountForm.selectAccountType')}>{field.value ? typeLabelMap[field.value] || field.value : null}</SelectValue></SelectTrigger></FormControl>
                  <SelectContent>
                    {ownership === 'own'
                      ? (['Cash', 'Bank', 'Investment', 'BorrowedOut', 'Prepaid', 'Other'] as const).map((type) => (
                        <SelectItem key={type} value={type}>{typeLabelMap[type]}</SelectItem>
                      ))
                      : ownership === 'liability'
                        ? (['CreditCard', 'BorrowedIn'] as const).map((type) => (
                          <SelectItem key={type} value={type}>{typeLabelMap[type]}</SelectItem>
                        ))
                        : (['Income', 'Expense'] as const).map((type) => (
                          <SelectItem key={type} value={type}>{typeLabelMap[type]}</SelectItem>
                        ))
                    }
                  </SelectContent>
                </Select>
                <FormMessage />
              </FormItem>
              )}
            />

            {isEditMode && initialData ? (
              <div className="space-y-2">
                <div className="space-y-1">
                  <div className="text-xs uppercase tracking-wider text-muted-foreground">
                    {t('accountForm.currentBalance')}
                  </div>
                  <div className="flex items-center rounded-lg border bg-muted/30 h-9 px-3">
                    <span className="text-sm font-medium">
                      {formatCurrency(initialData.current_balance, selectedCurrencyCode || 'CNY')}
                    </span>
                  </div>
                </div>
                <FormField
                  control={form.control}
                  name="initial_balance"
                  render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                      {t('accountForm.initialBalance')}
                    </FormLabel>
                    <FormControl>
                      <div className="flex items-center rounded-lg border overflow-hidden h-9">
                        <span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-r">{getCurrencySymbol(selectedCurrencyCode || 'CNY')}</span>
                        <input
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
              </div>
            ) : (
              <FormField
                control={form.control}
                name="initial_balance"
                render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                    {t('accountForm.initialBalance')}
                  </FormLabel>
                  <FormControl>
                    <div className="flex items-center rounded-lg border overflow-hidden h-9">
                      <span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-r">{getCurrencySymbol(selectedCurrencyCode || 'CNY')}</span>
                      <input
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
            )}
          </div>
        </div>

        {/* Icon & Color */}
        <div className="space-y-4">
          {/* Icon picker */}
          <FormField
            control={form.control}
            name="icon"
            render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('accountForm.iconLabel')}
                </FormLabel>
                <div className="flex flex-wrap gap-2">
                  {['💰','💵','💳','🏦','💸','📊','🏠','🚗','🍔','🛍️','🎮','🏥','📚','💡','🎁','📈','🛒','✈️','🐷','💎','🎯','💊','📱','☕','🎓'].map((emoji) => (
                    <button
                      key={emoji}
                      type="button"
                      onClick={() => field.onChange(emoji)}
                      className={cn(
                        "h-9 w-9 flex items-center justify-center rounded-lg border text-lg transition-all",
                        field.value === emoji
                          ? "border-primary bg-primary/10 scale-110"
                          : "border-input hover:border-primary/50 hover:bg-muted"
                      )}
                    >
                      {emoji}
                    </button>
                  ))}
                </div>
                <FormMessage />
              </FormItem>
            )}
          />

          {/* Color picker */}
          <FormField
            control={form.control}
            name="color"
            render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('accountForm.colorLabel')}
                </FormLabel>
                <div className="flex flex-wrap gap-2">
                  {['#EF4444','#F59E0B','#10B981','#3B82F6','#8B5CF6','#EC4899','#06B6D4','#84CC16','#F97316','#6366F1','#14B8A6','#E11D48','#D946EF','#0EA5E9','#64748B'].map((c) => (
                    <button
                      key={c}
                      type="button"
                      onClick={() => field.onChange(c)}
                      className={cn(
                        "h-7 w-7 rounded-full border-2 transition-all",
                        field.value === c
                          ? "border-foreground scale-110"
                          : "border-transparent hover:scale-105"
                      )}
                      style={{ backgroundColor: c }}
                    />
                  ))}
                </div>
                <div className="flex items-center gap-2 mt-2">
                  <div className="h-7 w-7 rounded border" style={{ backgroundColor: field.value || '#6B7280' }} />
                  <FormControl><Input placeholder="#EF4444" className="h-8 w-28 font-mono text-xs" {...field} /></FormControl>
                </div>
                <FormMessage />
              </FormItem>
            )}
          />
        </div>

        {/* Advanced fields — expandable */}
        <details className="border-t pt-4">
          <summary className="text-xs font-medium text-primary cursor-pointer hover:text-primary/80">
            {t('accountForm.advancedOptions')}
          </summary>
          <div className="space-y-4 mt-4">
            {/* Currency */}
            <FormField
              control={form.control}
              name="currency_code"
              render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('accountForm.currency')}
                  <span className="text-muted-foreground/50 font-normal"> {t('common.optionalSuffix')}</span>
                </FormLabel>
                <Select value={field.value} onValueChange={field.onChange} disabled={isEditMode}>
                  <FormControl><SelectTrigger className="h-9"><SelectValue placeholder={t('accountForm.selectCurrency')}>{field.value ? currencyLabelMap[field.value] || field.value : null}</SelectValue></SelectTrigger></FormControl>
                  <SelectContent>
                    {currencies.map((currency) => (
                      <SelectItem key={currency.code} value={currency.code}>
                        {currency.symbol} {currency.name} ({currency.code})
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <FormMessage />
              </FormItem>
              )}
            />

            {/* Account Number + Institution — single column */}
            <div className="space-y-4">
              <FormField
                control={form.control}
                name="account_number"
                render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                    {t('accountForm.accountNumber')}
                    <span className="text-muted-foreground/50 font-normal"> {t('common.optionalSuffix')}</span>
                  </FormLabel>
                  <FormControl><Input placeholder={t('accountForm.accountNumberPlaceholder')} className="h-9" {...field} /></FormControl>
                  <FormMessage />
                </FormItem>
                )}
              />
              <FormField
                control={form.control}
                name="institution"
                render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                    {t('accountForm.institution')}
                    <span className="text-muted-foreground/50 font-normal"> {t('common.optionalSuffix')}</span>
                  </FormLabel>
                  <FormControl><Input placeholder={t('accountForm.institutionPlaceholder')} className="h-9" {...field} /></FormControl>
                  <FormMessage />
                </FormItem>
                )}
              />
            </div>

            {/* Conditional: Credit Card fields */}
            {accountType === 'CreditCard' && (
              <div className="rounded-lg border border-blue-200/50 bg-gradient-to-br from-blue-50/50 to-card p-4 dark:from-blue-950/20 dark:to-card dark:border-blue-800/30">
                <div className="text-xs font-medium text-blue-600 dark:text-blue-400 uppercase tracking-wider mb-3">
                  {t('accountForm.creditCardDetails')}
                </div>
                <div className="space-y-4">
                  <FormField
                    control={form.control}
                    name="credit_limit"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-xs text-muted-foreground">{t('accountForm.creditLimit')}</FormLabel>
                        <FormControl><Input type="number" placeholder="50000" className="h-9" {...field} /></FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  <FormField
                    control={form.control}
                    name="billing_day"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-xs text-muted-foreground">{t('accountForm.billingDay')}</FormLabel>
                        <FormControl><Input type="number" min={1} max={31} placeholder="5" className="h-9" {...field} /></FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  <FormField
                    control={form.control}
                    name="payment_due_day"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-xs text-muted-foreground">{t('accountForm.paymentDueDay')}</FormLabel>
                        <FormControl><Input type="number" min={1} max={31} placeholder="25" className="h-9" {...field} /></FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                </div>
              </div>
            )}

            {/* Conditional: debt-related fields */}
            {(accountType === 'BorrowedIn' || accountType === 'BorrowedOut') && (
              <FormField
                control={form.control}
                name="interest_rate"
                render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">{t('accountForm.interestRate')}</FormLabel>
                  <FormControl>
                    <div className="flex items-center rounded-lg border overflow-hidden h-9">
                      <input className="flex-1 border-0 bg-transparent px-2.5 text-sm outline-none" placeholder="5.5" {...field} />
                      <span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-l">%</span>
                    </div>
                  </FormControl>
                  <FormMessage />
                </FormItem>
                )}
              />
            )}

            {/* Conditional: Prepaid fields */}
            {accountType === 'Prepaid' && (
              <div className="rounded-lg border border-purple-200/50 bg-gradient-to-br from-purple-50/50 to-card p-4 dark:from-purple-950/20 dark:to-card dark:border-purple-800/30">
                <div className="text-xs font-medium text-purple-600 dark:text-purple-400 uppercase tracking-wider mb-3">
                  {t('accountForm.prepaidDetails')}
                </div>
                <FormField
                  control={form.control}
                  name="low_balance_threshold"
                  render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-xs text-muted-foreground">{t('accountForm.lowBalanceThreshold')}</FormLabel>
                    <FormControl>
                      <div className="flex items-center rounded-lg border overflow-hidden h-9">
                        <span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-r">{getCurrencySymbol(selectedCurrencyCode || 'CNY')}</span>
                        <input
                          type="number"
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
              </div>
            )}
          </div>
        </details>

        <div className="flex justify-end gap-2 pt-4">
          <Button type="button" variant="outline" onClick={onCancel} disabled={isLoading}>
            {t('common.cancel')}
          </Button>
          <Button type="submit" variant="default-gradient" disabled={isLoading}>
            {isLoading
              ? t('common.saving')
              : isEditMode
                ? t('common.save')
                : t('accountForm.createAccount')}
          </Button>
        </div>
      </form>
    </Form>
  );
}
