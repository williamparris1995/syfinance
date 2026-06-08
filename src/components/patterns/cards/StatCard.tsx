import { cn } from '@/lib/utils';

interface StatCardProps {
  label: string;
  value: string;
  tag?: string;
  tagVariant?: 'positive' | 'negative' | 'neutral';
  className?: string;
}

export function StatCard({ label, value, tag, tagVariant = 'neutral', className }: StatCardProps) {
  return (
    <div className={cn('rounded-[14px] border border-border bg-card px-5 py-[18px]', className)}>
      <div className="mb-1.5 text-xs text-muted-foreground">{label}</div>
      <div className="font-display text-[22px] font-semibold tracking-tight">{value}</div>
      {tag && (
        <span
          className={cn(
            'mt-1.5 inline-block rounded-full px-2 py-0.5 font-mono text-[11px]',
            tagVariant === 'positive' && 'bg-income/10 text-income',
            tagVariant === 'negative' && 'bg-expense/10 text-expense',
            tagVariant === 'neutral' && 'bg-muted text-muted-foreground'
          )}
        >
          {tag}
        </span>
      )}
    </div>
  );
}
