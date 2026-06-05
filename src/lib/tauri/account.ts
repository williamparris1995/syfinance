import { invokeTauri } from '../tauri';

export type AccountType = 'Cash' | 'Bank' | 'CreditCard' | 'Investment' | 'BorrowedOut' | 'BorrowedIn' | 'Prepaid' | 'Other' | 'Income' | 'Expense';

export type Ownership = 'own' | 'external';

export interface CreateAccountDto {
  name: string;
  account_type: AccountType;
  ownership: Ownership;
  currency_code: string;
  initial_balance: number;
  icon: string;
  color: string;
  chart_code?: string | null;
  parent_id?: string | null;
  account_number?: string;
  institution?: string;
  credit_limit?: number;
  billing_day?: number;
  payment_due_day?: number;
  interest_rate?: number;
  low_balance_threshold?: number;
}

export interface UpdateAccountDto {
  name: string;
  initial_balance: number;
  icon?: string;
  color?: string;
  currency_code?: string;
  account_number?: string;
  institution?: string;
  credit_limit?: number;
  billing_day?: number;
  payment_due_day?: number;
  interest_rate?: number;
  low_balance_threshold?: number;
  chart_code?: string;
  parent_id?: string;
}

export interface AccountDto {
  id: string;
  name: string;
  account_type: AccountType;
  ownership: Ownership;
  icon: string;
  color: string;
  chart_code?: string | null;
  parent_id?: string | null;
  currency_code: string;
  initial_balance: number;
  current_balance: number;
  account_number?: string;
  institution?: string;
  credit_limit?: number;
  billing_day?: number;
  payment_due_day?: number;
  interest_rate?: number;
  low_balance_threshold?: number | null;
  status: string;
  opened_at?: string | null;
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

export const listAccountsByOwnership = (ownership: 'own' | 'external') =>
  invokeTauri<AccountDto[]>('list_accounts_by_ownership', { ownership });

export const getAccountBalance = (id: string) =>
  invokeTauri<AccountBalanceDto>('get_account_balance', { id });

export const listAccountsWithBalances = () =>
  invokeTauri<AccountDto[]>('list_accounts_with_balances');

export interface BalanceHistoryPoint {
  date: string;
  balance: string;
}

export const getAccountBalanceHistory = (accountId: string, days?: number) =>
  invokeTauri<BalanceHistoryPoint[]>('get_account_balance_history', { accountId, days });

export interface InvestmentTemplate {
  name: string;
  chart_code: string;
  icon: string;
  color: string;
}

export const INVESTMENT_TEMPLATES: InvestmentTemplate[] = [
  { name: 'stockAccount', chart_code: '1101', icon: 'TrendingUp', color: '#EF4444' },
  { name: 'fundAccount', chart_code: '1101', icon: 'BarChart3', color: '#3B82F6' },
  { name: 'etfAccount', chart_code: '1101', icon: 'Layers', color: '#8B5CF6' },
  { name: 'bondAccount', chart_code: '1501', icon: 'Landmark', color: '#10B981' },
  { name: 'goldAccount', chart_code: '1101', icon: 'Coins', color: '#F59E0B' },
  { name: 'optionAccount', chart_code: '1101', icon: 'GitBranch', color: '#F97316' },
  { name: 'otherInvestment', chart_code: '1012', icon: 'Wallet', color: '#6B7280' },
];

export const setupPresetInvestmentAccounts = (currencyCode?: string) =>
  invokeTauri<AccountDto[]>('setup_preset_investment_accounts', {
    currencyCode: currencyCode ?? 'CNY',
  });
