import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  listReminders,
  getReminder,
  createReminder,
  updateReminder,
  deleteReminder,
  completeReminder,
  type CreateReminderDto,
  type UpdateReminderDto,
} from '../lib/tauri/reminder';
import { toast } from 'sonner';

export function useReminders() {
  return useQuery({
    queryKey: ['reminders'],
    queryFn: listReminders,
    staleTime: 5 * 60 * 1000,
  });
}

export function useReminder(id: string) {
  return useQuery({
    queryKey: ['reminder', id],
    queryFn: () => getReminder(id),
    enabled: !!id,
  });
}

export function useCreateReminder() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (dto: CreateReminderDto) => createReminder(dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['reminders'] });
      toast.success('reminder created');
    },
    onError: (error) => {
      toast.error(`Failed to create reminder: ${error}`);
    },
  });
}

export function useUpdateReminder() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, dto }: { id: string; dto: UpdateReminderDto }) =>
      updateReminder(id, dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['reminders'] });
      toast.success('reminder updated');
    },
    onError: (error) => {
      toast.error(`Failed to update reminder: ${error}`);
    },
  });
}

export function useDeleteReminder() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => deleteReminder(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['reminders'] });
      toast.success('reminder deleted');
    },
    onError: (error) => {
      toast.error(`Failed to delete reminder: ${error}`);
    },
  });
}

export function useCompleteReminder() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => completeReminder(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['reminders'] });
      toast.success('reminder completed');
    },
    onError: (error) => {
      toast.error(`Failed to complete reminder: ${error}`);
    },
  });
}
