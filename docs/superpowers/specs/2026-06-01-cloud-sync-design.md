> **⚠️ CANCELLED — 2026-07-25**: 多设备同步(multi-device sync)已下架。御财 server+Postgres 已集中持久化数据,client 直连服务器读写,无需额外多端同步。云备份亦同时取消。本功能从未实现,本文档保留作历史/决策记录。

# Cloud Sync (Backup-Based) Design Spec

**Date:** 2026-06-01
**Status:** Draft
**Depends on:** BackupService (complete), CloudProvider (complete)

---

## Goal

Replace the broken SyncScheduler (pushes empty data through localhost REST API) with a working cloud sync system that:

1. Periodically creates a backup and uploads to the configured cloud provider
2. Detects newer backups on the cloud and downloads + restores them (using `keep_newer` strategy)
3. Persists sync settings to SQLite (not just in-memory)
4. Provides a frontend status indicator and manual sync trigger
5. Preserves existing SyncService / SyncScheduler code for future entity-level sync

---

## Architecture

```
main.rs (setup)
  └─ tokio::spawn(cloud_sync_scheduler.start())

CloudSyncScheduler (定时触发)
  └─ CloudSyncService (核心逻辑)
       ├─ BackupService::create_backup()   → 本地备份
       ├─ CloudProvider::upload()          → 上传到云端
       ├─ CloudProvider::list_backups()    → 检查云端更新
       ├─ CloudProvider::download()        → 下载新备份
       └─ BackupService::restore_backup()  → 增量恢复
```

No new REST API endpoints. The scheduler runs entirely within the Tauri process. Frontend communicates via Tauri IPC commands.

---

## New Files

| File | Responsibility |
|------|---------------|
| `src-tauri/src/infrastructure/sync/cloud_sync_service.rs` | Backup→upload, download→restore, status tracking |
| `src-tauri/src/infrastructure/sync/cloud_sync_scheduler.rs` | Periodic trigger with exponential backoff |
| `src-tauri/migrations/20260602000001_cloud_sync_settings.sql` | Settings persistence table |
| `src-tauri/src/presentation/tauri_commands/cloud_sync_commands.rs` | Tauri IPC commands |
| `src/lib/tauri/cloudSync.ts` | Frontend API client |
| `src/hooks/useCloudSync.ts` | React Query hook |
| `src/components/CloudSyncStatus.tsx` | Status indicator component |

## Modified Files

| File | Change |
|------|--------|
| `src-tauri/src/infrastructure/sync/mod.rs` | Add `cloud_sync_service` and `cloud_sync_scheduler` modules |
| `src-tauri/src/presentation/tauri_commands/mod.rs` | Add `cloud_sync_commands` module |
| `src-tauri/src/main.rs` | Create CloudSyncScheduler, pass to CloudSyncCommandState, start in `.setup()` |
| `src/pages/SettingsPage.tsx` | Add cloud sync status section |
| `src/i18n/locales/en.json` | Add cloud sync i18n keys |
| `src/i18n/locales/zh.json` | Add cloud sync i18n keys |

---

## Data Model

### `cloud_sync_settings` table

```sql
CREATE TABLE IF NOT EXISTS cloud_sync_settings (
    id INTEGER PRIMARY KEY CHECK (id = 1),  -- singleton row
    auto_sync_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    interval_minutes INTEGER NOT NULL DEFAULT 30,
    last_sync_at TEXT,
    last_sync_status TEXT,  -- 'success' | 'error' | 'syncing'
    last_error TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

Single-row table (enforced by `CHECK (id = 1)`). Read on startup, updated after each sync attempt.

### Rust types

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CloudSyncSettings {
    pub auto_sync_enabled: bool,
    pub interval_minutes: u64,   // minimum 5
    pub last_sync_at: Option<String>,
    pub last_sync_status: Option<String>,
    pub last_error: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CloudSyncStatus {
    pub enabled: bool,
    pub cloud_configured: bool,
    pub last_sync_at: Option<String>,
    pub last_status: Option<String>,
    pub last_error: Option<String>,
    pub next_sync_at: Option<String>,
    pub is_syncing: bool,
}
```

---

## CloudSyncService

Location: `src-tauri/src/infrastructure/sync/cloud_sync_service.rs`

### Dependencies

```rust
pub struct CloudSyncService {
    pool: SqlitePool,
    backup_dir: PathBuf,
    encryption_state: Arc<EncryptionAppService>,
}
```

Uses the same pool, backup dir, and encryption state as `BackupCommandState`.

### Methods

#### `sync_to_cloud() -> Result<(), CloudSyncError>`

1. Read cloud settings from `cloud_settings` table (already exists from backup module). If no provider configured, return `NotConfigured`.
2. Instantiate the configured `CloudProvider` from settings.
3. Call `BackupService::create_backup(encryption_service)` to create a local backup.
4. Call `CloudProvider::upload(local_path, remote_name)` with the backup filename.
5. Update `cloud_sync_settings`: set `last_sync_at = now`, `last_sync_status = 'success'`.
6. Emit Tauri event `sync:cloud-status` with `SyncEvent::Completed`.
7. Clean up local backups older than 7 days (keep the latest 3).

#### `sync_from_cloud() -> Result<Option<RestoreResult>, CloudSyncError>`

1. Read cloud settings. If no provider configured, return `NotConfigured`.
2. Read `last_sync_at` from `cloud_sync_settings`.
3. Call `CloudProvider::list_backups()` to get remote backup list.
4. Find the newest remote backup that is newer than `last_sync_at`. If none found, return `Ok(None)`.
5. Call `CloudProvider::download(remote_name, local_path)` to download.
6. Call `BackupService::restore_backup(&backup_data, "keep_newer")` to restore.
7. Update `cloud_sync_settings`: set `last_sync_at`, `last_sync_status = 'success'`.
8. Emit Tauri event `sync:cloud-status` with `SyncEvent::Completed`.
9. Return `Ok(Some(result))`.

#### `perform_sync() -> Result<CloudSyncResult, CloudSyncError>`

Convenience method that runs both:

```rust
pub async fn perform_sync(&self) -> Result<CloudSyncResult, CloudSyncError> {
    self.sync_to_cloud().await?;
    match self.sync_from_cloud().await {
        Ok(Some(restore)) => Ok(CloudSyncResult { restored: true, restore }),
        Ok(None) => Ok(CloudSyncResult { restored: false, restore: None }),
        Err(e) => {
            // Upload succeeded but download failed — log but don't fail
            tracing::warn!(error = %e, "Cloud download failed after successful upload");
            Ok(CloudSyncResult { restored: false, restore: None })
        }
    }
}
```

#### `get_status() -> CloudSyncStatus`

Reads `cloud_sync_settings` and `cloud_settings` tables to assemble the current status.

#### `update_settings(settings: CloudSyncSettings)`

Writes settings to `cloud_sync_settings` table.

### Error type

```rust
#[derive(Debug, thiserror::Error)]
pub enum CloudSyncError {
    #[error("cloud storage not configured")]
    NotConfigured,
    #[error("backup failed: {0}")]
    BackupFailed(#[from] BackupError),
    #[error("cloud provider error: {0}")]
    CloudError(#[from] CloudError),
    #[error("database error: {0}")]
    Database(String),
    #[error("encryption locked")]
    EncryptionLocked,
}
```

---

## CloudSyncScheduler

Location: `src-tauri/src/infrastructure/sync/cloud_sync_scheduler.rs`

### Design

```rust
pub struct CloudSyncScheduler {
    app_handle: tauri::AppHandle,
    service: Arc<CloudSyncService>,
    settings: Arc<RwLock<CloudSyncSettings>>,
    is_running: Arc<AtomicBool>,
}
```

### Behavior

1. `start()` spawns a `tokio::spawn` loop.
2. On each iteration:
   - If `auto_sync_enabled` is false, sleep 60 seconds and re-check.
   - If enabled, check if a cloud provider is configured. If not, sleep 60 seconds.
   - Otherwise, call `service.perform_sync()`.
   - On success: sleep for `interval_minutes`.
   - On failure: exponential backoff (2s, 4s, 8s, 16s, max 5 minutes), then retry.
   - After each attempt, emit `sync:cloud-status` Tauri event.
3. `stop()` sets `is_running` to false.
4. `trigger_now()` is a oneshot channel that wakes the scheduler immediately (for manual sync).

### Event payload

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CloudSyncEvent {
    pub status: String,  // "started" | "completed" | "failed"
    pub message: String,
    pub error: Option<String>,
}
```

---

## Tauri Commands

Location: `src-tauri/src/presentation/tauri_commands/cloud_sync_commands.rs`

### State

```rust
#[derive(Clone)]
pub struct CloudSyncCommandState {
    service: Arc<CloudSyncService>,
    scheduler: Arc<RwLock<Option<Arc<CloudSyncScheduler>>>>,
}
```

### Commands

| Command | Signature | Description |
|---------|-----------|-------------|
| `cloud_sync_now` | `() -> Result<CloudSyncResult, String>` | Manual sync trigger |
| `get_cloud_sync_status` | `() -> Result<CloudSyncStatus, String>` | Get current status |
| `update_cloud_sync_settings` | `(settings: CloudSyncSettings) -> Result<(), String>` | Update settings |
| `get_cloud_sync_settings` | `() -> Result<CloudSyncSettings, String>` | Get settings |

`cloud_sync_now` calls `scheduler.trigger_now()` and waits for the result.

---

## Frontend

### API client (`src/lib/tauri/cloudSync.ts`)

```typescript
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
  next_sync_at: string | null;
  is_syncing: boolean;
}

export interface CloudSyncResult {
  restored: boolean;
}

export const cloudSyncNow = () => invokeTauri<CloudSyncResult>('cloud_sync_now');
export const getCloudSyncStatus = () => invokeTauri<CloudSyncStatus>('get_cloud_sync_status');
export const updateCloudSyncSettings = (settings: CloudSyncSettings) =>
  invokeTauri<void>('update_cloud_sync_settings', { settings });
export const getCloudSyncSettings = () => invokeTauri<CloudSyncSettings>('get_cloud_sync_settings');
```

### Hook (`src/hooks/useCloudSync.ts`)

```typescript
export function useCloudSyncStatus() {
  return useQuery({ queryKey: ['cloudSyncStatus'], queryFn: getCloudSyncStatus, staleTime: 30_000 });
}

export function useCloudSyncNow() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: cloudSyncNow,
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['cloudSyncStatus'] }); },
  });
}
```

### Component (`src/components/CloudSyncStatus.tsx`)

Compact status indicator for the Settings page:
- Icon: Cloud / CloudOff / RefreshCw (spinning when syncing) / AlertCircle (error)
- Text: "Last synced 5 min ago" / "Syncing..." / "Not configured" / "Sync failed: ..."
- Button: "Sync now" (disabled when syncing or not configured)
- Toggle: "Auto sync" switch
- Interval selector: 15 / 30 / 60 minutes

---

## main.rs Integration

In `.setup()` closure, after existing schedulers:

```rust
// Cloud sync scheduler
let cloud_sync_service = Arc::new(CloudSyncService::new(
    pool.clone(),
    backup_dir.clone(),
    encryption_state.clone(),
));
let cloud_sync_scheduler = Arc::new(CloudSyncScheduler::new(
    app_handle.clone(),
    cloud_sync_service.clone(),
));
cloud_sync_scheduler.start();
```

Register `CloudSyncCommandState` via `.manage()` and add commands to `.invoke_handler()`.

---

## Settings Page Integration

Add a "Cloud Sync" section to SettingsPage below the existing backup section:

```
┌──────────────────────────────────────────┐
│ ☁️ Cloud Sync                            │
├──────────────────────────────────────────┤
│ Status: ● Synced (5 min ago)            │
│                                          │
│ [Auto Sync ◻]  Interval: [30 min ▾]     │
│                                          │
│ [Sync Now]                               │
└──────────────────────────────────────────┘
```

Visible only when cloud storage is configured (check `cloud_configured` from status).

---

## Edge Cases

1. **No cloud provider configured**: Scheduler skips sync, status shows "Not configured".
2. **Encryption locked**: `sync_to_cloud` creates unencrypted backup. `sync_from_cloud` returns error if backup is encrypted and encryption is locked.
3. **Concurrent sync**: Use `AtomicBool` flag to prevent overlapping sync operations.
4. **Large backup on slow connection**: Upload timeout handled by CloudProvider implementation.
5. **Device ID mismatch on restore**: The `keep_newer` strategy handles this correctly — newer timestamps win regardless of device.
6. **First sync (no cloud backups)**: `sync_from_cloud` returns `Ok(None)`, only upload runs.

---

## Testing Strategy

- **Unit tests**: CloudSyncService with mocked BackupService and CloudProvider
- **Integration test**: Full sync cycle with in-memory SQLite and a mock cloud provider
- **Manual test**: Configure WebDAV, verify backup appears on cloud, verify restore on second device

---

## Future Considerations

- Entity-level sync (using existing SyncService) for real-time multi-device sync
- Bandwidth throttling for large backups
- Differential backups (only upload changed records)
- Notification on sync failure
