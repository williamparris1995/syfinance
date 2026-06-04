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
  Tag,
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
      { to: '/categories', labelKey: 'nav.categories', icon: Tag },
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
  collapsed?: boolean;
}

export function Sidebar({ onNavigate, collapsed }: SidebarProps) {
  const { t } = useTranslation();
  const router = useRouterState();
  const pathname = router.location.pathname;
  const activeGroupId = findActiveGroupId(pathname);
  const { isGroupOpen, toggleGroup } = useSidebarState(activeGroupId);

  return (
    <aside
      className={cn(
        'flex h-full flex-col border-r bg-sidebar transition-all duration-300',
        collapsed ? 'w-16' : 'w-64'
      )}
    >
      {!collapsed ? (
        <div className="border-b px-6 py-4">
          <h1 className="text-lg font-semibold text-sidebar-foreground">
            {t('nav.appTitle')}
          </h1>
        </div>
      ) : (
        <div className="border-b px-2 py-4 text-center">
          <span className="text-lg">📊</span>
        </div>
      )}
      <nav className={cn('flex-1 space-y-1', collapsed ? 'p-2' : 'p-4')}>
        {navGroups.map((group) => (
          <SidebarGroup
            key={group.id}
            label={collapsed ? '' : t(group.labelKey)}
            isOpen={collapsed ? false : isGroupOpen(group.id)}
            onToggle={() => toggleGroup(group.id)}
            toggleDisabled={group.id === activeGroupId || collapsed}
          >
            <div
              className={cn(
                'mt-1 space-y-px',
                collapsed && 'flex flex-col items-center'
              )}
            >
              {group.items.map((item) => (
                <SidebarNavItem
                  key={item.to}
                  to={item.to}
                  label={collapsed ? '' : t(item.labelKey)}
                  icon={item.icon}
                  exact={item.exact}
                  onNavigate={onNavigate}
                  title={t(item.labelKey)}
                  collapsed={collapsed}
                />
              ))}
            </div>
          </SidebarGroup>
        ))}
      </nav>
    </aside>
  );
}
