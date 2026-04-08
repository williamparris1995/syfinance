export type Uuid = string;
export type IsoDate = string;

export interface CreateTransactionEntryInput {
  account_id: Uuid;
  chart_of_account_code: string;
  debit_amount: string | null;
  credit_amount: string | null;
  memo: string | null;
}

export interface CreateTransactionInput {
  transaction_date: IsoDate;
  description: string;
  entries: CreateTransactionEntryInput[];
}

export interface TransactionEntry {
  account_id: Uuid;
  chart_of_account_code: string;
  debit_amount: string | null;
  credit_amount: string | null;
  currency_code: string;
  memo: string | null;
}

export interface Transaction {
  id: Uuid;
  transaction_date: IsoDate;
  description: string;
  entries: TransactionEntry[];
  created_at: string;
  updated_at: string;
}

export interface TransactionDateRangeInput {
  start_date: IsoDate;
  end_date: IsoDate;
}
