import { useState } from 'react';
import { useTranslation } from 'react-i18next';
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
import { Calendar } from '@/components/ui/calendar';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { cn } from '@/lib/utils';
import { CalendarIcon } from 'lucide-react';
import { format } from 'date-fns';

interface Account {
  id: string;
  name: string;
  balance: string;
  currency_code: string;
}

interface Category {
  id: string;
  name: string;
  icon: string;
  color: string;
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
      const data: TransactionFormData = {
        type,
        date,
        amount,
        description,
      };

      if (type === 'transfer') {
        data.fromAccountId = fromAccountId;
        data.toAccountId = toAccountId;
      } else {
        data.accountId = accountId;
        data.categoryId = categoryId;
      }

      await onSubmit(data);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      <Tabs value={type} onValueChange={(v) => setType(v as any)}>
        <TabsList className="grid w-full grid-cols-3">
          <TabsTrigger value="expense">{t('transaction.expense')}</TabsTrigger>
          <TabsTrigger value="income">{t('transaction.income')}</TabsTrigger>
          <TabsTrigger value="transfer">{t('transaction.transfer')}</TabsTrigger>
        </TabsList>

        <TabsContent value="expense" className="space-y-4 mt-4">
          <div className="space-y-2">
            <Label htmlFor="amount">{t('transaction.amount')}</Label>
            <Input
              id="amount"
              type="number"
              step="0.01"
              placeholder="0.00"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              required
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="account">{t('transaction.account')}</Label>
            <Select value={accountId} onValueChange={setAccountId} required>
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
            <Select value={categoryId} onValueChange={setCategoryId} required>
              <SelectTrigger>
                <SelectValue placeholder={t('transaction.selectCategory')} />
              </SelectTrigger>
              <SelectContent>
                {categories
                  .filter((c) => c.category_type === 'expense')
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

        <TabsContent value="income" className="space-y-4 mt-4">
          <div className="space-y-2">
            <Label htmlFor="amount">{t('transaction.amount')}</Label>
            <Input
              id="amount"
              type="number"
              step="0.01"
              placeholder="0.00"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              required
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="account">{t('transaction.account')}</Label>
            <Select value={accountId} onValueChange={setAccountId} required>
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
            <Select value={categoryId} onValueChange={setCategoryId} required>
              <SelectTrigger>
                <SelectValue placeholder={t('transaction.selectCategory')} />
              </SelectTrigger>
              <SelectContent>
                {categories
                  .filter((c) => c.category_type === 'income')
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

        <TabsContent value="transfer" className="space-y-4 mt-4">
          <div className="space-y-2">
            <Label htmlFor="amount">{t('transaction.amount')}</Label>
            <Input
              id="amount"
              type="number"
              step="0.01"
              placeholder="0.00"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              required
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="fromAccount">{t('transaction.fromAccount')}</Label>
            <Select value={fromAccountId} onValueChange={setFromAccountId} required>
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
            <Select value={toAccountId} onValueChange={setToAccountId} required>
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
        <Label>{t('transaction.date')}</Label>
        <Popover>
          <PopoverTrigger asChild>
            <Button
              variant="outline"
              className={cn(
                'w-full justify-start text-left font-normal',
                !date && 'text-muted-foreground'
              )}
            >
              <CalendarIcon className="mr-2 h-4 w-4" />
              {date ? format(date, 'PPP') : <span>{t('transaction.pickDate')}</span>}
            </Button>
          </PopoverTrigger>
          <PopoverContent className="w-auto p-0">
            <Calendar mode="single" selected={date} onSelect={(d) => d && setDate(d)} />
          </PopoverContent>
        </Popover>
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
