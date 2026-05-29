import { invokeTauri } from '../tauri';

export interface CurrencyDto {
  id: string;
  code: string;
  name: string;
  symbol: string;
  exchange_rate: string;
  is_active: boolean;
  updated_at: string;
}

export interface CreateCurrencyDto {
  code: string;
  name: string;
  symbol: string;
  exchange_rate: string;
}

export interface UpdateCurrencyRateDto {
  exchange_rate: string;
}

export const listCurrencies = () => invokeTauri<CurrencyDto[]>('list_currencies');

export const getCurrency = (code: string) =>
  invokeTauri<CurrencyDto | null>('get_currency', { code });

export const addCurrency = (dto: CreateCurrencyDto) =>
  invokeTauri<void>('add_currency', { dto });

export const updateCurrencyRate = (code: string, exchangeRate: string) =>
  invokeTauri<void>('update_currency_rate', { code, exchangeRate });

export const deleteCurrency = (code: string) =>
  invokeTauri<boolean>('delete_currency', { code });

export const convertCurrency = (amount: number, fromCode: string, toCode: string) =>
  invokeTauri<number>('convert_currency', { amount, fromCode, toCode });
