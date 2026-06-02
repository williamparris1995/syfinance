import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  listTags,
  createTag,
  deleteTag,
  updateTag,
  softDeleteTag,
  addTagToTransaction,
  removeTagFromTransaction,
  getTransactionTags,
  CreateTagDto,
} from '../lib/tauri/tag';
import { toast } from 'sonner';
import { useTranslation } from 'react-i18next';

export function useTags() {
  return useQuery({ queryKey: ['tags'], queryFn: listTags });
}

export function useCreateTag() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: (dto: CreateTagDto) => createTag(dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tags'] });
      toast.success(t('tags.tagCreated'));
    },
    onError: (error) => {
      toast.error(t('tags.tagCreateFailed', { error: String(error) }));
    },
  });
}

export function useDeleteTag() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: (id: string) => deleteTag(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tags'] });
      toast.success(t('tags.tagDeleted'));
    },
    onError: (error) => {
      toast.error(t('tags.tagDeleteFailed', { error: String(error) }));
    },
  });
}

export function useUpdateTag() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: ({ id, name, color }: { id: string; name?: string; color?: string }) =>
      updateTag(id, name, color),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tags'] });
      toast.success(t('tags.tagUpdated'));
    },
    onError: (error) => {
      toast.error(t('tags.tagUpdateFailed', { error: String(error) }));
    },
  });
}

export function useSoftDeleteTag() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: (id: string) => softDeleteTag(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tags'] });
      toast.success(t('tags.tagSoftDeleted'));
    },
    onError: (error) => {
      toast.error(t('tags.tagSoftDeleteFailed', { error: String(error) }));
    },
  });
}

export function useTransactionTags(transactionId: string) {
  return useQuery({
    queryKey: ['transaction-tags', transactionId],
    queryFn: () => getTransactionTags(transactionId),
    enabled: !!transactionId,
  });
}

export function useAddTagToTransaction() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: ({ transactionId, tagId }: { transactionId: string; tagId: string }) =>
      addTagToTransaction(transactionId, tagId),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: ['transaction-tags', variables.transactionId] });
      toast.success(t('tags.tagAdded'));
    },
    onError: (error) => {
      toast.error(t('tags.tagAddFailed', { error: String(error) }));
    },
  });
}

export function useRemoveTagFromTransaction() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: ({ transactionId, tagId }: { transactionId: string; tagId: string }) =>
      removeTagFromTransaction(transactionId, tagId),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: ['transaction-tags', variables.transactionId] });
      toast.success(t('tags.tagRemoved'));
    },
    onError: (error) => {
      toast.error(t('tags.tagRemoveFailed', { error: String(error) }));
    },
  });
}
