import { useState } from 'react';
import { ChevronDown, Sparkles, User, CreditCard, Bell, LogOut } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '../ui/dropdown-menu';
import { cn } from '@/lib/utils';

interface SidebarUserMenuProps {
  userName: string;
  userEmail: string;
  userInitials?: string;
  collapsed?: boolean;
}

export function SidebarUserMenu({ userName, userEmail, userInitials, collapsed }: SidebarUserMenuProps) {
  const [isOpen, setIsOpen] = useState(false);
  const { t } = useTranslation();

  const initials = userInitials || userName.substring(0, 2).toUpperCase();

  if (collapsed) {
    return (
      <div className="border-t p-2">
        <DropdownMenu open={isOpen} onOpenChange={setIsOpen}>
          <DropdownMenuTrigger
            className={cn(
              'flex w-full items-center justify-center rounded-lg px-2 py-2 transition-colors hover:bg-accent',
              isOpen && 'bg-accent'
            )}
          >
            {/* User Avatar - collapsed */}
            <div className="flex h-8 w-8 items-center justify-center rounded-md bg-muted text-sm font-medium">
              {initials}
            </div>
          </DropdownMenuTrigger>

          <DropdownMenuContent
            align="end"
            side="right"
            className="w-56"
            sideOffset={8}
          >
            <div className="flex items-center gap-2 px-2 py-1.5">
              <div className="flex h-8 w-8 items-center justify-center rounded-md bg-muted text-sm font-medium">
                {initials}
              </div>
              <div className="flex flex-col">
                <span className="text-sm font-medium">{userName}</span>
                <span className="text-xs text-muted-foreground">{userEmail}</span>
              </div>
            </div>

            <DropdownMenuSeparator />

            <DropdownMenuItem>
              <Sparkles className="mr-2 h-4 w-4" />
              <span>{t('header.upgradeToPro')}</span>
            </DropdownMenuItem>

            <DropdownMenuSeparator />

            <DropdownMenuItem>
              <User className="mr-2 h-4 w-4" />
              <span>{t('header.profile')}</span>
            </DropdownMenuItem>

            <DropdownMenuItem>
              <CreditCard className="mr-2 h-4 w-4" />
              <span>{t('header.billing')}</span>
            </DropdownMenuItem>

            <DropdownMenuItem>
              <Bell className="mr-2 h-4 w-4" />
              <span>{t('settings.notifications')}</span>
            </DropdownMenuItem>

            <DropdownMenuSeparator />

            <DropdownMenuItem className="text-destructive focus:text-destructive">
              <LogOut className="mr-2 h-4 w-4" />
              <span>{t('header.signOut')}</span>
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    );
  }

  return (
    <div className="border-t p-3">
      <DropdownMenu open={isOpen} onOpenChange={setIsOpen}>
        <DropdownMenuTrigger
          className={cn(
            'flex w-full items-center gap-3 rounded-lg px-2 py-2 text-left transition-colors hover:bg-accent',
            isOpen && 'bg-accent'
          )}
        >
          {/* User Avatar */}
          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-md bg-muted text-sm font-medium">
            {initials}
          </div>

          {/* User Info */}
          <div className="flex min-w-0 flex-1 flex-col">
            <span className="truncate text-sm font-medium">{userName}</span>
            <span className="truncate text-xs text-muted-foreground">{userEmail}</span>
          </div>

          {/* Dropdown Indicator */}
          <ChevronDown
            className={cn(
              'h-4 w-4 shrink-0 text-muted-foreground transition-transform',
              isOpen && 'rotate-180'
            )}
          />
        </DropdownMenuTrigger>

        <DropdownMenuContent
          align="end"
          side="top"
          className="w-56"
          sideOffset={8}
        >
          <div className="flex items-center gap-2 px-2 py-1.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-md bg-muted text-sm font-medium">
              {initials}
            </div>
            <div className="flex flex-col">
              <span className="text-sm font-medium">{userName}</span>
              <span className="text-xs text-muted-foreground">{userEmail}</span>
            </div>
          </div>

          <DropdownMenuSeparator />

          <DropdownMenuItem>
            <Sparkles className="mr-2 h-4 w-4" />
            <span>{t('header.upgradeToPro')}</span>
          </DropdownMenuItem>

          <DropdownMenuSeparator />

          <DropdownMenuItem>
            <User className="mr-2 h-4 w-4" />
            <span>{t('header.profile')}</span>
          </DropdownMenuItem>

          <DropdownMenuItem>
            <CreditCard className="mr-2 h-4 w-4" />
            <span>{t('header.billing')}</span>
          </DropdownMenuItem>

          <DropdownMenuItem>
            <Bell className="mr-2 h-4 w-4" />
            <span>{t('settings.notifications')}</span>
          </DropdownMenuItem>

          <DropdownMenuSeparator />

          <DropdownMenuItem className="text-destructive focus:text-destructive">
            <LogOut className="mr-2 h-4 w-4" />
            <span>{t('header.signOut')}</span>
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
}
