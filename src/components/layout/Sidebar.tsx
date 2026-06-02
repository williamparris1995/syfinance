import {
  Home,
  Receipt,
  Wallet,
  CreditCard,
  BarChart3,
  Settings,
  HardDrive,
  HelpCircle,
  TrendingUp,
  CalendarClock,
  PiggyBank,
  Target,
  Repeat,
} from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { SidebarHeader } from './SidebarHeader';
import { SidebarMenuItem } from './SidebarMenuItem';
import { SidebarMenuGroup } from './SidebarMenuGroup';
import { SidebarUserMenu } from './SidebarUserMenu';
import { cn } from '@/lib/utils';

interface SidebarProps {
  onNavigate?: () => void;
  collapsed?: boolean;
}

export function Sidebar({ onNavigate, collapsed }: SidebarProps) {
  const { t } = useTranslation();

  return (
    <aside className={cn(
      'flex h-full flex-col border-r bg-gradient-to-b from-card via-card to-muted/20 transition-all duration-300',
      collapsed ? 'w-16' : 'w-64'
    )}>
      {/* Header */}
      <SidebarHeader 
        organizationName={t('common.appName')}
        subtitle="Finance Management"
        collapsed={collapsed}
      />

      {/* Navigation */}
      <nav className={cn(
        'flex-1 overflow-y-auto p-4',
        collapsed && 'p-2'
      )}>
        <div className="space-y-6">
          {/* General Section */}
          {!collapsed && <SidebarMenuGroup label="General" />}
          <div className="space-y-0.5">
            <SidebarMenuItem
              to="/"
              label={t('nav.dashboard')}
              icon={Home}
              onClick={onNavigate}
              collapsed={collapsed}
            />
            <SidebarMenuItem
              to="/accounts"
              label={t('nav.accounts')}
              icon={Wallet}
              onClick={onNavigate}
              collapsed={collapsed}
            />
            <SidebarMenuItem
              to="/debts"
              label={t('nav.debts')}
              icon={CreditCard}
              onClick={onNavigate}
              collapsed={collapsed}
            />
            <SidebarMenuItem
              to="/holdings"
              label={t('nav.holdings')}
              icon={TrendingUp}
              onClick={onNavigate}
              collapsed={collapsed}
            />
            <SidebarMenuItem
              to="/subscriptions"
              label={t('nav.subscriptions')}
              icon={CalendarClock}
              onClick={onNavigate}
              collapsed={collapsed}
            />
            <SidebarMenuItem
              to="/transactions"
              label={t('nav.transactions')}
              icon={Receipt}
              onClick={onNavigate}
              collapsed={collapsed}
            />
            <SidebarMenuItem
              to="/transaction-templates"
              label={t('nav.recurring')}
              icon={Repeat}
              onClick={onNavigate}
              collapsed={collapsed}
            />
            <SidebarMenuItem
              to="/budget"
              label={t('nav.budget')}
              icon={PiggyBank}
              onClick={onNavigate}
              collapsed={collapsed}
            />
            <SidebarMenuItem
              to="/goals"
              label={t('nav.goals')}
              icon={Target}
              onClick={onNavigate}
              collapsed={collapsed}
            />
            <SidebarMenuItem
              to="/reports"
              label={t('nav.reports')}
              icon={BarChart3}
              onClick={onNavigate}
              collapsed={collapsed}
            />
          </div>

          {/* Other Section */}
          {!collapsed && <SidebarMenuGroup label="Other" />}
          <div className="space-y-0.5">
            <SidebarMenuItem
              to="/backup"
              label={t('nav.backup')}
              icon={HardDrive}
              onClick={onNavigate}
              collapsed={collapsed}
            />
            <SidebarMenuItem
              to="/settings"
              label={t('nav.settings')}
              icon={Settings}
              onClick={onNavigate}
              collapsed={collapsed}
            />
            <SidebarMenuItem
              to="/help"
              label={t('sidebar.helpCenter')}
              icon={HelpCircle}
              onClick={onNavigate}
              collapsed={collapsed}
            />
          </div>
        </div>
      </nav>

      {/* User Menu */}
      <SidebarUserMenu
        userName="User"
        userEmail="user@example.com"
        userInitials="U"
        collapsed={collapsed}
      />
    </aside>
  );
}
