import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { useTranslation } from 'react-i18next';
import {
  cloudSyncNow,
  getCloudSyncStatus,
  updateCloudSyncSettings,
  getCloudSyncSettings,
  getSyncStatusWithConflicts,
  resolveSyncConflict,
  type CloudSyncSettings,
} from '@/lib/tauri/cloudSync';

export function useCloudSyncStatus() {
  return useQuery({
    queryKey: ['cloudSyncStatus'],
    queryFn: getCloudSyncStatus,
    staleTime: 30_000,
  });
}

export function useCloudSyncSettings() {
  return useQuery({
    queryKey: ['cloudSyncSettings'],
    queryFn: getCloudSyncSettings,
  });
}

export function useCloudSyncNow() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: cloudSyncNow,
    onSuccess: (result) => {
      queryClient.invalidateQueries({ queryKey: ['cloudSyncStatus'] });
      queryClient.invalidateQueries({ queryKey: ['syncConflicts'] });
      toast.success(
        result.restored
          ? t('cloudSync.syncCompleteWithRestore')
          : t('cloudSync.syncComplete'),
      );
    },
    onError: (error) => {
      toast.error(t('cloudSync.syncFailed'), {
        description: String(error),
      });
    },
  });
}

export function useUpdateCloudSyncSettings() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (settings: CloudSyncSettings) =>
      updateCloudSyncSettings(settings),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['cloudSyncSettings'] });
      queryClient.invalidateQueries({ queryKey: ['cloudSyncStatus'] });
    },
  });
}

export function useSyncConflicts() {
  return useQuery({
    queryKey: ['syncConflicts'],
    queryFn: getSyncStatusWithConflicts,
    staleTime: 30_000,
    enabled: false, // Only fetch on demand, not automatically
  });
}

export function useResolveSyncConflict() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: ({
      tableName,
      recordId,
      resolution,
    }: {
      tableName: string;
      recordId: string;
      resolution: string;
    }) => resolveSyncConflict(tableName, recordId, resolution),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['syncConflicts'] });
      queryClient.invalidateQueries({ queryKey: ['cloudSyncStatus'] });
    },
    onError: (error) => {
      toast.error(t('cloudSync.conflictResolveFailed'), {
        description: String(error),
      });
    },
  });
}
