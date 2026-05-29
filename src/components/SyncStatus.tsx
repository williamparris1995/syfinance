import { RefreshCw } from 'lucide-react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { invokeTauri } from '@/lib/tauri';
import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';

interface SyncStatusDto {
  last_sync_at: string | null;
  is_syncing: boolean;
  error: string | null;
}

const LAST_SYNC_KEY = 'finance_app_last_sync';

function getRelativeTime(timestamp: string, t: (key: string, options?: Record<string, unknown>) => string): string {
  const now = new Date();
  const syncTime = new Date(timestamp);
  const diffMs = now.getTime() - syncTime.getTime();
  const diffMinutes = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMinutes / 60);
  const diffDays = Math.floor(diffHours / 24);

  if (diffMinutes < 1) return t('sync.justNow');
  if (diffMinutes === 1) return t('sync.minuteAgo', { count: 1 });
  if (diffMinutes < 60) return t('sync.minutesAgo', { count: diffMinutes });
  if (diffHours === 1) return t('sync.hourAgo', { count: 1 });
  if (diffHours < 24) return t('sync.hoursAgo', { count: diffHours });
  if (diffDays === 1) return t('sync.dayAgo', { count: 1 });
  return t('sync.daysAgo', { count: diffDays });
}

export function SyncStatus() {
  const { t } = useTranslation();
  const [lastSyncLocal, setLastSyncLocal] = useState<string | null>(() => {
    return localStorage.getItem(LAST_SYNC_KEY);
  });

  const { data: syncStatus } = useQuery<SyncStatusDto>({
    queryKey: ['syncStatus'],
    queryFn: () => invokeTauri<SyncStatusDto>('get_sync_status'),
    refetchInterval: 5000,
  });

  const syncMutation = useMutation({
    mutationFn: async () => {
      const result = await invokeTauri<SyncStatusDto>('sync_to_server');
      return result;
    },
    onSuccess: (data) => {
      if (data.last_sync_at) {
        localStorage.setItem(LAST_SYNC_KEY, data.last_sync_at);
        setLastSyncLocal(data.last_sync_at);
      }
    },
  });

  useEffect(() => {
    if (syncStatus?.last_sync_at) {
      localStorage.setItem(LAST_SYNC_KEY, syncStatus.last_sync_at);
      setLastSyncLocal(syncStatus.last_sync_at);
    }
  }, [syncStatus?.last_sync_at]);

  const isSyncing = syncStatus?.is_syncing || syncMutation.isPending;
  const error = syncMutation.error
    ? String(syncMutation.error)
    : syncStatus?.error;
  const lastSync = syncStatus?.last_sync_at || lastSyncLocal;

  const handleSync = () => {
    syncMutation.mutate();
  };

  return (
    <div className="flex items-center gap-3">
      <div className="flex items-center gap-2">
        {isSyncing ? (
          <Badge variant="secondary" className="gap-1.5">
            <RefreshCw className="h-3 w-3 animate-spin" />
            Syncing...
          </Badge>
        ) : error ? (
          <Badge variant="destructive" className="gap-1.5">
            Failed
          </Badge>
        ) : lastSync ? (
          <Badge variant="outline" className="gap-1.5">
            <span className="h-2 w-2 rounded-full bg-green-500" />
            Synced
          </Badge>
        ) : (
          <Badge variant="outline">Not synced</Badge>
        )}

        {lastSync && !isSyncing && (
          <span className="text-xs text-muted-foreground">
            {getRelativeTime(lastSync, t)}
          </span>
        )}
      </div>

      <Button
        variant="ghost"
        size="sm"
        onClick={handleSync}
        disabled={isSyncing}
        className="gap-1.5"
      >
        <RefreshCw className={`h-4 w-4 ${isSyncing ? 'animate-spin' : ''}`} />
        Sync Now
      </Button>

      {error && !isSyncing && (
        <span className="text-xs text-destructive max-w-xs truncate" title={error}>
          {error}
        </span>
      )}
    </div>
  );
}
