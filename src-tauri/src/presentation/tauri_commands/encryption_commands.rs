use crate::application::services::EncryptionAppService;
use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;
use std::sync::Arc;

#[derive(Clone)]
pub struct EncryptionCommandState {
    pub service: Arc<EncryptionAppService>,
}

impl EncryptionCommandState {
    pub fn new(pool: SqlitePool) -> Self {
        Self {
            service: Arc::new(EncryptionAppService::new(pool)),
        }
    }
}

#[derive(Serialize)]
pub struct EncryptionStatus {
    pub enabled: bool,
    pub unlocked: bool,
}

#[tauri::command]
pub async fn get_encryption_status(
    state: tauri::State<'_, EncryptionCommandState>,
) -> Result<EncryptionStatus, String> {
    let enabled = state.service.is_enabled().await
        .map_err(|e: crate::application::services::EncryptionAppError| e.to_string())?;
    let unlocked = state.service.is_unlocked();
    Ok(EncryptionStatus { enabled, unlocked })
}

#[derive(Deserialize)]
pub struct SetupEncryptionPayload {
    pub password: String,
}

#[tauri::command]
pub async fn setup_encryption(
    state: tauri::State<'_, EncryptionCommandState>,
    payload: SetupEncryptionPayload,
) -> Result<(), String> {
    if payload.password.len() < 8 {
        return Err("Password must be at least 8 characters".to_string());
    }
    state.service.setup(&payload.password).await
        .map_err(|e: crate::application::services::EncryptionAppError| e.to_string())
}

#[derive(Deserialize)]
pub struct UnlockEncryptionPayload {
    pub password: String,
}

#[tauri::command]
pub async fn unlock_encryption(
    state: tauri::State<'_, EncryptionCommandState>,
    payload: UnlockEncryptionPayload,
) -> Result<(), String> {
    state.service.unlock(&payload.password).await
        .map_err(|e: crate::application::services::EncryptionAppError| e.to_string())
}

#[tauri::command]
pub async fn unlock_encryption_keychain(
    state: tauri::State<'_, EncryptionCommandState>,
) -> Result<(), String> {
    state.service.unlock_with_keychain().await
        .map_err(|e: crate::application::services::EncryptionAppError| e.to_string())
}

#[tauri::command]
pub async fn lock_encryption(
    state: tauri::State<'_, EncryptionCommandState>,
) -> Result<(), String> {
    state.service.lock()
        .map_err(|e: crate::application::services::EncryptionAppError| e.to_string())
}

#[derive(Deserialize)]
pub struct DisableEncryptionPayload {
    pub password: String,
}

#[tauri::command]
pub async fn disable_encryption(
    state: tauri::State<'_, EncryptionCommandState>,
    payload: DisableEncryptionPayload,
) -> Result<(), String> {
    state.service.disable(&payload.password).await
        .map_err(|e: crate::application::services::EncryptionAppError| e.to_string())
}

pub fn create_encryption_default_state(pool: SqlitePool) -> EncryptionCommandState {
    EncryptionCommandState::new(pool)
}
