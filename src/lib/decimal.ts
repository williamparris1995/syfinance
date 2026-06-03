/**
 * String-based decimal arithmetic to avoid floating-point precision loss.
 * All amounts are stored as strings from the Rust backend (which uses rust_decimal).
 *
 * These functions convert to integer cents internally to avoid
 * the classic 0.1 + 0.2 = 0.30000000000000004 problem.
 */

/** Convert a decimal string to integer cents (rounding to nearest cent) */
function toCents(value: string): number {
  // parseFloat is fine here — we immediately round to integer cents
  return Math.round(parseFloat(value) * 100);
}

/** Convert integer cents back to a fixed-point decimal string */
function fromCents(cents: number): string {
  return (cents / 100).toFixed(2);
}

/** Add two decimal strings */
export function addDecimals(a: string, b: string): string {
  return fromCents(toCents(a) + toCents(b));
}

/** Subtract two decimal strings (a - b) */
export function subtractDecimals(a: string, b: string): string {
  return fromCents(toCents(a) - toCents(b));
}

/** Multiply a decimal string by a number (e.g. quantity * price) */
export function multiplyDecimal(value: string, multiplier: number): string {
  // For multiplication we need to work at the cents level to avoid float errors
  // but the multiplier itself may not be integer, so we use a scaling approach
  const cents = toCents(value);
  // Work in cent-millis (cents * 1000) to preserve precision with non-integer multipliers
  const scaledResult = Math.round(cents * multiplier);
  return (scaledResult / 100).toFixed(2);
}

/** Multiply two decimal strings together (e.g. quantity * price where both are strings) */
export function multiplyDecimals(a: string, b: string): string {
  const centsA = toCents(a);
  const centsB = toCents(b);
  // (centsA * centsB) / 10000 gives us the result in cents
  // We round to nearest cent
  const resultCents = Math.round((centsA * centsB) / 100);
  return fromCents(resultCents);
}

/** Format a decimal string for display with 2 decimal places */
export function formatDecimal(value: string): string {
  return parseFloat(value).toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

/** Safely parse a decimal string, returning '0.00' for invalid input */
export function safeParseDecimal(value: string | undefined | null): string {
  if (!value) return '0.00';
  const parsed = parseFloat(value);
  if (isNaN(parsed)) return '0.00';
  return parsed.toFixed(2);
}
