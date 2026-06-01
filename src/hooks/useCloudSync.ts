import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { useTranslation } from 'react-i18next';
import {
  cloudSyncNow,
  getCloudSyncStatus,
  updateCloudSyncSettings,
  getCloudSyncSettings,
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
