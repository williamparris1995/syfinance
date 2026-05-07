use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;

use crate::infrastructure::sync::{SyncScheduler, SyncSettings};

pub use crate::infrastructure::sync::SyncSettings as SyncSettingsDto;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncStatusDto {
    pub last_sync_at: Option<DateTime<Utc>>,
    pub is_syncing: bool,
    pub error: Option<String>,
}

#[derive(Clone)]
pub struct SyncCommandState {
    last_sync: Arc<RwLock<Option<DateTime<Utc>>>>,
    is_syncing: Arc<RwLock<bool>>,
    last_error: Arc<RwLock<Option<String>>>,
    scheduler: Option<Arc<SyncScheduler>>,
}

impl SyncCommandState {
    pub fn new() -> Self {
        Self {
            last_sync: Arc::new(RwLock::new(None)),
            is_syncing: Arc::new(RwLock::new(false)),
            last_error: Arc::new(RwLock::new(None)),
            scheduler: None,
        }
    }

    pub fn with_scheduler(mut self, scheduler: Arc<SyncScheduler>) -> Self {
        self.scheduler = Some(scheduler);
        self
    }
}

#[tauri::command]
pub async fn sync_to_server(
    state: tauri::State<'_, SyncCommandState>,
) -> Result<SyncStatusDto, String> {
    let mut is_syncing = state.is_syncing.write().await;
    if *is_syncing {
        return Err("Sync already in progress".to_string());
    }
    *is_syncing = true;
    drop(is_syncing);

    // Clear previous error
    let mut last_error = state.last_error.write().await;
    *last_error = None;
    drop(last_error);

    // Call REST API to push changes
    let client = reqwest::Client::new();
    let result = client
        .post("http://127.0.0.1:3000/api/sync/push")
        .json(&serde_json::json!({
            "device_id": "local-device",
            "changes": []
        }))
        .send()
        .await;

    let mut is_syncing = state.is_syncing.write().await;
    *is_syncing = false;
    drop(is_syncing);

    match result {
        Ok(response) => {
            if response.status().is_success() {
                let mut last_sync = state.last_sync.write().await;
                *last_sync = Some(Utc::now());
                drop(last_sync);

                Ok(SyncStatusDto {
                    last_sync_at: Some(Utc::now()),
                    is_syncing: false,
                    error: None,
                })
            } else {
                let error_msg = format!("Sync failed: HTTP {}", response.status());
                let mut last_error = state.last_error.write().await;
                *last_error = Some(error_msg.clone());
                Err(error_msg)
            }
        }
        Err(e) => {
            let error_msg = format!("Sync failed: Unable to connect - {}", e);
            let mut last_error = state.last_error.write().await;
            *last_error = Some(error_msg.clone());
            Err(error_msg)
        }
    }
}

#[tauri::command]
pub async fn sync_from_server(
    state: tauri::State<'_, SyncCommandState>,
) -> Result<SyncStatusDto, String> {
    let mut is_syncing = state.is_syncing.write().await;
    if *is_syncing {
        return Err("Sync already in progress".to_string());
    }
    *is_syncing = true;
    drop(is_syncing);

    // Clear previous error
    let mut last_error = state.last_error.write().await;
    *last_error = None;
    drop(last_error);

    // Call REST API to pull changes
    let client = reqwest::Client::new();
    let last_sync = state.last_sync.read().await;
    let result = client
        .post("http://127.0.0.1:3000/api/sync/pull")
        .json(&serde_json::json!({
            "device_id": "local-device",
            "last_sync_at": *last_sync
        }))
        .send()
        .await;
    drop(last_sync);

    let mut is_syncing = state.is_syncing.write().await;
    *is_syncing = false;
    drop(is_syncing);

    match result {
        Ok(response) => {
            if response.status().is_success() {
                let mut last_sync = state.last_sync.write().await;
                *last_sync = Some(Utc::now());
                drop(last_sync);

                Ok(SyncStatusDto {
                    last_sync_at: Some(Utc::now()),
                    is_syncing: false,
                    error: None,
                })
            } else {
                let error_msg = format!("Sync failed: HTTP {}", response.status());
                let mut last_error = state.last_error.write().await;
                *last_error = Some(error_msg.clone());
                Err(error_msg)
            }
        }
        Err(e) => {
            let error_msg = format!("Sync failed: Unable to connect - {}", e);
            let mut last_error = state.last_error.write().await;
            *last_error = Some(error_msg.clone());
            Err(error_msg)
        }
    }
}

#[tauri::command]
pub async fn get_sync_status(
    state: tauri::State<'_, SyncCommandState>,
) -> Result<SyncStatusDto, String> {
    let last_sync = state.last_sync.read().await;
    let is_syncing = state.is_syncing.read().await;
    let last_error = state.last_error.read().await;

    Ok(SyncStatusDto {
        last_sync_at: *last_sync,
        is_syncing: *is_syncing,
        error: last_error.clone(),
    })
}

pub fn create_default_state() -> SyncCommandState {
    SyncCommandState::new()
}

#[tauri::command]
pub async fn update_sync_settings(
    state: tauri::State<'_, SyncCommandState>,
    enabled: bool,
    interval_minutes: u64,
) -> Result<SyncSettingsDto, String> {
    if let Some(scheduler) = &state.scheduler {
        let settings = SyncSettings {
            enabled,
            interval_minutes,
        };
        scheduler.update_settings(settings.clone()).await;
        Ok(settings)
    } else {
        Err("Scheduler not initialized".to_string())
    }
}

#[tauri::command]
pub async fn get_sync_settings(
    state: tauri::State<'_, SyncCommandState>,
) -> Result<SyncSettingsDto, String> {
    if let Some(scheduler) = &state.scheduler {
        Ok(scheduler.get_settings().await)
    } else {
        Err("Scheduler not initialized".to_string())
    }
}
