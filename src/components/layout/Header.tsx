import { WifiOff } from 'lucide-react';
import { useEffect, useState } from 'react';
import { isOnline, setupNetworkListeners } from '../../lib/error-handler';
import { SyncStatus } from '../SyncStatus';

export function Header() {
  const [online, setOnline] = useState(isOnline());

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
        <h1 className="text-xl font-semibold">Finance App</h1>
        <div className="flex items-center gap-4">
          {!online && (
            <div className="flex items-center gap-2 px-3 py-1 bg-orange-100 text-orange-800 rounded-md text-sm">
              <WifiOff className="h-4 w-4" />
              <span>Offline</span>
            </div>
          )}
          <SyncStatus />
        </div>
      </div>
    </header>
  );
}
