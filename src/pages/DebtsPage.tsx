import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { AlertCircle, Calendar } from 'lucide-react';
import { useState } from 'react';
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
  const [isCreateDialogOpen, setIsCreateDialogOpen] = useState(false);
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
      setIsCreateDialogOpen(false);
      toast.success('Debt created successfully');
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
      toast.success('Payment recorded successfully');
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });

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
      return { label: 'Paid Off', variant: 'secondary' as const };
    }

    if (dueDate < today) {
      return { label: 'Overdue', variant: 'destructive' as const };
    }

    return { label: 'Active', variant: 'default' as const };
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
        <h1 className="text-3xl font-bold">Debts</h1>
        <Button onClick={() => setIsCreateDialogOpen(true)}>Create Debt</Button>
      </div>

      {overdueDebts.length > 0 && (
        <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg">
          <div className="flex items-center gap-2 mb-3">
            <AlertCircle className="h-5 w-5 text-red-600" />
            <h2 className="text-lg font-semibold text-red-900">Overdue Debts</h2>
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
                    Due: {new Date(debt.due_date).toLocaleDateString('en-US', {
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
            <h2 className="text-lg font-semibold text-blue-900">Upcoming Payments (Next 7 Days)</h2>
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
                    Payment Date: {new Date(item.payment.payment_date).toLocaleDateString('en-US', {
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
                    Record Payment
                  </Button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <div className="text-neutral-500">Loading debts...</div>
        </div>
      ) : debts.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <p className="text-neutral-500 mb-4">No debts yet</p>
          <Button onClick={() => setIsCreateDialogOpen(true)}>Create your first debt</Button>
        </div>
      ) : (
        <div className="border rounded-lg">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Type</TableHead>
                <TableHead>Counterparty</TableHead>
                <TableHead className="text-right">Principal</TableHead>
                <TableHead className="text-right">Remaining Balance</TableHead>
                <TableHead>Due Date</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="w-[100px]">Actions</TableHead>
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
                        View
                      </Button>
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </div>
      )}

      <Dialog open={isCreateDialogOpen} onOpenChange={setIsCreateDialogOpen}>
        <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Create Debt</DialogTitle>
            <DialogDescription>
              Add a new debt with payment schedule.
            </DialogDescription>
          </DialogHeader>
          <DebtForm
            onSubmit={handleCreateDebt}
            onCancel={() => setIsCreateDialogOpen(false)}
            isLoading={createMutation.isPending}
          />
        </DialogContent>
      </Dialog>

      <Dialog open={!!selectedDebt} onOpenChange={() => setSelectedDebt(null)}>
        <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Debt Details</DialogTitle>
            <DialogDescription>
              {selectedDebt?.counterparty} - {selectedDebt?.debt_type}
            </DialogDescription>
          </DialogHeader>
          {selectedDebt && (
            <div className="space-y-6">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <div className="text-sm text-neutral-500">Principal Amount</div>
                  <div className="text-lg font-semibold">
                    {formatCurrency(selectedDebt.principal_amount, selectedDebt.currency_code)}
                  </div>
                </div>
                <div>
                  <div className="text-sm text-neutral-500">Remaining Balance</div>
                  <div className="text-lg font-semibold">
                    {formatCurrency(selectedDebt.remaining_balance, selectedDebt.currency_code)}
                  </div>
                </div>
                <div>
                  <div className="text-sm text-neutral-500">Interest Rate</div>
                  <div className="text-lg font-semibold">{selectedDebt.interest_rate}% per year</div>
                </div>
                <div>
                  <div className="text-sm text-neutral-500">Due Date</div>
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
                <h3 className="text-lg font-semibold mb-3">Payment Schedule</h3>
                <div className="border rounded-lg max-h-[400px] overflow-y-auto">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Payment Date</TableHead>
                        <TableHead className="text-right">Principal</TableHead>
                        <TableHead className="text-right">Interest</TableHead>
                        <TableHead className="text-right">Total</TableHead>
                        <TableHead>Status</TableHead>
                        <TableHead className="w-[120px]">Actions</TableHead>
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
                              {payment.paid ? 'Paid' : 'Unpaid'}
                            </Badge>
                          </TableCell>
                          <TableCell>
                            {!payment.paid && (
                              <Button
                                size="sm"
                                variant="outline"
                                onClick={() => setPaymentToRecord({ debt: selectedDebt, payment })}
                              >
                                Record
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
            <DialogTitle>Record Payment</DialogTitle>
            <DialogDescription>
              Confirm payment for {paymentToRecord?.debt.counterparty}
            </DialogDescription>
          </DialogHeader>
          {paymentToRecord && (
            <div className="space-y-4">
              <div>
                <div className="text-sm text-neutral-500">Payment Date</div>
                <div className="text-lg font-semibold">
                  {new Date(paymentToRecord.payment.payment_date).toLocaleDateString('en-US', {
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric',
                  })}
                </div>
              </div>
              <div>
                <div className="text-sm text-neutral-500">Amount</div>
                <div className="text-lg font-semibold">
                  {formatCurrency(paymentToRecord.payment.total_amount, paymentToRecord.payment.currency_code)}
                </div>
              </div>
              <div className="flex justify-end gap-2 pt-4">
                <Button variant="outline" onClick={() => setPaymentToRecord(null)}>
                  Cancel
                </Button>
                <Button
                  onClick={handleRecordPayment}
                  disabled={recordPaymentMutation.isPending}
                >
                  {recordPaymentMutation.isPending ? 'Recording...' : 'Confirm Payment'}
                </Button>
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
