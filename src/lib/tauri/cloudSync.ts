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

export const cloudSyncNow = () =>
  invokeTauri<CloudSyncResult>('cloud_sync_now');

export const getCloudSyncStatus = () =>
  invokeTauri<CloudSyncStatus>('get_cloud_sync_status');

export const updateCloudSyncSettings = (settings: CloudSyncSettings) =>
  invokeTauri<void>('update_cloud_sync_settings', { settings });

export const getCloudSyncSettings = () =>
  invokeTauri<CloudSyncSettings>('get_cloud_sync_settings');
