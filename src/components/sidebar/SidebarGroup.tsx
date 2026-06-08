import { cn } from '@/lib/utils';

export interface SidebarGroupProps {
  label: string;
  isOpen: boolean;
  onToggle: () => void;
  toggleDisabled?: boolean;
  collapsed?: boolean;
  children: React.ReactNode;
}

export function SidebarGroup({
  label,
  isOpen,
  onToggle,
  toggleDisabled = false,
  collapsed = false,
  children,
}: SidebarGroupProps) {
  const handleClick = () => {
    if (!toggleDisabled) {
      onToggle();
    }
  };

  if (collapsed) {
    return (
      <div className="flex flex-col gap-1 px-2 py-1">
        <div className="mx-auto my-1 h-px w-5 bg-white/10" />
        {children}
      </div>
    );
  }

  return (
    <div className="flex flex-col">
      <button
        type="button"
        onClick={handleClick}
        disabled={toggleDisabled}
        aria-expanded={isOpen}
        className={cn(
          'px-5 py-3 text-[10px] font-medium uppercase tracking-[0.1em] font-mono transition-all duration-150',
          'text-white/25',
          toggleDisabled
            ? 'cursor-default'
            : 'cursor-pointer hover:text-white/40'
        )}
      >
        {label}
      </button>
      <div
        className="overflow-hidden transition-all duration-150 ease-in-out"
        style={{
          maxHeight: isOpen ? 500 : 0,
          opacity: isOpen ? 1 : 0,
        }}
      >
        <div className="flex flex-col gap-0.5 pb-1">{children}</div>
      </div>
    </div>
  );
}
