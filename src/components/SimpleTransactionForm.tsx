import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { cn } from '@/lib/utils';
import {
  createSimpleIncome,
  createSimpleExpense,
  createSimpleTransfer,
} from '@/lib/api/transactions';

interface Account {
  id: string;
  name: string;
  balance: number;
  currency_code: string;
}

interface Category {
  id: string;
  name: string;
  icon: string;
  color: string;
  category_type: 'Income' | 'Expense';
}

interface SimpleTransactionFormProps {
  accounts: Account[];
  categories: Category[];
  onSubmit: (data: TransactionFormData) => Promise<void>;
  onCancel: () => void;
}

export interface TransactionFormData {
  type: 'income' | 'expense' | 'transfer';
  date: Date;
  amount: string;
  accountId?: string;
  fromAccountId?: string;
  toAccountId?: string;
  categoryId?: string;
  description: string;
}

export function SimpleTransactionForm({
  accounts,
  categories,
  onSubmit,
  onCancel,
}: SimpleTransactionFormProps) {
  const { t } = useTranslation();
  const [type, setType] = useState<'income' | 'expense' | 'transfer'>('expense');
  const [date, setDate] = useState<Date>(new Date());
  const [amount, setAmount] = useState('');
  const [accountId, setAccountId] = useState('');
  const [fromAccountId, setFromAccountId] = useState('');
  const [toAccountId, setToAccountId] = useState('');
  const [categoryId, setCategoryId] = useState('');
  const [description, setDescription] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);

    try {
      // Validate required fields
      if (type === 'expense' || type === 'income') {
        if (!accountId) {
          toast.error(t('transaction.pleaseSelectAccount'));
          setIsSubmitting(false);
          return;
        }
        if (!categoryId) {
          toast.error(t('transaction.pleaseSelectCategory'));
          setIsSubmitting(false);
          return;
        }
        if (!amount || parseFloat(amount) <= 0) {
          toast.error(t('transaction.pleaseEnterValidAmount'));
          setIsSubmitting(false);
          return;
        }
      } else if (type === 'transfer') {
        if (!fromAccountId) {
          toast.error(t('transaction.pleaseSelectFromAccount'));
          setIsSubmitting(false);
          return;
        }
        if (!toAccountId) {
          toast.error(t('transaction.pleaseSelectToAccount'));
          setIsSubmitting(false);
          return;
        }
        if (fromAccountId === toAccountId) {
          toast.error(t('transaction.accountsMustBeDifferent'));
          setIsSubmitting(false);
          return;
        }
        if (!amount || parseFloat(amount) <= 0) {
          toast.error(t('transaction.pleaseEnterValidAmount'));
          setIsSubmitting(false);
          return;
        }
      }

      // Format date as YYYY-MM-DD
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      const dateStr = `${year}-${month}-${day}`;

      if (type === 'income') {
        await createSimpleIncome({
          accountId,
          categoryId,
          amount,
          date: dateStr,
          description,
        });
      } else if (type === 'expense') {
        await createSimpleExpense({
          accountId,
          categoryId,
          amount,
          date: dateStr,
          description,
        });
      } else if (type === 'transfer') {
        await createSimpleTransfer({
          fromAccountId,
          toAccountId,
          amount,
          date: dateStr,
          description,
        });
      }

      // Reset form fields
      setAmount('');
      setAccountId('');
      setFromAccountId('');
      setToAccountId('');
      setCategoryId('');
      setDescription('');

      // Call parent onSubmit to close dialog and refresh
      await onSubmit({
        type,
        date,
        amount,
        accountId: type === 'transfer' ? undefined : accountId,
        fromAccountId: type === 'transfer' ? fromAccountId : undefined,
        toAccountId: type === 'transfer' ? toAccountId : undefined,
        categoryId: type === 'transfer' ? undefined : categoryId,
        description,
      });
    } catch (error) {
      console.error('Failed to create transaction:', error);
      toast.error(`Failed to create transaction: ${error}`);
      return; // Don't call onSubmit if API failed
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      {/* Amount — always visible, type-tinted background */}
      <div className={cn(
        "rounded-xl border p-4 text-center",
        type === 'expense' && "bg-gradient-to-br from-red-50/50 to-card border-red-200/50 dark:from-red-950/20 dark:to-card dark:border-red-800/30",
        type === 'income' && "bg-gradient-to-br from-emerald-50/50 to-card border-emerald-200/50 dark:from-emerald-950/20 dark:to-card dark:border-emerald-800/30",
        type === 'transfer' && "bg-gradient-to-br from-blue-50/50 to-card border-blue-200/50 dark:from-blue-950/20 dark:to-card dark:border-blue-800/30",
      )}>
        <div className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2">
          {t('transaction.amount')}
        </div>
        <div className="flex items-center justify-center gap-1">
          <span className="text-3xl font-bold text-foreground/80">¥</span>
          <input
            type="number"
            step="0.01"
            min="0.01"
            required
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.00"
            className="w-40 bg-transparent text-center text-3xl font-bold outline-none [appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none"
          />
        </div>
      </div>
      <Tabs value={type} onValueChange={(v) => setType(v as 'income' | 'expense' | 'transfer')}>
        <TabsList variant="line" className="w-full">
          <TabsTrigger value="expense">{t('transaction.expense')}</TabsTrigger>
          <TabsTrigger value="income">{t('transaction.income')}</TabsTrigger>
          <TabsTrigger value="transfer">{t('transaction.transfer')}</TabsTrigger>
        </TabsList>

        <TabsContent value="expense" className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="account">{t('transaction.account')}</Label>
            <Select value={accountId} onValueChange={(v) => v && setAccountId(v)} required>
              <SelectTrigger>
                <SelectValue placeholder={t('transaction.selectAccount')} />
              </SelectTrigger>
              <SelectContent>
                {accounts.map((account) => (
                  <SelectItem key={account.id} value={account.id}>
                    {account.name} ({account.currency_code})
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label htmlFor="category">{t('transaction.category')}</Label>
            <Select value={categoryId} onValueChange={(v) => v && setCategoryId(v)} required>
              <SelectTrigger>
                <SelectValue placeholder={t('transaction.selectCategory')} />
              </SelectTrigger>
              <SelectContent>
                {categories
                  .filter((c) => c.category_type === 'Expense')
                  .map((category) => (
                    <SelectItem key={category.id} value={category.id}>
                      <span className="flex items-center gap-2">
                        <span>{category.icon}</span>
                        <span>{category.name}</span>
                      </span>
                    </SelectItem>
                  ))}
              </SelectContent>
            </Select>
          </div>
        </TabsContent>

        <TabsContent value="income" className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="account">{t('transaction.account')}</Label>
            <Select value={accountId} onValueChange={(v) => v && setAccountId(v)} required>
              <SelectTrigger>
                <SelectValue placeholder={t('transaction.selectAccount')} />
              </SelectTrigger>
              <SelectContent>
                {accounts.map((account) => (
                  <SelectItem key={account.id} value={account.id}>
                    {account.name} ({account.currency_code})
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label htmlFor="category">{t('transaction.category')}</Label>
            <Select value={categoryId} onValueChange={(v) => v && setCategoryId(v)} required>
              <SelectTrigger>
                <SelectValue placeholder={t('transaction.selectCategory')} />
              </SelectTrigger>
              <SelectContent>
                {categories
                  .filter((c) => c.category_type === 'Income')
                  .map((category) => (
                    <SelectItem key={category.id} value={category.id}>
                      <span className="flex items-center gap-2">
                        <span>{category.icon}</span>
                        <span>{category.name}</span>
                      </span>
                    </SelectItem>
                  ))}
              </SelectContent>
            </Select>
          </div>
        </TabsContent>

        <TabsContent value="transfer" className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="fromAccount">{t('transaction.fromAccount')}</Label>
            <Select value={fromAccountId} onValueChange={(v) => v && setFromAccountId(v)} required>
              <SelectTrigger>
                <SelectValue placeholder={t('transaction.selectAccount')} />
              </SelectTrigger>
              <SelectContent>
                {accounts.map((account) => (
                  <SelectItem key={account.id} value={account.id}>
                    {account.name} ({account.currency_code})
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label htmlFor="toAccount">{t('transaction.toAccount')}</Label>
            <Select value={toAccountId} onValueChange={(v) => v && setToAccountId(v)} required>
              <SelectTrigger>
                <SelectValue placeholder={t('transaction.selectAccount')} />
              </SelectTrigger>
              <SelectContent>
                {accounts
                  .filter((a) => a.id !== fromAccountId)
                  .map((account) => (
                    <SelectItem key={account.id} value={account.id}>
                      {account.name} ({account.currency_code})
                    </SelectItem>
                  ))}
              </SelectContent>
            </Select>
          </div>
        </TabsContent>
      </Tabs>

      {/* Common fields for all types */}
      <div className="space-y-2">
        <Label htmlFor="date">{t('transaction.date')}</Label>
        <Input
          id="date"
          type="date"
          value={date.toISOString().split('T')[0]}
          onChange={(e) => setDate(new Date(e.target.value))}
          required
        />
      </div>

      <div className="space-y-2">
        <Label htmlFor="description">{t('transaction.description')}</Label>
        <Input
          id="description"
          placeholder={t('transaction.descriptionPlaceholder')}
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          required
        />
      </div>

      <div className="flex gap-2 justify-end">
        <Button type="button" variant="outline" onClick={onCancel}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" disabled={isSubmitting}>
          {isSubmitting ? t('common.saving') : t('common.save')}
        </Button>
      </div>
    </form>
  );
}
