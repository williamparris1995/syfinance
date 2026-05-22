import { invoke } from '@tauri-apps/api/core';

export interface SimpleIncomeRequest {
  debitAccountId: string;
  creditAccountId: string;
  amount: string;
  date: string; // YYYY-MM-DD format
  description: string;
}

export interface SimpleExpenseRequest {
  debitAccountId: string;
  creditAccountId: string;
  amount: string;
  date: string; // YYYY-MM-DD format
  description: string;
}

export interface SimpleTransferRequest {
  fromAccountId: string;
  toAccountId: string;
  amount: string;
  date: string; // YYYY-MM-DD format
  description: string;
}

export async function createSimpleIncome(
  request: SimpleIncomeRequest
): Promise<string> {
  return invoke<string>('create_simple_income', {
    debitAccountId: request.debitAccountId,
    creditAccountId: request.creditAccountId,
    amount: request.amount,
    date: request.date,
    description: request.description,
  });
}

export async function createSimpleExpense(
  request: SimpleExpenseRequest
): Promise<string> {
  return invoke<string>('create_simple_expense', {
    debitAccountId: request.debitAccountId,
    creditAccountId: request.creditAccountId,
    amount: request.amount,
    date: request.date,
    description: request.description,
  });
}

export async function createSimpleTransfer(
  request: SimpleTransferRequest
): Promise<string> {
  return invoke<string>('create_simple_transfer', {
    fromAccountId: request.fromAccountId,
    toAccountId: request.toAccountId,
    amount: request.amount,
    date: request.date,
    description: request.description,
  });
}
