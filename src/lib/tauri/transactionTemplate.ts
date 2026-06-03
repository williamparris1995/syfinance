import { invokeTauri } from '../tauri';

export interface CreateTransactionTemplateDto {
  name: string;
  description?: string | null;
  amount: string;
  direction: 'expense' | 'income' | 'transfer';
  source_account_id: string;
  destination_account_id?: string | null;
  cycle: 'weekly' | 'monthly' | 'yearly' | 'custom';
  cycle_days?: number | null;
  billing_day?: number | null;
  next_date: string;
  start_date: string;
  end_date?: string | null;
  auto_record?: boolean;
  category?: string | null;
}

export interface UpdateTransactionTemplateDto {
  id: string;
  name?: string;
  description?: string | null;
  amount?: string;
  direction?: 'expense' | 'income' | 'transfer';
  source_account_id?: string;
  destination_account_id?: string | null;
  cycle?: 'weekly' | 'monthly' | 'yearly' | 'custom';
  cycle_days?: number | null;
  billing_day?: number | null;
  next_date?: string;
  end_date?: string | null;
  auto_record?: boolean;
  category?: string | null;
}

export interface TransactionTemplateDto {
  id: string;
  name: string;
  description: string | null;
  amount: string;
  direction: 'expense' | 'income' | 'transfer';
  source_account_id: string;
  source_account_name: string;
  destination_account_id: string | null;
  destination_account_name: string | null;
  currency_code: string;
  cycle: 'weekly' | 'monthly' | 'yearly' | 'custom';
  cycle_days: number | null;
  billing_day: number | null;
  next_date: string;
  start_date: string;
  end_date: string | null;
  auto_record: boolean;
  paused: boolean;
  last_transaction_id: string | null;
  category: string | null;
}

export const listTransactionTemplates = () =>
  invokeTauri<TransactionTemplateDto[]>('list_transaction_templates');

export const getTransactionTemplate = (id: string) =>
  invokeTauri<TransactionTemplateDto>('get_transaction_template', { id });

export const createTransactionTemplate = (dto: CreateTransactionTemplateDto) =>
  invokeTauri<string>('create_transaction_template', { dto });

export const updateTransactionTemplate = (dto: UpdateTransactionTemplateDto) =>
  invokeTauri<void>('update_transaction_template', { dto });

export const deleteTransactionTemplate = (id: string) =>
  invokeTauri<void>('delete_transaction_template', { id });

export const pauseTransactionTemplate = (id: string) =>
  invokeTauri<void>('pause_transaction_template', { id });

export const resumeTransactionTemplate = (id: string) =>
  invokeTauri<void>('resume_transaction_template', { id });

export const listTemplateTransactions = (templateId: string) =>
  invokeTauri<import('./transaction').TransactionDto[]>('list_template_transactions', { templateId });
