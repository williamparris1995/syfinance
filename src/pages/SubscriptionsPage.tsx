import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import React, { useState, useMemo } from 'react';
import { toast } from 'sonner';
import {
  ArrowUpDown,
  Plus,
  ChevronRight,
  ChevronDown,
  Pencil,
  Trash2,
  Pause,
  Play,
  CalendarCheck,
  Receipt,
  Users,
} from 'lucide-react';
import { Button } from '../components/ui/button';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from '../components/ui/sheet';
import { Badge } from '../components/ui/badge';
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
import { Input } from '../components/ui/input';
import { SubscriptionForm } from '../components/SubscriptionForm';
import { getUserFriendlyError } from '../lib/error-handler';
import { formatCurrency, getCurrencySymbol } from '../lib/currency';
import {
  createSubscription,
  listSubscriptions,
  updateSubscription,
  deleteSubscription,
  pauseSubscription,
  resumeSubscription,
  listSubscriptionTransactions,
  type SubscriptionDto,
  type CreateSubscriptionDto,
  type UpdateSubscriptionDto,
  type SubscriptionFilters,
} from '../lib/tauri/subscription';

type SortKey = 'next_billing_date' | 'amount' | 'name';
type SortDir = 'asc' | 'desc';

function getDaysUntil(dateStr: string): number {
  const now = new Date();
  now.setHours(0, 0, 0, 0);
  const target = new Date(dateStr);
  target.setHours(0, 0, 0, 0);
  return Math.ceil((target.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
}

function formatDaysUntil(days: number): string {
  if (days < 0) return `${Math.abs(days)}d overdue`;
  if (days === 0) return 'Today';
  if (days === 1) return 'Tomorrow';
  return `${days}d`;
}

export function SubscriptionsPage() {
  const { t } = useTranslation();
  const queryClient = useQueryClient();

  // Sheet state
  const [showSheet, setShowSheet] = useState(false);
  const [editingSubscription, setEditingSubscription] =
    useState<SubscriptionDto | null>(null);

  // Table state
  const [sortKey, setSortKey] = useState<SortKey>('next_billing_date');
  const [sortDir, setSortDir] = useState<SortDir>('asc');
  const [filterCycle, setFilterCycle] = useState<string>('all');
  const [filterDirection, setFilterDirection] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);

  // Build filters for API
  const filters: SubscriptionFilters = useMemo(() => {
    const f: SubscriptionFilters = {};
    if (filterDirection !== 'all') f.direction = filterDirection;
    if (filterCycle !== 'all') f.cycle = filterCycle;
    return f;
  }, [filterCycle, filterDirection]);

  const { data: subscriptions = [], isLoading } = useQuery({
    queryKey: ['subscriptions', filters],
    queryFn: () => listSubscriptions(filters),
  });

  // Transaction history for expanded row
  const { data: transactionHistory = [], isLoading: isLoadingTransactions } =
    useQuery({
      queryKey: ['subscription-transactions', expandedId],
      queryFn: () => listSubscriptionTransactions(expandedId!),
      enabled: !!expandedId,
    });

  // Mutations
  const createMutation = useMutation({
    mutationFn: createSubscription,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['subscriptions'] });
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      setShowSheet(false);
      setEditingSubscription(null);
      toast.success(t('subscription.createSuccess'));
    },
    onError: (error) => toast.error(getUserFriendlyError(error)),
  });

  const updateMutation = useMutation({
    mutationFn: updateSubscription,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['subscriptions'] });
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      setShowSheet(false);
      setEditingSubscription(null);
      toast.success(t('subscription.updateSuccess'));
    },
    onError: (error) => toast.error(getUserFriendlyError(error)),
  });

  const deleteMutation = useMutation({
    mutationFn: deleteSubscription,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['subscriptions'] });
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      setDeleteConfirmId(null);
      toast.success(t('subscription.deleteSuccess'));
    },
    onError: (error) => toast.error(getUserFriendlyError(error)),
  });

  const pauseMutation = useMutation({
    mutationFn: pauseSubscription,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['subscriptions'] });
      toast.success(t('subscription.pause'));
    },
    onError: (error) => toast.error(getUserFriendlyError(error)),
  });

  const resumeMutation = useMutation({
    mutationFn: resumeSubscription,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['subscriptions'] });
      toast.success(t('subscription.resume'));
    },
    onError: (error) => toast.error(getUserFriendlyError(error)),
  });

  // Handlers
  const handleNew = () => {
    setEditingSubscription(null);
    setShowSheet(true);
  };

  const handleEdit = (sub: SubscriptionDto) => {
    setEditingSubscription(sub);
    setShowSheet(true);
  };

  const handleFormSubmit = (data: CreateSubscriptionDto | UpdateSubscriptionDto) => {
    if (editingSubscription) {
      updateMutation.mutate(data as UpdateSubscriptionDto);
    } else {
      createMutation.mutate(data as CreateSubscriptionDto);
    }
  };

  const toggleSort = (key: SortKey) => {
    if (sortKey === key) {
      setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'));
    } else {
      setSortKey(key);
      setSortDir('asc');
    }
  };

  const toggleExpand = (id: string) => {
    setExpandedId((prev) => (prev === id ? null : id));
    setDeleteConfirmId(null);
  };

  // Filtered & sorted list
  const filteredSubscriptions = useMemo(() => {
    let list = [...subscriptions];
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      list = list.filter((s) => s.name.toLowerCase().includes(q));
    }
    return list;
  }, [subscriptions, searchQuery]);

  const sortedSubscriptions = useMemo(() => {
    const sorted = [...filteredSubscriptions].sort((a, b) => {
      let va: number | string, vb: number | string;
      switch (sortKey) {
        case 'name':
          return sortDir === 'asc'
            ? a.name.localeCompare(b.name)
            : b.name.localeCompare(a.name);
        case 'amount':
          va = Number(a.amount);
          vb = Number(b.amount);
          break;
        case 'next_billing_date':
          va = a.next_billing_date;
          vb = b.next_billing_date;
          if (sortDir === 'asc') return va < vb ? -1 : va > vb ? 1 : 0;
          return va > vb ? -1 : va < vb ? 1 : 0;
        default:
          return 0;
      }
      return sortDir === 'asc'
        ? (va as number) - (vb as number)
        : (vb as number) - (va as number);
    });
    return sorted;
  }, [filteredSubscriptions, sortKey, sortDir]);

  // Summary calculations
  const monthlyExpense = useMemo(
    () =>
      subscriptions
        .filter((s) => s.direction === 'expense' && !s.paused)
        .reduce((sum, s) => {
          const amount = Number(s.amount);
          if (s.cycle === 'monthly') return sum + amount;
          if (s.cycle === 'yearly') return sum + amount / 12;
          if (s.cycle === 'weekly') return sum + amount * (52 / 12);
          if (s.cycle === 'custom' && s.cycle_days)
            return sum + (amount * 30) / s.cycle_days;
          return sum + amount;
        }, 0),
    [subscriptions]
  );

  const monthlyIncome = useMemo(
    () =>
      subscriptions
        .filter((s) => s.direction === 'income' && !s.paused)
        .reduce((sum, s) => {
          const amount = Number(s.amount);
          if (s.cycle === 'monthly') return sum + amount;
          if (s.cycle === 'yearly') return sum + amount / 12;
          if (s.cycle === 'weekly') return sum + amount * (52 / 12);
          if (s.cycle === 'custom' && s.cycle_days)
            return sum + (amount * 30) / s.cycle_days;
          return sum + amount;
        }, 0),
    [subscriptions]
  );

  const activeCount = subscriptions.filter((s) => !s.paused).length;

  // Sort header helper
  const SortHeader = ({
    label,
    sortKeyName,
    align,
  }: {
    label: string;
    sortKeyName: SortKey;
    align?: 'left' | 'right';
  }) => (
    <TableHead
      className={`${align === 'left' ? '' : 'text-right'} cursor-pointer select-none`}
      onClick={() => toggleSort(sortKeyName)}
    >
      <span className="inline-flex items-center gap-1">
        {label}
        <ArrowUpDown
          className={`h-3 w-3 ${sortKey === sortKeyName ? 'text-primary' : 'text-muted-foreground/40'}`}
        />
      </span>
    </TableHead>
  );

  if (isLoading) {
    return (
      <div className="p-6 text-center text-muted-foreground">
        {t('common.loading')}
      </div>
    );
  }

  return (
    <div className="p-4 sm:p-6">
      {/* Header */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between mb-4 sm:mb-6">
        <h1 className="text-2xl font-bold sm:text-3xl">{t('subscription.title')}</h1>
        <Button variant="default-gradient" onClick={handleNew}>
          <Plus className="h-4 w-4 mr-1" />
          {t('subscription.newSubscription')}
        </Button>
      </div>

      {subscriptions.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <Receipt className="h-12 w-12 text-muted-foreground/40 mb-4" />
          <p className="text-neutral-500 mb-4">{t('subscription.noSubscriptions')}</p>
          <Button onClick={handleNew}>{t('subscription.firstSubscription')}</Button>
        </div>
      ) : (
        <>
          {/* Summary cards */}
          <div className="grid grid-cols-3 gap-4 mb-6">
            <div className="rounded-lg border p-4">
              <div className="flex items-center gap-2 text-xs text-muted-foreground">
                <Receipt className="h-3.5 w-3.5" />
                {t('subscription.monthlyExpense')}
              </div>
              <div className="text-xl font-bold text-red-600">
                {formatCurrency(Number(monthlyExpense), 'CNY')}
              </div>
            </div>
            <div className="rounded-lg border p-4">
              <div className="flex items-center gap-2 text-xs text-muted-foreground">
                <Receipt className="h-3.5 w-3.5" />
                {t('subscription.monthlyIncome')}
              </div>
              <div className="text-xl font-bold text-emerald-600">
                {formatCurrency(Number(monthlyIncome), 'CNY')}
              </div>
            </div>
            <div className="rounded-lg border p-4">
              <div className="flex items-center gap-2 text-xs text-muted-foreground">
                <Users className="h-3.5 w-3.5" />
                {t('subscription.activeSubscriptions')}
              </div>
              <div className="text-xl font-bold">{activeCount}</div>
            </div>
          </div>

          {/* Filter bar */}
          <div className="flex flex-wrap items-center gap-3 mb-4">
            <Select value={filterCycle} onValueChange={v => setFilterCycle(v ?? 'all')}>
              <SelectTrigger className="w-36 h-8 text-xs">
                <SelectValue placeholder={t('subscription.allCycles')} />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">{t('subscription.allCycles')}</SelectItem>
                <SelectItem value="weekly">{t('subscription.weekly')}</SelectItem>
                <SelectItem value="monthly">{t('subscription.monthly')}</SelectItem>
                <SelectItem value="yearly">{t('subscription.yearly')}</SelectItem>
                <SelectItem value="custom">{t('subscription.custom')}</SelectItem>
              </SelectContent>
            </Select>

            <div className="flex items-center gap-1">
              <Button
                variant={filterDirection === 'all' ? 'default' : 'outline'}
                size="sm"
                className="h-7 text-xs"
                onClick={() => setFilterDirection('all')}
              >
                {t('subscription.all')}
              </Button>
              <Button
                variant={filterDirection === 'expense' ? 'default' : 'outline'}
                size="sm"
                className="h-7 text-xs"
                onClick={() => setFilterDirection('expense')}
              >
                {t('subscription.expense')}
              </Button>
              <Button
                variant={filterDirection === 'income' ? 'default' : 'outline'}
                size="sm"
                className="h-7 text-xs"
                onClick={() => setFilterDirection('income')}
              >
                {t('subscription.income')}
              </Button>
            </div>

            <Input
              placeholder={t('common.search')}
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-48 h-8 text-xs"
            />

            <span className="text-xs text-muted-foreground">
              {sortedSubscriptions.length}{' '}
              {t('subscription.title').toLowerCase()}
            </span>
          </div>

          {/* Table */}
          <div className="border rounded-lg">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-8" />
                  <SortHeader
                    label={t('subscription.name')}
                    sortKeyName="name"
                    align="left"
                  />
                  <SortHeader
                    label={t('subscription.amount')}
                    sortKeyName="amount"
                  />
                  <TableHead>{t('subscription.cycle')}</TableHead>
                  <TableHead>{t('subscription.direction')}</TableHead>
                  <SortHeader
                    label={t('subscription.nextBillingDate')}
                    sortKeyName="next_billing_date"
                  />
                  <TableHead>{t('subscription.active')}</TableHead>
                  <TableHead className="text-right">
                    {t('common.actions')}
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {sortedSubscriptions.length === 0 ? (
                  <TableRow>
                    <TableCell
                      colSpan={8}
                      className="text-center py-8 text-muted-foreground text-xs"
                    >
                      {t('subscription.noSubscriptions')}
                    </TableCell>
                  </TableRow>
                ) : (
                  sortedSubscriptions.map((sub) => {
                    const isExpanded = expandedId === sub.id;
                    const daysUntil = getDaysUntil(sub.next_billing_date);

                    return (
                      <React.Fragment key={sub.id}>
                        <TableRow
                          className={isExpanded ? 'bg-muted/20' : ''}
                        >
                          {/* Expand toggle */}
                          <TableCell className="w-8">
                            <Button
                              variant="ghost"
                              size="sm"
                              className="h-6 w-6 p-0"
                              onClick={() => toggleExpand(sub.id)}
                            >
                              {isExpanded ? (
                                <ChevronDown className="h-4 w-4" />
                              ) : (
                                <ChevronRight className="h-4 w-4" />
                              )}
                            </Button>
                          </TableCell>

                          {/* Name */}
                          <TableCell className="font-medium">
                            {sub.name}
                          </TableCell>

                          {/* Amount */}
                          <TableCell className="text-right">
                            {formatCurrency(Number(sub.amount), 'CNY')}
                          </TableCell>

                          {/* Cycle */}
                          <TableCell>
                            <Badge variant="secondary" className="text-[10px]">
                              {t(`subscription.${sub.cycle}`)}
                              {sub.cycle === 'custom' && sub.cycle_days
                                ? ` (${sub.cycle_days}d)`
                                : ''}
                            </Badge>
                          </TableCell>

                          {/* Direction */}
                          <TableCell>
                            <Badge
                              className={`text-[10px] ${
                                sub.direction === 'expense'
                                  ? 'bg-red-100 text-red-800'
                                  : 'bg-emerald-100 text-emerald-800'
                              }`}
                            >
                              {t(`subscription.${sub.direction}`)}
                            </Badge>
                          </TableCell>

                          {/* Next billing date */}
                          <TableCell>
                            <div className="flex flex-col">
                              <span className="text-xs">
                                {sub.next_billing_date}
                              </span>
                              <span
                                className={`text-[10px] ${
                                  daysUntil < 0
                                    ? 'text-red-500'
                                    : daysUntil <= 3
                                      ? 'text-amber-500'
                                      : 'text-muted-foreground'
                                }`}
                              >
                                {formatDaysUntil(daysUntil)}
                              </span>
                            </div>
                          </TableCell>

                          {/* Status */}
                          <TableCell>
                            {sub.paused ? (
                              <Badge
                                variant="secondary"
                                className="text-[10px] bg-amber-100 text-amber-800"
                              >
                                {t('subscription.pausedLabel')}
                              </Badge>
                            ) : (
                              <Badge
                                variant="secondary"
                                className="text-[10px] bg-emerald-100 text-emerald-800"
                              >
                                {t('subscription.active')}
                              </Badge>
                            )}
                          </TableCell>

                          {/* Actions */}
                          <TableCell className="text-right">
                            {deleteConfirmId === sub.id ? (
                              <div className="flex justify-end items-center gap-1">
                                <span className="text-xs text-red-600 mr-1">
                                  {t('common.confirmDelete')}
                                </span>
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  className="h-6 text-xs text-red-600"
                                  onClick={() =>
                                    deleteMutation.mutate(sub.id)
                                  }
                                  disabled={deleteMutation.isPending}
                                >
                                  {t('common.confirm')}
                                </Button>
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  className="h-6 text-xs"
                                  onClick={() => setDeleteConfirmId(null)}
                                >
                                  {t('common.cancel')}
                                </Button>
                              </div>
                            ) : (
                              <div className="flex justify-end gap-1">
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  className="h-7 text-xs"
                                  onClick={() =>
                                    sub.paused
                                      ? pauseMutation.mutate(sub.id)
                                      : resumeMutation.mutate(sub.id)
                                  }
                                  disabled={
                                    pauseMutation.isPending ||
                                    resumeMutation.isPending
                                  }
                                >
                                  {sub.paused ? (
                                    <>
                                      <Play className="h-3 w-3 mr-1" />
                                      {t('subscription.resume')}
                                    </>
                                  ) : (
                                    <>
                                      <Pause className="h-3 w-3 mr-1" />
                                      {t('subscription.pause')}
                                    </>
                                  )}
                                </Button>
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  className="h-7 text-xs"
                                  onClick={() => handleEdit(sub)}
                                >
                                  <Pencil className="h-3 w-3 mr-1" />
                                  {t('subscription.edit')}
                                </Button>
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  className="h-7 text-xs text-red-600 hover:text-red-700 hover:bg-red-50"
                                  onClick={() => setDeleteConfirmId(sub.id)}
                                >
                                  <Trash2 className="h-3 w-3 mr-1" />
                                  {t('subscription.delete')}
                                </Button>
                              </div>
                            )}
                          </TableCell>
                        </TableRow>

                        {/* Expanded transaction history */}
                        {isExpanded && (
                          <TableRow className="bg-muted/30">
                            <TableCell />
                            <TableCell colSpan={7}>
                              <div className="py-2">
                                <div className="text-xs font-medium text-muted-foreground mb-2">
                                  {t('subscription.transactionHistory')}
                                </div>
                                {isLoadingTransactions ? (
                                  <div className="text-xs text-muted-foreground py-2">
                                    {t('common.loading')}
                                  </div>
                                ) : transactionHistory.length === 0 ? (
                                  <div className="text-xs text-muted-foreground py-2">
                                    {t('subscription.noTransactions')}
                                  </div>
                                ) : (
                                  <div className="space-y-1">
                                    {transactionHistory.map(
                                      (txn: { id?: string; date?: string; transaction_date?: string; amount?: string; credit_amount?: string; debit_amount?: string; [key: string]: unknown }, idx: number) => (
                                        <div
                                          key={txn.id || idx}
                                          className="flex items-center justify-between text-xs py-1 px-2 rounded hover:bg-muted/50"
                                        >
                                          <div className="flex items-center gap-2">
                                            <CalendarCheck className="h-3 w-3 text-muted-foreground" />
                                            <span>
                                              {txn.date ||
                                                txn.transaction_date ||
                                                ''}
                                            </span>
                                          </div>
                                          <span
                                            className={
                                              Number(txn.amount || txn.credit_amount || 0) > 0
                                                ? 'text-emerald-600'
                                                : 'text-red-600'
                                            }
                                          >
                                            {getCurrencySymbol('CNY')}
                                            {Number(
                                              txn.amount ||
                                                txn.credit_amount ||
                                                txn.debit_amount ||
                                                0
                                            ).toFixed(2)}
                                          </span>
                                        </div>
                                      )
                                    )}
                                  </div>
                                )}
                              </div>
                            </TableCell>
                          </TableRow>
                        )}
                      </React.Fragment>
                    );
                  })
                )}
              </TableBody>
            </Table>
          </div>
        </>
      )}

      {/* Create/Edit Sheet */}
      <Sheet open={showSheet} onOpenChange={setShowSheet}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>
              {editingSubscription
                ? t('subscription.edit')
                : t('subscription.newSubscription')}
            </SheetTitle>
            <SheetDescription>
              {editingSubscription
                ? t('subscription.edit')
                : t('subscription.newSubscription')}
            </SheetDescription>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto -mx-4 px-4">
            <SubscriptionForm
              onSubmit={handleFormSubmit}
              onCancel={() => {
                setShowSheet(false);
                setEditingSubscription(null);
              }}
              initialValues={editingSubscription}
              isLoading={
                createMutation.isPending || updateMutation.isPending
              }
            />
          </div>
        </SheetContent>
      </Sheet>
    </div>
  );
}
