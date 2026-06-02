import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { CheckCircle2 } from 'lucide-react';
import { Badge } from './ui/badge';
import { Separator } from './ui/separator';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from './ui/sheet';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from './ui/table';
import { TransactionList } from './TransactionList';
import { getTransactionsByAccount } from '@/lib/tauri/transaction';
import type { DebtDto } from '@/lib/tauri/debt';
import { formatCurrency as formatCurrencyUtil } from '@/lib/currency';

interface DebtDetailPanelProps {
  debt: DebtDto;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

function formatCurrency(amount: string, currencyCode: string) {
  const num = parseFloat(amount);
  return formatCurrencyUtil(num, currencyCode);
}

function debtTypeBadge(type: string) {
  const map: Record<string, string> = {
    BorrowedIn: 'bg-red-100 text-red-800',
    BorrowedOut: 'bg-amber-100 text-amber-800',
    CreditCard: 'bg-orange-100 text-orange-800',
  };
  return map[type] || 'bg-gray-100 text-gray-800';
}

function amortizationLabel(method: string, t: (key: string) => string) {
  const map: Record<string, string> = {
    EqualPrincipalInterest: t('debtForm.equalPrincipalInterest'),
    EqualPrincipal: t('debtForm.equalPrincipal'),
    LumpSum: t('debtForm.lumpSum'),
  };
  return map[method] || method;
}

export function DebtDetailPanel({ debt, open, onOpenChange }: DebtDetailPanelProps) {
  const { t } = useTranslation();

  const { data: transactions = [], isLoading: isLoadingTx } = useQuery({
    queryKey: ['account-transactions', debt.account_id],
    queryFn: () => getTransactionsByAccount(debt.account_id),
    enabled: open && !!debt.account_id,
  });

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="right" className="w-full sm:max-w-2xl">
        <SheetHeader>
          <SheetTitle className="flex items-center gap-2">
            {debt.account_name}
            <Badge className={debtTypeBadge(debt.account_type)}>
              {debt.account_type === 'BorrowedIn' ? t('debtForm.borrowedIn')
                : debt.account_type === 'BorrowedOut' ? t('debtForm.borrowedOut')
                : t('debtForm.creditCard')}
            </Badge>
          </SheetTitle>
        </SheetHeader>
        <div className="flex-1 overflow-y-auto -mx-4 px-4">
          <div className="space-y-4 px-5 pt-4">
            {/* Summary */}
            <div className="grid grid-cols-2 gap-3">
              <div>
                <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('debts.counterparty')}</div>
                <div className="text-sm font-medium">{debt.counterparty}</div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('debts.principal')}</div>
                <div className="text-sm font-medium">{formatCurrency(debt.principal_amount, debt.currency_code)}</div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('debts.remainingBalance')}</div>
                <div className="text-sm font-bold">{formatCurrency(debt.remaining_principal, debt.currency_code)}</div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('debts.interestRate')}</div>
                <div className="text-sm font-medium">{debt.interest_rate}% {t('debts.perYear')}</div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('debts.startDate')}</div>
                <div className="text-sm font-medium">{debt.start_date}</div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('debts.dueDate')}</div>
                <div className="text-sm font-medium">{debt.due_date}</div>
              </div>
              <div className="col-span-2">
                <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('debtForm.amortizationMethod')}</div>
                <div className="text-sm font-medium">{amortizationLabel(debt.amortization_method, t)}</div>
              </div>
            </div>

            <Separator />

            {/* Payment Schedule */}
            {debt.payment_schedule && debt.payment_schedule.length > 0 && (
              <>
                <div>
                  <h3 className="text-sm font-medium mb-2">{t('debts.paymentSchedule')}</h3>
                  <div className="border rounded-lg">
                    <Table>
                      <TableHeader>
                        <TableRow>
                          <TableHead className="w-[50px]">#</TableHead>
                          <TableHead>{t('common.date')}</TableHead>
                          <TableHead className="text-right">{t('debts.principal')}</TableHead>
                          <TableHead className="text-right">{t('debts.interest')}</TableHead>
                          <TableHead className="text-right">{t('debts.total')}</TableHead>
                          <TableHead className="w-[50px]">{t('debts.status')}</TableHead>
                        </TableRow>
                      </TableHeader>
                      <TableBody>
                        {debt.payment_schedule.map((p, i) => (
                          <TableRow key={p.id} className={p.paid ? 'opacity-50' : ''}>
                            <TableCell className="text-xs text-muted-foreground">{i + 1}</TableCell>
                            <TableCell className="text-xs">{p.payment_date}</TableCell>
                            <TableCell className="text-xs text-right">{formatCurrency(p.principal_amount, debt.currency_code)}</TableCell>
                            <TableCell className="text-xs text-right">{formatCurrency(p.interest_amount, debt.currency_code)}</TableCell>
                            <TableCell className="text-xs text-right font-medium">{formatCurrency(p.total_amount, debt.currency_code)}</TableCell>
                            <TableCell>
                              {p.paid ? (
                                <CheckCircle2 className="h-4 w-4 text-emerald-600" />
                              ) : (
                                <span className="text-xs text-muted-foreground">{t('debts.unpaid')}</span>
                              )}
                            </TableCell>
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
                  </div>
                </div>
                <Separator />
              </>
            )}

            {/* Transaction History */}
            <div>
              <h3 className="text-sm font-medium mb-2">{t('debts.transactionHistory')}</h3>
              <TransactionList
                transactions={transactions}
                accountId={debt.account_id}
                currencyCode={debt.currency_code}
                isLoading={isLoadingTx}
              />
            </div>
          </div>
        </div>
      </SheetContent>
    </Sheet>
  );
}
