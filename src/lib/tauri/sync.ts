import { invokeTauri } from '../tauri';

export interface SyncSettings {
  enabled: boolean;
  interval_minutes: number;
}

export async function updateSyncSettings(
  enabled: boolean,
  intervalMinutes: number
): Promise<SyncSettings> {
  return invokeTauri<SyncSettings>('update_sync_settings', {
    enabled,
    interval_minutes: intervalMinutes,
  });
}

export async function getSyncSettings(): Promise<SyncSettings> {
  return invokeTauri<SyncSettings>('get_sync_settings');
}
