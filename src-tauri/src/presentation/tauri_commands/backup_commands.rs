use crate::application::services::EncryptionAppService;
use crate::infrastructure::backup::backup_service::{
    BackupFile, BackupInfo, BackupService, DiffSummary, RestoreResult,
};
use crate::infrastructure::backup::cloud_provider::{
    get_presets, CloudBackupInfo, CloudPreset, CloudProvider, CloudSettings,
};
use crate::infrastructure::backup::oauth;
use sqlx::SqlitePool;
use std::path::PathBuf;
use std::sync::Arc;
use tracing::{error, info};

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

#[derive(Clone)]
pub struct BackupCommandState {
    pool: SqlitePool,
    backup_dir: PathBuf,
    encryption_state: Arc<EncryptionAppService>,
}

impl BackupCommandState {
    pub fn new(
        pool: SqlitePool,
        backup_dir: PathBuf,
        encryption_state: Arc<EncryptionAppService>,
    ) -> Self {
        Self {
            pool,
            backup_dir,
            encryption_state,
        }
    }
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

#[tauri::command]
pub async fn create_backup(
    state: tauri::State<'_, BackupCommandState>,
) -> Result<BackupInfo, String> {
    info!("Creating backup via Tauri command");

    let service = BackupService::new(state.pool.clone(), state.backup_dir.clone())
        .map_err(|e| e.to_string())?;

    let encryption = if state.encryption_state.is_unlocked() {
        state.encryption_state.get_encryption_service()
    } else {
        None
    };

    service
        .create_backup(encryption.as_ref())
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub fn list_backups(
    state: tauri::State<'_, BackupCommandState>,
) -> Result<Vec<BackupInfo>, String> {
    let service = BackupService::new(state.pool.clone(), state.backup_dir.clone())
        .map_err(|e| e.to_string())?;

    service.list_backups().map_err(|e| e.to_string())
}

#[tauri::command]
pub fn get_backup_metadata(
    state: tauri::State<'_, BackupCommandState>,
    filename: String,
) -> Result<BackupFile, String> {
    let path = state.backup_dir.join(&filename);
    let contents =
        std::fs::read_to_string(&path).map_err(|e| format!("failed to read backup file: {e}"))?;
    let backup: BackupFile =
        serde_json::from_str(&contents).map_err(|e| format!("failed to parse backup file: {e}"))?;
    Ok(backup)
}

#[tauri::command]
pub async fn get_backup_diff(
    state: tauri::State<'_, BackupCommandState>,
    filename: String,
) -> Result<DiffSummary, String> {
    let service = BackupService::new(state.pool.clone(), state.backup_dir.clone())
        .map_err(|e| e.to_string())?;

    // Read and parse the backup file
    let path = state.backup_dir.join(&filename);
    let contents =
        std::fs::read_to_string(&path).map_err(|e| format!("failed to read backup file: {e}"))?;
    let backup: BackupFile =
        serde_json::from_str(&contents).map_err(|e| format!("failed to parse backup file: {e}"))?;

    // Decrypt if needed
    let backup_data = if backup.encrypted {
        let encryption = state
            .encryption_state
            .get_encryption_service()
            .ok_or_else(|| "encryption is locked - unlock to compute diff".to_string())?;
        BackupService::decrypt_backup_data(&backup, &encryption).map_err(|e| e.to_string())?
    } else {
        // Not encrypted - still need to decompress
        BackupService::decrypt_backup_data_no_encryption(&backup).map_err(|e| e.to_string())?
    };

    service
        .compute_diff(&backup_data)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub fn delete_backup(
    state: tauri::State<'_, BackupCommandState>,
    filename: String,
) -> Result<(), String> {
    let service = BackupService::new(state.pool.clone(), state.backup_dir.clone())
        .map_err(|e| e.to_string())?;

    service.delete_backup(&filename).map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn restore_backup(
    state: tauri::State<'_, BackupCommandState>,
    filename: String,
    strategy: String,
) -> Result<RestoreResult, String> {
    info!(filename = %filename, strategy = %strategy, "Restoring backup via Tauri command");

    // Validate strategy
    if !["keep_newer", "use_backup", "keep_local"].contains(&strategy.as_str()) {
        return Err(format!("invalid strategy: {strategy}"));
    }

    let service = BackupService::new(state.pool.clone(), state.backup_dir.clone())
        .map_err(|e| e.to_string())?;

    // Read and parse the backup file
    let path = state.backup_dir.join(&filename);
    let contents =
        std::fs::read_to_string(&path).map_err(|e| format!("failed to read backup file: {e}"))?;
    let backup: BackupFile =
        serde_json::from_str(&contents).map_err(|e| format!("failed to parse backup file: {e}"))?;

    // Decrypt if needed
    let backup_data = if backup.encrypted {
        let encryption = state
            .encryption_state
            .get_encryption_service()
            .ok_or_else(|| "encryption is locked - unlock to restore".to_string())?;
        BackupService::decrypt_backup_data(&backup, &encryption).map_err(|e| e.to_string())?
    } else {
        BackupService::decrypt_backup_data_no_encryption(&backup).map_err(|e| e.to_string())?
    };

    service
        .restore_backup(&backup_data, &strategy)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub fn get_cloud_presets() -> Vec<CloudPreset> {
    get_presets()
}

#[tauri::command]
pub async fn get_cloud_settings(
    state: tauri::State<'_, BackupCommandState>,
) -> Result<Option<CloudSettings>, String> {
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
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| format!("failed to read cloud settings: {e}"))?;

    Ok(row.map(|r| CloudSettings {
        provider: r.0,
        server_url: r.1,
        port: r.2,
        username: r.3,
        password: r.4,
        remote_path: r.5,
        access_token: r.6,
        refresh_token: r.7,
        auto_upload: r.8,
        enabled: r.9,
    }))
}

#[tauri::command]
pub async fn save_cloud_settings(
    state: tauri::State<'_, BackupCommandState>,
    settings: CloudSettings,
) -> Result<(), String> {
    // Delete existing row then insert new one (upsert)
    sqlx::query("DELETE FROM cloud_settings")
        .execute(&state.pool)
        .await
        .map_err(|e| format!("failed to clear cloud settings: {e}"))?;

    sqlx::query(
        "INSERT INTO cloud_settings \
         (provider, server_url, port, username, password, remote_path, \
          access_token, refresh_token, auto_upload, enabled) \
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(&settings.provider)
    .bind(&settings.server_url)
    .bind(settings.port)
    .bind(&settings.username)
    .bind(&settings.password)
    .bind(&settings.remote_path)
    .bind(&settings.access_token)
    .bind(&settings.refresh_token)
    .bind(&settings.auto_upload)
    .bind(settings.enabled)
    .execute(&state.pool)
    .await
    .map_err(|e| format!("failed to save cloud settings: {e}"))?;

    info!("Cloud settings saved");
    Ok(())
}

#[tauri::command]
pub async fn test_cloud_connection(settings: CloudSettings) -> Result<(), String> {
    let provider = crate::infrastructure::backup::build_cloud_provider(&settings)
        .map_err(|e| format!("cloud provider not configured: {e}"))?;
    provider
        .test_connection()
        .await
        .map_err(|e| format!("cloud connection test failed: {e}"))
}

#[tauri::command]
pub async fn upload_to_cloud(
    state: tauri::State<'_, BackupCommandState>,
    filename: String,
) -> Result<(), String> {
    let cloud_settings = get_cloud_settings_inner(&state.pool)
        .await?
        .ok_or_else(|| "cloud not configured".to_string())?;

    let provider = crate::infrastructure::backup::build_cloud_provider(&cloud_settings)
        .map_err(|e| format!("cloud provider not configured: {e}"))?;
    let local_path = state.backup_dir.join(&filename);

    if !local_path.exists() {
        return Err(format!("backup file not found: {filename}"));
    }

    provider
        .upload(&local_path, &filename)
        .await
        .map_err(|e| format!("upload failed: {e}"))?;

    info!(filename = %filename, "Backup uploaded to cloud");
    Ok(())
}

#[tauri::command]
pub async fn list_cloud_backups(
    state: tauri::State<'_, BackupCommandState>,
) -> Result<Vec<CloudBackupInfo>, String> {
    let cloud_settings = get_cloud_settings_inner(&state.pool)
        .await?
        .ok_or_else(|| "cloud not configured".to_string())?;

    let provider = crate::infrastructure::backup::build_cloud_provider(&cloud_settings)
        .map_err(|e| format!("cloud provider not configured: {e}"))?;
    provider
        .list_backups()
        .await
        .map_err(|e| format!("failed to list cloud backups: {e}"))
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

#[tauri::command]
pub async fn authorize_cloud_provider(
    app_handle: tauri::AppHandle,
    state: tauri::State<'_, BackupCommandState>,
    provider: String,
    client_id: String,
) -> Result<CloudSettings, String> {
    let oauth_providers = ["dropbox", "google_drive", "onedrive"];
    if !oauth_providers.contains(&provider.as_str()) {
        return Err(format!("provider '{provider}' does not support OAuth"));
    }

    if client_id.trim().is_empty() {
        return Err("client_id is required for OAuth authorization".to_string());
    }

    info!(provider = %provider, "starting OAuth authorization flow");

    let config = oauth::get_oauth_config(&provider, &client_id, None);

    let tokens = oauth::authorize_with_pkce(&config, &app_handle).await?;

    info!(provider = %provider, "OAuth authorization successful, saving tokens");

    // Save tokens to cloud_settings
    let settings = CloudSettings {
        provider: provider.clone(),
        server_url: None,
        port: None,
        username: Some(client_id),
        password: None,
        remote_path: None,
        access_token: Some(tokens.access_token),
        refresh_token: tokens.refresh_token,
        auto_upload: None,
        enabled: Some(true),
    };

    // Persist tokens
    sqlx::query("DELETE FROM cloud_settings")
        .execute(&state.pool)
        .await
        .map_err(|e| format!("failed to clear cloud settings: {e}"))?;

    sqlx::query(
        "INSERT INTO cloud_settings \
         (provider, server_url, port, username, password, remote_path, \
          access_token, refresh_token, auto_upload, enabled) \
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(&settings.provider)
    .bind(&settings.server_url)
    .bind(settings.port)
    .bind(&settings.username)
    .bind(&settings.password)
    .bind(&settings.remote_path)
    .bind(&settings.access_token)
    .bind(&settings.refresh_token)
    .bind(&settings.auto_upload)
    .bind(settings.enabled)
    .execute(&state.pool)
    .await
    .map_err(|e| format!("failed to save OAuth tokens: {e}"))?;

    info!(provider = %provider, "OAuth tokens saved");
    Ok(settings)
}

async fn get_cloud_settings_inner(pool: &SqlitePool) -> Result<Option<CloudSettings>, String> {
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
    .fetch_optional(pool)
    .await
    .map_err(|e| format!("failed to read cloud settings: {e}"))?;

    Ok(row.map(|r| CloudSettings {
        provider: r.0,
        server_url: r.1,
        port: r.2,
        username: r.3,
        password: r.4,
        remote_path: r.5,
        access_token: r.6,
        refresh_token: r.7,
        auto_upload: r.8,
        enabled: r.9,
    }))
}

// ---------------------------------------------------------------------------
// Auto Backup Settings
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct AutoBackupSettings {
    pub enabled: bool,
    pub interval_hours: i64,
    pub max_backups: i64,
    pub last_backup_at: Option<String>,
}

#[tauri::command]
pub async fn get_auto_backup_settings(
    state: tauri::State<'_, BackupCommandState>,
) -> Result<AutoBackupSettings, String> {
    let row = sqlx::query_as::<_, (bool, i64, i64, Option<String>)>(
        "SELECT enabled, interval_hours, max_backups, last_backup_at FROM auto_backup_settings WHERE id = 1",
    )
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| format!("failed to read auto backup settings: {e}"))?;

    let row = row.unwrap_or((false, 24, 5, None));
    Ok(AutoBackupSettings {
        enabled: row.0,
        interval_hours: row.1,
        max_backups: row.2,
        last_backup_at: row.3,
    })
}

#[tauri::command]
pub async fn update_auto_backup_settings(
    state: tauri::State<'_, BackupCommandState>,
    enabled: bool,
    interval_hours: i64,
) -> Result<(), String> {
    if ![6, 12, 24, 168].contains(&interval_hours) {
        return Err("interval_hours must be one of: 6, 12, 24, 168".to_string());
    }

    sqlx::query(
        "UPDATE auto_backup_settings SET enabled = ?, interval_hours = ?, updated_at = datetime('now') WHERE id = 1",
    )
    .bind(enabled)
    .bind(interval_hours)
    .execute(&state.pool)
    .await
    .map_err(|e| format!("failed to update auto backup settings: {e}"))?;

    info!(enabled = enabled, interval_hours = interval_hours, "Auto backup settings updated");
    Ok(())
}

/// Read auto backup settings directly from pool (for background scheduler).
pub async fn read_auto_backup_settings(
    pool: &SqlitePool,
) -> Result<AutoBackupSettings, String> {
    let row = sqlx::query_as::<_, (bool, i64, i64, Option<String>)>(
        "SELECT enabled, interval_hours, max_backups, last_backup_at FROM auto_backup_settings WHERE id = 1",
    )
    .fetch_optional(pool)
    .await
    .map_err(|e| format!("failed to read auto backup settings: {e}"))?;

    let row = row.unwrap_or((false, 24, 5, None));
    Ok(AutoBackupSettings {
        enabled: row.0,
        interval_hours: row.1,
        max_backups: row.2,
        last_backup_at: row.3,
    })
}

/// Update last_backup_at timestamp after a successful auto backup.
pub async fn update_auto_backup_last_run(pool: &SqlitePool) -> Result<(), String> {
    sqlx::query(
        "UPDATE auto_backup_settings SET last_backup_at = datetime('now'), updated_at = datetime('now') WHERE id = 1",
    )
    .execute(pool)
    .await
    .map_err(|e| format!("failed to update auto backup last run: {e}"))?;
    Ok(())
}

/// Factory helper for main.rs state creation.
pub fn create_backup_state(
    pool: SqlitePool,
    backup_dir: PathBuf,
    encryption_state: Arc<EncryptionAppService>,
) -> BackupCommandState {
    BackupCommandState::new(pool, backup_dir, encryption_state)
}
