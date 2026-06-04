import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { SidebarGroup } from '../SidebarGroup';

describe('SidebarGroup', () => {
  it('renders group label', () => {
    render(
      <SidebarGroup label="Accounts" isOpen={true} onToggle={() => {}}>
        <div>Child content</div>
      </SidebarGroup>
    );

    expect(screen.getByText('Accounts')).toBeInTheDocument();
  });

  it('renders children when open', () => {
    render(
      <SidebarGroup label="Accounts" isOpen={true} onToggle={() => {}}>
        <div data-testid="child">Child content</div>
      </SidebarGroup>
    );

    expect(screen.getByTestId('child')).toBeInTheDocument();
  });

  it('hides children when closed', () => {
    render(
      <SidebarGroup label="Accounts" isOpen={false} onToggle={() => {}}>
        <div data-testid="child">Child content</div>
      </SidebarGroup>
    );

    expect(screen.getByTestId('child')).toBeInTheDocument();
    const contentWrapper = screen.getByTestId('child').parentElement?.parentElement;
    expect(contentWrapper).toHaveStyle({ maxHeight: '0px', opacity: '0' });
  });

  it('calls onToggle when header is clicked', async () => {
    const user = userEvent.setup();
    const onToggle = vi.fn();

    render(
      <SidebarGroup label="Accounts" isOpen={true} onToggle={onToggle}>
        <div>Child content</div>
      </SidebarGroup>
    );

    const button = screen.getByRole('button');
    await user.click(button);

    expect(onToggle).toHaveBeenCalledTimes(1);
  });

  it('does NOT call onToggle when disabled', async () => {
    const user = userEvent.setup();
    const onToggle = vi.fn();

    render(
      <SidebarGroup
        label="Accounts"
        isOpen={true}
        onToggle={onToggle}
        toggleDisabled={true}
      >
        <div>Child content</div>
      </SidebarGroup>
    );

    const button = screen.getByRole('button');
    await user.click(button);

    expect(onToggle).not.toHaveBeenCalled();
  });

  it('has aria-expanded attribute', () => {
    const { rerender } = render(
      <SidebarGroup label="Accounts" isOpen={true} onToggle={() => {}}>
        <div>Child content</div>
      </SidebarGroup>
    );

    const button = screen.getByRole('button');
    expect(button).toHaveAttribute('aria-expanded', 'true');

    rerender(
      <SidebarGroup label="Accounts" isOpen={false} onToggle={() => {}}>
        <div>Child content</div>
      </SidebarGroup>
    );

    expect(button).toHaveAttribute('aria-expanded', 'false');
  });
});
