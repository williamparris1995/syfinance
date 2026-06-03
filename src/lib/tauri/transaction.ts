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
  invokeTauri<TransactionDto[]>('get_transactions_by_account', { accountId });

export const getTransactionsByDateRange = (startDate: string, endDate: string) =>
  invokeTauri<TransactionDto[]>('get_transactions_by_date_range', {
    startDate,
    endDate,
  });

export const updateTransaction = (id: string, dto: CreateTransactionDto) =>
  invokeTauri<string>('update_transaction', { id, dto });

export const deleteTransaction = (id: string) =>
  invokeTauri<void>('delete_transaction', { id });

export const batchDeleteTransactions = (ids: string[]) =>
  invokeTauri<number>('batch_delete_transactions', { ids });

export interface PageInfo {
  has_next_page: boolean;
  has_prev_page: boolean;
  next_cursor: string | null;
  prev_cursor: string | null;
}

export interface PaginatedResult<T> {
  items: T[];
  page_info: PageInfo;
}

export interface PaginatedTransactionQuery {
  first?: number;
  after?: string;
  before?: string;
  accountId?: string;
  startDate?: string;
  endDate?: string;
}

export const listTransactionsPaginated = (query: PaginatedTransactionQuery) =>
  invokeTauri<PaginatedResult<TransactionDto>>('list_transactions_paginated', { query });
