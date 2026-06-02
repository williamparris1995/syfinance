import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import {
  listTransactionTemplates,
  getTransactionTemplate,
  createTransactionTemplate,
  updateTransactionTemplate,
  deleteTransactionTemplate,
  pauseTransactionTemplate,
  resumeTransactionTemplate,
} from '../lib/tauri/transactionTemplate';
import { getUserFriendlyError } from '../lib/error-handler';

export function useTransactionTemplates() {
  return useQuery({
    queryKey: ['transactionTemplates'],
    queryFn: listTransactionTemplates,
  });
}

export function useTransactionTemplate(id: string) {
  return useQuery({
    queryKey: ['transactionTemplate', id],
    queryFn: () => getTransactionTemplate(id),
    enabled: !!id,
  });
}

export function useCreateTransactionTemplate() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: createTransactionTemplate,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactionTemplates'] });
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      toast.success('Template created');
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });
}

export function useUpdateTransactionTemplate() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: updateTransactionTemplate,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactionTemplates'] });
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      toast.success('Template updated');
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });
}

export function useDeleteTransactionTemplate() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: deleteTransactionTemplate,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactionTemplates'] });
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      toast.success('Template deleted');
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });
}

export function usePauseTransactionTemplate() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: pauseTransactionTemplate,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactionTemplates'] });
      toast.success('Template paused');
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });
}

export function useResumeTransactionTemplate() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: resumeTransactionTemplate,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactionTemplates'] });
      toast.success('Template resumed');
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });
}
