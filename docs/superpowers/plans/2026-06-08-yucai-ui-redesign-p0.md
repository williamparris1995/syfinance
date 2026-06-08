# YuCai UI Redesign — P0 Infrastructure Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the YuCai design foundation — theme tokens, sidebar, header, layout, shared component skeletons, and route placeholders — so all existing pages continue to function with the new visual identity.

**Architecture:** Override existing shadcn CSS variables with YuCai design tokens in `src/index.css`. Add new Tailwind extensions for sidebar colors and display font. Rewrite Sidebar and Header components to match the prototype. Create `src/components/patterns/` for reusable page-pattern components. Extend router with placeholder routes for detail/form pages.

**Tech Stack:** React, Tailwind CSS, shadcn/ui, TanStack Router, lucide-react, react-i18next

**Spec:** `docs/superpowers/specs/2026-06-08-yucai-ui-redesign-design.md`

---

## File Map

### Modify
| File | Change |
|------|--------|
| `src/index.css` | Replace CSS variable values with YuCai tokens |
| `tailwind.config.js` | Add `fontFamily.display`, sidebar semantic colors, adjust radius |
| `src/components/sidebar/Sidebar.tsx` | Dark theme, 5 groups, brand area, user footer, collapse button |
| `src/components/sidebar/SidebarGroup.tsx` | Dark styling, collapsed state |
| `src/components/sidebar/SidebarNavItem.tsx` | Dark styling, tooltip on collapsed, badge support |
| `src/components/layout/AppLayout.tsx` | Adapt to 240/64px sidebar widths |
| `src/components/layout/Header.tsx` | Breadcrumb, blur backdrop, remove user menu |
| `src/hooks/useSidebarState.ts` | Update GroupId to match new 5-group structure |
| `src/router.tsx` | Add detail/form route placeholders |
| `src/i18n/locales/en.json` | Add new nav group keys |
| `src/i18n/locales/zh.json` | Add new nav group keys (Chinese) |

### Create
| File | Purpose |
|------|---------|
| `src/components/layout/BreadcrumbBar.tsx` | Breadcrumb navigation component |
| `src/components/patterns/layout/PageShell.tsx` | Page outer container (padding + max-width) |
| `src/components/patterns/layout/PageHeader.tsx` | Title row (h1 + action area slot) |
| `src/components/patterns/layout/FilterBar.tsx` | Filter tab bar (pill buttons + search) |
| `src/components/patterns/cards/HeroCard.tsx` | Detail page hero card |
| `src/components/patterns/cards/StatCard.tsx` | Quick stat card |
| `src/components/patterns/cards/DataCard.tsx` | List page data card |
| `src/components/patterns/forms/FormCard.tsx` | Form outer card |
| `src/components/patterns/forms/FormSection.tsx` | Form section with title |
| `src/components/patterns/forms/FormRow.tsx` | Form field row (1/2/3 col) |
| `src/components/patterns/forms/TypeTabs.tsx` | Type selection tabs |
| `src/components/patterns/forms/AmountInput.tsx` | Amount input with currency prefix |
| `src/components/patterns/detail/DetailTwoCol.tsx` | Detail two-column layout |
| `src/pages/AccountDetailPage.tsx` | Placeholder detail page |
| `src/pages/TransactionDetailPage.tsx` | Placeholder detail page |
| `src/pages/GoalDetailPage.tsx` | Placeholder detail page |
| `src/pages/DebtDetailPage.tsx` | Placeholder detail page |
| `src/pages/HoldingDetailPage.tsx` | Placeholder detail page |

### Delete (later phases)
- `src/components/AccountDetailPanel.tsx` — replaced by AccountDetailPage in P1
- `src/components/DebtDetailPanel.tsx` — replaced by DebtDetailPage in P3
- `src/components/PrepaidDetailPanel.tsx` — replaced in P3

---

## Task 1: Theme Tokens

**Files:**
- Modify: `src/index.css`
- Modify: `tailwind.config.js`

- [ ] **Step 1: Update CSS variables in `src/index.css`**

Replace the entire `:root` and `.dark` blocks in `src/index.css`:

```css
@layer base {
  :root {
    /* YuCai Light Theme */
    --background: 47 24% 96%;
    --foreground: 42 8% 9%;
    --card: 0 0% 100%;
    --card-foreground: 42 8% 9%;
    --popover: 0 0% 100%;
    --popover-foreground: 42 8% 9%;
    --primary: 37 35% 52%;
    --primary-foreground: 0 0% 100%;
    --secondary: 41 16% 92%;
    --secondary-foreground: 42 8% 9%;
    --muted: 41 16% 92%;
    --muted-foreground: 42 4% 46%;
    --accent: 37 35% 52%;
    --accent-foreground: 0 0% 100%;
    --destructive: 3 52% 54%;
    --destructive-foreground: 0 0% 100%;
    --border: 41 16% 88%;
    --input: 41 16% 88%;
    --ring: 37 35% 52%;
    --radius: 0.625rem;

    /* Sidebar - YuCai Dark */
    --sidebar: 216 8% 12%;
    --sidebar-foreground: 42 5% 76%;
    --sidebar-primary: 37 35% 52%;
    --sidebar-primary-foreground: 0 0% 100%;
    --sidebar-accent: 220 7% 18%;
    --sidebar-accent-foreground: 0 0% 100%;
    --sidebar-border: 0 0% 100%;
    --sidebar-ring: 37 35% 52%;
  }

  .dark {
    /* YuCai Dark Theme — warm dark variant */
    --background: 40 6% 8%;
    --foreground: 42 10% 92%;
    --card: 40 6% 10%;
    --card-foreground: 42 10% 92%;
    --popover: 40 6% 10%;
    --popover-foreground: 42 10% 92%;
    --primary: 37 35% 52%;
    --primary-foreground: 0 0% 100%;
    --secondary: 40 5% 16%;
    --secondary-foreground: 42 10% 92%;
    --muted: 40 5% 16%;
    --muted-foreground: 42 4% 56%;
    --accent: 37 35% 52%;
    --accent-foreground: 0 0% 100%;
    --destructive: 3 52% 54%;
    --destructive-foreground: 0 0% 100%;
    --border: 40 5% 18%;
    --input: 40 5% 18%;
    --ring: 37 35% 52%;

    /* Sidebar stays dark in both themes */
    --sidebar: 216 8% 10%;
    --sidebar-foreground: 42 5% 76%;
    --sidebar-primary: 37 35% 52%;
    --sidebar-primary-foreground: 0 0% 100%;
    --sidebar-accent: 220 7% 15%;
    --sidebar-accent-foreground: 0 0% 100%;
    --sidebar-border: 0 0% 100%;
    --sidebar-ring: 37 35% 52%;
  }

  * {
    border-color: hsl(var(--border));
  }

  body {
    @apply bg-background text-foreground;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', 'Microsoft YaHei', system-ui, sans-serif;
  }
}
```

Also update the `body` rule at the top of the file (line 12-14) to use the system sans-serif stack matching the prototype:

```css
body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', 'Microsoft YaHei', system-ui, sans-serif;
}
```

- [ ] **Step 2: Update `tailwind.config.js`**

Add `fontFamily.display` and adjust `borderRadius`:

```js
/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'class',
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      fontFamily: {
        display: [
          'Iowan Old Style', 'Charter', 'Georgia', 'Noto Serif SC', 'Source Han Serif SC', 'serif',
        ],
      },
      colors: {
        border: 'hsl(var(--border))',
        input: 'hsl(var(--input))',
        ring: 'hsl(var(--ring))',
        background: 'hsl(var(--background))',
        foreground: 'hsl(var(--foreground))',
        primary: {
          DEFAULT: 'hsl(var(--primary))',
          foreground: 'hsl(var(--primary-foreground))',
        },
        secondary: {
          DEFAULT: 'hsl(var(--secondary))',
          foreground: 'hsl(var(--secondary-foreground))',
        },
        destructive: {
          DEFAULT: 'hsl(var(--destructive))',
          foreground: 'hsl(var(--destructive-foreground))',
        },
        muted: {
          DEFAULT: 'hsl(var(--muted))',
          foreground: 'hsl(var(--muted-foreground))',
        },
        accent: {
          DEFAULT: 'hsl(var(--accent))',
          foreground: 'hsl(var(--accent-foreground))',
        },
        popover: {
          DEFAULT: 'hsl(var(--popover))',
          foreground: 'hsl(var(--popover-foreground))',
        },
        card: {
          DEFAULT: 'hsl(var(--card))',
          foreground: 'hsl(var(--card-foreground))',
        },
        income: {
          DEFAULT: '#2d8a6e',
          light: '#34d399',
          dark: '#059669',
        },
        expense: {
          DEFAULT: '#c4544d',
          light: '#f87171',
          dark: '#dc2626',
        },
        asset: {
          DEFAULT: '#3b82f6',
          light: '#60a5fa',
          dark: '#2563eb',
        },
        liability: {
          DEFAULT: '#f59e0b',
          light: '#fbbf24',
          dark: '#d97706',
        },
      },
      borderRadius: {
        lg: 'var(--radius)',
        md: 'calc(var(--radius) - 2px)',
        sm: 'calc(var(--radius) - 4px)',
      },
    },
  },
  plugins: [],
};
```

- [ ] **Step 3: Verify theme renders correctly**

Run: `pnpm dev`

Expected: App loads with warm cream background (#f7f6f2), gold accent color (#b08d57), and warm gray borders. All existing pages should still function. Sidebar should show dark background.

- [ ] **Step 4: Commit**

```bash
git add src/index.css tailwind.config.js
git commit -m "feat(theme): apply YuCai design tokens — warm gold accent, cream background, serif display font"
```

---

## Task 2: Sidebar Redesign

**Files:**
- Modify: `src/hooks/useSidebarState.ts`
- Modify: `src/components/sidebar/Sidebar.tsx`
- Modify: `src/components/sidebar/SidebarGroup.tsx`
- Modify: `src/components/sidebar/SidebarNavItem.tsx`

- [ ] **Step 1: Update `useSidebarState.ts` — new 5-group structure**

Replace the `GroupId` type and `ALL_GROUP_IDS` array. The sidebar will now have 5 groups matching the prototype: overview (概览), investment (投资), finance (财务), borrowing (借贷), tools (工具).

```ts
import { useCallback, useEffect, useState } from 'react';

export type GroupId =
  | 'overview'
  | 'investment'
  | 'finance'
  | 'borrowing'
  | 'tools';

const STORAGE_KEY = 'sidebar-group-state';

const ALL_GROUP_IDS: GroupId[] = [
  'overview',
  'investment',
  'finance',
  'borrowing',
  'tools',
];

function getDefaultState(): Record<GroupId, boolean> {
  const state = {} as Record<GroupId, boolean>;
  for (const id of ALL_GROUP_IDS) {
    state[id] = true;
  }
  return state;
}

function loadStateFromStorage(): Record<GroupId, boolean> {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return getDefaultState();

    const parsed = JSON.parse(raw);
    if (typeof parsed !== 'object' || parsed === null) return getDefaultState();

    const state = {} as Record<GroupId, boolean>;
    for (const id of ALL_GROUP_IDS) {
      state[id] = typeof parsed[id] === 'boolean' ? parsed[id] : true;
    }
    return state;
  } catch {
    return getDefaultState();
  }
}

function saveStateToStorage(state: Record<GroupId, boolean>): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch {
    // Ignore localStorage errors
  }
}

export function useSidebarState(activeGroupId?: GroupId) {
  const [groupState, setGroupState] = useState<Record<GroupId, boolean>>(
    () => loadStateFromStorage()
  );

  useEffect(() => {
    saveStateToStorage(groupState);
  }, [groupState]);

  useEffect(() => {
    if (!activeGroupId) return;
    setGroupState((prev) => {
      if (prev[activeGroupId] === true) return prev;
      return { ...prev, [activeGroupId]: true };
    });
  }, [activeGroupId]);

  const isGroupOpen = useCallback(
    (groupId: GroupId): boolean => {
      if (groupId === activeGroupId) return true;
      return groupState[groupId];
    },
    [groupState, activeGroupId]
  );

  const toggleGroup = useCallback(
    (groupId: GroupId): void => {
      if (groupId === activeGroupId) return;
      setGroupState((prev) => ({
        ...prev,
        [groupId]: !prev[groupId],
      }));
    },
    [activeGroupId]
  );

  return { isGroupOpen, toggleGroup };
}
```

- [ ] **Step 2: Update `SidebarGroup.tsx` — dark styling, collapsed state**

The group label uses monospace uppercase style matching the prototype. When sidebar is collapsed, hide the label text and show items in a tooltip-style popover.

```tsx
import { cn } from '@/lib/utils';

export interface SidebarGroupProps {
  label: string;
  isOpen: boolean;
  onToggle: () => void;
  toggleDisabled?: boolean;
  collapsed?: boolean;
  children: React.ReactNode;
}

export function SidebarGroup({
  label,
  isOpen,
  onToggle,
  toggleDisabled = false,
  collapsed = false,
  children,
}: SidebarGroupProps) {
  const handleClick = () => {
    if (!toggleDisabled) {
      onToggle();
    }
  };

  if (collapsed) {
    return (
      <div className="flex flex-col gap-1 px-2 py-1">
        <div className="mx-auto my-1 h-px w-5 bg-white/10" />
        {children}
      </div>
    );
  }

  return (
    <div className="flex flex-col">
      <button
        type="button"
        onClick={handleClick}
        disabled={toggleDisabled}
        aria-expanded={isOpen}
        className={cn(
          'px-5 py-3 text-[10px] font-medium uppercase tracking-[0.1em] font-mono transition-all duration-150',
          'text-white/25',
          toggleDisabled
            ? 'cursor-default'
            : 'cursor-pointer hover:text-white/40'
        )}
      >
        {label}
      </button>
      <div
        className="overflow-hidden transition-all duration-150 ease-in-out"
        style={{
          maxHeight: isOpen ? 500 : 0,
          opacity: isOpen ? 1 : 0,
        }}
      >
        <div className="flex flex-col gap-0.5 pb-1">{children}</div>
      </div>
    </div>
  );
}
```

- [ ] **Step 3: Update `SidebarNavItem.tsx` — dark styling, badge, tooltip**

```tsx
import { Link } from '@tanstack/react-router';
import { cn } from '@/lib/utils';

export interface SidebarNavItemProps {
  to: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  exact?: boolean;
  onNavigate?: () => void;
  title?: string;
  collapsed?: boolean;
  badge?: string | number;
}

export function SidebarNavItem({
  to,
  label,
  icon: Icon,
  exact,
  onNavigate,
  title,
  collapsed,
  badge,
}: SidebarNavItemProps) {
  if (collapsed) {
    return (
      <Link
        to={to}
        activeOptions={exact ? { exact: true } : undefined}
        activeProps={{
          className: 'bg-sidebar-accent text-white',
        }}
        className="flex items-center justify-center rounded-lg p-2.5 text-sidebar-foreground transition-colors hover:bg-sidebar-accent hover:text-white"
        onClick={onNavigate}
        title={title ?? label}
      >
        <Icon className="h-[18px] w-[18px]" />
      </Link>
    );
  }

  return (
    <Link
      to={to}
      activeOptions={exact ? { exact: true } : undefined}
      activeProps={{
        className: 'bg-sidebar-accent text-white [&>svg]:opacity-100',
      }}
      className={cn(
        'flex items-center gap-2.5 px-5 py-2 text-[13px] text-sidebar-foreground transition-colors',
        'hover:bg-sidebar-accent hover:text-white',
        ' [&>svg]:opacity-60'
      )}
      onClick={onNavigate}
      title={title}
    >
      <Icon className="h-[18px] w-[18px] shrink-0" />
      <span>{label}</span>
      {badge !== undefined && (
        <span className="ml-auto rounded-full bg-primary px-1.5 py-px text-[10px] font-mono text-primary-foreground">
          {badge}
        </span>
      )}
    </Link>
  );
}
```

- [ ] **Step 4: Rewrite `Sidebar.tsx` — full YuCai sidebar with brand, 5 groups, user footer, collapse button**

```tsx
import {
  Home,
  Wallet,
  BarChart3,
  CreditCard,
  Receipt,
  ClipboardList,
  Target,
  PieChart,
  Settings,
  ChevronsLeft,
  ChevronsRight,
} from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { useRouterState } from '@tanstack/react-router';
import { cn } from '@/lib/utils';
import { useSidebarState, type GroupId } from '@/hooks/useSidebarState';
import { SidebarGroup } from './SidebarGroup';
import { SidebarNavItem } from './SidebarNavItem';

interface NavItemConfig {
  to: string;
  labelKey: string;
  icon: React.ComponentType<{ className?: string }>;
  exact?: boolean;
  badge?: string;
}

interface NavGroupConfig {
  id: GroupId;
  labelKey: string;
  items: NavItemConfig[];
}

const navGroups: NavGroupConfig[] = [
  {
    id: 'overview',
    labelKey: 'nav.groups.overview',
    items: [
      { to: '/', labelKey: 'nav.dashboard', icon: Home, exact: true },
    ],
  },
  {
    id: 'investment',
    labelKey: 'nav.groups.investment',
    items: [
      { to: '/holdings', labelKey: 'nav.holdings', icon: BarChart3, badge: '5' },
    ],
  },
  {
    id: 'finance',
    labelKey: 'nav.groups.finance',
    items: [
      { to: '/accounts', labelKey: 'nav.accounts', icon: Wallet },
      { to: '/transactions', labelKey: 'nav.transactions', icon: Receipt },
      { to: '/budget', labelKey: 'nav.budget', icon: ClipboardList },
      { to: '/goals', labelKey: 'nav.goals', icon: Target },
    ],
  },
  {
    id: 'borrowing',
    labelKey: 'nav.groups.borrowing',
    items: [
      { to: '/debts', labelKey: 'nav.debts', icon: CreditCard },
    ],
  },
  {
    id: 'tools',
    labelKey: 'nav.groups.tools',
    items: [
      { to: '/reports', labelKey: 'nav.reports', icon: PieChart },
      { to: '/settings', labelKey: 'nav.settings', icon: Settings },
    ],
  },
];

/** Map route prefix to group ID for auto-open active group */
function getActiveGroupId(pathname: string): GroupId {
  if (pathname === '/') return 'overview';
  if (pathname.startsWith('/holdings')) return 'investment';
  if (
    pathname.startsWith('/accounts') ||
    pathname.startsWith('/transactions') ||
    pathname.startsWith('/budget') ||
    pathname.startsWith('/goals') ||
    pathname.startsWith('/categories') ||
    pathname.startsWith('/transaction-templates')
  ) return 'finance';
  if (pathname.startsWith('/debts')) return 'borrowing';
  if (pathname.startsWith('/reports') || pathname.startsWith('/settings')) return 'tools';
  return 'overview';
}

interface SidebarProps {
  collapsed?: boolean;
  onNavigate?: () => void;
  onToggleCollapse?: () => void;
}

export function Sidebar({ collapsed = false, onNavigate, onToggleCollapse }: SidebarProps) {
  const { t } = useTranslation();
  const routerState = useRouterState();
  const pathname = routerState.location.pathname;
  const activeGroupId = getActiveGroupId(pathname);
  const { isGroupOpen, toggleGroup } = useSidebarState(activeGroupId);

  return (
    <div
      className={cn(
        'flex h-full flex-col bg-sidebar text-sidebar-foreground',
        collapsed ? 'w-16' : 'w-60'
      )}
    >
      {/* Brand */}
      {!collapsed && (
        <div className="border-b border-white/[0.06] px-5 pb-5 pt-6">
          <h2 className="font-display text-xl font-semibold tracking-tight text-white">
            {t('nav.brandTitle')}
          </h2>
          <span className="mt-0.5 block text-[11px] text-white/40">
            {t('nav.brandSubtitle')}
          </span>
        </div>
      )}
      {collapsed && (
        <div className="flex items-center justify-center border-b border-white/[0.06] py-5">
          <span className="font-display text-lg font-semibold text-primary">御</span>
        </div>
      )}

      {/* Navigation */}
      <nav className="flex-1 overflow-y-auto py-3">
        {navGroups.map((group) => (
          <SidebarGroup
            key={group.id}
            label={t(group.labelKey)}
            isOpen={isGroupOpen(group.id)}
            onToggle={() => toggleGroup(group.id)}
            toggleDisabled={collapsed}
            collapsed={collapsed}
          >
            {group.items.map((item) => (
              <SidebarNavItem
                key={item.to}
                to={item.to}
                label={t(item.labelKey)}
                icon={item.icon}
                exact={item.exact}
                onNavigate={onNavigate}
                collapsed={collapsed}
                badge={item.badge}
              />
            ))}
          </SidebarGroup>
        ))}
      </nav>

      {/* Footer: User + Collapse button */}
      <div className="border-t border-white/[0.06] px-4 py-3">
        {!collapsed && (
          <div className="mb-2 flex items-center gap-2.5 px-1">
            <div className="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-full bg-sidebar-accent text-sm text-white">
              {t('nav.userInitial')}
            </div>
            <div className="text-[13px]">
              <div className="text-white">{t('nav.userName')}</div>
              <div className="text-[11px] text-white/40">{t('nav.userTier')}</div>
            </div>
          </div>
        )}
        <button
          type="button"
          onClick={onToggleCollapse}
          className={cn(
            'flex w-full items-center justify-center rounded-lg p-2 text-sidebar-foreground/50 transition-colors hover:bg-sidebar-accent hover:text-white',
          )}
          title={collapsed ? t('nav.expandSidebar') : t('nav.collapseSidebar')}
        >
          {collapsed ? (
            <ChevronsRight className="h-4 w-4" />
          ) : (
            <ChevronsLeft className="h-4 w-4" />
          )}
        </button>
      </div>
    </div>
  );
}
```

- [ ] **Step 5: Verify sidebar renders correctly**

Run: `pnpm dev`

Expected: Dark sidebar (#1c1e21) with brand "御财" at top, 5 navigation groups with gold accent on active item. Collapse button at bottom toggles between 240px and 64px. All pages still navigable.

- [ ] **Step 6: Commit**

```bash
git add src/hooks/useSidebarState.ts src/components/sidebar/
git commit -m "feat(sidebar): YuCai dark sidebar with 5-group navigation, brand area, collapse toggle"
```

---

## Task 3: Breadcrumb Component

**Files:**
- Create: `src/components/layout/BreadcrumbBar.tsx`

- [ ] **Step 1: Create `BreadcrumbBar.tsx`**

This component renders breadcrumb items from the router state or explicit props. It integrates with TanStack Router for navigation.

```tsx
import { Link, useRouterState } from '@tanstack/react-router';
import { ChevronRight, Home } from 'lucide-react';
import { useTranslation } from 'react-i18next';

export interface BreadcrumbItem {
  label: string;
  to?: string;
}

interface BreadcrumbBarProps {
  items?: BreadcrumbItem[];
}

/**
 * Auto-generates breadcrumbs from the current route path.
 * Override with explicit `items` prop if needed.
 */
export function BreadcrumbBar({ items }: BreadcrumbBarProps) {
  const { t } = useTranslation();
  const routerState = useRouterState();
  const pathname = routerState.location.pathname;

  // Auto-generate breadcrumbs from path segments
  const breadcrumbs: BreadcrumbItem[] = items ?? generateBreadcrumbs(pathname, t);

  if (breadcrumbs.length === 0) return null;

  return (
    <nav className="flex items-center gap-2 text-sm">
      <Link
        to="/"
        className="text-muted-foreground/60 transition-colors hover:text-primary"
      >
        <Home className="h-3.5 w-3.5" />
      </Link>
      {breadcrumbs.map((item, i) => (
        <span key={i} className="flex items-center gap-2">
          <ChevronRight className="h-3 w-3 text-border" />
          {item.to ? (
            <Link
              to={item.to}
              className="text-muted-foreground transition-colors hover:text-primary"
            >
              {item.label}
            </Link>
          ) : (
            <span className="font-medium text-foreground">{item.label}</span>
          )}
        </span>
      ))}
    </nav>
  );
}

/** Map route paths to breadcrumb labels */
const routeLabelMap: Record<string, string> = {
  accounts: 'nav.accounts',
  transactions: 'nav.transactions',
  holdings: 'nav.holdings',
  debts: 'nav.debts',
  budget: 'nav.budget',
  goals: 'nav.goals',
  reports: 'nav.reports',
  settings: 'nav.settings',
  categories: 'nav.categories',
  'transaction-templates': 'nav.recurring',
  reminders: 'nav.reminders',
  new: 'common.new',
  edit: 'common.edit',
};

function generateBreadcrumbs(pathname: string, t: (key: string) => string): BreadcrumbItem[] {
  const segments = pathname.split('/').filter(Boolean);
  const items: BreadcrumbItem[] = [];
  let accumulatedPath = '';

  for (let i = 0; i < segments.length; i++) {
    const seg = segments[i];
    accumulatedPath += `/${seg}`;

    // Skip dynamic segments like UUIDs
    if (seg.match(/^[0-9a-f-]{20,}$/)) {
      // This is an ID — use "详情" or "编辑" depending on next segment
      continue;
    }

    const labelKey = routeLabelMap[seg];
    const isLast = i === segments.length - 1;

    items.push({
      label: labelKey ? t(labelKey) : seg,
      to: isLast ? undefined : accumulatedPath,
    });
  }

  return items;
}
```

- [ ] **Step 2: Commit**

```bash
git add src/components/layout/BreadcrumbBar.tsx
git commit -m "feat(layout): add BreadcrumbBar component with auto-route generation"
```

---

## Task 4: Header Redesign

**Files:**
- Modify: `src/components/layout/Header.tsx`

- [ ] **Step 1: Rewrite `Header.tsx` — breadcrumb + blur backdrop + simplified**

Remove user menu (moved to sidebar footer), add BreadcrumbBar on left, keep search and theme toggle on right.

```tsx
import { ReactNode } from 'react';
import { GlobalSearch } from '@/components/GlobalSearch';
import { ThemeToggle } from '../theme/ThemeToggle';
import { SettingsButton } from './SettingsButton';
import { BreadcrumbBar } from './BreadcrumbBar';
import { cn } from '@/lib/utils';

interface HeaderProps {
  /** Content to display in the right section (before theme/settings) */
  rightContent?: ReactNode;
  /** Show search bar */
  showSearch?: boolean;
  /** Show theme toggle button */
  showThemeToggle?: boolean;
  /** Show settings button */
  showSettings?: boolean;
  className?: string;
}

export function Header({
  rightContent,
  showSearch = true,
  showThemeToggle = true,
  showSettings = true,
  className,
}: HeaderProps) {
  return (
    <header
      className={cn(
        'sticky top-0 z-10 flex h-14 items-center justify-between border-b px-8',
        'border-border bg-background/90 backdrop-blur-xl',
        className
      )}
    >
      {/* Left: Breadcrumb */}
      <BreadcrumbBar />

      {/* Right: Search + Actions */}
      <div className="flex items-center gap-3">
        {rightContent}
        {showSearch && <GlobalSearch className="w-56" />}
        {showThemeToggle && <ThemeToggle />}
        {showSettings && <SettingsButton />}
      </div>
    </header>
  );
}
```

- [ ] **Step 2: Verify header renders correctly**

Run: `pnpm dev`

Expected: Sticky header with blur backdrop. Left side shows breadcrumb navigation. Right side shows search + theme toggle + settings. No user menu (now in sidebar).

- [ ] **Step 3: Commit**

```bash
git add src/components/layout/Header.tsx
git commit -m "feat(header): YuCai sticky header with breadcrumb and blur backdrop"
```

---

## Task 5: AppLayout Update

**Files:**
- Modify: `src/components/layout/AppLayout.tsx`

- [ ] **Step 1: Update `AppLayout.tsx` — 240/64px sidebar widths**

The sidebar now controls its own width (w-60 = 240px expanded, w-16 = 64px collapsed). AppLayout adjusts the main content margin accordingly. Collapse toggle is handled inside the Sidebar component.

```tsx
import { ReactNode, useState } from 'react';
import { Sidebar } from '@/components/sidebar';

interface AppLayoutProps {
  children: ReactNode;
}

export function AppLayout({ children }: AppLayoutProps) {
  const [sidebarOpen, setSidebarOpen] = useState(false); // Mobile: show/hide
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false); // Desktop: expand/collapse

  return (
    <div className="flex h-screen overflow-hidden">
      {/* Sidebar - Desktop: always visible, Mobile: overlay */}
      <div
        className="fixed inset-y-0 left-0 z-50 transform transition-all duration-300 ease-in-out lg:relative lg:translate-x-0"
        style={{
          width: sidebarCollapsed ? '64px' : '240px',
          transform: sidebarOpen ? 'translateX(0)' : undefined,
        }}
      >
        {/* Mobile off-screen by default */}
        {!sidebarOpen && (
          <style>{`@media (max-width: 1023px) { .sidebar-mobile-hide { transform: translateX(-100%); } }`}</style>
        )}
        <div className={sidebarOpen ? '' : 'sidebar-mobile-hide lg:sidebar-mobile-show'} style={{ height: '100%' }}>
          <Sidebar
            collapsed={sidebarCollapsed}
            onNavigate={() => setSidebarOpen(false)}
            onToggleCollapse={() => setSidebarCollapsed(!sidebarCollapsed)}
          />
        </div>
      </div>

      {/* Overlay for mobile */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/50 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Main content area */}
      <div className="flex flex-1 flex-col overflow-hidden">
        <main className="flex-1 overflow-y-auto">
          {children}
        </main>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Verify layout works correctly**

Run: `pnpm dev`

Expected: Sidebar takes 240px (expanded) or 64px (collapsed). Main content fills remaining space. Mobile: sidebar slides in as overlay. All existing pages render in the content area.

- [ ] **Step 3: Commit**

```bash
git add src/components/layout/AppLayout.tsx
git commit -m "feat(layout): adapt AppLayout to YuCai sidebar 240/64px widths"
```

---

## Task 6: i18n Updates

**Files:**
- Modify: `src/i18n/locales/en.json`
- Modify: `src/i18n/locales/zh.json`

- [ ] **Step 1: Add new nav keys to `en.json`**

Add inside the `"nav"` object:

```json
{
  "nav": {
    "brandTitle": "YuCai",
    "brandSubtitle": "Private Wealth Management",
    "userInitial": "U",
    "userName": "User",
    "userTier": "Premium",
    "collapseSidebar": "Collapse sidebar",
    "expandSidebar": "Expand sidebar",
    "groups": {
      "overview": "Overview",
      "investment": "Investment",
      "finance": "Finance",
      "borrowing": "Borrowing",
      "tools": "Tools"
    }
  },
  "common": {
    "new": "New",
    "edit": "Edit",
    "routeShell": "Page under construction"
  }
}
```

Note: Merge with existing keys — don't remove any existing nav keys. The existing keys like `nav.dashboard`, `nav.accounts` etc. remain unchanged. Only add the new keys that don't exist yet.

- [ ] **Step 2: Add new nav keys to `zh.json`**

Add inside the `"nav"` object:

```json
{
  "nav": {
    "brandTitle": "御财",
    "brandSubtitle": "私人财富管理",
    "userInitial": "U",
    "userName": "用户",
    "userTier": "高级会员",
    "collapseSidebar": "收起侧边栏",
    "expandSidebar": "展开侧边栏",
    "groups": {
      "overview": "概览",
      "investment": "投资",
      "finance": "财务",
      "borrowing": "借贷",
      "tools": "工具"
    }
  },
  "common": {
    "new": "新建",
    "edit": "编辑",
    "routeShell": "页面建设中"
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add src/i18n/locales/en.json src/i18n/locales/zh.json
git commit -m "feat(i18n): add YuCai sidebar nav group labels and common keys"
```

---

## Task 7: Shared Component Skeletons

**Files:**
- Create: `src/components/patterns/layout/PageShell.tsx`
- Create: `src/components/patterns/layout/PageHeader.tsx`
- Create: `src/components/patterns/layout/FilterBar.tsx`
- Create: `src/components/patterns/cards/HeroCard.tsx`
- Create: `src/components/patterns/cards/StatCard.tsx`
- Create: `src/components/patterns/cards/DataCard.tsx`
- Create: `src/components/patterns/forms/FormCard.tsx`
- Create: `src/components/patterns/forms/FormSection.tsx`
- Create: `src/components/patterns/forms/FormRow.tsx`
- Create: `src/components/patterns/forms/TypeTabs.tsx`
- Create: `src/components/patterns/forms/AmountInput.tsx`
- Create: `src/components/patterns/detail/DetailTwoCol.tsx`

These are skeleton components with correct props interfaces and Tailwind classes matching the prototype CSS. They contain no business logic.

- [ ] **Step 1: Create layout patterns**

`src/components/patterns/layout/PageShell.tsx`:
```tsx
import { cn } from '@/lib/utils';
import { ReactNode } from 'react';

interface PageShellProps {
  children: ReactNode;
  /** Constrain max-width (for form pages) */
  narrow?: boolean;
  className?: string;
}

export function PageShell({ children, narrow, className }: PageShellProps) {
  return (
    <div className={cn('px-8 pb-12 pt-7', narrow && 'mx-auto max-w-[760px]', className)}>
      {children}
    </div>
  );
}
```

`src/components/patterns/layout/PageHeader.tsx`:
```tsx
import { cn } from '@/lib/utils';
import { ReactNode } from 'react';

interface PageHeaderProps {
  title: string;
  subtitle?: string;
  /** Right-side action area (buttons, filters) */
  actions?: ReactNode;
  className?: string;
}

export function PageHeader({ title, subtitle, actions, className }: PageHeaderProps) {
  return (
    <div className={cn('mb-6 flex items-end justify-between', className)}>
      <div>
        <h1 className="font-display text-[28px] leading-tight">{title}</h1>
        {subtitle && (
          <p className="mt-1 text-xs text-muted-foreground">{subtitle}</p>
        )}
      </div>
      {actions && <div className="flex items-center gap-3">{actions}</div>}
    </div>
  );
}
```

`src/components/patterns/layout/FilterBar.tsx`:
```tsx
import { cn } from '@/lib/utils';

interface FilterOption {
  label: string;
  value: string;
}

interface FilterBarProps {
  options: FilterOption[];
  value: string;
  onChange: (value: string) => void;
  className?: string;
}

export function FilterBar({ options, value, onChange, className }: FilterBarProps) {
  return (
    <div className={cn('mb-6 flex flex-wrap gap-1.5', className)}>
      {options.map((opt) => (
        <button
          key={opt.value}
          type="button"
          onClick={() => onChange(opt.value)}
          className={cn(
            'rounded-full border px-3.5 py-1.5 text-[13px] transition-colors',
            value === opt.value
              ? 'border-primary bg-primary text-primary-foreground'
              : 'border-border text-muted-foreground hover:border-primary hover:text-foreground'
          )}
        >
          {opt.label}
        </button>
      ))}
    </div>
  );
}
```

- [ ] **Step 2: Create card patterns**

`src/components/patterns/cards/HeroCard.tsx`:
```tsx
import { cn } from '@/lib/utils';
import { ReactNode } from 'react';

interface HeroCardProps {
  icon: ReactNode;
  name: string;
  subtitle?: string;
  children?: ReactNode;
  className?: string;
}

export function HeroCard({ icon, name, subtitle, children, className }: HeroCardProps) {
  return (
    <div
      className={cn(
        'relative mb-5 overflow-hidden rounded-[14px] border border-border bg-card p-7',
        'flex items-center gap-10',
        className
      )}
    >
      {/* Decorative radial gradient */}
      <div className="pointer-events-none absolute -right-[10%] -top-[40%] h-[180%] w-1/2 bg-[radial-gradient(ellipse_at_center,oklch(var(--primary)/0.06)_0%,transparent_70%)]" />
      <div className="relative z-10 shrink-0">
        <div className="mb-3 flex h-12 w-12 items-center justify-center rounded-xl bg-primary/10 text-primary">
          {icon}
        </div>
        <div className="font-display text-xl font-semibold tracking-tight">{name}</div>
        {subtitle && <div className="mt-0.5 text-xs text-muted-foreground">{subtitle}</div>}
      </div>
      <div className="relative z-10 flex-1">{children}</div>
    </div>
  );
}
```

`src/components/patterns/cards/StatCard.tsx`:
```tsx
import { cn } from '@/lib/utils';

interface StatCardProps {
  label: string;
  value: string;
  tag?: string;
  tagVariant?: 'positive' | 'negative' | 'neutral';
  className?: string;
}

export function StatCard({ label, value, tag, tagVariant = 'neutral', className }: StatCardProps) {
  return (
    <div className={cn('rounded-[14px] border border-border bg-card px-5 py-[18px]', className)}>
      <div className="mb-1.5 text-xs text-muted-foreground">{label}</div>
      <div className="font-display text-[22px] font-semibold tracking-tight">{value}</div>
      {tag && (
        <span
          className={cn(
            'mt-1.5 inline-block rounded-full px-2 py-0.5 font-mono text-[11px]',
            tagVariant === 'positive' && 'bg-income/10 text-income',
            tagVariant === 'negative' && 'bg-expense/10 text-expense',
            tagVariant === 'neutral' && 'bg-muted text-muted-foreground'
          )}
        >
          {tag}
        </span>
      )}
    </div>
  );
}
```

`src/components/patterns/cards/DataCard.tsx`:
```tsx
import { cn } from '@/lib/utils';
import { ReactNode } from 'react';

interface DataCardProps {
  children?: ReactNode;
  onClick?: () => void;
  className?: string;
}

export function DataCard({ children, onClick, className }: DataCardProps) {
  return (
    <div
      onClick={onClick}
      className={cn(
        'rounded-[14px] border border-border bg-card p-5 transition-colors',
        onClick && 'cursor-pointer hover:border-primary/40'
      )}
    >
      {children}
    </div>
  );
}
```

- [ ] **Step 3: Create form patterns**

`src/components/patterns/forms/FormCard.tsx`:
```tsx
import { cn } from '@/lib/utils';
import { ReactNode } from 'react';

interface FormCardProps {
  children: ReactNode;
  className?: string;
}

export function FormCard({ children, className }: FormCardProps) {
  return (
    <div className={cn('rounded-[14px] border border-border bg-card p-7', className)}>
      {children}
    </div>
  );
}
```

`src/components/patterns/forms/FormSection.tsx`:
```tsx
import { cn } from '@/lib/utils';
import { ReactNode } from 'react';

interface FormSectionProps {
  title: string;
  children: ReactNode;
  className?: string;
}

export function FormSection({ title, children, className }: FormSectionProps) {
  return (
    <div className={cn('mb-6 last:mb-0', className)}>
      <div className="mb-4 border-b border-border pb-2 text-xs font-semibold uppercase tracking-[0.08em] text-muted-foreground">
        {title}
      </div>
      {children}
    </div>
  );
}
```

`src/components/patterns/forms/FormRow.tsx`:
```tsx
import { cn } from '@/lib/utils';
import { ReactNode } from 'react';

interface FormRowProps {
  children: ReactNode;
  /** Number of columns: 1, 2, or 3 */
  cols?: 1 | 2 | 3;
  className?: string;
}

export function FormRow({ children, cols = 2, className }: FormRowProps) {
  return (
    <div
      className={cn(
        'mb-4 grid gap-4',
        cols === 1 && 'grid-cols-1',
        cols === 2 && 'grid-cols-2',
        cols === 3 && 'grid-cols-3',
        className
      )}
    >
      {children}
    </div>
  );
}
```

`src/components/patterns/forms/TypeTabs.tsx`:
```tsx
import { cn } from '@/lib/utils';

interface TypeTab {
  label: string;
  value: string;
}

interface TypeTabsProps {
  tabs: TypeTab[];
  value: string;
  onChange: (value: string) => void;
  className?: string;
}

export function TypeTabs({ tabs, value, onChange, className }: TypeTabsProps) {
  return (
    <div className={cn('mb-6 flex overflow-hidden rounded-[10px] border border-border bg-card', className)}>
      {tabs.map((tab, i) => (
        <button
          key={tab.value}
          type="button"
          onClick={() => onChange(tab.value)}
          className={cn(
            'flex-1 border-r border-border px-4 py-3 text-[13px] font-medium transition-colors last:border-r-0',
            value === tab.value
              ? 'bg-primary/10 text-primary'
              : 'text-muted-foreground hover:text-foreground'
          )}
        >
          {tab.label}
        </button>
      ))}
    </div>
  );
}
```

`src/components/patterns/forms/AmountInput.tsx`:
```tsx
import { cn } from '@/lib/utils';
import { Input } from '@/components/ui/input';

interface AmountInputProps {
  currencySymbol?: string;
  currencyCode?: string;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  className?: string;
}

export function AmountInput({
  currencySymbol = '¥',
  currencyCode = 'CNY',
  value,
  onChange,
  placeholder = '0.00',
  className,
}: AmountInputProps) {
  return (
    <div
      className={cn(
        'flex overflow-hidden rounded-[10px] border border-border transition-colors',
        'focus-within:border-primary focus-within:ring-[3px] focus-within:ring-primary/10',
        className
      )}
    >
      <div className="flex items-center gap-1 border-r border-border bg-background px-3 py-2.5 font-mono text-[13px] font-medium text-muted-foreground">
        {currencySymbol}
        <span className="text-[10px]">{currencyCode}</span>
      </div>
      <Input
        type="number"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="border-0 bg-transparent text-lg font-mono tabular-nums shadow-none focus-visible:ring-0"
      />
    </div>
  );
}
```

- [ ] **Step 4: Create detail pattern**

`src/components/patterns/detail/DetailTwoCol.tsx`:
```tsx
import { cn } from '@/lib/utils';
import { ReactNode } from 'react';

interface DetailTwoColProps {
  main: ReactNode;
  side: ReactNode;
  className?: string;
}

export function DetailTwoCol({ main, side, className }: DetailTwoColProps) {
  return (
    <div className={cn('grid grid-cols-1 gap-6 lg:grid-cols-[1fr_300px]', className)}>
      <div>{main}</div>
      <div>{side}</div>
    </div>
  );
}
```

- [ ] **Step 5: Verify components compile**

Run: `pnpm type-check`

Expected: No type errors. All new pattern components compile cleanly.

- [ ] **Step 6: Commit**

```bash
git add src/components/patterns/
git commit -m "feat(patterns): add reusable YuCai page-pattern components — layout, cards, forms, detail"
```

---

## Task 8: Route Expansion — Detail Page Placeholders

**Files:**
- Create: `src/pages/AccountDetailPage.tsx`
- Create: `src/pages/TransactionDetailPage.tsx`
- Create: `src/pages/GoalDetailPage.tsx`
- Create: `src/pages/DebtDetailPage.tsx`
- Create: `src/pages/HoldingDetailPage.tsx`
- Modify: `src/router.tsx`

- [ ] **Step 1: Create 5 placeholder detail pages**

Each placeholder uses `PageShell` and `PageHeader` from patterns, showing "under construction" state. They will be fully implemented in their respective phases (P1-P4).

All 5 files follow this template (replace `EntityName` and route param):

`src/pages/AccountDetailPage.tsx`:
```tsx
import { useTranslation } from 'react-i18next';
import { PageShell } from '@/components/patterns/layout/PageShell';
import { PageHeader } from '@/components/patterns/layout/PageHeader';

export function AccountDetailPage() {
  const { t } = useTranslation();
  return (
    <PageShell>
      <PageHeader title={t('accounts.detailTitle')} subtitle={t('common.routeShell')} />
    </PageShell>
  );
}
```

`src/pages/TransactionDetailPage.tsx`:
```tsx
import { useTranslation } from 'react-i18next';
import { PageShell } from '@/components/patterns/layout/PageShell';
import { PageHeader } from '@/components/patterns/layout/PageHeader';

export function TransactionDetailPage() {
  const { t } = useTranslation();
  return (
    <PageShell>
      <PageHeader title={t('transactions.detailTitle')} subtitle={t('common.routeShell')} />
    </PageShell>
  );
}
```

`src/pages/GoalDetailPage.tsx`:
```tsx
import { useTranslation } from 'react-i18next';
import { PageShell } from '@/components/patterns/layout/PageShell';
import { PageHeader } from '@/components/patterns/layout/PageHeader';

export function GoalDetailPage() {
  const { t } = useTranslation();
  return (
    <PageShell>
      <PageHeader title={t('goals.detailTitle')} subtitle={t('common.routeShell')} />
    </PageShell>
  );
}
```

`src/pages/DebtDetailPage.tsx`:
```tsx
import { useTranslation } from 'react-i18next';
import { PageShell } from '@/components/patterns/layout/PageShell';
import { PageHeader } from '@/components/patterns/layout/PageHeader';

export function DebtDetailPage() {
  const { t } = useTranslation();
  return (
    <PageShell>
      <PageHeader title={t('debts.detailTitle')} subtitle={t('common.routeShell')} />
    </PageShell>
  );
}
```

`src/pages/HoldingDetailPage.tsx`:
```tsx
import { useTranslation } from 'react-i18next';
import { PageShell } from '@/components/patterns/layout/PageShell';
import { PageHeader } from '@/components/patterns/layout/PageHeader';

export function HoldingDetailPage() {
  const { t } = useTranslation();
  return (
    <PageShell>
      <PageHeader title={t('holdings.detailTitle')} subtitle={t('common.routeShell')} />
    </PageShell>
  );
}
```

- [ ] **Step 2: Add detail i18n keys**

Add to `en.json` (inside respective sections):
```json
{
  "accounts": { "detailTitle": "Account Details" },
  "transactions": { "detailTitle": "Transaction Details" },
  "goals": { "detailTitle": "Goal Details" },
  "debts": { "detailTitle": "Debt Details" },
  "holdings": { "detailTitle": "Holding Details" }
}
```

Add to `zh.json`:
```json
{
  "accounts": { "detailTitle": "账户详情" },
  "transactions": { "detailTitle": "交易详情" },
  "goals": { "detailTitle": "目标详情" },
  "debts": { "detailTitle": "债务详情" },
  "holdings": { "detailTitle": "持仓详情" }
}
```

- [ ] **Step 3: Add routes to `src/router.tsx`**

Add imports at the top:
```tsx
import { AccountDetailPage } from './pages/AccountDetailPage';
import { TransactionDetailPage } from './pages/TransactionDetailPage';
import { GoalDetailPage } from './pages/GoalDetailPage';
import { DebtDetailPage } from './pages/DebtDetailPage';
import { HoldingDetailPage } from './pages/HoldingDetailPage';
```

Add route definitions before the `routeTree`:
```tsx
const accountDetailRoute = createRoute({
  getParentRoute: () => accountsRoute,
  path: '$accountId',
  component: AccountDetailPage,
});

const transactionDetailRoute = createRoute({
  getParentRoute: () => transactionsRoute,
  path: '$transactionId',
  component: TransactionDetailPage,
});

const goalDetailRoute = createRoute({
  getParentRoute: () => goalsRoute,
  path: '$goalId',
  component: GoalDetailPage,
});

const debtDetailRoute = createRoute({
  getParentRoute: () => debtsRoute,
  path: '$debtId',
  component: DebtDetailPage,
});

const holdingDetailRoute = createRoute({
  getParentRoute: () => holdingsRoute,
  path: '$holdingId',
  component: HoldingDetailPage,
});
```

Update `routeTree` to nest detail routes:
```tsx
const routeTree = rootRoute.addChildren([
  homeRoute,
  accountsRoute.addChildren([newAccountRoute, accountEditRoute, accountDetailRoute]),
  transactionsRoute.addChildren([newTransactionRoute, transactionDetailRoute]),
  debtsRoute.addChildren([newDebtRoute, debtDetailRoute]),
  holdingsRoute.addChildren([holdingDetailRoute]),
  goalsRoute.addChildren([goalDetailRoute]),
  remindersRoute,
  categoriesRoute,
  transactionTemplatesRoute,
  budgetRoute,
  reportsRoute,
  backupRoute,
  settingsRoute,
  onboardingRoute,
]);
```

- [ ] **Step 4: Verify routes work**

Run: `pnpm dev`

Navigate to `/accounts/some-id` — should render AccountDetailPage placeholder. Same for `/transactions/some-id`, `/goals/some-id`, `/debts/some-id`, `/holdings/some-id`.

Run: `pnpm type-check`

Expected: No type errors.

- [ ] **Step 5: Commit**

```bash
git add src/pages/AccountDetailPage.tsx src/pages/TransactionDetailPage.tsx src/pages/GoalDetailPage.tsx src/pages/DebtDetailPage.tsx src/pages/HoldingDetailPage.tsx src/router.tsx src/i18n/locales/en.json src/i18n/locales/zh.json
git commit -m "feat(routes): add placeholder detail page routes for account, transaction, goal, debt, holding"
```

---

## Task 9: Final Verification

- [ ] **Step 1: Run full validation**

Run: `pnpm type-check && pnpm lint`

Expected: No errors. All existing pages still compile and pass lint.

- [ ] **Step 2: Manual smoke test**

Run: `pnpm dev`

Verify:
- [ ] App loads with warm cream background
- [ ] Sidebar is dark with "御财" brand, 5 groups, gold active state
- [ ] Sidebar collapse/expand works (240px ↔ 64px)
- [ ] Header shows breadcrumb, blur backdrop
- [ ] All existing pages navigate correctly (Dashboard, Accounts, Transactions, etc.)
- [ ] Detail placeholder routes render (`/accounts/123`, `/transactions/123`, etc.)
- [ ] New/edit routes still work (`/accounts/new`, `/accounts/123/edit`)
- [ ] Mobile sidebar overlay still works

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "chore: P0 infrastructure complete — YuCai theme, sidebar, header, patterns, routes"
```

---

## Summary

| Task | What | Files |
|------|------|-------|
| 1 | Theme tokens | `index.css`, `tailwind.config.js` |
| 2 | Sidebar redesign | `Sidebar.tsx`, `SidebarGroup.tsx`, `SidebarNavItem.tsx`, `useSidebarState.ts` |
| 3 | Breadcrumb component | `BreadcrumbBar.tsx` |
| 4 | Header redesign | `Header.tsx` |
| 5 | AppLayout update | `AppLayout.tsx` |
| 6 | i18n updates | `en.json`, `zh.json` |
| 7 | Shared components | `patterns/` (12 components) |
| 8 | Route placeholders | 5 detail pages, `router.tsx`, i18n keys |
| 9 | Final verification | Type check, lint, smoke test |

**Next phase:** P1 — Account module (list → detail → form), using the patterns established in P0.
