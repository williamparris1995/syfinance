import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import React, { useState, useMemo } from 'react';
import { toast } from 'sonner';
import { ArrowUpDown, RefreshCw, TrendingDown, ChevronRight, ChevronDown, Pencil, Trash2, DollarSign, Split } from 'lucide-react';
import { Pie, PieChart, Cell, ResponsiveContainer, Tooltip } from 'recharts';
import { Button } from '../components/ui/button';
import {
  Sheet, SheetContent, SheetHeader, SheetTitle,
} from '../components/ui/sheet';
import { Badge } from '../components/ui/badge';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '../components/ui/select';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '../components/ui/table';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { HoldingTradeForm } from '../components/HoldingTradeForm';
import { getUserFriendlyError } from '../lib/error-handler';
import { formatCurrency, getCurrencySymbol } from '../lib/currency';
import {
  buyHolding, sellHolding, listHoldings, updateSecurityPrice,
  listSecurities, fetchSecurityPrice,
  deleteHoldingTrade, updateHoldingTrade,
  recordDividend, recordSplit,
  listHoldingTransactionsPaginated,
  type HoldingDto, type HoldingTradeDto, type HoldingTransactionDto, type UpdateHoldingTradeRequest,
  type DividendDto, type SplitDto,
} from '../lib/tauri/holding';
import { useCursorPagination } from '../hooks/useCursorPagination';

const typeColors: Record<string, string> = {
  stock: 'bg-blue-100 text-blue-800',
  fund: 'bg-green-100 text-green-800',
  etf: 'bg-emerald-100 text-emerald-800',
  bond: 'bg-amber-100 text-amber-800',
  gold: 'bg-yellow-100 text-yellow-800',
  option: 'bg-purple-100 text-purple-800',
};

const pieColors: Record<string, string> = {
  stock: '#3b82f6',
  fund: '#22c55e',
  etf: '#10b981',
  bond: '#f59e0b',
  gold: '#eab308',
  option: '#a855f7',
  other: '#6b7280',
};

type SortKey = 'symbol' | 'name' | 'quantity' | 'avgCost' | 'currentPrice' | 'marketValue' | 'pnl' | 'pnlPct';
type SortDir = 'asc' | 'desc';
type FilterType = 'all' | string;
type DateRangePreset = 'all' | 'month' | 'quarter' | 'year' | 'custom';

interface EnrichedHolding extends HoldingDto {
  _avgCost: number;
  _quantity: number;
  _currentPrice: number | null;
  _marketValue: number | null;
  _pnl: number;
  _pnlPct: number;
}

export function HoldingsPage() {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const [showTradeSheet, setShowTradeSheet] = useState(false);
  const [tradeDirection, setTradeDirection] = useState<'BUY' | 'SELL'>('BUY');
  const [selectedHolding, setSelectedHolding] = useState<HoldingDto | null>(null);
  const [sortKey, setSortKey] = useState<SortKey>('marketValue');
  const [sortDir, setSortDir] = useState<SortDir>('desc');
  const [filterType, setFilterType] = useState<FilterType>('all');
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [refreshProgress, setRefreshProgress] = useState('');
  const [dateRangePreset, setDateRangePreset] = useState<DateRangePreset>('all');
  const [customStartDate, setCustomStartDate] = useState('');
  const [customEndDate, setCustomEndDate] = useState(new Date().toISOString().split('T')[0]);

  // Expanded holding for trade history
  const [expandedHoldingId, setExpandedHoldingId] = useState<string | null>(null);
  const [editingTradeId, setEditingTradeId] = useState<string | null>(null);
  const [editForm, setEditForm] = useState({ quantity: '', price: '', fee: '', trade_date: '', notes: '' });
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);

  // Dividend / Split sheets
  const [showDividendSheet, setShowDividendSheet] = useState(false);
  const [dividendTarget, setDividendTarget] = useState<HoldingDto | null>(null);
  const [dividendForm, setDividendForm] = useState({ cashPerShare: '', quantity: '', totalAmount: '', fee: '', tradeDate: new Date().toISOString().split('T')[0], notes: '' });

  const [showSplitSheet, setShowSplitSheet] = useState(false);
  const [splitTarget, setSplitTarget] = useState<HoldingDto | null>(null);
  const [splitForm, setSplitForm] = useState({ ratio: '', tradeDate: new Date().toISOString().split('T')[0], notes: '' });

  const { data: holdings = [], isLoading } = useQuery({ queryKey: ['holdings'], queryFn: listHoldings });

  // Fetch trade history for expanded holding (paginated)
  const {
    items: tradeHistory,
    isLoading: isLoadingTrades,
    hasNextPage: hasMoreTrades,
    goNext: loadMoreTrades,
  } = useCursorPagination(
    ['holding-trades-paginated', expandedHoldingId],
    async (cursor) => {
      return listHoldingTransactionsPaginated(expandedHoldingId!, 20, cursor ?? undefined);
    },
    { enabled: !!expandedHoldingId },
  );

  const tradeMutation = useMutation({
    mutationFn: (dto: HoldingTradeDto) => dto.direction === 'BUY' ? buyHolding(dto) : sellHolding(dto),
    onSuccess: (_data, vars) => {
      queryClient.invalidateQueries({ queryKey: ['holdings'] });
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      setShowTradeSheet(false);
      setSelectedHolding(null);
      toast.success(vars.direction === 'BUY' ? t('holding.buySuccess') : t('holding.sellSuccess'));
    },
    onError: (error) => toast.error(getUserFriendlyError(error)),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => deleteHoldingTrade(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['holdings'] });
      queryClient.invalidateQueries({ queryKey: ['holding-trades', expandedHoldingId] });
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      setDeleteConfirmId(null);
      toast.success(t('holding.tradeDeleted'));
    },
    onError: (error) => toast.error(getUserFriendlyError(error)),
  });

  const updateMutation = useMutation({
    mutationFn: (req: UpdateHoldingTradeRequest) => updateHoldingTrade(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['holdings'] });
      queryClient.invalidateQueries({ queryKey: ['holding-trades', expandedHoldingId] });
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      setEditingTradeId(null);
      toast.success(t('holding.tradeUpdated'));
    },
    onError: (error) => toast.error(getUserFriendlyError(error)),
  });

  const dividendMutation = useMutation({
    mutationFn: (dto: DividendDto) => recordDividend(dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['holdings'] });
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      setShowDividendSheet(false);
      setDividendTarget(null);
      setDividendForm({ cashPerShare: '', quantity: '', totalAmount: '', fee: '', tradeDate: new Date().toISOString().split('T')[0], notes: '' });
      toast.success(t('holding.dividendSuccess'));
    },
    onError: (error) => toast.error(getUserFriendlyError(error)),
  });

  const splitMutation = useMutation({
    mutationFn: (dto: SplitDto) => recordSplit(dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['holdings'] });
      setShowSplitSheet(false);
      setSplitTarget(null);
      setSplitForm({ ratio: '', tradeDate: new Date().toISOString().split('T')[0], notes: '' });
      toast.success(t('holding.splitSuccess'));
    },
    onError: (error) => toast.error(getUserFriendlyError(error)),
  });

  const handleRefreshPrices = async () => {
    setIsRefreshing(true);
    setRefreshProgress('');
    try {
      const securities = await listSecurities();
      let updated = 0;
      for (const sec of securities) {
        try {
          setRefreshProgress(`${sec.symbol}...`);
          const result = await fetchSecurityPrice(sec.symbol, sec.exchange);
          if (result && result.price > 0) {
            await updateSecurityPrice(sec.id, result.price);
            updated++;
          }
        } catch {
          // skip individual failures
        }
      }
      await queryClient.invalidateQueries({ queryKey: ['holdings'] });
      toast.success(t('holding.pricesUpdated') + ` (${updated}/${securities.length})`);
    } catch {
      toast.error(t('holding.pricesUpdateFailed'));
    } finally {
      setIsRefreshing(false);
      setRefreshProgress('');
    }
  };

  const handleSell = (h: HoldingDto) => {
    setSelectedHolding(h);
    setTradeDirection('SELL');
    setShowTradeSheet(true);
  };

  const handleNewTrade = () => {
    setSelectedHolding(null);
    setTradeDirection('BUY');
    setShowTradeSheet(true);
  };

  const handleDividend = (h: HoldingDto) => {
    setDividendTarget(h);
    setDividendForm({
      cashPerShare: '',
      quantity: String(h.quantity),
      totalAmount: '',
      fee: '',
      tradeDate: new Date().toISOString().split('T')[0],
      notes: '',
    });
    setShowDividendSheet(true);
  };

  const handleSplit = (h: HoldingDto) => {
    setSplitTarget(h);
    setSplitForm({ ratio: '', tradeDate: new Date().toISOString().split('T')[0], notes: '' });
    setShowSplitSheet(true);
  };

  const toggleSort = (key: SortKey) => {
    if (sortKey === key) {
      setSortDir(d => d === 'asc' ? 'desc' : 'asc');
    } else {
      setSortKey(key);
      setSortDir('desc');
    }
  };

  const toggleExpand = (h: EnrichedHolding) => {
    if (expandedHoldingId === h.id) {
      setExpandedHoldingId(null);
      setEditingTradeId(null);
    } else {
      setExpandedHoldingId(h.id);
      setEditingTradeId(null);
      setDeleteConfirmId(null);
    }
  };

  const startEdit = (trade: HoldingTransactionDto) => {
    setEditingTradeId(trade.id);
    setEditForm({
      quantity: String(trade.quantity),
      price: String(trade.price),
      fee: String(trade.fee),
      trade_date: trade.trade_date,
      notes: trade.notes || '',
    });
    setDeleteConfirmId(null);
  };

  const cancelEdit = () => {
    setEditingTradeId(null);
    setEditForm({ quantity: '', price: '', fee: '', trade_date: '', notes: '' });
  };

  const saveEdit = (trade: HoldingTransactionDto) => {
    updateMutation.mutate({
      holding_transaction_id: trade.id,
      quantity: Number(editForm.quantity),
      price: Number(editForm.price),
      fee: Number(editForm.fee),
      trade_date: editForm.trade_date,
      notes: editForm.notes || null,
    });
  };

  const securityTypes = useMemo(() => {
    const types = new Set(holdings.map(h => h.security_type));
    return Array.from(types);
  }, [holdings]);

  const filteredHoldings = useMemo(() => {
    let list = filterType === 'all' ? holdings : holdings.filter(h => h.security_type === filterType);
    return list.map(h => {
      const avgCost = Number(h.avg_cost) || 0;
      const quantity = Number(h.quantity) || 0;
      const currentPrice = h.current_price != null ? Number(h.current_price) : null;
      const marketValue = currentPrice != null ? currentPrice * quantity : null;
      const pnl = marketValue != null ? marketValue - avgCost * quantity : 0;
      const pnlPct = currentPrice != null && avgCost > 0
        ? ((currentPrice - avgCost) / avgCost * 100) : 0;
      return {
        ...h,
        _avgCost: avgCost,
        _quantity: quantity,
        _currentPrice: currentPrice,
        _marketValue: marketValue,
        _pnl: pnl,
        _pnlPct: pnlPct,
      };
    });
  }, [holdings, filterType]);

  const sortedHoldings = useMemo(() => {
    const sorted = [...filteredHoldings].sort((a, b) => {
      let va: number | string, vb: number | string;
      switch (sortKey) {
        case 'symbol': return sortDir === 'asc' ? a.symbol.localeCompare(b.symbol) : b.symbol.localeCompare(a.symbol);
        case 'name': return sortDir === 'asc' ? a.security_name.localeCompare(b.security_name) : b.security_name.localeCompare(a.security_name);
        case 'quantity': va = a._quantity; vb = b._quantity; break;
        case 'avgCost': va = a._avgCost; vb = b._avgCost; break;
        case 'currentPrice': va = a._currentPrice || 0; vb = b._currentPrice || 0; break;
        case 'marketValue': va = a._marketValue || 0; vb = b._marketValue || 0; break;
        case 'pnl': va = a._pnl; vb = b._pnl; break;
        case 'pnlPct': va = a._pnlPct; vb = b._pnlPct; break;
        default: return 0;
      }
      return sortDir === 'asc' ? (va as number) - (vb as number) : (vb as number) - (va as number);
    });
    return sorted;
  }, [filteredHoldings, sortKey, sortDir]);

  const grouped = useMemo(() => {
    const groups: Record<string, typeof sortedHoldings> = {};
    for (const h of sortedHoldings) {
      (groups[h.security_type] ||= []).push(h);
    }
    return groups;
  }, [sortedHoldings]);

  const allocationData = useMemo(() => {
    const map: Record<string, number> = {};
    for (const h of filteredHoldings) {
      const val = h._marketValue || h._avgCost * h._quantity;
      map[h.security_type] = (map[h.security_type] || 0) + val;
    }
    return Object.entries(map)
      .map(([type, value]) => ({ type, value: Math.round(value * 100) / 100 }))
      .sort((a, b) => b.value - a.value);
  }, [filteredHoldings]);

  const totalMarketValue = filteredHoldings.reduce((s, h) => s + (h._marketValue || h._avgCost * h._quantity), 0);
  const totalCost = filteredHoldings.reduce((s, h) => s + h._avgCost * h._quantity, 0);
  const totalPnl = totalMarketValue - totalCost;

  const SortHeader = ({ label, sortKeyName, align }: { label: string; sortKeyName: SortKey; align?: 'left' | 'right' }) => (
    <TableHead className={`${align === 'left' ? '' : 'text-right'} cursor-pointer select-none`} onClick={() => toggleSort(sortKeyName)}>
      <span className="inline-flex items-center gap-1">
        {label}
        <ArrowUpDown className={`h-3 w-3 ${sortKey === sortKeyName ? 'text-primary' : 'text-muted-foreground/40'}`} />
      </span>
    </TableHead>
  );

  const renderHoldingRow = (h: EnrichedHolding) => {
    const isExpanded = expandedHoldingId === h.id;
    return (
      <HoldingRow
        key={h.id}
        h={h}
        isExpanded={isExpanded}
        onSell={handleSell}
        onDividend={handleDividend}
        onSplit={handleSplit}
        onToggle={toggleExpand}
        t={t}
      />
    );
  };

  const renderTradeHistory = () => {
    if (!expandedHoldingId) return null;
    if (isLoadingTrades) {
      return (
        <TableRow>
          <TableCell colSpan={9} className="text-center py-4 text-muted-foreground text-xs">
            {t('common.loading')}
          </TableCell>
        </TableRow>
      );
    }
    if (tradeHistory.length === 0) {
      return (
        <TableRow>
          <TableCell colSpan={9} className="text-center py-4 text-muted-foreground text-xs">
            {t('holding.noTradeHistory')}
          </TableCell>
        </TableRow>
      );
    }
    const rows = tradeHistory.map(trade => {
      const isEditing = editingTradeId === trade.id;
      const isDeleteConfirm = deleteConfirmId === trade.id;

      if (isEditing) {
        return (
          <TableRow key={trade.id} className="bg-muted/30">
            <TableCell />
            <TableCell colSpan={2}>
              <div className="flex items-center gap-1">
                <Badge variant={trade.trade_type === 'BUY' ? 'default' : 'secondary'} className="text-[10px]">
                  {trade.trade_type}
                </Badge>
              </div>
            </TableCell>
            <TableCell><Input type="number" step="any" value={editForm.quantity} onChange={e => setEditForm(f => ({ ...f, quantity: e.target.value }))} className="h-7 text-xs w-20" /></TableCell>
            <TableCell><Input type="number" step="any" value={editForm.price} onChange={e => setEditForm(f => ({ ...f, price: e.target.value }))} className="h-7 text-xs w-20" /></TableCell>
            <TableCell><Input type="number" step="any" value={editForm.fee} onChange={e => setEditForm(f => ({ ...f, fee: e.target.value }))} className="h-7 text-xs w-16" /></TableCell>
            <TableCell><Input type="date" value={editForm.trade_date} onChange={e => setEditForm(f => ({ ...f, trade_date: e.target.value }))} className="h-7 text-xs w-28" /></TableCell>
            <TableCell className="text-right">
              <div className="flex justify-end gap-1">
                <Button variant="ghost" size="sm" className="h-6 text-xs text-emerald-600" onClick={() => saveEdit(trade)} disabled={updateMutation.isPending}>
                  {t('common.save')}
                </Button>
                <Button variant="ghost" size="sm" className="h-6 text-xs" onClick={cancelEdit}>
                  {t('common.cancel')}
                </Button>
              </div>
            </TableCell>
          </TableRow>
        );
      }

      const totalAmount = Number(trade.quantity) * Number(trade.price) + Number(trade.fee);

      return (
        <TableRow key={trade.id} className="bg-muted/30">
          <TableCell />
          <TableCell colSpan={2}>
            <div className="flex items-center gap-1">
              <Badge variant={trade.trade_type === 'BUY' ? 'default' : 'secondary'} className="text-[10px]">
                {trade.trade_type}
              </Badge>
              <span className="text-xs text-muted-foreground">{trade.trade_date}</span>
            </div>
          </TableCell>
          <TableCell className="text-right text-xs">{Number(trade.quantity)}</TableCell>
          <TableCell className="text-right text-xs">{Number(trade.price).toFixed(2)}</TableCell>
          <TableCell className="text-right text-xs">{Number(trade.fee).toFixed(2)}</TableCell>
          <TableCell className="text-right text-xs font-medium">
            {totalAmount.toLocaleString('en-US', { minimumFractionDigits: 2 })}
          </TableCell>
          <TableCell className="text-right">
            {isDeleteConfirm ? (
              <div className="flex justify-end gap-1">
                <span className="text-xs text-red-600 mr-1">{t('common.confirmDelete')}</span>
                <Button variant="ghost" size="sm" className="h-6 text-xs text-red-600" onClick={() => deleteMutation.mutate(trade.id)} disabled={deleteMutation.isPending}>
                  {t('common.confirm')}
                </Button>
                <Button variant="ghost" size="sm" className="h-6 text-xs" onClick={() => setDeleteConfirmId(null)}>
                  {t('common.cancel')}
                </Button>
              </div>
            ) : (
              <div className="flex justify-end gap-1">
                <Button variant="ghost" size="sm" className="h-6 text-xs" onClick={() => startEdit(trade)}>
                  <Pencil className="h-3 w-3 mr-1" />
                  {t('common.edit')}
                </Button>
                <Button variant="ghost" size="sm" className="h-6 text-xs text-red-600 hover:text-red-700" onClick={() => setDeleteConfirmId(trade.id)}>
                  <Trash2 className="h-3 w-3 mr-1" />
                  {t('common.delete')}
                </Button>
              </div>
            )}
          </TableCell>
        </TableRow>
      );
    });

    return (
      <>
        {rows}
        {hasMoreTrades && (
          <TableRow>
            <TableCell colSpan={9} className="py-1">
              <Button
                variant="ghost"
                size="sm"
                className="w-full"
                onClick={loadMoreTrades}
              >
                {t('common.loadMore')}
              </Button>
            </TableCell>
          </TableRow>
        )}
      </>
    );
  };

  if (isLoading) return <div className="p-4 sm:p-6 text-center text-muted-foreground">{t('common.loading')}</div>;

  return (
    <div className="p-4 sm:p-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between mb-4 sm:mb-6">
        <h1 className="text-2xl font-bold sm:text-3xl">{t('holding.title')}</h1>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm" onClick={handleRefreshPrices} disabled={isRefreshing}>
            <RefreshCw className={`h-4 w-4 mr-1 ${isRefreshing ? 'animate-spin' : ''}`} />
            {isRefreshing ? refreshProgress || t('holding.refreshPrices') : t('holding.refreshPrices')}
          </Button>
          <Button variant="default-gradient" onClick={handleNewTrade}>
            {t('holding.newTrade')}
          </Button>
        </div>
      </div>

      {holdings.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <p className="text-neutral-500 mb-4">{t('holding.noHoldings')}</p>
          <Button onClick={handleNewTrade}>{t('holding.firstTrade')}</Button>
        </div>
      ) : (
        <>
          {/* Portfolio summary */}
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_auto] gap-6 mb-6">
            <div className="grid grid-cols-3 gap-4">
              <div className="rounded-lg border p-4">
                <div className="text-xs text-muted-foreground">{t('holding.totalMarketValue')}</div>
                <div className="text-xl font-bold">{formatCurrency(totalMarketValue, 'CNY')}</div>
              </div>
              <div className="rounded-lg border p-4">
                <div className="text-xs text-muted-foreground">{t('holding.totalCost')}</div>
                <div className="text-xl font-bold">{formatCurrency(totalCost, 'CNY')}</div>
              </div>
              <div className={`rounded-lg border p-4 ${totalPnl >= 0 ? 'border-emerald-200 bg-emerald-50/50' : 'border-red-200 bg-red-50/50'}`}>
                <div className="text-xs text-muted-foreground">{t('holding.totalPnl')}</div>
                <div className={`text-xl font-bold ${totalPnl >= 0 ? 'text-emerald-600' : 'text-red-600'}`}>
                  {totalPnl >= 0 ? '+' : ''}{formatCurrency(totalPnl, 'CNY')}
                </div>
              </div>
            </div>
            {/* Allocation pie chart */}
            {allocationData.length > 0 && (
              <div className="rounded-lg border p-4 min-w-[220px]">
                <div className="text-xs text-muted-foreground mb-2">{t('holding.allocationChart')}</div>
                <div className="flex items-center gap-3">
                  <ResponsiveContainer width={100} height={100}>
                    <PieChart>
                      <Pie data={allocationData} dataKey="value" nameKey="type" cx="50%" cy="50%" innerRadius={24} outerRadius={44} paddingAngle={2}>
                        {allocationData.map((entry) => (
                          <Cell key={entry.type} fill={pieColors[entry.type] || '#6b7280'} />
                        ))}
                      </Pie>
                      <Tooltip formatter={(value) => `${getCurrencySymbol('CNY')}${Number(value).toLocaleString('en-US', { minimumFractionDigits: 2 })}`} labelFormatter={(label) => t(`holding.types.${label}`)} />
                    </PieChart>
                  </ResponsiveContainer>
                  <div className="space-y-1">
                    {allocationData.map((d) => (
                      <div key={d.type} className="flex items-center gap-1.5 text-xs">
                        <span className="inline-block w-2.5 h-2.5 rounded-full" style={{ backgroundColor: pieColors[d.type] || '#6b7280' }} />
                        <span className="text-muted-foreground">{t(`holding.types.${d.type}`)}</span>
                        <span className="font-medium ml-auto">{totalMarketValue > 0 ? (d.value / totalMarketValue * 100).toFixed(1) : 0}%</span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Filter bar */}
          <div className="flex flex-wrap items-center gap-3 mb-4">
            <Select value={filterType} onValueChange={v => setFilterType(v as FilterType)}>
              <SelectTrigger className="w-40 h-8 text-xs">
                <SelectValue placeholder={t('holding.allTypes')} />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">{t('holding.allTypes')}</SelectItem>
                {securityTypes.map(type => (
                  <SelectItem key={type} value={type}>{t(`holding.types.${type}`)}</SelectItem>
                ))}
              </SelectContent>
            </Select>

            <div className="flex items-center gap-1">
              <Button variant={dateRangePreset === 'all' ? 'default' : 'outline'} size="sm" className="h-7 text-xs" onClick={() => setDateRangePreset('all')}>
                {t('common.all')}
              </Button>
              <Button variant={dateRangePreset === 'month' ? 'default' : 'outline'} size="sm" className="h-7 text-xs" onClick={() => setDateRangePreset('month')}>
                {t('reports.thisMonth')}
              </Button>
              <Button variant={dateRangePreset === 'quarter' ? 'default' : 'outline'} size="sm" className="h-7 text-xs" onClick={() => setDateRangePreset('quarter')}>
                {t('reports.thisQuarter')}
              </Button>
              <Button variant={dateRangePreset === 'year' ? 'default' : 'outline'} size="sm" className="h-7 text-xs" onClick={() => setDateRangePreset('year')}>
                {t('reports.thisYear')}
              </Button>
              <Button variant={dateRangePreset === 'custom' ? 'default' : 'outline'} size="sm" className="h-7 text-xs" onClick={() => setDateRangePreset('custom')}>
                {t('reports.custom')}
              </Button>
              {dateRangePreset === 'custom' && (
                <div className="flex items-center gap-1 ml-1">
                  <Input type="date" value={customStartDate} onChange={e => setCustomStartDate(e.target.value)} className="w-32 h-7 text-xs" />
                  <span className="text-xs text-muted-foreground">—</span>
                  <Input type="date" value={customEndDate} onChange={e => setCustomEndDate(e.target.value)} className="w-32 h-7 text-xs" />
                </div>
              )}
            </div>

            <span className="text-xs text-muted-foreground">{sortedHoldings.length} {t('holding.positions')}</span>
          </div>

          {/* Holdings table */}
          {filterType === 'all' ? (
            Object.entries(grouped).map(([type, items]) => (
              <div key={type} className="mb-8">
                <h2 className="text-lg font-semibold mb-3">
                  <Badge className={`mr-2 ${typeColors[type] || ''}`}>{t(`holding.types.${type}`)}</Badge>
                  {items.length} {t('holding.positions')}
                </h2>
                <div className="border rounded-lg">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead className="w-8" />
                        <SortHeader label={t('holding.symbol')} sortKeyName="symbol" align="left" />
                        <SortHeader label={t('holding.name')} sortKeyName="name" align="left" />
                        <SortHeader label={t('holding.quantity')} sortKeyName="quantity" />
                        <SortHeader label={t('holding.avgCost')} sortKeyName="avgCost" />
                        <SortHeader label={t('holding.currentPrice')} sortKeyName="currentPrice" />
                        <SortHeader label={t('holding.marketValue')} sortKeyName="marketValue" />
                        <SortHeader label={t('holding.pnl')} sortKeyName="pnl" />
                        <SortHeader label={t('holding.pnlPct')} sortKeyName="pnlPct" />
                        <TableHead className="text-right">{t('holding.actions')}</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {items.map(h => (
                        <React.Fragment key={h.id}>
                          {renderHoldingRow(h)}
                          {expandedHoldingId === h.id && renderTradeHistory()}
                        </React.Fragment>
                      ))}
                    </TableBody>
                  </Table>
                </div>
              </div>
            ))
          ) : (
            <div className="border rounded-lg">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="w-8" />
                    <SortHeader label={t('holding.symbol')} sortKeyName="symbol" align="left" />
                    <SortHeader label={t('holding.name')} sortKeyName="name" align="left" />
                    <SortHeader label={t('holding.quantity')} sortKeyName="quantity" />
                    <SortHeader label={t('holding.avgCost')} sortKeyName="avgCost" />
                    <SortHeader label={t('holding.currentPrice')} sortKeyName="currentPrice" />
                    <SortHeader label={t('holding.marketValue')} sortKeyName="marketValue" />
                    <SortHeader label={t('holding.pnl')} sortKeyName="pnl" />
                    <SortHeader label={t('holding.pnlPct')} sortKeyName="pnlPct" />
                    <TableHead className="text-right">{t('holding.actions')}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {sortedHoldings.map(h => (
                    <React.Fragment key={h.id}>
                      {renderHoldingRow(h)}
                      {expandedHoldingId === h.id && renderTradeHistory()}
                    </React.Fragment>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </>
      )}

      <Sheet open={showTradeSheet} onOpenChange={setShowTradeSheet}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{tradeDirection === 'BUY' ? t('holding.newTrade') : t('holding.sellTitle')}</SheetTitle>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto -mx-4 px-4">
            <HoldingTradeForm
              initialDirection={tradeDirection}
              initialHolding={selectedHolding}
              onSubmit={(dto) => tradeMutation.mutate(dto)}
              onCancel={() => { setShowTradeSheet(false); setSelectedHolding(null); }}
              isLoading={tradeMutation.isPending}
            />
          </div>
        </SheetContent>
      </Sheet>

      {/* Dividend Sheet */}
      <Sheet open={showDividendSheet} onOpenChange={setShowDividendSheet}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{t('holding.recordDividend')} — {dividendTarget?.symbol}</SheetTitle>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto px-4 py-4 space-y-4">
            <div>
              <Label>{t('holding.cashPerShare')}</Label>
              <Input type="number" step="any" placeholder="0.00" value={dividendForm.cashPerShare} onChange={(e) => {
                const cps = e.target.value;
                const qty = Number(dividendForm.quantity) || 0;
                setDividendForm(f => ({ ...f, cashPerShare: cps, totalAmount: cps && qty ? String(Number(cps) * qty) : '' }));
              }} />
            </div>
            <div>
              <Label>{t('holding.quantity')}</Label>
              <Input type="number" step="any" value={dividendForm.quantity} onChange={(e) => {
                const qty = e.target.value;
                const cps = Number(dividendForm.cashPerShare) || 0;
                setDividendForm(f => ({ ...f, quantity: qty, totalAmount: qty && cps ? String(Number(qty) * cps) : '' }));
              }} />
            </div>
            <div>
              <Label>{t('holding.totalAmount')}</Label>
              <Input type="number" step="any" placeholder="0.00" value={dividendForm.totalAmount} onChange={(e) => setDividendForm(f => ({ ...f, totalAmount: e.target.value }))} />
            </div>
            <div>
              <Label>{t('holding.fee')}</Label>
              <Input type="number" step="any" placeholder="0.00" value={dividendForm.fee} onChange={(e) => setDividendForm(f => ({ ...f, fee: e.target.value }))} />
            </div>
            <div>
              <Label>{t('common.date')}</Label>
              <Input type="date" value={dividendForm.tradeDate} onChange={(e) => setDividendForm(f => ({ ...f, tradeDate: e.target.value }))} />
            </div>
            <div>
              <Label>{t('holding.notes')}</Label>
              <Input value={dividendForm.notes} onChange={(e) => setDividendForm(f => ({ ...f, notes: e.target.value }))} />
            </div>
            <div className="flex gap-2 pt-2">
              <Button onClick={() => {
                if (!dividendTarget) return;
                dividendMutation.mutate({
                  account_id: dividendTarget.account_id,
                  security_id: dividendTarget.security_id,
                  cash_per_share: dividendForm.cashPerShare,
                  quantity: dividendForm.quantity,
                  total_amount: dividendForm.totalAmount,
                  fee: dividendForm.fee || null,
                  trade_date: dividendForm.tradeDate,
                  notes: dividendForm.notes || null,
                });
              }} disabled={dividendMutation.isPending || !dividendForm.cashPerShare || !dividendForm.totalAmount} className="flex-1">
                {dividendMutation.isPending ? t('holding.submitting') : t('holding.recordDividend')}
              </Button>
              <Button variant="outline" onClick={() => { setShowDividendSheet(false); setDividendTarget(null); }}>{t('common.cancel')}</Button>
            </div>
          </div>
        </SheetContent>
      </Sheet>

      {/* Split Sheet */}
      <Sheet open={showSplitSheet} onOpenChange={setShowSplitSheet}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{t('holding.recordSplit')} — {splitTarget?.symbol}</SheetTitle>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto px-4 py-4 space-y-4">
            <div>
              <Label>{t('holding.ratio')}</Label>
              <Input type="number" step="any" placeholder={t('holding.ratioHint')} value={splitForm.ratio} onChange={(e) => setSplitForm(f => ({ ...f, ratio: e.target.value }))} />
              <p className="text-xs text-muted-foreground mt-1">{t('holding.ratioHint')}</p>
            </div>
            <div>
              <Label>{t('common.date')}</Label>
              <Input type="date" value={splitForm.tradeDate} onChange={(e) => setSplitForm(f => ({ ...f, tradeDate: e.target.value }))} />
            </div>
            <div>
              <Label>{t('holding.notes')}</Label>
              <Input value={splitForm.notes} onChange={(e) => setSplitForm(f => ({ ...f, notes: e.target.value }))} />
            </div>
            <div className="flex gap-2 pt-2">
              <Button onClick={() => {
                if (!splitTarget) return;
                splitMutation.mutate({
                  holding_id: splitTarget.id,
                  ratio: splitForm.ratio,
                  trade_date: splitForm.tradeDate,
                  notes: splitForm.notes || null,
                });
              }} disabled={splitMutation.isPending || !splitForm.ratio} className="flex-1">
                {splitMutation.isPending ? t('holding.submitting') : t('holding.recordSplit')}
              </Button>
              <Button variant="outline" onClick={() => { setShowSplitSheet(false); setSplitTarget(null); }}>{t('common.cancel')}</Button>
            </div>
          </div>
        </SheetContent>
      </Sheet>
    </div>
  );
}

function HoldingRow({ h, isExpanded, onSell, onDividend, onSplit, onToggle, t }: {
  h: EnrichedHolding;
  isExpanded: boolean;
  onSell: (h: HoldingDto) => void;
  onDividend: (h: HoldingDto) => void;
  onSplit: (h: HoldingDto) => void;
  onToggle: (h: EnrichedHolding) => void;
  t: (key: string) => string;
}) {
  return (
    <TableRow className={isExpanded ? 'bg-muted/20' : ''}>
      <TableCell className="w-8">
        <Button variant="ghost" size="sm" className="h-6 w-6 p-0" onClick={() => onToggle(h)}>
          {isExpanded ? <ChevronDown className="h-4 w-4" /> : <ChevronRight className="h-4 w-4" />}
        </Button>
      </TableCell>
      <TableCell className="font-medium">{h.symbol}</TableCell>
      <TableCell>{h.security_name}</TableCell>
      <TableCell className="text-right">{h._quantity}</TableCell>
      <TableCell className="text-right">{h._avgCost.toFixed(2)}</TableCell>
      <TableCell className="text-right">{h._currentPrice?.toFixed(2) || '-'}</TableCell>
      <TableCell className="text-right">{h._marketValue?.toLocaleString('en-US', { minimumFractionDigits: 2 }) || '-'}</TableCell>
      <TableCell className={`text-right ${h._pnl >= 0 ? 'text-emerald-600' : 'text-red-600'}`}>
        {h._pnl !== 0 ? (h._pnl >= 0 ? '+' : '') + getCurrencySymbol('CNY') + Math.abs(h._pnl).toLocaleString('en-US', { minimumFractionDigits: 2 }) : '-'}
      </TableCell>
      <TableCell className={`text-right ${h._pnlPct >= 0 ? 'text-emerald-600' : 'text-red-600'}`}>
        {h._pnlPct !== 0 ? (h._pnlPct >= 0 ? '+' : '') + h._pnlPct.toFixed(2) + '%' : '-'}
      </TableCell>
      <TableCell className="text-right">
        <div className="flex justify-end gap-1">
          <Button variant="ghost" size="sm" className="text-emerald-600 hover:text-emerald-700 hover:bg-emerald-50 h-7 text-xs" onClick={() => onDividend(h)}>
            <DollarSign className="h-3 w-3 mr-1" />
            {t('holding.dividend')}
          </Button>
          <Button variant="ghost" size="sm" className="text-blue-600 hover:text-blue-700 hover:bg-blue-50 h-7 text-xs" onClick={() => onSplit(h)}>
            <Split className="h-3 w-3 mr-1" />
            {t('holding.split')}
          </Button>
          <Button variant="ghost" size="sm" className="text-red-600 hover:text-red-700 hover:bg-red-50 h-7 text-xs" onClick={() => onSell(h)}>
            <TrendingDown className="h-3 w-3 mr-1" />
            {t('holding.sell')}
          </Button>
        </div>
      </TableCell>
    </TableRow>
  );
}
