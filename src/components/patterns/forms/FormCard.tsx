import { cn } from '@/lib/utils';
import { ReactNode } from 'react';

interface FormCardProps {
  children: ReactNode;
  className?: string;
}

export function FormCard({ children, className }: FormCardProps) {
  return (
    <div className={cn('rounded-[14px] border border-border bg-card p-7', className)}>
      {children}
    </div>
  );
}
