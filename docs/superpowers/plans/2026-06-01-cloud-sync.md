# Cloud Sync (Backup-Based) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken SyncScheduler with a working backup-based cloud sync system that periodically creates backups and uploads to the configured cloud provider, and downloads/restores newer backups from the cloud.

**Architecture:** New CloudSyncService wraps existing BackupService + CloudProvider for backup→upload and download→restore operations. CloudSyncScheduler provides periodic triggering with exponential backoff. Settings persist to a new `cloud_sync_settings` SQLite table. Frontend communicates via Tauri IPC commands.

**Tech Stack:** Rust (sqlx, serde, tracing, tauri), TypeScript (React, TanStack React Query, i18next)

**Design spec:** `docs/superpowers/specs/2026-06-01-cloud-sync-design.md`

---

## File Structure

### New files

| File | Responsibility |
|------|---------------|
| `src-tauri/migrations/20260602000001_cloud_sync_settings.sql` | Settings persistence table |
| `src-tauri/src/infrastructure/sync/cloud_sync_service.rs` | Core sync logic: backup→upload, download→restore |
| `src-tauri/src/infrastructure/sync/cloud_sync_scheduler.rs` | Periodic trigger with exponential backoff |
| `src-tauri/src/presentation/tauri_commands/cloud_sync_commands.rs` | Tauri IPC commands |
| `src/lib/tauri/cloudSync.ts` | Frontend API client |
| `src/hooks/useCloudSync.ts` | React Query hook |

### Modified files

| File | Change |
|------|--------|
| `src-tauri/src/infrastructure/sync/mod.rs` | Add cloud_sync_service and cloud_sync_scheduler modules |
| `src-tauri/src/infrastructure/backup/mod.rs` | Add shared `build_cloud_provider` helper |
| `src-tauri/src/presentation/tauri_commands/mod.rs` | Add cloud_sync_commands module |
| `src-tauri/src/main.rs` | Create CloudSyncCommandState, start CloudSyncScheduler |
| `src/pages/SettingsPage.tsx` | Add Cloud Sync status section |
| `src/i18n/locales/en.json` | Add cloud sync i18n keys |
| `src/i18n/locales/zh.json` | Add cloud sync i18n keys |

---

### Task 1: Create cloud_sync_settings migration

**Files:**
- Create: `src-tauri/migrations/20260602000001_cloud_sync_settings.sql`

- [ ] **Step 1: Create migration file**

```sql
-- src-tauri/migrations/20260602000001_cloud_sync_settings.sql
-- Cloud sync settings (singleton row)
CREATE TABLE IF NOT EXISTS cloud_sync_settings (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    auto_sync_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    interval_minutes INTEGER NOT NULL DEFAULT 30,
    last_sync_at TEXT,
    last_sync_status TEXT,
    last_error TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Seed the singleton row
INSERT OR IGNORE INTO cloud_sync_settings (id, auto_sync_enabled, interval_minutes)
VALUES (1, FALSE, 30);
```

- [ ] **Step 2: Verify migration runs**

Run: `cd src-tauri && cargo build`
Expected: Build succeeds, migration applied on next app launch

- [ ] **Step 3: Commit**

```bash
git add src-tauri/migrations/20260602000001_cloud_sync_settings.sql
git commit -m "feat(cloud-sync): add cloud_sync_settings migration"
```

---

### Task 2: Add shared cloud provider builder

**Files:**
- Modify: `src-tauri/src/infrastructure/backup/mod.rs`

The `build_webdav_provider` helper in backup_commands.rs is private. We need a shared version for both backup_commands and CloudSyncService.

- [ ] **Step 1: Add `build_cloud_provider` to `backup/mod.rs`**

Append to `src-tauri/src/infrastructure/backup/mod.rs`:

```rust
use crate::infrastructure::backup::cloud_provider::CloudSettings;

/// Build a CloudProvider from saved cloud settings.
///
/// Currently supports WebDAV-based providers only (webdav, nextcloud, synology, jianguoyun, box).
/// Returns `Err(CloudError::NotConfigured)` for unsupported provider types.
pub fn build_cloud_provider(settings: &CloudSettings) -> Result<Box<dyn CloudProvider>, CloudError> {
    match settings.provider.as_str() {
        "webdav" | "nextcloud" | "synology" | "jianguoyun" | "box" => {
            let base_url = settings
                .server_url
                .clone()
                .ok_or(CloudError::NotConfigured)?;
            let username = settings
                .username
                .clone()
                .ok_or(CloudError::NotConfigured)?;
            let password = settings
                .password
                .clone()
                .ok_or(CloudError::NotConfigured)?;
            let remote_path = settings
                .remote_path
                .clone()
                .unwrap_or_else(|| "backups".to_string());

            Ok(Box::new(webdav_provider::WebDavProvider::new(
                base_url,
                username,
                password,
                remote_path,
            )))
        }
        _ => Err(CloudError::NotConfigured),
    }
}
```

Note: This function needs `CloudSettings` to be a shared type. Currently `CloudSettings` is defined in `backup_commands.rs`. We need to move it to a shared location. Add the struct to `cloud_provider.rs` instead.

- [ ] **Step 2: Move `CloudSettings` to `cloud_provider.rs`**

In `src-tauri/src/infrastructure/backup/cloud_provider.rs`, add before the `get_presets()` function:

```rust
/// Persisted cloud storage configuration.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CloudSettings {
    pub provider: String,
    pub server_url: Option<String>,
    pub port: Option<i64>,
    pub username: Option<String>,
    pub password: Option<String>,
    pub remote_path: Option<String>,
    pub access_token: Option<String>,
    pub refresh_token: Option<String>,
    pub auto_upload: Option<String>,
    pub enabled: Option<bool>,
}
```

- [ ] **Step 3: Update `cloud_provider.rs` exports**

In `src-tauri/src/infrastructure/backup/cloud_provider.rs`, ensure the struct is public (it already is with `pub`).

- [ ] **Step 4: Update `backup/mod.rs` re-exports**

Change the `pub use` line in `src-tauri/src/infrastructure/backup/mod.rs`:

```rust
pub use cloud_provider::{CloudBackupInfo, CloudError, CloudProvider, CloudSettings};
```

- [ ] **Step 5: Update `backup_commands.rs` to use shared `CloudSettings`**

In `src-tauri/src/presentation/tauri_commands/backup_commands.rs`:

Remove the local `CloudSettings` struct definition (lines 44-56). Add import:

```rust
use crate::infrastructure::backup::cloud_provider::CloudSettings;
```

Remove the local `use crate::infrastructure::backup::cloud_provider::{CloudBackupInfo, CloudPreset, CloudProvider};` and replace with:

```rust
use crate::infrastructure::backup::cloud_provider::{
    CloudBackupInfo, CloudPreset, CloudProvider, CloudSettings,
};
```

- [ ] **Step 6: Verify compilation**

Run: `cd src-tauri && cargo check`
Expected: Compiles successfully

- [ ] **Step 7: Commit**

```bash
git add src-tauri/src/infrastructure/backup/mod.rs src-tauri/src/infrastructure/backup/cloud_provider.rs src-tauri/src/presentation/tauri_commands/backup_commands.rs
git commit -m "refactor(backup): extract CloudSettings and build_cloud_provider for shared use"
```

---

### Task 3: Create CloudSyncService

**Files:**
- Create: `src-tauri/src/infrastructure/sync/cloud_sync_service.rs`
- Modify: `src-tauri/src/infrastructure/sync/mod.rs`

- [ ] **Step 1: Create CloudSyncService**

Create `src-tauri/src/infrastructure/sync/cloud_sync_service.rs`:

```rust
use std::fs;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;
use tracing::{error, info, warn};

use crate::application::services::EncryptionAppService;
use crate::infrastructure::backup::backup_service::{
    BackupFile, BackupInfo, BackupService,
};
use crate::infrastructure::backup::cloud_provider::CloudError;
use crate::infrastructure::backup::{build_cloud_provider, CloudSettings};

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Persisted cloud sync settings (stored in cloud_sync_settings table).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CloudSyncSettings {
    pub auto_sync_enabled: bool,
    pub interval_minutes: u64,
    pub last_sync_at: Option<String>,
    pub last_sync_status: Option<String>,
    pub last_error: Option<String>,
}

impl Default for CloudSyncSettings {
    fn default() -> Self {
        Self {
            auto_sync_enabled: false,
            interval_minutes: 30,
            last_sync_at: None,
            last_sync_status: None,
            last_error: None,
        }
    }
}

/// Current cloud sync status (returned to frontend).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CloudSyncStatus {
    pub enabled: bool,
    pub cloud_configured: bool,
    pub last_sync_at: Option<String>,
    pub last_status: Option<String>,
    pub last_error: Option<String>,
    pub is_syncing: bool,
}

/// Result of a cloud sync operation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CloudSyncResult {
    pub uploaded: bool,
    pub restored: bool,
}

// ---------------------------------------------------------------------------
// Error type
// ---------------------------------------------------------------------------

#[derive(Debug, thiserror::Error)]
pub enum CloudSyncError {
    #[error("cloud storage not configured")]
    NotConfigured,
    #[error("sync already in progress")]
    AlreadySyncing,
    #[error("encryption is locked - unlock to restore encrypted backups")]
    EncryptionLocked,
    #[error("backup error: {0}")]
    Backup(#[from] crate::infrastructure::backup::backup_service::BackupError),
    #[error("cloud error: {0}")]
    Cloud(#[from] CloudError),
    #[error("database error: {0}")]
    Database(String),
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
}

// ---------------------------------------------------------------------------
// CloudSyncService
// ---------------------------------------------------------------------------

pub struct CloudSyncService {
    pool: SqlitePool,
    backup_dir: PathBuf,
    encryption_state: Arc<EncryptionAppService>,
    is_syncing: AtomicBool,
}

impl CloudSyncService {
    pub fn new(
        pool: SqlitePool,
        backup_dir: PathBuf,
        encryption_state: Arc<EncryptionAppService>,
    ) -> Self {
        Self {
            pool,
            backup_dir,
            encryption_state,
            is_syncing: AtomicBool::new(false),
        }
    }

    // ----- public API -------------------------------------------------------

    /// Perform a full cloud sync: upload backup, then download and restore
    /// newer remote backups.
    pub async fn perform_sync(&self) -> Result<CloudSyncResult, CloudSyncError> {
        // Prevent concurrent syncs
        if self
            .is_syncing
            .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
            .is_err()
        {
            return Err(CloudSyncError::AlreadySyncing);
        }

        let result = self.do_sync().await;

        self.is_syncing.store(false, Ordering::SeqCst);

        // Update status in database
        match &result {
            Ok(sync_result) => {
                self.update_sync_status("success", None).await.ok();
                info!(
                    uploaded = sync_result.uploaded,
                    restored = sync_result.restored,
                    "Cloud sync completed"
                );
            }
            Err(e) => {
                self.update_sync_status("error", Some(&e.to_string()))
                    .await
                    .ok();
                error!(error = %e, "Cloud sync failed");
            }
        }

        result
    }

    /// Read current cloud sync status from the database.
    pub async fn get_status(&self) -> CloudSyncStatus {
        let cloud_configured = self.get_cloud_settings().await.is_some();
        let settings = self.read_sync_settings().await;

        CloudSyncStatus {
            enabled: settings.auto_sync_enabled,
            cloud_configured,
            last_sync_at: settings.last_sync_at,
            last_status: settings.last_sync_status,
            last_error: settings.last_error,
            is_syncing: self.is_syncing.load(Ordering::SeqCst),
        }
    }

    /// Update cloud sync settings in the database.
    pub async fn update_settings(
        &self,
        settings: &CloudSyncSettings,
    ) -> Result<(), CloudSyncError> {
        let interval = settings.interval_minutes.max(5);
        sqlx::query(
            "UPDATE cloud_sync_settings SET auto_sync_enabled = ?, interval_minutes = ?, updated_at = datetime('now') WHERE id = 1",
        )
        .bind(settings.auto_sync_enabled)
        .bind(interval as i64)
        .execute(&self.pool)
        .await
        .map_err(|e| CloudSyncError::Database(e.to_string()))?;

        Ok(())
    }

    /// Read cloud sync settings from the database.
    pub async fn read_sync_settings(&self) -> CloudSyncSettings {
        let row = sqlx::query_as::<_, (bool, i64, Option<String>, Option<String>, Option<String>)>(
            "SELECT auto_sync_enabled, interval_minutes, last_sync_at, last_sync_status, last_error FROM cloud_sync_settings WHERE id = 1",
        )
        .fetch_optional(&self.pool)
        .await;

        match row {
            Ok(Some(r)) => CloudSyncSettings {
                auto_sync_enabled: r.0,
                interval_minutes: r.1 as u64,
                last_sync_at: r.2,
                last_sync_status: r.3,
                last_error: r.4,
            },
            _ => CloudSyncSettings::default(),
        }
    }

    /// Check if a sync is currently in progress.
    pub fn is_syncing(&self) -> bool {
        self.is_syncing.load(Ordering::SeqCst)
    }

    // ----- internal ---------------------------------------------------------

    async fn do_sync(&self) -> Result<CloudSyncResult, CloudSyncError> {
        let prev_sync_at = self.get_last_sync_at().await?;

        // 1. Upload: create backup and upload to cloud
        self.sync_to_cloud().await?;

        // 2. Download: check for newer remote backups and restore
        let restored = match self.sync_from_cloud(&prev_sync_at).await {
            Ok(r) => r,
            Err(e) => {
                warn!(error = %e, "Cloud download/restore failed after successful upload");
                false
            }
        };

        // 3. Update last_sync_at timestamp
        self.update_last_sync_at().await?;

        // 4. Cleanup old local backups
        if let Err(e) = self.cleanup_old_backups() {
            warn!(error = %e, "Failed to cleanup old backups");
        }

        Ok(CloudSyncResult {
            uploaded: true,
            restored,
        })
    }

    /// Create a local backup and upload to the configured cloud provider.
    async fn sync_to_cloud(&self) -> Result<(), CloudSyncError> {
        let cloud_settings = self
            .get_cloud_settings()
            .await
            .ok_or(CloudSyncError::NotConfigured)?;

        let provider = build_cloud_provider(&cloud_settings)?;

        // Create backup
        let backup_service =
            BackupService::new(self.pool.clone(), self.backup_dir.clone())?;
        let encryption = self.encryption_state.get_encryption_service();
        let backup_info = backup_service
            .create_backup(encryption.as_ref())
            .await?;

        info!(filename = %backup_info.filename, "Backup created for cloud sync");

        // Upload
        let local_path = self.backup_dir.join(&backup_info.filename);
        provider
            .upload(&local_path, &backup_info.filename)
            .await?;

        info!(filename = %backup_info.filename, "Backup uploaded to cloud");

        Ok(())
    }

    /// Check for newer remote backups, download and restore.
    async fn sync_from_cloud(&self, prev_sync_at: &Option<String>) -> Result<bool, CloudSyncError> {
        let cloud_settings = self
            .get_cloud_settings()
            .await
            .ok_or(CloudSyncError::NotConfigured)?;

        let provider = build_cloud_provider(&cloud_settings)?;

        // List remote backups
        let remote_backups = provider.list_backups().await?;

        // Find the newest remote backup newer than our last sync
        let newer = self.find_newer_remote(&remote_backups, prev_sync_at);

        let Some(remote) = newer else {
            info!("No newer remote backups found");
            return Ok(false);
        };

        info!(name = %remote.name, "Found newer remote backup");

        // Download
        let download_path = self.backup_dir.join(&remote.name);
        provider
            .download(&remote.name, &download_path)
            .await?;

        // Read and parse backup file
        let contents = fs::read_to_string(&download_path)?;
        let backup_file: BackupFile = serde_json::from_str(&contents)?;

        // Decrypt backup data
        let backup_data = if backup_file.encrypted {
            let encryption = self
                .encryption_state
                .get_encryption_service()
                .ok_or(CloudSyncError::EncryptionLocked)?;
            BackupService::decrypt_backup_data(&backup_file, &encryption)
                .map_err(CloudSyncError::Backup)?
        } else {
            BackupService::decrypt_backup_data_no_encryption(&backup_file)
                .map_err(CloudSyncError::Backup)?
        };

        // Restore with keep_newer strategy
        let backup_service =
            BackupService::new(self.pool.clone(), self.backup_dir.clone())?;
        let result = backup_service
            .restore_backup(&backup_data, "keep_newer")
            .await?;

        info!(
            safety_backup = %result.safety_backup,
            "Remote backup restored"
        );

        Ok(true)
    }

    /// Find the newest remote backup that is newer than `prev_sync_at`.
    fn find_newer_remote(
        &self,
        remote_backups: &[crate::infrastructure::backup::cloud_provider::CloudBackupInfo],
        prev_sync_at: &Option<String>,
    ) -> Option<crate::infrastructure::backup::cloud_provider::CloudBackupInfo> {
        let cutoff = prev_sync_at.as_deref().unwrap_or("");

        remote_backups
            .iter()
            .filter(|b| {
                b.last_modified
                    .as_deref()
                    .is_some_and(|m| m > cutoff)
            })
            .max_by(|a, b| {
                let a_time = a.last_modified.as_deref().unwrap_or("");
                let b_time = b.last_modified.as_deref().unwrap_or("");
                a_time.cmp(b_time)
            })
            .cloned()
    }

    // ----- database helpers -------------------------------------------------

    async fn get_cloud_settings(&self) -> Option<CloudSettings> {
        let row = sqlx::query_as::<
            _,
            (
                String,
                Option<String>,
                Option<i64>,
                Option<String>,
                Option<String>,
                Option<String>,
                Option<String>,
                Option<String>,
                Option<String>,
                Option<bool>,
            ),
        >(
            "SELECT provider, server_url, port, username, password, remote_path, \
             access_token, refresh_token, auto_upload, enabled \
             FROM cloud_settings LIMIT 1",
        )
        .fetch_optional(&self.pool)
        .await
        .ok()??;

        Some(CloudSettings {
            provider: row.0,
            server_url: row.1,
            port: row.2,
            username: row.3,
            password: row.4,
            remote_path: row.5,
            access_token: row.6,
            refresh_token: row.7,
            auto_upload: row.8,
            enabled: row.9,
        })
    }

    async fn get_last_sync_at(&self) -> Result<Option<String>, CloudSyncError> {
        let row = sqlx::query_as::<_, (Option<String>,)>(
            "SELECT last_sync_at FROM cloud_sync_settings WHERE id = 1",
        )
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| CloudSyncError::Database(e.to_string()))?;

        Ok(row.map(|r| r.0).flatten())
    }

    async fn update_last_sync_at(&self) -> Result<(), CloudSyncError> {
        sqlx::query(
            "UPDATE cloud_sync_settings SET last_sync_at = datetime('now'), updated_at = datetime('now') WHERE id = 1",
        )
        .execute(&self.pool)
        .await
        .map_err(|e| CloudSyncError::Database(e.to_string()))?;

        Ok(())
    }

    async fn update_sync_status(
        &self,
        status: &str,
        error: Option<&str>,
    ) -> Result<(), CloudSyncError> {
        sqlx::query(
            "UPDATE cloud_sync_settings SET last_sync_status = ?, last_error = ?, updated_at = datetime('now') WHERE id = 1",
        )
        .bind(status)
        .bind(error)
        .execute(&self.pool)
        .await
        .map_err(|e| CloudSyncError::Database(e.to_string()))?;

        Ok(())
    }

    /// Delete local backups older than 7 days, keeping at least the 3 newest.
    fn cleanup_old_backups(&self) -> Result<(), CloudSyncError> {
        let mut backups: Vec<(String, std::time::SystemTime)> = Vec::new();

        for entry in fs::read_dir(&self.backup_dir)? {
            let entry = entry?;
            let path = entry.path();
            if path.extension().is_some_and(|ext| ext == "enc") {
                if let Ok(metadata) = entry.metadata() {
                    if let Ok(modified) = metadata.modified() {
                        if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
                            backups.push((name.to_string(), modified));
                        }
                    }
                }
            }
        }

        // Sort newest first
        backups.sort_by(|a, b| b.1.cmp(&a.1));

        // Keep the 3 newest; delete the rest if older than 7 days
        let seven_days = std::time::Duration::from_secs(7 * 24 * 3600);
        let now = std::time::SystemTime::now();

        for (i, (name, modified)) in backups.iter().enumerate() {
            if i >= 3 {
                if let Ok(age) = now.duration_since(*modified) {
                    if age > seven_days {
                        let path = self.backup_dir.join(name);
                        if let Err(e) = fs::remove_file(&path) {
                            warn!(path = %path.display(), error = %e, "Failed to delete old backup");
                        }
                    }
                }
            }
        }

        Ok(())
    }
}
```

- [ ] **Step 2: Update sync module exports**

Replace the contents of `src-tauri/src/infrastructure/sync/mod.rs`:

```rust
pub mod cloud_sync_scheduler;
pub mod cloud_sync_service;
pub mod sync_scheduler;
pub mod sync_service;

pub use cloud_sync_scheduler::CloudSyncScheduler;
pub use cloud_sync_service::{
    CloudSyncError, CloudSyncResult, CloudSyncService, CloudSyncSettings, CloudSyncStatus,
};
pub use sync_scheduler::{SyncScheduler, SyncSettings};
pub use sync_service::{SyncEntity, SyncError, SyncRepository, SyncService, SyncSummary};
```

- [ ] **Step 3: Verify compilation**

Run: `cd src-tauri && cargo check`
Expected: `cloud_sync_scheduler` module will fail (not yet created). All other errors should be resolved. Proceed to Task 4.

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/infrastructure/sync/cloud_sync_service.rs src-tauri/src/infrastructure/sync/mod.rs
git commit -m "feat(cloud-sync): add CloudSyncService with backup-based sync logic"
```

---

### Task 4: Create CloudSyncScheduler

**Files:**
- Create: `src-tauri/src/infrastructure/sync/cloud_sync_scheduler.rs`

- [ ] **Step 1: Create CloudSyncScheduler**

Create `src-tauri/src/infrastructure/sync/cloud_sync_scheduler.rs`:

```rust
use std::sync::Arc;
use std::time::Duration;

use serde::Serialize;
use tauri::{AppHandle, Emitter};
use tracing::{error, info, warn};

use super::cloud_sync_service::CloudSyncService;

const DEFAULT_INTERVAL_MINUTES: u64 = 30;
const MIN_INTERVAL_MINUTES: u64 = 5;
const DISABLED_CHECK_INTERVAL: Duration = Duration::from_secs(60);

const BACKOFF_DELAYS: [Duration; 4] = [
    Duration::from_secs(2),
    Duration::from_secs(4),
    Duration::from_secs(8),
    Duration::from_secs(16),
];

// ---------------------------------------------------------------------------
// Event types
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize)]
pub struct CloudSyncEvent {
    pub status: String, // "started" | "completed" | "failed"
    pub message: String,
    pub error: Option<String>,
}

// ---------------------------------------------------------------------------
// CloudSyncScheduler
// ---------------------------------------------------------------------------

pub struct CloudSyncScheduler {
    app_handle: AppHandle,
    service: Arc<CloudSyncService>,
}

impl CloudSyncScheduler {
    pub fn new(app_handle: AppHandle, service: Arc<CloudSyncService>) -> Self {
        Self {
            app_handle,
            service,
        }
    }

    /// Start the background scheduler loop.
    pub fn start(self: Arc<Self>) {
        tokio::spawn(async move {
            self.run_scheduler().await;
        });
        info!("Cloud sync scheduler started");
    }

    async fn run_scheduler(&self) {
        let mut backoff_index: usize = 0;

        loop {
            // Read current settings from database
            let settings = self.service.read_sync_settings().await;

            if !settings.auto_sync_enabled {
                tokio::time::sleep(DISABLED_CHECK_INTERVAL).await;
                continue;
            }

            // Check if cloud is configured
            let status = self.service.get_status().await;
            if !status.cloud_configured {
                tokio::time::sleep(DISABLED_CHECK_INTERVAL).await;
                continue;
            }

            // Sleep for configured interval
            let interval = Duration::from_secs(
                (settings.interval_minutes.max(MIN_INTERVAL_MINUTES)) * 60,
            );
            tokio::time::sleep(interval).await;

            // Perform sync
            self.emit_event("started", "Cloud sync started", None);

            match self.service.perform_sync().await {
                Ok(result) => {
                    let msg = format!(
                        "Sync completed (uploaded: {}, restored: {})",
                        result.uploaded, result.restored
                    );
                    self.emit_event("completed", &msg, None);
                    backoff_index = 0;
                }
                Err(e) => {
                    let msg = format!("Cloud sync failed: {e}");
                    error!(error = %e, "Cloud sync failed");
                    self.emit_event("failed", "Sync failed", Some(&e.to_string()));

                    // Exponential backoff
                    let delay = BACKOFF_DELAYS
                        .get(backoff_index)
                        .copied()
                        .unwrap_or(BACKOFF_DELAYS[3]);
                    backoff_index = (backoff_index + 1).min(BACKOFF_DELAYS.len() - 1);
                    tokio::time::sleep(delay).await;
                }
            }
        }
    }

    fn emit_event(&self, status: &str, message: &str, error: Option<&str>) {
        let event = CloudSyncEvent {
            status: status.to_string(),
            message: message.to_string(),
            error: error.map(|s| s.to_string()),
        };
        if let Err(e) = self.app_handle.emit("sync:cloud-status", &event) {
            warn!(error = %e, "Failed to emit cloud sync event");
        }
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd src-tauri && cargo check`
Expected: Compiles successfully

- [ ] **Step 3: Commit**

```bash
git add src-tauri/src/infrastructure/sync/cloud_sync_scheduler.rs
git commit -m "feat(cloud-sync): add CloudSyncScheduler with periodic sync"
```

---

### Task 5: Create Tauri commands and wire in main.rs

**Files:**
- Create: `src-tauri/src/presentation/tauri_commands/cloud_sync_commands.rs`
- Modify: `src-tauri/src/presentation/tauri_commands/mod.rs`
- Modify: `src-tauri/src/main.rs`

- [ ] **Step 1: Create cloud sync commands**

Create `src-tauri/src/presentation/tauri_commands/cloud_sync_commands.rs`:

```rust
use std::sync::Arc;

use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;
use std::path::PathBuf;

use crate::application::services::EncryptionAppService;
use crate::infrastructure::sync::cloud_sync_service::{
    CloudSyncResult, CloudSyncService, CloudSyncSettings, CloudSyncStatus,
};

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

#[derive(Clone)]
pub struct CloudSyncCommandState {
    service: Arc<CloudSyncService>,
}

impl CloudSyncCommandState {
    pub fn new(
        pool: SqlitePool,
        backup_dir: PathBuf,
        encryption_state: Arc<EncryptionAppService>,
    ) -> Self {
        Self {
            service: Arc::new(CloudSyncService::new(pool, backup_dir, encryption_state)),
        }
    }
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

#[tauri::command]
pub async fn cloud_sync_now(
    state: tauri::State<'_, CloudSyncCommandState>,
) -> Result<CloudSyncResult, String> {
    state
        .service
        .perform_sync()
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn get_cloud_sync_status(
    state: tauri::State<'_, CloudSyncCommandState>,
) -> Result<CloudSyncStatus, String> {
    Ok(state.service.get_status().await)
}

#[tauri::command]
pub async fn update_cloud_sync_settings(
    state: tauri::State<'_, CloudSyncCommandState>,
    settings: CloudSyncSettings,
) -> Result<(), String> {
    state
        .service
        .update_settings(&settings)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn get_cloud_sync_settings(
    state: tauri::State<'_, CloudSyncCommandState>,
) -> Result<CloudSyncSettings, String> {
    Ok(state.service.read_sync_settings().await)
}

/// Factory for main.rs state creation.
pub fn create_cloud_sync_state(
    pool: SqlitePool,
    backup_dir: PathBuf,
    encryption_state: Arc<EncryptionAppService>,
) -> CloudSyncCommandState {
    CloudSyncCommandState::new(pool, backup_dir, encryption_state)
}
```

- [ ] **Step 2: Update tauri_commands/mod.rs**

In `src-tauri/src/presentation/tauri_commands/mod.rs`, add the module declaration alongside the existing ones:

```rust
pub mod cloud_sync_commands;
```

And add the re-exports:

```rust
pub use cloud_sync_commands::{
    create_cloud_sync_state, cloud_sync_now, get_cloud_sync_status,
    update_cloud_sync_settings, get_cloud_sync_settings, CloudSyncCommandState,
};
```

- [ ] **Step 3: Wire in main.rs**

In `src-tauri/src/main.rs`, after the `backup_state` creation (line 194), add:

```rust
    let cloud_sync_state = create_cloud_sync_state(
        pool.clone(),
        app_dir.join("backups"),
        encryption_state.service.clone(),
    );
```

In the `.manage()` block (after line 223 `.manage(backup_state)`), add:

```rust
        .manage(cloud_sync_state)
```

In the `generate_handler![]` macro (after line 313 `get_sync_settings`), add:

```rust
            cloud_sync_now,
            get_cloud_sync_status,
            update_cloud_sync_settings,
            get_cloud_sync_settings,
```

In the `.setup()` closure, after the subscription scheduler (after line 364 `info!("Subscription scheduler started...");`), add:

```rust
            // Start cloud sync scheduler
            let cloud_sync_svc = Arc::new(
                crate::infrastructure::sync::cloud_sync_service::CloudSyncService::new(
                    pool.clone(),
                    app_dir.join("backups"),
                    encryption_state.service.clone(),
                )
            );
            let cloud_sync_scheduler = Arc::new(
                crate::infrastructure::sync::cloud_sync_scheduler::CloudSyncScheduler::new(
                    app.handle().clone(),
                    cloud_sync_svc,
                )
            );
            cloud_sync_scheduler.start();
```

Note: The CloudSyncScheduler creates its own CloudSyncService for the background loop, separate from the one in CloudSyncCommandState. Both share the same pool/backup_dir/encryption_state. The `is_syncing` AtomicBool is per-service instance, so manual sync (via command state) and automatic sync (via scheduler) won't conflict — each has its own flag. This is acceptable since the pool-level database transactions handle concurrency.

- [ ] **Step 4: Verify compilation**

Run: `cd src-tauri && cargo check`
Expected: Compiles successfully

- [ ] **Step 5: Commit**

```bash
git add src-tauri/src/presentation/tauri_commands/cloud_sync_commands.rs src-tauri/src/presentation/tauri_commands/mod.rs src-tauri/src/main.rs
git commit -m "feat(cloud-sync): add Tauri commands and wire into main.rs"
```

---

### Task 6: Create frontend API client and hook

**Files:**
- Create: `src/lib/tauri/cloudSync.ts`
- Create: `src/hooks/useCloudSync.ts`

- [ ] **Step 1: Create frontend API client**

Create `src/lib/tauri/cloudSync.ts`:

```typescript
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
```

- [ ] **Step 2: Create React Query hook**

Create `src/hooks/useCloudSync.ts`:

```typescript
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
```

- [ ] **Step 3: Verify type check**

Run: `pnpm type-check`
Expected: Passes (no TypeScript errors in new files; SettingsPage errors from missing i18n keys will be fixed in Task 7)

- [ ] **Step 4: Commit**

```bash
git add src/lib/tauri/cloudSync.ts src/hooks/useCloudSync.ts
git commit -m "feat(cloud-sync): add frontend API client and React Query hooks"
```

---

### Task 7: Update SettingsPage and add i18n keys

**Files:**
- Modify: `src/pages/SettingsPage.tsx`
- Modify: `src/i18n/locales/en.json`
- Modify: `src/i18n/locales/zh.json`

- [ ] **Step 1: Add i18n keys to en.json**

Add a `"cloudSync"` section to `src/i18n/locales/en.json`:

```json
"cloudSync": {
  "title": "Cloud Sync",
  "description": "Automatically backup and sync to your cloud storage",
  "enableAutoSync": "Enable Auto Sync",
  "autoSyncDesc": "Periodically create a backup and upload to cloud",
  "interval": "Sync Interval",
  "every30Minutes": "Every 30 minutes",
  "everyHour": "Every hour",
  "every2Hours": "Every 2 hours",
  "every6Hours": "Every 6 hours",
  "syncNow": "Sync Now",
  "syncing": "Syncing...",
  "lastSynced": "Last synced",
  "notSynced": "Never synced",
  "notConfigured": "Cloud storage not configured. Configure it in Backup settings above.",
  "syncComplete": "Backup uploaded to cloud",
  "syncCompleteWithRestore": "Backup uploaded and cloud data restored",
  "syncFailed": "Sync failed",
  "success": "Success",
  "failed": "Failed",
  "never": "Never",
  "ago": "ago",
  "statusLabel": "Status",
  "lastSync": "Last Sync"
}
```

- [ ] **Step 2: Add i18n keys to zh.json**

Add a `"cloudSync"` section to `src/i18n/locales/zh.json`:

```json
"cloudSync": {
  "title": "云端同步",
  "description": "自动备份并同步到您的云端存储",
  "enableAutoSync": "启用自动同步",
  "autoSyncDesc": "定期创建备份并上传到云端",
  "interval": "同步间隔",
  "every30Minutes": "每30分钟",
  "everyHour": "每小时",
  "every2Hours": "每2小时",
  "every6Hours": "每6小时",
  "syncNow": "立即同步",
  "syncing": "同步中...",
  "lastSynced": "上次同步",
  "notSynced": "从未同步",
  "notConfigured": "未配置云存储。请先在上方备份设置中配置。",
  "syncComplete": "备份已上传到云端",
  "syncCompleteWithRestore": "备份已上传，云端数据已恢复",
  "syncFailed": "同步失败",
  "success": "成功",
  "failed": "失败",
  "never": "从未",
  "ago": "前",
  "statusLabel": "状态",
  "lastSync": "上次同步"
}
```

- [ ] **Step 3: Update SettingsPage.tsx**

Add imports at the top of `src/pages/SettingsPage.tsx`:

```typescript
import { useCloudSyncStatus, useCloudSyncNow, useUpdateCloudSyncSettings, useCloudSyncSettings } from '@/hooks/useCloudSync';
import { listen } from '@tauri-apps/api/event';
```

Add cloud sync event state and hook usage inside the `SettingsPage` component function, near the other state declarations:

```typescript
  // Cloud sync state
  const { data: cloudSyncStatus } = useCloudSyncStatus();
  const { data: cloudSyncSettings } = useCloudSyncSettings();
  const cloudSyncNowMutation = useCloudSyncNow();
  const updateCloudSyncSettingsMutation = useUpdateCloudSyncSettings();
  const [cloudSyncInterval, setCloudSyncInterval] = useState('30');

  // Cloud sync event listener
  const [lastCloudSyncEvent, setLastCloudSyncEvent] = useState<{
    status: string;
    message: string;
    error?: string;
  } | null>(null);

  useEffect(() => {
    const unlisten = listen<{
      status: string;
      message: string;
      error?: string;
    }>('sync:cloud-status', (event) => {
      setLastCloudSyncEvent(event.payload);
      if (event.payload.status === 'completed' || event.payload.status === 'failed') {
        queryClient.invalidateQueries({ queryKey: ['cloudSyncStatus'] });
      }
    });
    return () => {
      unlisten.then((fn) => fn());
    };
  }, [queryClient]);

  const handleCloudSyncEnabledChange = (enabled: boolean) => {
    updateCloudSyncSettingsMutation.mutate({
      auto_sync_enabled: enabled,
      interval_minutes: parseInt(cloudSyncInterval, 10),
      last_sync_at: null,
      last_sync_status: null,
      last_error: null,
    });
  };

  const handleCloudSyncIntervalChange = (interval: string) => {
    setCloudSyncInterval(interval);
    updateCloudSyncSettingsMutation.mutate({
      auto_sync_enabled: cloudSyncSettings?.auto_sync_enabled ?? false,
      interval_minutes: parseInt(interval, 10),
      last_sync_at: null,
      last_sync_status: null,
      last_error: null,
    });
  };
```

Add the Cloud Sync card between the existing Auto Sync card (line 364 `</Card>`) and the Encryption section (line 366 `{/* Encryption Settings Section */}`):

```tsx
      {/* Cloud Sync Section */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle>{t('cloudSync.title')}</CardTitle>
          <CardDescription>
            {t('cloudSync.description')}
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {!cloudSyncStatus?.cloud_configured ? (
            <p className="text-sm text-muted-foreground">
              {t('cloudSync.notConfigured')}
            </p>
          ) : (
            <>
              <div className="flex items-center justify-between">
                <div className="space-y-0.5">
                  <Label>{t('cloudSync.enableAutoSync')}</Label>
                  <p className="text-xs text-muted-foreground">
                    {t('cloudSync.autoSyncDesc')}
                  </p>
                </div>
                <Switch
                  checked={cloudSyncSettings?.auto_sync_enabled ?? false}
                  onCheckedChange={handleCloudSyncEnabledChange}
                />
              </div>

              <div className="space-y-2">
                <Label>{t('cloudSync.interval')}</Label>
                <Select
                  value={cloudSyncInterval}
                  onValueChange={handleCloudSyncIntervalChange}
                  disabled={!(cloudSyncSettings?.auto_sync_enabled ?? false)}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="30">{t('cloudSync.every30Minutes')}</SelectItem>
                    <SelectItem value="60">{t('cloudSync.everyHour')}</SelectItem>
                    <SelectItem value="120">{t('cloudSync.every2Hours')}</SelectItem>
                    <SelectItem value="360">{t('cloudSync.every6Hours')}</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="flex items-center gap-3">
                <Button
                  onClick={() => cloudSyncNowMutation.mutate()}
                  disabled={cloudSyncStatus?.is_syncing}
                >
                  {cloudSyncStatus?.is_syncing
                    ? t('cloudSync.syncing')
                    : t('cloudSync.syncNow')}
                </Button>
                {cloudSyncStatus?.last_sync_at && (
                  <span className="text-xs text-muted-foreground">
                    {t('cloudSync.lastSynced')}: {cloudSyncStatus.last_sync_at}
                  </span>
                )}
              </div>

              {lastCloudSyncEvent && (
                <div className="pt-2 border-t">
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-medium">{t('cloudSync.statusLabel')}</span>
                    {lastCloudSyncEvent.status === 'started' && (
                      <Badge variant="secondary">{t('cloudSync.syncing')}</Badge>
                    )}
                    {lastCloudSyncEvent.status === 'completed' && (
                      <Badge variant="outline" className="gap-1.5">
                        <span className="h-2 w-2 rounded-full bg-green-500" />
                        {t('cloudSync.success')}
                      </Badge>
                    )}
                    {lastCloudSyncEvent.status === 'failed' && (
                      <Badge variant="destructive">{t('cloudSync.failed')}</Badge>
                    )}
                  </div>
                  <p className="text-xs text-muted-foreground mt-1">
                    {lastCloudSyncEvent.message}
                  </p>
                  {lastCloudSyncEvent.error && (
                    <p className="text-xs text-destructive mt-1">
                      {lastCloudSyncEvent.error}
                    </p>
                  )}
                </div>
              )}
            </>
          )}
        </CardContent>
      </Card>
```

- [ ] **Step 4: Verify type check and lint**

Run: `pnpm type-check && pnpm lint`
Expected: Passes

- [ ] **Step 5: Commit**

```bash
git add src/pages/SettingsPage.tsx src/i18n/locales/en.json src/i18n/locales/zh.json
git commit -m "feat(cloud-sync): add SettingsPage Cloud Sync section and i18n keys"
```

---

### Task 8: Final verification

**Files:**
- No new file changes

- [ ] **Step 1: Rust compilation check**

Run: `cd src-tauri && cargo check`
Expected: Compiles successfully

- [ ] **Step 2: Rust clippy + format**

Run: `cd src-tauri && cargo fmt --check && cargo clippy -- -D warnings`
Expected: No warnings

- [ ] **Step 3: Fix any clippy issues**

If clippy reports issues, run `cd src-tauri && cargo clippy --fix` and then `cargo fmt`. Commit fixes.

- [ ] **Step 4: Frontend type check**

Run: `pnpm type-check`
Expected: No TypeScript errors

- [ ] **Step 5: Frontend lint**

Run: `pnpm lint`
Expected: No ESLint errors

- [ ] **Step 6: Run make check (if available)**

Run: `make check`
Expected: All checks pass

- [ ] **Step 7: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix(cloud-sync): resolve clippy and lint issues"
```
