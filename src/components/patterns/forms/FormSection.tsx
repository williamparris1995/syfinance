import { cn } from '@/lib/utils';
import { ReactNode } from 'react';

interface FormSectionProps {
  title: string;
  children: ReactNode;
  className?: string;
}

export function FormSection({ title, children, className }: FormSectionProps) {
  return (
    <div className={cn('mb-6 last:mb-0', className)}>
      <div className="mb-4 border-b border-border pb-2 text-xs font-semibold uppercase tracking-[0.08em] text-muted-foreground">
        {title}
      </div>
      {children}
    </div>
  );
}
