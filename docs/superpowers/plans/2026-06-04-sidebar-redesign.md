# Sidebar Redesign — Functional Domain Grouping Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the sidebar from a flat 6-item list into 6 collapsible functional domain groups with 11 nav items, using localStorage persistence for collapse state.

**Architecture:** Decompose Sidebar into smaller focused components (SidebarGroup, SidebarNavItem), extract state management into a reusable hook (useSidebarState), and update i18n keys. Keep MobileSidebar unchanged except for passing through props.

**Tech Stack:** React 18, TypeScript, Tailwind CSS, shadcn/ui, TanStack Router, i18next, Lucide React, Vitest + Testing Library

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `src/hooks/useSidebarState.ts` | Create | Manages collapsible group state with localStorage persistence |
| `src/components/sidebar/SidebarGroup.tsx` | Create | Renders a collapsible group header + animated content area |
| `src/components/sidebar/SidebarNavItem.tsx` | Create | Renders a single nav link with icon and active state |
| `src/components/sidebar/Sidebar.tsx` | Modify | Top-level sidebar using groups, hooks, and nav items |
| `src/components/sidebar/index.ts` | Create | Barrel export for sidebar components |
| `src/components/layout/MobileSidebar.tsx` | Modify | Pass onNavigate prop through to Sidebar |
| `src/i18n/locales/en.json` | Modify | Add new nav group label keys |
| `src/i18n/locales/zh.json` | Modify | Add new nav group label keys |
| `src/components/__tests__/Sidebar.test.tsx` | Create | Test sidebar rendering, active state, collapse/expand, persistence |

---

## Task 1: Add i18n Keys

**Files:**
- Modify: `src/i18n/locales/en.json`
- Modify: `src/i18n/locales/zh.json`

- [ ] **Step 1: Add English nav group labels**

In `src/i18n/locales/en.json`, add the following keys inside the existing `"nav"` object (after `"settings"`):

```json
    "overview": "Overview",
    "assetManagement": "Assets",
    "transactionsGroup": "Transactions",
    "planning": "Planning",
    "analysis": "Analysis",
    "system": "System",
    "backup": "Backup"
```

The full `nav` section should look like:

```json
  "nav": {
    "appTitle": "Finance App",
    "dashboard": "Dashboard",
    "transactions": "Transactions",
    "accounts": "Accounts",
    "debts": "Debts",
    "holdings": "Portfolio",
    "subscriptions": "Subscriptions",
    "recurring": "Recurring",
    "budget": "Budget",
    "goals": "Goals",
    "reports": "Reports",
    "reminders": "Reminders",
    "settings": "Settings",
    "overview": "Overview",
    "assetManagement": "Assets",
    "transactionsGroup": "Transactions",
    "planning": "Planning",
    "analysis": "Analysis",
    "system": "System",
    "backup": "Backup"
  },
```

- [ ] **Step 2: Add Chinese nav group labels**

In `src/i18n/locales/zh.json`, add the same keys with Chinese translations:

```json
    "overview": "概览",
    "assetManagement": "资产管理",
    "transactionsGroup": "交易操作",
    "planning": "规划",
    "analysis": "分析",
    "system": "系统",
    "backup": "备份"
```

- [ ] **Step 3: Verify tests can read new keys**

Run: `npx vitest run src/__tests__/App.test.tsx`

Expected: PASS (tests load en.json at startup via vitest.setup.ts)

- [ ] **Step 4: Commit**

```bash
git add src/i18n/locales/en.json src/i18n/locales/zh.json
git commit -m "i18n: add sidebar group label keys for en and zh

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Create useSidebarState Hook

**Files:**
- Create: `src/hooks/useSidebarState.ts`
- Test: `src/hooks/__tests__/useSidebarState.test.ts`

- [ ] **Step 1: Write the failing test**

Create `src/hooks/__tests__/useSidebarState.test.ts`:

```typescript
import { describe, it, expect, beforeEach } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { useSidebarState } from '../useSidebarState';

describe('useSidebarState', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it('returns all groups open by default', () => {
    const { result } = renderHook(() => useSidebarState());
    expect(result.current.isGroupOpen('assetManagement')).toBe(true);
    expect(result.current.isGroupOpen('planning')).toBe(true);
  });

  it('toggles group open state', () => {
    const { result } = renderHook(() => useSidebarState());

    act(() => {
      result.current.toggleGroup('assetManagement');
    });

    expect(result.current.isGroupOpen('assetManagement')).toBe(false);
  });

  it('persists state to localStorage', () => {
    const { result } = renderHook(() => useSidebarState());

    act(() => {
      result.current.toggleGroup('system');
    });

    expect(localStorage.getItem('sidebar-group-state')).toContain('"system":false');
  });

  it('reads state from localStorage on mount', () => {
    localStorage.setItem('sidebar-group-state', JSON.stringify({ planning: false }));

    const { result } = renderHook(() => useSidebarState());
    expect(result.current.isGroupOpen('planning')).toBe(false);
    expect(result.current.isGroupOpen('assetManagement')).toBe(true);
  });

  it('handles corrupted localStorage gracefully', () => {
    localStorage.setItem('sidebar-group-state', 'not-json');

    const { result } = renderHook(() => useSidebarState());
    expect(result.current.isGroupOpen('assetManagement')).toBe(true);
  });

  it('forces open the active group', () => {
    const { result } = renderHook(() => useSidebarState('planning'));

    // Even if localStorage says it's closed
    localStorage.setItem('sidebar-group-state', JSON.stringify({ planning: false }));

    // After re-rendering with active group
    const { result: result2 } = renderHook(() => useSidebarState('planning'));
    expect(result2.current.isGroupOpen('planning')).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/hooks/__tests__/useSidebarState.test.ts`

Expected: FAIL — "useSidebarState" module not found

- [ ] **Step 3: Implement useSidebarState**

Create `src/hooks/useSidebarState.ts`:

```typescript
import { useState, useCallback, useEffect } from 'react';

const STORAGE_KEY = 'sidebar-group-state';

export type GroupId =
  | 'overview'
  | 'assetManagement'
  | 'transactions'
  | 'planning'
  | 'analysis'
  | 'system';

interface GroupState {
  [groupId: string]: boolean;
}

const defaultState: GroupState = {
  overview: true,
  assetManagement: true,
  transactions: true,
  planning: true,
  analysis: true,
  system: true,
};

function readState(): GroupState {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return { ...defaultState };
    const parsed = JSON.parse(raw) as GroupState;
    // Merge with defaults for any missing groups
    return { ...defaultState, ...parsed };
  } catch {
    return { ...defaultState };
  }
}

function writeState(state: GroupState): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch {
    // Silently fail if localStorage is unavailable
  }
}

export function useSidebarState(activeGroupId?: GroupId) {
  const [state, setState] = useState<GroupState>(() => {
    const saved = readState();
    if (activeGroupId) {
      saved[activeGroupId] = true;
    }
    return saved;
  });

  useEffect(() => {
    if (activeGroupId) {
      setState((prev) => {
        if (prev[activeGroupId]) return prev;
        const next = { ...prev, [activeGroupId]: true };
        writeState(next);
        return next;
      });
    }
  }, [activeGroupId]);

  const isGroupOpen = useCallback(
    (groupId: GroupId) => {
      if (activeGroupId && groupId === activeGroupId) return true;
      return state[groupId] ?? true;
    },
    [state, activeGroupId]
  );

  const toggleGroup = useCallback((groupId: GroupId) => {
    // Don't allow toggling the active group
    if (activeGroupId && groupId === activeGroupId) return;

    setState((prev) => {
      const next = { ...prev, [groupId]: !prev[groupId] };
      writeState(next);
      return next;
    });
  }, [activeGroupId]);

  return { isGroupOpen, toggleGroup };
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx vitest run src/hooks/__tests__/useSidebarState.test.ts`

Expected: All 6 tests PASS

- [ ] **Step 5: Commit**

```bash
git add src/hooks/useSidebarState.ts src/hooks/__tests__/useSidebarState.test.ts
git commit -m "feat(sidebar): add useSidebarState hook with localStorage persistence

- Manages collapsible group state
- Handles corrupted localStorage gracefully
- Forces active group to stay open

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Create SidebarNavItem Component

**Files:**
- Create: `src/components/sidebar/SidebarNavItem.tsx`
- Test: `src/components/sidebar/__tests__/SidebarNavItem.test.tsx`

- [ ] **Step 1: Write the failing test**

Create `src/components/sidebar/__tests__/SidebarNavItem.test.tsx`:

```typescript
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { SidebarNavItem } from '../SidebarNavItem';
import { Home } from 'lucide-react';

vi.mock('@tanstack/react-router', () => ({
  Link: ({
    children,
    to,
    ...props
  }: {
    children: React.ReactNode;
    to: string;
    [key: string]: unknown;
  }) => (
    <a href={to} {...props}>
      {children}
    </a>
  ),
}));

describe('SidebarNavItem', () => {
  it('renders label and icon', () => {
    render(<SidebarNavItem to="/" label="Dashboard" icon={Home} />);
    expect(screen.getByText('Dashboard')).toBeInTheDocument();
  });

  it('has correct href', () => {
    render(<SidebarNavItem to="/accounts" label="Accounts" icon={Home} />);
    expect(screen.getByRole('link')).toHaveAttribute('href', '/accounts');
  });

  it('calls onNavigate when clicked', async () => {
    const user = userEvent.setup();
    const onNavigate = vi.fn();

    render(
      <SidebarNavItem to="/" label="Dashboard" icon={Home} onNavigate={onNavigate} />
    );

    await user.click(screen.getByRole('link'));
    expect(onNavigate).toHaveBeenCalledTimes(1);
  });

  it('applies exact active styling', () => {
    render(<SidebarNavItem to="/" label="Dashboard" icon={Home} exact />);
    const link = screen.getByRole('link');
    expect(link).toHaveAttribute('data-exact', 'true');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/components/sidebar/__tests__/SidebarNavItem.test.tsx`

Expected: FAIL — module not found

- [ ] **Step 3: Implement SidebarNavItem**

Create `src/components/sidebar/SidebarNavItem.tsx`:

```typescript
import { Link } from '@tanstack/react-router';

interface SidebarNavItemProps {
  to: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  exact?: boolean;
  onNavigate?: () => void;
}

export function SidebarNavItem({
  to,
  label,
  icon: Icon,
  exact,
  onNavigate,
}: SidebarNavItemProps) {
  return (
    <Link
      to={to}
      data-exact={exact || undefined}
      activeOptions={exact ? { exact: true } : undefined}
      activeProps={{
        className: 'bg-sidebar-accent text-sidebar-accent-foreground',
      }}
      className="flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium text-sidebar-foreground transition-colors hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
      onClick={onNavigate}
    >
      <Icon className="h-4 w-4" />
      <span>{label}</span>
    </Link>
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx vitest run src/components/sidebar/__tests__/SidebarNavItem.test.tsx`

Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add src/components/sidebar/SidebarNavItem.tsx src/components/sidebar/__tests__/SidebarNavItem.test.tsx
git commit -m "feat(sidebar): add SidebarNavItem component

- Extracted reusable nav item with icon, label, active state
- Supports optional onNavigate callback for mobile

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Create SidebarGroup Component

**Files:**
- Create: `src/components/sidebar/SidebarGroup.tsx`
- Test: `src/components/sidebar/__tests__/SidebarGroup.test.tsx`

- [ ] **Step 1: Write the failing test**

Create `src/components/sidebar/__tests__/SidebarGroup.test.tsx`:

```typescript
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { SidebarGroup } from '../SidebarGroup';

describe('SidebarGroup', () => {
  it('renders group label', () => {
    // label is user-visible text passed from parent via t()
    render(
      <SidebarGroup label="Assets" isOpen={true} onToggle={() => {}}>
        <div>Child content</div>
      </SidebarGroup>
    );
    expect(screen.getByText('Assets')).toBeInTheDocument();
  });

  it('renders children when open', () => {
    render(
      <SidebarGroup label="Assets" isOpen={true} onToggle={() => {}}>
        <div data-testid="child">Child</div>
      </SidebarGroup>
    );
    expect(screen.getByTestId('child')).toBeInTheDocument();
  });

  it('hides children when closed', () => {
    render(
      <SidebarGroup label="Assets" isOpen={false} onToggle={() => {}}>
        <div data-testid="child">Child</div>
      </SidebarGroup>
    );
    expect(screen.queryByTestId('child')).not.toBeVisible();
  });

  it('calls onToggle when header is clicked', async () => {
    const user = userEvent.setup();
    const onToggle = vi.fn();

    render(
      <SidebarGroup label="Assets" isOpen={true} onToggle={onToggle}>
        <div>Child</div>
      </SidebarGroup>
    );

    await user.click(screen.getByText('Assets'));
    expect(onToggle).toHaveBeenCalledTimes(1);
  });

  it('does not call onToggle when disabled', async () => {
    const user = userEvent.setup();
    const onToggle = vi.fn();

    render(
      <SidebarGroup
        label="Assets"
        isOpen={true}
        onToggle={onToggle}
        toggleDisabled={true}
      >
        <div>Child</div>
      </SidebarGroup>
    );

    await user.click(screen.getByText('Assets'));
    expect(onToggle).not.toHaveBeenCalled();
  });

  it('has aria-expanded attribute', () => {
    render(
      <SidebarGroup label="Assets" isOpen={true} onToggle={() => {}}>
        <div>Child</div>
      </SidebarGroup>
    );

    expect(screen.getByRole('button')).toHaveAttribute('aria-expanded', 'true');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/components/sidebar/__tests__/SidebarGroup.test.tsx`

Expected: FAIL — module not found

- [ ] **Step 3: Implement SidebarGroup**

Create `src/components/sidebar/SidebarGroup.tsx`:

```typescript
import { ChevronDown, ChevronRight } from 'lucide-react';

interface SidebarGroupProps {
  label: string;
  isOpen: boolean;
  onToggle: () => void;
  toggleDisabled?: boolean;
  children: React.ReactNode;
}

export function SidebarGroup({
  label,
  isOpen,
  onToggle,
  toggleDisabled,
  children,
}: SidebarGroupProps) {
  const ToggleIcon = isOpen ? ChevronDown : ChevronRight;

  return (
    <div className="mt-1">
      <button
        type="button"
        onClick={() => {
          if (!toggleDisabled) onToggle();
        }}
        disabled={toggleDisabled}
        aria-expanded={isOpen}
        className="flex w-full items-center justify-between rounded-md px-3 py-1.5 text-xs font-medium uppercase tracking-wider text-sidebar-foreground/60 transition-colors hover:bg-sidebar-accent/50 disabled:cursor-default disabled:opacity-50"
      >
        <span>{label}</span>
        <ToggleIcon className="h-3.5 w-3.5" />
      </button>
      <div
        className="space-y-px overflow-hidden transition-all duration-150 ease-in-out"
        style={{
          maxHeight: isOpen ? '500px' : '0px',
          opacity: isOpen ? 1 : 0,
        }}
      >
        {children}
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx vitest run src/components/sidebar/__tests__/SidebarGroup.test.tsx`

Expected: All 6 tests PASS

- [ ] **Step 5: Commit**

```bash
git add src/components/sidebar/SidebarGroup.tsx src/components/sidebar/__tests__/SidebarGroup.test.tsx
git commit -m "feat(sidebar): add SidebarGroup component with collapse/expand

- Animated open/close with CSS transition
- Accessible with aria-expanded
- Supports disabled toggle for active group

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Create Barrel Export

**Files:**
- Create: `src/components/sidebar/index.ts`

- [ ] **Step 1: Create barrel export**

Create `src/components/sidebar/index.ts`:

```typescript
export { Sidebar } from './Sidebar';
export { SidebarGroup } from './SidebarGroup';
export { SidebarNavItem } from './SidebarNavItem';
```

- [ ] **Step 2: Commit**

```bash
git add src/components/sidebar/index.ts
git commit -m "chore(sidebar): add barrel export for sidebar components

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: Refactor Sidebar Component

**Files:**
- Modify: `src/components/sidebar/Sidebar.tsx` (move from `src/components/Sidebar.tsx`)
- Test: `src/components/__tests__/Sidebar.test.tsx`

- [ ] **Step 1: Delete old Sidebar.tsx and write new one**

First, delete `src/components/Sidebar.tsx`:

```bash
git rm src/components/Sidebar.tsx
```

Then create `src/components/sidebar/Sidebar.tsx`:

```typescript
import {
  Home,
  Wallet,
  BarChart3,
  CreditCard,
  Receipt,
  Repeat,
  Target,
  ClipboardList,
  Bell,
  PieChart,
  Settings,
  Database,
} from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { useRouterState } from '@tanstack/react-router';
import { useSidebarState, type GroupId } from '@/hooks/useSidebarState';
import { SidebarGroup } from './SidebarGroup';
import { SidebarNavItem } from './SidebarNavItem';

interface NavItemConfig {
  to: string;
  labelKey: string;
  icon: React.ComponentType<{ className?: string }>;
  exact?: boolean;
}

interface NavGroupConfig {
  id: GroupId;
  labelKey: string;
  items: NavItemConfig[];
}

const navGroups: NavGroupConfig[] = [
  {
    id: 'overview',
    labelKey: 'nav.overview',
    items: [
      { to: '/', labelKey: 'nav.dashboard', icon: Home, exact: true },
    ],
  },
  {
    id: 'assetManagement',
    labelKey: 'nav.assetManagement',
    items: [
      { to: '/accounts', labelKey: 'nav.accounts', icon: Wallet },
      { to: '/holdings', labelKey: 'nav.holdings', icon: BarChart3 },
      { to: '/debts', labelKey: 'nav.debts', icon: CreditCard },
    ],
  },
  {
    id: 'transactions',
    labelKey: 'nav.transactionsGroup',
    items: [
      { to: '/transactions', labelKey: 'nav.transactions', icon: Receipt },
      { to: '/transaction-templates', labelKey: 'nav.recurring', icon: Repeat },
    ],
  },
  {
    id: 'planning',
    labelKey: 'nav.planning',
    items: [
      { to: '/goals', labelKey: 'nav.goals', icon: Target },
      { to: '/budget', labelKey: 'nav.budget', icon: ClipboardList },
      { to: '/reminders', labelKey: 'nav.reminders', icon: Bell },
    ],
  },
  {
    id: 'analysis',
    labelKey: 'nav.analysis',
    items: [
      { to: '/reports', labelKey: 'nav.reports', icon: PieChart },
    ],
  },
  {
    id: 'system',
    labelKey: 'nav.system',
    items: [
      { to: '/settings', labelKey: 'nav.settings', icon: Settings },
      { to: '/backup', labelKey: 'nav.backup', icon: Database },
    ],
  },
];

function findActiveGroupId(pathname: string): GroupId | undefined {
  for (const group of navGroups) {
    for (const item of group.items) {
      if (item.exact && pathname === item.to) return group.id;
      if (!item.exact && pathname.startsWith(item.to)) return group.id;
    }
  }
  return undefined;
}

interface SidebarProps {
  onNavigate?: () => void;
}

export function Sidebar({ onNavigate }: SidebarProps) {
  const { t } = useTranslation();
  const router = useRouterState();
  const pathname = router.location.pathname;
  const activeGroupId = findActiveGroupId(pathname);
  const { isGroupOpen, toggleGroup } = useSidebarState(activeGroupId);

  return (
    <aside className="flex h-full w-64 flex-col border-r bg-sidebar">
      <div className="border-b px-6 py-4">
        <h1 className="text-lg font-semibold text-sidebar-foreground">
          {t('nav.appTitle')}
        </h1>
      </div>
      <nav className="flex-1 space-y-1 p-4">
        {navGroups.map((group) => (
          <SidebarGroup
            key={group.id}
            label={t(group.labelKey)}
            isOpen={isGroupOpen(group.id)}
            onToggle={() => toggleGroup(group.id)}
            toggleDisabled={group.id === activeGroupId}
          >
            <div className="mt-1 space-y-px">
              {group.items.map((item) => (
                <SidebarNavItem
                  key={item.to}
                  to={item.to}
                  label={t(item.labelKey)}
                  icon={item.icon}
                  exact={item.exact}
                  onNavigate={onNavigate}
                />
              ))}
            </div>
          </SidebarGroup>
        ))}
      </nav>
    </aside>
  );
}
```

- [ ] **Step 2: Write integration test**

Create `src/components/__tests__/Sidebar.test.tsx`:

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Sidebar } from '@/components/sidebar/Sidebar';

// Mock router state
const mockLocation = { pathname: '/' };

vi.mock('@tanstack/react-router', () => ({
  useRouterState: () => ({ location: mockLocation }),
  Link: ({
    children,
    to,
    ...props
  }: {
    children: React.ReactNode;
    to: string;
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
    expect(screen.getByText('Transactions')).toBeInTheDocument();
    expect(screen.getByText('Planning')).toBeInTheDocument();
    expect(screen.getByText('Analysis')).toBeInTheDocument();
    expect(screen.getByText('System')).toBeInTheDocument();
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

    // Planning group should have Goals, Budget, Reminders
    const planningHeader = screen.getByText('Planning');
    await user.click(planningHeader);

    // After collapse, children should not be visible
    expect(screen.getByText('Goals')).not.toBeVisible();
  });

  it('forces active group open', () => {
    mockLocation.pathname = '/budget';
    localStorage.setItem('sidebar-group-state', JSON.stringify({ planning: false }));

    render(<Sidebar />);
    // Planning group should still show its items because /budget is inside it
    expect(screen.getByText('Goals')).toBeInTheDocument();
    expect(screen.getByText('Budget')).toBeInTheDocument();
  });
});
```

- [ ] **Step 3: Run tests to verify they pass**

Run: `npx vitest run src/components/__tests__/Sidebar.test.tsx`

Expected: All 5 tests PASS

- [ ] **Step 4: Run full test suite to check for regressions**

Run: `npx vitest run`

Expected: All existing tests still PASS

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(sidebar): refactor Sidebar with functional domain groups

- Replace flat 6-item list with 6 collapsible groups (11 nav items)
- Use SidebarGroup + SidebarNavItem components
- Integrate useSidebarState for collapse persistence
- Move Sidebar to src/components/sidebar/ directory

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: Update MobileSidebar

**Files:**
- Modify: `src/components/layout/MobileSidebar.tsx`

- [ ] **Step 1: Update import path**

Modify `src/components/layout/MobileSidebar.tsx`:

```typescript
import { useState } from 'react';
import { Menu } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  Sheet,
  SheetContent,
  SheetTrigger,
} from '@/components/ui/sheet';
import { Sidebar } from '@/components/sidebar/Sidebar';

export function MobileSidebar() {
  const [open, setOpen] = useState(false);

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>
        <Button variant="ghost" size="icon" className="md:hidden">
          <Menu className="h-5 w-5" />
        </Button>
      </SheetTrigger>
      <SheetContent side="left" className="p-0 w-64">
        <Sidebar onNavigate={() => setOpen(false)} />
      </SheetContent>
    </Sheet>
  );
}
```

Key changes:
- Import from `@/components/sidebar/Sidebar` instead of `@/components/Sidebar`
- Added `asChild` to `SheetTrigger` (best practice for shadcn/ui)

- [ ] **Step 2: Verify no tests break**

Run: `npx vitest run`

Expected: All tests PASS

- [ ] **Step 3: Commit**

```bash
git add src/components/layout/MobileSidebar.tsx
git commit -m "fix(mobile-sidebar): update import path for refactored Sidebar

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 8: Update App.tsx Import (if needed)

**Files:**
- Check: `src/App.tsx`

- [ ] **Step 1: Check if App.tsx imports Sidebar**

Run: `grep -n "Sidebar" src/App.tsx`

If App.tsx imports `Sidebar` from `@/components/Sidebar`, update it:

```typescript
// Change:
import { Sidebar } from '@/components/Sidebar';
// To:
import { Sidebar } from '@/components/sidebar';
```

If App.tsx does NOT import Sidebar directly, skip this task.

- [ ] **Step 2: Commit if changed**

```bash
git add src/App.tsx
git commit -m "chore: update Sidebar import path

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 9: Run Full Validation

- [ ] **Step 1: Run all frontend tests**

Run: `npx vitest run`

Expected: All tests PASS

- [ ] **Step 2: Run TypeScript check**

Run: `pnpm type-check`

Expected: No errors

- [ ] **Step 3: Run ESLint**

Run: `pnpm lint`

Expected: No errors (or only pre-existing warnings)

- [ ] **Step 4: Visual verification (manual)**

Run: `pnpm tauri dev`

Verify:
- [ ] Sidebar shows 6 groups with 11 nav items
- [ ] Groups can be collapsed/expanded
- [ ] Active group stays open
- [ ] Active item is highlighted
- [ ] Mobile sidebar works via hamburger menu
- [ ] i18n works for both English and Chinese

- [ ] **Step 5: Final commit**

```bash
git commit --allow-empty -m "feat(sidebar): complete sidebar redesign with functional domain grouping

- 6 collapsible groups: Overview, Assets, Transactions, Planning, Analysis, System
- 11 nav items with clear functional boundaries
- localStorage persistence for collapse state
- Active group forced open
- Mobile sidebar updated

Closes sidebar-redesign-design.md spec"
```

---

## Self-Review Checklist

### Spec Coverage

| Spec Section | Implementing Task |
|--------------|-------------------|
| 6 groups / 11 nav items | Task 6 |
| Collapsible groups | Tasks 2, 4, 6 |
| localStorage persistence | Task 2 |
| Active group forced open | Tasks 2, 6 |
| Excluded items (prepaid, tags, export) | N/A — design decision, no code needed |
| Contextual investment plans | N/A — future work in HoldingsPage |
| i18n keys | Task 1 |
| Mobile sidebar | Task 7 |
| Accessibility (aria-expanded) | Task 4 |

### Placeholder Scan

- [x] No "TBD", "TODO", "implement later"
- [x] No vague "add error handling" — specific try/catch in Task 2
- [x] No "Similar to Task N" — each task is self-contained
- [x] No references to undefined types/functions

### Type Consistency

- [x] `GroupId` type used consistently across `useSidebarState`, `Sidebar`
- [x] `NavItemConfig` and `NavGroupConfig` interfaces defined in Sidebar task
- [x] `onNavigate` prop optional and consistent between Sidebar and SidebarNavItem
