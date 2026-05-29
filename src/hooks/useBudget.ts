import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  listBudgets,
  getBudget,
  getBudgetByMonth,
  createBudget,
  addBudgetItem,
  deleteBudget,
  removeBudgetItem,
  CreateBudgetDto,
  AddBudgetItemDto,
} from '../lib/tauri/budget';
import { toast } from 'sonner';

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

  return useMutation({
    mutationFn: (dto: CreateBudgetDto) => createBudget(dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgets'] });
      toast.success('预算创建成功');
    },
    onError: (error) => {
      toast.error(`创建预算失败: ${error}`);
    },
  });
}

export function useAddBudgetItem() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ budgetId, dto }: { budgetId: string; dto: AddBudgetItemDto }) =>
      addBudgetItem(budgetId, dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgets'] });
      queryClient.invalidateQueries({ queryKey: ['budget'] });
      toast.success('预算项添加成功');
    },
    onError: (error) => {
      toast.error(`添加预算项失败: ${error}`);
    },
  });
}

export function useDeleteBudget() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => deleteBudget(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgets'] });
      toast.success('预算删除成功');
    },
    onError: (error) => {
      toast.error(`删除预算失败: ${error}`);
    },
  });
}

export function useRemoveBudgetItem() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ budgetId, itemId }: { budgetId: string; itemId: string }) =>
      removeBudgetItem(budgetId, itemId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgets'] });
      queryClient.invalidateQueries({ queryKey: ['budget'] });
      toast.success('预算项删除成功');
    },
    onError: (error) => {
      toast.error(`删除预算项失败: ${error}`);
    },
  });
}
