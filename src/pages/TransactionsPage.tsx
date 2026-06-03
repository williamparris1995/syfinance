import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { toast } from 'sonner';
import { useTranslation } from 'react-i18next';
import { useSearch } from '@tanstack/react-router';
import { SimpleTransactionForm, type TransactionFormData } from '../components/SimpleTransactionForm';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { MultiSelect } from '../components/ui/multi-select';
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
import { ArrowDown, ArrowUp, Copy, Plus, Pencil, Trash2, Search, X } from 'lucide-react';
import { listAccounts, listAccountsByOwnership } from '../lib/tauri/account';
import {
  updateTransaction,
  deleteTransaction,
  batchDeleteTransactions,
  listTransactionsPaginated,
  type TransactionDto,
  type CreateTransactionDto,
} from '../lib/tauri/transaction';
import { useCursorPagination } from '../hooks/useCursorPagination';

type DateRangePreset = 'month' | 'quarter' | 'year' | 'custom';
type TransactionType_ = 'all' | 'expense' | 'income' | 'transfer';

export function TransactionsPage() {
  const search = useSearch({ strict: false }) as {
    accountId?: string;
    startDate?: string;
    endDate?: string;
  };

  const [isSheetOpen, setIsSheetOpen] = useState(false);
  const [editingTransaction, setEditingTransaction] = useState<TransactionDto | null>(null);
  const [copyingTransaction, setCopyingTransaction] = useState<TransactionDto | null>(null);
  const [deletingTransaction, setDeletingTransaction] = useState<TransactionDto | null>(null);
  const [inlineEditId, setInlineEditId] = useState<string | null>(null);
  const [inlineEditValue, setInlineEditValue] = useState('');
  const inlineEditEscapeRef = useRef(false);

  // Period selector state — use search params as defaults when drilling down
  const [dateRangePreset, setDateRangePreset] = useState<DateRangePreset>(
    search.startDate && search.endDate ? 'custom' : 'month',
  );
  const [customStartDate, setCustomStartDate] = useState(search.startDate || '');
  const [customEndDate, setCustomEndDate] = useState(search.endDate || '');

  // Filter state — pre-set account filter when drilling down
  const [typeFilter, setTypeFilter] = useState<TransactionType_>('all');
  const [ownAccountFilter, setOwnAccountFilter] = useState<string[]>([]);
  const [externalAccountFilter, setExternalAccountFilter] = useState<string[]>(
    search.accountId ? [search.accountId] : [],
  );
  const [searchQuery, setSearchQuery] = useState('');

  // Sort state
  type SortColumn = 'date' | 'type' | 'description' | 'amount';
  const [sortColumn, setSortColumn] = useState<SortColumn>('date');
  const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('desc');

  // Multi-select state
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [confirmBatchDelete, setConfirmBatchDelete] = useState(false);

  const queryClient = useQueryClient();
  const { t } = useTranslation();

  const batchDeleteMutation = useMutation({
    mutationFn: batchDeleteTransactions,
    onSuccess: (deleted) => {
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      toast.success(t('transactions.batchDeleteSuccess', { count: deleted }));
      setSelectedIds(new Set());
      setConfirmBatchDelete(false);
    },
    onError: () => {
      toast.error(t('common.errorGeneric'));
    },
  });

  const toggleSelect = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  };

  const toggleSelectAll = () => {
    if (selectedIds.size === filteredTransactions.length && filteredTransactions.length > 0) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(filteredTransactions.map((tx) => tx.id)));
    }
  };

  const { data: accounts = [] } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
  });

  const { data: externalAccounts = [] } = useQuery({
    queryKey: ['accounts', 'external'],
    queryFn: () => listAccountsByOwnership('external'),
  });

  const ownAccounts = useMemo(
    () => accounts.filter((a) => a.ownership === 'own'),
    [accounts],
  );

  const dateRange = useMemo(() => {
    const now = new Date();
    const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;

    if (dateRangePreset === 'custom' && customStartDate && customEndDate) {
      return { start: customStartDate, end: customEndDate };
    }

    if (dateRangePreset === 'month') {
      const start = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`;
      return { start, end: today };
    }

    if (dateRangePreset === 'quarter') {
      const quarterMonth = Math.floor(now.getMonth() / 3) * 3 + 1;
      return { start: `${now.getFullYear()}-${String(quarterMonth).padStart(2, '0')}-01`, end: today };
    }

    if (dateRangePreset === 'year') {
      const start = `${now.getFullYear()}-01-01`;
      return { start, end: today };
    }

    return { start: '', end: '' };
  }, [dateRangePreset, customStartDate, customEndDate]);

  const {
    items: transactions,
    isLoading,
    currentPage,
    totalPages,
    hasNextPage,
    hasPrevPage,
    goNext,
    goPrev,
    goToPage,
    reset: resetPagination,
  } = useCursorPagination(
    ['transactions-paginated', dateRange.start, dateRange.end],
    async (cursor) => {
      return listTransactionsPaginated({
        first: 50,
        after: cursor,
        startDate: dateRange.start || undefined,
        endDate: dateRange.end || undefined,
      });
    },
  );

  useEffect(() => {
    resetPagination();
  }, [dateRange.start, dateRange.end, resetPagination]);

  const getAccountName = (accountId: string) => {
    const account = accounts.find((a) => a.id === accountId);
    return account ? account.name : accountId;
  };

  const getTransactionAmount = (transaction: TransactionDto) => {
    let total = 0;
    transaction.entries.forEach((entry) => {
      if (entry.debit_amount) {
        total += parseFloat(entry.debit_amount);
      }
    });
    return total;
  };

  const getTransactionAccounts = (transaction: TransactionDto) => {
    const accountNames = transaction.entries.map((entry) => getAccountName(entry.account_id));
    return [...new Set(accountNames)].join(', ');
  };

  const getTransactionType = useCallback((transaction: TransactionDto): TransactionType_ => {
    const externalAccountIds = externalAccounts.map(a => a.id);
    const txExternalEntries = transaction.entries.filter(e => externalAccountIds.includes(e.account_id));
    if (txExternalEntries.length === 0) return 'transfer';
    const incomeCount = txExternalEntries.filter(e =>
      externalAccounts.find(a => a.id === e.account_id && a.account_type === 'Income')
    ).length;
    const expenseCount = txExternalEntries.filter(e =>
      externalAccounts.find(a => a.id === e.account_id && a.account_type === 'Expense')
    ).length;
    if (incomeCount > 0 && expenseCount === 0) return 'income';
    if (expenseCount > 0 && incomeCount === 0) return 'expense';
    return 'transfer';
  }, [externalAccounts]);

  const getTypeBadgeClass = (type: TransactionType_) => {
    switch (type) {
      case 'expense': return 'bg-red-50 text-red-600 dark:bg-red-950/30 dark:text-red-400';
      case 'income': return 'bg-green-50 text-green-600 dark:bg-green-950/30 dark:text-green-400';
      case 'transfer': return 'bg-purple-50 text-purple-600 dark:bg-purple-950/30 dark:text-purple-400';
      default: return '';
    }
  };

  const filteredTransactions = useMemo(() => {
    let result = transactions;
    if (typeFilter !== 'all') {
      result = result.filter(tx => getTransactionType(tx) === typeFilter);
    }
    const isAllOwnSelected =
      ownAccountFilter.length === 0 ||
      ownAccountFilter.length === ownAccounts.length;
    const isAllExtSelected =
      externalAccountFilter.length === 0 ||
      externalAccountFilter.length === externalAccounts.length;

    if (!isAllOwnSelected || !isAllExtSelected) {
      result = result.filter((tx) => {
        const matchesOwn =
          isAllOwnSelected ||
          tx.entries.some((e) => ownAccountFilter.includes(e.account_id));
        const matchesExt =
          isAllExtSelected ||
          tx.entries.some((e) => externalAccountFilter.includes(e.account_id));
        return matchesOwn && matchesExt;
      });
    }
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      result = result.filter(tx =>
        tx.description?.toLowerCase().includes(q)
      );
    }
    // Sort
    result = [...result].sort((a, b) => {
      let cmp = 0;
      if (sortColumn === 'date') {
        cmp = a.transaction_date.localeCompare(b.transaction_date);
      } else if (sortColumn === 'type') {
        cmp = getTransactionType(a).localeCompare(getTransactionType(b));
      } else if (sortColumn === 'description') {
        cmp = (a.description || '').localeCompare(b.description || '');
      } else if (sortColumn === 'amount') {
        cmp = getTransactionAmount(a) - getTransactionAmount(b);
      }
      return sortDirection === 'asc' ? cmp : -cmp;
    });
    return result;
  }, [transactions, typeFilter, ownAccountFilter, externalAccountFilter, searchQuery, ownAccounts.length, externalAccounts.length, sortColumn, sortDirection, getTransactionType]);

  const getEditInitialData = (tx: TransactionDto): TransactionFormData => {
    const txType = getTransactionType(tx);
    const amount = getTransactionAmount(tx).toFixed(2);
    if (txType === 'transfer') {
      const creditEntry = tx.entries.find(e => e.credit_amount);
      const debitEntry = tx.entries.find(e => e.debit_amount);
      return {
        type: 'transfer',
        date: new Date(tx.transaction_date),
        amount,
        fromAccountId: creditEntry?.account_id || '',
        toAccountId: debitEntry?.account_id || '',
        description: tx.description,
      };
    }
    if (txType === 'expense') {
      const debitEntry = tx.entries.find(e => e.debit_amount);
      const creditEntry = tx.entries.find(e => e.credit_amount);
      return {
        type: 'expense',
        date: new Date(tx.transaction_date),
        amount,
        debitAccountId: debitEntry?.account_id || '',
        creditAccountId: creditEntry?.account_id || '',
        description: tx.description,
      };
    }
    // income
    const debitEntry = tx.entries.find(e => e.debit_amount);
    const creditEntry = tx.entries.find(e => e.credit_amount);
    return {
      type: 'income',
      date: new Date(tx.transaction_date),
      amount,
      debitAccountId: debitEntry?.account_id || '',
      creditAccountId: creditEntry?.account_id || '',
      description: tx.description,
    };
  };

  const buildEditEntries = (data: TransactionFormData) => {
    if (data.type === 'transfer') {
      return [
        {
          account_id: data.toAccountId!,
          chart_of_account_code: '1002',
          debit_amount: data.amount,
          credit_amount: null,
          memo: data.description || null,
        },
        {
          account_id: data.fromAccountId!,
          chart_of_account_code: '1002',
          debit_amount: null,
          credit_amount: data.amount,
          memo: data.description || null,
        },
      ];
    }
    if (data.type === 'expense') {
      return [
        {
          account_id: data.debitAccountId!,
          chart_of_account_code: '5401',
          debit_amount: data.amount,
          credit_amount: null,
          memo: data.description || null,
        },
        {
          account_id: data.creditAccountId!,
          chart_of_account_code: '5401',
          debit_amount: null,
          credit_amount: data.amount,
          memo: data.description || null,
        },
      ];
    }
    // income
    return [
      {
        account_id: data.debitAccountId!,
        chart_of_account_code: '4001',
        debit_amount: data.amount,
        credit_amount: null,
        memo: data.description || null,
      },
      {
        account_id: data.creditAccountId!,
        chart_of_account_code: '4001',
        debit_amount: null,
        credit_amount: data.amount,
        memo: data.description || null,
      },
    ];
  };

  const handleInlineSave = async (transaction: TransactionDto) => {
    if (inlineEditValue === transaction.description) {
      setInlineEditId(null);
      return;
    }

    // Optimistic update
    const queryKey = ['transactions', dateRange.start, dateRange.end];
    const previous = queryClient.getQueryData<TransactionDto[]>(queryKey);
    queryClient.setQueryData<TransactionDto[]>(
      queryKey,
      (old) => old?.map(tx =>
        tx.id === transaction.id ? { ...tx, description: inlineEditValue } : tx
      ),
    );

    setInlineEditId(null);

    try {
      const dto: CreateTransactionDto = {
        transaction_date: transaction.transaction_date,
        description: inlineEditValue,
        entries: transaction.entries.map(e => ({
          account_id: e.account_id,
          chart_of_account_code: e.chart_of_account_code,
          debit_amount: e.debit_amount,
          credit_amount: e.credit_amount,
          memo: e.memo,
          category_id: e.category_id,
        })),
      };
      await updateTransaction(transaction.id, dto);
      toast.success(t('transactions.descriptionUpdated'));
    } catch {
      queryClient.setQueryData(queryKey, previous);
      toast.error(t('common.errorGeneric'));
    }
  };

  const handleCopyClick = (transaction: TransactionDto) => {
    setEditingTransaction(null);
    setCopyingTransaction(transaction);
    setIsSheetOpen(true);
  };

  const handleEditSubmit = async (data: TransactionFormData) => {
    if (!editingTransaction) return;

    const year = data.date.getFullYear();
    const month = String(data.date.getMonth() + 1).padStart(2, '0');
    const day = String(data.date.getDate()).padStart(2, '0');
    const dateStr = `${year}-${month}-${day}`;

    const dto: CreateTransactionDto = {
      transaction_date: dateStr,
      description: data.description,
      entries: buildEditEntries(data),
    };

    try {
      await updateTransaction(editingTransaction.id, dto);
      setIsSheetOpen(false);
      setEditingTransaction(null);
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      toast.success(t('transactions.recorded'));
    } catch {
      toast.error(t('common.errorGeneric'));
    }
  };

  const handleDelete = async () => {
    if (!deletingTransaction) return;

    const txId = deletingTransaction.id;
    const queryKey = ['transactions', dateRange.start, dateRange.end];

    // Optimistic removal
    const previous = queryClient.getQueryData<TransactionDto[]>(queryKey);
    queryClient.setQueryData<TransactionDto[]>(
      queryKey,
      (old) => old?.filter(tx => tx.id !== txId),
    );
    setDeletingTransaction(null);

    try {
      await deleteTransaction(txId);
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      toast.success(t('transactions.deleteSuccess'), {
        action: {
          label: t('transactions.undo'),
          onClick: () => {
            queryClient.setQueryData(queryKey, previous);
            queryClient.invalidateQueries({ queryKey: ['accounts'] });
          },
        },
      });
    } catch {
      queryClient.setQueryData(queryKey, previous);
      toast.error(t('common.errorGeneric'));
    }
  };

  return (
    <div className="p-4 sm:p-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between mb-4 sm:mb-6">
        <h1 className="text-2xl font-bold sm:text-3xl">{t('transactions.title')}</h1>
        <Button variant="default-gradient" onClick={() => setIsSheetOpen(true)}>
          <Plus className="mr-2 h-4 w-4" />
          {t('transactions.recordTransaction')}
        </Button>
      </div>

      {/* Period Selector */}
      <div className="flex flex-wrap items-center gap-2 mb-4">
        <Button
          variant={dateRangePreset === 'month' ? 'default' : 'outline'}
          size="sm"
          onClick={() => setDateRangePreset('month')}
        >
          {t('reports.thisMonth')}
        </Button>
        <Button
          variant={dateRangePreset === 'quarter' ? 'default' : 'outline'}
          size="sm"
          onClick={() => setDateRangePreset('quarter')}
        >
          {t('reports.thisQuarter')}
        </Button>
        <Button
          variant={dateRangePreset === 'year' ? 'default' : 'outline'}
          size="sm"
          onClick={() => setDateRangePreset('year')}
        >
          {t('reports.thisYear')}
        </Button>
        <Button
          variant={dateRangePreset === 'custom' ? 'default' : 'outline'}
          size="sm"
          onClick={() => setDateRangePreset('custom')}
        >
          {t('reports.custom')}
        </Button>
        {dateRangePreset === 'custom' && (
          <div className="flex items-center gap-2 ml-2">
            <Input
              type="date"
              value={customStartDate}
              onChange={(e) => setCustomStartDate(e.target.value)}
              className="w-36 h-8 text-xs"
            />
            <span className="text-xs text-muted-foreground">—</span>
            <Input
              type="date"
              value={customEndDate}
              onChange={(e) => setCustomEndDate(e.target.value)}
              className="w-36 h-8 text-xs"
            />
          </div>
        )}
        <span className="text-xs text-muted-foreground ml-2">
          {dateRange.start && dateRange.end ? `${dateRange.start} — ${dateRange.end}` : ''}
        </span>
      </div>

      {/* Filter Bar */}
      <div className="flex flex-wrap items-center gap-3 mb-4 p-3 bg-muted/50 rounded-lg">
        <div className="flex items-center gap-1">
          {(['all', 'expense', 'income', 'transfer'] as const).map((filterType) => (
            <Button
              key={filterType}
              variant={typeFilter === filterType ? 'default' : 'ghost'}
              size="sm"
              onClick={() => setTypeFilter(filterType)}
              className="text-xs h-7 px-2.5"
            >
              {filterType === 'all'
                ? t('transactions.allTypes')
                : filterType === 'expense'
                  ? t('transaction.expense')
                  : filterType === 'income'
                    ? t('transaction.income')
                    : t('transaction.transfer')}
            </Button>
          ))}
        </div>
        <div className="hidden sm:block w-px h-5 bg-border" />
        <div className="flex items-center gap-2">
          <span className="text-[11px] text-muted-foreground hidden sm:inline">
            {t('transactions.ownAccounts')}
          </span>
          <MultiSelect
            options={ownAccounts.map((a) => ({ id: a.id, label: a.name }))}
            value={ownAccountFilter}
            onChange={setOwnAccountFilter}
            placeholder={t('transactions.ownAccounts')}
            selectAllLabel={t('common.selectAll')}
          />
        </div>
        <div className="hidden sm:block w-px h-5 bg-border" />
        <div className="flex items-center gap-2">
          <span className="text-[11px] text-muted-foreground hidden sm:inline">
            {t('transactions.externalAccounts')}
          </span>
          <MultiSelect
            options={externalAccounts.map((a) => ({ id: a.id, label: a.name }))}
            value={externalAccountFilter}
            onChange={setExternalAccountFilter}
            placeholder={t('transactions.externalAccounts')}
            selectAllLabel={t('common.selectAll')}
          />
        </div>
        <div className="hidden sm:block w-px h-5 bg-border" />
        <div className="relative flex-1 min-w-[180px] max-w-xs">
          <Search className="absolute left-2 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground" />
          <Input
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder={t('transactions.searchDescription')}
            className="pl-7 h-7 text-xs"
          />
        </div>
        <span className="text-xs text-muted-foreground ml-auto">
          {t('transactions.resultCount', { count: filteredTransactions.length })}
        </span>
      </div>

      {/* Table */}
      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <div className="text-neutral-500">{t('transactions.loadingTransactions')}</div>
        </div>
      ) : filteredTransactions.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <p className="text-neutral-500 mb-4">
            {dateRange.start || dateRange.end
              ? t('transactions.noTransactionsInRange')
              : t('transactions.noTransactions')}
          </p>
          <Button variant="default-gradient" onClick={() => setIsSheetOpen(true)}>
            {t('transactions.recordFirst')}
          </Button>
        </div>
      ) : (
        <div className="border rounded-lg overflow-x-auto">
          {/* Batch Action Bar */}
          {selectedIds.size > 0 && (
            <div className="flex items-center gap-3 px-4 py-2 bg-muted/70 border-b">
              <span className="text-sm font-medium">
                {t('transactions.selected', { count: selectedIds.size })}
              </span>
              <Button
                variant="destructive"
                size="sm"
                onClick={() => setConfirmBatchDelete(true)}
              >
                <Trash2 className="mr-1 h-3.5 w-3.5" />
                {t('transactions.batchDelete')}
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setSelectedIds(new Set())}
              >
                <X className="mr-1 h-3.5 w-3.5" />
                {t('transactions.clearSelection')}
              </Button>
            </div>
          )}
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="w-[40px] px-2">
                  <input
                    type="checkbox"
                    checked={selectedIds.size === filteredTransactions.length && filteredTransactions.length > 0}
                    ref={(el) => {
                      if (el) {
                        el.indeterminate = selectedIds.size > 0 && selectedIds.size < filteredTransactions.length;
                      }
                    }}
                    onChange={toggleSelectAll}
                    className="h-4 w-4 rounded border-gray-300"
                  />
                </TableHead>
                {(
                  [
                    { col: 'date' as const, label: t('common.date'), className: '' },
                    { col: 'type' as const, label: t('transactions.type'), className: 'w-[90px]' },
                    { col: 'description' as const, label: t('common.description'), className: '' },
                    { col: 'amount' as const, label: t('common.amount'), className: 'text-right w-[120px]' },
                  ] as const
                ).map(({ col, label, className }) => (
                  <TableHead
                    key={col}
                    className={`cursor-pointer select-none ${className}`}
                    onClick={() => {
                      if (sortColumn === col) {
                        setSortDirection((d) => (d === 'asc' ? 'desc' : 'asc'));
                      } else {
                        setSortColumn(col);
                        setSortDirection(col === 'date' ? 'desc' : 'asc');
                      }
                    }}
                  >
                    <span className="inline-flex items-center gap-1">
                      {label}
                      {sortColumn === col &&
                        (sortDirection === 'asc' ? (
                          <ArrowUp className="h-3 w-3" />
                        ) : (
                          <ArrowDown className="h-3 w-3" />
                        ))}
                    </span>
                  </TableHead>
                ))}
                <TableHead>{t('transactions.accounts')}</TableHead>
                <TableHead className="text-center w-[80px]">{t('common.actions')}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filteredTransactions.map((transaction) => {
                const txType = getTransactionType(transaction);
                const amount = getTransactionAmount(transaction);
                return (
                  <TableRow key={transaction.id}>
                    <TableCell className="w-[40px] px-2">
                      <input
                        type="checkbox"
                        checked={selectedIds.has(transaction.id)}
                        onChange={() => toggleSelect(transaction.id)}
                        className="h-4 w-4 rounded border-gray-300"
                      />
                    </TableCell>
                    <TableCell className="font-medium">
                      {new Date(transaction.transaction_date).toLocaleDateString('en-US', {
                        year: 'numeric',
                        month: 'short',
                        day: 'numeric',
                      })}
                    </TableCell>
                    <TableCell>
                      <span className={`inline-block px-2 py-0.5 rounded-full text-xs font-medium ${getTypeBadgeClass(txType)}`}>
                        {txType === 'expense'
                          ? t('transaction.expense')
                          : txType === 'income'
                            ? t('transaction.income')
                            : t('transaction.transfer')}
                      </span>
                    </TableCell>
                    <TableCell>
                      {inlineEditId === transaction.id ? (
                        <Input
                          value={inlineEditValue}
                          onChange={(e) => setInlineEditValue(e.target.value)}
                          onBlur={() => {
                            if (inlineEditEscapeRef.current) {
                              inlineEditEscapeRef.current = false;
                              return;
                            }
                            handleInlineSave(transaction);
                          }}
                          onKeyDown={(e) => {
                            if (e.key === 'Enter') handleInlineSave(transaction);
                            if (e.key === 'Escape') {
                              inlineEditEscapeRef.current = true;
                              setInlineEditId(null);
                            }
                          }}
                          className="h-7 text-sm border-2 border-blue-500"
                          autoFocus
                        />
                      ) : (
                        <span
                          className="cursor-pointer hover:text-blue-600 hover:underline decoration-dotted"
                          onClick={() => {
                            setInlineEditId(transaction.id);
                            setInlineEditValue(transaction.description);
                          }}
                        >
                          {transaction.description}
                        </span>
                      )}
                    </TableCell>
                    <TableCell className={`text-right font-medium ${
                      txType === 'expense' ? 'text-red-600' : txType === 'income' ? 'text-green-600' : ''
                    }`}>
                      {txType === 'expense' ? '-' : txType === 'income' ? '+' : ''}
                      {amount.toLocaleString('en-US', {
                        minimumFractionDigits: 2,
                        maximumFractionDigits: 2,
                      })}
                    </TableCell>
                    <TableCell className="text-neutral-600">
                      {getTransactionAccounts(transaction)}
                    </TableCell>
                    <TableCell className="text-center">
                      <Button
                        variant="ghost"
                        size="icon"
                        className="h-7 w-7"
                        onClick={() => handleCopyClick(transaction)}
                        title={t('transactions.copyToCreate')}
                      >
                        <Copy className="h-3.5 w-3.5 text-gray-500" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        className="h-7 w-7"
                        onClick={() => {
                          setEditingTransaction(transaction);
                          setIsSheetOpen(true);
                        }}
                      >
                        <Pencil className="h-3.5 w-3.5 text-blue-500" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        className="h-7 w-7"
                        onClick={() => setDeletingTransaction(transaction)}
                      >
                        <Trash2 className="h-3.5 w-3.5 text-red-500" />
                      </Button>
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
          <div className="flex items-center justify-between px-2 py-3 border-t">
            <div className="text-sm text-muted-foreground">
              {t('transactions.pageInfo', { page: currentPage + 1, total: totalPages })}
            </div>
            <div className="flex items-center gap-1">
              <Button
                variant="outline"
                size="sm"
                onClick={goPrev}
                disabled={!hasPrevPage}
              >
                {t('common.previous')}
              </Button>
              {Array.from({ length: totalPages }, (_, i) => (
                <Button
                  key={i}
                  variant={i === currentPage ? 'default' : 'outline'}
                  size="sm"
                  className="w-8 h-8 p-0"
                  onClick={() => goToPage(i)}
                >
                  {i + 1}
                </Button>
              ))}
              <Button
                variant="outline"
                size="sm"
                onClick={goNext}
                disabled={!hasNextPage}
              >
                {t('common.next')}
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* Add Sheet (also used for copy) */}
      <Sheet open={isSheetOpen && !editingTransaction} onOpenChange={(open) => { setIsSheetOpen(open); if (!open) { setEditingTransaction(null); setCopyingTransaction(null); } }}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{copyingTransaction ? t('transactions.copyToCreate') : t('transactions.recordTransaction')}</SheetTitle>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto -mx-4 px-4">
            <SimpleTransactionForm
              accounts={accounts}
              externalAccounts={externalAccounts}
              initialData={copyingTransaction ? getEditInitialData(copyingTransaction) : undefined}
              onSubmit={async () => {
                setIsSheetOpen(false);
                setCopyingTransaction(null);
                queryClient.invalidateQueries({ queryKey: ['transactions'] });
                queryClient.invalidateQueries({ queryKey: ['accounts'] });
                toast.success(t('transactions.recorded'));
              }}
              onCancel={() => { setIsSheetOpen(false); setCopyingTransaction(null); }}
            />
          </div>
        </SheetContent>
      </Sheet>

      {/* Edit Sheet */}
      <Sheet open={isSheetOpen && !!editingTransaction} onOpenChange={(open) => { setIsSheetOpen(open); if (!open) setEditingTransaction(null); }}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{t('transactions.editTransaction')}</SheetTitle>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto -mx-4 px-4">
            {editingTransaction && (
              <SimpleTransactionForm
                accounts={accounts}
                externalAccounts={externalAccounts}
                initialData={getEditInitialData(editingTransaction!)}
                mode="edit"
                onSubmit={handleEditSubmit}
                onCancel={() => { setIsSheetOpen(false); setEditingTransaction(null); }}
              />
            )}
          </div>
        </SheetContent>
      </Sheet>

      {/* Delete Confirmation Dialog */}
      {deletingTransaction && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-background rounded-lg shadow-lg p-6 max-w-sm w-full mx-4">
            <h3 className="text-lg font-semibold mb-2">{t('transactions.deleteTransaction')}</h3>
            <p className="text-sm text-muted-foreground mb-6">{t('transactions.deleteConfirmDesc')}</p>
            <div className="flex justify-end gap-2">
              <Button variant="outline" size="sm" onClick={() => setDeletingTransaction(null)}>
                {t('common.cancel')}
              </Button>
              <Button variant="destructive" size="sm" onClick={handleDelete}>
                {t('common.delete')}
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* Batch Delete Confirmation Dialog */}
      {confirmBatchDelete && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-background rounded-lg shadow-lg p-6 max-w-sm w-full mx-4">
            <h3 className="text-lg font-semibold mb-2">{t('transactions.batchDelete')}</h3>
            <p className="text-sm text-muted-foreground mb-6">
              {t('transactions.confirmBatchDelete', { count: selectedIds.size })}
            </p>
            <div className="flex justify-end gap-2">
              <Button variant="outline" size="sm" onClick={() => setConfirmBatchDelete(false)}>
                {t('common.cancel')}
              </Button>
              <Button
                variant="destructive"
                size="sm"
                disabled={batchDeleteMutation.isPending}
                onClick={() => batchDeleteMutation.mutate(Array.from(selectedIds))}
              >
                {t('common.delete')}
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
