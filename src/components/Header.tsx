import { Bell, User } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { SyncStatus } from '@/components/SyncStatus';
import { useTranslation } from 'react-i18next';

export function Header() {
  const { t } = useTranslation();
  return (
    <header className="flex h-16 items-center justify-between border-b bg-background px-6">
      <div className="flex items-center gap-4">
        <h2 className="text-lg font-semibold text-foreground">{t('nav.dashboard')}</h2>
      </div>
      <div className="flex items-center gap-4">
        <SyncStatus />
        <div className="flex items-center gap-2">
          <Button variant="ghost" size="icon">
            <Bell className="h-5 w-5" />
          </Button>
          <Button variant="ghost" size="icon">
            <User className="h-5 w-5" />
          </Button>
        </div>
      </div>
    </header>
  );
}
