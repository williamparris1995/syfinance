import { useState } from 'react';
import { ChevronDown, Plus } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '../ui/dropdown-menu';
import { cn } from '@/lib/utils';

interface Organization {
  id: string;
  name: string;
  subtitle?: string;
  icon?: React.ReactNode;
  shortcut?: string;
}

interface SidebarHeaderProps {
  organizationName: string;
  subtitle?: string;
  collapsed?: boolean;
  organizations?: Organization[];
  currentOrgId?: string;
  onOrganizationChange?: (orgId: string) => void;
  onAddOrganization?: () => void;
}

export function SidebarHeader({ 
  organizationName, 
  subtitle, 
  collapsed,
  organizations = [],
  currentOrgId,
  onOrganizationChange,
  onAddOrganization,
}: SidebarHeaderProps) {
  const [isOpen, setIsOpen] = useState(false);
  const { t } = useTranslation();

  const defaultIcon = (
    <svg
      className="h-5 w-5"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <rect x="3" y="3" width="7" height="7" />
      <rect x="14" y="3" width="7" height="7" />
      <rect x="14" y="14" width="7" height="7" />
      <rect x="3" y="14" width="7" height="7" />
    </svg>
  );

  if (collapsed) {
    return (
      <div className="flex items-center justify-center border-b px-2 py-3">
        {/* Organization Icon/Logo - collapsed state */}
        <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-foreground text-background">
          {defaultIcon}
        </div>
      </div>
    );
  }

  return (
    <div className="border-b">
      <DropdownMenu open={isOpen} onOpenChange={setIsOpen}>
        <DropdownMenuTrigger
          className={cn(
            'flex w-full items-center justify-between px-4 py-3 transition-colors hover:bg-accent',
            isOpen && 'bg-accent'
          )}
        >
          <div className="flex items-center gap-3">
            {/* Organization Icon/Logo */}
            <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-foreground text-background">
              {defaultIcon}
            </div>

            {/* Organization Name and Subtitle */}
            <div className="flex flex-col text-left">
              <span className="text-sm font-semibold leading-none">{organizationName}</span>
              {subtitle && (
                <span className="mt-1 text-xs text-muted-foreground">{subtitle}</span>
              )}
            </div>
          </div>

          {/* Dropdown Indicator */}
          <ChevronDown
            className={cn(
              'h-4 w-4 shrink-0 text-muted-foreground transition-transform',
              isOpen && 'rotate-180'
            )}
          />
        </DropdownMenuTrigger>

        <DropdownMenuContent align="start" className="w-56" sideOffset={8}>
          {/* Organization List */}
          {organizations.length > 0 ? (
            <>
              {organizations.map((org) => (
                <DropdownMenuItem
                  key={org.id}
                  onClick={() => onOrganizationChange?.(org.id)}
                  className={cn(
                    'flex items-center justify-between',
                    currentOrgId === org.id && 'bg-accent'
                  )}
                >
                  <div className="flex items-center gap-2">
                    {org.icon || (
                      <div className="flex h-5 w-5 items-center justify-center rounded bg-muted">
                        {defaultIcon}
                      </div>
                    )}
                    <span>{org.name}</span>
                  </div>
                  {org.shortcut && (
                    <span className="text-xs text-muted-foreground">{org.shortcut}</span>
                  )}
                </DropdownMenuItem>
              ))}
              <DropdownMenuSeparator />
            </>
          ) : (
            <div className="px-2 py-1.5 text-sm text-muted-foreground">
              {t('sidebar.noOrganizations')}
            </div>
          )}

          {/* Add Organization */}
          <DropdownMenuItem onClick={onAddOrganization}>
            <Plus className="mr-2 h-4 w-4" />
            <span>{t('sidebar.addOrganization')}</span>
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
}
