import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '../ui/dropdown-menu';

interface HeaderUserMenuProps {
  userName?: string;
  userEmail?: string;
  userInitials?: string;
  onProfileClick?: () => void;
  onBillingClick?: () => void;
  onSettingsClick?: () => void;
  onNewTeamClick?: () => void;
  onSignOut?: () => void;
}

export function HeaderUserMenu({
  userName = 'User',
  userEmail = 'user@example.com',
  userInitials,
  onProfileClick,
  onBillingClick,
  onSettingsClick,
  onNewTeamClick,
  onSignOut,
}: HeaderUserMenuProps) {
  const [isOpen, setIsOpen] = useState(false);
  const { t } = useTranslation();
  const initials = userInitials || userName.substring(0, 2).toUpperCase();

  return (
    <DropdownMenu open={isOpen} onOpenChange={setIsOpen}>
      <DropdownMenuTrigger asChild>
        <div
          role="button"
          tabIndex={0}
          className="inline-flex h-8 w-8 items-center justify-center rounded-md hover:bg-accent hover:text-accent-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring cursor-pointer"
          aria-label="User menu"
          onKeyDown={(e) => {
            if (e.key === 'Enter' || e.key === ' ') {
              e.preventDefault();
              setIsOpen(!isOpen);
            }
          }}
        >
          <div className="flex h-full w-full items-center justify-center bg-muted text-xs font-medium rounded-md">
            {initials}
          </div>
        </div>
      </DropdownMenuTrigger>

      <DropdownMenuContent align="end" className="w-56">
        <div className="flex flex-col space-y-1 px-2 py-1.5">
          <p className="text-sm font-medium">{userName}</p>
          <p className="text-xs text-muted-foreground">{userEmail}</p>
        </div>

        <DropdownMenuSeparator />

        <DropdownMenuItem onClick={onProfileClick}>
          <span>{t('header.profile')}</span>
          <span className="ml-auto text-xs text-muted-foreground">⌘P</span>
        </DropdownMenuItem>

        <DropdownMenuItem onClick={onBillingClick}>
          <span>{t('header.billing')}</span>
          <span className="ml-auto text-xs text-muted-foreground">⌘B</span>
        </DropdownMenuItem>

        <DropdownMenuItem onClick={onSettingsClick}>
          <span>{t('header.settings')}</span>
          <span className="ml-auto text-xs text-muted-foreground">⌘S</span>
        </DropdownMenuItem>

        <DropdownMenuSeparator />

        <DropdownMenuItem onClick={onNewTeamClick}>
          <span>{t('header.newTeam')}</span>
        </DropdownMenuItem>

        <DropdownMenuSeparator />

        <DropdownMenuItem 
          onClick={onSignOut}
          className="text-destructive focus:text-destructive"
        >
          <span>{t('header.signOut')}</span>
          <span className="ml-auto text-xs text-muted-foreground">⌘Q</span>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
