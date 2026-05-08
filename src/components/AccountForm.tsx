import { zodResolver } from '@hookform/resolvers/zod';
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

const accountFormSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  account_type: z.enum(['Cash', 'Bank', 'CreditCard', 'Investment', 'Loan', 'Other'], {
    required_error: 'Account type is required',
  }),
  currency_code: z.string().min(3, 'Currency code is required').max(3, 'Currency code must be 3 characters'),
  initial_balance: z.string().min(1, 'Initial balance is required').refine(
    (val) => !isNaN(parseFloat(val)),
    'Initial balance must be a valid number'
  ),
  account_number: z.string().optional(),
  institution: z.string().optional(),
  credit_limit: z.string().optional().refine(
    (val) => !val || !isNaN(parseFloat(val)),
    'Credit limit must be a valid number'
  ),
  billing_day: z.string().optional().refine(
    (val) => !val || (!isNaN(parseInt(val)) && parseInt(val) >= 1 && parseInt(val) <= 31),
    'Billing day must be between 1 and 31'
  ),
  payment_due_day: z.string().optional().refine(
    (val) => !val || (!isNaN(parseInt(val)) && parseInt(val) >= 1 && parseInt(val) <= 31),
    'Payment due day must be between 1 and 31'
  ),
  interest_rate: z.string().optional().refine(
    (val) => !val || !isNaN(parseFloat(val)),
    'Interest rate must be a valid number'
  ),
});

type AccountFormValues = z.infer<typeof accountFormSchema>;

interface AccountFormProps {
  onSubmit: (data: CreateAccountDto) => void;
  onCancel: () => void;
  isLoading?: boolean;
}

export function AccountForm({ onSubmit, onCancel, isLoading }: AccountFormProps) {
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
              <FormLabel>Account Name</FormLabel>
              <FormControl>
                <Input placeholder="e.g., Checking Account" {...field} />
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
              <FormLabel>Account Type</FormLabel>
              <Select onValueChange={field.onChange} defaultValue={field.value}>
                <FormControl>
                  <SelectTrigger>
                    <SelectValue placeholder="Select account type" />
                  </SelectTrigger>
                </FormControl>
                <SelectContent>
                  <SelectItem value="Cash">Cash (库存现金)</SelectItem>
                  <SelectItem value="Bank">Bank (银行存款)</SelectItem>
                  <SelectItem value="CreditCard">Credit Card (信用卡)</SelectItem>
                  <SelectItem value="Investment">Investment (投资)</SelectItem>
                  <SelectItem value="Loan">Loan (借款)</SelectItem>
                  <SelectItem value="Other">Other (其他)</SelectItem>
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

        <FormField
          control={form.control}
          name="initial_balance"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Initial Balance</FormLabel>
              <FormControl>
                <Input type="text" placeholder="0.00" {...field} />
              </FormControl>
              <FormDescription>
                For credit cards: enter the amount you owe (positive number)
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
              <FormLabel>Account Number (Optional)</FormLabel>
              <FormControl>
                <Input placeholder="e.g., 1234567890" {...field} />
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
              <FormLabel>Institution (Optional)</FormLabel>
              <FormControl>
                <Input placeholder="e.g., Bank of China" {...field} />
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
                  <FormLabel>Credit Limit (Optional)</FormLabel>
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
                  <FormLabel>Billing Day (Optional)</FormLabel>
                  <FormControl>
                    <Input type="text" placeholder="1-31" {...field} />
                  </FormControl>
                  <FormDescription>Day of month when statement is generated</FormDescription>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="payment_due_day"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Payment Due Day (Optional)</FormLabel>
                  <FormControl>
                    <Input type="text" placeholder="1-31" {...field} />
                  </FormControl>
                  <FormDescription>Day of month when payment is due</FormDescription>
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
                <FormLabel>Interest Rate (Optional)</FormLabel>
                <FormControl>
                  <Input type="text" placeholder="e.g., 5.5" {...field} />
                </FormControl>
                <FormDescription>Annual interest rate as percentage</FormDescription>
                <FormMessage />
              </FormItem>
            )}
          />
        )}

        <div className="flex justify-end gap-2 pt-4">
          <Button type="button" variant="outline" onClick={onCancel} disabled={isLoading}>
            Cancel
          </Button>
          <Button type="submit" disabled={isLoading}>
            {isLoading ? 'Creating...' : 'Create Account'}
          </Button>
        </div>
      </form>
    </Form>
  );
}
