import { invokeTauri } from '../tauri';

export interface ReminderDto {
  id: string;
  reminder_type: string;
  related_entity_id: string | null;
  title: string;
  description: string;
  remind_at: string;
  repeat_pattern: string | null;
  priority: string;
  notified: boolean;
  last_notified_at: string | null;
  notification_count: number;
}

export interface CreateReminderDto {
  title: string;
  description?: string | null;
  reminder_type?: string | null;
  related_entity_id?: string | null;
  remind_at: string;
  repeat_pattern?: string | null;
  priority?: string | null;
}

export interface UpdateReminderDto {
  title?: string;
  description?: string;
  remind_at?: string;
  repeat_pattern?: string;
  priority?: string;
}

export const listReminders = () => invokeTauri<ReminderDto[]>('list_reminders');

export const getReminder = (id: string) =>
  invokeTauri<ReminderDto>('get_reminder', { id });

export const createReminder = (dto: CreateReminderDto) =>
  invokeTauri<ReminderDto>('create_reminder', { dto });

export const updateReminder = (id: string, dto: UpdateReminderDto) =>
  invokeTauri<ReminderDto>('update_reminder', { id, dto });

export const deleteReminder = (id: string) =>
  invokeTauri<void>('delete_reminder', { id });

export const completeReminder = (id: string) =>
  invokeTauri<void>('complete_reminder', { id });
