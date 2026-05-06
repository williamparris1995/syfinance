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
} from './ui/form';
import { Input } from './ui/input';
import type { AddCurrencyDto } from '@/lib/tauri/currency';

const currencyFormSchema = z.object({
  code: z
    .string()
    .length(3, 'Currency code must be exactly 3 characters')
    .regex(/^[A-Z]{3}$/, 'Currency code must be 3 uppercase letters (ISO 4217)'),
  symbol: z.string().min(1, 'Currency symbol is required'),
  exchange_rate: z
    .string()
    .min(1, 'Exchange rate is required')
    .refine((val) => !isNaN(parseFloat(val)) && parseFloat(val) > 0, {
      message: 'Exchange rate must be greater than 0',
    }),
});

type CurrencyFormValues = z.infer<typeof currencyFormSchema>;

interface CurrencyFormProps {
  onSubmit: (data: AddCurrencyDto) => void;
  onCancel: () => void;
  isLoading?: boolean;
}

export function CurrencyForm({ onSubmit, onCancel, isLoading }: CurrencyFormProps) {
  const form = useForm<CurrencyFormValues>({
    resolver: zodResolver(currencyFormSchema),
    defaultValues: {
      code: '',
      symbol: '',
      exchange_rate: '',
    },
  });

  const handleSubmit = (values: CurrencyFormValues) => {
    onSubmit(values);
  };

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-4">
        <FormField
          control={form.control}
          name="code"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Currency Code</FormLabel>
              <FormControl>
                <Input
                  placeholder="e.g., USD"
                  {...field}
                  onChange={(e) => field.onChange(e.target.value.toUpperCase())}
                  maxLength={3}
                />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="symbol"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Currency Symbol</FormLabel>
              <FormControl>
                <Input placeholder="e.g., $" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="exchange_rate"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Exchange Rate (relative to CNY)</FormLabel>
              <FormControl>
                <Input type="text" placeholder="e.g., 0.14" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <div className="flex justify-end gap-2 pt-4">
          <Button type="button" variant="outline" onClick={onCancel} disabled={isLoading}>
            Cancel
          </Button>
          <Button type="submit" disabled={isLoading}>
            {isLoading ? 'Adding...' : 'Add Currency'}
          </Button>
        </div>
      </form>
    </Form>
  );
}
