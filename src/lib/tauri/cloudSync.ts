import { invokeTauri } from '../tauri';

export interface CloudSyncSettings {
  auto_sync_enabled: boolean;
  interval_minutes: number;
  last_sync_at: string | null;
  last_sync_status: string | null;
  last_error: string | null;
}

export interface CloudSyncStatus {
  enabled: boolean;
  cloud_configured: boolean;
  last_sync_at: string | null;
  last_status: string | null;
  last_error: string | null;
  is_syncing: boolean;
}

export interface CloudSyncResult {
  uploaded: boolean;
  restored: boolean;
}

export interface SyncConflictItem {
  table_name: string;
  record_id: string;
  local_updated_at: string | null;
  remote_updated_at: string | null;
  local_data: Record<string, unknown>;
  remote_data: Record<string, unknown>;
}

export interface SyncStatusWithConflicts {
  last_sync_at: string | null;
  last_status: string | null;
  is_syncing: boolean;
  conflicts: SyncConflictItem[];
}

export const cloudSyncNow = () =>
  invokeTauri<CloudSyncResult>('cloud_sync_now');

export const getCloudSyncStatus = () =>
  invokeTauri<CloudSyncStatus>('get_cloud_sync_status');

export const updateCloudSyncSettings = (settings: CloudSyncSettings) =>
  invokeTauri<void>('update_cloud_sync_settings', { settings });

export const getCloudSyncSettings = () =>
  invokeTauri<CloudSyncSettings>('get_cloud_sync_settings');

export const getSyncStatusWithConflicts = () =>
  invokeTauri<SyncStatusWithConflicts>('get_sync_status_with_conflicts');

export const resolveSyncConflict = (
  tableName: string,
  recordId: string,
  resolution: string,
) =>
  invokeTauri<void>('resolve_sync_conflict', {
    tableName,
    recordId,
    resolution,
  });
