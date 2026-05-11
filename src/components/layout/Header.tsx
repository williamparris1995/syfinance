import { WifiOff } from 'lucide-react';
import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { isOnline, setupNetworkListeners } from '../../lib/error-handler';
import { SyncStatus } from '../SyncStatus';
import { MobileSidebar } from './MobileSidebar';

export function Header() {
  const [online, setOnline] = useState(isOnline());
  const { t } = useTranslation();

  useEffect(() => {
    const cleanup = setupNetworkListeners(
      () => setOnline(true),
      () => setOnline(false)
    );
    return cleanup;
  }, []);

  return (
    <header className="border-b bg-card">
      <div className="flex h-16 items-center justify-between px-6">
        <div className="flex items-center gap-4">
          <MobileSidebar />
          <h1 className="text-xl font-semibold">{t('common.appName')}</h1>
        </div>
        <div className="flex items-center gap-4">
          {!online && (
            <div className="flex items-center gap-2 px-3 py-1 bg-orange-100 text-orange-800 rounded-md text-sm">
              <WifiOff className="h-4 w-4" />
              <span>{t('common.offline')}</span>
            </div>
          )}
          <SyncStatus />
        </div>
      </div>
    </header>
  );
}
