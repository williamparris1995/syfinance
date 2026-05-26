import { useQuery } from '@tanstack/react-query';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { useTranslation } from 'react-i18next';
import { z } from 'zod';
import { Button } from './ui/button';
import {
  Form, FormControl, FormField, FormItem, FormLabel, FormMessage,
} from './ui/form';
import { Input } from './ui/input';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from './ui/select';
import { listAccounts, type AccountDto } from '@/lib/tauri/account';
import { listSecurities, type SecurityDto, type HoldingTradeDto } from '@/lib/tauri/holding';

interface Props {
  onSubmit: (data: HoldingTradeDto) => void;
  onCancel: () => void;
  isLoading?: boolean;
}

const tradeSchema = z.object({
  account_id: z.string().min(1, 'Account is required'),
  security_id: z.string().min(1, 'Security is required'),
  direction: z.enum(['BUY', 'SELL']),
  quantity: z.string().min(1).refine(v => !isNaN(parseFloat(v)) && parseFloat(v) > 0, 'Must be positive'),
  price: z.string().min(1).refine(v => !isNaN(parseFloat(v)) && parseFloat(v) > 0, 'Must be positive'),
  fee: z.string().refine(v => v === '' || !isNaN(parseFloat(v)), 'Must be a number'),
  trade_date: z.string().min(1, 'Date is required'),
  notes: z.string().optional(),
});

type FormValues = z.infer<typeof tradeSchema>;

export function HoldingTradeForm({ onSubmit, onCancel, isLoading }: Props) {
  const { t } = useTranslation();

  const { data: accounts = [] } = useQuery({ queryKey: ['accounts'], queryFn: listAccounts });
  const { data: securities = [] } = useQuery({ queryKey: ['securities'], queryFn: listSecurities });

  const investmentAccounts = accounts.filter(a => a.account_type === 'Investment');
  const today = new Date().toISOString().split('T')[0];

  const form = useForm<FormValues>({
    resolver: zodResolver(tradeSchema),
    defaultValues: { account_id: '', security_id: '', direction: 'BUY', quantity: '', price: '', fee: '0', trade_date: today, notes: '' },
  });

  const handleSubmit = (values: FormValues) => {
    onSubmit({
      account_id: values.account_id,
      security_id: values.security_id,
      direction: values.direction as 'BUY' | 'SELL',
      quantity: parseFloat(values.quantity),
      price: parseFloat(values.price),
      fee: parseFloat(values.fee || '0'),
      trade_date: values.trade_date,
      notes: values.notes || null,
    });
  };

  const watched = form.watch();
  const estimatedAmount = parseFloat(watched.quantity || '0') * parseFloat(watched.price || '0');

  return (
    <div className="space-y-6">
      <Form {...form}>
        <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-4 px-5">
          <FormField name="account_id" render={({ field }) => (
            <FormItem>
              <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">{t('holding.account')} <span className="text-red-500">*</span></FormLabel>
              <Select value={field.value} onValueChange={field.onChange}>
                <FormControl><SelectTrigger className="h-9"><SelectValue placeholder={t('holding.selectAccount')} /></SelectTrigger></FormControl>
                <SelectContent>
                  {investmentAccounts.map(a => (<SelectItem key={a.id} value={a.id}>{a.name}</SelectItem>))}
                </SelectContent>
              </Select>
              <FormMessage />
            </FormItem>
          )} />

          <FormField name="security_id" render={({ field }) => (
            <FormItem>
              <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">{t('holding.security')} <span className="text-red-500">*</span></FormLabel>
              <Select value={field.value} onValueChange={field.onChange}>
                <FormControl><SelectTrigger className="h-9"><SelectValue placeholder={t('holding.selectSecurity')} /></SelectTrigger></FormControl>
                <SelectContent>
                  {securities.map(s => (<SelectItem key={s.id} value={s.id}>{s.symbol} {s.name}</SelectItem>))}
                </SelectContent>
              </Select>
              <FormMessage />
            </FormItem>
          )} />

          <FormField name="direction" render={({ field }) => (
            <FormItem>
              <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">{t('holding.direction')}</FormLabel>
              <div className="flex gap-2">
                <Button type="button" size="sm" variant={field.value === 'BUY' ? 'default' : 'outline'} onClick={() => field.onChange('BUY')}>{t('holding.buy')}</Button>
                <Button type="button" size="sm" variant={field.value === 'SELL' ? 'default' : 'outline'} onClick={() => field.onChange('SELL')}>{t('holding.sell')}</Button>
              </div>
            </FormItem>
          )} />

          <div className="grid grid-cols-2 gap-4">
            <FormField name="quantity" render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">{t('holding.quantity')} <span className="text-red-500">*</span></FormLabel>
                <FormControl><Input type="number" step="any" className="h-9" {...field} /></FormControl>
                <FormMessage />
              </FormItem>
            )} />
            <FormField name="price" render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">{t('holding.price')} <span className="text-red-500">*</span></FormLabel>
                <FormControl><Input type="number" step="any" className="h-9" {...field} /></FormControl>
                <FormMessage />
              </FormItem>
            )} />
          </div>

          <FormField name="fee" render={({ field }) => (
            <FormItem>
              <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">{t('holding.fee')}</FormLabel>
              <FormControl><Input type="number" step="any" className="h-9" {...field} /></FormControl>
              <FormMessage />
            </FormItem>
          )} />

          <FormField name="trade_date" render={({ field }) => (
            <FormItem>
              <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">{t('holding.tradeDate')} <span className="text-red-500">*</span></FormLabel>
              <FormControl><Input type="date" className="h-9" {...field} /></FormControl>
              <FormMessage />
            </FormItem>
          )} />

          {estimatedAmount > 0 && (
            <div className="text-xs text-muted-foreground">{t('holding.estimatedAmount')}: ¥{estimatedAmount.toLocaleString('en-US', { minimumFractionDigits: 2 })}</div>
          )}

          <div className="flex justify-end gap-2 pt-4">
            <Button type="button" variant="outline" onClick={onCancel} disabled={isLoading}>{t('common.cancel')}</Button>
            <Button type="submit" variant="default-gradient" disabled={isLoading}>
              {isLoading ? t('holding.submitting') : watched.direction === 'BUY' ? t('holding.buy') : t('holding.sell')}
            </Button>
          </div>
        </form>
      </Form>
    </div>
  );
}
