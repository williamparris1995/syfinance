import { ReactNode } from 'react';
import { GlobalSearch } from '@/components/GlobalSearch';
import { ThemeToggle } from '../theme/ThemeToggle';
import { SettingsButton } from './SettingsButton';
import { BreadcrumbBar } from './BreadcrumbBar';
import { cn } from '@/lib/utils';

interface HeaderProps {
  rightContent?: ReactNode;
  showSearch?: boolean;
  showThemeToggle?: boolean;
  showSettings?: boolean;
  className?: string;
}

export function Header({
  rightContent,
  showSearch = true,
  showThemeToggle = true,
  showSettings = true,
  className,
}: HeaderProps) {
  return (
    <header
      className={cn(
        'sticky top-0 z-10 flex h-14 items-center justify-between border-b px-8',
        'border-border bg-background/90 backdrop-blur-xl',
        className
      )}
    >
      <BreadcrumbBar />
      <div className="flex items-center gap-3">
        {rightContent}
        {showSearch && <GlobalSearch className="w-56" />}
        {showThemeToggle && <ThemeToggle />}
        {showSettings && <SettingsButton />}
      </div>
    </header>
  );
}
