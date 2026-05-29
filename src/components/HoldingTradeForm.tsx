import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { useTranslation } from 'react-i18next';
import { z } from 'zod';
import { Plus, Search, Loader2 } from 'lucide-react';
import { Button } from './ui/button';
import {
  Form, FormControl, FormField, FormItem, FormLabel, FormMessage,
} from './ui/form';
import { Input } from './ui/input';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from './ui/select';
import { listAccounts } from '@/lib/tauri/account';
import {
  listSecurities, createSecurity, searchSecurities,
  type HoldingTradeDto, type HoldingDto, type SecurityType, type SecuritySearchResult,
} from '@/lib/tauri/holding';
import { useState } from 'react';

interface Props {
  onSubmit: (data: HoldingTradeDto) => void;
  onCancel: () => void;
  isLoading?: boolean;
  initialDirection?: 'BUY' | 'SELL';
  initialHolding?: HoldingDto | null;
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

export function HoldingTradeForm({ onSubmit, onCancel, isLoading, initialDirection, initialHolding }: Props) {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const [showAddSecurity, setShowAddSecurity] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<SecuritySearchResult[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [newSymbol, setNewSymbol] = useState('');
  const [newName, setNewName] = useState('');
  const [newType, setNewType] = useState<SecurityType>('stock');
  const [newExchange, setNewExchange] = useState('');

  const { data: accounts = [] } = useQuery({ queryKey: ['accounts'], queryFn: listAccounts });
  const { data: securities = [] } = useQuery({ queryKey: ['securities'], queryFn: listSecurities });

  const investmentAccounts = accounts.filter(a => a.account_type === 'Investment');
  const today = new Date().toISOString().split('T')[0];

  const accountNameMap = Object.fromEntries(investmentAccounts.map(a => [a.id, a.name]));
  const securityNameMap = Object.fromEntries(securities.map(s => [s.id, `${s.symbol} ${s.name}`]));

  const form = useForm<FormValues>({
    resolver: zodResolver(tradeSchema),
    defaultValues: {
      account_id: initialHolding?.account_id || '',
      security_id: initialHolding?.security_id || '',
      direction: initialDirection || 'BUY',
      quantity: '',
      price: '',
      fee: '0',
      trade_date: today,
      notes: '',
    },
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

  const handleSearch = async () => {
    if (!searchQuery.trim()) return;
    setIsSearching(true);
    try {
      const results = await searchSecurities(searchQuery.trim());
      setSearchResults(results);
    } catch {
      setSearchResults([]);
    } finally {
      setIsSearching(false);
    }
  };

  const handleSelectSearchResult = (result: SecuritySearchResult) => {
    setNewSymbol(result.symbol);
    setNewName(result.name);
    setNewType(result.security_type);
    setNewExchange(result.exchange_display);
    setSearchResults([]);
  };

  const handleCreateSecurity = async () => {
    if (!newSymbol.trim() || !newName.trim()) return;
    try {
      const newSecurity = await createSecurity({
        symbol: newSymbol.trim(),
        name: newName.trim(),
        security_type: newType,
        exchange: newExchange || null,
        currency_code: 'CNY',
      });
      await queryClient.invalidateQueries({ queryKey: ['securities'] });
      form.setValue('security_id', newSecurity.id);
      setShowAddSecurity(false);
      setSearchQuery('');
      setSearchResults([]);
      setNewSymbol('');
      setNewName('');
      setNewType('stock');
      setNewExchange('');
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
                    onClick={() => { setShowAddSecurity(!showAddSecurity); setSearchResults([]); }}
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
              <div className="mt-2 rounded-lg border bg-muted/30 p-3 space-y-3">
                {/* Search bar */}
                <div className="flex gap-2">
                  <Input
                    placeholder={t('holding.searchPlaceholder')}
                    className="h-8 text-xs flex-1"
                    value={searchQuery}
                    onChange={e => setSearchQuery(e.target.value)}
                    onKeyDown={e => e.key === 'Enter' && (e.preventDefault(), handleSearch())}
                  />
                  <Button type="button" size="sm" variant="outline" className="h-8 px-2" onClick={handleSearch} disabled={isSearching}>
                    {isSearching ? <Loader2 className="h-3 w-3 animate-spin" /> : <Search className="h-3 w-3" />}
                  </Button>
                </div>

                {/* Search results */}
                {searchResults.length > 0 && (
                  <div className="max-h-40 overflow-y-auto rounded-md border bg-background divide-y">
                    {searchResults.map(r => (
                      <button
                        key={`${r.symbol}-${r.exchange}`}
                        type="button"
                        onClick={() => handleSelectSearchResult(r)}
                        className="w-full text-left px-3 py-2 hover:bg-muted/50 text-xs"
                      >
                        <div className="flex items-center justify-between">
                          <span className="font-medium">{r.symbol}</span>
                          <span className="text-muted-foreground">{r.exchange_display}</span>
                        </div>
                        <div className="text-muted-foreground truncate">{r.name}</div>
                      </button>
                    ))}
                  </div>
                )}

                {/* Editable fields (auto-filled from search or manual) */}
                <div className="space-y-2">
                  <div className="grid grid-cols-2 gap-2">
                    <div>
                      <label className="text-[10px] text-muted-foreground">{t('holding.symbol')}</label>
                      <Input
                        className="h-8 text-xs"
                        value={newSymbol}
                        onChange={e => setNewSymbol(e.target.value)}
                        placeholder="AAPL"
                      />
                    </div>
                    <div>
                      <label className="text-[10px] text-muted-foreground">{t('holding.exchange')}</label>
                      <Input
                        className="h-8 text-xs"
                        value={newExchange}
                        onChange={e => setNewExchange(e.target.value)}
                        placeholder="NASDAQ"
                      />
                    </div>
                  </div>
                  <div>
                    <label className="text-[10px] text-muted-foreground">{t('holding.name')}</label>
                    <Input
                      className="h-8 text-xs"
                      value={newName}
                      onChange={e => setNewName(e.target.value)}
                      placeholder={t('holding.name')}
                    />
                  </div>
                  <div>
                    <label className="text-[10px] text-muted-foreground">{t('holding.type')}</label>
                    <select
                      className="h-8 w-full rounded-md border bg-background px-2 text-xs"
                      value={newType}
                      onChange={e => setNewType(e.target.value as SecurityType)}
                    >
                      {SECURITY_TYPES.map(st => <option key={st.value} value={st.value}>{st.label}</option>)}
                    </select>
                  </div>
                </div>

                <div className="flex justify-end gap-2">
                  <Button type="button" variant="ghost" size="sm" onClick={() => setShowAddSecurity(false)}>{t('common.cancel')}</Button>
                  <Button type="button" size="sm" onClick={handleCreateSecurity} disabled={!newSymbol.trim() || !newName.trim()}>
                    {t('holding.confirmCreate')}
                  </Button>
                </div>
              </div>
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
            <div className="text-xs text-muted-foreground">{t('holding.estimatedAmountDisplay', { value: estimatedAmount.toLocaleString('en-US', { minimumFractionDigits: 2 }) })}</div>
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
