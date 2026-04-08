export type Uuid = string;
export type IsoDate = string;
export type DebtType = 'borrowed_out' | 'borrowed_in' | 'credit_card' | 'loan';
export type AmortizationMethod = 'equal_principal_interest' | 'equal_principal';

export interface CreateDebtInput {
  debt_type: DebtType;
  counterparty: string;
  principal_amount: string;
  currency_code: string;
  interest_rate: string;
  start_date: IsoDate;
  due_date: IsoDate;
  amortization_method?: AmortizationMethod | null;
}

export interface PaymentSchedule {
  payment_date: IsoDate;
  principal_amount: string;
  interest_amount: string;
  total_amount: string;
  currency_code: string;
  paid: boolean;
}

export interface Debt {
  id: Uuid;
  debt_type: DebtType;
  counterparty: string;
  principal_amount: string;
  currency_code: string;
  interest_rate: string;
  start_date: IsoDate;
  due_date: IsoDate;
  payment_schedule: PaymentSchedule[];
  remaining_balance: string;
  created_at: string;
  updated_at: string;
}

export interface RecordPaymentInput {
  debt_id: Uuid;
  payment_date: IsoDate;
  transaction_id: Uuid;
}

export interface UpcomingPayment {
  debt: Debt;
  payment: PaymentSchedule;
}
