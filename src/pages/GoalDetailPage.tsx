import { useParams, useNavigate } from '@tanstack/react-router';
import { useTranslation } from 'react-i18next';
import { useQuery } from '@tanstack/react-query';
import {
  Target,
  CheckCircle2,
  AlertTriangle,
  Pencil,
  TrendingUp,
  RefreshCw,
  DollarSign,
} from 'lucide-react';
import { PageShell } from '@/components/patterns/layout/PageShell';
import { HeroCard } from '@/components/patterns/cards/HeroCard';
import { StatCard } from '@/components/patterns/cards/StatCard';
import { DetailTwoCol } from '@/components/patterns/detail/DetailTwoCol';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Separator } from '@/components/ui/separator';
import { Progress } from '@/components/ui/progress';
import { getGoal, listGoals, type GoalDto } from '@/lib/tauri/goal';
import {
  formatGoalAmount,
  getGoalTypeLabel,
  getGoalTypeColor,
  getGoalProgressColor,
  getGoalStatusColor,
} from '@/lib/goal';
import { listAccounts } from '@/lib/tauri/account';
import { useCurrencies } from '@/hooks/useCurrency';
import {
  useCompleteGoal,
  useSyncGoalProgress,
  useUpdateGoalProgress,
} from '@/hooks/useGoal';
import { useState } from 'react';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { toast } from 'sonner';

function getGoalStatusLabel(goal: GoalDto, t: (key: string) => string): string {
  if (goal.is_completed) return t('goals.completed');
  if (goal.is_overdue) return t('goals.overdue');
  if (goal.progress_percentage >= 100) return t('goals.completed');
  return t('goals.filterActive');
}

export function GoalDetailPage() {
  const { goalId } = useParams({ strict: false }) as { goalId: string };
  const navigate = useNavigate();
  const { t } = useTranslation();

  const [showProgressDialog, setShowProgressDialog] = useState(false);
  const [progressAmount, setProgressAmount] = useState('');

  // Fetch single goal directly
  const { data: singleGoal, isLoading: isLoadingSingle } = useQuery({
    queryKey: ['goal', goalId],
    queryFn: () => getGoal(goalId),
    enabled: !!goalId,
  });

  // Fallback: fetch all goals and find
  const { data: allGoals = [], isLoading: isLoadingAll } = useQuery({
    queryKey: ['goals'],
    queryFn: listGoals,
    enabled: !!goalId && !singleGoal,
  });

  const goal: GoalDto | undefined = singleGoal ?? allGoals.find((g) => g.id === goalId);
  const isLoading = isLoadingSingle || (isLoadingAll && !singleGoal);

  // Fetch accounts for linked account display
  const { data: accounts = [] } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
    enabled: !!goal,
  });

  const { data: currencies = [] } = useCurrencies();

  // Mutations
  const completeGoalMutation = useCompleteGoal();
  const syncProgressMutation = useSyncGoalProgress();
  const updateProgressMutation = useUpdateGoalProgress();

  // Get currency symbol
  const getCurrencySymbol = (code: string) => {
    const currency = currencies.find((c) => c.code === code);
    return currency?.symbol || code;
  };

  // Get linked account name
  const getAccountName = (accountId: string | null) => {
    if (!accountId) return null;
    const account = accounts.find((a) => a.id === accountId);
    return account?.name || accountId;
  };

  // Handle update progress
  const handleUpdateProgress = () => {
    if (!goal) return;
    if (!progressAmount || parseFloat(progressAmount) <= 0) {
      toast.error(t('goals.validAmountRequired'));
      return;
    }
    updateProgressMutation.mutate(
      { id: goal.id, amount: progressAmount },
      {
        onSuccess: () => {
          setShowProgressDialog(false);
          setProgressAmount('');
        },
      }
    );
  };

  if (isLoading) {
    return (
      <PageShell>
        <div className="flex items-center justify-center py-12">
          <div className="text-muted-foreground">{t('common.loading')}</div>
        </div>
      </PageShell>
    );
  }

  if (!goal) {
    return (
      <PageShell>
        <div className="flex items-center justify-center py-12">
          <div className="text-muted-foreground">{t('common.noResults')}</div>
        </div>
      </PageShell>
    );
  }

  const progressPct = goal.target_amount
    ? (parseFloat(goal.current_amount) / parseFloat(goal.target_amount)) * 100
    : 0;
  const clampedPct = Math.min(progressPct, 100);

  const statusBadgeClass = goal.is_completed
    ? 'bg-emerald-100 text-emerald-800'
    : goal.is_overdue
    ? 'bg-red-100 text-red-800'
    : getGoalTypeColor(goal.goal_type);

  return (
    <PageShell>
      <HeroCard
        icon={<Target className="h-5 w-5" />}
        name={goal.name}
        subtitle={getGoalTypeLabel(goal.goal_type, t)}
      >
        <div className="font-display text-4xl font-semibold">
          {getCurrencySymbol(goal.currency_code)}
          {formatGoalAmount(goal.current_amount)}
        </div>
        <div className="text-xs text-muted-foreground">
          {t('goals.of')} {getCurrencySymbol(goal.currency_code)}
          {formatGoalAmount(goal.target_amount)}
        </div>
        <div className="mt-3 h-2 rounded-full bg-border overflow-hidden w-full">
          <div
            className={`h-full rounded-full ${getGoalProgressColor(progressPct)}`}
            style={{ width: `${clampedPct}%` }}
          />
        </div>
        <div className="text-[11px] text-muted-foreground mt-1">
          {progressPct.toFixed(1)}%
        </div>
      </HeroCard>

      <div className="grid grid-cols-4 gap-3.5 mb-7">
        <StatCard
          label={t('goals.status')}
          value={getGoalStatusLabel(goal, t)}
        />
        <StatCard
          label={t('goals.deadline')}
          value={goal.deadline || '—'}
        />
        <StatCard
          label={t('common.currency')}
          value={goal.currency_code}
        />
        <StatCard
          label={t('goals.progress')}
          value={`${progressPct.toFixed(1)}%`}
          tagVariant={progressPct >= 100 ? 'positive' : progressPct >= 50 ? 'positive' : 'negative'}
        />
      </div>

      <DetailTwoCol
        main={
          <div className="rounded-[14px] border border-border bg-card p-5 space-y-4">
            <h3 className="text-sm font-semibold">
              {t('goals.progress')}
            </h3>

            {/* Progress breakdown */}
            <div className="grid grid-cols-3 gap-4">
              <div>
                <div className="text-xs text-muted-foreground">{t('goals.targetAmount')}</div>
                <div className="text-sm font-medium">
                  {getCurrencySymbol(goal.currency_code)}
                  {formatGoalAmount(goal.target_amount)}
                </div>
              </div>
              <div>
                <div className="text-xs text-muted-foreground">{t('goals.currentAmount')}</div>
                <div className="text-sm font-medium">
                  {getCurrencySymbol(goal.currency_code)}
                  {formatGoalAmount(goal.current_amount)}
                </div>
              </div>
              <div>
                <div className="text-xs text-muted-foreground">{t('goals.remaining')}</div>
                <div className={`text-sm font-medium ${parseFloat(goal.remaining_amount) <= 0 ? 'text-emerald-600' : 'text-amber-600'}`}>
                  {getCurrencySymbol(goal.currency_code)}
                  {formatGoalAmount(goal.remaining_amount)}
                </div>
              </div>
            </div>

            <Progress value={clampedPct} className="h-2">
              <div
                className={`h-full rounded-full ${getGoalProgressColor(progressPct)}`}
                style={{ width: `${clampedPct}%` }}
              />
            </Progress>

            <div className="flex justify-between text-xs text-muted-foreground">
              <span>{progressPct.toFixed(1)}%</span>
              <span className={getGoalStatusColor({
                is_completed: goal.is_completed,
                is_overdue: goal.is_overdue,
                progress_percentage: goal.progress_percentage,
              })}>
                {goal.is_completed ? t('goals.completed') : goal.is_overdue ? t('goals.overdue') : t('goals.filterActive')}
              </span>
            </div>

            {/* Action buttons */}
            <Separator />
            <div className="flex flex-wrap gap-2">
              {!goal.is_completed && (
                <>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setShowProgressDialog(true)}
                  >
                    <TrendingUp className="h-4 w-4 mr-1" />
                    {t('goals.addProgress')}
                  </Button>
                  {goal.linked_account_id && (
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => syncProgressMutation.mutate(goal.id)}
                      disabled={syncProgressMutation.isPending}
                    >
                      <RefreshCw className={`h-4 w-4 mr-1 ${syncProgressMutation.isPending ? 'animate-spin' : ''}`} />
                      {t('goals.syncProgress')}
                    </Button>
                  )}
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => completeGoalMutation.mutate(goal.id)}
                  >
                    <CheckCircle2 className="h-4 w-4 mr-1" />
                    {t('goals.markComplete')}
                  </Button>
                </>
              )}
            </div>
          </div>
        }
        side={
          <div className="rounded-[14px] border border-border bg-card p-5 space-y-4">
            <div>
              <div className="text-xs text-muted-foreground">{t('goals.goalType')}</div>
              <div className="text-sm">
                <Badge className={getGoalTypeColor(goal.goal_type)}>
                  {getGoalTypeLabel(goal.goal_type, t)}
                </Badge>
              </div>
            </div>

            <div>
              <div className="text-xs text-muted-foreground">{t('goals.status')}</div>
              <div className="text-sm">
                <Badge className={statusBadgeClass}>
                  {getGoalStatusLabel(goal, t)}
                </Badge>
              </div>
            </div>

            {goal.deadline && (
              <div>
                <div className="text-xs text-muted-foreground">{t('goals.deadline')}</div>
                <div className="text-sm">{goal.deadline}</div>
              </div>
            )}

            {goal.linked_account_id && (
              <div>
                <div className="text-xs text-muted-foreground">{t('goals.linkedAccount')}</div>
                <div className="text-sm flex items-center gap-1">
                  <DollarSign className="h-3 w-3" />
                  {getAccountName(goal.linked_account_id)}
                </div>
              </div>
            )}

            <div>
              <div className="text-xs text-muted-foreground">{t('common.currency')}</div>
              <div className="text-sm">{goal.currency_code}</div>
            </div>

            {goal.completed_at && (
              <div>
                <div className="text-xs text-muted-foreground">{t('goals.completedDate')}</div>
                <div className="text-sm">{goal.completed_at}</div>
              </div>
            )}

            {goal.notes && (
              <div>
                <div className="text-xs text-muted-foreground">{t('common.note')}</div>
                <div className="text-sm">{goal.notes}</div>
              </div>
            )}

            <Separator />
            <Button
              variant="outline"
              className="w-full"
              onClick={() => navigate({ to: '/goals' })}
            >
              {t('common.back')}
            </Button>
          </div>
        }
      />

      {/* Update Progress Dialog */}
      <Dialog
        open={showProgressDialog}
        onOpenChange={(open) => {
          setShowProgressDialog(open);
          if (!open) setProgressAmount('');
        }}
      >
        <DialogContent className="max-w-sm">
          <DialogHeader>
            <DialogTitle>{t('goals.addProgress')}</DialogTitle>
            <DialogDescription>
              {goal.name} - {t('goals.current')}:{' '}
              {getCurrencySymbol(goal.currency_code)}
              {formatGoalAmount(goal.current_amount)}
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
    </PageShell>
  );
}
