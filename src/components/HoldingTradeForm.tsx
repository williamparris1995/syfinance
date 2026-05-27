import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { useTranslation } from 'react-i18next';
import { z } from 'zod';
import { Plus } from 'lucide-react';
import { Button } from './ui/button';
import {
  Form, FormControl, FormField, FormItem, FormLabel, FormMessage,
} from './ui/form';
import { Input } from './ui/input';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from './ui/select';
import { listAccounts, type AccountDto } from '@/lib/tauri/account';
import {
  listSecurities, createSecurity, type SecurityDto, type HoldingTradeDto, type SecurityType,
} from '@/lib/tauri/holding';
import { useState } from 'react';

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

const SECURITY_TYPES: { value: SecurityType; label: string }[] = [
  { value: 'stock', label: '股票' },
  { value: 'fund', label: '基金' },
  { value: 'etf', label: 'ETF' },
  { value: 'bond', label: '债券' },
  { value: 'gold', label: '黄金' },
  { value: 'option', label: '期权' },
  { value: 'other', label: '其他' },
];

export function HoldingTradeForm({ onSubmit, onCancel, isLoading }: Props) {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const [showAddSecurity, setShowAddSecurity] = useState(false);

  const { data: accounts = [] } = useQuery({ queryKey: ['accounts'], queryFn: listAccounts });
  const { data: securities = [] } = useQuery({ queryKey: ['securities'], queryFn: listSecurities });

  const investmentAccounts = accounts.filter(a => a.account_type === 'Investment');
  const today = new Date().toISOString().split('T')[0];

  const accountNameMap = Object.fromEntries(investmentAccounts.map(a => [a.id, a.name]));
  const securityNameMap = Object.fromEntries(securities.map(s => [s.id, `${s.symbol} ${s.name}`]));

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

  const handleCreateSecurity = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formEl = e.currentTarget;
    const formData = new FormData(formEl);
    const symbol = (formData.get('new_symbol') as string)?.trim();
    const name = (formData.get('new_name') as string)?.trim();
    const type = formData.get('new_type') as SecurityType;

    if (!symbol || !name || !type) return;

    try {
      const newSecurity = await createSecurity({
        symbol,
        name,
        security_type: type,
        currency_code: 'CNY',
      });
      await queryClient.invalidateQueries({ queryKey: ['securities'] });
      form.setValue('security_id', newSecurity.id);
      setShowAddSecurity(false);
    } catch {
      // ignore — user can retry
    }
  };

  return (
    <div className="space-y-6">
      <Form {...form}>
        <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-4 px-5">
          <FormField name="account_id" render={({ field }) => (
            <FormItem>
              <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">{t('holding.account')} <span className="text-red-500">*</span></FormLabel>
              <Select value={field.value} onValueChange={field.onChange}>
                <FormControl><SelectTrigger className="h-9"><SelectValue placeholder={t('holding.selectAccount')}>{field.value ? accountNameMap[field.value] || field.value : null}</SelectValue></SelectTrigger></FormControl>
                <SelectContent>
                  {investmentAccounts.map(a => (<SelectItem key={a.id} value={a.id}>{a.name}</SelectItem>))}
                </SelectContent>
              </Select>
              <FormMessage />
            </FormItem>
          )} />

          <div>
            <FormField name="security_id" render={({ field }) => (
              <FormItem>
                <div className="flex items-center justify-between">
                  <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">{t('holding.security')} <span className="text-red-500">*</span></FormLabel>
                  <button
                    type="button"
                    onClick={() => setShowAddSecurity(!showAddSecurity)}
                    className="text-xs text-primary hover:text-primary/80 flex items-center gap-1"
                  >
                    <Plus className="h-3 w-3" />
                    {t('holding.addSecurity')}
                  </button>
                </div>
                <Select value={field.value} onValueChange={field.onChange}>
                  <FormControl><SelectTrigger className="h-9"><SelectValue placeholder={t('holding.selectSecurity')}>{field.value ? securityNameMap[field.value] || field.value : null}</SelectValue></SelectTrigger></FormControl>
                  <SelectContent>
                    {securities.map(s => (<SelectItem key={s.id} value={s.id}>{s.symbol} {s.name}</SelectItem>))}
                  </SelectContent>
                </Select>
                <FormMessage />
              </FormItem>
            )} />

            {showAddSecurity && (
              <form onSubmit={handleCreateSecurity} className="mt-2 rounded-lg border bg-muted/30 p-3 space-y-2">
                <div className="text-xs font-medium text-muted-foreground">{t('holding.newSecurity')}</div>
                <div className="grid grid-cols-3 gap-2">
                  <Input name="new_symbol" placeholder={t('holding.symbol')} className="h-8 text-xs" required />
                  <Input name="new_name" placeholder={t('holding.name')} className="h-8 text-xs" required />
                  <select name="new_type" className="h-8 rounded-md border bg-background px-2 text-xs" required defaultValue="stock">
                    {SECURITY_TYPES.map(st => <option key={st.value} value={st.value}>{st.label}</option>)}
                  </select>
                </div>
                <div className="flex justify-end gap-2">
                  <Button type="button" variant="ghost" size="sm" onClick={() => setShowAddSecurity(false)}>{t('common.cancel')}</Button>
                  <Button type="submit" size="sm">{t('holding.addSecurity')}</Button>
                </div>
              </form>
            )}
          </div>

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
