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
import type { AccountType, CreateAccountDto, Ownership } from '@/lib/tauri/account';

const createAccountFormSchema = (t: (key: string) => string) => z.object({
  name: z.string().min(1, t('accountForm.nameRequired')),
  account_type: z.enum(['Cash', 'Bank', 'CreditCard', 'Investment', 'Loan', 'Other', 'Income', 'Expense'], {
    required_error: t('accountForm.accountTypeRequired'),
  }),
  ownership: z.enum(['own', 'external'], {
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
  icon: z.string().default('💰'),
  color: z.string().default('#10B981'),
  chart_code: z.string().optional().nullable(),
  parent_id: z.string().uuid().optional().nullable(),
});

interface AccountFormProps {
  onSubmit: (data: CreateAccountDto) => void;
  onCancel: () => void;
  isLoading?: boolean;
}

export function AccountForm({ onSubmit, onCancel, isLoading }: AccountFormProps) {
  const { t } = useTranslation();
  const accountFormSchema = createAccountFormSchema(t);
  type AccountFormValues = z.infer<typeof accountFormSchema>;
  
  const form = useForm<AccountFormValues>({
    resolver: zodResolver(accountFormSchema),
    defaultValues: {
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
      icon: '📁',
      color: '#6B7280',
      chart_code: '',
      parent_id: '',
    },
  });

  const accountType = form.watch('account_type');
  const ownership = form.watch('ownership');

  const handleSubmit = (values: AccountFormValues) => {
    const dto: CreateAccountDto = {
      name: values.name,
      account_type: values.account_type as AccountType,
      ownership: values.ownership as Ownership,
      currency_code: values.currency_code,
      initial_balance: parseFloat(values.initial_balance),
      icon: values.icon || '📁',
      color: values.color || '#6B7280',
    };

    // Add optional fields if provided
    if (values.chart_code) dto.chart_code = values.chart_code;
    if (values.parent_id) dto.parent_id = values.parent_id;
    if (values.account_number) dto.account_number = values.account_number;
    if (values.institution) dto.institution = values.institution;
    if (values.credit_limit) dto.credit_limit = parseFloat(values.credit_limit);
    if (values.billing_day) dto.billing_day = parseInt(values.billing_day);
    if (values.payment_due_day) dto.payment_due_day = parseInt(values.payment_due_day);
    if (values.interest_rate) dto.interest_rate = parseFloat(values.interest_rate);

    onSubmit(dto);
  };

  const typeLabelMap: Record<string, string> = {
    Cash: t('accountForm.cashWithChinese'),
    Bank: t('accountForm.bankWithChinese'),
    CreditCard: t('accountForm.creditCardWithChinese'),
    Investment: t('accountForm.investmentWithChinese'),
    Loan: t('accountForm.loanWithChinese'),
    Other: t('accountForm.otherWithChinese'),
    Income: t('accountForm.incomeWithChinese'),
    Expense: t('accountForm.expenseWithChinese'),
  };

  const currencyLabelMap: Record<string, string> = {
    CNY: 'CNY (¥)',
    USD: 'USD ($)',
    EUR: 'EUR (€)',
  };

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
                  所有权 (OWNERSHIP) <span className="text-red-500">*</span>
                </FormLabel>
                <div className="flex gap-2">
                  <button
                    type="button"
                    onClick={() => field.onChange('own')}
                    className={cn(
                      "flex-1 rounded-lg border px-3 py-2 text-sm font-medium transition-all",
                      field.value === 'own'
                        ? "bg-emerald-50 border-emerald-300 text-emerald-700 dark:bg-emerald-950 dark:border-emerald-700 dark:text-emerald-400"
                        : "bg-background border-input text-muted-foreground hover:text-foreground"
                    )}
                  >
                    🏠 自己账户
                  </button>
                  <button
                    type="button"
                    onClick={() => field.onChange('external')}
                    className={cn(
                      "flex-1 rounded-lg border px-3 py-2 text-sm font-medium transition-all",
                      field.value === 'external'
                        ? "bg-amber-50 border-amber-300 text-amber-700 dark:bg-amber-950 dark:border-amber-700 dark:text-amber-400"
                        : "bg-background border-input text-muted-foreground hover:text-foreground"
                    )}
                  >
                    🌐 外部账户
                  </button>
                </div>
                <FormMessage />
              </FormItem>
            )}
          />

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
                <Select value={field.value} onValueChange={field.onChange}>
                  <FormControl><SelectTrigger className="h-9"><SelectValue placeholder={t('accountForm.selectAccountType')}>{field.value ? typeLabelMap[field.value] || field.value : null}</SelectValue></SelectTrigger></FormControl>
                  <SelectContent>
                    {ownership === 'own'
                      ? (['Cash', 'Bank', 'CreditCard', 'Investment', 'Loan', 'Other'] as const).map((type) => (
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
                    <span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-r">¥</span>
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
        </div>

        {/* Icon & Color */}
        <div className="grid grid-cols-2 gap-4">
          <FormField
            control={form.control}
            name="icon"
            render={({ field }) => (
              <FormItem>
                <FormLabel>图标</FormLabel>
                <FormControl><Input placeholder="🍔" className="h-9" {...field} /></FormControl>
              </FormItem>
            )}
          />
          <FormField
            control={form.control}
            name="color"
            render={({ field }) => (
              <FormItem>
                <FormLabel>颜色</FormLabel>
                <FormControl>
                  <div className="flex items-center gap-2">
                    <Input placeholder="#EF4444" className="h-9" {...field} />
                    <div className="h-8 w-8 rounded border" style={{backgroundColor: field.value || '#6B7280'}} />
                  </div>
                </FormControl>
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
                  <span className="text-muted-foreground/50 font-normal"> — optional</span>
                </FormLabel>
                <Select value={field.value} onValueChange={field.onChange}>
                  <FormControl><SelectTrigger className="h-9"><SelectValue placeholder={t('accountForm.selectCurrency')}>{field.value ? currencyLabelMap[field.value] || field.value : null}</SelectValue></SelectTrigger></FormControl>
                  <SelectContent>
                    <SelectItem value="CNY">CNY (¥)</SelectItem>
                    <SelectItem value="USD">USD ($)</SelectItem>
                    <SelectItem value="EUR">EUR (€)</SelectItem>
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
                    <span className="text-muted-foreground/50 font-normal"> — optional</span>
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
                    <span className="text-muted-foreground/50 font-normal"> — optional</span>
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

            {/* Conditional: Loan field */}
            {accountType === 'Loan' && (
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
          </div>
        </details>

        <div className="flex justify-end gap-2 pt-4">
          <Button type="button" variant="outline" onClick={onCancel} disabled={isLoading}>
            {t('common.cancel')}
          </Button>
          <Button type="submit" variant="default-gradient" disabled={isLoading}>
            {isLoading ? t('accountForm.creating') : t('accountForm.createAccount')}
          </Button>
        </div>
      </form>
    </Form>
  );
}
