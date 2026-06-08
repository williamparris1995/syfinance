import { cn } from '@/lib/utils';
import { ReactNode } from 'react';

interface PageShellProps {
  children: ReactNode;
  narrow?: boolean;
  className?: string;
}

export function PageShell({ children, narrow, className }: PageShellProps) {
  return (
    <div className={cn('px-8 pb-12 pt-7', narrow && 'mx-auto max-w-[760px]', className)}>
      {children}
    </div>
  );
}
