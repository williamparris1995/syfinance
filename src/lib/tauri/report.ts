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

export const getYoyComparison = (year1: number, year2: number) =>
  invokeTauri<YoyComparison>('get_yoy_comparison', { year1, year2 });
