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

  const { data: accounts = [] } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
  });

  const { data: externalAccounts = [] } = useQuery({
    queryKey: ['accounts', 'external'],
    queryFn: () => listAccountsByOwnership('external'),
  });

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

  const { data: transactions = [], isLoading } = useQuery({
    queryKey: ['transactions', dateRange.start, dateRange.end],
    queryFn: async () => {
      if (dateRange.start && dateRange.end) {
        return getTransactionsByDateRange(dateRange.start, dateRange.end);
      }
      return listTransactions();
    },
  });

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

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">{t('transactions.title')}</h1>
        <Button variant="default-gradient" onClick={() => setIsSheetOpen(true)}>
          <Plus className="mr-2 h-4 w-4" />
          {t('transactions.recordTransaction')}
        </Button>
      </div>

      {/* Placeholder — full UI in Tasks 5 and 6 */}
      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <div className="text-neutral-500">{t('transactions.loadingTransactions')}</div>
        </div>
      ) : (
        <div className="border rounded-lg">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t('common.date')}</TableHead>
                <TableHead>{t('common.description')}</TableHead>
                <TableHead className="text-right">{t('common.amount')}</TableHead>
                <TableHead>{t('transactions.accounts')}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filteredTransactions.map((transaction: TransactionDto) => (
                <TableRow key={transaction.id}>
                  <TableCell className="font-medium">
                    {new Date(transaction.transaction_date).toLocaleDateString('en-US', {
                      year: 'numeric',
                      month: 'short',
                      day: 'numeric',
                    })}
                  </TableCell>
                  <TableCell>{transaction.description}</TableCell>
                  <TableCell className="text-right">
                    {getTransactionAmount(transaction).toLocaleString('en-US', {
                      minimumFractionDigits: 2,
                      maximumFractionDigits: 2,
                    })}
                  </TableCell>
                  <TableCell className="text-neutral-600">
                    {getTransactionAccounts(transaction)}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}

      {/* Add Sheet — simplified for now, will be enhanced in Task 6 */}
      <Sheet open={isSheetOpen} onOpenChange={setIsSheetOpen}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{t('transactions.recordTransaction')}</SheetTitle>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto -mx-4 px-4">
            <SimpleTransactionForm
              accounts={accounts}
              externalAccounts={externalAccounts}
              onSubmit={async () => {
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
    </div>
  );
}
