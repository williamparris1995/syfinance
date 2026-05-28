import { invokeTauri } from '../tauri';

export interface NewCurrencyDto {
  id: string;
  code: string;
  name: string;
  symbol: string;
  exchange_rate: number;
  is_active: boolean;
}

export interface CreateNewCurrencyDto {
  code: string;
  name: string;
  symbol: string;
  exchange_rate: number;
}

export const listNewCurrencies = (): Promise<NewCurrencyDto[]> =>
  invokeTauri('new_list_currencies');

export const getNewCurrency = (code: string): Promise<NewCurrencyDto | null> =>
  invokeTauri('new_get_currency', { code });

export const createNewCurrency = (dto: CreateNewCurrencyDto): Promise<NewCurrencyDto> =>
  invokeTauri('new_create_currency', { dto });

export const updateNewExchangeRate = (code: string, rate: number): Promise<void> =>
  invokeTauri('new_update_exchange_rate', { code, rate });

export const fetchNewLatestRates = (): Promise<NewCurrencyDto[]> =>
  invokeTauri('new_fetch_latest_rates');

export const convertNewCurrency = (
  amount: number,
  fromCode: string,
  toCode: string
): Promise<number> =>
  invokeTauri('new_convert_currency', { amount, fromCode, toCode });
