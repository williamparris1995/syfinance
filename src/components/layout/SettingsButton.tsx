import { Settings } from 'lucide-react';
import { Link } from '@tanstack/react-router';
import { Button } from '../ui/button';

interface SettingsButtonProps {
  onClick?: () => void;
}

export function SettingsButton({ onClick }: SettingsButtonProps) {
  if (onClick) {
    return (
      <Button
        variant="ghost"
        size="icon"
        onClick={onClick}
        aria-label="Settings"
      >
        <Settings className="h-5 w-5" />
      </Button>
    );
  }

  return (
    <Link to="/settings">
      <Button
        variant="ghost"
        size="icon"
        aria-label="Settings"
      >
        <Settings className="h-5 w-5" />
      </Button>
    </Link>
  );
}
