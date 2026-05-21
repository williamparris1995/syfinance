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
  const { t } = useTranslation();
  
  const currencyFormSchema = z.object({
    code: z
      .string()
      .length(3, t('currencyForm.codeLength'))
      .regex(/^[A-Z]{3}$/, t('currencyForm.codeFormat')),
    symbol: z.string().min(1, t('currencyForm.symbolRequired')),
    exchange_rate: z
      .string()
      .min(1, t('currencyForm.exchangeRateRequired'))
      .refine((val) => !isNaN(parseFloat(val)) && parseFloat(val) > 0, {
        message: t('currencyForm.exchangeRatePositive'),
      }),
  });
  
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
              <FormLabel>{t('currencyForm.currencyCode')}</FormLabel>
              <FormControl>
                <Input
                  maxLength={3}
                  placeholder="CNY"
                  className="uppercase"
                  {...field}
                  onChange={(e) => field.onChange(e.target.value.toUpperCase())}
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
              <FormLabel>{t('currencyForm.currencySymbol')}</FormLabel>
              <FormControl>
                <Input placeholder={t('currencyForm.currencySymbolPlaceholder')} {...field} />
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
              <FormLabel>{t('currencyForm.exchangeRate')}</FormLabel>
              <FormControl>
                <Input
                  type="number"
                  step="0.0001"
                  min="0"
                  placeholder={t('currencyForm.exchangeRatePlaceholder')}
                  {...field}
                />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <div className="flex justify-end gap-2 pt-4">
          <Button type="button" variant="outline" onClick={onCancel} disabled={isLoading}>
            {t('common.cancel')}
          </Button>
          <Button type="submit" variant="default-gradient" disabled={isLoading}>
            {isLoading ? t('common.create') + '...' : t('settings.addCurrency')}
          </Button>
        </div>
      </form>
    </Form>
  );
}
