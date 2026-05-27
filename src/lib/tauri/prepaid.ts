import { invokeTauri } from '../tauri';

export interface TopUpRequest {
  account_id: string;
  source_account_id: string;
  paid_amount: number;
  bonus_amount?: number;
  top_up_date: string; // YYYY-MM-DD
  expiry_date?: string;
  description?: string;
}

export interface TopUpRecordDto {
  id: string;
  account_id: string;
  transaction_id: string | null;
  paid_amount: string;
  bonus_amount: string;
  total_credited: string;
  top_up_date: string;
  expiry_date: string | null;
  source_account_id: string;
  description: string | null;
}

export interface PrepaidDetailDto {
  account_id: string;
  account_name: string;
  currency_code: string;
  current_balance: string;
  total_top_ups: string;
  total_consumption: string;
  low_balance_threshold: string | null;
  top_up_records: TopUpRecordDto[];
}

export async function topUp(request: TopUpRequest): Promise<string> {
  return invokeTauri<string>('top_up', { request });
}

export async function getPrepaidDetail(accountId: string): Promise<PrepaidDetailDto> {
  return invokeTauri<PrepaidDetailDto>('get_prepaid_detail', { accountId });
}

export async function getTopUpRecords(accountId: string): Promise<TopUpRecordDto[]> {
  return invokeTauri<TopUpRecordDto[]>('get_top_up_records', { accountId });
}
