import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import {
  Plus,
  Trash2,
  Wallet,
  TrendingUp,
  TrendingDown,
  Target,
  ChevronLeft,
  ChevronRight,
  PiggyBank,
  AlertTriangle,
} from 'lucide-react';
import { toast } from 'sonner';
import { Button } from '../components/ui/button';
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from '../components/ui/card';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '../components/ui/dialog';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../components/ui/select';
import { Progress } from '../components/ui/progress';
import {
  useBudgetByMonth,
  useCreateBudget,
  useAddBudgetItem,
  useDeleteBudget,
  useRemoveBudgetItem,
} from '../hooks/useBudget';
import { useCurrencies } from '../hooks/useCurrency';
import { listAccounts, type AccountDto } from '../lib/tauri/account';
import {
  formatBudgetAmount,
  getBudgetStatusColor,
  getBudgetProgressColor,
  getCurrentMonth,
  formatMonth,
} from '../lib/budget';

export function BudgetPage() {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const [currentMonth, setCurrentMonth] = useState(getCurrentMonth());
  const [showCreateDialog, setShowCreateDialog] = useState(false);
  const [showAddItemDialog, setShowAddItemDialog] = useState(false);
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);
  const [removeItemConfirm, setRemoveItemConfirm] = useState<{
    budgetId: string;
    itemId: string;
  } | null>(null);

  // Form states
  const [budgetName, setBudgetName] = useState('');
  const [budgetCurrency, setBudgetCurrency] = useState('CNY');
  const [itemCategory, setItemCategory] = useState('');
  const [itemPlannedAmount, setItemPlannedAmount] = useState('');
  const [itemNotes, setItemNotes] = useState('');

  // Fetch budget for current month
  const { data: budget, isLoading } = useBudgetByMonth(currentMonth);
  const { data: currencies = [] } = useCurrencies();
  const { data: accounts = [] } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
  });

  // Filter expense accounts for budget items
  const expenseAccounts = accounts.filter(
    (a) => a.account_type === 'Expense'
  );

  // Mutations
  const createBudgetMutation = useCreateBudget();
  const addBudgetItemMutation = useAddBudgetItem();
  const deleteBudgetMutation = useDeleteBudget();
  const removeBudgetItemMutation = useRemoveBudgetItem();

  // Month navigation
  const handlePrevMonth = () => {
    const [year, month] = currentMonth.split('-').map(Number);
    const prevMonth = month === 1 ? 12 : month - 1;
    const prevYear = month === 1 ? year - 1 : year;
    setCurrentMonth(`${prevYear}-${String(prevMonth).padStart(2, '0')}`);
  };

  const handleNextMonth = () => {
    const [year, month] = currentMonth.split('-').map(Number);
    const nextMonth = month === 12 ? 1 : month + 1;
    const nextYear = month === 12 ? year + 1 : year;
    setCurrentMonth(`${nextYear}-${String(nextMonth).padStart(2, '0')}`);
  };

  // Create budget
  const handleCreateBudget = () => {
    if (!budgetName.trim()) {
      toast.error(t('budget.nameRequired'));
      return;
    }
    createBudgetMutation.mutate(
      {
        name: budgetName,
        month: currentMonth,
        currency_code: budgetCurrency,
      },
      {
        onSuccess: () => {
          setShowCreateDialog(false);
          setBudgetName('');
          setBudgetCurrency('CNY');
          queryClient.invalidateQueries({ queryKey: ['budget'] });
        },
      }
    );
  };

  // Add budget item
  const handleAddItem = () => {
    if (!budget?.id) return;
    if (!itemCategory) {
      toast.error(t('budget.categoryRequired'));
      return;
    }
    if (!itemPlannedAmount || parseFloat(itemPlannedAmount) <= 0) {
      toast.error(t('budget.amountRequired'));
      return;
    }
    addBudgetItemMutation.mutate(
      {
        budgetId: budget.id,
        dto: {
          category_account_id: itemCategory,
          planned_amount: itemPlannedAmount,
          notes: itemNotes || undefined,
        },
      },
      {
        onSuccess: () => {
          setShowAddItemDialog(false);
          setItemCategory('');
          setItemPlannedAmount('');
          setItemNotes('');
          queryClient.invalidateQueries({ queryKey: ['budget'] });
        },
      }
    );
  };

  // Delete budget
  const handleDeleteBudget = () => {
    if (!budget?.id) return;
    deleteBudgetMutation.mutate(budget.id, {
      onSuccess: () => {
        setDeleteConfirmId(null);
        queryClient.invalidateQueries({ queryKey: ['budget'] });
      },
    });
  };

  // Remove budget item
  const handleRemoveItem = () => {
    if (!removeItemConfirm) return;
    removeBudgetItemMutation.mutate(removeItemConfirm, {
      onSuccess: () => {
        setRemoveItemConfirm(null);
        queryClient.invalidateQueries({ queryKey: ['budget'] });
      },
    });
  };

  // Get account name by ID
  const getAccountName = (accountId: string) => {
    const account = accounts.find((a) => a.id === accountId);
    return account?.name || accountId;
  };

  // Get currency symbol
  const getCurrencySymbol = (code: string) => {
    const currency = currencies.find((c) => c.code === code);
    return currency?.symbol || code;
  };

  if (isLoading) {
    return (
      <div className="p-6 flex items-center justify-center">
        <div className="text-muted-foreground">{t('common.loading')}</div>
      </div>
    );
  }

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">{t('budget.title')}</h1>
        {budget && (
          <div className="flex gap-2">
            <Button
              variant="outline"
              onClick={() => setShowAddItemDialog(true)}
            >
              <Plus className="h-4 w-4 mr-1" />
              {t('budget.addItem')}
            </Button>
            <Button
              variant="destructive"
              onClick={() => setDeleteConfirmId(budget.id)}
            >
              <Trash2 className="h-4 w-4 mr-1" />
              {t('budget.deleteBudget')}
            </Button>
          </div>
        )}
      </div>

      {/* Month Selector */}
      <div className="flex items-center justify-center gap-4 mb-6">
        <Button variant="outline" size="icon" onClick={handlePrevMonth}>
          <ChevronLeft className="h-4 w-4" />
        </Button>
        <div className="text-lg font-semibold min-w-[140px] text-center">
          {formatMonth(currentMonth)}
        </div>
        <Button variant="outline" size="icon" onClick={handleNextMonth}>
          <ChevronRight className="h-4 w-4" />
        </Button>
      </div>

      {!budget ? (
        /* No budget for this month */
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <PiggyBank className="h-12 w-12 text-muted-foreground/40 mb-4" />
          <p className="text-neutral-500 mb-4">{t('budget.noBudget')}</p>
          <Button onClick={() => setShowCreateDialog(true)}>
            <Plus className="h-4 w-4 mr-1" />
            {t('budget.createBudget')}
          </Button>
        </div>
      ) : (
        <>
          {/* Budget Overview Cards */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">
                  {t('budget.totalBudget')}
                </CardTitle>
                <Wallet className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">
                  {getCurrencySymbol(budget.currency_code)}
                  {formatBudgetAmount(budget.total_amount)}
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">
                  {t('budget.used')}
                </CardTitle>
                <TrendingUp className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-amber-600">
                  {getCurrencySymbol(budget.currency_code)}
                  {formatBudgetAmount(budget.total_actual)}
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">
                  {t('budget.remaining')}
                </CardTitle>
                <TrendingDown className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div
                  className={`text-2xl font-bold ${
                    parseFloat(budget.total_remaining) >= 0
                      ? 'text-emerald-600'
                      : 'text-red-600'
                  }`}
                >
                  {getCurrencySymbol(budget.currency_code)}
                  {formatBudgetAmount(budget.total_remaining)}
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">
                  {t('budget.usageRate')}
                </CardTitle>
                <Target className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div
                  className={`text-2xl font-bold ${getBudgetStatusColor(
                    budget.usage_percentage
                  )}`}
                >
                  {budget.usage_percentage.toFixed(1)}%
                </div>
                <Progress
                  value={Math.min(budget.usage_percentage, 100)}
                  className="mt-2"
                >
                  <div
                    className={`h-full rounded-full ${getBudgetProgressColor(
                      budget.usage_percentage
                    )}`}
                    style={{
                      width: `${Math.min(budget.usage_percentage, 100)}%`,
                    }}
                  />
                </Progress>
              </CardContent>
            </Card>
          </div>

          {/* Budget Items */}
          <div className="space-y-4">
            <h2 className="text-xl font-semibold">{t('budget.items')}</h2>

            {budget.items.length === 0 ? (
              <div className="text-center py-8 text-muted-foreground">
                {t('budget.noItems')}
              </div>
            ) : (
              <div className="grid gap-4">
                {budget.items.map((item) => (
                  <Card key={item.id}>
                    <CardContent className="pt-4">
                      <div className="flex items-center justify-between mb-4">
                        <div>
                          <div className="font-medium">
                            {getAccountName(item.category_account_id)}
                          </div>
                          {item.notes && (
                            <div className="text-sm text-muted-foreground">
                              {item.notes}
                            </div>
                          )}
                        </div>
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() =>
                            setRemoveItemConfirm({
                              budgetId: budget.id,
                              itemId: item.id,
                            })
                          }
                        >
                          <Trash2 className="h-4 w-4 text-red-500" />
                        </Button>
                      </div>

                      <div className="grid grid-cols-3 gap-4 mb-4">
                        <div>
                          <div className="text-sm text-muted-foreground">
                            {t('budget.planned')}
                          </div>
                          <div className="font-medium">
                            {getCurrencySymbol(budget.currency_code)}
                            {formatBudgetAmount(item.planned_amount)}
                          </div>
                        </div>
                        <div>
                          <div className="text-sm text-muted-foreground">
                            {t('budget.actual')}
                          </div>
                          <div className="font-medium">
                            {getCurrencySymbol(budget.currency_code)}
                            {formatBudgetAmount(item.actual_amount)}
                          </div>
                        </div>
                        <div>
                          <div className="text-sm text-muted-foreground">
                            {t('budget.remaining')}
                          </div>
                          <div
                            className={`font-medium ${
                              item.is_over_budget
                                ? 'text-red-600'
                                : 'text-emerald-600'
                            }`}
                          >
                            {item.is_over_budget && (
                              <AlertTriangle className="h-4 w-4 inline mr-1" />
                            )}
                            {getCurrencySymbol(budget.currency_code)}
                            {formatBudgetAmount(item.remaining)}
                          </div>
                        </div>
                      </div>

                      <div className="space-y-2">
                        <div className="flex justify-between text-sm">
                          <span>{t('budget.progress')}</span>
                          <span
                            className={getBudgetStatusColor(
                              item.usage_percentage
                            )}
                          >
                            {item.usage_percentage.toFixed(1)}%
                          </span>
                        </div>
                        <Progress
                          value={Math.min(item.usage_percentage, 100)}
                        >
                          <div
                            className={`h-full rounded-full ${getBudgetProgressColor(
                              item.usage_percentage
                            )}`}
                            style={{
                              width: `${Math.min(item.usage_percentage, 100)}%`,
                            }}
                          />
                        </Progress>
                      </div>
                    </CardContent>
                  </Card>
                ))}
              </div>
            )}
          </div>
        </>
      )}

      {/* Create Budget Dialog */}
      <Dialog open={showCreateDialog} onOpenChange={setShowCreateDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('budget.createBudget')}</DialogTitle>
            <DialogDescription>{t('budget.createBudgetDesc')}</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="budgetName">{t('budget.budgetName')}</Label>
              <Input
                id="budgetName"
                value={budgetName}
                onChange={(e) => setBudgetName(e.target.value)}
                placeholder={t('budget.budgetNamePlaceholder')}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="budgetCurrency">{t('common.currency')}</Label>
              <Select value={budgetCurrency} onValueChange={(v) => setBudgetCurrency(v ?? 'CNY')}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {currencies.map((currency) => (
                    <SelectItem key={currency.code} value={currency.code}>
                      {currency.code} ({currency.symbol})
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="text-sm text-muted-foreground">
              {t('budget.month')}: {formatMonth(currentMonth)}
            </div>
          </div>
          <div className="flex justify-end gap-2">
            <Button
              variant="outline"
              onClick={() => setShowCreateDialog(false)}
            >
              {t('common.cancel')}
            </Button>
            <Button
              onClick={handleCreateBudget}
              disabled={createBudgetMutation.isPending}
            >
              {createBudgetMutation.isPending
                ? t('common.saving')
                : t('common.create')}
            </Button>
          </div>
        </DialogContent>
      </Dialog>

      {/* Add Budget Item Dialog */}
      <Dialog open={showAddItemDialog} onOpenChange={setShowAddItemDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('budget.addItem')}</DialogTitle>
            <DialogDescription>{t('budget.addItemDesc')}</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="itemCategory">{t('budget.category')}</Label>
              <Select value={itemCategory} onValueChange={(v) => setItemCategory(v ?? '')}>
                <SelectTrigger>
                  <SelectValue placeholder={t('budget.selectCategory')} />
                </SelectTrigger>
                <SelectContent>
                  {expenseAccounts.map((account) => (
                    <SelectItem key={account.id} value={account.id}>
                      {account.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="itemPlannedAmount">
                {t('budget.plannedAmount')}
              </Label>
              <Input
                id="itemPlannedAmount"
                type="number"
                value={itemPlannedAmount}
                onChange={(e) => setItemPlannedAmount(e.target.value)}
                placeholder="0.00"
                min="0"
                step="0.01"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="itemNotes">{t('common.note')}</Label>
              <Input
                id="itemNotes"
                value={itemNotes}
                onChange={(e) => setItemNotes(e.target.value)}
                placeholder={t('budget.notesPlaceholder')}
              />
            </div>
          </div>
          <div className="flex justify-end gap-2">
            <Button
              variant="outline"
              onClick={() => setShowAddItemDialog(false)}
            >
              {t('common.cancel')}
            </Button>
            <Button
              onClick={handleAddItem}
              disabled={addBudgetItemMutation.isPending}
            >
              {addBudgetItemMutation.isPending
                ? t('common.saving')
                : t('common.create')}
            </Button>
          </div>
        </DialogContent>
      </Dialog>

      {/* Delete Budget Confirmation */}
      <Dialog
        open={!!deleteConfirmId}
        onOpenChange={() => setDeleteConfirmId(null)}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('budget.deleteBudget')}</DialogTitle>
            <DialogDescription>{t('budget.deleteBudgetConfirm')}</DialogDescription>
          </DialogHeader>
          <div className="flex justify-end gap-2 pt-4">
            <Button variant="outline" onClick={() => setDeleteConfirmId(null)}>
              {t('common.cancel')}
            </Button>
            <Button
              variant="destructive"
              onClick={handleDeleteBudget}
              disabled={deleteBudgetMutation.isPending}
            >
              {deleteBudgetMutation.isPending
                ? t('common.deleting')
                : t('common.delete')}
            </Button>
          </div>
        </DialogContent>
      </Dialog>

      {/* Remove Budget Item Confirmation */}
      <Dialog
        open={!!removeItemConfirm}
        onOpenChange={() => setRemoveItemConfirm(null)}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t('budget.removeItem')}</DialogTitle>
            <DialogDescription>{t('budget.removeItemConfirm')}</DialogDescription>
          </DialogHeader>
          <div className="flex justify-end gap-2 pt-4">
            <Button
              variant="outline"
              onClick={() => setRemoveItemConfirm(null)}
            >
              {t('common.cancel')}
            </Button>
            <Button
              variant="destructive"
              onClick={handleRemoveItem}
              disabled={removeBudgetItemMutation.isPending}
            >
              {removeBudgetItemMutation.isPending
                ? t('common.deleting')
                : t('common.delete')}
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}
