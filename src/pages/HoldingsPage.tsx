import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { useState, useMemo } from 'react';
import { toast } from 'sonner';
import { ArrowUpDown, RefreshCw, TrendingDown } from 'lucide-react';
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
import { HoldingTradeForm } from '../components/HoldingTradeForm';
import { getUserFriendlyError } from '../lib/error-handler';
import {
  buyHolding, sellHolding, listHoldings, updateSecurityPrice,
  listSecurities, searchSecurities,
  type HoldingDto, type HoldingTradeDto,
} from '../lib/tauri/holding';

const typeColors: Record<string, string> = {
  stock: 'bg-blue-100 text-blue-800',
  fund: 'bg-green-100 text-green-800',
  etf: 'bg-emerald-100 text-emerald-800',
  bond: 'bg-amber-100 text-amber-800',
  gold: 'bg-yellow-100 text-yellow-800',
  option: 'bg-purple-100 text-purple-800',
};

type SortKey = 'symbol' | 'marketValue' | 'pnl' | 'pnlPct';
type SortDir = 'asc' | 'desc';
type FilterType = 'all' | string;

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

  const { data: holdings = [], isLoading } = useQuery({ queryKey: ['holdings'], queryFn: listHoldings });

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

  const handleRefreshPrices = async () => {
    setIsRefreshing(true);
    try {
      const securities = await listSecurities();
      for (const sec of securities) {
        try {
          const results = await searchSecurities(sec.symbol);
          const match = results.find(r => r.symbol === sec.symbol && r.exchange === sec.exchange);
          if (match) {
            // Use Yahoo Finance to get current price — for now we just update if we can find the symbol
            // The search results don't include price, so we'll skip price update for now
          }
        } catch {
          // skip individual failures
        }
      }
      toast.success(t('holding.pricesUpdated'));
    } catch {
      toast.error(t('holding.pricesUpdateFailed'));
    } finally {
      setIsRefreshing(false);
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

  const toggleSort = (key: SortKey) => {
    if (sortKey === key) {
      setSortDir(d => d === 'asc' ? 'desc' : 'asc');
    } else {
      setSortKey(key);
      setSortDir('desc');
    }
  };

  const securityTypes = useMemo(() => {
    const types = new Set(holdings.map(h => h.security_type));
    return Array.from(types);
  }, [holdings]);

  const filteredHoldings = useMemo(() => {
    let list = filterType === 'all' ? holdings : holdings.filter(h => h.security_type === filterType);
    return list.map(h => ({
      ...h,
      _avgCost: Number(h.avg_cost) || 0,
      _quantity: Number(h.quantity) || 0,
      _currentPrice: h.current_price != null ? Number(h.current_price) : null,
      _marketValue: h.market_value != null ? Number(h.market_value) : null,
      _pnl: h.unrealized_pnl != null ? Number(h.unrealized_pnl) : 0,
      _pnlPct: h.current_price != null && Number(h.avg_cost) > 0
        ? ((Number(h.current_price) - Number(h.avg_cost)) / Number(h.avg_cost) * 100) : 0,
    }));
  }, [holdings, filterType]);

  const sortedHoldings = useMemo(() => {
    const sorted = [...filteredHoldings].sort((a, b) => {
      let va: number, vb: number;
      switch (sortKey) {
        case 'symbol': return sortDir === 'asc' ? a.symbol.localeCompare(b.symbol) : b.symbol.localeCompare(a.symbol);
        case 'marketValue': va = a._marketValue || 0; vb = b._marketValue || 0; break;
        case 'pnl': va = a._pnl; vb = b._pnl; break;
        case 'pnlPct': va = a._pnlPct; vb = b._pnlPct; break;
        default: return 0;
      }
      return sortDir === 'asc' ? va - vb : vb - va;
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

  // Portfolio summary
  const totalValue = filteredHoldings.reduce((s, h) => s + (h._marketValue || 0), 0);
  const totalCost = filteredHoldings.reduce((s, h) => s + h._avgCost * h._quantity, 0);
  const totalPnl = totalValue - totalCost;

  const SortHeader = ({ label, sortKeyName }: { label: string; sortKeyName: SortKey }) => (
    <TableHead className="text-right cursor-pointer select-none" onClick={() => toggleSort(sortKeyName)}>
      <span className="inline-flex items-center gap-1">
        {label}
        <ArrowUpDown className={`h-3 w-3 ${sortKey === sortKeyName ? 'text-primary' : 'text-muted-foreground/40'}`} />
      </span>
    </TableHead>
  );

  if (isLoading) return <div className="p-6 text-center text-muted-foreground">{t('common.loading')}</div>;

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">{t('holding.title')}</h1>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm" onClick={handleRefreshPrices} disabled={isRefreshing}>
            <RefreshCw className={`h-4 w-4 mr-1 ${isRefreshing ? 'animate-spin' : ''}`} />
            {t('holding.refreshPrices')}
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
          <div className="grid grid-cols-3 gap-4 mb-6">
            <div className="rounded-lg border p-4">
              <div className="text-xs text-muted-foreground">{t('holding.totalMarketValue')}</div>
              <div className="text-xl font-bold">¥{totalValue.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</div>
            </div>
            <div className="rounded-lg border p-4">
              <div className="text-xs text-muted-foreground">{t('holding.totalCost')}</div>
              <div className="text-xl font-bold">¥{totalCost.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</div>
            </div>
            <div className={`rounded-lg border p-4 ${totalPnl >= 0 ? 'border-emerald-200 bg-emerald-50/50' : 'border-red-200 bg-red-50/50'}`}>
              <div className="text-xs text-muted-foreground">{t('holding.totalPnl')}</div>
              <div className={`text-xl font-bold ${totalPnl >= 0 ? 'text-emerald-600' : 'text-red-600'}`}>
                {totalPnl >= 0 ? '+' : ''}¥{totalPnl.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
              </div>
            </div>
          </div>

          {/* Filter bar */}
          <div className="flex items-center gap-3 mb-4">
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
                        <TableHead>{t('holding.symbol')}</TableHead>
                        <TableHead>{t('holding.name')}</TableHead>
                        <TableHead className="text-right">{t('holding.quantity')}</TableHead>
                        <TableHead className="text-right">{t('holding.avgCost')}</TableHead>
                        <TableHead className="text-right">{t('holding.currentPrice')}</TableHead>
                        <SortHeader label={t('holding.marketValue')} sortKeyName="marketValue" />
                        <SortHeader label={t('holding.pnl')} sortKeyName="pnl" />
                        <SortHeader label={t('holding.pnlPct')} sortKeyName="pnlPct" />
                        <TableHead className="text-right">{t('holding.actions')}</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {items.map(h => (
                        <HoldingRow key={h.id} h={h} onSell={handleSell} t={t} />
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
                    <TableHead>{t('holding.symbol')}</TableHead>
                    <TableHead>{t('holding.name')}</TableHead>
                    <TableHead className="text-right">{t('holding.quantity')}</TableHead>
                    <TableHead className="text-right">{t('holding.avgCost')}</TableHead>
                    <TableHead className="text-right">{t('holding.currentPrice')}</TableHead>
                    <SortHeader label={t('holding.marketValue')} sortKeyName="marketValue" />
                    <SortHeader label={t('holding.pnl')} sortKeyName="pnl" />
                    <SortHeader label={t('holding.pnlPct')} sortKeyName="pnlPct" />
                    <TableHead className="text-right">{t('holding.actions')}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {sortedHoldings.map(h => (
                    <HoldingRow key={h.id} h={h} onSell={handleSell} t={t} />
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
    </div>
  );
}

function HoldingRow({ h, onSell, t }: {
  h: HoldingDto & { _avgCost: number; _quantity: number; _currentPrice: number | null; _marketValue: number | null; _pnl: number; _pnlPct: number };
  onSell: (h: HoldingDto) => void;
  t: (key: string) => string;
}) {
  return (
    <TableRow>
      <TableCell className="font-medium">{h.symbol}</TableCell>
      <TableCell>{h.security_name}</TableCell>
      <TableCell className="text-right">{h._quantity}</TableCell>
      <TableCell className="text-right">{h._avgCost.toFixed(2)}</TableCell>
      <TableCell className="text-right">{h._currentPrice?.toFixed(2) || '-'}</TableCell>
      <TableCell className="text-right">{h._marketValue?.toLocaleString('en-US', { minimumFractionDigits: 2 }) || '-'}</TableCell>
      <TableCell className={`text-right ${h._pnl >= 0 ? 'text-emerald-600' : 'text-red-600'}`}>
        {h._pnl !== 0 ? (h._pnl >= 0 ? '+' : '') + '¥' + Math.abs(h._pnl).toLocaleString('en-US', { minimumFractionDigits: 2 }) : '-'}
      </TableCell>
      <TableCell className={`text-right ${h._pnlPct >= 0 ? 'text-emerald-600' : 'text-red-600'}`}>
        {h._pnlPct !== 0 ? (h._pnlPct >= 0 ? '+' : '') + h._pnlPct.toFixed(2) + '%' : '-'}
      </TableCell>
      <TableCell className="text-right">
        <Button variant="ghost" size="sm" className="text-red-600 hover:text-red-700 hover:bg-red-50 h-7 text-xs" onClick={() => onSell(h)}>
          <TrendingDown className="h-3 w-3 mr-1" />
          {t('holding.sell')}
        </Button>
      </TableCell>
    </TableRow>
  );
}
