import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { DebtForm } from '../DebtForm';

describe('DebtForm', () => {
  it('renders all form fields', () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();

    render(<DebtForm onSubmit={onSubmit} onCancel={onCancel} />);

    expect(screen.getByLabelText(/debt type/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/counterparty/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/principal amount/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/currency/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/interest rate/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/start date/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/due date/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/amortization method/i)).toBeInTheDocument();
  });

  it('displays payment schedule preview when all fields are filled', async () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();
    const user = userEvent.setup();

    render(<DebtForm onSubmit={onSubmit} onCancel={onCancel} />);

    // Fill in the form
    const principalInput = screen.getByLabelText(/principal amount/i);
    await user.type(principalInput, '100000');

    const interestInput = screen.getByLabelText(/interest rate/i);
    await user.type(interestInput, '5');

    const startDateInput = screen.getByLabelText(/start date/i);
    await user.type(startDateInput, '2024-01-01');

    const dueDateInput = screen.getByLabelText(/due date/i);
    await user.type(dueDateInput, '2025-01-01');

    // Wait for debounced preview calculation
    await waitFor(
      () => {
        expect(screen.getByText(/payment schedule preview/i)).toBeInTheDocument();
      },
      { timeout: 1000 }
    );
  });

  it('calls onSubmit with correct data when form is submitted', async () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();
    const user = userEvent.setup();

    render(<DebtForm onSubmit={onSubmit} onCancel={onCancel} />);

    // Select debt type (required field)
    const debtTypeCombobox = screen.getByRole('combobox', { name: /debt type/i });
    await user.click(debtTypeCombobox);
    const loanOption = await screen.findByRole('option', { name: /Loan/i });
    await user.click(loanOption);

    // Fill in required fields
    const counterpartyInput = screen.getByLabelText(/counterparty/i);
    await user.type(counterpartyInput, 'Bank of China');

    const principalInput = screen.getByLabelText(/principal amount/i);
    await user.type(principalInput, '100000');

    const interestInput = screen.getByLabelText(/interest rate/i);
    await user.type(interestInput, '5');

    const startDateInput = screen.getByLabelText(/start date/i);
    await user.type(startDateInput, '2024-01-01');

    const dueDateInput = screen.getByLabelText(/due date/i);
    await user.type(dueDateInput, '2025-01-01');

    // Submit form
    const submitButton = screen.getByRole('button', { name: /create debt/i });
    await user.click(submitButton);

    await waitFor(() => {
      expect(onSubmit).toHaveBeenCalledWith(
        expect.objectContaining({
          counterparty: 'Bank of China',
          principal_amount: '100000',
          interest_rate: '5',
          start_date: '2024-01-01',
          due_date: '2025-01-01',
        })
      );
    });
  });

  it('calls onCancel when cancel button is clicked', async () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();
    const user = userEvent.setup();

    render(<DebtForm onSubmit={onSubmit} onCancel={onCancel} />);

    const cancelButton = screen.getByRole('button', { name: /cancel/i });
    await user.click(cancelButton);

    expect(onCancel).toHaveBeenCalled();
  });

  it('validates that due date is after start date', async () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();
    const user = userEvent.setup();

    render(<DebtForm onSubmit={onSubmit} onCancel={onCancel} />);

    // Select debt type (required field, needed before refinement validation runs)
    const debtTypeCombobox = screen.getByRole('combobox', { name: /debt type/i });
    await user.click(debtTypeCombobox);
    const loanOption = await screen.findByRole('option', { name: /Loan/i });
    await user.click(loanOption);

    const startDateInput = screen.getByLabelText(/start date/i);
    await user.type(startDateInput, '2025-01-01');

    const dueDateInput = screen.getByLabelText(/due date/i);
    await user.type(dueDateInput, '2024-01-01');

    const submitButton = screen.getByRole('button', { name: /create debt/i });
    await user.click(submitButton);

    await waitFor(() => {
      expect(screen.getByText(/due date must be after start date/i)).toBeInTheDocument();
    });

    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('validates that principal amount is positive', async () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();
    const user = userEvent.setup();

    render(<DebtForm onSubmit={onSubmit} onCancel={onCancel} />);

    const principalInput = screen.getByLabelText(/principal amount/i);
    await user.type(principalInput, '-100');

    const submitButton = screen.getByRole('button', { name: /create debt/i });
    await user.click(submitButton);

    await waitFor(() => {
      expect(screen.getByText(/principal amount must be greater than 0/i)).toBeInTheDocument();
    });

    expect(onSubmit).not.toHaveBeenCalled();
  });
});
