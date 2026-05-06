import { zodResolver } from '@hookform/resolvers/zod';
import { useQuery } from '@tanstack/react-query';
import { Plus, Trash2 } from 'lucide-react';
import { useFieldArray, useForm } from 'react-hook-form';
import { z } from 'zod';
import { listAccounts } from '@/lib/tauri/account';
import type { CreateTransactionDto } from '@/lib/tauri/transaction';
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

const transactionEntrySchema = z
  .object({
    account_id: z.string().min(1, 'Account is required'),
    chart_of_account_code: z.string().min(1, 'Chart of account code is required'),
    debit_amount: z.string().nullable(),
    credit_amount: z.string().nullable(),
    memo: z.string().nullable(),
  })
  .refine(
    (data) => {
      const hasDebit = data.debit_amount && data.debit_amount !== '' && parseFloat(data.debit_amount) !== 0;
      const hasCredit = data.credit_amount && data.credit_amount !== '' && parseFloat(data.credit_amount) !== 0;
      return (hasDebit && !hasCredit) || (!hasDebit && hasCredit);
    },
    {
      message: 'Each entry must have either debit OR credit amount (not both, not neither)',
      path: ['debit_amount'],
    }
  );

const transactionFormSchema = z.object({
  transaction_date: z.string().min(1, 'Transaction date is required'),
  description: z.string().min(1, 'Description is required'),
  entries: z.array(transactionEntrySchema).min(2, 'At least 2 entries are required'),
});

type TransactionFormValues = z.infer<typeof transactionFormSchema>;

interface TransactionFormProps {
  onSubmit: (data: CreateTransactionDto) => void;
  onCancel: () => void;
  isLoading?: boolean;
}

export function TransactionForm({ onSubmit, onCancel, isLoading }: TransactionFormProps) {
  const { data: accounts = [] } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
  });

  const form = useForm<TransactionFormValues>({
    resolver: zodResolver(transactionFormSchema),
    defaultValues: {
      transaction_date: new Date().toISOString().split('T')[0],
      description: '',
      entries: [
        { account_id: '', chart_of_account_code: '', debit_amount: null, credit_amount: null, memo: null },
        { account_id: '', chart_of_account_code: '', debit_amount: null, credit_amount: null, memo: null },
      ],
    },
  });

  const { fields, append, remove } = useFieldArray({
    control: form.control,
    name: 'entries',
  });

  const watchEntries = form.watch('entries');

  const calculateBalance = () => {
    let totalDebit = 0;
    let totalCredit = 0;

    watchEntries.forEach((entry) => {
      if (entry.debit_amount) {
        const debit = parseFloat(entry.debit_amount);
        if (!isNaN(debit)) totalDebit += debit;
      }
      if (entry.credit_amount) {
        const credit = parseFloat(entry.credit_amount);
        if (!isNaN(credit)) totalCredit += credit;
      }
    });

    return totalDebit - totalCredit;
  };

  const balance = calculateBalance();
  const isBalanced = Math.abs(balance) < 0.01;

  const handleSubmit = (values: TransactionFormValues) => {
    if (!isBalanced) {
      form.setError('root', {
        message: 'Transaction must be balanced (total debits = total credits)',
      });
      return;
    }

    onSubmit({
      transaction_date: values.transaction_date,
      description: values.description,
      entries: values.entries.map((entry) => ({
        account_id: entry.account_id,
        chart_of_account_code: entry.chart_of_account_code,
        debit_amount: entry.debit_amount && entry.debit_amount !== '' ? entry.debit_amount : null,
        credit_amount: entry.credit_amount && entry.credit_amount !== '' ? entry.credit_amount : null,
        memo: entry.memo && entry.memo !== '' ? entry.memo : null,
      })),
    });
  };

  const handleAccountChange = (index: number, accountId: string | null) => {
    if (!accountId) return;
    const account = accounts.find((a) => a.id === accountId);
    if (account) {
      form.setValue(`entries.${index}.account_id`, accountId);
      form.setValue(`entries.${index}.chart_of_account_code`, account.chart_of_account_code);
    }
  };

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-4">
        <FormField
          control={form.control}
          name="transaction_date"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Transaction Date</FormLabel>
              <FormControl>
                <Input type="date" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="description"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Description</FormLabel>
              <FormControl>
                <Input placeholder="e.g., Salary payment" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <FormLabel>Entries</FormLabel>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() =>
                append({
                  account_id: '',
                  chart_of_account_code: '',
                  debit_amount: null,
                  credit_amount: null,
                  memo: null,
                })
              }
            >
              <Plus className="h-4 w-4 mr-1" />
              Add Entry
            </Button>
          </div>

          {fields.map((field, index) => (
            <div key={field.id} className="border rounded-lg p-4 space-y-3">
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm font-medium">Entry {index + 1}</span>
                {fields.length > 2 && (
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={() => remove(index)}
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                )}
              </div>

              <FormField
                control={form.control}
                name={`entries.${index}.account_id`}
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Account</FormLabel>
                    <Select
                      onValueChange={(value) => handleAccountChange(index, value)}
                      defaultValue={field.value}
                    >
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue placeholder="Select account" />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        {accounts.map((account) => (
                          <SelectItem key={account.id} value={account.id}>
                            {account.name} ({account.chart_of_account_code})
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <div className="grid grid-cols-2 gap-3">
                <FormField
                  control={form.control}
                  name={`entries.${index}.debit_amount`}
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Debit Amount</FormLabel>
                      <FormControl>
                        <Input
                          type="text"
                          placeholder="0.00"
                          {...field}
                          value={field.value || ''}
                          onChange={(e) => {
                            const value = e.target.value;
                            field.onChange(value === '' ? null : value);
                            if (value !== '') {
                              form.setValue(`entries.${index}.credit_amount`, null);
                            }
                          }}
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />

                <FormField
                  control={form.control}
                  name={`entries.${index}.credit_amount`}
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Credit Amount</FormLabel>
                      <FormControl>
                        <Input
                          type="text"
                          placeholder="0.00"
                          {...field}
                          value={field.value || ''}
                          onChange={(e) => {
                            const value = e.target.value;
                            field.onChange(value === '' ? null : value);
                            if (value !== '') {
                              form.setValue(`entries.${index}.debit_amount`, null);
                            }
                          }}
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>

              <FormField
                control={form.control}
                name={`entries.${index}.memo`}
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Memo (Optional)</FormLabel>
                    <FormControl>
                      <Input
                        placeholder="Additional notes"
                        {...field}
                        value={field.value || ''}
                        onChange={(e) => field.onChange(e.target.value === '' ? null : e.target.value)}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>
          ))}
        </div>

        <div className="flex items-center justify-between p-4 bg-neutral-50 rounded-lg">
          <span className="font-medium">Balance:</span>
          <span
            className={`font-bold ${
              isBalanced ? 'text-green-600' : 'text-red-600'
            }`}
          >
            {isBalanced ? '✓ Balanced' : `Unbalanced: ${balance.toFixed(2)} CNY`}
          </span>
        </div>

        {form.formState.errors.root && (
          <div className="p-3 bg-red-50 border border-red-200 rounded-lg text-red-700 text-sm">
            {form.formState.errors.root.message}
          </div>
        )}

        <div className="flex justify-end gap-2 pt-4">
          <Button type="button" variant="outline" onClick={onCancel} disabled={isLoading}>
            Cancel
          </Button>
          <Button type="submit" disabled={isLoading || !isBalanced}>
            {isLoading ? 'Creating...' : 'Create Transaction'}
          </Button>
        </div>
      </form>
    </Form>
  );
}
