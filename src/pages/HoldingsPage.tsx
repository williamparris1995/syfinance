import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { Badge } from '../components/ui/badge';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '../components/ui/table';
import { listHoldings, type HoldingDto } from '../lib/tauri/holding';

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
  const { data: holdings = [], isLoading } = useQuery({ queryKey: ['holdings'], queryFn: listHoldings });

  const grouped = holdings.reduce((acc, h) => {
    (acc[h.security_type] ||= []).push(h);
    return acc;
  }, {} as Record<string, HoldingDto[]>);

  if (isLoading) return <div className="p-6 text-center text-muted-foreground">{t('common.loading')}</div>;

  return (
    <div className="p-6">
      <h1 className="text-3xl font-bold mb-6">{t('holding.title')}</h1>
      {Object.entries(grouped).map(([type, items]) => (
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
                  const pnl = h.unrealized_pnl ?? 0;
                  const pnlPct = h.current_price && h.avg_cost > 0 ? ((h.current_price - h.avg_cost) / h.avg_cost * 100) : 0;
                  return (
                    <TableRow key={h.id}>
                      <TableCell className="font-medium">{h.symbol}</TableCell>
                      <TableCell>{h.security_name}</TableCell>
                      <TableCell className="text-right">{h.quantity}</TableCell>
                      <TableCell className="text-right">{h.avg_cost.toFixed(2)}</TableCell>
                      <TableCell className="text-right">{h.current_price?.toFixed(2) || '-'}</TableCell>
                      <TableCell className="text-right">{h.market_value?.toLocaleString() || '-'}</TableCell>
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
      ))}
    </div>
  );
}
