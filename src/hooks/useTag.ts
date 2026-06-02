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

export function useTags() {
  return useQuery({ queryKey: ['tags'], queryFn: listTags });
}

export function useCreateTag() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (dto: CreateTagDto) => createTag(dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tags'] });
      toast.success('Tag created');
    },
    onError: (error) => {
      toast.error(`Failed to create tag: ${error}`);
    },
  });
}

export function useDeleteTag() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => deleteTag(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tags'] });
      toast.success('Tag deleted');
    },
    onError: (error) => {
      toast.error(`Failed to delete tag: ${error}`);
    },
  });
}

export function useUpdateTag() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, name, color }: { id: string; name?: string; color?: string }) =>
      updateTag(id, name, color),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tags'] });
      toast.success('Tag updated');
    },
    onError: (error) => {
      toast.error(`Failed to update tag: ${error}`);
    },
  });
}

export function useSoftDeleteTag() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => softDeleteTag(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tags'] });
      toast.success('Tag deleted');
    },
    onError: (error) => {
      toast.error(`Failed to delete tag: ${error}`);
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
  return useMutation({
    mutationFn: ({ transactionId, tagId }: { transactionId: string; tagId: string }) =>
      addTagToTransaction(transactionId, tagId),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: ['transaction-tags', variables.transactionId] });
      toast.success('Tag added');
    },
    onError: (error) => {
      toast.error(`Failed to add tag: ${error}`);
    },
  });
}

export function useRemoveTagFromTransaction() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ transactionId, tagId }: { transactionId: string; tagId: string }) =>
      removeTagFromTransaction(transactionId, tagId),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: ['transaction-tags', variables.transactionId] });
      toast.success('Tag removed');
    },
    onError: (error) => {
      toast.error(`Failed to remove tag: ${error}`);
    },
  });
}
