import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import React, { useState, useMemo } from 'react';
import { toast } from 'sonner';
import {
  ArrowUpDown,
  Plus,
  Pencil,
  Trash2,
  Pause,
  Play,
  Repeat,
  Calendar,
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
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '../components/ui/table';
import { Input } from '../components/ui/input';
import { TransactionTemplateForm } from '../components/TransactionTemplateForm';
import { getUserFriendlyError } from '../lib/error-handler';
import {
  createTransactionTemplate,
  listTransactionTemplates,
  updateTransactionTemplate,
  deleteTransactionTemplate,
  pauseTransactionTemplate,
  resumeTransactionTemplate,
  type TransactionTemplateDto,
  type CreateTransactionTemplateDto,
  type UpdateTransactionTemplateDto,
} from '../lib/tauri/transactionTemplate';
import { formatCurrency } from '../lib/currency';

type SortKey = 'next_date' | 'amount' | 'name';
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

export function TransactionTemplatesPage() {
  const { t } = useTranslation();
  const queryClient = useQueryClient();

  // Sheet state
  const [showSheet, setShowSheet] = useState(false);
  const [editingTemplate, setEditingTemplate] =
    useState<TransactionTemplateDto | null>(null);

  // Table state
  const [sortKey, setSortKey] = useState<SortKey>('next_date');
  const [sortDir, setSortDir] = useState<SortDir>('asc');
  const [filterDirection, setFilterDirection] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);

  const { data: templates = [], isLoading } = useQuery({
    queryKey: ['transactionTemplates'],
    queryFn: listTransactionTemplates,
  });

  // Mutations
  const createMutation = useMutation({
    mutationFn: createTransactionTemplate,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactionTemplates'] });
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      setShowSheet(false);
      setEditingTemplate(null);
      toast.success(t('transactionTemplate.createSuccess'));
    },
    onError: (error) => toast.error(getUserFriendlyError(error)),
  });

  const updateMutation = useMutation({
    mutationFn: updateTransactionTemplate,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactionTemplates'] });
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      setShowSheet(false);
      setEditingTemplate(null);
      toast.success(t('transactionTemplate.updateSuccess'));
    },
    onError: (error) => toast.error(getUserFriendlyError(error)),
  });

  const deleteMutation = useMutation({
    mutationFn: deleteTransactionTemplate,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactionTemplates'] });
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      setDeleteConfirmId(null);
      toast.success(t('transactionTemplate.deleteSuccess'));
    },
    onError: (error) => toast.error(getUserFriendlyError(error)),
  });

  const pauseMutation = useMutation({
    mutationFn: pauseTransactionTemplate,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactionTemplates'] });
      toast.success(t('transactionTemplate.pause'));
    },
    onError: (error) => toast.error(getUserFriendlyError(error)),
  });

  const resumeMutation = useMutation({
    mutationFn: resumeTransactionTemplate,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactionTemplates'] });
      toast.success(t('transactionTemplate.resume'));
    },
    onError: (error) => toast.error(getUserFriendlyError(error)),
  });

  // Handlers
  const handleNew = () => {
    setEditingTemplate(null);
    setShowSheet(true);
  };

  const handleEdit = (tpl: TransactionTemplateDto) => {
    setEditingTemplate(tpl);
    setShowSheet(true);
  };

  const handleFormSubmit = (data: CreateTransactionTemplateDto | UpdateTransactionTemplateDto) => {
    if (editingTemplate) {
      updateMutation.mutate(data as UpdateTransactionTemplateDto);
    } else {
      createMutation.mutate(data as CreateTransactionTemplateDto);
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

  // Filtered & sorted list
  const filteredTemplates = useMemo(() => {
    let list = [...templates];
    if (filterDirection !== 'all') {
      list = list.filter((tpl) => tpl.direction === filterDirection);
    }
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      list = list.filter((tpl) => tpl.name.toLowerCase().includes(q));
    }
    return list;
  }, [templates, filterDirection, searchQuery]);

  const sortedTemplates = useMemo(() => {
    const sorted = [...filteredTemplates].sort((a, b) => {
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
        case 'next_date':
          va = a.next_date;
          vb = b.next_date;
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
  }, [filteredTemplates, sortKey, sortDir]);

  // Summary calculations
  const monthlyExpense = useMemo(
    () =>
      templates
        .filter((tpl) => tpl.direction === 'expense' && !tpl.paused)
        .reduce((sum, tpl) => {
          const amount = Number(tpl.amount);
          if (tpl.cycle === 'monthly') return sum + amount;
          if (tpl.cycle === 'yearly') return sum + amount / 12;
          if (tpl.cycle === 'weekly') return sum + amount * (52 / 12);
          if (tpl.cycle === 'custom' && tpl.cycle_days)
            return sum + (amount * 30) / tpl.cycle_days;
          return sum + amount;
        }, 0),
    [templates]
  );

  const monthlyIncome = useMemo(
    () =>
      templates
        .filter((tpl) => tpl.direction === 'income' && !tpl.paused)
        .reduce((sum, tpl) => {
          const amount = Number(tpl.amount);
          if (tpl.cycle === 'monthly') return sum + amount;
          if (tpl.cycle === 'yearly') return sum + amount / 12;
          if (tpl.cycle === 'weekly') return sum + amount * (52 / 12);
          if (tpl.cycle === 'custom' && tpl.cycle_days)
            return sum + (amount * 30) / tpl.cycle_days;
          return sum + amount;
        }, 0),
    [templates]
  );

  const activeCount = templates.filter((tpl) => !tpl.paused).length;

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
        <h1 className="text-2xl font-bold sm:text-3xl">{t('transactionTemplate.title')}</h1>
        <Button variant="default-gradient" onClick={handleNew}>
          <Plus className="h-4 w-4 mr-1" />
          {t('transactionTemplate.newTemplate')}
        </Button>
      </div>

      {templates.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <Repeat className="h-12 w-12 text-muted-foreground/40 mb-4" />
          <p className="text-neutral-500 mb-4">{t('transactionTemplate.noTemplates')}</p>
          <Button onClick={handleNew}>{t('transactionTemplate.firstTemplate')}</Button>
        </div>
      ) : (
        <>
          {/* Summary cards */}
          <div className="grid grid-cols-3 gap-4 mb-6">
            <div className="rounded-lg border p-4">
              <div className="flex items-center gap-2 text-xs text-muted-foreground">
                <Repeat className="h-3.5 w-3.5" />
                {t('transactionTemplate.monthlyExpense')}
              </div>
              <div className="text-xl font-bold text-red-600">
                {formatCurrency(Number(monthlyExpense), 'CNY')}
              </div>
            </div>
            <div className="rounded-lg border p-4">
              <div className="flex items-center gap-2 text-xs text-muted-foreground">
                <Repeat className="h-3.5 w-3.5" />
                {t('transactionTemplate.monthlyIncome')}
              </div>
              <div className="text-xl font-bold text-emerald-600">
                {formatCurrency(Number(monthlyIncome), 'CNY')}
              </div>
            </div>
            <div className="rounded-lg border p-4">
              <div className="flex items-center gap-2 text-xs text-muted-foreground">
                <Calendar className="h-3.5 w-3.5" />
                {t('transactionTemplate.activeTemplates')}
              </div>
              <div className="text-xl font-bold">{activeCount}</div>
            </div>
          </div>

          {/* Filter bar */}
          <div className="flex flex-wrap items-center gap-3 mb-4">
            <div className="flex items-center gap-1">
              <Button
                variant={filterDirection === 'all' ? 'default' : 'outline'}
                size="sm"
                className="h-7 text-xs"
                onClick={() => setFilterDirection('all')}
              >
                {t('transactionTemplate.all')}
              </Button>
              <Button
                variant={filterDirection === 'expense' ? 'default' : 'outline'}
                size="sm"
                className="h-7 text-xs"
                onClick={() => setFilterDirection('expense')}
              >
                {t('transactionTemplate.expense')}
              </Button>
              <Button
                variant={filterDirection === 'income' ? 'default' : 'outline'}
                size="sm"
                className="h-7 text-xs"
                onClick={() => setFilterDirection('income')}
              >
                {t('transactionTemplate.income')}
              </Button>
              <Button
                variant={filterDirection === 'transfer' ? 'default' : 'outline'}
                size="sm"
                className="h-7 text-xs"
                onClick={() => setFilterDirection('transfer')}
              >
                {t('transactionTemplate.transfer')}
              </Button>
            </div>

            <Input
              placeholder={t('common.search')}
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-48 h-8 text-xs"
            />

            <span className="text-xs text-muted-foreground">
              {sortedTemplates.length}{' '}
              {t('transactionTemplate.title').toLowerCase()}
            </span>
          </div>

          {/* Table */}
          <div className="border rounded-lg">
            <Table>
              <TableHeader>
                <TableRow>
                  <SortHeader
                    label={t('transactionTemplate.name')}
                    sortKeyName="name"
                    align="left"
                  />
                  <SortHeader
                    label={t('transactionTemplate.amount')}
                    sortKeyName="amount"
                  />
                  <TableHead>{t('transactionTemplate.cycle')}</TableHead>
                  <TableHead>{t('transactionTemplate.direction')}</TableHead>
                  <SortHeader
                    label={t('transactionTemplate.nextDate')}
                    sortKeyName="next_date"
                  />
                  <TableHead>{t('transactionTemplate.active')}</TableHead>
                  <TableHead className="text-right">
                    {t('common.actions')}
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {sortedTemplates.length === 0 ? (
                  <TableRow>
                    <TableCell
                      colSpan={7}
                      className="text-center py-8 text-muted-foreground text-xs"
                    >
                      {t('transactionTemplate.noTemplates')}
                    </TableCell>
                  </TableRow>
                ) : (
                  sortedTemplates.map((tpl) => {
                    const daysUntil = getDaysUntil(tpl.next_date);

                    return (
                      <TableRow key={tpl.id}>
                        {/* Name */}
                        <TableCell className="font-medium">
                          <div>
                            {tpl.name}
                            {tpl.description && (
                              <div className="text-[10px] text-muted-foreground mt-0.5 truncate max-w-48">
                                {tpl.description}
                              </div>
                            )}
                          </div>
                        </TableCell>

                        {/* Amount */}
                        <TableCell className="text-right">
                          {formatCurrency(Number(tpl.amount), 'CNY')}
                        </TableCell>

                        {/* Cycle */}
                        <TableCell>
                          <Badge variant="secondary" className="text-[10px]">
                            {t(`transactionTemplate.${tpl.cycle}`)}
                            {tpl.cycle === 'custom' && tpl.cycle_days
                              ? ` (${tpl.cycle_days}d)`
                              : ''}
                          </Badge>
                        </TableCell>

                        {/* Direction */}
                        <TableCell>
                          <Badge
                            className={`text-[10px] ${
                              tpl.direction === 'expense'
                                ? 'bg-red-100 text-red-800'
                                : tpl.direction === 'income'
                                  ? 'bg-emerald-100 text-emerald-800'
                                  : 'bg-blue-100 text-blue-800'
                            }`}
                          >
                            {t(`transactionTemplate.${tpl.direction}`)}
                          </Badge>
                        </TableCell>

                        {/* Next date */}
                        <TableCell>
                          <div className="flex flex-col">
                            <span className="text-xs">
                              {tpl.next_date}
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
                          {tpl.paused ? (
                            <Badge
                              variant="secondary"
                              className="text-[10px] bg-amber-100 text-amber-800"
                            >
                              {t('transactionTemplate.pausedLabel')}
                            </Badge>
                          ) : (
                            <Badge
                              variant="secondary"
                              className="text-[10px] bg-emerald-100 text-emerald-800"
                            >
                              {t('transactionTemplate.active')}
                            </Badge>
                          )}
                        </TableCell>

                        {/* Actions */}
                        <TableCell className="text-right">
                          {deleteConfirmId === tpl.id ? (
                            <div className="flex justify-end items-center gap-1">
                              <span className="text-xs text-red-600 mr-1">
                                {t('common.confirmDelete')}
                              </span>
                              <Button
                                variant="ghost"
                                size="sm"
                                className="h-6 text-xs text-red-600"
                                onClick={() =>
                                  deleteMutation.mutate(tpl.id)
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
                                  tpl.paused
                                    ? resumeMutation.mutate(tpl.id)
                                    : pauseMutation.mutate(tpl.id)
                                }
                                disabled={
                                  pauseMutation.isPending ||
                                  resumeMutation.isPending
                                }
                              >
                                {tpl.paused ? (
                                  <>
                                    <Play className="h-3 w-3 mr-1" />
                                    {t('transactionTemplate.resume')}
                                  </>
                                ) : (
                                  <>
                                    <Pause className="h-3 w-3 mr-1" />
                                    {t('transactionTemplate.pause')}
                                  </>
                                )}
                              </Button>
                              <Button
                                variant="ghost"
                                size="sm"
                                className="h-7 text-xs"
                                onClick={() => handleEdit(tpl)}
                              >
                                <Pencil className="h-3 w-3 mr-1" />
                                {t('transactionTemplate.edit')}
                              </Button>
                              <Button
                                variant="ghost"
                                size="sm"
                                className="h-7 text-xs text-red-600 hover:text-red-700 hover:bg-red-50"
                                onClick={() => setDeleteConfirmId(tpl.id)}
                              >
                                <Trash2 className="h-3 w-3 mr-1" />
                                {t('transactionTemplate.delete')}
                              </Button>
                            </div>
                          )}
                        </TableCell>
                      </TableRow>
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
              {editingTemplate
                ? t('transactionTemplate.edit')
                : t('transactionTemplate.newTemplate')}
            </SheetTitle>
            <SheetDescription>
              {editingTemplate
                ? t('transactionTemplate.edit')
                : t('transactionTemplate.newTemplate')}
            </SheetDescription>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto -mx-4 px-4">
            <TransactionTemplateForm
              onSubmit={handleFormSubmit}
              onCancel={() => {
                setShowSheet(false);
                setEditingTemplate(null);
              }}
              initialValues={editingTemplate}
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
