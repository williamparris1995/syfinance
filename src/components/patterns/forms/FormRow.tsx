import { cn } from '@/lib/utils';
import { ReactNode } from 'react';

interface FormRowProps {
  children: ReactNode;
  cols?: 1 | 2 | 3;
  className?: string;
}

export function FormRow({ children, cols = 2, className }: FormRowProps) {
  return (
    <div
      className={cn(
        'mb-4 grid gap-4',
        cols === 1 && 'grid-cols-1',
        cols === 2 && 'grid-cols-2',
        cols === 3 && 'grid-cols-3',
        className
      )}
    >
      {children}
    </div>
  );
}
