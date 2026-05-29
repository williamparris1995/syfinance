/**
 * Currency conversion utilities for multi-currency reports
 */

import { CurrencyDto } from './tauri/currency';

export interface ExchangeRate {
  code: string;
  rate: number; // Rate relative to base currency (CNY)
}

/**
 * Convert amount from one currency to another
 * @param amount - Amount to convert
 * @param fromCurrency - Source currency code
 * @param toCurrency - Target currency code
 * @param rates - Map of currency codes to exchange rates
 * @returns Converted amount or null if rate is missing
 */
export function convertMoney(
  amount: number,
  fromCurrency: string,
  toCurrency: string,
  rates: Map<string, number>
): number | null {
  // Same currency, no conversion needed
  if (fromCurrency === toCurrency) {
    return amount;
  }

  const fromRate = rates.get(fromCurrency);
  const toRate = rates.get(toCurrency);

  // Missing exchange rate
  if (fromRate === undefined || toRate === undefined) {
    return null;
  }

  // Convert: amount * (targetRate / sourceRate)
  // Example: 100 USD -> EUR with USD=7.25, EUR=8.00
  // Result: 100 * (7.25 / 8.00) = 90.625 EUR
  const converted = amount * (fromRate / toRate);

  // Round to 2 decimal places
  return Math.round(converted * 100) / 100;
}

/**
 * Get list of currencies with missing exchange rates
 * @param currencies - List of currency codes to check
 * @param targetCurrency - Target currency for conversion
 * @param rates - Map of currency codes to exchange rates
 * @returns Array of currency codes with missing rates
 */
export function getMissingRates(
  currencies: string[],
  targetCurrency: string,
  rates: Map<string, number>
): string[] {
  const missing: string[] = [];

  for (const currency of currencies) {
    // Skip if same as target
    if (currency === targetCurrency) {
      continue;
    }

    // Check if rate exists
    if (!rates.has(currency) || !rates.has(targetCurrency)) {
      if (!missing.includes(currency)) {
        missing.push(currency);
      }
    }
  }

  return missing;
}

/**
 * Format currency amount with symbol and thousands separator
 * @param amount - Amount to format
 * @param currencyCode - Currency code (CNY, USD, EUR, etc.)
 * @returns Formatted string (e.g., "¥1,234.56")
 */
export function formatCurrency(amount: number, currencyCode: string): string {
  const symbols: Record<string, string> = {
    CNY: '¥',
    USD: '$',
    EUR: '€',
    GBP: '£',
    JPY: '¥',
  };

  const symbol = symbols[currencyCode] || currencyCode;
  const formatted = amount.toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });

  return `${symbol}${formatted}`;
}

/**
 * Format currency amount using CurrencyDto
 * @param amount - Amount to format
 * @param currency - CurrencyDto object
 * @param options - Intl.NumberFormatOptions
 * @returns Formatted string
 */
export function formatCurrencyWithDto(
  amount: number,
  currency: CurrencyDto,
  options?: Intl.NumberFormatOptions
): string {
  return new Intl.NumberFormat('zh-CN', {
    style: 'currency',
    currency: currency.code,
    currencyDisplay: 'narrowSymbol',
    ...options,
  }).format(amount);
}

/**
 * Build exchange rate map from currency DTOs
 * @param currencies - Array of currency DTOs with exchange_rate strings
 * @returns Map of currency code to numeric rate
 */
export function buildRateMap(currencies: Array<{ code: string; exchange_rate: string }>): Map<string, number> {
  const rateMap = new Map<string, number>();

  for (const currency of currencies) {
    const rate = parseFloat(currency.exchange_rate);
    if (!isNaN(rate)) {
      rateMap.set(currency.code, rate);
    }
  }

  return rateMap;
}

/**
 * Calculate total balance in CNY from multiple accounts
 * @param accounts - Array of accounts with balance and currency_code
 * @param currencies - Array of CurrencyDto objects
 * @returns Total balance in CNY
 */
export function calculateTotalBalanceInCNY(
  accounts: { balance: number; currency_code: string }[],
  currencies: CurrencyDto[]
): number {
  const cny = currencies.find(c => c.code === 'CNY');
  if (!cny) return 0;

  return accounts.reduce((total, account) => {
    const currency = currencies.find(c => c.code === account.currency_code);
    if (!currency) return total;

    // 转换为 CNY
    const fromRate = parseFloat(currency.exchange_rate) || 1;
    const toRate = parseFloat(cny.exchange_rate) || 1;
    const balanceInCNY = account.balance * fromRate / toRate;
    return total + balanceInCNY;
  }, 0);
}

/**
 * Convert amount between currencies using CurrencyDto
 * @param amount - Amount to convert
 * @param fromCurrency - Source CurrencyDto
 * @param toCurrency - Target CurrencyDto
 * @returns Converted amount
 */
export function convertAmountWithDto(
  amount: number,
  fromCurrency: CurrencyDto,
  toCurrency: CurrencyDto
): number {
  if (fromCurrency.code === toCurrency.code) return amount;
  const fromRate = parseFloat(fromCurrency.exchange_rate) || 1;
  const toRate = parseFloat(toCurrency.exchange_rate) || 1;
  return amount * fromRate / toRate;
}
