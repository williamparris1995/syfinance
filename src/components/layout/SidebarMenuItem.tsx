import { Link, useLocation } from '@tanstack/react-router';
import { ChevronRight, LucideIcon } from 'lucide-react';
import { Badge } from '../ui/badge';
import { cn } from '@/lib/utils';
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from '../ui/tooltip';

interface SidebarMenuItemProps {
  to: string;
  label: string;
  icon: LucideIcon;
  badge?: string | number;
  hasSubmenu?: boolean;
  onClick?: () => void;
  collapsed?: boolean;
}

export function SidebarMenuItem({
  to,
  label,
  icon: Icon,
  badge,
  hasSubmenu,
  onClick,
  collapsed,
}: SidebarMenuItemProps) {
  const location = useLocation();
  const isActive = location.pathname === to;

  const content = (
    <Link
      to={to}
      onClick={onClick}
      className={cn(
        'group flex items-center justify-between rounded-lg px-3 py-2 text-sm font-medium transition-colors',
        isActive
          ? 'bg-accent text-accent-foreground'
          : 'text-muted-foreground hover:bg-accent/50 hover:text-foreground',
        collapsed && 'justify-center px-2'
      )}
    >
      <div className={cn('flex items-center gap-3', collapsed && 'gap-0')}>
        <Icon className="h-4 w-4 shrink-0" />
        {!collapsed && <span>{label}</span>}
      </div>

      {!collapsed && (
        <div className="flex items-center gap-2">
          {badge && (
            <Badge
              variant="secondary"
              className="h-5 min-w-5 rounded-full px-1.5 text-xs font-medium"
            >
              {badge}
            </Badge>
          )}
          {hasSubmenu && (
            <ChevronRight className="h-4 w-4 text-muted-foreground transition-transform group-hover:translate-x-0.5" />
          )}
        </div>
      )}
    </Link>
  );

  if (collapsed) {
    return (
      <TooltipProvider delay={0}>
        <Tooltip>
          <TooltipTrigger>{content}</TooltipTrigger>
          <TooltipContent side="right" className="flex items-center gap-2">
            {label}
            {badge && (
              <Badge variant="secondary" className="h-5 min-w-5 rounded-full px-1.5 text-xs">
                {badge}
              </Badge>
            )}
          </TooltipContent>
        </Tooltip>
      </TooltipProvider>
    );
  }

  return content;
}
