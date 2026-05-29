import { render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { ErrorBoundary } from '../components/ErrorBoundary';
import { getUserFriendlyError, isOnline, setupNetworkListeners } from '../lib/error-handler';

describe('ErrorBoundary', () => {
  it('renders children when there is no error', () => {
    render(
      <ErrorBoundary>
        <div>Test Content</div>
      </ErrorBoundary>
    );

    expect(screen.getByText('Test Content')).toBeInTheDocument();
  });

  it('renders error UI when an error is thrown', () => {
    const ThrowError = () => {
      throw new Error('Test error message');
    };

    // Suppress console.error for this test
    const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});

    render(
      <ErrorBoundary>
        <ThrowError />
      </ErrorBoundary>
    );

    expect(screen.getByText('Something went wrong')).toBeInTheDocument();
    expect(screen.getByText('Test error message')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /try again/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /reload page/i })).toBeInTheDocument();

    consoleError.mockRestore();
  });

  it('allows custom fallback UI', () => {
    const ThrowError = () => {
      throw new Error('Custom error');
    };

    const customFallback = (error: Error) => <div>Custom Error: {error.message}</div>;

    const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});

    render(
      <ErrorBoundary fallback={customFallback}>
        <ThrowError />
      </ErrorBoundary>
    );

    expect(screen.getByText('Custom Error: Custom error')).toBeInTheDocument();

    consoleError.mockRestore();
  });
});

describe('getUserFriendlyError', () => {
  it('maps "not found" errors', () => {
    expect(getUserFriendlyError('Account not found')).toBe('The requested item was not found.');
    expect(getUserFriendlyError(new Error('RowNotFound'))).toBe('The requested item was not found.');
  });

  it('maps unique constraint errors', () => {
    expect(getUserFriendlyError('unique constraint violation')).toBe(
      'This item already exists. Please use a different name.'
    );
    expect(getUserFriendlyError('duplicate key error')).toBe(
      'This item already exists. Please use a different name.'
    );
  });

  it('maps foreign key constraint errors', () => {
    expect(getUserFriendlyError('foreign key constraint failed')).toBe(
      'Cannot delete this item because it is being used elsewhere.'
    );
  });

  it('maps validation errors', () => {
    expect(getUserFriendlyError('invalid input')).toBe(
      'Invalid input. Please check your data and try again.'
    );
    expect(getUserFriendlyError('validation failed')).toBe(
      'Invalid input. Please check your data and try again.'
    );
  });

  it('maps network errors', () => {
    expect(getUserFriendlyError('network error occurred')).toBe(
      'Network error. Please check your connection and try again.'
    );
    expect(getUserFriendlyError('fetch failed')).toBe(
      'Network error. Please check your connection and try again.'
    );
  });

  it('maps timeout errors', () => {
    expect(getUserFriendlyError('request timeout')).toBe('Request timed out. Please try again.');
  });

  it('maps permission errors', () => {
    expect(getUserFriendlyError('permission denied')).toBe(
      'You do not have permission to perform this action.'
    );
    expect(getUserFriendlyError('unauthorized access')).toBe(
      'You do not have permission to perform this action.'
    );
  });

  it('maps balance errors', () => {
    expect(getUserFriendlyError('insufficient balance')).toBe(
      'Insufficient balance for this transaction.'
    );
    expect(getUserFriendlyError('balance not equal')).toBe(
      'Transaction entries must balance (debits must equal credits).'
    );
  });

  it('maps debt payment errors', () => {
    expect(getUserFriendlyError('payment already recorded')).toBe(
      'This payment has already been recorded.'
    );
    expect(getUserFriendlyError('payment not found')).toBe('Payment not found in the schedule.');
  });

  it('returns user-friendly messages as-is', () => {
    const friendlyMessage = 'Please enter a valid email address';
    expect(getUserFriendlyError(friendlyMessage)).toBe(friendlyMessage);
  });

  it('filters out technical jargon', () => {
    expect(getUserFriendlyError('sqlx::Error: database error')).toBe(
      'An error occurred. Please try again or contact support if the problem persists.'
    );
    expect(getUserFriendlyError('panic at thread main')).toBe(
      'An error occurred. Please try again or contact support if the problem persists.'
    );
  });

  it('handles unknown error types', () => {
    expect(getUserFriendlyError(null)).toBe('An unexpected error occurred. Please try again.');
    expect(getUserFriendlyError(undefined)).toBe('An unexpected error occurred. Please try again.');
    expect(getUserFriendlyError(123)).toBe('An unexpected error occurred. Please try again.');
  });
});

describe('Network status utilities', () => {
  it('isOnline returns navigator.onLine status', () => {
    // Mock navigator.onLine
    Object.defineProperty(navigator, 'onLine', {
      writable: true,
      value: true,
    });

    expect(isOnline()).toBe(true);

    Object.defineProperty(navigator, 'onLine', {
      writable: true,
      value: false,
    });

    expect(isOnline()).toBe(false);
  });

  it('setupNetworkListeners registers event listeners', () => {
    const onOnline = vi.fn();
    const onOffline = vi.fn();

    const cleanup = setupNetworkListeners(onOnline, onOffline);

    // Simulate online event
    window.dispatchEvent(new Event('online'));
    expect(onOnline).toHaveBeenCalledTimes(1);

    // Simulate offline event
    window.dispatchEvent(new Event('offline'));
    expect(onOffline).toHaveBeenCalledTimes(1);

    // Cleanup
    cleanup();

    // Events should no longer trigger callbacks
    window.dispatchEvent(new Event('online'));
    window.dispatchEvent(new Event('offline'));
    expect(onOnline).toHaveBeenCalledTimes(1);
    expect(onOffline).toHaveBeenCalledTimes(1);
  });
});
