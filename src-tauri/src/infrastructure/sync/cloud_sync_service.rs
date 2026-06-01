use std::fs;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;
use tracing::{error, info, warn};

use crate::application::services::EncryptionAppService;
use crate::infrastructure::backup::backup_service::{BackupFile, BackupInfo, BackupService};
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
        if self
            .is_syncing
            .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
            .is_err()
        {
            return Err(CloudSyncError::AlreadySyncing);
        }

        let result = self.do_sync().await;

        self.is_syncing.store(false, Ordering::SeqCst);

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

        self.sync_to_cloud().await?;

        let restored = match self.sync_from_cloud(&prev_sync_at).await {
            Ok(r) => r,
            Err(e) => {
                warn!(error = %e, "Cloud download/restore failed after successful upload");
                false
            }
        };

        self.update_last_sync_at().await?;

        if let Err(e) = self.cleanup_old_backups() {
            warn!(error = %e, "Failed to cleanup old backups");
        }

        Ok(CloudSyncResult {
            uploaded: true,
            restored,
        })
    }

    async fn sync_to_cloud(&self) -> Result<(), CloudSyncError> {
        let cloud_settings = self
            .get_cloud_settings()
            .await
            .ok_or(CloudSyncError::NotConfigured)?;

        let provider = build_cloud_provider(&cloud_settings)?;

        let backup_service = BackupService::new(self.pool.clone(), self.backup_dir.clone())?;
        let encryption = self.encryption_state.get_encryption_service();
        let backup_info = backup_service.create_backup(encryption.as_ref()).await?;

        info!(filename = %backup_info.filename, "Backup created for cloud sync");

        let local_path = self.backup_dir.join(&backup_info.filename);
        provider.upload(&local_path, &backup_info.filename).await?;

        info!(filename = %backup_info.filename, "Backup uploaded to cloud");

        Ok(())
    }

    async fn sync_from_cloud(&self, prev_sync_at: &Option<String>) -> Result<bool, CloudSyncError> {
        let cloud_settings = self
            .get_cloud_settings()
            .await
            .ok_or(CloudSyncError::NotConfigured)?;

        let provider = build_cloud_provider(&cloud_settings)?;

        let remote_backups = provider.list_backups().await?;

        let newer = self.find_newer_remote(&remote_backups, prev_sync_at);

        let Some(remote) = newer else {
            info!("No newer remote backups found");
            return Ok(false);
        };

        info!(name = %remote.name, "Found newer remote backup");

        let download_path = self.backup_dir.join(&remote.name);
        provider.download(&remote.name, &download_path).await?;

        let contents = fs::read_to_string(&download_path)?;
        let backup_file: BackupFile = serde_json::from_str(&contents).map_err(|e| {
            CloudSyncError::Io(std::io::Error::new(std::io::ErrorKind::InvalidData, e))
        })?;

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

        let backup_service = BackupService::new(self.pool.clone(), self.backup_dir.clone())?;
        let result = backup_service
            .restore_backup(&backup_data, "keep_newer")
            .await?;

        info!(
            safety_backup = %result.safety_backup,
            "Remote backup restored"
        );

        Ok(true)
    }

    fn find_newer_remote(
        &self,
        remote_backups: &[crate::infrastructure::backup::cloud_provider::CloudBackupInfo],
        prev_sync_at: &Option<String>,
    ) -> Option<crate::infrastructure::backup::cloud_provider::CloudBackupInfo> {
        let cutoff = prev_sync_at.as_deref().unwrap_or("");

        remote_backups
            .iter()
            .filter(|b| b.last_modified.as_deref().is_some_and(|m| m > cutoff))
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

        Ok(row.and_then(|r| r.0))
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

        backups.sort_by(|a, b| b.1.cmp(&a.1));

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
