import { ReactNode } from 'react';
import { SidebarToggle } from './SidebarToggle';
import { GlobalSearch } from '@/components/GlobalSearch';
import { ThemeToggle } from '../theme/ThemeToggle';
import { SettingsButton } from './SettingsButton';
import { HeaderUserMenu } from './HeaderUserMenu';
import { cn } from '@/lib/utils';

interface HeaderProps {
  /** Content to display in the left section (after sidebar toggle) */
  leftContent?: ReactNode;
  /** Content to display in the center section */
  centerContent?: ReactNode;
  /** Content to display in the right section (before theme/settings/user) */
  rightContent?: ReactNode;
  /** Show sidebar toggle button */
  showSidebarToggle?: boolean;
  /** Show search bar */
  showSearch?: boolean;
  /** Show theme toggle button */
  showThemeToggle?: boolean;
  /** Show settings button */
  showSettings?: boolean;
  /** Show user menu */
  showUserMenu?: boolean;
  /** Callback when sidebar toggle is clicked */
  onSidebarToggle?: () => void;
  /** User information for user menu */
  user?: {
    name: string;
    email: string;
    initials?: string;
  };
  /** Callbacks for user menu actions */
  userMenuActions?: {
    onProfileClick?: () => void;
    onBillingClick?: () => void;
    onSettingsClick?: () => void;
    onNewTeamClick?: () => void;
    onSignOut?: () => void;
  };
  className?: string;
}

export function Header({
  leftContent,
  centerContent,
  rightContent,
  showSidebarToggle = true,
  showSearch = true,
  showThemeToggle = true,
  showSettings = true,
  showUserMenu = true,
  onSidebarToggle,
  user,
  userMenuActions,
  className,
}: HeaderProps) {
  return (
    <header className={cn('flex h-14 items-center border-b bg-card px-4', className)}>
      {/* Left Section */}
      <div className="flex items-center gap-3">
        {showSidebarToggle && <SidebarToggle onClick={onSidebarToggle} />}
        {showSearch && <GlobalSearch className="w-64" />}
        {leftContent}
      </div>

      {/* Center Section */}
      {centerContent && (
        <div className="flex flex-1 items-center justify-center">
          {centerContent}
        </div>
      )}

      {/* Right Section */}
      <div className="ml-auto flex items-center gap-2">
        {rightContent}
        {showThemeToggle && <ThemeToggle />}
        {showSettings && <SettingsButton />}
        {showUserMenu && (
          <HeaderUserMenu
            userName={user?.name}
            userEmail={user?.email}
            userInitials={user?.initials}
            {...userMenuActions}
          />
        )}
      </div>
    </header>
  );
}
