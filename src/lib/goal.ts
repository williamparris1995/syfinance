/**
 * Goal utilities for formatting and status display
 */

/**
 * Format goal amount for display
 */
export function formatGoalAmount(amount: string): string {
  const num = parseFloat(amount);
  if (isNaN(num)) return '0.00';
  return num.toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

/**
 * Get goal type label
 */
export function getGoalTypeLabel(type: string, t: (key: string) => string): string {
  const labels: Record<string, string> = {
    savings: t('goals.typeSavings'),
    debt_payoff: t('goals.typeDebtPayoff'),
    investment: t('goals.typeInvestment'),
  };
  return labels[type] || type;
}

/**
 * Get goal type badge color class
 */
export function getGoalTypeColor(type: string): string {
  const colors: Record<string, string> = {
    savings: 'bg-blue-100 text-blue-800',
    debt_payoff: 'bg-red-100 text-red-800',
    investment: 'bg-green-100 text-green-800',
  };
  return colors[type] || 'bg-gray-100 text-gray-800';
}

/**
 * Get progress bar color based on percentage
 */
export function getGoalProgressColor(percentage: number): string {
  if (percentage >= 100) return 'bg-emerald-500';
  if (percentage >= 75) return 'bg-blue-500';
  if (percentage >= 50) return 'bg-amber-500';
  return 'bg-gray-400';
}

/**
 * Get status text color based on goal state
 */
export function getGoalStatusColor(goal: {
  is_completed: boolean;
  is_overdue: boolean;
  progress_percentage: number;
}): string {
  if (goal.is_completed) return 'text-emerald-600';
  if (goal.is_overdue) return 'text-red-600';
  if (goal.progress_percentage >= 75) return 'text-blue-600';
  return 'text-muted-foreground';
}
