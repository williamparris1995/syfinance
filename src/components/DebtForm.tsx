import { zodResolver } from '@hookform/resolvers/zod';
import { useEffect, useMemo, useState } from 'react';
import { useForm } from 'react-hook-form';
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
  start_date: z.string().min(1, 'Start date is required'),
  due_date: z.string().min(1, 'Due date is required'),
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
  const [paymentPreview, setPaymentPreview] = useState<PaymentPreview[]>([]);
  
  const form = useForm<DebtFormValues>({
    resolver: zodResolver(debtFormSchema),
    defaultValues: {
      debt_type: undefined,
      counterparty: '',
      principal_amount: '',
      currency_code: 'CNY',
      interest_rate: '',
      start_date: '',
      due_date: '',
      amortization_method: 'EqualPrincipalInterest',
    },
  });

  const watchedValues = form.watch();

  // Calculate payment schedule preview
  useEffect(() => {
    const timer = setTimeout(() => {
      const { principal_amount, interest_rate, start_date, due_date, amortization_method } = watchedValues;
      
      if (!principal_amount || !interest_rate || !start_date || !due_date || !amortization_method) {
        setPaymentPreview([]);
        return;
      }

      const principal = parseFloat(principal_amount);
      const rate = parseFloat(interest_rate) / 100 / 12; // Monthly rate
      const startDate = new Date(start_date);
      const dueDate = new Date(due_date);

      if (isNaN(principal) || isNaN(rate) || principal <= 0 || rate < 0 || dueDate <= startDate) {
        setPaymentPreview([]);
        return;
      }

      // Calculate number of months
      const months = Math.round(
        (dueDate.getFullYear() - startDate.getFullYear()) * 12 +
        (dueDate.getMonth() - startDate.getMonth())
      );

      if (months <= 0) {
        setPaymentPreview([]);
        return;
      }

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
          
          const paymentDate = new Date(startDate);
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

          const paymentDate = new Date(startDate);
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
    onSubmit({
      debt_type: values.debt_type as DebtType,
      counterparty: values.counterparty,
      principal_amount: values.principal_amount,
      currency_code: values.currency_code,
      interest_rate: values.interest_rate,
      start_date: values.start_date,
      due_date: values.due_date,
      amortization_method: values.amortization_method as AmortizationMethod | null,
    });
  };

  return (
    <div className="space-y-6">
      <Form {...form}>
        <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-4">
          <FormField
            control={form.control}
            name="debt_type"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Debt Type</FormLabel>
                <Select onValueChange={field.onChange} defaultValue={field.value}>
                  <FormControl>
                    <SelectTrigger>
                      <SelectValue placeholder="Select debt type" />
                    </SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    <SelectItem value="BorrowedOut">Borrowed Out (Lent Money)</SelectItem>
                    <SelectItem value="BorrowedIn">Borrowed In (Owed Money)</SelectItem>
                    <SelectItem value="CreditCard">Credit Card</SelectItem>
                    <SelectItem value="Loan">Loan</SelectItem>
                  </SelectContent>
                </Select>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="counterparty"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Counterparty</FormLabel>
                <FormControl>
                  <Input placeholder="e.g., Bank of China, John Doe" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />

          <div className="grid grid-cols-2 gap-4">
            <FormField
              control={form.control}
              name="principal_amount"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Principal Amount</FormLabel>
                  <FormControl>
                    <Input type="text" placeholder="10000.00" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="currency_code"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Currency</FormLabel>
                  <Select onValueChange={field.onChange} defaultValue={field.value}>
                    <FormControl>
                      <SelectTrigger>
                        <SelectValue placeholder="Select currency" />
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
          </div>

          <FormField
            control={form.control}
            name="interest_rate"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Interest Rate (% per year)</FormLabel>
                <FormControl>
                  <Input type="text" placeholder="5.5" {...field} />
                </FormControl>
                <FormMessage />
              </FormItem>
            )}
          />

          <div className="grid grid-cols-2 gap-4">
            <FormField
              control={form.control}
              name="start_date"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Start Date</FormLabel>
                  <FormControl>
                    <Input type="date" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="due_date"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Due Date</FormLabel>
                  <FormControl>
                    <Input type="date" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
          </div>

          <FormField
            control={form.control}
            name="amortization_method"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Amortization Method</FormLabel>
                <Select 
                  onValueChange={field.onChange} 
                  defaultValue={field.value || undefined}
                >
                  <FormControl>
                    <SelectTrigger>
                      <SelectValue placeholder="Select amortization method" />
                    </SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    <SelectItem value="EqualPrincipalInterest">
                      等额本息 (Equal Total Payment)
                    </SelectItem>
                    <SelectItem value="EqualPrincipal">
                      等额本金 (Equal Principal)
                    </SelectItem>
                  </SelectContent>
                </Select>
                <FormMessage />
              </FormItem>
            )}
          />

          <div className="flex justify-end gap-2 pt-4">
            <Button type="button" variant="outline" onClick={onCancel} disabled={isLoading}>
              Cancel
            </Button>
            <Button type="submit" disabled={isLoading}>
              {isLoading ? 'Creating...' : 'Create Debt'}
            </Button>
          </div>
        </form>
      </Form>

      {paymentPreview.length > 0 && (
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <h3 className="text-lg font-semibold">Payment Schedule Preview</h3>
            <div className="text-sm text-neutral-600">
              Total Interest: {totalInterest.toLocaleString('en-US', {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2,
              })}
            </div>
          </div>
          
          <div className="border rounded-lg max-h-[400px] overflow-y-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Payment Date</TableHead>
                  <TableHead className="text-right">Principal</TableHead>
                  <TableHead className="text-right">Interest</TableHead>
                  <TableHead className="text-right">Total</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {paymentPreview.map((payment, index) => (
                  <TableRow key={index}>
                    <TableCell>
                      {new Date(payment.payment_date).toLocaleDateString('en-US', {
                        year: 'numeric',
                        month: 'short',
                        day: 'numeric',
                      })}
                    </TableCell>
                    <TableCell className="text-right">
                      {payment.principal_amount.toLocaleString('en-US', {
                        minimumFractionDigits: 2,
                        maximumFractionDigits: 2,
                      })}
                    </TableCell>
                    <TableCell className="text-right">
                      {payment.interest_amount.toLocaleString('en-US', {
                        minimumFractionDigits: 2,
                        maximumFractionDigits: 2,
                      })}
                    </TableCell>
                    <TableCell className="text-right font-medium">
                      {payment.total_amount.toLocaleString('en-US', {
                        minimumFractionDigits: 2,
                        maximumFractionDigits: 2,
                      })}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        </div>
      )}
    </div>
  );
}
