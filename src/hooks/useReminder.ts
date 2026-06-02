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
import { useTranslation } from 'react-i18next';

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
  const { t } = useTranslation();
  return useMutation({
    mutationFn: (dto: CreateReminderDto) => createReminder(dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['reminders'] });
      toast.success(t('reminders.createSuccess'));
    },
    onError: (error) => {
      toast.error(t('reminders.createFailed', { error: String(error) }));
    },
  });
}

export function useUpdateReminder() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: ({ id, dto }: { id: string; dto: UpdateReminderDto }) =>
      updateReminder(id, dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['reminders'] });
      toast.success(t('reminders.updateSuccess'));
    },
    onError: (error) => {
      toast.error(t('reminders.updateFailed', { error: String(error) }));
    },
  });
}

export function useDeleteReminder() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: (id: string) => deleteReminder(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['reminders'] });
      toast.success(t('reminders.deleteSuccess'));
    },
    onError: (error) => {
      toast.error(t('reminders.deleteFailed', { error: String(error) }));
    },
  });
}

export function useCompleteReminder() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: (id: string) => completeReminder(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['reminders'] });
      toast.success(t('reminders.completeSuccess'));
    },
    onError: (error) => {
      toast.error(t('reminders.completeFailed', { error: String(error) }));
    },
  });
}
