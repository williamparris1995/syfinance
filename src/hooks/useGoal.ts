import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  listGoals,
  getGoal,
  createGoal,
  updateGoal,
  updateGoalProgress,
  completeGoal,
  deleteGoal,
  GoalDto,
  CreateGoalDto,
  UpdateGoalDto,
} from '../lib/tauri/goal';
import { toast } from 'sonner';

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
  return useMutation({
    mutationFn: (dto: CreateGoalDto) => createGoal(dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['goals'] });
      toast.success('目标创建成功');
    },
    onError: (error) => {
      toast.error(`创建目标失败: ${error}`);
    },
  });
}

export function useUpdateGoal() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, dto }: { id: string; dto: UpdateGoalDto }) =>
      updateGoal(id, dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['goals'] });
      toast.success('目标更新成功');
    },
    onError: (error) => {
      toast.error(`更新目标失败: ${error}`);
    },
  });
}

export function useUpdateGoalProgress() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, amount }: { id: string; amount: string }) =>
      updateGoalProgress(id, amount),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['goals'] });
      toast.success('进度更新成功');
    },
    onError: (error) => {
      toast.error(`更新进度失败: ${error}`);
    },
  });
}

export function useCompleteGoal() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => completeGoal(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['goals'] });
      toast.success('目标已完成！');
    },
    onError: (error) => {
      toast.error(`完成目标失败: ${error}`);
    },
  });
}

export function useDeleteGoal() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => deleteGoal(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['goals'] });
      toast.success('目标删除成功');
    },
    onError: (error) => {
      toast.error(`删除目标失败: ${error}`);
    },
  });
}
