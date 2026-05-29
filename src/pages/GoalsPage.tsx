import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import {
  Plus,
  Trash2,
  Target,
  CheckCircle2,
  Clock,
  AlertTriangle,
  TrendingUp,
  PiggyBank,
  CreditCard,
  BarChart3,
  DollarSign,
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
  useGoals,
  useCreateGoal,
  useUpdateGoalProgress,
  useCompleteGoal,
  useDeleteGoal,
} from '../hooks/useGoal';
import { useCurrencies } from '../hooks/useCurrency';
import { listAccounts } from '../lib/tauri/account';
import type { GoalDto, CreateGoalDto } from '../lib/tauri/goal';
import {
  formatGoalAmount,
  getGoalTypeLabel,
  getGoalTypeColor,
  getGoalProgressColor,
  getGoalStatusColor,
} from '../lib/goal';

type FilterType = 'all' | 'active' | 'completed';

export function GoalsPage() {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const [showCreateDialog, setShowCreateDialog] = useState(false);
  const [showProgressDialog, setShowProgressDialog] = useState(false);
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);
  const [selectedGoal, setSelectedGoal] = useState<GoalDto | null>(null);
  const [filter, setFilter] = useState<FilterType>('all');

  // Form states
  const [goalName, setGoalName] = useState('');
  const [goalType, setGoalType] = useState('savings');
  const [targetAmount, setTargetAmount] = useState('');
  const [goalCurrency, setGoalCurrency] = useState('CNY');
  const [goalDeadline, setGoalDeadline] = useState('');
  const [goalLinkedAccount, setGoalLinkedAccount] = useState('');
  const [goalNotes, setGoalNotes] = useState('');
  const [progressAmount, setProgressAmount] = useState('');

  // Data fetching
  const { data: goals = [], isLoading } = useGoals();
  const { data: currencies = [] } = useCurrencies();
  const { data: accounts = [] } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
  });

  // Mutations
  const createGoalMutation = useCreateGoal();
  const updateProgressMutation = useUpdateGoalProgress();
  const completeGoalMutation = useCompleteGoal();
  const deleteGoalMutation = useDeleteGoal();

  // Filter goals
  const filteredGoals = goals.filter((goal) => {
    if (filter === 'active') return !goal.is_completed;
    if (filter === 'completed') return goal.is_completed;
    return true;
  });

  // Summary stats
  const activeGoals = goals.filter((g) => !g.is_completed);
  const completedGoals = goals.filter((g) => g.is_completed);
  const overdueGoals = goals.filter((g) => g.is_overdue);

  // Get currency symbol
  const getCurrencySymbol = (code: string) => {
    const currency = currencies.find((c) => c.code === code);
    return currency?.symbol || code;
  };

  // Get account name
  const getAccountName = (accountId: string | null) => {
    if (!accountId) return null;
    const account = accounts.find((a) => a.id === accountId);
    return account?.name || accountId;
  };

  // Get goal type icon
  const getGoalTypeIcon = (type: string) => {
    switch (type) {
      case 'savings':
        return <PiggyBank className="h-4 w-4" />;
      case 'debt_payoff':
        return <CreditCard className="h-4 w-4" />;
      case 'investment':
        return <BarChart3 className="h-4 w-4" />;
      default:
        return <Target className="h-4 w-4" />;
    }
  };

  // Reset form
  const resetForm = () => {
    setGoalName('');
    setGoalType('savings');
    setTargetAmount('');
    setGoalCurrency('CNY');
    setGoalDeadline('');
    setGoalLinkedAccount('');
    setGoalNotes('');
  };

  // Create goal
  const handleCreateGoal = () => {
    if (!goalName.trim()) {
      toast.error('请输入目标名称');
      return;
    }
    if (!targetAmount || parseFloat(targetAmount) <= 0) {
      toast.error('请输入有效的目标金额');
      return;
    }

    const dto: CreateGoalDto = {
      name: goalName,
      goal_type: goalType,
      target_amount: targetAmount,
      currency_code: goalCurrency,
      deadline: goalDeadline || undefined,
      linked_account_id: goalLinkedAccount || undefined,
      notes: goalNotes || undefined,
    };

    createGoalMutation.mutate(dto, {
      onSuccess: () => {
        setShowCreateDialog(false);
        resetForm();
        queryClient.invalidateQueries({ queryKey: ['goals'] });
      },
    });
  };

  // Update progress
  const handleUpdateProgress = () => {
    if (!selectedGoal) return;
    if (!progressAmount || parseFloat(progressAmount) <= 0) {
      toast.error('请输入有效的金额');
      return;
    }

    updateProgressMutation.mutate(
      { id: selectedGoal.id, amount: progressAmount },
      {
        onSuccess: () => {
          setShowProgressDialog(false);
          setSelectedGoal(null);
          setProgressAmount('');
          queryClient.invalidateQueries({ queryKey: ['goals'] });
        },
      }
    );
  };

  // Complete goal
  const handleCompleteGoal = (id: string) => {
    completeGoalMutation.mutate(id);
  };

  // Delete goal
  const handleDeleteGoal = () => {
    if (!deleteConfirmId) return;
    deleteGoalMutation.mutate(deleteConfirmId, {
      onSuccess: () => {
        setDeleteConfirmId(null);
        queryClient.invalidateQueries({ queryKey: ['goals'] });
      },
    });
  };

  if (isLoading) {
    return (
      <div className="p-6 flex items-center justify-center">
        <div className="text-muted-foreground">{t('common.loading')}</div>
      </div>
    );
  }

  return (
    <div className="p-4 sm:p-6">
      {/* Header */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between mb-4 sm:mb-6">
        <h1 className="text-2xl font-bold sm:text-3xl">{t('goals.title')}</h1>
        <Button onClick={() => setShowCreateDialog(true)}>
          <Plus className="h-4 w-4 mr-1" />
          {t('goals.createGoal')}
        </Button>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">
              {t('goals.totalGoals')}
            </CardTitle>
            <Target className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{goals.length}</div>
            <p className="text-xs text-muted-foreground">
              {t('goals.activeCount', { count: activeGoals.length })}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">
              {t('goals.completed')}
            </CardTitle>
            <CheckCircle2 className="h-4 w-4 text-emerald-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-emerald-600">
              {completedGoals.length}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">
              {t('goals.overdue')}
            </CardTitle>
            <AlertTriangle className="h-4 w-4 text-red-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-red-600">
              {overdueGoals.length}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">
              {t('goals.avgProgress')}
            </CardTitle>
            <TrendingUp className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {activeGoals.length > 0
                ? (
                    activeGoals.reduce(
                      (sum, g) => sum + g.progress_percentage,
                      0
                    ) / activeGoals.length
                  ).toFixed(1)
                : '0.0'}
              %
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Filter Tabs */}
      <div className="flex gap-2 mb-6">
        <Button
          variant={filter === 'all' ? 'default' : 'outline'}
          size="sm"
          onClick={() => setFilter('all')}
        >
          {t('goals.filterAll')} ({goals.length})
        </Button>
        <Button
          variant={filter === 'active' ? 'default' : 'outline'}
          size="sm"
          onClick={() => setFilter('active')}
        >
          {t('goals.filterActive')} ({activeGoals.length})
        </Button>
        <Button
          variant={filter === 'completed' ? 'default' : 'outline'}
          size="sm"
          onClick={() => setFilter('completed')}
        >
          {t('goals.filterCompleted')} ({completedGoals.length})
        </Button>
      </div>

      {/* Goals List */}
      {filteredGoals.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <Target className="h-12 w-12 text-muted-foreground/40 mb-4" />
          <p className="text-neutral-500 mb-2">
            {filter === 'all'
              ? t('goals.noGoals')
              : filter === 'active'
              ? t('goals.noActiveGoals')
              : t('goals.noCompletedGoals')}
          </p>
          {filter === 'all' && (
            <Button onClick={() => setShowCreateDialog(true)} className="mt-2">
              <Plus className="h-4 w-4 mr-1" />
              {t('goals.createGoal')}
            </Button>
          )}
        </div>
      ) : (
        <div className="grid gap-4">
          {filteredGoals.map((goal) => (
            <Card
              key={goal.id}
              className={goal.is_completed ? 'opacity-75' : ''}
            >
              <CardContent className="pt-4">
                <div className="flex items-start justify-between mb-4">
                  <div className="flex items-start gap-3">
                    <div
                      className={`p-2 rounded-lg ${getGoalTypeColor(
                        goal.goal_type
                      )}`}
                    >
                      {getGoalTypeIcon(goal.goal_type)}
                    </div>
                    <div>
                      <div className="flex items-center gap-2">
                        <h3 className="font-semibold text-lg">{goal.name}</h3>
                        {goal.is_completed && (
                          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-emerald-100 text-emerald-800">
                            <CheckCircle2 className="h-3 w-3" />
                            {t('goals.completed')}
                          </span>
                        )}
                        {goal.is_overdue && !goal.is_completed && (
                          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                            <AlertTriangle className="h-3 w-3" />
                            {t('goals.overdue')}
                          </span>
                        )}
                      </div>
                      <div className="flex items-center gap-3 mt-1 text-sm text-muted-foreground">
                        <span
                          className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium ${getGoalTypeColor(
                            goal.goal_type
                          )}`}
                        >
                          {getGoalTypeLabel(goal.goal_type)}
                        </span>
                        {goal.deadline && (
                          <span className="flex items-center gap-1">
                            <Clock className="h-3 w-3" />
                            {goal.deadline}
                          </span>
                        )}
                        {goal.linked_account_id && (
                          <span className="flex items-center gap-1">
                            <DollarSign className="h-3 w-3" />
                            {getAccountName(goal.linked_account_id)}
                          </span>
                        )}
                      </div>
                      {goal.notes && (
                        <p className="text-sm text-muted-foreground mt-1">
                          {goal.notes}
                        </p>
                      )}
                    </div>
                  </div>

                  <div className="flex items-center gap-1">
                    {!goal.is_completed && (
                      <>
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => {
                            setSelectedGoal(goal);
                            setShowProgressDialog(true);
                          }}
                          title={t('goals.addProgress')}
                        >
                          <TrendingUp className="h-4 w-4" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleCompleteGoal(goal.id)}
                          title={t('goals.markComplete')}
                        >
                          <CheckCircle2 className="h-4 w-4 text-emerald-500" />
                        </Button>
                      </>
                    )}
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => setDeleteConfirmId(goal.id)}
                      title={t('common.delete')}
                    >
                      <Trash2 className="h-4 w-4 text-red-500" />
                    </Button>
                  </div>
                </div>

                {/* Progress Section */}
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                  <div>
                    <div className="text-sm text-muted-foreground">
                      {t('goals.targetAmount')}
                    </div>
                    <div className="font-medium text-lg">
                      {getCurrencySymbol(goal.currency_code)}
                      {formatGoalAmount(goal.target_amount)}
                    </div>
                  </div>
                  <div>
                    <div className="text-sm text-muted-foreground">
                      {t('goals.currentAmount')}
                    </div>
                    <div className="font-medium text-lg">
                      {getCurrencySymbol(goal.currency_code)}
                      {formatGoalAmount(goal.current_amount)}
                    </div>
                  </div>
                  <div>
                    <div className="text-sm text-muted-foreground">
                      {t('goals.remaining')}
                    </div>
                    <div
                      className={`font-medium text-lg ${
                        parseFloat(goal.remaining_amount) <= 0
                          ? 'text-emerald-600'
                          : 'text-amber-600'
                      }`}
                    >
                      {getCurrencySymbol(goal.currency_code)}
                      {formatGoalAmount(goal.remaining_amount)}
                    </div>
                  </div>
                </div>

                {/* Progress Bar */}
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>{t('goals.progress')}</span>
                    <span
                      className={getGoalStatusColor({
                        is_completed: goal.is_completed,
                        is_overdue: goal.is_overdue,
                        progress_percentage: goal.progress_percentage,
                      })}
                    >
                      {goal.progress_percentage.toFixed(1)}%
                    </span>
                  </div>
                  <Progress
                    value={Math.min(goal.progress_percentage, 100)}
                  >
                    <div
                      className={`h-full rounded-full ${getGoalProgressColor(
                        goal.progress_percentage
                      )}`}
                      style={{
                        width: `${Math.min(goal.progress_percentage, 100)}%`,
                      }}
                    />
                  </Progress>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {/* Create Goal Dialog */}
      <Dialog
        open={showCreateDialog}
        onOpenChange={(open) => {
          setShowCreateDialog(open);
          if (!open) resetForm();
        }}
      >
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>{t('goals.createGoal')}</DialogTitle>
            <DialogDescription>{t('goals.createGoalDesc')}</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="goalName">{t('goals.goalName')}</Label>
              <Input
                id="goalName"
                value={goalName}
                onChange={(e) => setGoalName(e.target.value)}
                placeholder={t('goals.goalNamePlaceholder')}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="goalType">{t('goals.goalType')}</Label>
              <Select value={goalType} onValueChange={(v) => setGoalType(v ?? '')}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="savings">
                    {t('goals.typeSavings')}
                  </SelectItem>
                  <SelectItem value="debt_payoff">
                    {t('goals.typeDebtPayoff')}
                  </SelectItem>
                  <SelectItem value="investment">
                    {t('goals.typeInvestment')}
                  </SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="targetAmount">{t('goals.targetAmount')}</Label>
                <Input
                  id="targetAmount"
                  type="number"
                  value={targetAmount}
                  onChange={(e) => setTargetAmount(e.target.value)}
                  placeholder="0.00"
                  min="0"
                  step="0.01"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="goalCurrency">{t('common.currency')}</Label>
                <Select
                  value={goalCurrency}
                  onValueChange={(v) => setGoalCurrency(v ?? '')}
                >
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
            </div>
            <div className="space-y-2">
              <Label htmlFor="goalDeadline">
                {t('goals.deadline')} ({t('common.optional')})
              </Label>
              <Input
                id="goalDeadline"
                type="date"
                value={goalDeadline}
                onChange={(e) => setGoalDeadline(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="goalLinkedAccount">
                {t('goals.linkedAccount')} ({t('common.optional')})
              </Label>
              <Select
                value={goalLinkedAccount}
                onValueChange={(v) => setGoalLinkedAccount(v ?? '')}
              >
                <SelectTrigger>
                  <SelectValue placeholder={t('goals.selectAccount')} />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="none">
                    {t('goals.noAccount')}
                  </SelectItem>
                  {accounts.map((account) => (
                    <SelectItem key={account.id} value={account.id}>
                      {account.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="goalNotes">
                {t('common.note')} ({t('common.optional')})
              </Label>
              <Input
                id="goalNotes"
                value={goalNotes}
                onChange={(e) => setGoalNotes(e.target.value)}
                placeholder={t('goals.notesPlaceholder')}
              />
            </div>
          </div>
          <div className="flex justify-end gap-2">
            <Button
              variant="outline"
              onClick={() => {
                setShowCreateDialog(false);
                resetForm();
              }}
            >
              {t('common.cancel')}
            </Button>
            <Button
              onClick={handleCreateGoal}
              disabled={createGoalMutation.isPending}
            >
              {createGoalMutation.isPending
                ? t('common.saving')
                : t('common.create')}
            </Button>
          </div>
        </DialogContent>
      </Dialog>

      {/* Update Progress Dialog */}
      <Dialog
        open={showProgressDialog}
        onOpenChange={(open) => {
          setShowProgressDialog(open);
          if (!open) {
            setSelectedGoal(null);
            setProgressAmount('');
          }
        }}
      >
        <DialogContent className="max-w-sm">
          <DialogHeader>
            <DialogTitle>{t('goals.addProgress')}</DialogTitle>
            <DialogDescription>
              {selectedGoal && (
                <>
                  {selectedGoal.name} - {t('goals.current')}:{' '}
                  {getCurrencySymbol(selectedGoal.currency_code)}
                  {formatGoalAmount(selectedGoal.current_amount)}
                </>
              )}
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="progressAmount">{t('goals.progressAmount')}</Label>
              <Input
                id="progressAmount"
                type="number"
                value={progressAmount}
                onChange={(e) => setProgressAmount(e.target.value)}
                placeholder="0.00"
                min="0"
                step="0.01"
                autoFocus
              />
            </div>
          </div>
          <div className="flex justify-end gap-2">
            <Button
              variant="outline"
              onClick={() => {
                setShowProgressDialog(false);
                setSelectedGoal(null);
                setProgressAmount('');
              }}
            >
              {t('common.cancel')}
            </Button>
            <Button
              onClick={handleUpdateProgress}
              disabled={updateProgressMutation.isPending}
            >
              {updateProgressMutation.isPending
                ? t('common.saving')
                : t('goals.addProgress')}
            </Button>
          </div>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <Dialog
        open={!!deleteConfirmId}
        onOpenChange={() => setDeleteConfirmId(null)}
      >
        <DialogContent className="max-w-sm">
          <DialogHeader>
            <DialogTitle>{t('goals.deleteGoal')}</DialogTitle>
            <DialogDescription>
              {t('goals.deleteGoalConfirm')}
            </DialogDescription>
          </DialogHeader>
          <div className="flex justify-end gap-2 pt-4">
            <Button
              variant="outline"
              onClick={() => setDeleteConfirmId(null)}
            >
              {t('common.cancel')}
            </Button>
            <Button
              variant="destructive"
              onClick={handleDeleteGoal}
              disabled={deleteGoalMutation.isPending}
            >
              {deleteGoalMutation.isPending
                ? t('common.deleting')
                : t('common.delete')}
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}
