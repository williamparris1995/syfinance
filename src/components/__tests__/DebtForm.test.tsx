import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { DebtForm } from '../DebtForm';

describe('DebtForm', () => {
  it('renders all form fields in lump sum mode', () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();

    render(<DebtForm onSubmit={onSubmit} onCancel={onCancel} />);

    expect(screen.getByLabelText(/type/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/counterparty/i)).toBeInTheDocument();
    expect(screen.getByPlaceholderText('100,000')).toBeInTheDocument();
    expect(screen.getByPlaceholderText('5.5')).toBeInTheDocument();
    expect(screen.getByLabelText(/due date/i)).toBeInTheDocument();
    // start_date and amortization_method are hidden in lump sum mode
    expect(screen.queryByLabelText(/start date/i)).not.toBeInTheDocument();
    expect(screen.queryByLabelText(/amortization method/i)).not.toBeInTheDocument();
    // currency_code is hidden
    expect(screen.queryByLabelText(/currency/i)).not.toBeInTheDocument();
  });

  it('shows installment fields when switching to installment mode', async () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();
    const user = userEvent.setup();

    render(<DebtForm onSubmit={onSubmit} onCancel={onCancel} />);

    // Click the Installment toggle button
    const installmentButton = screen.getByRole('button', { name: /installment/i });
    await user.click(installmentButton);

    // Now installment-specific fields should appear
    expect(screen.getByLabelText(/periods/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/start date/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/amortization method/i)).toBeInTheDocument();
    // due_date should not be visible in installment mode
    expect(screen.queryByLabelText(/due date/i)).not.toBeInTheDocument();
  });

  it('displays payment schedule preview when installment fields are filled', async () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();
    const user = userEvent.setup();

    render(<DebtForm onSubmit={onSubmit} onCancel={onCancel} />);

    // Switch to installment mode
    const installmentButton = screen.getByRole('button', { name: /installment/i });
    await user.click(installmentButton);

    // Fill in the form
    const principalInput = screen.getByPlaceholderText('100,000');
    await user.type(principalInput, '100000');

    const interestInput = screen.getByPlaceholderText('5.5');
    await user.type(interestInput, '5');

    // Select periods
    const periodsCombobox = screen.getByRole('combobox', { name: /periods/i });
    await user.click(periodsCombobox);
    const twelveMonthsOption = await screen.findByRole('option', { name: /12 months/i });
    await user.click(twelveMonthsOption);

    const startDateInput = screen.getByLabelText(/start date/i);
    await user.type(startDateInput, '2024-01-01');

    // Wait for debounced preview calculation
    await waitFor(
      () => {
        expect(screen.getByText(/monthly payment/i)).toBeInTheDocument();
      },
      { timeout: 1000 }
    );
  });

  it('calls onSubmit with correct data when form is submitted (lump sum)', async () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();
    const user = userEvent.setup();

    render(<DebtForm onSubmit={onSubmit} onCancel={onCancel} />);

    // Select debt type
    const debtTypeCombobox = screen.getByRole('combobox', { name: /type/i });
    await user.click(debtTypeCombobox);
    const loanOption = await screen.findByRole('option', { name: /Loan/i });
    await user.click(loanOption);

    // Fill in required fields for lump sum
    const counterpartyInput = screen.getByLabelText(/counterparty/i);
    await user.type(counterpartyInput, 'Bank of China');

    const principalInput = screen.getByPlaceholderText('100,000');
    await user.type(principalInput, '100000');

    const interestInput = screen.getByPlaceholderText('5.5');
    await user.type(interestInput, '5');

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
          due_date: '2025-01-01',
        })
      );
    });
  });

  it('calls onSubmit with correct data when form is submitted (installment)', async () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();
    const user = userEvent.setup();

    render(<DebtForm onSubmit={onSubmit} onCancel={onCancel} />);

    // Switch to installment mode
    const installmentButton = screen.getByRole('button', { name: /installment/i });
    await user.click(installmentButton);

    // Select debt type
    const debtTypeCombobox = screen.getByRole('combobox', { name: /type/i });
    await user.click(debtTypeCombobox);
    const loanOption = await screen.findByRole('option', { name: /Loan/i });
    await user.click(loanOption);

    // Fill in required fields
    const counterpartyInput = screen.getByLabelText(/counterparty/i);
    await user.type(counterpartyInput, 'Bank of China');

    const principalInput = screen.getByPlaceholderText('100,000');
    await user.type(principalInput, '100000');

    const interestInput = screen.getByPlaceholderText('5.5');
    await user.type(interestInput, '5');

    // Select periods (12 months)
    const periodsCombobox = screen.getByRole('combobox', { name: /periods/i });
    await user.click(periodsCombobox);
    const twelveMonthsOption = await screen.findByRole('option', { name: /12 months/i });
    await user.click(twelveMonthsOption);

    const startDateInput = screen.getByLabelText(/start date/i);
    await user.type(startDateInput, '2024-01-01');

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
          due_date: '2025-01-01', // derived from start_date + 12 months
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

  it('validates that due date is after start date when both are provided', async () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();
    const user = userEvent.setup();

    render(<DebtForm onSubmit={onSubmit} onCancel={onCancel} />);

    // First go to installment mode to set start_date
    const installmentButton = screen.getByRole('button', { name: /installment/i });
    await user.click(installmentButton);

    // Select debt type
    const debtTypeCombobox = screen.getByRole('combobox', { name: /type/i });
    await user.click(debtTypeCombobox);
    const loanOption = await screen.findByRole('option', { name: /Loan/i });
    await user.click(loanOption);

    const startDateInput = screen.getByLabelText(/start date/i);
    await user.type(startDateInput, '2025-01-01');

    // Switch back to lump sum mode to set due_date
    const lumpSumButton = screen.getByRole('button', { name: /lump sum/i });
    await user.click(lumpSumButton);

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

    const principalInput = screen.getByPlaceholderText('100,000');
    await user.type(principalInput, '-100');

    const submitButton = screen.getByRole('button', { name: /create debt/i });
    await user.click(submitButton);

    await waitFor(() => {
      expect(screen.getByText(/principal amount must be greater than 0/i)).toBeInTheDocument();
    });

    expect(onSubmit).not.toHaveBeenCalled();
  });
});
