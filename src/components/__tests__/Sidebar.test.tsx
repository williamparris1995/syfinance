import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Sidebar } from '@/components/sidebar/Sidebar';

const mockLocation = { pathname: '/' };

vi.mock('@tanstack/react-router', () => ({
  useRouterState: () => ({ location: mockLocation }),
  Link: ({
    children,
    to,
    activeOptions: _activeOptions,
    activeProps: _activeProps,
    ...props
  }: {
    children: React.ReactNode;
    to: string;
    activeOptions?: unknown;
    activeProps?: unknown;
    [key: string]: unknown;
  }) => (
    <a href={to} {...props}>
      {children}
    </a>
  ),
}));

describe('Sidebar', () => {
  beforeEach(() => {
    localStorage.clear();
    mockLocation.pathname = '/';
  });

  it('renders all nav groups', () => {
    render(<Sidebar />);
    expect(screen.getByText('Overview')).toBeInTheDocument();
    expect(screen.getByText('Assets')).toBeInTheDocument();
    expect(screen.getByText('Planning')).toBeInTheDocument();
    expect(screen.getByText('Analysis')).toBeInTheDocument();
    expect(screen.getByText('System')).toBeInTheDocument();
    // "Transactions" appears as both group label and nav item — use getAllByText
    expect(screen.getAllByText('Transactions').length).toBeGreaterThanOrEqual(1);
  });

  it('renders all nav items', () => {
    render(<Sidebar />);
    expect(screen.getByText('Dashboard')).toBeInTheDocument();
    expect(screen.getByText('Accounts')).toBeInTheDocument();
    expect(screen.getByText('Portfolio')).toBeInTheDocument();
    expect(screen.getByText('Debts')).toBeInTheDocument();
    expect(screen.getByText('Recurring')).toBeInTheDocument();
    expect(screen.getByText('Goals')).toBeInTheDocument();
    expect(screen.getByText('Budget')).toBeInTheDocument();
    expect(screen.getByText('Reminders')).toBeInTheDocument();
    expect(screen.getByText('Reports')).toBeInTheDocument();
    expect(screen.getByText('Settings')).toBeInTheDocument();
    expect(screen.getByText('Backup')).toBeInTheDocument();
  });

  it('calls onNavigate when nav item is clicked', async () => {
    const user = userEvent.setup();
    const onNavigate = vi.fn();

    render(<Sidebar onNavigate={onNavigate} />);
    await user.click(screen.getByText('Dashboard'));
    expect(onNavigate).toHaveBeenCalled();
  });

  it('toggles group collapse', async () => {
    const user = userEvent.setup();
    render(<Sidebar />);

    const planningHeader = screen.getByText('Planning');
    await user.click(planningHeader);

    // After collapsing, the Goals link should be hidden (maxHeight: 0, opacity: 0)
    const goalsLink = screen.getByText('Goals').closest('a');
    expect(goalsLink).not.toBeVisible();
  });

  it('forces active group open', () => {
    mockLocation.pathname = '/budget';
    localStorage.setItem('sidebar-group-state', JSON.stringify({ planning: false }));

    render(<Sidebar />);
    expect(screen.getByText('Goals')).toBeInTheDocument();
    expect(screen.getByText('Budget')).toBeInTheDocument();
  });
});
