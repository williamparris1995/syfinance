import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { AccountForm } from '../AccountForm';

describe('AccountForm', () => {
  it('shows validation error when name is empty', async () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();
    const user = userEvent.setup();

    render(<AccountForm onSubmit={onSubmit} onCancel={onCancel} />);

    // Try to submit without filling the form
    const submitButton = screen.getByRole('button', { name: /create account/i });
    await user.click(submitButton);

    // Wait for validation error
    await waitFor(() => {
      expect(screen.getByText('Name is required')).toBeInTheDocument();
    });

    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('shows validation error when account type is not selected', async () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();
    const user = userEvent.setup();

    render(<AccountForm onSubmit={onSubmit} onCancel={onCancel} />);

    // Fill only the name field
    const nameInput = screen.getByPlaceholderText(/e.g., Checking Account/i);
    await user.type(nameInput, 'Test Account');

    // Try to submit
    const submitButton = screen.getByRole('button', { name: /create account/i });
    await user.click(submitButton);

    // Wait for validation error
    await waitFor(() => {
      expect(screen.getByText('Account type is required')).toBeInTheDocument();
    });

    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('shows validation error for invalid initial balance', async () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();
    const user = userEvent.setup();

    render(<AccountForm onSubmit={onSubmit} onCancel={onCancel} />);

    // Fill name
    const nameInput = screen.getByPlaceholderText(/e.g., Checking Account/i);
    await user.type(nameInput, 'Test Account');

    // Select account type
    const accountTypeCombobox = screen.getByRole('combobox', { name: /Account Type/i });
    await user.click(accountTypeCombobox);
    const bankOption = await screen.findByRole('option', { name: /Bank/i });
    await user.click(bankOption);

    // Enter invalid balance
    const balanceInput = screen.getByPlaceholderText('0.00');
    await user.clear(balanceInput);
    await user.type(balanceInput, 'invalid');

    // Try to submit
    const submitButton = screen.getByRole('button', { name: /create account/i });
    await user.click(submitButton);

    // Wait for validation error
    await waitFor(() => {
      expect(screen.getByText('Initial balance must be a valid number')).toBeInTheDocument();
    });

    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('submits form with valid data', async () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();
    const user = userEvent.setup();

    render(<AccountForm onSubmit={onSubmit} onCancel={onCancel} />);

    // Fill name
    const nameInput = screen.getByPlaceholderText(/e.g., Checking Account/i);
    await user.type(nameInput, 'Checking Account');

    // Select account type
    const accountTypeCombobox = screen.getByRole('combobox', { name: /Account Type/i });
    await user.click(accountTypeCombobox);
    const bankOption = await screen.findByRole('option', { name: /Bank/i });
    await user.click(bankOption);

    // Currency is pre-filled with CNY, so we don't need to change it

    // Fill initial balance
    const balanceInput = screen.getByPlaceholderText('0.00');
    await user.clear(balanceInput);
    await user.type(balanceInput, '1000.00');

    // Submit
    const submitButton = screen.getByRole('button', { name: /create account/i });
    await user.click(submitButton);

    // Wait for submission
    await waitFor(() => {
      expect(onSubmit).toHaveBeenCalledWith({
        name: 'Checking Account',
        account_type: 'Bank',
        currency_code: 'CNY',
        initial_balance: 1000.00,
      });
    });
  });

  it('calls onCancel when cancel button is clicked', async () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();
    const user = userEvent.setup();

    render(<AccountForm onSubmit={onSubmit} onCancel={onCancel} />);

    const cancelButton = screen.getByRole('button', { name: /cancel/i });
    await user.click(cancelButton);

    expect(onCancel).toHaveBeenCalled();
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('disables buttons when isLoading is true', () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();

    render(<AccountForm onSubmit={onSubmit} onCancel={onCancel} isLoading={true} />);

    const submitButton = screen.getByRole('button', { name: /creating.../i });
    const cancelButton = screen.getByRole('button', { name: /cancel/i });

    expect(submitButton).toBeDisabled();
    expect(cancelButton).toBeDisabled();
  });
});
