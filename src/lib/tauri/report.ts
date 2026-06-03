import { invokeTauri } from '../tauri';

export interface YoyMonthData {
  month: number;
  year1_income: string;
  year1_expense: string;
  year2_income: string;
  year2_expense: string;
  income_change_pct: number | null;
  expense_change_pct: number | null;
}

export interface YoyComparison {
  year1: number;
  year2: number;
  months: YoyMonthData[];
}

export interface BalanceSheetItem {
  account_id: string;
  account_name: string;
  account_type: string;
  balance: string;
  currency_code: string;
}

export interface BalanceSheet {
  as_of_date: string;
  assets: BalanceSheetItem[];
  liabilities: BalanceSheetItem[];
  total_assets: string;
  total_liabilities: string;
  equity: string;
}

export interface IncomeStatementItem {
  account_id: string;
  account_name: string;
  amount: string;
  transaction_count: number;
}

export interface IncomeStatement {
  start_date: string;
  end_date: string;
  income: IncomeStatementItem[];
  expenses: IncomeStatementItem[];
  total_income: string;
  total_expenses: string;
  net_income: string;
}

export interface DashboardSummary {
  start_date: string;
  end_date: string;
  total_income: string;
  total_expenses: string;
  net_savings: string;
  income_by_category: IncomeStatementItem[];
  expense_by_category: IncomeStatementItem[];
}

export const getYoyComparison = (year1: number, year2: number) =>
  invokeTauri<YoyComparison>('get_yoy_comparison', { year1, year2 });

export const getBalanceSheet = (asOfDate: string) =>
  invokeTauri<BalanceSheet>('get_balance_sheet', { asOfDate: asOfDate });

export const getIncomeStatement = (startDate: string, endDate: string) =>
  invokeTauri<IncomeStatement>('get_income_statement', {
    query: { start_date: startDate, end_date: endDate },
  });

export const getDashboardSummary = (startDate: string, endDate: string) =>
  invokeTauri<DashboardSummary>('get_dashboard_summary', {
    query: { start_date: startDate, end_date: endDate },
  });

export interface MonthlyTrendItem {
  month: string;
  income: string;
  expenses: string;
  expense_categories: Record<string, string>;
  income_categories: Record<string, string>;
}

export const getMonthlyTrend = (startDate: string, endDate: string) =>
  invokeTauri<MonthlyTrendItem[]>('get_monthly_trend', {
    query: { start_date: startDate, end_date: endDate },
  });
