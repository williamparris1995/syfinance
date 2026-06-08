import { cn } from '@/lib/utils';
import { Input } from '@/components/ui/input';

interface AmountInputProps {
  currencySymbol?: string;
  currencyCode?: string;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  className?: string;
}

export function AmountInput({
  currencySymbol = '¥',
  currencyCode = 'CNY',
  value,
  onChange,
  placeholder = '0.00',
  className,
}: AmountInputProps) {
  return (
    <div
      className={cn(
        'flex overflow-hidden rounded-[10px] border border-border transition-colors',
        'focus-within:border-primary focus-within:ring-[3px] focus-within:ring-primary/10',
        className
      )}
    >
      <div className="flex items-center gap-1 border-r border-border bg-background px-3 py-2.5 font-mono text-[13px] font-medium text-muted-foreground">
        {currencySymbol}
        <span className="text-[10px]">{currencyCode}</span>
      </div>
      <Input
        type="number"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="border-0 bg-transparent text-lg font-mono tabular-nums shadow-none focus-visible:ring-0"
      />
    </div>
  );
}
