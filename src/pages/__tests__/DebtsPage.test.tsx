import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { DebtsPage } from '../DebtsPage';
import * as debtApi from '@/lib/tauri/debt';

vi.mock('@/lib/tauri/debt');
vi.mock('@/hooks/useMediaQuery', () => ({
  useMediaQuery: () => true,
}));

const createTestQueryClient = () =>
  new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  });

const mockDebts: debtApi.DebtDto[] = [
  {
    id: '1',
    debt_type: 'Loan',
    counterparty: 'Bank of China',
    principal_amount: '100000.00',
    currency_code: 'CNY',
    interest_rate: '5.0',
    start_date: '2024-01-01',
    due_date: '2025-01-01',
    payment_schedule: [
      {
        payment_date: '2024-02-01',
        principal_amount: '8333.33',
        interest_amount: '416.67',
        total_amount: '8750.00',
        currency_code: 'CNY',
        paid: false,
      },
    ],
    remaining_balance: '100000.00',
    created_at: '2024-01-01T00:00:00Z',
    updated_at: '2024-01-01T00:00:00Z',
  },
];

describe('DebtsPage', () => {
  it('renders loading state initially', () => {
    vi.mocked(debtApi.listDebts).mockImplementation(
      () => new Promise(() => {}) // Never resolves
    );
    vi.mocked(debtApi.getUpcomingPayments).mockImplementation(
      () => new Promise(() => {})
    );

    const queryClient = createTestQueryClient();
    render(
      <QueryClientProvider client={queryClient}>
        <DebtsPage />
      </QueryClientProvider>
    );

    expect(screen.getByText(/loading debts/i)).toBeInTheDocument();
  });

  it('renders empty state when no debts exist', async () => {
    vi.mocked(debtApi.listDebts).mockResolvedValue([]);
    vi.mocked(debtApi.getUpcomingPayments).mockResolvedValue([]);

    const queryClient = createTestQueryClient();
    render(
      <QueryClientProvider client={queryClient}>
        <DebtsPage />
      </QueryClientProvider>
    );

    await waitFor(() => {
      expect(screen.getByText(/no debts yet/i)).toBeInTheDocument();
    });
  });

  it('renders debt list with data', async () => {
    vi.mocked(debtApi.listDebts).mockResolvedValue(mockDebts);
    vi.mocked(debtApi.getUpcomingPayments).mockResolvedValue([]);

    const queryClient = createTestQueryClient();
    render(
      <QueryClientProvider client={queryClient}>
        <DebtsPage />
      </QueryClientProvider>
    );

    await waitFor(() => {
      expect(screen.getAllByText('Bank of China').length).toBeGreaterThan(0);
      expect(screen.getAllByText('Loan').length).toBeGreaterThan(0);
    });
  });

  it('opens create sheet when Create Debt button is clicked', async () => {
    vi.mocked(debtApi.listDebts).mockResolvedValue([]);
    vi.mocked(debtApi.getUpcomingPayments).mockResolvedValue([]);

    const queryClient = createTestQueryClient();
    const user = userEvent.setup();

    render(
      <QueryClientProvider client={queryClient}>
        <DebtsPage />
      </QueryClientProvider>
    );

    await waitFor(() => {
      expect(screen.getByText(/no debts yet/i)).toBeInTheDocument();
    });

    const createButton = screen.getAllByText(/create debt/i)[0];
    await user.click(createButton);

    // Sheet opens with DebtForm containing the counterparty field
    await waitFor(() => {
      expect(screen.getByPlaceholderText(/e.g., Bank of China/i)).toBeInTheDocument();
    });
  });

  it('displays overdue debts section when debts are overdue', async () => {
    const overdueDebt: debtApi.DebtDto = {
      ...mockDebts[0],
      due_date: '2020-01-01', // Past date
      remaining_balance: '50000.00',
    };

    vi.mocked(debtApi.listDebts).mockResolvedValue([overdueDebt]);
    vi.mocked(debtApi.getUpcomingPayments).mockResolvedValue([]);

    const queryClient = createTestQueryClient();
    render(
      <QueryClientProvider client={queryClient}>
        <DebtsPage />
      </QueryClientProvider>
    );

    await waitFor(() => {
      expect(screen.getByText(/overdue debts/i)).toBeInTheDocument();
    });
  });

  it('displays upcoming payments section when payments are due', async () => {
    const upcomingPayment: debtApi.UpcomingPaymentDto = {
      debt: mockDebts[0],
      payment: mockDebts[0].payment_schedule[0],
    };

    vi.mocked(debtApi.listDebts).mockResolvedValue(mockDebts);
    vi.mocked(debtApi.getUpcomingPayments).mockResolvedValue([upcomingPayment]);

    const queryClient = createTestQueryClient();
    render(
      <QueryClientProvider client={queryClient}>
        <DebtsPage />
      </QueryClientProvider>
    );

    await waitFor(() => {
      expect(screen.getByText(/upcoming payments/i)).toBeInTheDocument();
    });
  });
});
