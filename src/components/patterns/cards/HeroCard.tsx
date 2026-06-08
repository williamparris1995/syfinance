import { cn } from '@/lib/utils';
import { ReactNode } from 'react';

interface HeroCardProps {
  icon: ReactNode;
  name: string;
  subtitle?: string;
  children?: ReactNode;
  className?: string;
}

export function HeroCard({ icon, name, subtitle, children, className }: HeroCardProps) {
  return (
    <div
      className={cn(
        'relative mb-5 overflow-hidden rounded-[14px] border border-border bg-card p-7',
        'flex items-center gap-10',
        className
      )}
    >
      <div className="pointer-events-none absolute -right-[10%] -top-[40%] h-[180%] w-1/2 bg-[radial-gradient(ellipse_at_center,oklch(var(--primary)/0.06)_0%,transparent_70%)]" />
      <div className="relative z-10 shrink-0">
        <div className="mb-3 flex h-12 w-12 items-center justify-center rounded-xl bg-primary/10 text-primary">
          {icon}
        </div>
        <div className="font-display text-xl font-semibold tracking-tight">{name}</div>
        {subtitle && <div className="mt-0.5 text-xs text-muted-foreground">{subtitle}</div>}
      </div>
      <div className="relative z-10 flex-1">{children}</div>
    </div>
  );
}
