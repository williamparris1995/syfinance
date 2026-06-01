import { invokeTauri } from '../tauri';

export interface ExportDataDto {
  accounts: Record<string, unknown>[];
  transactions: Record<string, unknown>[];
  debts: Record<string, unknown>[];
  goals: Record<string, unknown>[];
  budgets: Record<string, unknown>[];
  tags: Record<string, unknown>[];
  exported_at: string;
}

export interface ExportCsvResult {
  file_path: string;
  rows_exported: number;
}

export const exportAllData = () => invokeTauri<ExportDataDto>('export_all_data');

export const exportCsv = () => invokeTauri<ExportCsvResult>('export_csv');
