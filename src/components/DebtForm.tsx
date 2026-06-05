import { zodResolver } from '@hookform/resolvers/zod';
import { useEffect, useMemo, useState } from 'react';
import { useForm } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import { useQuery } from '@tanstack/react-query';
import { Info } from 'lucide-react';
import { z } from 'zod';
import { cn } from '@/lib/utils';
import { Button } from './ui/button';
import { Tooltip, TooltipContent, TooltipTrigger } from './ui/tooltip';
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
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from './ui/table';
import type { CreateDebtDto, DebtDto, AmortizationMethod } from '@/lib/tauri/debt';
import { listAccounts, type AccountDto } from '@/lib/tauri/account';
import { formatCurrency, getCurrencySymbol } from '@/lib/currency';

const DEBT_ACCOUNT_TYPES = ['BorrowedOut', 'BorrowedIn', 'CreditCard'] as const;

interface PaymentPreview {
  payment_date: string;
  principal_amount: number;
  interest_amount: number;
  total_amount: number;
}

interface DebtFormProps {
  onSubmit: (data: CreateDebtDto) => void;
  onCancel: () => void;
  isLoading?: boolean;
  initialData?: DebtDto | null;
  mode?: 'create' | 'edit' | 'view';
}

export function DebtForm({ onSubmit, onCancel, isLoading, initialData, mode = 'create' }: DebtFormProps) {
  const { t } = useTranslation();
  const [paymentPreview, setPaymentPreview] = useState<PaymentPreview[]>([]);
  const [repaymentMode, setRepaymentMode] = useState<'lump_sum' | 'installment'>('lump_sum');
  const readOnly = mode === 'view';
  const isEdit = mode === 'edit';

  const { data: accounts = [] } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
  });

  const debtAccounts = accounts.filter(
    (a: AccountDto) =>
      (a.ownership === 'own' || a.ownership === 'liability') && DEBT_ACCOUNT_TYPES.includes(a.account_type as typeof DEBT_ACCOUNT_TYPES[number])
  );

  const fundingAccounts = accounts.filter(
    (a: AccountDto) =>
      a.ownership === 'own' && (a.account_type === 'Cash' || a.account_type === 'Bank')
  );

  const amortizationLabelMap: Record<string, string> = {
    EqualPrincipalInterest: t('debtForm.equalPI'),
    EqualPrincipal: t('debtForm.equalPrincipal'),
    LumpSum: t('debtForm.lumpSum'),
  };

  const debtFormSchema = z.object({
    account_id: z.string().min(1, t('debtForm.accountRequired')),
    funding_account_id: isEdit ? z.string().optional() : z.string().min(1, t('debtForm.fundingAccountRequired')),
    counterparty: z.string().min(1, t('debtForm.counterpartyRequired')),
    principal_amount: z.string().min(1, t('debtForm.principalRequired')).refine(
      (val) => {
        const num = parseFloat(val);
        return !isNaN(num) && num > 0;
      },
      { message: t('debtForm.principalPositive') }
    ),
    currency_code: z.string().min(3, t('debtForm.currencyRequired')).max(3, t('debtForm.currencyLength')),
    interest_rate: z.string().min(1, t('debtForm.interestRateRequired')).refine(
      (val) => {
        const num = parseFloat(val);
        return !isNaN(num) && num >= 0;
      },
      { message: t('debtForm.interestRatePositive') }
    ),
    start_date: z.string().optional(),
    due_date: z.string().optional(),
    periods: z.number().optional(),
    amortization_method: z.enum(['EqualPrincipalInterest', 'EqualPrincipal', 'LumpSum']).nullable(),
  }).refine(
    (data) => {
      if (data.start_date && data.due_date) {
        return new Date(data.due_date) > new Date(data.start_date);
      }
      return true;
    },
    {
      message: t('debtForm.dueDateAfterStart'),
      path: ['due_date'],
    }
  );

  type DebtFormValues = z.infer<typeof debtFormSchema>;

  const form = useForm<DebtFormValues>({
    resolver: zodResolver(debtFormSchema),
    defaultValues: {
      account_id: mode === 'edit' || mode === 'view' ? (initialData?.account_id || '') : '',
      funding_account_id: '',
      counterparty: initialData?.counterparty || '',
      principal_amount: initialData?.principal_amount || '',
      currency_code: initialData?.currency_code || 'CNY',
      interest_rate: initialData?.interest_rate || '',
      start_date: initialData?.start_date || '',
      due_date: initialData?.due_date || '',
      periods: undefined,
      amortization_method: (initialData?.amortization_method as 'EqualPrincipalInterest' | 'EqualPrincipal' | 'LumpSum' | null) || 'EqualPrincipalInterest',
    },
  });

  const watchedValues = form.watch();
  const { account_id, principal_amount, interest_rate, start_date, due_date, amortization_method, periods, currency_code: selectedCurrencyCode } = watchedValues;

  // Auto-fill counterparty from selected account name (only on account change)
  useEffect(() => {
    if (!isEdit && !readOnly && account_id) {
      const selected = accounts.find(a => a.id === account_id);
      if (selected) {
        form.setValue('counterparty', selected.name);
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [account_id]);

  // Auto-sync currency_code from selected debt account
  useEffect(() => {
    if (!isEdit && !readOnly && account_id) {
      const selectedAccount = debtAccounts.find(a => a.id === account_id);
      if (selectedAccount?.currency_code) {
        form.setValue('currency_code', selectedAccount.currency_code);
      }
    }
  }, [account_id, debtAccounts, form, isEdit, readOnly]);

  useEffect(() => {
    const timer = setTimeout(() => {
      if (!principal_amount || !interest_rate || !amortization_method || amortization_method === 'LumpSum') {
        setPaymentPreview([]);
        return;
      }

      const principal = parseFloat(principal_amount);
      const rate = parseFloat(interest_rate) / 100 / 12;
      const startDateStr = start_date;

      if (isNaN(principal) || isNaN(rate) || principal <= 0 || rate < 0) {
        setPaymentPreview([]);
        return;
      }

      let months: number;
      if (periods && periods > 0) {
        months = periods;
      } else if (startDateStr && due_date) {
        const sd = new Date(startDateStr);
        const dd = new Date(due_date);
        if (dd <= sd) { setPaymentPreview([]); return; }
        months = Math.round((dd.getFullYear() - sd.getFullYear()) * 12 + (dd.getMonth() - sd.getMonth()));
      } else {
        setPaymentPreview([]);
        return;
      }

      if (months <= 0) { setPaymentPreview([]); return; }

      const scheduleStart = startDateStr ? new Date(startDateStr) : new Date();
      const schedule: PaymentPreview[] = [];
      let remaining = principal;

      if (amortization_method === 'EqualPrincipalInterest') {
        const pmt = rate === 0
          ? principal / months
          : (principal * rate * Math.pow(1 + rate, months)) / (Math.pow(1 + rate, months) - 1);

        for (let i = 1; i <= months; i++) {
          const interest = remaining * rate;
          const principalPmt = pmt - interest;
          const d = new Date(scheduleStart);
          d.setMonth(d.getMonth() + i);
          schedule.push({
            payment_date: d.toISOString().split('T')[0],
            principal_amount: principalPmt,
            interest_amount: interest,
            total_amount: pmt,
          });
          remaining -= principalPmt;
        }
      } else {
        const principalPmt = principal / months;
        for (let i = 1; i <= months; i++) {
          const interest = remaining * rate;
          const d = new Date(scheduleStart);
          d.setMonth(d.getMonth() + i);
          schedule.push({
            payment_date: d.toISOString().split('T')[0],
            principal_amount: principalPmt,
            interest_amount: interest,
            total_amount: principalPmt + interest,
          });
          remaining -= principalPmt;
        }
      }

      setPaymentPreview(schedule);
    }, 500);

    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [watchedValues]);

  const totalInterest = useMemo(() => {
    return paymentPreview.reduce((sum, p) => sum + p.interest_amount, 0);
  }, [paymentPreview]);

  const lumpSumYears = useMemo(() => {
    // Calculate term in years for lump sum simple interest
    let months = 0;
    if (repaymentMode === 'lump_sum') {
      const startStr = start_date;
      const dueStr = due_date;
      if (startStr && dueStr) {
        const sd = new Date(startStr);
        const dd = new Date(dueStr);
        if (dd > sd) {
          months = Math.round((dd.getFullYear() - sd.getFullYear()) * 12 + (dd.getMonth() - sd.getMonth()));
        }
      }
    }
    return months > 0 ? months / 12 : 0;
  }, [repaymentMode, start_date, due_date]);

  const handleSubmit = (values: DebtFormValues) => {
    let resolvedDueDate = values.due_date || '';
    let resolvedMethod = values.amortization_method;

    if (repaymentMode === 'lump_sum') {
      resolvedMethod = 'LumpSum';
    }

    if (repaymentMode === 'installment' && values.periods && values.start_date) {
      const d = new Date(values.start_date);
      d.setMonth(d.getMonth() + values.periods);
      resolvedDueDate = d.toISOString().split('T')[0];
    }

    onSubmit({
      account_id: values.account_id,
      funding_account_id: values.funding_account_id || '',
      counterparty: values.counterparty,
      principal_amount: values.principal_amount,
      currency_code: values.currency_code,
      interest_rate: values.interest_rate ? (parseFloat(values.interest_rate) / 100).toString() : '0',
      start_date: values.start_date || null,
      due_date: resolvedDueDate || null,
      amortization_method: resolvedMethod as AmortizationMethod | null,
    });
  };

  return (
    <div className="space-y-6">
      <Form {...form}>
        <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-4 px-5">
          <div className="flex justify-center">
            <div className="inline-flex gap-1 rounded-full bg-muted p-1">
              <button
                type="button"
                onClick={() => setRepaymentMode('lump_sum')}
                className={cn(
                  "rounded-full px-4 py-1.5 text-xs font-medium transition-all",
                  repaymentMode === 'lump_sum'
                    ? "bg-background text-foreground shadow-sm"
                    : "text-muted-foreground hover:text-foreground"
                )}
              >
                {t('debtForm.lumpSum')}
              </button>
              <button
                type="button"
                onClick={() => setRepaymentMode('installment')}
                className={cn(
                  "rounded-full px-4 py-1.5 text-xs font-medium transition-all",
                  repaymentMode === 'installment'
                    ? "bg-background text-foreground shadow-sm"
                    : "text-muted-foreground hover:text-foreground"
                )}
              >
                {t('debtForm.installment')}
              </button>
            </div>
          </div>

          <div className="space-y-4">
            <FormField name="account_id" render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('debtForm.debtAccount')} <span className="text-red-500">*</span>
                </FormLabel>
                <Select value={field.value} onValueChange={field.onChange} disabled={isEdit}>
                  <FormControl>
                    <SelectTrigger className="h-9">
                      <SelectValue placeholder={t('debtForm.selectAccount')}>
                        {field.value ? (debtAccounts.find(a => a.id === field.value)?.name || field.value) : null}
                      </SelectValue>
                    </SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    {debtAccounts.length === 0 ? (
                      <div className="px-2 py-4 text-sm text-muted-foreground text-center">
                        {t('debtForm.noDebtAccounts')}
                      </div>
                    ) : (
                      debtAccounts.map((acc) => (
                        <SelectItem key={acc.id} value={acc.id}>
                          {acc.name} ({acc.account_type})
                        </SelectItem>
                      ))
                    )}
                  </SelectContent>
                </Select>
                <FormMessage />
              </FormItem>
            )} />
            {!isEdit && (
            <FormField name="funding_account_id" render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('debtForm.fundingAccount')} <span className="text-red-500">*</span>
                  <Tooltip>
                    <TooltipTrigger>
                      <Info className="inline ml-1 h-3 w-3 text-muted-foreground cursor-help" />
                    </TooltipTrigger>
                    <TooltipContent>
                      <p>{t('debtForm.fundingAccountDesc')}</p>
                    </TooltipContent>
                  </Tooltip>
                </FormLabel>
                <Select value={field.value} onValueChange={field.onChange}>
                  <FormControl>
                    <SelectTrigger className="h-9">
                      <SelectValue placeholder={t('debtForm.selectFundingAccount')}>
                        {field.value ? (fundingAccounts.find(a => a.id === field.value)?.name || field.value) : null}
                      </SelectValue>
                    </SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    {fundingAccounts.map((acc) => (
                      <SelectItem key={acc.id} value={acc.id}>
                        {acc.name} ({acc.account_type})
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <FormMessage />
              </FormItem>
            )} />
            )}
            <FormField name="counterparty" render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('debtForm.counterparty')} <span className="text-red-500">*</span>
                </FormLabel>
                <FormControl><Input placeholder={t('debtForm.counterpartyPlaceholder')} className="h-9" disabled={readOnly} {...field} /></FormControl>
                <FormMessage />
              </FormItem>
            )} />
            <FormItem>
              <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                {t('common.currency')}
              </FormLabel>
              <div className="flex items-center rounded-lg border overflow-hidden h-9 bg-muted/30">
                <span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-r">{getCurrencySymbol(selectedCurrencyCode || 'CNY')}</span>
                <span className="flex-1 px-2.5 text-sm text-muted-foreground">{selectedCurrencyCode || 'CNY'}</span>
              </div>
            </FormItem>
          </div>

          <div className="space-y-4">
            <FormField name="principal_amount" render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('debtForm.principal')} <span className="text-red-500">*</span>
                </FormLabel>
                <FormControl>
                  <div className="flex items-center rounded-lg border overflow-hidden h-9">
                    <span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-r">{getCurrencySymbol(selectedCurrencyCode || 'CNY')}</span>
                    <input className="flex-1 border-0 bg-transparent px-2.5 text-sm outline-none" placeholder="100,000" disabled={readOnly} {...field} />
                  </div>
                </FormControl>
                <FormMessage />
              </FormItem>
            )} />
            <FormField name="interest_rate" render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('debtForm.interestRate')}
                </FormLabel>
                <FormControl>
                  <div className="flex items-center rounded-lg border overflow-hidden h-9">
                    <input className="flex-1 border-0 bg-transparent px-2.5 text-sm outline-none" placeholder="5.5" disabled={readOnly} {...field} />
                    <span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-l">%</span>
                  </div>
                </FormControl>
                <FormMessage />
              </FormItem>
            )} />

            <FormField name="start_date" render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('debtForm.startDate')} <span className="text-red-500">*</span>
                </FormLabel>
                <FormControl><Input type="date" className="h-9" disabled={readOnly} {...field} /></FormControl>
                <FormMessage />
              </FormItem>
            )} />

            {repaymentMode === 'installment' ? (
              <>
                <FormField name="periods" render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                      {t('debtForm.periods')} <span className="text-red-500">*</span>
                    </FormLabel>
                    <Select value={field.value?.toString() || ''} onValueChange={(v) => field.onChange(parseInt(v))} disabled={readOnly}>
                      <FormControl><SelectTrigger className="h-9"><SelectValue placeholder={t('debtForm.selectPeriods')}>{field.value ? `${field.value} ${t('debtForm.months')}` : null}</SelectValue></SelectTrigger></FormControl>
                      <SelectContent>
                        {[3, 6, 12, 24, 36, 60].map((n) => (
                          <SelectItem key={n} value={n.toString()}>{n} {t('debtForm.months')}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )} />
                <FormField name="amortization_method" render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                      {t('debtForm.amortizationMethod')}
                    </FormLabel>
                    <Select value={field.value || undefined} onValueChange={field.onChange} disabled={readOnly}>
                      <FormControl><SelectTrigger className="h-9"><SelectValue placeholder={t('debtForm.selectAmortization')}>{field.value ? amortizationLabelMap[field.value] || field.value : null}</SelectValue></SelectTrigger></FormControl>
                      <SelectContent>
                        <SelectItem value="EqualPrincipalInterest">{t('debtForm.equalPI')}</SelectItem>
                        <SelectItem value="EqualPrincipal">{t('debtForm.equalPrincipal')}</SelectItem>
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )} />
              </>
            ) : (
              <FormField name="due_date" render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                    {t('debtForm.dueDate')} <span className="text-red-500">*</span>
                  </FormLabel>
                  <FormControl><Input type="date" className="h-9" disabled={readOnly} {...field} /></FormControl>
                  <FormMessage />
                </FormItem>
              )} />
            )}
          </div>

          {repaymentMode === 'lump_sum' && principal_amount && interest_rate && (() => {
            const p = parseFloat(principal_amount);
            const r = parseFloat(interest_rate || '0') / 100;
            const years = lumpSumYears || 1;
            const interest = p * r * years;
            const total = p + interest;
            return (
            <div className="rounded-xl border border-blue-200/50 bg-gradient-to-br from-blue-50/50 to-card p-4 flex items-center justify-between dark:from-blue-950/20 dark:to-card dark:border-blue-800/30">
              <div>
                <div className="text-xs text-muted-foreground">{t('debtForm.repaymentOnDueDate')} ({years} {t('debts.perYear')})</div>
                <div className="text-xl font-bold">{formatCurrency(total, selectedCurrencyCode || 'CNY')}</div>
              </div>
              <div className="text-right text-xs space-y-1">
                <div className="text-muted-foreground">{t('debtForm.principalDisplay', { label: t('debtForm.principal'), value: p.toLocaleString() })}</div>
                <div className="text-muted-foreground">{t('debtForm.interestDisplay', { label: t('debtForm.interest'), rate: interest_rate, years, value: interest.toLocaleString() })}</div>
              </div>
            </div>
            );
          })()}

          {repaymentMode === 'installment' && paymentPreview.length > 0 && (
            <div className="rounded-xl border border-emerald-200/50 bg-gradient-to-br from-emerald-50/50 to-card p-4 dark:from-emerald-950/20 dark:to-card dark:border-emerald-800/30">
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-medium text-emerald-700 dark:text-emerald-400">{t('debtForm.monthlyPayment')}</span>
                <span className="text-xl font-bold text-emerald-700 dark:text-emerald-400">{formatCurrency(paymentPreview[0]?.total_amount || 0, selectedCurrencyCode || 'CNY')}</span>
              </div>
              <div className="flex justify-between text-xs text-muted-foreground">
                <span>{paymentPreview.length} {t('debtForm.payments')}</span>
                <span>{t('debtForm.totalInterestDisplay', { label: t('debtForm.totalInterest'), value: totalInterest.toLocaleString() })}</span>
              </div>
              <details className="mt-3">
                <summary className="text-xs text-primary cursor-pointer">{t('debtForm.viewSchedule')}</summary>
                <div className="max-h-40 overflow-y-auto mt-2 rounded-lg border">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>#</TableHead>
                        <TableHead>{t('debtForm.date')}</TableHead>
                        <TableHead className="text-right">{t('debtForm.payment')}</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {paymentPreview.map((payment, i) => (
                        <TableRow key={i}>
                          <TableCell className="text-xs">{i + 1}</TableCell>
                          <TableCell className="text-xs">{payment.payment_date}</TableCell>
                          <TableCell className="text-xs text-right font-medium">{formatCurrency(payment.total_amount || 0, selectedCurrencyCode || 'CNY')}</TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </div>
              </details>
            </div>
          )}

          <div className="flex justify-end gap-2 pt-4">
            <Button type="button" variant="outline" onClick={onCancel} disabled={isLoading}>
              {readOnly ? t('common.close') : t('common.cancel')}
            </Button>
            {!readOnly && (
              <Button type="submit" variant="default-gradient" disabled={isLoading}>
                {isLoading ? t('debtForm.saving') : isEdit ? t('debtForm.saveChanges') : t('debtForm.createDebt')}
              </Button>
            )}
          </div>
        </form>
      </Form>
    </div>
  );
}
