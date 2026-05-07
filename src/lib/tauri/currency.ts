import { invokeTauri } from '../tauri';

export interface CurrencyDto {
  code: string;
  symbol: string;
  exchange_rate: string;
  updated_at: string;
}

export interface AddCurrencyDto {
  code: string;
  symbol: string;
  exchange_rate: string;
}

export interface UpdateCurrencyRateDto {
  exchange_rate: string;
}

export const listCurrencies = () => invokeTauri<CurrencyDto[]>('list_currencies');

export const addCurrency = (dto: AddCurrencyDto) =>
  invokeTauri<CurrencyDto>('add_currency', { dto });

export const updateCurrencyRate = (code: string, dto: UpdateCurrencyRateDto) =>
  invokeTauri<CurrencyDto>('update_currency_rate', { code, dto });
