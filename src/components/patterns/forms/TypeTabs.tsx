import { cn } from '@/lib/utils';

interface TypeTab {
  label: string;
  value: string;
}

interface TypeTabsProps {
  tabs: TypeTab[];
  value: string;
  onChange: (value: string) => void;
  className?: string;
}

export function TypeTabs({ tabs, value, onChange, className }: TypeTabsProps) {
  return (
    <div className={cn('mb-6 flex overflow-hidden rounded-[10px] border border-border bg-card', className)}>
      {tabs.map((tab) => (
        <button
          key={tab.value}
          type="button"
          onClick={() => onChange(tab.value)}
          className={cn(
            'flex-1 border-r border-border px-4 py-3 text-[13px] font-medium transition-colors last:border-r-0',
            value === tab.value
              ? 'bg-primary/10 text-primary'
              : 'text-muted-foreground hover:text-foreground'
          )}
        >
          {tab.label}
        </button>
      ))}
    </div>
  );
}
