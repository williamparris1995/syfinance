import { cn } from '@/lib/utils';
import { ReactNode } from 'react';

interface DetailTwoColProps {
  main: ReactNode;
  side: ReactNode;
  className?: string;
}

export function DetailTwoCol({ main, side, className }: DetailTwoColProps) {
  return (
    <div className={cn('grid grid-cols-1 gap-6 lg:grid-cols-[1fr_300px]', className)}>
      <div>{main}</div>
      <div>{side}</div>
    </div>
  );
}
