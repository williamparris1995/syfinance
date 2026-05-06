import { useState, useEffect } from 'react';
import { Clock, RefreshCw, Check, AlertCircle } from 'lucide-react';
import { Button } from './ui/button';
import { getLastSyncTime, formatSyncTime, triggerSync } from '../lib/sync';

type SyncState = 'idle' | 'syncing' | 'success' | 'error';

export function SyncStatus() {
  const [syncState, setSyncState] = useState<SyncState>('idle');
  const [lastSyncTime, setLastSyncTime] = useState<Date | null>(null);
  const [errorMessage, setErrorMessage] = useState<string>('');

  // Load last sync time from localStorage on mount
  useEffect(() => {
    const lastSync = getLastSyncTime();
    setLastSyncTime(lastSync);
  }, []);

  // Auto-clear success state after 3 seconds
  useEffect(() => {
    if (syncState === 'success') {
      const timer = setTimeout(() => {
        setSyncState('idle');
      }, 3000);
      return () => clearTimeout(timer);
    }
  }, [syncState]);

  // Auto-clear error state after 5 seconds
  useEffect(() => {
    if (syncState === 'error') {
      const timer = setTimeout(() => {
        setSyncState('idle');
        setErrorMessage('');
      }, 5000);
      return () => clearTimeout(timer);
    }
  }, [syncState]);

  const handleSyncClick = async () => {
    setSyncState('syncing');
    setErrorMessage('');

    try {
      await triggerSync();
      const newSyncTime = getLastSyncTime();
      setLastSyncTime(newSyncTime);
      setSyncState('success');
    } catch (error) {
      setSyncState('error');
      setErrorMessage(error instanceof Error ? error.message : 'Sync failed');
    }
  };

  const getSyncStatusText = () => {
    switch (syncState) {
      case 'syncing':
        return 'Syncing...';
      case 'success':
        return 'Synced just now';
      case 'error':
        return `Sync failed: ${errorMessage}`;
      case 'idle':
      default:
        return lastSyncTime ? `Last synced: ${formatSyncTime(lastSyncTime)}` : 'Never synced';
    }
  };

  const getSyncIcon = () => {
    switch (syncState) {
      case 'syncing':
        return <RefreshCw className="h-4 w-4 animate-spin" />;
      case 'success':
        return <Check className="h-4 w-4 text-green-600" />;
      case 'error':
        return <AlertCircle className="h-4 w-4 text-red-600" />;
      case 'idle':
      default:
        return <Clock className="h-4 w-4 text-muted-foreground" />;
    }
  };

  return (
    <div className="flex items-center gap-3">
      <div className="flex items-center gap-2 text-sm text-muted-foreground">
        {getSyncIcon()}
        <span className={syncState === 'error' ? 'text-red-600' : ''}>{getSyncStatusText()}</span>
      </div>
      <Button
        variant="outline"
        size="sm"
        onClick={handleSyncClick}
        disabled={syncState === 'syncing'}
      >
        <RefreshCw className={`h-4 w-4 mr-2 ${syncState === 'syncing' ? 'animate-spin' : ''}`} />
        Sync Now
      </Button>
    </div>
  );
}
