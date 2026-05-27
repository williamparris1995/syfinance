import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { useState } from 'react';
import { toast } from 'sonner';
import { Button } from '../components/ui/button';
import {
  Sheet, SheetContent, SheetHeader, SheetTitle,
} from '../components/ui/sheet';
import { Badge } from '../components/ui/badge';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '../components/ui/table';
import { HoldingTradeForm } from '../components/HoldingTradeForm';
import { getUserFriendlyError } from '../lib/error-handler';
import { buyHolding, sellHolding, listHoldings, type HoldingDto, type HoldingTradeDto } from '../lib/tauri/holding';

const typeColors: Record<string, string> = {
  stock: 'bg-blue-100 text-blue-800',
  fund: 'bg-green-100 text-green-800',
  etf: 'bg-emerald-100 text-emerald-800',
  bond: 'bg-amber-100 text-amber-800',
  gold: 'bg-yellow-100 text-yellow-800',
  option: 'bg-purple-100 text-purple-800',
};

export function HoldingsPage() {
  const { t } = useTranslation();
  const [showTradeSheet, setShowTradeSheet] = useState(false);
  const queryClient = useQueryClient();

  const { data: holdings = [], isLoading } = useQuery({ queryKey: ['holdings'], queryFn: listHoldings });

  const tradeMutation = useMutation({
    mutationFn: (dto: HoldingTradeDto) => dto.direction === 'BUY' ? buyHolding(dto) : sellHolding(dto),
    onSuccess: (_data, vars) => {
      queryClient.invalidateQueries({ queryKey: ['holdings'] });
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      setShowTradeSheet(false);
      toast.success(vars.direction === 'BUY' ? t('holding.buySuccess') : t('holding.sellSuccess'));
    },
    onError: (error) => toast.error(getUserFriendlyError(error)),
  });

  const grouped = holdings.reduce((acc, h) => {
    (acc[h.security_type] ||= []).push(h);
    return acc;
  }, {} as Record<string, HoldingDto[]>);

  if (isLoading) return <div className="p-6 text-center text-muted-foreground">{t('common.loading')}</div>;

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">{t('holding.title')}</h1>
        <Button variant="default-gradient" onClick={() => setShowTradeSheet(true)}>
          {t('holding.newTrade')}
        </Button>
      </div>

      {holdings.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <p className="text-neutral-500 mb-4">{t('holding.noHoldings')}</p>
          <Button onClick={() => setShowTradeSheet(true)}>{t('holding.firstTrade')}</Button>
        </div>
      ) : (
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
                    <TableHead className="text-right">{t('holding.marketValue')}</TableHead>
                    <TableHead className="text-right">{t('holding.pnl')}</TableHead>
                    <TableHead className="text-right">{t('holding.pnlPct')}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {items.map(h => {
                    const avgCost = Number(h.avg_cost) || 0;
                    const quantity = Number(h.quantity) || 0;
                    const currentPrice = h.current_price != null ? Number(h.current_price) : null;
                    const marketValue = h.market_value != null ? Number(h.market_value) : null;
                    const pnl = h.unrealized_pnl != null ? Number(h.unrealized_pnl) : 0;
                    const pnlPct = currentPrice && avgCost > 0 ? ((currentPrice - avgCost) / avgCost * 100) : 0;
                    return (
                      <TableRow key={h.id}>
                        <TableCell className="font-medium">{h.symbol}</TableCell>
                        <TableCell>{h.security_name}</TableCell>
                        <TableCell className="text-right">{quantity}</TableCell>
                        <TableCell className="text-right">{avgCost.toFixed(2)}</TableCell>
                        <TableCell className="text-right">{currentPrice?.toFixed(2) || '-'}</TableCell>
                        <TableCell className="text-right">{marketValue?.toLocaleString() || '-'}</TableCell>
                        <TableCell className={`text-right ${pnl >= 0 ? 'text-emerald-600' : 'text-red-600'}`}>
                          {pnl !== 0 ? (pnl >= 0 ? '+' : '') + pnl.toLocaleString() : '-'}
                        </TableCell>
                        <TableCell className={`text-right ${pnlPct >= 0 ? 'text-emerald-600' : 'text-red-600'}`}>
                          {pnlPct !== 0 ? (pnlPct >= 0 ? '+' : '') + pnlPct.toFixed(2) + '%' : '-'}
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </div>
          </div>
        ))
      )}

      <Sheet open={showTradeSheet} onOpenChange={setShowTradeSheet}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{t('holding.newTrade')}</SheetTitle>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto -mx-4 px-4">
            <HoldingTradeForm
              onSubmit={(dto) => tradeMutation.mutate(dto)}
              onCancel={() => setShowTradeSheet(false)}
              isLoading={tradeMutation.isPending}
            />
          </div>
        </SheetContent>
      </Sheet>
    </div>
  );
}
