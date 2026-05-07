import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { TransactionForm } from '../TransactionForm';
import * as accountModule from '@/lib/tauri/account';

// Mock the account module
vi.mock('@/lib/tauri/account', () => ({
  listAccounts: vi.fn(),
}));

const mockAccounts: accountModule.AccountDto[] = [
  {
    id: 'acc-1',
    name: 'Checking Account',
    account_type: 'Bank' as accountModule.AccountType,
    chart_of_account_code: '1002',
    currency_code: 'CNY',
    balance: 1000.00,
    created_at: '2024-01-01T00:00:00Z',
    updated_at: '2024-01-01T00:00:00Z',
  },
  {
    id: 'acc-2',
    name: 'Cash',
    account_type: 'Cash' as accountModule.AccountType,
    chart_of_account_code: '1001',
    currency_code: 'CNY',
    balance: 500.00,
    created_at: '2024-01-01T00:00:00Z',
    updated_at: '2024-01-01T00:00:00Z',
  },
];

const createWrapper = () => {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
    },
  });
  return ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  );
};

describe('TransactionForm', () => {
  it('calculates balance correctly for balanced transaction', async () => {
    vi.mocked(accountModule.listAccounts).mockResolvedValue(mockAccounts);

    const onSubmit = vi.fn();
    const onCancel = vi.fn();

    render(<TransactionForm onSubmit={onSubmit} onCancel={onCancel} />, {
      wrapper: createWrapper(),
    });

    // Wait for form to render
    await waitFor(() => {
      expect(screen.getByText('Entry 1')).toBeInTheDocument();
    });

    // Initially should show balanced (0 = 0)
    expect(screen.getByText(/✓ Balanced/i)).toBeInTheDocument();

    // Fill in first entry with debit
    const debitInputs = screen.getAllByPlaceholderText('0.00');
    await userEvent.type(debitInputs[0], '100');

    // Should show unbalanced
    await waitFor(() => {
      expect(screen.getByText(/Unbalanced: 100.00 CNY/i)).toBeInTheDocument();
    });

    // Fill in second entry with credit
    await userEvent.type(debitInputs[2], '100');

    // Should show balanced again
    await waitFor(() => {
      expect(screen.getByText(/✓ Balanced/i)).toBeInTheDocument();
    });
  });

  it('shows unbalanced state when debits do not equal credits', async () => {
    vi.mocked(accountModule.listAccounts).mockResolvedValue(mockAccounts);

    const onSubmit = vi.fn();
    const onCancel = vi.fn();

    render(<TransactionForm onSubmit={onSubmit} onCancel={onCancel} />, {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(screen.getByText('Entry 1')).toBeInTheDocument();
    });

    // Fill in first entry with debit 100
    const debitInputs = screen.getAllByPlaceholderText('0.00');
    await userEvent.type(debitInputs[0], '100');

    // Fill in second entry with credit 50
    await userEvent.type(debitInputs[2], '50');

    // Should show unbalanced with difference
    await waitFor(() => {
      expect(screen.getByText(/Unbalanced: 50.00 CNY/i)).toBeInTheDocument();
    });
  });

  it('prevents submission when transaction is unbalanced', async () => {
    vi.mocked(accountModule.listAccounts).mockResolvedValue(mockAccounts);

    const onSubmit = vi.fn();
    const onCancel = vi.fn();

    render(<TransactionForm onSubmit={onSubmit} onCancel={onCancel} />, {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(screen.getByText('Entry 1')).toBeInTheDocument();
    });

    // Fill in unbalanced transaction
    const debitInputs = screen.getAllByPlaceholderText('0.00');
    await userEvent.type(debitInputs[0], '100');
    await userEvent.type(debitInputs[2], '50');

    // Submit button should be disabled
    const submitButton = screen.getByRole('button', { name: /Create Transaction/i });
    expect(submitButton).toBeDisabled();

    // Try to submit (should not call onSubmit)
    await userEvent.click(submitButton);
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('allows submission when transaction is balanced', async () => {
    vi.mocked(accountModule.listAccounts).mockResolvedValue(mockAccounts);

    const onSubmit = vi.fn();
    const onCancel = vi.fn();

    render(<TransactionForm onSubmit={onSubmit} onCancel={onCancel} />, {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(screen.getByText('Entry 1')).toBeInTheDocument();
    });

    // Fill in date and description
    const dateInput = screen.getByLabelText(/Transaction Date/i);
    await userEvent.clear(dateInput);
    await userEvent.type(dateInput, '2024-01-15');

    const descInput = screen.getByPlaceholderText(/e.g., Salary payment/i);
    await userEvent.type(descInput, 'Test transaction');

    // Select accounts
    const selectTriggers = screen.getAllByRole('combobox');
    await userEvent.click(selectTriggers[0]);
    await waitFor(() => {
      expect(screen.getByText('Checking Account (1002)')).toBeInTheDocument();
    });
    await userEvent.click(screen.getByText('Checking Account (1002)'));

    await userEvent.click(selectTriggers[1]);
    await waitFor(() => {
      expect(screen.getByText('Cash (1001)')).toBeInTheDocument();
    });
    await userEvent.click(screen.getByText('Cash (1001)'));

    // Fill in balanced amounts
    const debitInputs = screen.getAllByPlaceholderText('0.00');
    await userEvent.type(debitInputs[0], '100');
    await userEvent.type(debitInputs[2], '100');

    // Wait for balanced state
    await waitFor(() => {
      expect(screen.getByText(/✓ Balanced/i)).toBeInTheDocument();
    });

    // Submit button should be enabled
    const submitButton = screen.getByRole('button', { name: /Create Transaction/i });
    expect(submitButton).not.toBeDisabled();

    // Submit should work
    await userEvent.click(submitButton);

    await waitFor(() => {
      expect(onSubmit).toHaveBeenCalledWith({
        transaction_date: '2024-01-15',
        description: 'Test transaction',
        entries: expect.arrayContaining([
          expect.objectContaining({
            account_id: 'acc-1',
            chart_of_account_code: '1002',
            debit_amount: '100',
            credit_amount: null,
          }),
          expect.objectContaining({
            account_id: 'acc-2',
            chart_of_account_code: '1001',
            debit_amount: null,
            credit_amount: '100',
          }),
        ]),
      });
    });
  });

  it('clears opposite field when entering debit or credit', async () => {
    vi.mocked(accountModule.listAccounts).mockResolvedValue(mockAccounts);

    const onSubmit = vi.fn();
    const onCancel = vi.fn();

    render(<TransactionForm onSubmit={onSubmit} onCancel={onCancel} />, {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(screen.getByText('Entry 1')).toBeInTheDocument();
    });

    const inputs = screen.getAllByPlaceholderText('0.00');
    const firstDebit = inputs[0];
    const firstCredit = inputs[1];

    // Enter debit
    await userEvent.type(firstDebit, '100');
    expect(firstDebit).toHaveValue('100');

    // Enter credit (should clear debit)
    await userEvent.type(firstCredit, '50');
    expect(firstCredit).toHaveValue('50');
    expect(firstDebit).toHaveValue('');
  });

  it('allows adding and removing entries', async () => {
    vi.mocked(accountModule.listAccounts).mockResolvedValue(mockAccounts);

    const onSubmit = vi.fn();
    const onCancel = vi.fn();

    render(<TransactionForm onSubmit={onSubmit} onCancel={onCancel} />, {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(screen.getByText('Entry 1')).toBeInTheDocument();
    });

    // Initially 2 entries
    expect(screen.getByText('Entry 1')).toBeInTheDocument();
    expect(screen.getByText('Entry 2')).toBeInTheDocument();
    expect(screen.queryByText('Entry 3')).not.toBeInTheDocument();

    // Add entry
    const addButton = screen.getByRole('button', { name: /Add Entry/i });
    await userEvent.click(addButton);

    await waitFor(() => {
      expect(screen.getByText('Entry 3')).toBeInTheDocument();
    });

    // Remove entry (trash icon should appear for entries > 2)
    const trashButtons = screen.getAllByRole('button', { name: '' }).filter(btn => 
      btn.querySelector('svg')
    );
    
    if (trashButtons.length > 0) {
      await userEvent.click(trashButtons[0]);
      
      await waitFor(() => {
        expect(screen.queryByText('Entry 3')).not.toBeInTheDocument();
      });
    }
  });
});
