import { Link } from '@tanstack/react-router';

export interface SidebarNavItemProps {
  to: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  exact?: boolean;
  onNavigate?: () => void;
}

export function SidebarNavItem({
  to,
  label,
  icon: Icon,
  exact,
  onNavigate,
}: SidebarNavItemProps) {
  return (
    <Link
      to={to}
      activeOptions={exact ? { exact: true } : undefined}
      activeProps={{
        className: 'bg-sidebar-accent text-sidebar-accent-foreground',
      }}
      className="flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium text-sidebar-foreground transition-colors hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
      onClick={onNavigate}
    >
      <Icon className="h-4 w-4" />
      {label}
    </Link>
  );
}
