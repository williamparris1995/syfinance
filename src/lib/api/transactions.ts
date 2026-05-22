import { invoke } from '@tauri-apps/api/core';

export interface SimpleIncomeRequest {
  accountId: string;
  categoryId: string;
  amount: string;
  date: string; // YYYY-MM-DD format
  description: string;
}

export interface SimpleExpenseRequest {
  accountId: string;
  categoryId: string;
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
    accountId: request.accountId,
    categoryId: request.categoryId,
    amount: request.amount,
    date: request.date,
    description: request.description,
  });
}

export async function createSimpleExpense(
  request: SimpleExpenseRequest
): Promise<string> {
  return invoke<string>('create_simple_expense', {
    accountId: request.accountId,
    categoryId: request.categoryId,
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
