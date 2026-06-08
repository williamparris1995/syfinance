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
  badge?: string | number;
}

export function SidebarNavItem({
  to,
  label,
  icon: Icon,
  exact,
  onNavigate,
  title,
  collapsed,
  badge,
}: SidebarNavItemProps) {
  if (collapsed) {
    return (
      <Link
        to={to}
        activeOptions={exact ? { exact: true } : undefined}
        activeProps={{
          className: 'bg-sidebar-accent text-white',
        }}
        className="flex items-center justify-center rounded-lg p-2.5 text-sidebar-foreground transition-colors hover:bg-sidebar-accent hover:text-white"
        onClick={onNavigate}
        title={title ?? label}
      >
        <Icon className="h-[18px] w-[18px]" />
      </Link>
    );
  }

  return (
    <Link
      to={to}
      activeOptions={exact ? { exact: true } : undefined}
      activeProps={{
        className: 'bg-sidebar-accent text-white [&>svg]:opacity-100',
      }}
      className={cn(
        'flex items-center gap-2.5 px-5 py-2 text-[13px] text-sidebar-foreground transition-colors',
        'hover:bg-sidebar-accent hover:text-white',
        '[&>svg]:opacity-60'
      )}
      onClick={onNavigate}
      title={title}
    >
      <Icon className="h-[18px] w-[18px] shrink-0" />
      <span>{label}</span>
      {badge !== undefined && (
        <span className="ml-auto rounded-full bg-primary px-1.5 py-px text-[10px] font-mono text-primary-foreground">
          {badge}
        </span>
      )}
    </Link>
  );
}
