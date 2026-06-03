/**
 * Budget utilities for formatting and status display
 */

/**
 * Format budget amount for display
 */
export function formatBudgetAmount(amount: string): string {
  const num = parseFloat(amount);
  if (isNaN(num)) return '0.00';
  return num.toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

/**
 * Get budget status color based on usage percentage
 */
export function getBudgetStatusColor(percentage: number): string {
  if (percentage >= 100) return 'text-red-600';
  if (percentage >= 80) return 'text-amber-600';
  return 'text-emerald-600';
}

/**
 * Get budget progress bar color based on usage percentage
 */
export function getBudgetProgressColor(percentage: number): string {
  if (percentage >= 100) return 'bg-red-500';
  if (percentage >= 80) return 'bg-amber-500';
  return 'bg-emerald-500';
}

/**
 * Get current month in YYYY-MM format
 */
export function getCurrentMonth(): string {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
}

/**
 * Format month string for display
 */
export function formatMonth(month: string, t: (key: string, options?: Record<string, unknown>) => string): string {
  const [year, monthNum] = month.split('-');
  return t('budget.monthFormat', { year, month: parseInt(monthNum) });
}
