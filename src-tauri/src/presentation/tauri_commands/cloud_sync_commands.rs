use std::sync::Arc;

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
