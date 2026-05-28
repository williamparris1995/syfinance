import { invokeTauri } from '../tauri';

export interface BudgetDto {
  id: string;
  name: string;
  month: string;
  total_amount: string;
  total_actual: string;
  total_remaining: string;
  usage_percentage: number;
  currency_code: string;
  is_active: boolean;
  items: BudgetItemDto[];
}

export interface BudgetItemDto {
  id: string;
  category_account_id: string;
  planned_amount: string;
  actual_amount: string;
  remaining: string;
  usage_percentage: number;
  is_over_budget: boolean;
  notes: string | null;
}

export interface CreateBudgetDto {
  name: string;
  month: string;
  currency_code: string;
}

export interface AddBudgetItemDto {
  category_account_id: string;
  planned_amount: string;
  notes?: string;
}

export const listBudgets = () => invokeTauri<BudgetDto[]>('list_budgets');

export const getBudget = (id: string) =>
  invokeTauri<BudgetDto | null>('get_budget', { id });

export const getBudgetByMonth = (month: string) =>
  invokeTauri<BudgetDto | null>('get_budget_by_month', { month });

export const createBudget = (dto: CreateBudgetDto) =>
  invokeTauri<BudgetDto>('create_budget', { dto });

export const addBudgetItem = (budgetId: string, dto: AddBudgetItemDto) =>
  invokeTauri<BudgetDto>('add_budget_item', { budgetId, dto });

export const deleteBudget = (id: string) =>
  invokeTauri<void>('delete_budget', { id });

export const removeBudgetItem = (budgetId: string, itemId: string) =>
  invokeTauri<BudgetDto>('remove_budget_item', { budgetId, itemId });
