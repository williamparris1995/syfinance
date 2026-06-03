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
  listTemplateTransactions,
} from '../lib/tauri/transactionTemplate';
import { getUserFriendlyError } from '../lib/error-handler';
import { useTranslation } from 'react-i18next';

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
  const { t } = useTranslation();

  return useMutation({
    mutationFn: createTransactionTemplate,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactionTemplates'] });
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      toast.success(t('transactionTemplate.createSuccess'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });
}

export function useUpdateTransactionTemplate() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: updateTransactionTemplate,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactionTemplates'] });
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      toast.success(t('transactionTemplate.updateSuccess'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });
}

export function useDeleteTransactionTemplate() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: deleteTransactionTemplate,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactionTemplates'] });
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      toast.success(t('transactionTemplate.deleteSuccess'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });
}

export function usePauseTransactionTemplate() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: pauseTransactionTemplate,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactionTemplates'] });
      toast.success(t('transactionTemplate.templatePaused'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });
}

export function useResumeTransactionTemplate() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: resumeTransactionTemplate,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactionTemplates'] });
      toast.success(t('transactionTemplate.templateResumed'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });
}

export function useListTemplateTransactions(templateId: string | null) {
  return useQuery({
    queryKey: ['templateTransactions', templateId],
    queryFn: () => listTemplateTransactions(templateId!),
    enabled: !!templateId,
  });
}
