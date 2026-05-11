import { Menu, PanelLeft } from 'lucide-react';
import { Button } from '../ui/button';

interface SidebarToggleProps {
  onClick?: () => void;
  /** Use panel icon for desktop (collapse mode) or menu icon for mobile (hide mode) */
  variant?: 'desktop' | 'mobile';
}

export function SidebarToggle({ onClick, variant = 'desktop' }: SidebarToggleProps) {
  const Icon = variant === 'desktop' ? PanelLeft : Menu;
  
  return (
    <Button
      variant="ghost"
      size="icon"
      onClick={onClick}
      aria-label="Toggle sidebar"
    >
      <Icon className="h-5 w-5" />
    </Button>
  );
}
