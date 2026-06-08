import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from '@tanstack/react-router';
import { AlertCircle, ArrowDown, ArrowUp, Banknote, Calendar, Copy, Eye, Pencil, Search, Trash2 } from 'lucide-react';
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
import { formatCurrency as formatCurrencyUtil } from '../lib/currency';
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
  type UpdateDebtDto,
} from '../lib/tauri/debt';
import { listAccountsWithBalances, type AccountDto } from '../lib/tauri/account';
import { PageShell } from '@/components/patterns/layout/PageShell';
import { PageHeader } from '@/components/patterns/layout/PageHeader';
import { StatCard } from '@/components/patterns/cards/StatCard';
import { FilterBar } from '@/components/patterns/layout/FilterBar';

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
  return formatCurrencyUtil(num, currencyCode);
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
  const navigate = useNavigate();
  const [isSheetOpen, setIsSheetOpen] = useState(false);
  const [editingDebt, setEditingDebt] = useState<DebtDto | null>(null);
  const [deletingDebt, setDeletingDebt] = useState<DebtDto | null>(null);
  const [copyingDebt, setCopyingDebt] = useState<DebtDto | null>(null);
  const [paymentToRecord, setPaymentToRecord] = useState<{
    debt: DebtDto;
    payment: PaymentScheduleDto;
  } | null>(null);
  const [paymentSourceId, setPaymentSourceId] = useState<string>('');
  const [paymentDate, setPaymentDate] = useState<string>(new Date().toISOString().split('T')[0]);
  const [paymentAmount, setPaymentAmount] = useState<string>('');
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
    queryFn: listAccountsWithBalances,
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
      toast.error(t('common.errorGeneric'));
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
      setPaymentSourceId(''); setPaymentDate(new Date().toISOString().split('T')[0]); setPaymentAmount('');
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
      payment_amount: paymentAmount || null,
      payment_date: paymentDate || null,
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
    <PageShell>
      <PageHeader
        title={t('debts.title')}
        actions={
          <Button onClick={() => { setIsSheetOpen(true); setCopyingDebt(null); }}>
            {t('debts.createDebt')}
          </Button>
        }
      />

      {/* Summary StatCards */}
      <div className="grid grid-cols-3 gap-3.5 mb-7">
        <StatCard label={t('debts.totalDebts')} value={String(debts.filter(d => parseFloat(d.remaining_principal) > 0).length)} />
        <StatCard label={t('debts.totalRemaining')} value={formatCurrency(
          debts.reduce((sum, d) => sum + parseFloat(d.remaining_principal), 0).toString(), 'CNY'
        )} tagVariant="negative" />
        <StatCard label={t('debts.overdueCount')} value={String(overdueDebts.length)}
          tag={overdueDebts.length > 0 ? t('debts.needsAttention') : undefined}
          tagVariant={overdueDebts.length > 0 ? 'negative' : 'positive'} />
      </div>

      {overdueDebts.length > 0 && (
        <div className="mb-4 p-4 bg-expense/5 border border-expense/20 rounded-[14px]">
          <div className="flex items-center gap-2 mb-3">
            <AlertCircle className="h-5 w-5 text-expense" />
            <h2 className="text-lg font-semibold text-expense">{t('debts.overdueDebts')}</h2>
          </div>
          <div className="space-y-2">
            {overdueDebts.map((debt) => (
              <div key={debt.account_id} className="flex items-center justify-between p-3 bg-card rounded-lg border border-expense/20">
                <div>
                  <div className="font-medium text-expense">{debt.account_name} ({debt.counterparty})</div>
                  <div className="text-sm text-muted-foreground">
                    {t('debts.due')}: {new Date(debt.due_date).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })}
                  </div>
                </div>
                <div className="text-right">
                  <div className="font-semibold text-expense">{formatCurrency(debt.remaining_principal, debt.currency_code)}</div>
                  <div className="text-sm text-muted-foreground">{debtTypeLabel(debt.account_type, t)}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {upcomingPayments.length > 0 && (
        <div className="mb-4 p-4 bg-primary/5 border border-primary/20 rounded-[14px]">
          <div className="flex items-center gap-2 mb-3">
            <Calendar className="h-5 w-5 text-primary" />
            <h2 className="text-lg font-semibold text-primary">{t('debts.upcomingPayments')}</h2>
          </div>
          <div className="space-y-2">
            {upcomingPayments.map((item, i) => (
              <div key={`${item.debt.account_id}-${i}`} className="flex items-center justify-between p-3 bg-card rounded-lg border border-primary/20">
                <div>
                  <div className="font-medium text-primary">{item.debt.account_name} ({item.debt.counterparty})</div>
                  <div className="text-sm text-muted-foreground">
                    {t('debts.paymentDate')}: {new Date(item.payment.payment_date).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })}
                  </div>
                </div>
                <div className="text-right">
                  <div className="font-semibold text-primary">{formatCurrency(item.payment.total_amount, item.debt.currency_code)}</div>
                  <Button size="sm" variant="outline" onClick={() => { setPaymentToRecord({ debt: item.debt, payment: item.payment }); setPaymentSourceId(''); setPaymentDate(new Date().toISOString().split('T')[0]); setPaymentAmount(item.payment.total_amount); }} className="mt-1">
                    {t('debts.recordPayment')}
                  </Button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Filter bars */}
      <div className="flex flex-wrap items-center gap-3 mb-6">
        <FilterBar
          options={typeFilterButtons.map(b => ({ label: b.label, value: b.value }))}
          value={typeFilter}
          onChange={(v) => setTypeFilter(v as TypeFilter)}
        />
        <FilterBar
          options={statusFilterButtons.map(b => ({ label: b.label, value: b.value }))}
          value={statusFilter}
          onChange={(v) => setStatusFilter(v as StatusFilter)}
        />
        <div className="relative ml-auto">
          <Search className="absolute left-2 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground" />
          <Input placeholder={t('debts.searchDebts')} value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="h-8 pl-7 w-48 text-xs" />
        </div>
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <div className="text-muted-foreground">{t('debts.loadingDebts')}</div>
        </div>
      ) : filteredAndSortedDebts.length === 0 && debts.length > 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <p className="text-muted-foreground">{t('debts.noResults')}</p>
        </div>
      ) : debts.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <p className="text-muted-foreground mb-4">{t('debts.noDebts')}</p>
          <Button onClick={() => { setIsSheetOpen(true); setCopyingDebt(null); }}>{t('debts.createFirstDebt')}</Button>
        </div>
      ) : (
        <div className="rounded-[14px] border border-border bg-card overflow-hidden">
          <Table>
            <TableHeader>
              <TableRow className="bg-muted/50">
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
                  <TableRow
                    key={debt.account_id}
                    className="cursor-pointer hover:bg-muted/30"
                    onClick={() => navigate({ to: '/debts/$debtId', params: { debtId: debt.account_id } })}
                  >
                    <TableCell className="font-medium">{debt.account_name}</TableCell>
                    <TableCell>{debtTypeLabel(debt.account_type, t)}</TableCell>
                    <TableCell>{debt.counterparty}</TableCell>
                    <TableCell className="text-right">{formatCurrency(debt.principal_amount, debt.currency_code)}</TableCell>
                    <TableCell className="text-right">{formatCurrency(debt.remaining_principal, debt.currency_code)}</TableCell>
                    <TableCell>{new Date(debt.due_date).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })}</TableCell>
                    <TableCell><Badge variant={status.variant}>{status.label}</Badge></TableCell>
                    <TableCell>
                      <div className="flex gap-1">
                        {debt.payment_schedule.some(p => !p.paid) && (
                          <Button variant="ghost" size="icon-sm" onClick={(e) => {
                            e.stopPropagation();
                            const firstUnpaid = debt.payment_schedule.find(p => !p.paid);
                            if (firstUnpaid) { setPaymentToRecord({ debt, payment: firstUnpaid }); setPaymentSourceId(''); setPaymentDate(new Date().toISOString().split('T')[0]); setPaymentAmount(firstUnpaid.total_amount); }
                          }} title={t('debts.recordPayment')}>
                            <Banknote className="h-3.5 w-3.5 text-emerald-600" />
                          </Button>
                        )}
                        <Button variant="ghost" size="icon-sm"
                          onClick={(e) => { e.stopPropagation(); navigate({ to: '/debts/$debtId', params: { debtId: debt.account_id } }); }}
                          title={t('debts.view')}>
                          <Eye className="h-3.5 w-3.5" />
                        </Button>
                        <Button variant="ghost" size="icon-sm" onClick={(e) => { e.stopPropagation(); setEditingDebt(debt); }} title={t('debts.editDebt')}>
                          <Pencil className="h-3.5 w-3.5" />
                        </Button>
                        <Button variant="ghost" size="icon-sm" onClick={(e) => { e.stopPropagation(); setCopyingDebt(debt); setIsSheetOpen(true); }} title={t('debts.copyDebt')}>
                          <Copy className="h-3.5 w-3.5" />
                        </Button>
                        <Button variant="ghost" size="icon-sm" onClick={(e) => { e.stopPropagation(); setDeletingDebt(debt); }} title={t('debts.deleteDebt')}>
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

      {/* Create Sheet (also used for copy) */}
      <Sheet open={isSheetOpen && !editingDebt} onOpenChange={(open) => { setIsSheetOpen(open); if (!open) setCopyingDebt(null); }}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{copyingDebt ? t('debts.copyDebt') : t('debts.createDebt')}</SheetTitle>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto -mx-4 px-4">
            <DebtForm
              key={copyingDebt?.account_id || 'create'}
              onSubmit={handleCreateDebt}
              onCancel={() => { setIsSheetOpen(false); setCopyingDebt(null); }}
              isLoading={createMutation.isPending}
              initialData={copyingDebt}
            />
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
                onSubmit={handleUpdateDebt as (data: CreateDebtDto) => void}
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

      {/* Record Payment Sheet */}
      <Sheet open={!!paymentToRecord} onOpenChange={() => setPaymentToRecord(null)}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{t('debts.recordPayment')}</SheetTitle>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto -mx-4 px-4">
            {paymentToRecord && (() => {
              const isBorrowedOut = paymentToRecord.debt.account_type === 'BorrowedOut';
              const payLabel = isBorrowedOut ? t('debts.receiveToAccount') : t('debts.payFromAccount');
              const payPlaceholder = isBorrowedOut ? t('debts.selectReceiveAccount') : t('debts.selectPayAccount');
              return (
              <div className="space-y-4 px-5 pt-4">
                <div className="rounded-xl border bg-card p-4 space-y-3">
                  <div className="flex justify-between">
                    <span className="text-xs uppercase tracking-wider text-muted-foreground">{t('debts.counterparty')}</span>
                    <span className="text-sm font-medium">{paymentToRecord.debt.counterparty}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-xs uppercase tracking-wider text-muted-foreground">{t('debts.scheduledDate')}</span>
                    <span className="text-sm font-medium">{new Date(paymentToRecord.payment.payment_date).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-xs uppercase tracking-wider text-muted-foreground">{t('debts.scheduledAmount')}</span>
                    <span className="text-sm font-medium">{formatCurrency(paymentToRecord.payment.total_amount, paymentToRecord.debt.currency_code)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-xs uppercase tracking-wider text-muted-foreground">{t('debts.remainingBalance')}</span>
                    <span className="text-sm font-medium">{formatCurrency(paymentToRecord.debt.remaining_principal, paymentToRecord.debt.currency_code)}</span>
                  </div>
                  <div className="text-xs text-muted-foreground bg-muted/50 rounded-lg p-2">
                    {isBorrowedOut ? t('debts.borrowedOutPaymentHint') : t('debts.borrowedInPaymentHint')}
                  </div>
                </div>

                <div className="space-y-1.5">
                  <span className="text-xs uppercase tracking-wider text-muted-foreground">{t('debts.actualPaymentDate')}</span>
                  <Input type="date" value={paymentDate} onChange={(e) => setPaymentDate(e.target.value)} className="h-9" />
                </div>

                <div className="space-y-1.5">
                  <span className="text-xs uppercase tracking-wider text-muted-foreground">{t('debts.actualPaymentAmount')}</span>
                  <Input type="number" value={paymentAmount} onChange={(e) => setPaymentAmount(e.target.value)} className="h-9" />
                </div>

                <div className="space-y-1.5">
                  <span className="text-xs uppercase tracking-wider text-muted-foreground">{payLabel} <span className="text-red-500">*</span></span>
                  <Select value={paymentSourceId} onValueChange={(v) => v && setPaymentSourceId(v)}>
                    <SelectTrigger className="h-9">
                      <SelectValue placeholder={payPlaceholder}>
                        {paymentSourceId ? (ownPaymentAccounts.find(a => a.id === paymentSourceId)?.name || '') : null}
                      </SelectValue>
                    </SelectTrigger>
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
              );
            })()}
          </div>
        </SheetContent>
      </Sheet>
    </PageShell>
  );
}
