import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { DebtsPage } from '../DebtsPage';
import * as debtApi from '@/lib/tauri/debt';
import * as accountApi from '@/lib/tauri/account';

vi.mock('@/lib/tauri/debt');
vi.mock('@/lib/tauri/account');
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
    account_id: '1',
    account_name: 'Home Mortgage',
    account_type: 'BorrowedIn',
    counterparty: 'Bank of China',
    principal_amount: '100000.00',
    currency_code: 'CNY',
    interest_rate: '5.0',
    start_date: '2024-01-01',
    due_date: '2025-01-01',
    amortization_method: 'EqualPrincipalInterest',
    remaining_principal: '100000.00',
    payment_schedule: [
      {
        id: 'schedule-1',
        payment_date: '2024-02-01',
        principal_amount: '8333.33',
        interest_amount: '416.67',
        total_amount: '8750.00',
        paid: false,
        transaction_id: null,
      },
    ],
  },
];

const mockAccounts: accountApi.AccountDto[] = [
  {
    id: 'bank-1',
    name: 'Checking',
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

describe('DebtsPage', () => {
  it('renders loading state initially', () => {
    vi.mocked(debtApi.listDebts).mockImplementation(
      () => new Promise(() => {})
    );
    vi.mocked(debtApi.getUpcomingPayments).mockImplementation(
      () => new Promise(() => {})
    );
    vi.mocked(accountApi.listAccounts).mockResolvedValue([]);

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
    vi.mocked(accountApi.listAccounts).mockResolvedValue(mockAccounts);

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
    vi.mocked(accountApi.listAccounts).mockResolvedValue(mockAccounts);

    const queryClient = createTestQueryClient();
    render(
      <QueryClientProvider client={queryClient}>
        <DebtsPage />
      </QueryClientProvider>
    );

    await waitFor(() => {
      expect(screen.getAllByText('Bank of China').length).toBeGreaterThan(0);
      expect(screen.getByText('Home Mortgage')).toBeInTheDocument();
    });
  });

  it('opens create sheet when Create Debt button is clicked', async () => {
    vi.mocked(debtApi.listDebts).mockResolvedValue([]);
    vi.mocked(debtApi.getUpcomingPayments).mockResolvedValue([]);
    vi.mocked(accountApi.listAccounts).mockResolvedValue(mockAccounts);

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

    await waitFor(() => {
      expect(screen.getByPlaceholderText(/e.g., Bank of China/i)).toBeInTheDocument();
    });
  });

  it('displays overdue debts section when debts are overdue', async () => {
    const overdueDebt: debtApi.DebtDto = {
      ...mockDebts[0],
      due_date: '2020-01-01',
      remaining_principal: '50000.00',
    };

    vi.mocked(debtApi.listDebts).mockResolvedValue([overdueDebt]);
    vi.mocked(debtApi.getUpcomingPayments).mockResolvedValue([]);
    vi.mocked(accountApi.listAccounts).mockResolvedValue(mockAccounts);

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
});
