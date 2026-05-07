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

// Mapping from account type to chart of account code
const ACCOUNT_TYPE_TO_CODE: Record<string, string> = {
  Cash: '1001',        // 库存现金
  Bank: '1002',        // 银行存款
  CreditCard: '2202',  // 应付信用卡款
  Investment: '1012',  // 其他货币资金
  Loan: '2001',        // 短期借款
  Other: '1012',       // 其他货币资金
};

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
    },
  });

  const handleSubmit = (values: AccountFormValues) => {
    // Auto-select chart of account code based on account type
    const chart_of_account_code = ACCOUNT_TYPE_TO_CODE[values.account_type] || '1012';
    
    onSubmit({
      ...values,
      chart_of_account_code,
      account_type: values.account_type as AccountType,
      initial_balance: parseFloat(values.initial_balance),
    });
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
              <FormDescription>
                Chart of account code will be automatically assigned
              </FormDescription>
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
