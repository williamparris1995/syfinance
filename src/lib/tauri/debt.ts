import { invokeTauri } from '../tauri';

export type DebtType = 'BorrowedOut' | 'BorrowedIn' | 'CreditCard' | 'Loan';
export type AmortizationMethod = 'EqualPrincipalInterest' | 'EqualPrincipal';

export interface CreateDebtDto {
  debt_type: DebtType;
  counterparty: string;
  principal_amount: string;
  currency_code: string;
  interest_rate: string;
  start_date: string; // YYYY-MM-DD format
  due_date: string; // YYYY-MM-DD format
  amortization_method: AmortizationMethod | null;
}

export interface PaymentScheduleDto {
  payment_date: string; // YYYY-MM-DD format
  principal_amount: string;
  interest_amount: string;
  total_amount: string;
  currency_code: string;
  paid: boolean;
}

export interface DebtDto {
  id: string;
  debt_type: DebtType;
  counterparty: string;
  principal_amount: string;
  currency_code: string;
  interest_rate: string;
  start_date: string; // YYYY-MM-DD format
  due_date: string; // YYYY-MM-DD format
  payment_schedule: PaymentScheduleDto[];
  remaining_balance: string;
  created_at: string;
  updated_at: string;
}

export interface RecordPaymentDto {
  debt_id: string;
  payment_date: string; // YYYY-MM-DD format
  transaction_id: string;
}

export interface UpcomingPaymentDto {
  debt: DebtDto;
  payment: PaymentScheduleDto;
}

export const createDebt = (dto: CreateDebtDto) =>
  invokeTauri<DebtDto>('create_debt', { dto });

export const getDebt = (id: string) => invokeTauri<DebtDto>('get_debt', { id });

export const listDebts = () => invokeTauri<DebtDto[]>('list_debts');

export const recordPayment = (dto: RecordPaymentDto) =>
  invokeTauri<void>('record_payment', { dto });

export const getUpcomingPayments = (daysAhead: number) =>
  invokeTauri<UpcomingPaymentDto[]>('get_upcoming_payments', { daysAhead });
