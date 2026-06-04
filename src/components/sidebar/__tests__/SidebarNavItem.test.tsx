import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { SidebarNavItem } from '../SidebarNavItem';

const MockIcon = ({ className }: { className?: string }) => (
  <svg data-testid="mock-icon" className={className} />
);

vi.mock('@tanstack/react-router', () => ({
  Link: ({
    to,
    children,
    className,
    activeProps,
    activeOptions,
    onClick,
  }: {
    to: string;
    children: React.ReactNode;
    className?: string;
    activeProps?: { className?: string };
    activeOptions?: { exact?: boolean };
    onClick?: () => void;
  }) => (
    <a
      href={to}
      data-active-class={activeProps?.className}
      data-exact={activeOptions?.exact}
      className={className}
      onClick={onClick}
    >
      {children}
    </a>
  ),
}));

describe('SidebarNavItem', () => {
  it('renders label and icon', () => {
    render(
      <SidebarNavItem
        to="/accounts"
        label="Accounts"
        icon={MockIcon}
      />
    );

    expect(screen.getByText('Accounts')).toBeInTheDocument();
    expect(screen.getByTestId('mock-icon')).toBeInTheDocument();
  });

  it('has correct href', () => {
    render(
      <SidebarNavItem
        to="/accounts"
        label="Accounts"
        icon={MockIcon}
      />
    );

    const link = screen.getByRole('link');
    expect(link).toHaveAttribute('href', '/accounts');
  });

  it('calls onNavigate when clicked', async () => {
    const user = userEvent.setup();
    const onNavigate = vi.fn();

    render(
      <SidebarNavItem
        to="/accounts"
        label="Accounts"
        icon={MockIcon}
        onNavigate={onNavigate}
      />
    );

    const link = screen.getByRole('link');
    await user.click(link);

    expect(onNavigate).toHaveBeenCalledTimes(1);
  });

  it('applies exact prop for active options', () => {
    render(
      <SidebarNavItem
        to="/"
        label="Dashboard"
        icon={MockIcon}
        exact
      />
    );

    const link = screen.getByRole('link');
    expect(link).toHaveAttribute('data-exact', 'true');
  });

  it('does not set exact when prop is omitted', () => {
    render(
      <SidebarNavItem
        to="/accounts"
        label="Accounts"
        icon={MockIcon}
      />
    );

    const link = screen.getByRole('link');
    expect(link).not.toHaveAttribute('data-exact');
  });
});
