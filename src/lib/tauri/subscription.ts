import { invokeTauri } from '../tauri';

export interface CreateSubscriptionDto {
  name: string;
  amount: number;
  direction: 'expense' | 'income';
  cycle: 'weekly' | 'monthly' | 'yearly' | 'custom';
  cycle_days?: number | null;
  billing_day?: number | null;
  next_billing_date: string;
  start_date: string;
  end_date?: string | null;
  auto_record?: boolean;
  source_account_id: string;
  category?: string | null;
  description?: string | null;
}

export interface UpdateSubscriptionDto {
  id: string;
  name?: string;
  amount?: number;
  direction?: 'expense' | 'income';
  cycle?: 'weekly' | 'monthly' | 'yearly' | 'custom';
  cycle_days?: number | null;
  billing_day?: number | null;
  next_billing_date?: string;
  end_date?: string | null;
  auto_record?: boolean;
  source_account_id?: string;
  category?: string | null;
  description?: string | null;
}

export interface SubscriptionDto {
  id: string;
  name: string;
  amount: number;
  direction: 'expense' | 'income';
  cycle: 'weekly' | 'monthly' | 'yearly' | 'custom';
  cycle_days: number | null;
  billing_day: number | null;
  next_billing_date: string;
  start_date: string;
  end_date: string | null;
  auto_record: boolean;
  paused: boolean;
  source_account_id: string;
  source_account_name: string;
  currency_code: string;
  category: string | null;
  description: string | null;
  last_transaction_id: string | null;
}

export interface SubscriptionFilters {
  direction?: string | null;
  cycle?: string | null;
  paused?: boolean | null;
}

export const createSubscription = (dto: CreateSubscriptionDto) =>
  invokeTauri<string>('create_subscription', { dto });

export const listSubscriptions = (filters?: SubscriptionFilters) =>
  invokeTauri<SubscriptionDto[]>('list_subscriptions', { filters: filters || null });

export const getSubscription = (id: string) =>
  invokeTauri<SubscriptionDto>('get_subscription', { id });

export const updateSubscription = (dto: UpdateSubscriptionDto) =>
  invokeTauri<void>('update_subscription', { dto });

export const deleteSubscription = (id: string) =>
  invokeTauri<void>('delete_subscription', { id });

export const pauseSubscription = (id: string) =>
  invokeTauri<void>('pause_subscription', { id });

export const resumeSubscription = (id: string) =>
  invokeTauri<void>('resume_subscription', { id });

export const listSubscriptionTransactions = (subscriptionId: string) =>
  invokeTauri<any[]>('list_subscription_transactions', { subscriptionId });
