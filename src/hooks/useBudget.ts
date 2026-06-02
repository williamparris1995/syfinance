import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  listBudgets,
  getBudget,
  getBudgetByMonth,
  createBudget,
  addBudgetItem,
  deleteBudget,
  removeBudgetItem,
  computeBudgetActuals,
  cloneBudgetToMonth,
  CreateBudgetDto,
  AddBudgetItemDto,
} from '../lib/tauri/budget';
import { toast } from 'sonner';
import { useTranslation } from 'react-i18next';

export function useBudgets() {
  return useQuery({
    queryKey: ['budgets'],
    queryFn: listBudgets,
  });
}

export function useBudget(id: string) {
  return useQuery({
    queryKey: ['budget', id],
    queryFn: () => getBudget(id),
    enabled: !!id,
  });
}

export function useBudgetByMonth(month: string) {
  return useQuery({
    queryKey: ['budget', 'month', month],
    queryFn: () => getBudgetByMonth(month),
    enabled: !!month,
  });
}

export function useCreateBudget() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: (dto: CreateBudgetDto) => createBudget(dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgets'] });
      toast.success(t('budget.budgetCreated'));
    },
    onError: (error) => {
      toast.error(t('budget.budgetCreateFailed', { error: String(error) }));
    },
  });
}

export function useAddBudgetItem() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: ({ budgetId, dto }: { budgetId: string; dto: AddBudgetItemDto }) =>
      addBudgetItem(budgetId, dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgets'] });
      queryClient.invalidateQueries({ queryKey: ['budget'] });
      toast.success(t('budget.budgetItemAdded'));
    },
    onError: (error) => {
      toast.error(t('budget.budgetItemAddFailed', { error: String(error) }));
    },
  });
}

export function useDeleteBudget() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: (id: string) => deleteBudget(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgets'] });
      toast.success(t('budget.budgetDeleted'));
    },
    onError: (error) => {
      toast.error(t('budget.budgetDeleteFailed', { error: String(error) }));
    },
  });
}

export function useRemoveBudgetItem() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: ({ budgetId, itemId }: { budgetId: string; itemId: string }) =>
      removeBudgetItem(budgetId, itemId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgets'] });
      queryClient.invalidateQueries({ queryKey: ['budget'] });
      toast.success(t('budget.budgetItemRemoved'));
    },
    onError: (error) => {
      toast.error(t('budget.budgetItemRemoveFailed', { error: String(error) }));
    },
  });
}

export function useComputeBudgetActuals() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (budgetId: string) => computeBudgetActuals(budgetId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgets'] });
      queryClient.invalidateQueries({ queryKey: ['budget'] });
    },
  });
}

export function useCloneBudgetToMonth() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: ({ sourceBudgetId, targetMonth }: { sourceBudgetId: string; targetMonth: string }) =>
      cloneBudgetToMonth(sourceBudgetId, targetMonth),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgets'] });
      queryClient.invalidateQueries({ queryKey: ['budget'] });
      toast.success(t('budget.budgetCloned'));
    },
    onError: (error) => {
      toast.error(t('budget.budgetCloneFailed', { error: String(error) }));
    },
  });
}
