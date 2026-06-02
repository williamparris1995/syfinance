import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  createBackup, listBackups, getCloudPresets, getCloudSettings,
  saveCloudSettings, testCloudConnection, uploadToCloud, deleteBackup,
  restoreBackup, authorizeCloudProvider,
  getAutoBackupSettings, updateAutoBackupSettings,
  type BackupInfo, type CloudPreset, type CloudSettings,
  type AutoBackupSettings,
} from '../lib/tauri/backup';

export function useBackup() {
  const queryClient = useQueryClient();

  const backupsQuery = useQuery<BackupInfo[]>({
    queryKey: ['backups'],
    queryFn: listBackups,
  });

  const cloudPresetsQuery = useQuery<CloudPreset[]>({
    queryKey: ['cloud-presets'],
    queryFn: getCloudPresets,
  });

  const cloudSettingsQuery = useQuery<CloudSettings | null>({
    queryKey: ['cloud-settings'],
    queryFn: getCloudSettings,
  });

  const createBackupMutation = useMutation({
    mutationFn: createBackup,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['backups'] }),
  });

  const deleteBackupMutation = useMutation({
    mutationFn: (filename: string) => deleteBackup(filename),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['backups'] }),
  });

  const saveCloudSettingsMutation = useMutation({
    mutationFn: (settings: CloudSettings) => saveCloudSettings(settings),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['cloud-settings'] }),
  });

  const testConnectionMutation = useMutation({
    mutationFn: (settings: CloudSettings) => testCloudConnection(settings),
  });

  const uploadToCloudMutation = useMutation({
    mutationFn: (filename: string) => uploadToCloud(filename),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['backups'] }),
  });

  const restoreBackupMutation = useMutation({
    mutationFn: ({ filename, strategy }: { filename: string; strategy: 'keep_newer' | 'use_backup' | 'keep_local' }) =>
      restoreBackup(filename, strategy),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['backups'] }),
  });

  const authorizeCloudProviderMutation = useMutation({
    mutationFn: ({ provider, clientId }: { provider: string; clientId: string }) =>
      authorizeCloudProvider(provider, clientId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['cloud-settings'] });
    },
  });

  const autoBackupSettingsQuery = useQuery<AutoBackupSettings>({
    queryKey: ['auto-backup-settings'],
    queryFn: getAutoBackupSettings,
  });

  const updateAutoBackupSettingsMutation = useMutation({
    mutationFn: ({ enabled, intervalHours }: { enabled: boolean; intervalHours: number }) =>
      updateAutoBackupSettings(enabled, intervalHours),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['auto-backup-settings'] }),
  });

  return {
    backups: backupsQuery.data ?? [],
    isLoadingBackups: backupsQuery.isLoading,
    cloudPresets: cloudPresetsQuery.data ?? [],
    cloudSettings: cloudSettingsQuery.data,
    isLoadingCloudSettings: cloudSettingsQuery.isLoading,
    createBackup: createBackupMutation.mutateAsync,
    isCreatingBackup: createBackupMutation.isPending,
    deleteBackup: deleteBackupMutation.mutateAsync,
    isDeletingBackup: deleteBackupMutation.isPending,
    saveCloudSettings: saveCloudSettingsMutation.mutateAsync,
    isSavingCloudSettings: saveCloudSettingsMutation.isPending,
    testConnection: testConnectionMutation.mutateAsync,
    isTestingConnection: testConnectionMutation.isPending,
    uploadToCloud: uploadToCloudMutation.mutateAsync,
    isUploading: uploadToCloudMutation.isPending,
    restoreBackup: restoreBackupMutation.mutateAsync,
    isRestoringBackup: restoreBackupMutation.isPending,
    authorizeCloudProvider: authorizeCloudProviderMutation.mutateAsync,
    isAuthorizing: authorizeCloudProviderMutation.isPending,
    autoBackupSettings: autoBackupSettingsQuery.data,
    isLoadingAutoBackupSettings: autoBackupSettingsQuery.isLoading,
    updateAutoBackupSettings: updateAutoBackupSettingsMutation.mutateAsync,
    isUpdatingAutoBackupSettings: updateAutoBackupSettingsMutation.isPending,
  };
}
