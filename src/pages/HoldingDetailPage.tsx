import { useParams, useNavigate } from '@tanstack/react-router';
import { useTranslation } from 'react-i18next';
import { useQuery } from '@tanstack/react-query';
import { BarChart3 } from 'lucide-react';
import { cn } from '@/lib/utils';
import { PageShell } from '@/components/patterns/layout/PageShell';
import { HeroCard } from '@/components/patterns/cards/HeroCard';
import { StatCard } from '@/components/patterns/cards/StatCard';
import { DetailTwoCol } from '@/components/patterns/detail/DetailTwoCol';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Separator } from '@/components/ui/separator';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { listHoldings, listHoldingTransactionsPaginated } from '@/lib/tauri/holding';
import { formatCurrency } from '@/lib/currency';
import { multiplyDecimal, subtractDecimals, addDecimals, multiplyDecimals } from '@/lib/decimal';
import { useCursorPagination } from '@/hooks/useCursorPagination';

export function HoldingDetailPage() {
  const { holdingId } = useParams({ strict: false }) as { holdingId: string };
  const navigate = useNavigate();
  const { t } = useTranslation();

  const { data: holdings = [], isLoading } = useQuery({
    queryKey: ['holdings'],
    queryFn: listHoldings,
  });

  const holding = holdings.find((h) => h.id === holdingId);

  const {
    items: tradeHistory,
    isLoading: isLoadingTrades,
    hasNextPage: hasMoreTrades,
    goNext: loadMoreTrades,
  } = useCursorPagination(
    ['holding-trades-detail', holdingId],
    async (cursor) => {
      return listHoldingTransactionsPaginated(holdingId, 20, cursor ?? undefined);
    },
    { enabled: !!holdingId },
  );

  if (isLoading) {
    return (
      <PageShell>
        <div className="flex items-center justify-center py-12">
          <div className="text-muted-foreground">{t('common.loading')}</div>
        </div>
      </PageShell>
    );
  }

  if (!holding) {
    return (
      <PageShell>
        <div className="flex items-center justify-center py-12">
          <div className="text-muted-foreground">{t('common.noResults')}</div>
        </div>
      </PageShell>
    );
  }

  // Compute enriched values (same logic as HoldingsPage)
  const quantity = Number(holding.quantity) || 0;
  const avgCost = Number(holding.avg_cost) || 0;
  const currentPrice = holding.current_price != null ? Number(holding.current_price) : null;
  const marketValue = currentPrice != null
    ? parseFloat(multiplyDecimal(String(currentPrice), quantity))
    : null;
  const totalCost = parseFloat(multiplyDecimal(String(avgCost), quantity));
  const pnl = marketValue != null
    ? parseFloat(subtractDecimals(String(marketValue), String(totalCost)))
    : 0;
  const pnlPct = currentPrice != null && avgCost > 0
    ? ((currentPrice - avgCost) / avgCost * 100) : 0;

  const displayMarketValue = marketValue ?? totalCost;

  const typeColors: Record<string, string> = {
    stock: 'bg-blue-100 text-blue-800',
    fund: 'bg-green-100 text-green-800',
    etf: 'bg-emerald-100 text-emerald-800',
    bond: 'bg-amber-100 text-amber-800',
    gold: 'bg-yellow-100 text-yellow-800',
    option: 'bg-purple-100 text-purple-800',
    other: 'bg-gray-100 text-gray-800',
  };

  return (
    <PageShell>
      <HeroCard
        icon={<BarChart3 className="h-5 w-5" />}
        name={holding.symbol}
        subtitle={holding.security_name}
      >
        <div className="font-display text-4xl font-semibold">
          {formatCurrency(displayMarketValue, 'CNY')}
        </div>
        <div className={cn("text-sm font-medium", pnl >= 0 ? "text-income" : "text-expense")}>
          {pnl >= 0 ? '+' : ''}{formatCurrency(pnl, 'CNY')} ({pnlPct.toFixed(2)}%)
        </div>
      </HeroCard>

      <div className="grid grid-cols-4 gap-3.5 mb-7">
        <StatCard label={t('holding.quantity')} value={String(quantity)} />
        <StatCard label={t('holding.avgCost')} value={avgCost.toFixed(2)} />
        <StatCard label={t('holding.currentPrice')} value={currentPrice?.toFixed(2) || '—'} />
        <StatCard label={t('holding.securityType')} value={t(`holding.types.${holding.security_type}`)} />
      </div>

      <DetailTwoCol
        main={
          <div className="rounded-[14px] border border-border bg-card overflow-hidden">
            <h3 className="px-5 pt-5 pb-3 text-sm font-semibold">
              {t('holding.tradeHistory')}
            </h3>
            {isLoadingTrades ? (
              <div className="px-5 py-6 text-center text-sm text-muted-foreground">
                {t('common.loading')}
              </div>
            ) : tradeHistory.length === 0 ? (
              <div className="px-5 py-6 text-center text-sm text-muted-foreground">
                {t('holding.noTradeHistory')}
              </div>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow className="bg-muted/50">
                    <TableHead>{t('common.date')}</TableHead>
                    <TableHead>{t('common.type')}</TableHead>
                    <TableHead className="text-right">{t('holding.quantity')}</TableHead>
                    <TableHead className="text-right">{t('holding.price')}</TableHead>
                    <TableHead className="text-right">{t('holding.fee')}</TableHead>
                    <TableHead className="text-right">{t('holding.tradeTotal')}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {tradeHistory.map((trade) => {
                    const totalAmount = parseFloat(addDecimals(
                      multiplyDecimals(String(trade.quantity), String(trade.price)),
                      String(trade.fee),
                    ));
                    return (
                      <TableRow key={trade.id}>
                        <TableCell className="text-sm">{trade.trade_date}</TableCell>
                        <TableCell>
                          <Badge variant={trade.trade_type === 'BUY' ? 'default' : 'secondary'} className="text-[10px]">
                            {trade.trade_type === 'BUY' ? t('holding.buy') : t('holding.sell')}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-right text-sm">{Number(trade.quantity)}</TableCell>
                        <TableCell className="text-right text-sm">{Number(trade.price).toFixed(2)}</TableCell>
                        <TableCell className="text-right text-sm">{Number(trade.fee).toFixed(2)}</TableCell>
                        <TableCell className="text-right text-sm font-medium">
                          {totalAmount.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                        </TableCell>
                      </TableRow>
                    );
                  })}
                  {hasMoreTrades && (
                    <TableRow>
                      <TableCell colSpan={6} className="py-1">
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
                </TableBody>
              </Table>
            )}
          </div>
        }
        side={
          <div className="rounded-[14px] border border-border bg-card p-5 space-y-4">
            <div>
              <div className="text-xs text-muted-foreground">{t('holding.accountName')}</div>
              <div className="text-sm">{holding.account_name}</div>
            </div>
            <div>
              <div className="text-xs text-muted-foreground">{t('holding.securityType')}</div>
              <div className="text-sm">
                <Badge className={typeColors[holding.security_type] || ''}>
                  {t(`holding.types.${holding.security_type}`)}
                </Badge>
              </div>
            </div>
            <div>
              <div className="text-xs text-muted-foreground">{t('holding.currency')}</div>
              <div className="text-sm">{holding.currency_code}</div>
            </div>
            <Separator />
            <Button
              variant="outline"
              className="w-full"
              onClick={() => navigate({ to: '/holdings' })}
            >
              {t('common.back')}
            </Button>
          </div>
        }
      />
    </PageShell>
  );
}
