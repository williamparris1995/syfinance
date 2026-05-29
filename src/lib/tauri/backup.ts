import { invokeTauri } from '../tauri';

export interface BackupInfo {
  filename: string;
  file_size: number;
  created_at: string;
  metadata: {
    device_id: string;
    account_count: number;
    transaction_count: number;
    debt_count: number;
    goal_count: number;
    budget_count: number;
    tag_count: number;
  } | null;
  on_cloud: boolean;
}

export interface BackupFile {
  version: string;
  encrypted: boolean;
  compressed: boolean;
  salt: string;
  data: string;
  created_at: string;
  checksum: string;
  metadata: BackupInfo['metadata'];
}

export interface DiffSummary {
  accounts: TableDiff;
  transactions: TableDiff;
  debts: TableDiff;
  goals: TableDiff;
  budgets: TableDiff;
  tags: TableDiff;
}

export interface TableDiff {
  local_count: number;
  backup_count: number;
  added: number;
  removed: number;
  modified: number;
}

export interface CloudPreset {
  id: string;
  name: string;
  protocol: string;
  default_server: string;
  default_port: number;
  use_https: boolean;
  auth_type: string;
}

export interface CloudSettings {
  provider: string;
  server_url?: string;
  port?: number;
  username?: string;
  password?: string;
  remote_path?: string;
  access_token?: string;
  refresh_token?: string;
  auto_upload?: string;
  enabled?: boolean;
}

export interface CloudBackupInfo {
  name: string;
  size: number;
  last_modified: string | null;
}

export const createBackup = () =>
  invokeTauri<BackupInfo>('create_backup');

export const listBackups = () =>
  invokeTauri<BackupInfo[]>('list_backups');

export const getBackupMetadata = (filename: string) =>
  invokeTauri<BackupFile>('get_backup_metadata', { filename });

export const getBackupDiff = (filename: string) =>
  invokeTauri<DiffSummary>('get_backup_diff', { filename });

export const deleteBackup = (filename: string) =>
  invokeTauri<void>('delete_backup', { filename });

export const getCloudPresets = () =>
  invokeTauri<CloudPreset[]>('get_cloud_presets');

export const getCloudSettings = () =>
  invokeTauri<CloudSettings | null>('get_cloud_settings');

export const saveCloudSettings = (settings: CloudSettings) =>
  invokeTauri<void>('save_cloud_settings', { settings });

export const testCloudConnection = (settings: CloudSettings) =>
  invokeTauri<void>('test_cloud_connection', { settings });

export const uploadToCloud = (filename: string) =>
  invokeTauri<void>('upload_to_cloud', { filename });

export const listCloudBackups = () =>
  invokeTauri<CloudBackupInfo[]>('list_cloud_backups');
