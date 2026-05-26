import { invokeTauri } from '../tauri';
import type { AccountType } from './account';

export type AmortizationMethod = 'EqualPrincipalInterest' | 'EqualPrincipal' | 'LumpSum';

export interface CreateDebtDto {
  account_id: string;
  counterparty: string;
  principal_amount: string;
  currency_code: string;
  interest_rate: string;
  start_date: string | null;
  due_date: string | null;
  amortization_method: AmortizationMethod | null;
}

export interface PaymentScheduleDto {
  id: string;
  payment_date: string;
  principal_amount: string;
  interest_amount: string;
  total_amount: string;
  paid: boolean;
  transaction_id?: string | null;
}

export interface DebtDto {
  account_id: string;
  account_name: string;
  account_type: AccountType;
  counterparty: string;
  principal_amount: string;
  remaining_principal: string;
  currency_code: string;
  interest_rate: string;
  start_date: string;
  due_date: string;
  amortization_method: string;
  payment_schedule: PaymentScheduleDto[];
}

export interface RecordPaymentDto {
  schedule_entry_id: string;
  payment_source_account_id: string;
  interest_account_id?: string | null;
}

export const createDebt = (dto: CreateDebtDto) =>
  invokeTauri<DebtDto>('create_debt', { dto });

export const getDebt = (id: string) => invokeTauri<DebtDto>('get_debt', { id });

export const listDebts = () => invokeTauri<DebtDto[]>('list_debts');

export const recordPayment = (dto: RecordPaymentDto) =>
  invokeTauri<string>('record_payment', { dto });

export const getUpcomingPayments = (daysAhead: number) =>
  invokeTauri<DebtDto[]>('get_upcoming_payments', { daysAhead });
