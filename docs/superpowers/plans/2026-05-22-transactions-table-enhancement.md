# Transactions Table Enhancement — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add period selector, filter bar (type/account/text search), inline description editing, edit Sheet, and delete with confirmation to TransactionsPage, plus backend update_transaction and delete_transaction Tauri commands.

**Architecture:** Hybrid filtering — period/date range drives server-side fetch via existing `getTransactionsByDateRange`, while type/account/text filters are applied client-side in `useMemo`. Editing reuses `SimpleTransactionForm` with a new `initialData` prop. Backend adds `update_transaction` (reverses old balances, soft-deletes old entries, creates new entries, applies new balances) and exposes existing `soft_delete` as `delete_transaction`.

**Tech Stack:** React 19 + TypeScript + TanStack React Query + Tailwind CSS + shadcn-style UI + Tauri v2 + Rust + SQLite (sqlx)

---

### Task 1: Add i18n keys

**Files:**
- Modify: `src/i18n/locales/en.json`
- Modify: `src/i18n/locales/zh.json`

- [ ] **Step 1: Add English keys**

Add to the `transactions` section in `en.json` (after line 152, the `"recorded"` key):

```json
"type": "Type",
"allTypes": "All",
"allAccounts": "All Accounts",
"searchDescription": "Search description...",
"editTransaction": "Edit Transaction",
"deleteTransaction": "Delete Transaction",
"deleteConfirmDesc": "Are you sure? This action cannot be undone.",
"deleteSuccess": "Transaction deleted",
"undo": "Undo",
"saveChanges": "Save Changes",
"descriptionUpdated": "Description updated",
"resultCount": "{{count}} transaction",
"resultCount_plural": "{{count}} transactions"
```

- [ ] **Step 2: Add Chinese keys**

Add to the `transactions` section in `zh.json`:

```json
"type": "类型",
"allTypes": "全部",
"allAccounts": "全部账户",
"searchDescription": "搜索描述...",
"editTransaction": "编辑交易",
"deleteTransaction": "删除交易",
"deleteConfirmDesc": "确定要删除吗？此操作不可撤销。",
"deleteSuccess": "交易已删除",
"undo": "撤销",
"saveChanges": "保存更改",
"descriptionUpdated": "描述已更新",
"resultCount": "{{count}} 笔交易",
"resultCount_plural": "{{count}} 笔交易"
```

- [ ] **Step 3: Commit**

```bash
git add src/i18n/locales/en.json src/i18n/locales/zh.json
git commit -m "feat: add transaction filter and edit i18n keys"
```

---

### Task 2: Add updateTransaction and deleteTransaction TypeScript wrappers

**Files:**
- Modify: `src/lib/tauri/transaction.ts`

- [ ] **Step 1: Add functions to transaction.ts**

Add after the `getTransactionsByDateRange` function (line 53):

```typescript
export const updateTransaction = (id: string, dto: CreateTransactionDto) =>
  invokeTauri<string>('update_transaction', { id, dto });

export const deleteTransaction = (id: string) =>
  invokeTauri<void>('delete_transaction', { id });
```

- [ ] **Step 2: Commit**

```bash
git add src/lib/tauri/transaction.ts
git commit -m "feat: add updateTransaction and deleteTransaction TS wrappers"
```

---

### Task 3: Add `initialData` prop to SimpleTransactionForm

**Files:**
- Modify: `src/components/SimpleTransactionForm.tsx`

- [ ] **Step 1: Add `initialData` prop to interface**

Change the props interface (lines 30-35):

```typescript
interface SimpleTransactionFormProps {
  accounts: Account[];
  externalAccounts: Account[];
  onSubmit: (data: TransactionFormData) => Promise<void>;
  onCancel: () => void;
  initialData?: TransactionFormData;  // pre-fill for edit mode
}
```

- [ ] **Step 2: Initialize state from `initialData`**

Replace the `useState` initializers (lines 56-67) with these that check `initialData`:

```typescript
const [type, setType] = useState<'income' | 'expense' | 'transfer'>(
  initialData?.type || 'expense'
);
const [date, setDate] = useState<Date>(
  initialData?.date || new Date()
);
const [amount, setAmount] = useState(initialData?.amount || '');
const [fromAccountId, setFromAccountId] = useState(
  initialData?.fromAccountId || accounts[0]?.id || ''
);
const [toAccountId, setToAccountId] = useState(
  initialData?.toAccountId || accounts[1]?.id || ''
);
const [ownAccountId, setOwnAccountId] = useState(
  initialData
    ? (initialData.type === 'expense'
        ? initialData.creditAccountId
        : initialData.debitAccountId) || ''
    : accounts.filter(a => a.ownership === 'own')[0]?.id || ''
);
const [externalAccountId, setExternalAccountId] = useState(
  initialData
    ? (initialData.type === 'expense'
        ? initialData.debitAccountId
        : initialData.creditAccountId) || ''
    : externalAccounts.filter(a => a.account_type === 'Expense')[0]?.id || ''
);
const [description, setDescription] = useState(initialData?.description || '');
```

- [ ] **Step 3: Change submit button text for edit mode**

Replace the submit button text (lines 343-352):

```typescript
<Button type="submit" variant="default-gradient" disabled={isSubmitting}>
  {isSubmitting
    ? t('common.saving')
    : initialData
      ? t('transactions.saveChanges')
      : type === 'expense'
        ? `${t('transaction.recordExpense')} — ¥${amount || '0'}`
        : type === 'income'
          ? `${t('transaction.recordIncome')} — ¥${amount || '0'}`
          : `${t('transaction.recordTransfer')} — ¥${amount || '0'}`
  }
</Button>
```

- [ ] **Step 4: Commit**

```bash
git add src/components/SimpleTransactionForm.tsx
git commit -m "feat: add initialData prop to SimpleTransactionForm for edit mode"
```

---

### Task 4: Add period selector and filter bar to TransactionsPage

**Files:**
- Modify: `src/pages/TransactionsPage.tsx`

- [ ] **Step 1: Add new imports to TransactionsPage**

Replace the existing imports (lines 1-28) with:

```typescript
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { toast } from 'sonner';
import { useTranslation } from 'react-i18next';
import { SimpleTransactionForm, type TransactionFormData } from '../components/SimpleTransactionForm';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../components/ui/select';
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
import { Plus, Pencil, Trash2, Search } from 'lucide-react';
import { listAccounts, listAccountsByOwnership } from '../lib/tauri/account';
import {
  listTransactions,
  getTransactionsByDateRange,
  updateTransaction,
  deleteTransaction,
  type TransactionDto,
  type CreateTransactionDto,
} from '../lib/tauri/transaction';
```

- [ ] **Step 2: Replace state and add filter/period state**

Replace the existing state (lines 31-33):

```typescript
type DateRangePreset = 'month' | 'quarter' | 'year' | 'custom';
type TransactionType_ = 'all' | 'expense' | 'income' | 'transfer';

export function TransactionsPage() {
  const [isSheetOpen, setIsSheetOpen] = useState(false);
  const [editingTransaction, setEditingTransaction] = useState<TransactionDto | null>(null);
  const [deletingTransaction, setDeletingTransaction] = useState<TransactionDto | null>(null);
  const [inlineEditId, setInlineEditId] = useState<string | null>(null);
  const [inlineEditValue, setInlineEditValue] = useState('');

  // Period selector state
  const [dateRangePreset, setDateRangePreset] = useState<DateRangePreset>('month');
  const [customStartDate, setCustomStartDate] = useState('');
  const [customEndDate, setCustomEndDate] = useState('');

  // Filter state
  const [typeFilter, setTypeFilter] = useState<TransactionType_>('all');
  const [accountFilter, setAccountFilter] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState('');

  const queryClient = useQueryClient();
  const { t } = useTranslation();
```

- [ ] **Step 3: Add dateRange computation**

Add after the state declarations:

```typescript
  const dateRange = useMemo(() => {
    const now = new Date();
    const today = now.toISOString().split('T')[0];

    if (dateRangePreset === 'custom' && customStartDate && customEndDate) {
      return { start: customStartDate, end: customEndDate };
    }

    if (dateRangePreset === 'month') {
      const start = new Date(now.getFullYear(), now.getMonth(), 1)
        .toISOString().split('T')[0];
      return { start, end: today };
    }

    if (dateRangePreset === 'quarter') {
      const quarterStart = new Date(now.getFullYear(), Math.floor(now.getMonth() / 3) * 3, 1);
      return { start: quarterStart.toISOString().split('T')[0], end: today };
    }

    if (dateRangePreset === 'year') {
      const start = `${now.getFullYear()}-01-01`;
      return { start, end: today };
    }

    return { start: '', end: '' };
  }, [dateRangePreset, customStartDate, customEndDate]);
```

- [ ] **Step 4: Update query to use dateRange**

Replace the transactions query (lines 47-55):

```typescript
  const { data: transactions = [], isLoading } = useQuery({
    queryKey: ['transactions', dateRange.start, dateRange.end],
    queryFn: async () => {
      if (dateRange.start && dateRange.end) {
        return getTransactionsByDateRange(dateRange.start, dateRange.end);
      }
      return listTransactions();
    },
  });
```

- [ ] **Step 5: Add helper functions**

Replace `getTransactionAccounts` (lines 83-86) and add new helpers:

```typescript
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

  const getTransactionType = (transaction: TransactionDto): TransactionType_ => {
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
  };

  const getTypeBadgeClass = (type: TransactionType_) => {
    switch (type) {
      case 'expense': return 'bg-red-50 text-red-600 dark:bg-red-950/30 dark:text-red-400';
      case 'income': return 'bg-green-50 text-green-600 dark:bg-green-950/30 dark:text-green-400';
      case 'transfer': return 'bg-purple-50 text-purple-600 dark:bg-purple-950/30 dark:text-purple-400';
      default: return '';
    }
  };
```

- [ ] **Step 6: Implement filteredTransactions with useMemo**

```typescript
  const filteredTransactions = useMemo(() => {
    let result = transactions;
    if (typeFilter !== 'all') {
      result = result.filter(tx => getTransactionType(tx) === typeFilter);
    }
    if (accountFilter !== 'all') {
      result = result.filter(tx =>
        tx.entries.some(e => e.account_id === accountFilter)
      );
    }
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      result = result.filter(tx =>
        tx.description?.toLowerCase().includes(q)
      );
    }
    return result;
  }, [transactions, typeFilter, accountFilter, searchQuery]);
```

- [ ] **Step 7: Commit**

```bash
git add src/pages/TransactionsPage.tsx
git commit -m "feat: add period selector, filter state, and helpers to TransactionsPage"
```

---

### Task 5: Rewrite TransactionsPage JSX — period selector + filter bar + table

**Files:**
- Modify: `src/pages/TransactionsPage.tsx` (replace the return JSX)

- [ ] **Step 1: Replace the entire return block (lines 93-201)**

Replace the return statement with the new JSX containing period selector, filter bar, and enhanced table:

```tsx
  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">{t('transactions.title')}</h1>
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
        <div className="w-px h-5 bg-border" />
        <Select value={accountFilter} onValueChange={setAccountFilter}>
          <SelectTrigger className="w-40 h-7 text-xs">
            <SelectValue placeholder={t('transactions.allAccounts')} />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">{t('transactions.allAccounts')}</SelectItem>
            {externalAccounts.map((acct) => (
              <SelectItem key={acct.id} value={acct.id}>{acct.name}</SelectItem>
            ))}
          </SelectContent>
        </Select>
        <div className="w-px h-5 bg-border" />
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
        <div className="border rounded-lg">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t('common.date')}</TableHead>
                <TableHead className="w-[90px]">{t('transactions.type')}</TableHead>
                <TableHead>{t('common.description')}</TableHead>
                <TableHead className="text-right w-[120px]">{t('common.amount')}</TableHead>
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
                          onBlur={() => handleInlineSave(transaction)}
                          onKeyDown={(e) => {
                            if (e.key === 'Enter') handleInlineSave(transaction);
                            if (e.key === 'Escape') setInlineEditId(null);
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
        </div>
      )}
```

- [ ] **Step 2: Commit**

```bash
git add src/pages/TransactionsPage.tsx
git commit -m "feat: rewrite TransactionsPage UI with period selector, filter bar, and enhanced table"
```

---

### Task 6: Add inline edit, edit Sheet, and delete dialog handlers to TransactionsPage

**Files:**
- Modify: `src/pages/TransactionsPage.tsx` (add handlers and dialog components)

- [ ] **Step 1: Add inline edit save handler**

Add before the return statement:

```typescript
  const handleInlineSave = async (transaction: TransactionDto) => {
    if (inlineEditValue === transaction.description) {
      setInlineEditId(null);
      return;
    }

    // Optimistic update
    const previous = queryClient.getQueryData<TransactionDto[]>(['transactions', dateRange.start, dateRange.end]);
    queryClient.setQueryData<TransactionDto[]>(
      ['transactions', dateRange.start, dateRange.end],
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
    } catch (error) {
      queryClient.setQueryData(['transactions', dateRange.start, dateRange.end], previous);
      toast.error(String(error));
    }
  };
```

- [ ] **Step 2: Add edit submit handler**

```typescript
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
      toast.success(t('transactions.descriptionUpdated'));
    } catch (error) {
      toast.error(String(error));
    }
  };
```

- [ ] **Step 3: Add buildEditEntries helper and edit initialData builder**

```typescript
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

  const getEditInitialData = (tx: TransactionDto): TransactionFormData | undefined => {
    if (!tx) return undefined;
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
```

- [ ] **Step 4: Add delete handler**

```typescript
  const handleDelete = async () => {
    if (!deletingTransaction) return;

    const txId = deletingTransaction.id;

    // Optimistic removal
    const previous = queryClient.getQueryData<TransactionDto[]>(['transactions', dateRange.start, dateRange.end]);
    queryClient.setQueryData<TransactionDto[]>(
      ['transactions', dateRange.start, dateRange.end],
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
            queryClient.setQueryData(['transactions', dateRange.start, dateRange.end], previous);
            queryClient.invalidateQueries({ queryKey: ['accounts'] });
          },
        },
      });
    } catch (error) {
      queryClient.setQueryData(['transactions', dateRange.start, dateRange.end], previous);
      toast.error(String(error));
    }
  };
```

- [ ] **Step 5: Replace the Sheet and add AlertDialog at end of return**

Replace the existing Sheet block (lines 184-198) with:

```tsx
      {/* Add Sheet */}
      <Sheet open={isSheetOpen && !editingTransaction} onOpenChange={(open) => { setIsSheetOpen(open); if (!open) setEditingTransaction(null); }}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{t('transactions.recordTransaction')}</SheetTitle>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto -mx-4 px-4">
            <SimpleTransactionForm
              accounts={accounts}
              externalAccounts={externalAccounts}
              onSubmit={async (data) => {
                setIsSheetOpen(false);
                queryClient.invalidateQueries({ queryKey: ['transactions'] });
                queryClient.invalidateQueries({ queryKey: ['accounts'] });
                toast.success(t('transactions.recorded'));
              }}
              onCancel={() => setIsSheetOpen(false)}
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
                initialData={getEditInitialData(editingTransaction)}
                onSubmit={handleEditSubmit}
                onCancel={() => { setIsSheetOpen(false); setEditingTransaction(null); }}
              />
            )}
          </div>
        </SheetContent>
      </Sheet>

      {/* Delete Confirmation Dialog — using a simple embedded dialog */}
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
    </div>
  );
```

- [ ] **Step 6: Update the Sheet open handler for add button**

Change the add button onClick from `() => setIsSheetOpen(true)` to ensure editingTransaction is cleared:

In the header's Record Transaction button, this is already handled by only opening the add Sheet when `!editingTransaction`.

- [ ] **Step 7: Commit**

```bash
git add src/pages/TransactionsPage.tsx
git commit -m "feat: add inline edit, edit Sheet, and delete dialog handlers"
```

---

### Task 7: Add `update` to TransactionRepository trait

**Files:**
- Modify: `src-tauri/src/domain/repositories/mod.rs`

- [ ] **Step 1: Add `update` method to TransactionRepository trait**

Add after the `create` method in the `TransactionRepository` trait (after line 40):

```rust
    async fn update(&self, transaction: &Transaction) -> sqlx::Result<bool>;
```

- [ ] **Step 2: Commit**

```bash
git add src-tauri/src/domain/repositories/mod.rs
git commit -m "feat: add update method to TransactionRepository trait"
```

---

### Task 8: Implement `update` in SqliteTransactionRepository

**Files:**
- Modify: `src-tauri/src/infrastructure/repositories/transaction_repository.rs`

- [ ] **Step 1: Add the `update` implementation**

Add after the `create` method (after line 209):

```rust
    async fn update(&self, transaction: &Transaction) -> sqlx::Result<bool> {
        let mut tx = self.pool.begin().await?;

        let result = sqlx::query(
            r#"
            UPDATE transactions
            SET transaction_date = ?,
                description = ?,
                updated_at = ?
            WHERE id = ? AND deleted_at IS NULL
            "#,
        )
        .bind(transaction.transaction_date.to_string())
        .bind(&transaction.description)
        .bind(Utc::now().to_rfc3339())
        .bind(transaction.id.to_string())
        .execute(&mut *tx)
        .await?;

        if result.rows_affected() > 0 {
            // Soft delete old entries
            sqlx::query(
                r#"
                UPDATE transaction_entries
                SET deleted_at = CURRENT_TIMESTAMP
                WHERE transaction_id = ? AND deleted_at IS NULL
                "#,
            )
            .bind(transaction.id.to_string())
            .execute(&mut *tx)
            .await?;

            // Insert new entries
            for entry in &transaction.entries {
                let (debit_amount, credit_amount) = match (&entry.debit_amount, &entry.credit_amount) {
                    (Some(debit), None) => (Some(debit.amount.to_string()), None),
                    (None, Some(credit)) => (None, Some(credit.amount.to_string())),
                    _ => (None, None),
                };

                sqlx::query(
                    r#"
                    INSERT INTO transaction_entries (
                        id, transaction_id, account_id, chart_of_account_code,
                        debit_amount, credit_amount, note,
                        updated_at, deleted_at, device_id, synced_at
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    "#,
                )
                .bind(entry.id.to_string())
                .bind(transaction.id.to_string())
                .bind(entry.account_id.to_string())
                .bind(&entry.chart_of_account_code)
                .bind(debit_amount)
                .bind(credit_amount)
                .bind(&entry.note)
                .bind(transaction.sync_metadata.updated_at.to_rfc3339())
                .bind(transaction.sync_metadata.deleted_at.map(|dt| dt.to_rfc3339()))
                .bind(transaction.sync_metadata.device_id.to_string())
                .bind(transaction.sync_metadata.synced_at.map(|dt| dt.to_rfc3339()))
                .execute(&mut *tx)
                .await?;
            }

            tx.commit().await?;
            Ok(true)
        } else {
            Ok(false)
        }
    }
```

- [ ] **Step 2: Commit**

```bash
git add src-tauri/src/infrastructure/repositories/transaction_repository.rs
git commit -m "feat: implement update in SqliteTransactionRepository"
```

---

### Task 9: Add update_transaction and delete_transaction to TransactionService

**Files:**
- Modify: `src-tauri/src/application/services/transaction_service.rs`

- [ ] **Step 1: Add `reverse_balances` helper and `update_transaction` method**

Add after the `create_transaction` method (after line 147):

```rust
    async fn reverse_balances(
        &self,
        entries: &[TransactionEntry],
    ) -> Result<(), TransactionServiceError> {
        for entry in entries {
            let mut account = self
                .account_repo
                .find_by_id(entry.account_id)
                .await?
                .ok_or(TransactionServiceError::AccountNotFound(entry.account_id))?;

            let new_balance = if let Some(debit) = &entry.debit_amount {
                account.balance.subtract(debit).map_err(|e| {
                    TransactionServiceError::ValidationError(format!(
                        "failed to reverse debit: {}",
                        e
                    ))
                })?
            } else if let Some(credit) = &entry.credit_amount {
                account.balance.add(credit).map_err(|e| {
                    TransactionServiceError::ValidationError(format!(
                        "failed to reverse credit: {}",
                        e
                    ))
                })?
            } else {
                account.balance.clone()
            };

            account
                .update_balance(new_balance)
                .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

            self.account_repo.update(&account).await?;
        }
        Ok(())
    }

    pub async fn update_transaction(
        &self,
        id: Uuid,
        dto: CreateTransactionDto,
    ) -> Result<Uuid, TransactionServiceError> {
        // 1. Find old transaction
        let old = self
            .transaction_repo
            .find_by_id(id)
            .await?
            .ok_or(TransactionServiceError::TransactionNotFound(id))?;

        // 2. Reverse old account balances
        self.reverse_balances(&old.entries).await?;

        // 3. Build new entries
        let mut new_entries = Vec::new();
        for entry_dto in &dto.entries {
            let account = self
                .account_repo
                .find_by_id(entry_dto.account_id)
                .await?
                .ok_or(TransactionServiceError::AccountNotFound(entry_dto.account_id))?;

            let debit_amount = entry_dto
                .debit_amount
                .map(|amt| Money::new(amt, &account.currency_code))
                .transpose()
                .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

            let credit_amount = entry_dto
                .credit_amount
                .map(|amt| Money::new(amt, &account.currency_code))
                .transpose()
                .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

            let entry = TransactionEntry::new(
                entry_dto.account_id,
                &entry_dto.chart_of_account_code,
                debit_amount,
                credit_amount,
                entry_dto.memo.as_deref().unwrap_or(""),
            )
            .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

            new_entries.push(entry);
        }

        // 4. Build updated transaction (reuse old ID, update sync metadata)
        let updated_sync = SyncMetadata {
            updated_at: Utc::now(),
            deleted_at: None,
            device_id: old.sync_metadata.device_id,
            synced_at: None,
        };

        let updated_transaction = Transaction::new(
            id,
            dto.transaction_date,
            dto.description,
            new_entries,
            updated_sync,
        )
        .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

        if !updated_transaction.is_balanced() {
            return Err(TransactionServiceError::ValidationError(
                "updated transaction is not balanced".to_string(),
            ));
        }

        // 5. Update in repository (soft-deletes old entries, inserts new ones)
        self.transaction_repo.update(&updated_transaction).await?;

        // 6. Apply new balances
        for entry in &updated_transaction.entries {
            let mut account = self
                .account_repo
                .find_by_id(entry.account_id)
                .await?
                .ok_or(TransactionServiceError::AccountNotFound(entry.account_id))?;

            let new_balance = if let Some(debit) = &entry.debit_amount {
                account.balance.add(debit).map_err(|e| {
                    TransactionServiceError::ValidationError(format!("failed to add debit: {}", e))
                })?
            } else if let Some(credit) = &entry.credit_amount {
                account.balance.subtract(credit).map_err(|e| {
                    TransactionServiceError::ValidationError(format!(
                        "failed to subtract credit: {}",
                        e
                    ))
                })?
            } else {
                account.balance.clone()
            };

            account
                .update_balance(new_balance)
                .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

            self.account_repo.update(&account).await?;
        }

        Ok(id)
    }

    pub async fn delete_transaction(
        &self,
        id: Uuid,
    ) -> Result<(), TransactionServiceError> {
        // Find transaction to reverse balances
        let transaction = self
            .transaction_repo
            .find_by_id(id)
            .await?
            .ok_or(TransactionServiceError::TransactionNotFound(id))?;

        // Reverse account balances before soft-deleting
        self.reverse_balances(&transaction.entries).await?;

        // Soft delete
        self.transaction_repo.soft_delete(id).await?;

        Ok(())
    }
```

- [ ] **Step 2: Add required imports at top**

Add `chrono::Utc` to the chrono import if not already present (it's imported via `use crate::domain::...`). Check that `SyncMetadata` is accessible (it should be since `create_transaction` uses it).

- [ ] **Step 3: Commit**

```bash
git add src-tauri/src/application/services/transaction_service.rs
git commit -m "feat: add update_transaction and delete_transaction to TransactionService"
```

---

### Task 10: Add update_transaction and delete_transaction Tauri commands

**Files:**
- Modify: `src-tauri/src/presentation/tauri_commands/transaction_commands.rs`
- Modify: `src-tauri/src/presentation/tauri_commands/mod.rs`
- Modify: `src-tauri/src/main.rs`

- [ ] **Step 1: Add command implementations to transaction_commands.rs**

Add after `get_transactions_by_date_range_with_service` (after line 121):

```rust
pub async fn update_transaction_with_service(
    service: &TransactionService,
    id: Uuid,
    dto: CreateTransactionDto,
) -> Result<Uuid, String> {
    service
        .update_transaction(id, dto)
        .await
        .map_err(|e| e.to_string())
}

pub async fn delete_transaction_with_service(
    service: &TransactionService,
    id: Uuid,
) -> Result<(), String> {
    service
        .delete_transaction(id)
        .await
        .map_err(|e| e.to_string())
}
```

- [ ] **Step 2: Add Tauri commands**

Add after the `create_simple_transfer` command (after line 257):

```rust
#[tauri::command]
pub async fn update_transaction(
    state: State<'_, TransactionCommandState>,
    id: String,
    dto: CreateTransactionDto,
) -> Result<String, String> {
    let id = parse_uuid(&id, "id")?;
    update_transaction_with_service(state.service(), id, dto)
        .await
        .map(|id| id.to_string())
}

#[tauri::command]
pub async fn delete_transaction(
    state: State<'_, TransactionCommandState>,
    id: String,
) -> Result<(), String> {
    let id = parse_uuid(&id, "id")?;
    delete_transaction_with_service(state.service(), id).await
}
```

- [ ] **Step 3: Export new functions from mod.rs**

Add `update_transaction, delete_transaction` to the `pub use transaction_commands::{ ... }` block (line 25):

```rust
pub use transaction_commands::{
    create_transaction, get_transaction, get_transactions_by_account,
    get_transactions_by_date_range, list_transactions,
    update_transaction, delete_transaction,
    TransactionCommandState,
};
```

- [ ] **Step 4: Register commands in main.rs**

In the import block (lines 32-36), add `update_transaction, delete_transaction`:

```rust
    transaction_commands::{
        create_default_state_from_pool, create_simple_expense, create_simple_income,
        create_simple_transfer, create_transaction, get_transaction,
        get_transactions_by_account, get_transactions_by_date_range, list_transactions,
        update_transaction, delete_transaction,
    },
```

In the `generate_handler!` macro (line 133), add after `create_simple_transfer`:

```rust
            update_transaction,
            delete_transaction,
```

- [ ] **Step 5: Commit**

```bash
git add src-tauri/src/presentation/tauri_commands/transaction_commands.rs src-tauri/src/presentation/tauri_commands/mod.rs src-tauri/src/main.rs
git commit -m "feat: add update_transaction and delete_transaction Tauri commands"
```

---

### Task 11: Build and verify

**Files:** None (verification only)

- [ ] **Step 1: Build frontend**

Run: `cd c:/Users/BuHiYo-001/Desktop/projects/fiance && npx tsc --noEmit`

Expected: No TypeScript errors.

If errors occur, note and fix them before proceeding.

- [ ] **Step 2: Build backend**

Run: `cd c:/Users/BuHiYo-001/Desktop/projects/fiance/src-tauri && cargo check 2>&1`

Expected: No compile errors. "Checking finance-app" with success.

- [ ] **Step 3: Full build**

Run: `cd c:/Users/BuHiYo-001/Desktop/projects/fiance && npx tauri build 2>&1 | tail -20`

Expected: Build completes successfully.

- [ ] **Step 4: Commit any fixes**

If any build fixes were needed, commit them separately:

```bash
git add -A
git commit -m "fix: resolve build errors from transactions table enhancements"
```
