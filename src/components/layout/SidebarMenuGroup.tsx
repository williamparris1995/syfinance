import { ReactNode } from 'react';

interface SidebarMenuGroupProps {
  label: string;
  children?: ReactNode;
}

export function SidebarMenuGroup({ label, children }: SidebarMenuGroupProps) {
  return (
    <div className="space-y-1">
      <h3 className="mb-2 px-3 text-xs font-medium text-muted-foreground uppercase tracking-wider">
        {label}
      </h3>
      {children && <div className="space-y-0.5">{children}</div>}
    </div>
  );
}
