import { Link } from '@tanstack/react-router';
import { cn } from '@/lib/utils';

export interface SidebarNavItemProps {
  to: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  exact?: boolean;
  onNavigate?: () => void;
  title?: string;
  collapsed?: boolean;
}

export function SidebarNavItem({
  to,
  label,
  icon: Icon,
  exact,
  onNavigate,
  title,
  collapsed,
}: SidebarNavItemProps) {
  return (
    <Link
      to={to}
      activeOptions={exact ? { exact: true } : undefined}
      activeProps={{
        className: 'bg-sidebar-accent text-sidebar-accent-foreground',
      }}
      className={cn(
        'flex items-center rounded-md text-sidebar-foreground transition-colors hover:bg-sidebar-accent hover:text-sidebar-accent-foreground',
        collapsed
          ? 'justify-center px-2 py-2'
          : 'gap-3 px-3 py-2 text-sm font-medium'
      )}
      onClick={onNavigate}
      title={title}
    >
      <Icon className="h-4 w-4" />
      {!collapsed && <span>{label}</span>}
    </Link>
  );
}
