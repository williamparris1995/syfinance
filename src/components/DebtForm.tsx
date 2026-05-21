import { zodResolver } from '@hookform/resolvers/zod';
import { useEffect, useMemo, useState } from 'react';
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
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from './ui/table';
import type { AmortizationMethod, CreateDebtDto, DebtType } from '@/lib/tauri/debt';

const debtFormSchema = z.object({
  debt_type: z.enum(['BorrowedOut', 'BorrowedIn', 'CreditCard', 'Loan'], {
    required_error: 'Debt type is required',
  }),
  counterparty: z.string().min(1, 'Counterparty is required'),
  principal_amount: z.string().min(1, 'Principal amount is required').refine(
    (val) => {
      const num = parseFloat(val);
      return !isNaN(num) && num > 0;
    },
    { message: 'Principal amount must be greater than 0' }
  ),
  currency_code: z.string().min(3, 'Currency code is required').max(3, 'Currency code must be 3 characters'),
  interest_rate: z.string().min(1, 'Interest rate is required').refine(
    (val) => {
      const num = parseFloat(val);
      return !isNaN(num) && num >= 0;
    },
    { message: 'Interest rate must be 0 or greater' }
  ),
  start_date: z.string().optional(),
  due_date: z.string().optional(),
  periods: z.number().optional(),
  amortization_method: z.enum(['EqualPrincipalInterest', 'EqualPrincipal']).nullable(),
}).refine(
  (data) => {
    if (data.start_date && data.due_date) {
      return new Date(data.due_date) > new Date(data.start_date);
    }
    return true;
  },
  {
    message: 'Due date must be after start date',
    path: ['due_date'],
  }
);

type DebtFormValues = z.infer<typeof debtFormSchema>;

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
}

export function DebtForm({ onSubmit, onCancel, isLoading }: DebtFormProps) {
  const { t } = useTranslation();
  const [paymentPreview, setPaymentPreview] = useState<PaymentPreview[]>([]);
  const [repaymentMode, setRepaymentMode] = useState<'lump_sum' | 'installment'>('lump_sum');

  const debtFormSchema = z.object({
    debt_type: z.enum(['BorrowedOut', 'BorrowedIn', 'CreditCard', 'Loan'], {
      required_error: t('debtForm.debtTypeRequired'),
    }),
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
    amortization_method: z.enum(['EqualPrincipalInterest', 'EqualPrincipal']).nullable(),
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

  const form = useForm<DebtFormValues>({
    resolver: zodResolver(debtFormSchema),
    defaultValues: {
      debt_type: 'BorrowedIn',
      counterparty: '',
      principal_amount: '',
      currency_code: 'CNY',
      interest_rate: '',
      start_date: '',
      due_date: '',
      periods: undefined,
      amortization_method: 'EqualPrincipalInterest',
    },
  });

  const watchedValues = form.watch();
  const { principal_amount, interest_rate, start_date, due_date, amortization_method, periods } = watchedValues;

  // Calculate payment schedule preview
  useEffect(() => {
    const timer = setTimeout(() => {
      if (!principal_amount || !interest_rate || !amortization_method) {
        setPaymentPreview([]);
        return;
      }

      const principal = parseFloat(principal_amount);
      const rate = parseFloat(interest_rate) / 100 / 12; // Monthly rate
      const startDateStr = start_date;

      if (isNaN(principal) || isNaN(rate) || principal <= 0 || rate < 0) {
        setPaymentPreview([]);
        return;
      }

      let months: number;

      if (periods && periods > 0) {
        // Installment mode: use periods directly
        months = periods;
      } else if (startDateStr && due_date) {
        // Lump sum / legacy: calculate from date range
        const startDate = new Date(startDateStr);
        const dueDate = new Date(due_date);
        if (dueDate <= startDate) {
          setPaymentPreview([]);
          return;
        }
        months = Math.round(
          (dueDate.getFullYear() - startDate.getFullYear()) * 12 +
          (dueDate.getMonth() - startDate.getMonth())
        );
      } else {
        setPaymentPreview([]);
        return;
      }

      if (months <= 0) {
        setPaymentPreview([]);
        return;
      }

      // Use start_date as schedule start, defaulting to today if empty
      const scheduleStart = startDateStr ? new Date(startDateStr) : new Date();
      const schedule: PaymentPreview[] = [];
      let remainingPrincipal = principal;

      if (amortization_method === 'EqualPrincipalInterest') {
        // 等额本息: Equal total payment each period
        const monthlyPayment = rate === 0
          ? principal / months
          : (principal * rate * Math.pow(1 + rate, months)) / (Math.pow(1 + rate, months) - 1);

        for (let i = 1; i <= months; i++) {
          const interestPayment = remainingPrincipal * rate;
          const principalPayment = monthlyPayment - interestPayment;

          const paymentDate = new Date(scheduleStart);
          paymentDate.setMonth(paymentDate.getMonth() + i);

          schedule.push({
            payment_date: paymentDate.toISOString().split('T')[0],
            principal_amount: principalPayment,
            interest_amount: interestPayment,
            total_amount: monthlyPayment,
          });

          remainingPrincipal -= principalPayment;
        }
      } else {
        // 等额本金: Equal principal each period
        const principalPayment = principal / months;

        for (let i = 1; i <= months; i++) {
          const interestPayment = remainingPrincipal * rate;
          const totalPayment = principalPayment + interestPayment;

          const paymentDate = new Date(scheduleStart);
          paymentDate.setMonth(paymentDate.getMonth() + i);

          schedule.push({
            payment_date: paymentDate.toISOString().split('T')[0],
            principal_amount: principalPayment,
            interest_amount: interestPayment,
            total_amount: totalPayment,
          });

          remainingPrincipal -= principalPayment;
        }
      }

      setPaymentPreview(schedule);
    }, 500); // Debounce 500ms

    return () => clearTimeout(timer);
  }, [watchedValues]);

  const totalInterest = useMemo(() => {
    return paymentPreview.reduce((sum, payment) => sum + payment.interest_amount, 0);
  }, [paymentPreview]);

  const handleSubmit = (values: DebtFormValues) => {
    let resolvedDueDate = values.due_date || '';
    // In installment mode, derive due_date from start_date + periods
    if (repaymentMode === 'installment' && values.periods && values.start_date) {
      const d = new Date(values.start_date);
      d.setMonth(d.getMonth() + values.periods);
      resolvedDueDate = d.toISOString().split('T')[0];
    }

    onSubmit({
      debt_type: values.debt_type as DebtType,
      counterparty: values.counterparty,
      principal_amount: values.principal_amount,
      currency_code: values.currency_code,
      interest_rate: values.interest_rate,
      start_date: values.start_date || '',
      due_date: resolvedDueDate,
      amortization_method: values.amortization_method as AmortizationMethod | null,
    });
  };

  return (
    <div className="space-y-6">
      <Form {...form}>
        <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-4 px-5">
          {/* Repayment mode toggle */}
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

          {/* Hidden currency_code field - kept for schema validation */}
          <input type="hidden" {...form.register('currency_code')} />

          <div className="space-y-4">
            <FormField name="debt_type" render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('debtForm.type')} <span className="text-red-500">*</span>
                </FormLabel>
                <Select value={field.value} onValueChange={field.onChange}>
                  <FormControl><SelectTrigger className="h-9"><SelectValue placeholder={t('debtForm.selectDebtType')} /></SelectTrigger></FormControl>
                  <SelectContent>
                    <SelectItem value="BorrowedIn">{t('debtForm.borrowedIn')}</SelectItem>
                    <SelectItem value="BorrowedOut">{t('debtForm.borrowedOut')}</SelectItem>
                    <SelectItem value="CreditCard">{t('debtForm.creditCard')}</SelectItem>
                    <SelectItem value="Loan">{t('debtForm.loan')}</SelectItem>
                  </SelectContent>
                </Select>
                <FormMessage />
              </FormItem>
            )} />
            <FormField name="counterparty" render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('debtForm.counterparty')} <span className="text-red-500">*</span>
                </FormLabel>
                <FormControl><Input placeholder={t('debtForm.counterpartyPlaceholder')} className="h-9" {...field} /></FormControl>
                <FormMessage />
              </FormItem>
            )} />
          </div>

          <div className="space-y-4">
            <FormField name="principal_amount" render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                  {t('debtForm.principal')} <span className="text-red-500">*</span>
                </FormLabel>
                <FormControl>
                  <div className="flex items-center rounded-lg border overflow-hidden h-9">
                    <span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-r">¥</span>
                    <input className="flex-1 border-0 bg-transparent px-2.5 text-sm outline-none" placeholder="100,000" {...field} />
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
                    <input className="flex-1 border-0 bg-transparent px-2.5 text-sm outline-none" placeholder="5.5" {...field} />
                    <span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-l">%</span>
                  </div>
                </FormControl>
                <FormMessage />
              </FormItem>
            )} />

            {repaymentMode === 'lump_sum' ? (
              <FormField name="due_date" render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                    {t('debtForm.dueDate')} <span className="text-red-500">*</span>
                  </FormLabel>
                  <FormControl><Input type="date" className="h-9" {...field} /></FormControl>
                  <FormMessage />
                </FormItem>
              )} />
            ) : (
              <FormField name="periods" render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                    {t('debtForm.periods')} <span className="text-red-500">*</span>
                  </FormLabel>
                  <Select value={field.value?.toString() || ''} onValueChange={(v) => field.onChange(parseInt(v))}>
                    <FormControl><SelectTrigger className="h-9"><SelectValue placeholder={t('debtForm.selectPeriods')} /></SelectTrigger></FormControl>
                    <SelectContent>
                      {[3, 6, 12, 24, 36, 60].map((n) => (
                        <SelectItem key={n} value={n.toString()}>{n} {t('debtForm.months')}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )} />
            )}
          </div>

          {repaymentMode === 'installment' && (
            <div className="space-y-4">
              <FormField name="start_date" render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                    {t('debtForm.startDate')}
                  </FormLabel>
                  <FormControl><Input type="date" className="h-9" {...field} /></FormControl>
                  <FormMessage />
                </FormItem>
              )} />
              <FormField name="amortization_method" render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                    {t('debtForm.amortizationMethod')}
                  </FormLabel>
                  <Select value={field.value || undefined} onValueChange={field.onChange}>
                    <FormControl><SelectTrigger className="h-9"><SelectValue placeholder={t('debtForm.selectAmortization')} /></SelectTrigger></FormControl>
                    <SelectContent>
                      <SelectItem value="EqualPrincipalInterest">{t('debtForm.equalPI')}</SelectItem>
                      <SelectItem value="EqualPrincipal">{t('debtForm.equalPrincipal')}</SelectItem>
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )} />
            </div>
          )}

          {/* Lump sum summary */}
          {repaymentMode === 'lump_sum' && principal_amount && interest_rate && (
            <div className="rounded-xl border border-blue-200/50 bg-gradient-to-br from-blue-50/50 to-card p-4 flex items-center justify-between dark:from-blue-950/20 dark:to-card dark:border-blue-800/30">
              <div>
                <div className="text-xs text-muted-foreground">{t('debtForm.repaymentOnDueDate')}</div>
                <div className="text-xl font-bold">¥{(parseFloat(principal_amount) * (1 + parseFloat(interest_rate || '0') / 100)).toLocaleString()}</div>
              </div>
              <div className="text-right text-xs space-y-1">
                <div className="text-muted-foreground">{t('debtForm.principal')}: ¥{parseFloat(principal_amount).toLocaleString()}</div>
                <div className="text-muted-foreground">{t('debtForm.interest')} ({interest_rate}%): +¥{(parseFloat(principal_amount) * parseFloat(interest_rate || '0') / 100).toLocaleString()}</div>
              </div>
            </div>
          )}

          {/* Installment summary */}
          {repaymentMode === 'installment' && paymentPreview.length > 0 && (
            <div className="rounded-xl border border-emerald-200/50 bg-gradient-to-br from-emerald-50/50 to-card p-4 dark:from-emerald-950/20 dark:to-card dark:border-emerald-800/30">
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-medium text-emerald-700 dark:text-emerald-400">{t('debtForm.monthlyPayment')}</span>
                <span className="text-xl font-bold text-emerald-700 dark:text-emerald-400">¥{paymentPreview[0]?.total_amount?.toLocaleString() || '0'}</span>
              </div>
              <div className="flex justify-between text-xs text-muted-foreground">
                <span>{paymentPreview.length} {t('debtForm.payments')}</span>
                <span>{t('debtForm.totalInterest')}: ¥{totalInterest.toLocaleString()}</span>
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
                          <TableCell className="text-xs text-right font-medium">¥{payment.total_amount?.toLocaleString() || '0'}</TableCell>
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
              {t('common.cancel')}
            </Button>
            <Button type="submit" variant="default-gradient" disabled={isLoading}>
              {isLoading ? t('debtForm.creating') : t('debtForm.createDebt')}
            </Button>
          </div>
        </form>
      </Form>
    </div>
  );
}
