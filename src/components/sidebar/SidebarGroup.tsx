import { ChevronDown, ChevronRight } from 'lucide-react';

export interface SidebarGroupProps {
  label: string;
  isOpen: boolean;
  onToggle: () => void;
  toggleDisabled?: boolean;
  children: React.ReactNode;
}

export function SidebarGroup({
  label,
  isOpen,
  onToggle,
  toggleDisabled = false,
  children,
}: SidebarGroupProps) {
  const handleClick = () => {
    if (!toggleDisabled) {
      onToggle();
    }
  };

  return (
    <div className="flex flex-col">
      <button
        type="button"
        onClick={handleClick}
        disabled={toggleDisabled}
        aria-expanded={isOpen}
        className={`flex items-center justify-between rounded-md px-3 py-2 text-[11px] font-medium uppercase tracking-wider text-sidebar-foreground/60 transition-all duration-150 ease-in-out ${
          toggleDisabled
            ? 'cursor-default opacity-50'
            : 'hover:bg-sidebar-accent/50 cursor-pointer'
        }`}
      >
        <span>{label}</span>
        {isOpen ? (
          <ChevronDown className="h-3 w-3" />
        ) : (
          <ChevronRight className="h-3 w-3" />
        )}
      </button>
      <div
        className="overflow-hidden transition-all duration-150 ease-in-out"
        style={{
          maxHeight: isOpen ? 500 : 0,
          opacity: isOpen ? 1 : 0,
        }}
      >
        <div className="flex flex-col gap-1 py-1">{children}</div>
      </div>
    </div>
  );
}
