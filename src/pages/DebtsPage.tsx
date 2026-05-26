import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { AlertCircle, ArrowDown, ArrowUp, Calendar, Pencil, Search, Trash2 } from 'lucide-react';
import { useMemo, useState } from 'react';
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
import { Input } from '../components/ui/input';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from '../components/ui/sheet';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../components/ui/select';
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
  deleteDebt,
  getUpcomingPayments,
  listDebts,
  recordPayment,
  updateDebt,
  type CreateDebtDto,
  type DebtDto,
  type PaymentScheduleDto,
  type RecordPaymentDto,
  type UpdateDebtDto,
} from '../lib/tauri/debt';
import { listAccounts, type AccountDto } from '../lib/tauri/account';

type SortColumn = 'name' | 'type' | 'counterparty' | 'principal' | 'remaining' | 'dueDate' | 'status';
type TypeFilter = 'all' | 'BorrowedIn' | 'BorrowedOut' | 'CreditCard';
type StatusFilter = 'all' | 'active' | 'overdue' | 'paidOff';

function debtTypeLabel(type: string, t: (key: string) => string): string {
  const map: Record<string, string> = {
    BorrowedIn: t('debtForm.borrowedIn'),
    BorrowedOut: t('debtForm.borrowedOut'),
    CreditCard: t('debtForm.creditCard'),
  };
  return map[type] || type;
}

function formatCurrency(amount: string, currencyCode: string) {
  const num = parseFloat(amount);
  const formatted = num.toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  const symbols: Record<string, string> = { CNY: '¥', USD: '$', EUR: '€' };
  return `${symbols[currencyCode] || currencyCode} ${formatted}`;
}

function getDebtStatus(debt: DebtDto, t: (key: string) => string) {
  const remaining = parseFloat(debt.remaining_principal);
  const today = new Date();
  const dueDate = new Date(debt.due_date);
  if (remaining === 0) {
    return { label: t('debts.paidOff'), variant: 'secondary' as const, key: 'paidOff' as const };
  }
  if (dueDate < today) {
    return { label: t('debts.overdue'), variant: 'destructive' as const, key: 'overdue' as const };
  }
  return { label: t('debts.active'), variant: 'default' as const, key: 'active' as const };
}

export function DebtsPage() {
  const { t } = useTranslation();
  const [isSheetOpen, setIsSheetOpen] = useState(false);
  const [editingDebt, setEditingDebt] = useState<DebtDto | null>(null);
  const [selectedDebt, setSelectedDebt] = useState<DebtDto | null>(null);
  const [deletingDebt, setDeletingDebt] = useState<DebtDto | null>(null);
  const [paymentToRecord, setPaymentToRecord] = useState<{
    debt: DebtDto;
    payment: PaymentScheduleDto;
  } | null>(null);
  const [paymentSourceId, setPaymentSourceId] = useState<string>('');
  const [sortColumn, setSortColumn] = useState<SortColumn>('dueDate');
  const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('asc');
  const [typeFilter, setTypeFilter] = useState<TypeFilter>('all');
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const queryClient = useQueryClient();

  const { data: debts = [], isLoading } = useQuery({
    queryKey: ['debts'],
    queryFn: listDebts,
  });

  const { data: accounts = [] } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
  });

  const ownPaymentAccounts = accounts.filter(
    (a: AccountDto) =>
      a.ownership === 'own' &&
      (a.account_type === 'Cash' || a.account_type === 'Bank')
  );

  const { data: upcomingDebts = [] } = useQuery({
    queryKey: ['upcoming-payments'],
    queryFn: () => getUpcomingPayments(7),
  });

  const createMutation = useMutation({
    mutationFn: createDebt,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['debts'] });
      queryClient.invalidateQueries({ queryKey: ['upcoming-payments'] });
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      setIsSheetOpen(false);
      toast.success(t('debts.debtCreated'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, dto }: { id: string; dto: UpdateDebtDto }) => updateDebt(id, dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['debts'] });
      setEditingDebt(null);
      toast.success(t('debts.debtUpdated'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });

  const deleteMutation = useMutation({
    mutationFn: deleteDebt,
    onMutate: async (accountId) => {
      await queryClient.cancelQueries({ queryKey: ['debts'] });
      const prev = queryClient.getQueryData<DebtDto[]>(['debts']);
      queryClient.setQueryData<DebtDto[]>(['debts'], (old) =>
        (old || []).filter((d) => d.account_id !== accountId)
      );
      return { prev };
    },
    onError: (_err, _id, ctx) => {
      if (ctx?.prev) queryClient.setQueryData(['debts'], ctx.prev);
      toast.error(t('common.error'));
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['debts'] });
      setDeletingDebt(null);
    },
    onSuccess: () => {
      toast.success(t('debts.debtDeleted'));
    },
  });

  const recordPaymentMutation = useMutation({
    mutationFn: recordPayment,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['debts'] });
      queryClient.invalidateQueries({ queryKey: ['upcoming-payments'] });
      setPaymentToRecord(null);
      setSelectedDebt(null);
      setPaymentSourceId('');
      toast.success(t('debts.paymentRecorded'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });

  const handleCreateDebt = (data: CreateDebtDto) => {
    createMutation.mutate(data);
  };

  const handleUpdateDebt = (data: CreateDebtDto) => {
    if (!editingDebt) return;
    updateMutation.mutate({
      id: editingDebt.account_id,
      dto: {
        counterparty: data.counterparty,
        interest_rate: data.interest_rate,
        start_date: data.start_date || editingDebt.start_date,
        due_date: data.due_date || editingDebt.due_date,
        amortization_method: data.amortization_method || editingDebt.amortization_method,
      },
    });
  };

  const handleRecordPayment = () => {
    if (!paymentToRecord || !paymentSourceId) return;
    recordPaymentMutation.mutate({
      schedule_entry_id: paymentToRecord.payment.id,
      payment_source_account_id: paymentSourceId,
      interest_account_id: null,
    });
  };

  const toggleSort = (col: SortColumn) => {
    if (sortColumn === col) {
      setSortDirection((d) => (d === 'asc' ? 'desc' : 'asc'));
    } else {
      setSortColumn(col);
      setSortDirection(col === 'principal' || col === 'remaining' ? 'desc' : 'asc');
    }
  };

  const sortIcon = (col: SortColumn) => {
    if (sortColumn !== col) return null;
    return sortDirection === 'asc'
      ? <ArrowUp className="inline ml-1 h-3 w-3" />
      : <ArrowDown className="inline ml-1 h-3 w-3" />;
  };

  const filteredAndSortedDebts = useMemo(() => {
    let result = debts;

    if (typeFilter !== 'all') {
      result = result.filter((d) => d.account_type === typeFilter);
    }
    if (statusFilter !== 'all') {
      result = result.filter((d) => getDebtStatus(d, t).key === statusFilter);
    }
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      result = result.filter(
        (d) =>
          d.account_name.toLowerCase().includes(q) ||
          d.counterparty.toLowerCase().includes(q)
      );
    }

    return [...result].sort((a, b) => {
      let cmp = 0;
      switch (sortColumn) {
        case 'name': cmp = a.account_name.localeCompare(b.account_name); break;
        case 'type': cmp = a.account_type.localeCompare(b.account_type); break;
        case 'counterparty': cmp = a.counterparty.localeCompare(b.counterparty); break;
        case 'principal': cmp = parseFloat(a.principal_amount) - parseFloat(b.principal_amount); break;
        case 'remaining': cmp = parseFloat(a.remaining_principal) - parseFloat(b.remaining_principal); break;
        case 'dueDate': cmp = new Date(a.due_date).getTime() - new Date(b.due_date).getTime(); break;
        case 'status': cmp = getDebtStatus(a, t).key.localeCompare(getDebtStatus(b, t).key); break;
      }
      return sortDirection === 'asc' ? cmp : -cmp;
    });
  }, [debts, typeFilter, statusFilter, searchQuery, sortColumn, sortDirection, t]);

  const overdueDebts = debts.filter((debt) => {
    return parseFloat(debt.remaining_principal) > 0 && new Date(debt.due_date) < new Date();
  });

  const upcomingPayments = upcomingDebts
    .flatMap((debt) =>
      debt.payment_schedule
        .filter((p) => !p.paid)
        .map((p) => ({ debt, payment: p }))
    )
    .slice(0, 10);

  const typeFilterButtons: { value: TypeFilter; label: string }[] = [
    { value: 'all', label: t('common.all') },
    { value: 'BorrowedIn', label: t('debtForm.borrowedIn') },
    { value: 'BorrowedOut', label: t('debtForm.borrowedOut') },
    { value: 'CreditCard', label: t('debtForm.creditCard') },
  ];

  const statusFilterButtons: { value: StatusFilter; label: string }[] = [
    { value: 'all', label: t('debts.allStatus') },
    { value: 'active', label: t('debts.active') },
    { value: 'overdue', label: t('debts.overdue') },
    { value: 'paidOff', label: t('debts.paidOff') },
  ];

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">{t('debts.title')}</h1>
        <Button variant="default-gradient" onClick={() => setIsSheetOpen(true)}>
          {t('debts.createDebt')}
        </Button>
      </div>

      {overdueDebts.length > 0 && (
        <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg">
          <div className="flex items-center gap-2 mb-3">
            <AlertCircle className="h-5 w-5 text-red-600" />
            <h2 className="text-lg font-semibold text-red-900">{t('debts.overdueDebts')}</h2>
          </div>
          <div className="space-y-2">
            {overdueDebts.map((debt) => (
              <div key={debt.account_id} className="flex items-center justify-between p-3 bg-white rounded border border-red-200">
                <div>
                  <div className="font-medium text-red-900">{debt.account_name} ({debt.counterparty})</div>
                  <div className="text-sm text-red-700">
                    {t('debts.due')}: {new Date(debt.due_date).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })}
                  </div>
                </div>
                <div className="text-right">
                  <div className="font-semibold text-red-900">{formatCurrency(debt.remaining_principal, debt.currency_code)}</div>
                  <div className="text-sm text-red-700">{debtTypeLabel(debt.account_type, t)}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {upcomingPayments.length > 0 && (
        <div className="mb-4 p-4 bg-blue-50 border border-blue-200 rounded-lg">
          <div className="flex items-center gap-2 mb-3">
            <Calendar className="h-5 w-5 text-blue-600" />
            <h2 className="text-lg font-semibold text-blue-900">{t('debts.upcomingPayments')}</h2>
          </div>
          <div className="space-y-2">
            {upcomingPayments.map((item, i) => (
              <div key={`${item.debt.account_id}-${i}`} className="flex items-center justify-between p-3 bg-white rounded border border-blue-200">
                <div>
                  <div className="font-medium text-blue-900">{item.debt.account_name} ({item.debt.counterparty})</div>
                  <div className="text-sm text-blue-700">
                    {t('debts.paymentDate')}: {new Date(item.payment.payment_date).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })}
                  </div>
                </div>
                <div className="text-right">
                  <div className="font-semibold text-blue-900">{formatCurrency(item.payment.total_amount, item.debt.currency_code)}</div>
                  <Button size="sm" variant="outline" onClick={() => { setPaymentToRecord({ debt: item.debt, payment: item.payment }); setPaymentSourceId(''); }} className="mt-1">
                    {t('debts.recordPayment')}
                  </Button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Filter bar */}
      <div className="flex flex-wrap items-center gap-2 mb-4">
        <div className="flex gap-1">
          {typeFilterButtons.map((btn) => (
            <Button
              key={btn.value}
              size="sm"
              variant={typeFilter === btn.value ? 'default' : 'outline'}
              onClick={() => setTypeFilter(btn.value)}
              className="h-7 text-xs"
            >
              {btn.label}
            </Button>
          ))}
        </div>
        <div className="flex gap-1 ml-2">
          {statusFilterButtons.map((btn) => (
            <Button
              key={btn.value}
              size="sm"
              variant={statusFilter === btn.value ? 'default' : 'outline'}
              onClick={() => setStatusFilter(btn.value)}
              className="h-7 text-xs"
            >
              {btn.label}
            </Button>
          ))}
        </div>
        <div className="relative ml-auto">
          <Search className="absolute left-2 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground" />
          <Input
            placeholder={t('debts.searchDebts')}
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="h-7 pl-7 w-48 text-xs"
          />
        </div>
        <span className="text-xs text-muted-foreground ml-2">
          {filteredAndSortedDebts.length} {t('debts.results')}
        </span>
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <div className="text-neutral-500">{t('debts.loadingDebts')}</div>
        </div>
      ) : filteredAndSortedDebts.length === 0 && debts.length > 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <p className="text-neutral-500">{t('debts.noResults')}</p>
        </div>
      ) : debts.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <p className="text-neutral-500 mb-4">{t('debts.noDebts')}</p>
          <Button onClick={() => setIsSheetOpen(true)}>{t('debts.createFirstDebt')}</Button>
        </div>
      ) : (
        <div className="border rounded-lg">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="cursor-pointer select-none" onClick={() => toggleSort('name')}>
                  {t('debts.name')} {sortIcon('name')}
                </TableHead>
                <TableHead className="cursor-pointer select-none" onClick={() => toggleSort('type')}>
                  {t('debtForm.type')} {sortIcon('type')}
                </TableHead>
                <TableHead className="cursor-pointer select-none" onClick={() => toggleSort('counterparty')}>
                  {t('debts.counterparty')} {sortIcon('counterparty')}
                </TableHead>
                <TableHead className="text-right cursor-pointer select-none" onClick={() => toggleSort('principal')}>
                  {t('debts.principal')} {sortIcon('principal')}
                </TableHead>
                <TableHead className="text-right cursor-pointer select-none" onClick={() => toggleSort('remaining')}>
                  {t('debts.remainingBalance')} {sortIcon('remaining')}
                </TableHead>
                <TableHead className="cursor-pointer select-none" onClick={() => toggleSort('dueDate')}>
                  {t('debts.dueDate')} {sortIcon('dueDate')}
                </TableHead>
                <TableHead className="cursor-pointer select-none" onClick={() => toggleSort('status')}>
                  {t('debts.status')} {sortIcon('status')}
                </TableHead>
                <TableHead className="w-[120px]">{t('common.actions')}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filteredAndSortedDebts.map((debt) => {
                const status = getDebtStatus(debt, t);
                return (
                  <TableRow key={debt.account_id}>
                    <TableCell className="font-medium">{debt.account_name}</TableCell>
                    <TableCell>{debtTypeLabel(debt.account_type, t)}</TableCell>
                    <TableCell>{debt.counterparty}</TableCell>
                    <TableCell className="text-right">{formatCurrency(debt.principal_amount, debt.currency_code)}</TableCell>
                    <TableCell className="text-right">{formatCurrency(debt.remaining_principal, debt.currency_code)}</TableCell>
                    <TableCell>{new Date(debt.due_date).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })}</TableCell>
                    <TableCell><Badge variant={status.variant}>{status.label}</Badge></TableCell>
                    <TableCell>
                      <div className="flex gap-1">
                        <Button variant="ghost" size="icon-sm" onClick={() => setSelectedDebt(debt)} title={t('debts.view')}>
                          <Calendar className="h-3.5 w-3.5" />
                        </Button>
                        <Button variant="ghost" size="icon-sm" onClick={() => setEditingDebt(debt)} title={t('debts.editDebt')}>
                          <Pencil className="h-3.5 w-3.5" />
                        </Button>
                        <Button variant="ghost" size="icon-sm" onClick={() => setDeletingDebt(debt)} title={t('debts.deleteDebt')}>
                          <Trash2 className="h-3.5 w-3.5 text-destructive" />
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </div>
      )}

      {/* Create Sheet */}
      <Sheet open={isSheetOpen} onOpenChange={setIsSheetOpen}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{t('debts.createDebt')}</SheetTitle>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto -mx-4 px-4">
            <DebtForm onSubmit={handleCreateDebt} onCancel={() => setIsSheetOpen(false)} isLoading={createMutation.isPending} />
          </div>
        </SheetContent>
      </Sheet>

      {/* Edit Sheet */}
      <Sheet open={!!editingDebt} onOpenChange={() => setEditingDebt(null)}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{t('debts.editDebt')}</SheetTitle>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto -mx-4 px-4">
            {editingDebt && (
              <DebtForm
                onSubmit={handleUpdateDebt as any}
                onCancel={() => setEditingDebt(null)}
                isLoading={updateMutation.isPending}
                initialData={editingDebt}
                mode="edit"
              />
            )}
          </div>
        </SheetContent>
      </Sheet>

      {/* Delete Confirmation */}
      <Dialog open={!!deletingDebt} onOpenChange={() => setDeletingDebt(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('debts.deleteDebt')}</DialogTitle>
            <DialogDescription>
              {t('debts.deleteConfirm', { name: deletingDebt?.account_name || '' })}
            </DialogDescription>
          </DialogHeader>
          <div className="flex justify-end gap-2 pt-4">
            <Button variant="outline" onClick={() => setDeletingDebt(null)}>{t('common.cancel')}</Button>
            <Button variant="destructive" onClick={() => deletingDebt && deleteMutation.mutate(deletingDebt.account_id)} disabled={deleteMutation.isPending}>
              {deleteMutation.isPending ? t('debts.deleting') : t('debts.confirmDelete')}
            </Button>
          </div>
        </DialogContent>
      </Dialog>

      {/* View Details Dialog */}
      <Dialog open={!!selectedDebt} onOpenChange={() => setSelectedDebt(null)}>
        <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>{t('debts.debtDetails')}</DialogTitle>
            <DialogDescription>{selectedDebt?.account_name} ({selectedDebt?.counterparty})</DialogDescription>
          </DialogHeader>
          {selectedDebt && (
            <div className="space-y-6">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <div className="text-sm text-neutral-500">{t('debts.principalAmount')}</div>
                  <div className="text-lg font-semibold">{formatCurrency(selectedDebt.principal_amount, selectedDebt.currency_code)}</div>
                </div>
                <div>
                  <div className="text-sm text-neutral-500">{t('debts.remainingBalance')}</div>
                  <div className="text-lg font-semibold">{formatCurrency(selectedDebt.remaining_principal, selectedDebt.currency_code)}</div>
                </div>
                <div>
                  <div className="text-sm text-neutral-500">{t('debts.interestRate')}</div>
                  <div className="text-lg font-semibold">{selectedDebt.interest_rate}% {t('debts.perYear')}</div>
                </div>
                <div>
                  <div className="text-sm text-neutral-500">{t('debts.dueDate')}</div>
                  <div className="text-lg font-semibold">{new Date(selectedDebt.due_date).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })}</div>
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
                      {selectedDebt.payment_schedule.map((payment) => (
                        <TableRow key={payment.id}>
                          <TableCell>{new Date(payment.payment_date).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })}</TableCell>
                          <TableCell className="text-right">{formatCurrency(payment.principal_amount, selectedDebt.currency_code)}</TableCell>
                          <TableCell className="text-right">{formatCurrency(payment.interest_amount, selectedDebt.currency_code)}</TableCell>
                          <TableCell className="text-right font-medium">{formatCurrency(payment.total_amount, selectedDebt.currency_code)}</TableCell>
                          <TableCell><Badge variant={payment.paid ? 'secondary' : 'outline'}>{payment.paid ? t('debts.paid') : t('debts.unpaid')}</Badge></TableCell>
                          <TableCell>
                            {!payment.paid && (
                              <Button size="sm" variant="outline" onClick={() => { setPaymentToRecord({ debt: selectedDebt, payment }); setPaymentSourceId(''); }}>
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

      {/* Record Payment Dialog */}
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
                <div className="text-lg font-semibold">{new Date(paymentToRecord.payment.payment_date).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })}</div>
              </div>
              <div>
                <div className="text-sm text-neutral-500">{t('debts.amount')}</div>
                <div className="text-lg font-semibold">{formatCurrency(paymentToRecord.payment.total_amount, paymentToRecord.debt.currency_code)}</div>
              </div>
              <div>
                <div className="text-sm text-neutral-500 mb-1">{t('debts.paymentSource')}</div>
                <Select value={paymentSourceId} onValueChange={(v) => v && setPaymentSourceId(v)}>
                  <SelectTrigger className="h-9"><SelectValue placeholder={t('debts.selectPaymentSource')} /></SelectTrigger>
                  <SelectContent>
                    {ownPaymentAccounts.map((acc) => (<SelectItem key={acc.id} value={acc.id}>{acc.name} ({acc.account_type})</SelectItem>))}
                  </SelectContent>
                </Select>
              </div>
              <div className="flex justify-end gap-2 pt-4">
                <Button variant="outline" onClick={() => setPaymentToRecord(null)}>{t('common.cancel')}</Button>
                <Button onClick={handleRecordPayment} disabled={recordPaymentMutation.isPending || !paymentSourceId}>
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
