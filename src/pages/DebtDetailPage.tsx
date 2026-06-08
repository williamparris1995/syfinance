import { useParams, useNavigate } from '@tanstack/react-router';
import { useTranslation } from 'react-i18next';
import { useQuery } from '@tanstack/react-query';
import { CreditCard } from 'lucide-react';
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
import { getDebt, listDebts, type DebtDto } from '@/lib/tauri/debt';
import { formatCurrency as formatCurrencyUtil } from '@/lib/currency';

function formatCurrency(amount: string, currencyCode: string) {
  const num = parseFloat(amount);
  return formatCurrencyUtil(num, currencyCode);
}

function formatDate(dateStr: string) {
  return new Date(dateStr).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

function debtTypeLabel(type: string, t: (key: string) => string): string {
  const map: Record<string, string> = {
    BorrowedIn: t('debtForm.borrowedIn'),
    BorrowedOut: t('debtForm.borrowedOut'),
    CreditCard: t('debtForm.creditCard'),
  };
  return map[type] || type;
}

function amortizationMethodLabel(method: string, t: (key: string) => string): string {
  const map: Record<string, string> = {
    EqualPrincipalInterest: t('debtForm.equalPrincipalInterest'),
    EqualPrincipal: t('debtForm.equalPrincipal'),
    LumpSum: t('debtForm.lumpSum'),
  };
  return map[method] || method;
}

export function DebtDetailPage() {
  const { debtId } = useParams({ strict: false }) as { debtId: string };
  const navigate = useNavigate();
  const { t } = useTranslation();

  const { data: singleDebt, isLoading: isLoadingSingle } = useQuery({
    queryKey: ['debt', debtId],
    queryFn: () => getDebt(debtId),
    enabled: !!debtId,
  });

  // Fallback: fetch all debts and find if single fetch fails
  const { data: allDebts = [], isLoading: isLoadingAll } = useQuery({
    queryKey: ['debts'],
    queryFn: listDebts,
    enabled: !!debtId && !singleDebt,
  });

  const debt: DebtDto | undefined = singleDebt ?? allDebts.find((d) => d.account_id === debtId);
  const isLoading = isLoadingSingle || (isLoadingAll && !singleDebt);

  if (isLoading) {
    return (
      <PageShell>
        <div className="flex items-center justify-center py-12">
          <div className="text-muted-foreground">{t('common.loading')}</div>
        </div>
      </PageShell>
    );
  }

  if (!debt) {
    return (
      <PageShell>
        <div className="flex items-center justify-center py-12">
          <div className="text-muted-foreground">{t('common.noResults')}</div>
        </div>
      </PageShell>
    );
  }

  const principal = parseFloat(debt.principal_amount);
  const remaining = parseFloat(debt.remaining_principal);
  const paidPct = principal > 0 ? ((principal - remaining) / principal) * 100 : 0;

  const typeColors: Record<string, string> = {
    BorrowedIn: 'bg-red-100 text-red-800',
    BorrowedOut: 'bg-blue-100 text-blue-800',
    CreditCard: 'bg-purple-100 text-purple-800',
  };

  const paidPayments = debt.payment_schedule.filter((p) => p.paid);
  const unpaidPayments = debt.payment_schedule.filter((p) => !p.paid);

  return (
    <PageShell>
      <HeroCard icon={<CreditCard className="h-5 w-5" />} name={debt.account_name} subtitle={debt.counterparty}>
        <div className="font-display text-4xl font-semibold text-expense">
          {formatCurrency(debt.remaining_principal, debt.currency_code)}
        </div>
        <div className="text-xs text-muted-foreground">{t('debts.remainingBalance')}</div>
        {/* Progress bar */}
        <div className="mt-3 h-2 rounded-full bg-border overflow-hidden w-full">
          <div className="h-full rounded-full bg-primary" style={{ width: `${Math.min(paidPct, 100)}%` }} />
        </div>
        <div className="text-[11px] text-muted-foreground mt-1">{paidPct.toFixed(1)}% {t('debts.paidOff')}</div>
      </HeroCard>

      <div className="grid grid-cols-4 gap-3.5 mb-7">
        <StatCard label={t('debts.principal')} value={formatCurrency(debt.principal_amount, debt.currency_code)} />
        <StatCard label={t('debts.interestRate')} value={`${debt.interest_rate}%`} />
        <StatCard label={t('debts.dueDate')} value={formatDate(debt.due_date)} />
        <StatCard label={t('debtForm.type')} value={debtTypeLabel(debt.account_type, t)} />
      </div>

      <DetailTwoCol
        main={
          <div className="rounded-[14px] border border-border bg-card overflow-hidden">
            <h3 className="px-5 pt-5 pb-3 text-sm font-semibold">
              {t('debts.paymentSchedule')}
            </h3>
            {debt.payment_schedule.length === 0 ? (
              <div className="px-5 py-6 text-center text-sm text-muted-foreground">
                {t('common.noResults')}
              </div>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow className="bg-muted/50">
                    <TableHead>{t('common.date')}</TableHead>
                    <TableHead className="text-right">{t('debts.principal')}</TableHead>
                    <TableHead className="text-right">{t('debts.interest')}</TableHead>
                    <TableHead className="text-right">{t('debts.total')}</TableHead>
                    <TableHead>{t('debts.status')}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {debt.payment_schedule.map((payment) => (
                    <TableRow key={payment.id}>
                      <TableCell className="text-sm">{formatDate(payment.payment_date)}</TableCell>
                      <TableCell className="text-right text-sm">{formatCurrency(payment.principal_amount, debt.currency_code)}</TableCell>
                      <TableCell className="text-right text-sm">{formatCurrency(payment.interest_amount, debt.currency_code)}</TableCell>
                      <TableCell className="text-right text-sm font-medium">{formatCurrency(payment.total_amount, debt.currency_code)}</TableCell>
                      <TableCell>
                        <Badge variant={payment.paid ? 'secondary' : 'default'} className="text-[10px]">
                          {payment.paid ? t('debts.paid') : t('debts.unpaid')}
                        </Badge>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </div>
        }
        side={
          <div className="rounded-[14px] border border-border bg-card p-5 space-y-4">
            <div>
              <div className="text-xs text-muted-foreground">{t('debts.startDate')}</div>
              <div className="text-sm">{formatDate(debt.start_date)}</div>
            </div>
            <div>
              <div className="text-xs text-muted-foreground">{t('debts.amortizationMethod')}</div>
              <div className="text-sm">{amortizationMethodLabel(debt.amortization_method, t)}</div>
            </div>
            <div>
              <div className="text-xs text-muted-foreground">{t('common.currency')}</div>
              <div className="text-sm">{debt.currency_code}</div>
            </div>
            <div>
              <div className="text-xs text-muted-foreground">{t('debtForm.type')}</div>
              <div className="text-sm">
                <Badge className={typeColors[debt.account_type] || ''}>
                  {debtTypeLabel(debt.account_type, t)}
                </Badge>
              </div>
            </div>
            <div>
              <div className="text-xs text-muted-foreground">{t('debts.counterparty')}</div>
              <div className="text-sm">{debt.counterparty}</div>
            </div>
            <Separator />
            <div className="space-y-2 text-xs text-muted-foreground">
              <div>{t('debts.paid')}: {paidPayments.length} / {debt.payment_schedule.length} {t('debts.results')}</div>
              <div>{t('debts.total')}: {formatCurrency(
                paidPayments.reduce((sum, p) => sum + parseFloat(p.total_amount), 0).toString(),
                debt.currency_code,
              )}</div>
            </div>
            <Separator />
            <Button
              variant="outline"
              className="w-full"
              onClick={() => navigate({ to: '/debts' })}
            >
              {t('common.back')}
            </Button>
          </div>
        }
      />
    </PageShell>
  );
}
