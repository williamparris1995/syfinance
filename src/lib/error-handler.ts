/**
 * Maps backend error messages to user-friendly messages
 */
export function getUserFriendlyError(error: unknown): string {
  if (typeof error === 'string') {
    return mapErrorMessage(error);
  }

  if (error instanceof Error) {
    return mapErrorMessage(error.message);
  }

  return 'An unexpected error occurred. Please try again.';
}

function mapErrorMessage(message: string): string {
  const lowerMessage = message.toLowerCase();

  // Debt errors (check specific patterns first)
  if (lowerMessage.includes('payment already recorded')) {
    return 'This payment has already been recorded.';
  }

  if (lowerMessage.includes('payment not found')) {
    return 'Payment not found in the schedule.';
  }

  // Balance errors
  if (lowerMessage.includes('insufficient balance')) {
    return 'Insufficient balance for this transaction.';
  }

  if (lowerMessage.includes('balance') && lowerMessage.includes('not')) {
    return 'Transaction entries must balance (debits must equal credits).';
  }

  // Database errors
  if (lowerMessage.includes('not found') || lowerMessage.includes('rownotfound')) {
    return 'The requested item was not found.';
  }

  if (lowerMessage.includes('unique constraint') || lowerMessage.includes('duplicate')) {
    return 'This item already exists. Please use a different name.';
  }

  if (lowerMessage.includes('foreign key constraint')) {
    return 'Cannot delete this item because it is being used elsewhere.';
  }

  // Validation errors
  if (lowerMessage.includes('invalid') || lowerMessage.includes('validation')) {
    return 'Invalid input. Please check your data and try again.';
  }

  if (lowerMessage.includes('required')) {
    return 'Please fill in all required fields.';
  }

  // Network errors
  if (lowerMessage.includes('network') || lowerMessage.includes('fetch')) {
    return 'Network error. Please check your connection and try again.';
  }

  if (lowerMessage.includes('timeout')) {
    return 'Request timed out. Please try again.';
  }

  // Permission errors
  if (lowerMessage.includes('permission') || lowerMessage.includes('unauthorized')) {
    return 'You do not have permission to perform this action.';
  }

  // If the message is already user-friendly (no technical jargon), return it
  if (!containsTechnicalJargon(message)) {
    return message;
  }

  // Default fallback
  return 'An error occurred. Please try again or contact support if the problem persists.';
}

function containsTechnicalJargon(message: string): boolean {
  const technicalTerms = [
    'sqlx',
    'error:',
    'exception',
    'stack trace',
    'null pointer',
    'undefined',
    'panic',
    'thread',
    'mutex',
    'async',
  ];

  const lowerMessage = message.toLowerCase();
  return technicalTerms.some((term) => lowerMessage.includes(term));
}

/**
 * Checks if the browser is online
 */
export function isOnline(): boolean {
  return typeof navigator !== 'undefined' ? navigator.onLine : true;
}

/**
 * Sets up online/offline event listeners
 */
export function setupNetworkListeners(
  onOnline: () => void,
  onOffline: () => void
): () => void {
  if (typeof window === 'undefined') {
    return () => {};
  }

  window.addEventListener('online', onOnline);
  window.addEventListener('offline', onOffline);

  return () => {
    window.removeEventListener('online', onOnline);
    window.removeEventListener('offline', onOffline);
  };
}
