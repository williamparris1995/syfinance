import { invokeTauri } from '../tauri';

export interface CreateTransactionEntryDto {
  account_id: string;
  chart_of_account_code: string;
  debit_amount: string | null;
  credit_amount: string | null;
  memo: string | null;
  category_id?: string;
}

export interface CreateTransactionDto {
  transaction_date: string; // YYYY-MM-DD format
  description: string;
  entries: CreateTransactionEntryDto[];
}

export interface TransactionEntryDto {
  account_id: string;
  chart_of_account_code: string;
  debit_amount: string | null;
  credit_amount: string | null;
  currency_code: string;
  memo: string | null;
  category_id?: string;
}

export interface TransactionDto {
  id: string;
  transaction_date: string; // YYYY-MM-DD format
  description: string;
  entries: TransactionEntryDto[];
  created_at: string;
  updated_at: string;
}

export const createTransaction = (dto: CreateTransactionDto) =>
  invokeTauri<string>('create_transaction', { dto });

export const getTransaction = (id: string) =>
  invokeTauri<TransactionDto>('get_transaction', { id });

export const listTransactions = () =>
  invokeTauri<TransactionDto[]>('list_transactions');

export const getTransactionsByAccount = (accountId: string) =>
  invokeTauri<TransactionDto[]>('get_transactions_by_account', { account_id: accountId });

export const getTransactionsByDateRange = (startDate: string, endDate: string) =>
  invokeTauri<TransactionDto[]>('get_transactions_by_date_range', {
    start_date: startDate,
    end_date: endDate,
  });

export const updateTransaction = (id: string, dto: CreateTransactionDto) =>
  invokeTauri<string>('update_transaction', { id, dto });

export const deleteTransaction = (id: string) =>
  invokeTauri<void>('delete_transaction', { id });
