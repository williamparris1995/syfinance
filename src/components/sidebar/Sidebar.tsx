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
      {!collapsed ? (
        <div className="border-b border-white/[0.06] px-5 pb-5 pt-6">
          <h2 className="font-display text-xl font-semibold tracking-tight text-white">
            {t('nav.brandTitle')}
          </h2>
          <span className="mt-0.5 block text-[11px] text-white/40">
            {t('nav.brandSubtitle')}
          </span>
        </div>
      ) : (
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
        {onToggleCollapse && (
          <button
            type="button"
            onClick={onToggleCollapse}
            className="flex w-full items-center justify-center rounded-lg p-2 text-sidebar-foreground/50 transition-colors hover:bg-sidebar-accent hover:text-white"
            title={collapsed ? t('nav.expandSidebar') : t('nav.collapseSidebar')}
          >
            {collapsed ? (
              <ChevronsRight className="h-4 w-4" />
            ) : (
              <ChevronsLeft className="h-4 w-4" />
            )}
          </button>
        )}
      </div>
    </div>
  );
}
