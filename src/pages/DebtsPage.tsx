import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { AlertCircle, Calendar } from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { DebtForm } from '../components/DebtForm';
import { Badge } from '../components/ui/badge';
import { Button } from '../components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '../components/ui/dialog';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from '../components/ui/sheet';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '../components/ui/table';
import { getUserFriendlyError } from '../lib/error-handler';
import {
  createDebt,
  getUpcomingPayments,
  listDebts,
  recordPayment,
  type CreateDebtDto,
  type DebtDto,
  type PaymentScheduleDto,
  type RecordPaymentDto,
  type UpcomingPaymentDto,
} from '../lib/tauri/debt';

export function DebtsPage() {
  const { t } = useTranslation();
  const [isSheetOpen, setIsSheetOpen] = useState(false);
  const [selectedDebt, setSelectedDebt] = useState<DebtDto | null>(null);
  const [paymentToRecord, setPaymentToRecord] = useState<{
    debt: DebtDto;
    payment: PaymentScheduleDto;
  } | null>(null);
  const queryClient = useQueryClient();

  const { data: debts = [], isLoading } = useQuery({
    queryKey: ['debts'],
    queryFn: listDebts,
  });

  const { data: upcomingPayments = [] } = useQuery({
    queryKey: ['upcoming-payments'],
    queryFn: () => getUpcomingPayments(7),
  });

  const createMutation = useMutation({
    mutationFn: createDebt,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['debts'] });
      queryClient.invalidateQueries({ queryKey: ['upcoming-payments'] });
      setIsSheetOpen(false);
      toast.success(t('debts.debtCreated'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });

  const recordPaymentMutation = useMutation({
    mutationFn: recordPayment,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['debts'] });
      queryClient.invalidateQueries({ queryKey: ['upcoming-payments'] });
      setPaymentToRecord(null);
      setSelectedDebt(null);
      toast.success(t('debts.paymentRecorded'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });

  const handleCreateClick = () => {
    setIsSheetOpen(true);
  };

  const handleCreateDebt = (data: CreateDebtDto) => {
    createMutation.mutate(data);
  };

  const handleRecordPayment = () => {
    if (!paymentToRecord) return;
    const dto: RecordPaymentDto = {
      debt_id: paymentToRecord.debt.id,
      payment_date: paymentToRecord.payment.payment_date,
      transaction_id: '00000000-0000-0000-0000-000000000000',
    };
    recordPaymentMutation.mutate(dto);
  };

  const getDebtStatus = (debt: DebtDto) => {
    const remainingBalance = parseFloat(debt.remaining_balance);
    const today = new Date();
    const dueDate = new Date(debt.due_date);
    if (remainingBalance === 0) {
      return { label: t('debts.paidOff'), variant: 'secondary' as const };
    }
    if (dueDate < today) {
      return { label: t('debts.overdue'), variant: 'destructive' as const };
    }
    return { label: t('debts.active'), variant: 'default' as const };
  };

  const overdueDebts = debts.filter((debt) => {
    const remainingBalance = parseFloat(debt.remaining_balance);
    const today = new Date();
    const dueDate = new Date(debt.due_date);
    return remainingBalance > 0 && dueDate < today;
  });

  const formatCurrency = (amount: string, currencyCode: string) => {
    const num = parseFloat(amount);
    const formatted = num.toLocaleString('en-US', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    });
    const symbols: Record<string, string> = {
      CNY: '¥',
      USD: '$',
      EUR: '€',
    };
    return `${symbols[currencyCode] || currencyCode} ${formatted}`;
  };

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">{t('debts.title')}</h1>
        <Button variant="default-gradient" onClick={handleCreateClick}>{t('debts.createDebt')}</Button>
      </div>

      {overdueDebts.length > 0 && (
        <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg">
          <div className="flex items-center gap-2 mb-3">
            <AlertCircle className="h-5 w-5 text-red-600" />
            <h2 className="text-lg font-semibold text-red-900">{t('debts.overdueDebts')}</h2>
          </div>
          <div className="space-y-2">
            {overdueDebts.map((debt) => (
              <div
                key={debt.id}
                className="flex items-center justify-between p-3 bg-white rounded border border-red-200"
              >
                <div>
                  <div className="font-medium text-red-900">{debt.counterparty}</div>
                  <div className="text-sm text-red-700">
                    {t('debts.due')}: {new Date(debt.due_date).toLocaleDateString('en-US', {
                      year: 'numeric',
                      month: 'short',
                      day: 'numeric',
                    })}
                  </div>
                </div>
                <div className="text-right">
                  <div className="font-semibold text-red-900">
                    {formatCurrency(debt.remaining_balance, debt.currency_code)}
                  </div>
                  <div className="text-sm text-red-700">{debt.debt_type}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {upcomingPayments.length > 0 && (
        <div className="mb-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
          <div className="flex items-center gap-2 mb-3">
            <Calendar className="h-5 w-5 text-blue-600" />
            <h2 className="text-lg font-semibold text-blue-900">{t('debts.upcomingPayments')}</h2>
          </div>
          <div className="space-y-2">
            {upcomingPayments.map((item: UpcomingPaymentDto, index: number) => (
              <div
                key={index}
                className="flex items-center justify-between p-3 bg-white rounded border border-blue-200"
              >
                <div>
                  <div className="font-medium text-blue-900">{item.debt.counterparty}</div>
                  <div className="text-sm text-blue-700">
                    {t('debts.paymentDate')}: {new Date(item.payment.payment_date).toLocaleDateString('en-US', {
                      year: 'numeric',
                      month: 'short',
                      day: 'numeric',
                    })}
                  </div>
                </div>
                <div className="text-right">
                  <div className="font-semibold text-blue-900">
                    {formatCurrency(item.payment.total_amount, item.payment.currency_code)}
                  </div>
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => setPaymentToRecord({ debt: item.debt, payment: item.payment })}
                    className="mt-1"
                  >
                    {t('debts.recordPayment')}
                  </Button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <div className="text-neutral-500">{t('debts.loadingDebts')}</div>
        </div>
      ) : debts.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <p className="text-neutral-500 mb-4">{t('debts.noDebts')}</p>
          <Button onClick={handleCreateClick}>{t('debts.createFirstDebt')}</Button>
        </div>
      ) : (
        <div className="border rounded-lg">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t('debts.type')}</TableHead>
                <TableHead>{t('debts.counterparty')}</TableHead>
                <TableHead className="text-right">{t('debts.principal')}</TableHead>
                <TableHead className="text-right">{t('debts.remainingBalance')}</TableHead>
                <TableHead>{t('debts.dueDate')}</TableHead>
                <TableHead>{t('debts.status')}</TableHead>
                <TableHead className="w-[100px]">{t('common.actions')}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {debts.map((debt: DebtDto) => {
                const status = getDebtStatus(debt);
                return (
                  <TableRow key={debt.id}>
                    <TableCell className="font-medium">{debt.debt_type}</TableCell>
                    <TableCell>{debt.counterparty}</TableCell>
                    <TableCell className="text-right">
                      {formatCurrency(debt.principal_amount, debt.currency_code)}
                    </TableCell>
                    <TableCell className="text-right">
                      {formatCurrency(debt.remaining_balance, debt.currency_code)}
                    </TableCell>
                    <TableCell>
                      {new Date(debt.due_date).toLocaleDateString('en-US', {
                        year: 'numeric',
                        month: 'short',
                        day: 'numeric',
                      })}
                    </TableCell>
                    <TableCell>
                      <Badge variant={status.variant}>{status.label}</Badge>
                    </TableCell>
                    <TableCell>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => setSelectedDebt(debt)}
                      >
                        {t('debts.view')}
                      </Button>
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </div>
      )}

      <Sheet open={isSheetOpen} onOpenChange={setIsSheetOpen}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{t('debts.createDebt')}</SheetTitle>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto -mx-4 px-4">
            <DebtForm
              onSubmit={handleCreateDebt}
              onCancel={() => setIsSheetOpen(false)}
              isLoading={createMutation.isPending}
            />
          </div>
        </SheetContent>
      </Sheet>

      <Dialog open={!!selectedDebt} onOpenChange={() => setSelectedDebt(null)}>
        <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>{t('debts.debtDetails')}</DialogTitle>
            <DialogDescription>
              {selectedDebt?.counterparty} - {selectedDebt?.debt_type}
            </DialogDescription>
          </DialogHeader>
          {selectedDebt && (
            <div className="space-y-6">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <div className="text-sm text-neutral-500">{t('debts.principalAmount')}</div>
                  <div className="text-lg font-semibold">
                    {formatCurrency(selectedDebt.principal_amount, selectedDebt.currency_code)}
                  </div>
                </div>
                <div>
                  <div className="text-sm text-neutral-500">{t('debts.remainingBalance')}</div>
                  <div className="text-lg font-semibold">
                    {formatCurrency(selectedDebt.remaining_balance, selectedDebt.currency_code)}
                  </div>
                </div>
                <div>
                  <div className="text-sm text-neutral-500">{t('debts.interestRate')}</div>
                  <div className="text-lg font-semibold">{selectedDebt.interest_rate}% {t('debts.perYear')}</div>
                </div>
                <div>
                  <div className="text-sm text-neutral-500">{t('debts.dueDate')}</div>
                  <div className="text-lg font-semibold">
                    {new Date(selectedDebt.due_date).toLocaleDateString('en-US', {
                      year: 'numeric',
                      month: 'short',
                      day: 'numeric',
                    })}
                  </div>
                </div>
              </div>

              <div>
                <h3 className="text-lg font-semibold mb-3">{t('debts.paymentSchedule')}</h3>
                <div className="border rounded-lg max-h-[400px] overflow-y-auto">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>{t('debts.paymentDate')}</TableHead>
                        <TableHead className="text-right">{t('debts.principal')}</TableHead>
                        <TableHead className="text-right">{t('debts.interest')}</TableHead>
                        <TableHead className="text-right">{t('debts.total')}</TableHead>
                        <TableHead>{t('debts.status')}</TableHead>
                        <TableHead className="w-[120px]">{t('common.actions')}</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {selectedDebt.payment_schedule.map((payment: PaymentScheduleDto, index: number) => (
                        <TableRow key={index}>
                          <TableCell>
                            {new Date(payment.payment_date).toLocaleDateString('en-US', {
                              year: 'numeric',
                              month: 'short',
                              day: 'numeric',
                            })}
                          </TableCell>
                          <TableCell className="text-right">
                            {formatCurrency(payment.principal_amount, payment.currency_code)}
                          </TableCell>
                          <TableCell className="text-right">
                            {formatCurrency(payment.interest_amount, payment.currency_code)}
                          </TableCell>
                          <TableCell className="text-right font-medium">
                            {formatCurrency(payment.total_amount, payment.currency_code)}
                          </TableCell>
                          <TableCell>
                            <Badge variant={payment.paid ? 'secondary' : 'outline'}>
                              {payment.paid ? t('debts.paid') : t('debts.unpaid')}
                            </Badge>
                          </TableCell>
                          <TableCell>
                            {!payment.paid && (
                              <Button
                                size="sm"
                                variant="outline"
                                onClick={() => setPaymentToRecord({ debt: selectedDebt, payment })}
                              >
                                {t('debts.record')}
                              </Button>
                            )}
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </div>
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>

      <Dialog open={!!paymentToRecord} onOpenChange={() => setPaymentToRecord(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('debts.recordPayment')}</DialogTitle>
            <DialogDescription>
              {t('debts.confirmPayment', { counterparty: paymentToRecord?.debt.counterparty })}
            </DialogDescription>
          </DialogHeader>
          {paymentToRecord && (
            <div className="space-y-4">
              <div>
                <div className="text-sm text-neutral-500">{t('debts.paymentDate')}</div>
                <div className="text-lg font-semibold">
                  {new Date(paymentToRecord.payment.payment_date).toLocaleDateString('en-US', {
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric',
                  })}
                </div>
              </div>
              <div>
                <div className="text-sm text-neutral-500">{t('debts.amount')}</div>
                <div className="text-lg font-semibold">
                  {formatCurrency(paymentToRecord.payment.total_amount, paymentToRecord.payment.currency_code)}
                </div>
              </div>
              <div className="flex justify-end gap-2 pt-4">
                <Button variant="outline" onClick={() => setPaymentToRecord(null)}>
                  {t('common.cancel')}
                </Button>
                <Button
                  onClick={handleRecordPayment}
                  disabled={recordPaymentMutation.isPending}
                >
                  {recordPaymentMutation.isPending ? t('debts.recording') : t('debts.confirmPaymentButton')}
                </Button>
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
