import { cn } from '@/lib/utils';
import { ReactNode } from 'react';

interface DataCardProps {
  children?: ReactNode;
  onClick?: () => void;
  className?: string;
}

export function DataCard({ children, onClick, className }: DataCardProps) {
  return (
    <div
      onClick={onClick}
      className={cn(
        'rounded-[14px] border border-border bg-card p-5 transition-colors',
        onClick && 'cursor-pointer hover:border-primary/40'
      )}
    >
      {children}
    </div>
  );
}
