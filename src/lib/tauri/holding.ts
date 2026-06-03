import { invokeTauri } from '../tauri';

export type SecurityType = 'stock' | 'fund' | 'etf' | 'bond' | 'gold' | 'option' | 'other';

export interface CreateSecurityDto {
  symbol: string;
  name: string;
  security_type: SecurityType;
  exchange?: string | null;
  currency_code: string;
}

export interface SecurityDto {
  id: string;
  symbol: string;
  name: string;
  security_type: SecurityType;
  exchange?: string | null;
  currency_code: string;
  current_price?: number | null;
}

export interface HoldingTradeDto {
  account_id: string;
  security_id: string;
  direction: 'BUY' | 'SELL';
  quantity: number;
  price: number;
  fee: number;
  trade_date: string;
  notes?: string | null;
}

export interface HoldingDto {
  id: string;
  account_id: string;
  account_name: string;
  security_id: string;
  symbol: string;
  security_name: string;
  security_type: SecurityType;
  quantity: number;
  avg_cost: number;
  current_price?: number | null;
  market_value?: number | null;
  unrealized_pnl?: number | null;
  currency_code: string;
}

export const createSecurity = (dto: CreateSecurityDto) =>
  invokeTauri<SecurityDto>('create_security', { dto });

export const listSecurities = () =>
  invokeTauri<SecurityDto[]>('list_securities');

export const updateSecurityPrice = (id: string, price: number) =>
  invokeTauri<void>('update_security_price', { id, price });

export const buyHolding = (dto: HoldingTradeDto) =>
  invokeTauri<string>('buy_holding', { dto });

export const sellHolding = (dto: HoldingTradeDto) =>
  invokeTauri<string>('sell_holding', { dto });

export const listHoldings = () =>
  invokeTauri<HoldingDto[]>('list_holdings');

export interface SecuritySearchResult {
  symbol: string;
  name: string;
  exchange: string;
  exchange_display: string;
  security_type: SecurityType;
}

export const searchSecurities = (query: string) =>
  invokeTauri<SecuritySearchResult[]>('search_securities', { query });

export interface PriceResult {
  symbol: string;
  price: number;
}

export const fetchSecurityPrice = (symbol: string, exchange?: string | null) =>
  invokeTauri<PriceResult | null>('fetch_security_price', { symbol, exchange: exchange || null });

export interface HoldingTransactionDto {
  id: string;
  holding_id: string;
  transaction_id: string | null;
  trade_type: string;
  quantity: number;
  price: number;
  fee: number;
  amount: number;
  trade_date: string;
  notes: string | null;
}

export interface UpdateHoldingTradeRequest {
  holding_transaction_id: string;
  quantity: number;
  price: number;
  fee: number;
  trade_date: string;
  notes?: string | null;
}

export const listHoldingTransactions = (holdingId: string) =>
  invokeTauri<HoldingTransactionDto[]>('list_holding_transactions', { holdingId });

export const deleteHoldingTrade = (holdingTransactionId: string) =>
  invokeTauri<void>('delete_holding_trade', { holdingTransactionId });

export const updateHoldingTrade = (request: UpdateHoldingTradeRequest) =>
  invokeTauri<void>('update_holding_trade', { request });

export interface DividendDto {
  account_id: string;
  security_id: string;
  cash_per_share: string;
  quantity: string;
  total_amount: string;
  fee?: string | null;
  trade_date: string;
  notes?: string | null;
}

export interface SplitDto {
  holding_id: string;
  ratio: string;
  trade_date: string;
  notes?: string | null;
}

export const recordDividend = (dto: DividendDto) =>
  invokeTauri<string>('record_dividend', { dto });

export const recordSplit = (dto: SplitDto) =>
  invokeTauri<void>('record_split', { dto });

// Re-export PaginatedResult from transaction types for consistency
import type { PaginatedResult } from './transaction';

export const listHoldingTransactionsPaginated = (
  holdingId: string,
  first?: number,
  after?: string,
  before?: string,
) =>
  invokeTauri<PaginatedResult<HoldingTransactionDto>>(
    'list_holding_transactions_paginated',
    { holdingId, first, after, before },
  );
