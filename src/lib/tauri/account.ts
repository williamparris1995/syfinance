import { invokeTauri } from '../tauri';

export type AccountType = 'Cash' | 'Bank' | 'CreditCard' | 'Investment' | 'Loan' | 'Other';

export interface CreateAccountDto {
  name: string;
  account_type: AccountType;
  currency_code: string;
  initial_balance: number;
  account_number?: string;
  institution?: string;
  credit_limit?: number;
  billing_day?: number;
  payment_due_day?: number;
  interest_rate?: number;
}

export interface UpdateAccountDto {
  name?: string;
  balance?: number;
}

export interface AccountDto {
  id: string;
  name: string;
  account_type: AccountType;
  chart_of_account_code: string;
  currency_code: string;
  balance: number;
  account_number?: string;
  institution?: string;
  credit_limit?: number;
  billing_day?: number;
  payment_due_day?: number;
  interest_rate?: number;
  created_at: string;
  updated_at: string;
  deleted_at?: string;
}

export interface AccountBalanceDto {
  amount: number;
  currency_code: string;
}

export const createAccount = (dto: CreateAccountDto) =>
  invokeTauri<AccountDto>('create_account', { dto });

export const updateAccount = (id: string, dto: UpdateAccountDto) =>
  invokeTauri<AccountDto>('update_account', { id, dto });

export const deleteAccount = (id: string) => invokeTauri<void>('delete_account', { id });

export const getAccount = (id: string) => invokeTauri<AccountDto>('get_account', { id });

export const listAccounts = () => invokeTauri<AccountDto[]>('list_accounts');

export const getAccountBalance = (id: string) =>
  invokeTauri<AccountBalanceDto>('get_account_balance', { id });
