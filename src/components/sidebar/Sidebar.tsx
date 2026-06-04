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
