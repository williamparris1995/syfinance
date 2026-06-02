import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  listGoals,
  getGoal,
  createGoal,
  updateGoal,
  updateGoalProgress,
  completeGoal,
  deleteGoal,
  syncGoalProgress,
  CreateGoalDto,
  UpdateGoalDto,
} from '../lib/tauri/goal';
import { toast } from 'sonner';
import { useTranslation } from 'react-i18next';

export function useGoals() {
  return useQuery({ queryKey: ['goals'], queryFn: listGoals });
}

export function useGoal(id: string) {
  return useQuery({
    queryKey: ['goal', id],
    queryFn: () => getGoal(id),
    enabled: !!id,
  });
}

export function useCreateGoal() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: (dto: CreateGoalDto) => createGoal(dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['goals'] });
      toast.success(t('goals.goalCreated'));
    },
    onError: (error) => {
      toast.error(t('goals.goalCreateFailed', { error: String(error) }));
    },
  });
}

export function useUpdateGoal() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: ({ id, dto }: { id: string; dto: UpdateGoalDto }) =>
      updateGoal(id, dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['goals'] });
      toast.success(t('goals.goalUpdated'));
    },
    onError: (error) => {
      toast.error(t('goals.goalUpdateFailed', { error: String(error) }));
    },
  });
}

export function useUpdateGoalProgress() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: ({ id, amount }: { id: string; amount: string }) =>
      updateGoalProgress(id, amount),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['goals'] });
      toast.success(t('goals.goalProgressUpdated'));
    },
    onError: (error) => {
      toast.error(t('goals.goalProgressFailed', { error: String(error) }));
    },
  });
}

export function useCompleteGoal() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: (id: string) => completeGoal(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['goals'] });
      toast.success(t('goals.goalCompleted'));
    },
    onError: (error) => {
      toast.error(t('goals.goalCompleteFailed', { error: String(error) }));
    },
  });
}

export function useDeleteGoal() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: (id: string) => deleteGoal(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['goals'] });
      toast.success(t('goals.goalDeleted'));
    },
    onError: (error) => {
      toast.error(t('goals.goalDeleteFailed', { error: String(error) }));
    },
  });
}

export function useSyncGoalProgress() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: (goalId: string) => syncGoalProgress(goalId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['goals'] });
      toast.success(t('goals.goalProgressSynced'));
    },
    onError: (error) => {
      toast.error(t('goals.goalProgressSyncFailed', { error: String(error) }));
    },
  });
}
