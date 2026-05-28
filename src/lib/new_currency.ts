import { NewCurrencyDto } from './tauri/new_currency';

/**
 * Format a currency amount using Intl.NumberFormat
 */
export function formatNewCurrency(
  amount: number,
  currency: NewCurrencyDto,
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
 * Get currency symbol for a given code
 */
export function getNewCurrencySymbol(code: string): string {
  const symbols: Record<string, string> = {
    CNY: '¥',
    USD: '$',
    EUR: '€',
    GBP: '£',
    JPY: '¥',
  };
  return symbols[code] || code;
}

/**
 * Calculate total balance across multiple accounts in CNY
 */
export function calculateNewTotalBalanceInCNY(
  accounts: { balance: number; currency_code: string }[],
  currencies: NewCurrencyDto[]
): number {
  const cny = currencies.find((c) => c.code === 'CNY');
  if (!cny) return 0;

  return accounts.reduce((total, account) => {
    const currency = currencies.find((c) => c.code === account.currency_code);
    if (!currency) return total;

    // Convert to CNY
    const balanceInCNY = (account.balance * currency.exchange_rate) / cny.exchange_rate;
    return total + balanceInCNY;
  }, 0);
}

/**
 * Convert amount between two currencies
 */
export function convertNewAmount(
  amount: number,
  fromCurrency: NewCurrencyDto,
  toCurrency: NewCurrencyDto
): number {
  if (fromCurrency.code === toCurrency.code) return amount;
  return (amount * fromCurrency.exchange_rate) / toCurrency.exchange_rate;
}
