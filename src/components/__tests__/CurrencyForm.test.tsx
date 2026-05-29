import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { CurrencyForm } from '../CurrencyForm';

describe('CurrencyForm', () => {
  it('validates ISO 4217 currency code - must be 3 uppercase letters', async () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();

    render(<CurrencyForm onSubmit={onSubmit} onCancel={onCancel} />);

    const codeInput = screen.getByLabelText(/Currency Code/i);
    const symbolInput = screen.getByLabelText(/Currency Symbol/i);
    const rateInput = screen.getByLabelText(/Exchange Rate/i);
    const submitButton = screen.getByRole('button', { name: /Add Currency/i });

    // Test invalid: only 2 letters
    await userEvent.type(codeInput, 'US');
    await userEvent.type(symbolInput, '$');
    await userEvent.type(rateInput, '7.25');
    await userEvent.click(submitButton);

    await waitFor(() => {
      expect(screen.getByText(/Currency code must be exactly 3 characters/i)).toBeInTheDocument();
    });
    expect(onSubmit).not.toHaveBeenCalled();

    // Test valid: lowercase auto-uppercases and passes
    await userEvent.clear(codeInput);
    await userEvent.type(codeInput, 'eur');
    await userEvent.clear(symbolInput);
    await userEvent.type(symbolInput, '€');
    await userEvent.click(submitButton);

    await waitFor(() => {
      expect(onSubmit).toHaveBeenCalledWith({
        code: 'EUR',
        symbol: '€',
        exchange_rate: '7.25',
      });
    });
  });

  it('validates exchange rate must be positive', async () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();

    render(<CurrencyForm onSubmit={onSubmit} onCancel={onCancel} />);

    const codeInput = screen.getByLabelText(/Currency Code/i);
    const symbolInput = screen.getByLabelText(/Currency Symbol/i);
    const rateInput = screen.getByLabelText(/Exchange Rate/i);
    const submitButton = screen.getByRole('button', { name: /Add Currency/i });

    await userEvent.type(codeInput, 'USD');
    await userEvent.type(symbolInput, '$');
    await userEvent.type(rateInput, '0');
    await userEvent.click(submitButton);

    await waitFor(() => {
      expect(screen.getByText(/Exchange rate must be greater than 0/i)).toBeInTheDocument();
    });
    expect(onSubmit).not.toHaveBeenCalled();

    // Test negative value
    await userEvent.clear(rateInput);
    await userEvent.type(rateInput, '-5');
    await userEvent.click(submitButton);

    await waitFor(() => {
      expect(screen.getByText(/Exchange rate must be greater than 0/i)).toBeInTheDocument();
    });
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('submits valid currency data', async () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();

    render(<CurrencyForm onSubmit={onSubmit} onCancel={onCancel} />);

    const codeInput = screen.getByLabelText(/Currency Code/i);
    const symbolInput = screen.getByLabelText(/Currency Symbol/i);
    const rateInput = screen.getByLabelText(/Exchange Rate/i);
    const submitButton = screen.getByRole('button', { name: /Add Currency/i });

    await userEvent.type(codeInput, 'USD');
    await userEvent.type(symbolInput, '$');
    await userEvent.type(rateInput, '7.25');
    await userEvent.click(submitButton);

    await waitFor(() => {
      expect(onSubmit).toHaveBeenCalledWith({
        code: 'USD',
        symbol: '$',
        exchange_rate: '7.25',
      });
    });
  });

  it('auto-uppercases currency code input', async () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();

    render(<CurrencyForm onSubmit={onSubmit} onCancel={onCancel} />);

    const codeInput = screen.getByLabelText(/Currency Code/i) as HTMLInputElement;

    await userEvent.type(codeInput, 'usd');

    expect(codeInput.value).toBe('USD');
  });

  it('calls onCancel when cancel button is clicked', async () => {
    const onSubmit = vi.fn();
    const onCancel = vi.fn();

    render(<CurrencyForm onSubmit={onSubmit} onCancel={onCancel} />);

    const cancelButton = screen.getByRole('button', { name: /Cancel/i });
    await userEvent.click(cancelButton);

    expect(onCancel).toHaveBeenCalled();
    expect(onSubmit).not.toHaveBeenCalled();
  });
});
