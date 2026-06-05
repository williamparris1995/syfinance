import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { DebtForm } from '../DebtForm';
import * as accountApi from '@/lib/tauri/account';

vi.mock('@/lib/tauri/account');

const mockAccounts: accountApi.AccountDto[] = [
  {
    id: 'acc-1',
    name: 'Mortgage',
    account_type: 'BorrowedIn',
    ownership: 'liability' as accountApi.Ownership,
    icon: '💰',
    color: '#10B981',
    currency_code: 'CNY',
    initial_balance: 0,
    current_balance: 0,
    status: 'active',
    created_at: '2024-01-01T00:00:00Z',
    updated_at: '2024-01-01T00:00:00Z',
  },
  {
    id: 'acc-2',
    name: 'Bank of China',
    account_type: 'Bank',
    ownership: 'own',
    icon: '💰',
    color: '#10B981',
    currency_code: 'CNY',
    initial_balance: 10000,
    current_balance: 10000,
    status: 'active',
    created_at: '2024-01-01T00:00:00Z',
    updated_at: '2024-01-01T00:00:00Z',
  },
];

const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: false } },
});

function renderForm(onSubmit = vi.fn(), onCancel = vi.fn()) {
  return render(
    <QueryClientProvider client={queryClient}>
      <DebtForm onSubmit={onSubmit} onCancel={onCancel} />
    </QueryClientProvider>
  );
}

describe('DebtForm', () => {
  it('renders form fields in lump sum mode', () => {
    vi.mocked(accountApi.listAccounts).mockResolvedValue(mockAccounts);
    const { container } = renderForm();

    expect(screen.getByText(/lump sum/i)).toBeInTheDocument();
    expect(container.querySelector('[placeholder="100,000"]')).toBeInTheDocument();
    expect(container.querySelector('[placeholder="5.5"]')).toBeInTheDocument();
  });

  it('shows installment fields when switching to installment mode', async () => {
    vi.mocked(accountApi.listAccounts).mockResolvedValue(mockAccounts);
    const user = userEvent.setup();
    renderForm();

    const installmentButton = screen.getByRole('button', { name: /installment/i });
    await user.click(installmentButton);

    expect(screen.getByText(/periods/i)).toBeInTheDocument();
    expect(screen.getByText(/amortization method/i)).toBeInTheDocument();
  });

  it('calls onSubmit with correct data in lump sum mode', async () => {
    vi.mocked(accountApi.listAccounts).mockResolvedValue(mockAccounts);
    const onSubmit = vi.fn();
    const user = userEvent.setup();
    const { container } = renderForm(onSubmit);

    // Type amounts
    const principalInput = container.querySelector('[placeholder="100,000"]')!;
    await user.type(principalInput, '100000');

    const interestInput = container.querySelector('[placeholder="5.5"]')!;
    await user.type(interestInput, '5');

    const dueDateInput = screen.getByDisplayValue(''); // date input in lump sum
    await user.type(dueDateInput, '2025-01-01');

    // Submit
    const submitButton = screen.getByRole('button', { name: /create debt/i });
    await user.click(submitButton);

    await waitFor(() => {
      expect(onSubmit).toHaveBeenCalledWith(
        expect.objectContaining({
          principal_amount: '100000',
          interest_rate: '5',
          due_date: '2025-01-01',
        })
      );
    });
  });

  it('calls onCancel when cancel is clicked', async () => {
    vi.mocked(accountApi.listAccounts).mockResolvedValue(mockAccounts);
    const onCancel = vi.fn();
    const user = userEvent.setup();
    renderForm(vi.fn(), onCancel);

    const cancelButton = screen.getByRole('button', { name: /cancel/i });
    await user.click(cancelButton);
    expect(onCancel).toHaveBeenCalled();
  });

  it('validates principal amount is positive', async () => {
    vi.mocked(accountApi.listAccounts).mockResolvedValue(mockAccounts);
    const onSubmit = vi.fn();
    const user = userEvent.setup();
    const { container } = renderForm(onSubmit);

    const principalInput = container.querySelector('[placeholder="100,000"]')!;
    await user.type(principalInput, '-100');

    const submitButton = screen.getByRole('button', { name: /create debt/i });
    await user.click(submitButton);

    await waitFor(() => {
      expect(screen.getByText(/principal amount must be greater than 0/i)).toBeInTheDocument();
    });
    expect(onSubmit).not.toHaveBeenCalled();
  });
});
