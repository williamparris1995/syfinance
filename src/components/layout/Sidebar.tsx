import { Link, useLocation } from '@tanstack/react-router';
import { Home, Receipt, Wallet, CreditCard, BarChart3, Settings } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { cn } from '@/lib/utils';

interface SidebarProps {
  onNavigate?: () => void;
}

export function Sidebar({ onNavigate }: SidebarProps) {
  const location = useLocation();
  const { t } = useTranslation();

  const navItems = [
    { to: '/', label: t('nav.dashboard'), icon: Home },
    { to: '/transactions', label: t('nav.transactions'), icon: Receipt },
    { to: '/accounts', label: t('nav.accounts'), icon: Wallet },
    { to: '/debts', label: t('nav.debts'), icon: CreditCard },
    { to: '/reports', label: t('nav.reports'), icon: BarChart3 },
    { to: '/settings', label: t('nav.settings'), icon: Settings },
  ];

  return (
    <aside className="flex h-full w-64 flex-col border-r bg-card">
      {/* App branding */}
      <div className="flex h-16 items-center border-b px-6">
        <h2 className="text-lg font-semibold">{t('common.appName')}</h2>
      </div>

      {/* Navigation */}
      <nav className="flex-1 overflow-y-auto p-4">
        <div className="space-y-1">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = location.pathname === item.to;
            
            return (
              <Link
                key={item.to}
                to={item.to}
                onClick={onNavigate}
                className={cn(
                  "flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors",
                  isActive
                    ? "bg-accent text-accent-foreground"
                    : "text-muted-foreground hover:bg-accent hover:text-accent-foreground"
                )}
              >
                <Icon className="h-5 w-5" />
                {item.label}
              </Link>
            );
          })}
        </div>
      </nav>

      {/* Bottom section (optional - for user info, etc.) */}
      <div className="border-t p-4">
        <div className="text-xs text-muted-foreground">
          {/* Can add user info or app version here */}
        </div>
      </div>
    </aside>
  );
}
