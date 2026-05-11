import { zodResolver } from '@hookform/resolvers/zod';
import { useForm } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import { z } from 'zod';
import { Button } from './ui/button';
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
  FormDescription,
} from './ui/form';
import { Input } from './ui/input';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from './ui/select';
import type { AccountType, CreateAccountDto } from '@/lib/tauri/account';

const createAccountFormSchema = (t: (key: string) => string) => z.object({
  name: z.string().min(1, t('accountForm.nameRequired')),
  account_type: z.enum(['Cash', 'Bank', 'CreditCard', 'Investment', 'Loan', 'Other'], {
    required_error: t('accountForm.accountTypeRequired'),
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
      account_type: undefined,
      currency_code: 'CNY',
      initial_balance: '0.00',
      account_number: '',
      institution: '',
      credit_limit: '',
      billing_day: '',
      payment_due_day: '',
      interest_rate: '',
    },
  });

  const watchAccountType = form.watch('account_type');

  const handleSubmit = (values: AccountFormValues) => {
    const dto: CreateAccountDto = {
      name: values.name,
      account_type: values.account_type as AccountType,
      currency_code: values.currency_code,
      initial_balance: parseFloat(values.initial_balance),
    };

    // Add optional fields if provided
    if (values.account_number) dto.account_number = values.account_number;
    if (values.institution) dto.institution = values.institution;
    if (values.credit_limit) dto.credit_limit = parseFloat(values.credit_limit);
    if (values.billing_day) dto.billing_day = parseInt(values.billing_day);
    if (values.payment_due_day) dto.payment_due_day = parseInt(values.payment_due_day);
    if (values.interest_rate) dto.interest_rate = parseFloat(values.interest_rate);

    onSubmit(dto);
  };

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-4">
        <FormField
          control={form.control}
          name="name"
          render={({ field }) => (
          <FormItem>
            <FormLabel>{t('accountForm.accountName')}</FormLabel>
            <FormControl>
              <Input placeholder={t('accountForm.accountNamePlaceholder')} {...field} />
            </FormControl>
            <FormMessage />
          </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="account_type"
          render={({ field }) => (
          <FormItem>
            <FormLabel>{t('accountForm.accountType')}</FormLabel>
            <Select onValueChange={field.onChange} defaultValue={field.value}>
              <FormControl>
                <SelectTrigger>
                  <SelectValue placeholder={t('accountForm.selectAccountType')} />
                </SelectTrigger>
              </FormControl>
              <SelectContent>
                <SelectItem value="Cash">{t('accountForm.cashWithChinese')}</SelectItem>
                <SelectItem value="Bank">{t('accountForm.bankWithChinese')}</SelectItem>
                <SelectItem value="CreditCard">{t('accountForm.creditCardWithChinese')}</SelectItem>
                <SelectItem value="Investment">{t('accountForm.investmentWithChinese')}</SelectItem>
                <SelectItem value="Loan">{t('accountForm.loanWithChinese')}</SelectItem>
                <SelectItem value="Other">{t('accountForm.otherWithChinese')}</SelectItem>
              </SelectContent>
            </Select>
            <FormMessage />
          </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="currency_code"
          render={({ field }) => (
          <FormItem>
            <FormLabel>{t('accountForm.currency')}</FormLabel>
            <Select onValueChange={field.onChange} defaultValue={field.value}>
              <FormControl>
                <SelectTrigger>
                  <SelectValue placeholder={t('accountForm.selectCurrency')} />
                </SelectTrigger>
              </FormControl>
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

        <FormField
          control={form.control}
          name="initial_balance"
          render={({ field }) => (
          <FormItem>
            <FormLabel>{t('accountForm.initialBalance')}</FormLabel>
            <FormControl>
              <Input type="text" placeholder="0.00" {...field} />
            </FormControl>
            <FormDescription>
              {t('accountForm.creditCardNote')}
            </FormDescription>
            <FormMessage />
          </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="account_number"
          render={({ field }) => (
          <FormItem>
            <FormLabel>{t('accountForm.accountNumber')}</FormLabel>
            <FormControl>
              <Input placeholder={t('accountForm.accountNumberPlaceholder')} {...field} />
            </FormControl>
            <FormMessage />
          </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="institution"
          render={({ field }) => (
          <FormItem>
            <FormLabel>{t('accountForm.institution')}</FormLabel>
            <FormControl>
              <Input placeholder={t('accountForm.institutionPlaceholder')} {...field} />
            </FormControl>
            <FormMessage />
          </FormItem>
          )}
        />

        {watchAccountType === 'CreditCard' && (
          <>
            <FormField
              control={form.control}
              name="credit_limit"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>{t('accountForm.creditLimit')}</FormLabel>
                  <FormControl>
                    <Input type="text" placeholder="0.00" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="billing_day"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>{t('accountForm.billingDay')}</FormLabel>
                  <FormControl>
                    <Input type="text" placeholder="1-31" {...field} />
                  </FormControl>
                  <FormDescription>{t('accountForm.billingDayDesc')}</FormDescription>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="payment_due_day"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>{t('accountForm.paymentDueDay')}</FormLabel>
                  <FormControl>
                    <Input type="text" placeholder="1-31" {...field} />
                  </FormControl>
                  <FormDescription>{t('accountForm.paymentDueDayDesc')}</FormDescription>
                  <FormMessage />
                </FormItem>
              )}
            />
          </>
        )}

        {watchAccountType === 'Loan' && (
          <FormField
            control={form.control}
            name="interest_rate"
            render={({ field }) => (
              <FormItem>
                <FormLabel>{t('accountForm.interestRate')}</FormLabel>
                <FormControl>
                  <Input type="text" placeholder="e.g., 5.5" {...field} />
                </FormControl>
                <FormDescription>{t('accountForm.interestRateDesc')}</FormDescription>
                <FormMessage />
              </FormItem>
            )}
          />
        )}

        <div className="flex justify-end gap-2 pt-4">
          <Button type="button" variant="outline" onClick={onCancel} disabled={isLoading}>
            {t('common.cancel')}
          </Button>
          <Button type="submit" disabled={isLoading}>
            {isLoading ? t('accountForm.creating') : t('accountForm.createAccount')}
          </Button>
        </div>
      </form>
    </Form>
  );
}
