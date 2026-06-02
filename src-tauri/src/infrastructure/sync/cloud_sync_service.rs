use std::fs;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;
use tracing::{error, info, warn};

use crate::application::services::EncryptionAppService;
use crate::infrastructure::backup::backup_service::{
    bind_json_value, row_to_json, BackupData, BackupFile, BackupInfo, BackupService,
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

/// A single conflict between local and remote data for a record.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncConflictItem {
    pub table_name: String,
    pub record_id: String,
    pub local_updated_at: Option<String>,
    pub remote_updated_at: Option<String>,
    pub local_data: serde_json::Value,
    pub remote_data: serde_json::Value,
}

/// Sync status enriched with detected conflicts.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncStatusWithConflicts {
    pub last_sync_at: Option<String>,
    pub last_status: Option<String>,
    pub is_syncing: bool,
    pub conflicts: Vec<SyncConflictItem>,
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

    /// Detect conflicts between local data and the latest remote backup.
    ///
    /// Downloads the remote backup metadata, compares records with local data,
    /// and returns items where both local and remote have been modified after
    /// the last sync and the data differs.
    pub async fn detect_conflicts(&self) -> Result<Vec<SyncConflictItem>, CloudSyncError> {
        let cloud_settings = self
            .get_cloud_settings()
            .await
            .ok_or(CloudSyncError::NotConfigured)?;

        let provider = build_cloud_provider(&cloud_settings)?;
        let remote_backups = provider.list_backups().await?;
        let prev_sync_at = self.get_last_sync_at().await?;

        let newer = self.find_newer_remote(&remote_backups, &prev_sync_at);
        let Some(remote) = newer else {
            info!("No newer remote backups found for conflict detection");
            return Ok(Vec::new());
        };

        info!(name = %remote.name, "Checking remote backup for conflicts");

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

        // Compare local and remote data across tables
        let conflicts = self.compare_with_local(&backup_data).await;

        info!(
            conflict_count = conflicts.len(),
            "Conflict detection completed"
        );

        Ok(conflicts)
    }

    /// Get sync status with conflict information.
    pub async fn get_status_with_conflicts(&self) -> SyncStatusWithConflicts {
        let settings = self.read_sync_settings().await;
        let is_syncing = self.is_syncing.load(Ordering::SeqCst);

        // Only detect conflicts if not currently syncing and cloud is configured
        let conflicts = if !is_syncing && self.get_cloud_settings().await.is_some() {
            match self.detect_conflicts().await {
                Ok(c) => c,
                Err(e) => {
                    warn!(error = %e, "Failed to detect conflicts");
                    Vec::new()
                }
            }
        } else {
            Vec::new()
        };

        SyncStatusWithConflicts {
            last_sync_at: settings.last_sync_at,
            last_status: settings.last_sync_status,
            is_syncing,
            conflicts,
        }
    }

    /// Resolve a specific conflict using the chosen strategy.
    ///
    /// `resolution` can be "keep_local", "use_remote", or "keep_newer".
    /// For "use_remote", the remote data from the latest backup is applied.
    /// For "keep_local", no action is taken (local data wins).
    /// For "keep_newer", whichever side has the later updated_at wins.
    pub async fn resolve_conflict(
        &self,
        table_name: &str,
        record_id: &str,
        resolution: &str,
    ) -> Result<(), CloudSyncError> {
        info!(
            table = table_name,
            record_id = record_id,
            resolution = resolution,
            "Resolving sync conflict"
        );

        match resolution {
            "keep_local" => {
                // Local data wins — nothing to do
                info!("Conflict resolved: keeping local data");
                Ok(())
            }
            "use_remote" | "keep_newer" => {
                // Need to fetch remote data and apply it
                let cloud_settings = self
                    .get_cloud_settings()
                    .await
                    .ok_or(CloudSyncError::NotConfigured)?;

                let provider = build_cloud_provider(&cloud_settings)?;
                let remote_backups = provider.list_backups().await?;
                let prev_sync_at = self.get_last_sync_at().await?;
                let newer = self.find_newer_remote(&remote_backups, &prev_sync_at);

                let Some(remote) = newer else {
                    return Err(CloudSyncError::Database(
                        "No remote backup available for conflict resolution".to_string(),
                    ));
                };

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

                let remote_row = self.find_remote_row(&backup_data, table_name, record_id);

                let Some(remote_row) = remote_row else {
                    return Err(CloudSyncError::Database(format!(
                        "Remote record not found in {table_name} with id {record_id}"
                    )));
                };

                if resolution == "keep_newer" {
                    // Compare timestamps: only apply remote if it's newer
                    let local_updated = self.get_local_updated_at(table_name, record_id).await?;
                    let remote_updated = remote_row
                        .get("updated_at")
                        .and_then(|v| v.as_str())
                        .map(|s| s.to_string());

                    match (&local_updated, &remote_updated) {
                        (Some(local), Some(remote)) if remote > local => {
                            self.apply_remote_row(table_name, record_id, &remote_row)
                                .await?;
                        }
                        _ => {
                            info!("Keep newer: local data is newer or equal, keeping local");
                        }
                    }
                } else {
                    // "use_remote" — always apply
                    self.apply_remote_row(table_name, record_id, &remote_row)
                        .await?;
                }

                info!(
                    table = table_name,
                    record_id = record_id,
                    resolution = resolution,
                    "Conflict resolved successfully"
                );
                Ok(())
            }
            _ => Err(CloudSyncError::Database(format!(
                "Unknown resolution strategy: {resolution}"
            ))),
        }
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

    /// Compare remote backup data with local database and find conflicts.
    ///
    /// A conflict is a record that exists in both local and remote, has
    /// different data, and both have been modified since the last sync.
    async fn compare_with_local(&self, backup_data: &BackupData) -> Vec<SyncConflictItem> {
        let mut conflicts = Vec::new();

        let tables: &[(&str, &[serde_json::Value])] = &[
            ("accounts", &backup_data.accounts),
            ("transactions", &backup_data.transactions),
            ("debt_details", &backup_data.debt_details),
            ("debt_payment_schedule", &backup_data.debt_payment_schedule),
            ("budgets", &backup_data.budgets),
            ("budget_items", &backup_data.budget_items),
            ("goals", &backup_data.goals),
            ("tags", &backup_data.tags),
        ];

        for (table_name, remote_rows) in tables {
            if let Ok(table_conflicts) = self.compare_table(table_name, remote_rows).await {
                conflicts.extend(table_conflicts);
            }
        }

        conflicts
    }

    /// Compare a single table's remote rows with local data.
    async fn compare_table(
        &self,
        table_name: &str,
        remote_rows: &[serde_json::Value],
    ) -> Result<Vec<SyncConflictItem>, CloudSyncError> {
        if table_name == "transaction_tags" {
            // Skip composite PK tables
            return Ok(Vec::new());
        }

        // Fetch all local rows as JSON using the same serialization as backup
        let query = format!("SELECT * FROM {table_name}");
        let rows = sqlx::query(&query)
            .fetch_all(&self.pool)
            .await
            .map_err(|e| CloudSyncError::Database(e.to_string()))?;

        // Build map of local data by ID
        let mut local_map: std::collections::HashMap<String, serde_json::Value> =
            std::collections::HashMap::new();
        for row in &rows {
            let json_row = row_to_json(row);
            if let Some(id) = json_row.get("id").and_then(|v| v.as_str()) {
                local_map.insert(id.to_string(), json_row);
            }
        }

        let mut conflicts = Vec::new();

        for remote_row in remote_rows {
            let remote_obj = match remote_row.as_object() {
                Some(o) => o,
                None => continue,
            };

            let record_id = match remote_obj.get("id").and_then(|v| v.as_str()) {
                Some(id) => id.to_string(),
                None => continue,
            };

            // Only consider records that exist locally
            let Some(local_data) = local_map.get(&record_id) else {
                continue;
            };

            // Check if data differs
            if local_data == remote_row {
                continue;
            }

            let local_updated = local_data
                .get("updated_at")
                .and_then(|v| v.as_str())
                .map(|s| s.to_string());
            let remote_updated = remote_obj
                .get("updated_at")
                .and_then(|v| v.as_str())
                .map(|s| s.to_string());

            // This is a conflict: record exists in both, data differs
            conflicts.push(SyncConflictItem {
                table_name: table_name.to_string(),
                record_id,
                local_updated_at: local_updated,
                remote_updated_at: remote_updated,
                local_data: local_data.clone(),
                remote_data: remote_row.clone(),
            });
        }

        Ok(conflicts)
    }

    /// Find a specific record in the remote backup data.
    fn find_remote_row(
        &self,
        backup_data: &BackupData,
        table_name: &str,
        record_id: &str,
    ) -> Option<serde_json::Value> {
        let rows = match table_name {
            "accounts" => &backup_data.accounts,
            "transactions" => &backup_data.transactions,
            "debt_details" => &backup_data.debt_details,
            "debt_payment_schedule" => &backup_data.debt_payment_schedule,
            "budgets" => &backup_data.budgets,
            "budget_items" => &backup_data.budget_items,
            "goals" => &backup_data.goals,
            "tags" => &backup_data.tags,
            _ => return None,
        };

        rows.iter()
            .find(|row| {
                row.get("id")
                    .and_then(|v| v.as_str())
                    .is_some_and(|id| id == record_id)
            })
            .cloned()
    }

    /// Get the updated_at timestamp for a local record.
    async fn get_local_updated_at(
        &self,
        table_name: &str,
        record_id: &str,
    ) -> Result<Option<String>, CloudSyncError> {
        let query = format!("SELECT updated_at FROM {table_name} WHERE id = ?");
        let row = sqlx::query_as::<_, (Option<String>,)>(&query)
            .bind(record_id)
            .fetch_optional(&self.pool)
            .await
            .map_err(|e| CloudSyncError::Database(e.to_string()))?;

        Ok(row.and_then(|r| r.0))
    }

    /// Apply a remote row to the local database using UPDATE.
    async fn apply_remote_row(
        &self,
        table_name: &str,
        record_id: &str,
        remote_row: &serde_json::Value,
    ) -> Result<(), CloudSyncError> {
        let obj = match remote_row.as_object() {
            Some(o) => o.clone(),
            None => {
                return Err(CloudSyncError::Database(
                    "Invalid remote row data".to_string(),
                ))
            }
        };

        let columns: Vec<&str> = obj.keys().map(|s| s.as_str()).collect();
        let set_clause: Vec<String> = columns
            .iter()
            .filter(|&&col| col != "id")
            .map(|&col| format!("{col} = ?"))
            .collect();

        let sql = format!(
            "UPDATE {} SET {} WHERE id = ?",
            table_name,
            set_clause.join(", ")
        );

        let mut query = sqlx::query(&sql);
        for &col in &columns {
            if col != "id" {
                let val = obj.get(col).unwrap_or(&serde_json::Value::Null);
                query = bind_json_value(query, val);
            }
        }
        query = query.bind(record_id);

        query
            .execute(&self.pool)
            .await
            .map_err(|e| CloudSyncError::Database(format!("update {table_name} failed: {e}")))?;

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
