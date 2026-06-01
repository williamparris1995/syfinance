use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use chrono::Utc;
use flate2::read::GzDecoder;
use flate2::write::GzEncoder;
use flate2::Compression;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use sqlx::{Column, Row, SqlitePool};
use std::fs;
use std::io::{Read as _, Write as _};
use std::path::PathBuf;
use tracing::{error, info};

use crate::infrastructure::encryption::EncryptionService;

// ---------------------------------------------------------------------------
// Data types
// ---------------------------------------------------------------------------

/// Backup file envelope stored on disk as JSON.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackupFile {
    /// Format version (currently "1.0").
    pub version: String,
    /// Whether the `data` field is encrypted.
    pub encrypted: bool,
    /// Whether the payload is gzip-compressed.
    pub compressed: bool,
    /// Salt used for key derivation (hex-encoded). Present only when encrypted.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub salt: Option<String>,
    /// Base64-encoded payload (encrypted compressed JSON, or plain compressed JSON).
    pub data: String,
    /// SHA-256 checksum of the raw JSON *before* compression/encryption (hex).
    pub checksum: String,
    /// Metadata is NOT encrypted so it can be previewed without a password.
    pub metadata: BackupMetadata,
}

/// The actual data inside a backup.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackupData {
    pub accounts: Vec<serde_json::Value>,
    pub transactions: Vec<serde_json::Value>,
    #[serde(alias = "debts")]
    pub debt_details: Vec<serde_json::Value>,
    #[serde(default)]
    pub debt_payment_schedule: Vec<serde_json::Value>,
    pub goals: Vec<serde_json::Value>,
    pub budgets: Vec<serde_json::Value>,
    #[serde(default)]
    pub budget_items: Vec<serde_json::Value>,
    pub tags: Vec<serde_json::Value>,
    #[serde(default)]
    pub transaction_tags: Vec<serde_json::Value>,
}

/// Counts per table + device identifier. Stored unencrypted in the envelope.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackupMetadata {
    pub account_count: usize,
    pub transaction_count: usize,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub debt_count: Option<usize>,
    pub debt_detail_count: usize,
    pub debt_payment_count: usize,
    pub goal_count: usize,
    pub budget_count: usize,
    pub budget_item_count: usize,
    pub tag_count: usize,
    pub transaction_tag_count: usize,
    pub device_id: String,
}

/// Summary info about a backup file on disk.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackupInfo {
    pub filename: String,
    pub file_size: u64,
    pub created_at: String,
    pub metadata: BackupMetadata,
    pub on_cloud: bool,
}

/// Per-table statistics after a restore operation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TableRestoreStats {
    pub inserted: usize,
    pub updated: usize,
    pub skipped: usize,
}

/// Statistics for all tables after restore.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RestoreTableResult {
    pub accounts: TableRestoreStats,
    pub transactions: TableRestoreStats,
    pub debt_details: TableRestoreStats,
    pub debt_payment_schedule: TableRestoreStats,
    pub goals: TableRestoreStats,
    pub budgets: TableRestoreStats,
    pub budget_items: TableRestoreStats,
    pub tags: TableRestoreStats,
    pub transaction_tags: TableRestoreStats,
}

/// Result of a restore operation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RestoreResult {
    /// Filename of the automatic safety backup created before restore.
    pub safety_backup: String,
    /// Per-table restore statistics.
    pub tables: RestoreTableResult,
}

/// Per-table diff between backup data and current local data.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TableDiff {
    pub local_count: usize,
    pub backup_count: usize,
    pub added: usize,
    pub removed: usize,
    pub modified: usize,
}

/// Aggregate diff across all nine tables.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiffSummary {
    pub accounts: TableDiff,
    pub transactions: TableDiff,
    pub debt_details: TableDiff,
    pub debt_payment_schedule: TableDiff,
    pub goals: TableDiff,
    pub budgets: TableDiff,
    pub budget_items: TableDiff,
    pub tags: TableDiff,
    pub transaction_tags: TableDiff,
}

// ---------------------------------------------------------------------------
// Error type
// ---------------------------------------------------------------------------

#[derive(Debug, thiserror::Error)]
pub enum BackupError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("serialization error: {0}")]
    Serialization(#[from] serde_json::Error),
    #[error("encryption error: {0}")]
    Encryption(String),
    #[error("decryption error: {0}")]
    Decryption(String),
    #[error("backup not found: {0}")]
    NotFound(String),
    #[error("database error: {0}")]
    Database(String),
    #[error("invalid backup file: {0}")]
    InvalidFile(String),
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Convert a SQLx row into a JSON value by dynamically extracting every column.
fn row_to_json(row: &sqlx::sqlite::SqliteRow) -> serde_json::Value {
    let mut map = serde_json::Map::new();
    for i in 0..row.columns().len() {
        let col_name = row.columns()[i].name().to_string();
        if let Ok(val) = row.try_get::<String, _>(i) {
            map.insert(col_name, serde_json::Value::String(val));
        } else if let Ok(val) = row.try_get::<i64, _>(i) {
            map.insert(col_name, serde_json::Value::Number(val.into()));
        } else if let Ok(val) = row.try_get::<f64, _>(i) {
            if let Some(n) = serde_json::Number::from_f64(val) {
                map.insert(col_name, serde_json::Value::Number(n));
            }
        } else if let Ok(val) = row.try_get::<bool, _>(i) {
            map.insert(col_name, serde_json::Value::Bool(val));
        } else {
            map.insert(col_name, serde_json::Value::Null);
        }
    }
    serde_json::Value::Object(map)
}

/// Compute SHA-256 of a byte slice and return the hex digest.
fn sha256_hex(data: &[u8]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(data);
    hex::encode(hasher.finalize())
}

/// Gzip-compress a byte slice.
fn gzip_compress(data: &[u8]) -> Result<Vec<u8>, std::io::Error> {
    let mut encoder = GzEncoder::new(Vec::new(), Compression::default());
    encoder.write_all(data)?;
    encoder.finish()
}

/// Gzip-decompress a byte slice.
fn gzip_decompress(data: &[u8]) -> Result<Vec<u8>, std::io::Error> {
    let mut decoder = GzDecoder::new(data);
    let mut decoded = Vec::new();
    decoder.read_to_end(&mut decoded)?;
    Ok(decoded)
}

// ---------------------------------------------------------------------------
// BackupService
// ---------------------------------------------------------------------------

pub struct BackupService {
    pool: SqlitePool,
    backup_dir: PathBuf,
}

impl BackupService {
    /// Create a new `BackupService`. The `backup_dir` will be created if it does
    /// not already exist.
    pub fn new(pool: SqlitePool, backup_dir: PathBuf) -> Result<Self, BackupError> {
        fs::create_dir_all(&backup_dir)?;
        Ok(Self { pool, backup_dir })
    }

    // ----- create_backup ----------------------------------------------------

    /// Export all tables, compress, optionally encrypt, and write a `.enc` file.
    ///
    /// Returns a `BackupInfo` describing the newly-created file.
    pub async fn create_backup(
        &self,
        encryption_service: Option<&EncryptionService>,
    ) -> Result<BackupInfo, BackupError> {
        info!("Creating backup");

        // 1. Query all 6 tables
        let data = self.query_all_tables().await?;

        // 2. Serialize to JSON
        let json_bytes = serde_json::to_vec(&data)?;

        // 3. SHA-256 checksum of raw JSON
        let checksum = sha256_hex(&json_bytes);

        // 4. gzip compress
        let compressed = gzip_compress(&json_bytes)?;

        // 5. Encrypt if a service was provided
        let (encrypted, salt) = match encryption_service {
            Some(svc) => {
                let salt_bytes = EncryptionService::generate_salt();
                let salt_hex = hex::encode(salt_bytes);
                let encrypted_bytes = svc
                    .encrypt(&String::from_utf8_lossy(&compressed))
                    .map_err(|e| BackupError::Encryption(e.to_string()))?;
                (encrypted_bytes, Some(salt_hex))
            }
            None => (compressed, None),
        };

        // 6. Base64 encode
        let data_b64 = STANDARD.encode(&encrypted);

        // 7. Build metadata
        let metadata = BackupMetadata {
            account_count: data.accounts.len(),
            transaction_count: data.transactions.len(),
            debt_count: None,
            debt_detail_count: data.debt_details.len(),
            debt_payment_count: data.debt_payment_schedule.len(),
            goal_count: data.goals.len(),
            budget_count: data.budgets.len(),
            budget_item_count: data.budget_items.len(),
            tag_count: data.tags.len(),
            transaction_tag_count: data.transaction_tags.len(),
            device_id: self.get_device_id(),
        };

        // 8. Build envelope
        let backup_file = BackupFile {
            version: "1.0".to_string(),
            encrypted: encryption_service.is_some(),
            compressed: true,
            salt,
            data: data_b64,
            checksum,
            metadata,
        };

        // 9. Write to disk
        let filename = format!("backup_{}.enc", Utc::now().format("%Y%m%d_%H%M"));
        let filepath = self.backup_dir.join(&filename);
        let json_envelope = serde_json::to_string_pretty(&backup_file)?;
        fs::write(&filepath, &json_envelope)?;

        let file_size = fs::metadata(&filepath)?.len();
        let created_at = Utc::now().to_rfc3339();

        info!(
            filename = %filename,
            file_size,
            encrypted = backup_file.encrypted,
            "Backup created"
        );

        Ok(BackupInfo {
            filename,
            file_size,
            created_at,
            metadata: backup_file.metadata,
            on_cloud: false,
        })
    }

    // ----- list_backups -----------------------------------------------------

    /// Scan the backup directory and return metadata for every `.enc` file.
    pub fn list_backups(&self) -> Result<Vec<BackupInfo>, BackupError> {
        let mut backups = Vec::new();

        let entries = fs::read_dir(&self.backup_dir)?;
        for entry in entries {
            let entry = entry?;
            let path = entry.path();

            if path.extension().and_then(|e| e.to_str()) != Some("enc") {
                continue;
            }

            let filename = match path.file_name().and_then(|n| n.to_str()) {
                Some(n) => n.to_string(),
                None => continue,
            };

            let file_size = match fs::metadata(&path) {
                Ok(m) => m.len(),
                Err(e) => {
                    error!(filename = %filename, error = %e, "Failed to read backup file metadata");
                    continue;
                }
            };

            let created_at = file_created_at(&path);

            let metadata = match Self::parse_metadata_from_file(&path) {
                Ok(m) => m,
                Err(e) => {
                    error!(filename = %filename, error = %e, "Failed to parse backup metadata");
                    continue;
                }
            };

            backups.push(BackupInfo {
                filename,
                file_size,
                created_at,
                metadata,
                on_cloud: false,
            });
        }

        // Sort newest first by filename (which starts with a timestamp).
        backups.sort_by(|a, b| b.filename.cmp(&a.filename));

        Ok(backups)
    }

    // ----- read_backup_metadata ---------------------------------------------

    /// Read only the metadata portion of a backup file (no decryption needed).
    #[allow(dead_code)]
    pub fn read_backup_metadata(&self, filename: &str) -> Result<BackupMetadata, BackupError> {
        let path = self.backup_dir.join(filename);
        Self::parse_metadata_from_file(&path)
    }

    // ----- decrypt_backup_data ----------------------------------------------

    /// Decrypt, decompress, and deserialize the data payload of a `BackupFile`.
    #[allow(dead_code)]
    pub fn decrypt_backup_data(
        backup: &BackupFile,
        encryption_service: &EncryptionService,
    ) -> Result<BackupData, BackupError> {
        // 1. Base64 decode
        let raw = STANDARD
            .decode(&backup.data)
            .map_err(|e| BackupError::Decryption(format!("base64 decode failed: {}", e)))?;

        // 2. Decrypt if needed
        let compressed = if backup.encrypted {
            let plaintext = encryption_service
                .decrypt(&raw)
                .map_err(|e| BackupError::Decryption(e.to_string()))?;
            plaintext.into_bytes()
        } else {
            raw
        };

        // 3. Gzip decompress
        let json_bytes = gzip_decompress(&compressed)?;

        // 4. Verify checksum
        let actual_checksum = sha256_hex(&json_bytes);
        if actual_checksum != backup.checksum {
            return Err(BackupError::Decryption(
                "checksum mismatch - data may be corrupted".to_string(),
            ));
        }

        // 5. Deserialize
        let data: BackupData = serde_json::from_slice(&json_bytes)?;
        Ok(data)
    }

    /// Decompress and deserialize an unencrypted backup payload.
    #[allow(dead_code)]
    pub fn decrypt_backup_data_no_encryption(
        backup: &BackupFile,
    ) -> Result<BackupData, BackupError> {
        if backup.encrypted {
            return Err(BackupError::Decryption(
                "backup is encrypted - use decrypt_backup_data with encryption service".to_string(),
            ));
        }

        let raw = STANDARD
            .decode(&backup.data)
            .map_err(|e| BackupError::Decryption(format!("base64 decode failed: {}", e)))?;

        let json_bytes = if backup.compressed {
            gzip_decompress(&raw)?
        } else {
            raw
        };

        let actual_checksum = sha256_hex(&json_bytes);
        if actual_checksum != backup.checksum {
            return Err(BackupError::Decryption(
                "checksum mismatch - data may be corrupted".to_string(),
            ));
        }

        let data: BackupData = serde_json::from_slice(&json_bytes)?;
        Ok(data)
    }

    // ----- compute_diff -----------------------------------------------------

    /// Compare backup data with the current local database and produce a diff.
    #[allow(dead_code)]
    pub async fn compute_diff(&self, backup_data: &BackupData) -> Result<DiffSummary, BackupError> {
        let local = self.query_all_tables().await?;
        Ok(DiffSummary {
            accounts: diff_table(&local.accounts, &backup_data.accounts),
            transactions: diff_table(&local.transactions, &backup_data.transactions),
            debt_details: diff_table(&local.debt_details, &backup_data.debt_details),
            debt_payment_schedule: diff_table(
                &local.debt_payment_schedule,
                &backup_data.debt_payment_schedule,
            ),
            goals: diff_table(&local.goals, &backup_data.goals),
            budgets: diff_table(&local.budgets, &backup_data.budgets),
            budget_items: diff_table(&local.budget_items, &backup_data.budget_items),
            tags: diff_table(&local.tags, &backup_data.tags),
            transaction_tags: diff_table(&local.transaction_tags, &backup_data.transaction_tags),
        })
    }

    // ----- delete_backup ----------------------------------------------------

    /// Delete a backup file from disk.
    #[allow(dead_code)]
    pub fn delete_backup(&self, filename: &str) -> Result<(), BackupError> {
        let path = self.backup_dir.join(filename);
        if !path.exists() {
            return Err(BackupError::NotFound(filename.to_string()));
        }
        fs::remove_file(&path)?;
        info!(filename = %filename, "Backup deleted");
        Ok(())
    }

    // ----- internal helpers -------------------------------------------------

    /// Query all 9 tables and return rows as JSON values.
    async fn query_all_tables(&self) -> Result<BackupData, BackupError> {
        let accounts = self.query_table("accounts").await?;
        let transactions = self.query_table("transactions").await?;
        let debt_details = self.query_table("debt_details").await?;
        let debt_payment_schedule = self.query_table("debt_payment_schedule").await?;
        let goals = self.query_table("goals").await?;
        let budgets = self.query_table("budgets").await?;
        let budget_items = self.query_table("budget_items").await?;
        let tags = self.query_table("tags").await?;
        let transaction_tags = self.query_table("transaction_tags").await?;

        Ok(BackupData {
            accounts,
            transactions,
            debt_details,
            debt_payment_schedule,
            goals,
            budgets,
            budget_items,
            tags,
            transaction_tags,
        })
    }

    /// Query a single table and return rows as JSON values.
    async fn query_table(&self, table: &str) -> Result<Vec<serde_json::Value>, BackupError> {
        let query = format!("SELECT * FROM {}", table);
        let rows = sqlx::query(&query)
            .fetch_all(&self.pool)
            .await
            .map_err(|e| BackupError::Database(format!("query {} failed: {}", table, e)))?;
        Ok(rows.iter().map(row_to_json).collect())
    }

    /// Read a backup file from disk and parse just the metadata.
    fn parse_metadata_from_file(path: &PathBuf) -> Result<BackupMetadata, BackupError> {
        let contents = fs::read_to_string(path)?;
        let file: serde_json::Value = serde_json::from_str(&contents)?;
        let metadata = file
            .get("metadata")
            .ok_or_else(|| BackupError::InvalidFile("missing metadata field".to_string()))?;
        let meta: BackupMetadata = serde_json::from_value(metadata.clone())?;
        Ok(meta)
    }

    /// Return a stable device identifier.
    ///
    /// Uses a UUID v4 that is generated once and persisted in a tiny file next
    /// to the backup directory. Falls back to a transient UUID if the file
    /// cannot be written.
    fn get_device_id(&self) -> String {
        let id_path = self.backup_dir.join(".device_id");
        if let Ok(contents) = fs::read_to_string(&id_path) {
            let trimmed = contents.trim().to_string();
            if !trimmed.is_empty() {
                return trimmed;
            }
        }
        let new_id = format!("local-{}", uuid::Uuid::new_v4());
        let _ = fs::write(&id_path, &new_id);
        new_id
    }
}

// ---------------------------------------------------------------------------
// Free functions
// ---------------------------------------------------------------------------

/// Best-effort creation timestamp from file metadata.
fn file_created_at(path: &PathBuf) -> String {
    fs::metadata(path)
        .and_then(|m| m.created())
        .map(|t| {
            let dt: chrono::DateTime<Utc> = t.into();
            dt.to_rfc3339()
        })
        .unwrap_or_else(|_| Utc::now().to_rfc3339())
}

/// Compute a diff between local and backup rows for a single table.
///
/// Rows are matched by their `id` field (string comparison). A row present in
/// local but not backup counts as "added"; present in backup but not local
/// counts as "removed"; present in both but with different JSON is "modified".
fn diff_table(local: &[serde_json::Value], backup: &[serde_json::Value]) -> TableDiff {
    let get_id = |v: &serde_json::Value| -> String {
        v.get("id")
            .and_then(|id| id.as_str())
            .unwrap_or("")
            .to_string()
    };

    let local_map: std::collections::HashMap<String, &serde_json::Value> =
        local.iter().map(|v| (get_id(v), v)).collect();

    let backup_map: std::collections::HashMap<String, &serde_json::Value> =
        backup.iter().map(|v| (get_id(v), v)).collect();

    let mut added = 0usize;
    let mut removed = 0usize;
    let mut modified = 0usize;

    for (id, local_val) in &local_map {
        match backup_map.get(id) {
            None => added += 1,
            Some(backup_val) => {
                if local_val != backup_val {
                    modified += 1;
                }
            }
        }
    }

    for id in backup_map.keys() {
        if !local_map.contains_key(id) {
            removed += 1;
        }
    }

    TableDiff {
        local_count: local.len(),
        backup_count: backup.len(),
        added,
        removed,
        modified,
    }
}
