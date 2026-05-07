/**
 * Currency conversion utilities for multi-currency reports
 */

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
