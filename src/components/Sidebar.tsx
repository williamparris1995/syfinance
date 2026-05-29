import { Link } from '@tanstack/react-router';
import { Home, Wallet, Receipt, CreditCard, BarChart3, Settings } from 'lucide-react';
import { useTranslation } from 'react-i18next';

type NavItem = {
  to: '/' | '/accounts' | '/transactions' | '/debts' | '/reports' | '/settings';
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  exact?: boolean;
};

export function Sidebar() {
  const { t } = useTranslation();

  const navItems: NavItem[] = [
    { to: '/', label: t('nav.dashboard'), icon: Home, exact: true },
    { to: '/accounts', label: t('nav.accounts'), icon: Wallet },
    { to: '/transactions', label: t('nav.transactions'), icon: Receipt },
    { to: '/debts', label: t('nav.debts'), icon: CreditCard },
    { to: '/reports', label: t('nav.reports'), icon: BarChart3 },
    { to: '/settings', label: t('nav.settings'), icon: Settings },
  ];

  return (
    <aside className="flex h-full w-64 flex-col border-r bg-sidebar">
      <div className="border-b px-6 py-4">
        <h1 className="text-lg font-semibold text-sidebar-foreground">{t('nav.appTitle')}</h1>
      </div>
      <nav className="flex-1 space-y-1 p-4">
        {navItems.map((item) => {
          const Icon = item.icon;
          return (
            <Link
              key={item.to}
              to={item.to}
              activeOptions={item.exact ? { exact: true } : undefined}
              activeProps={{
                className: 'bg-sidebar-accent text-sidebar-accent-foreground',
              }}
              className="flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium text-sidebar-foreground transition-colors hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
            >
              <Icon className="h-4 w-4" />
              {item.label}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}
