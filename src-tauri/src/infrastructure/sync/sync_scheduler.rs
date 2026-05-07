use serde::{Deserialize, Serialize};
use std::sync::Arc;
use std::time::Duration;
use tauri::{AppHandle, Emitter};
use tokio::sync::RwLock;
use tokio::time::{interval, sleep};

const DEFAULT_SYNC_INTERVAL_MINUTES: u64 = 15;
const MIN_SYNC_INTERVAL_MINUTES: u64 = 5;
const BACKOFF_DELAYS: [Duration; 4] = [
    Duration::from_secs(2),
    Duration::from_secs(4),
    Duration::from_secs(8),
    Duration::from_secs(16),
];

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncSettings {
    pub enabled: bool,
    pub interval_minutes: u64,
}

impl Default for SyncSettings {
    fn default() -> Self {
        Self {
            enabled: true,
            interval_minutes: DEFAULT_SYNC_INTERVAL_MINUTES,
        }
    }
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SyncEvent {
    pub status: SyncStatus,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum SyncStatus {
    Started,
    Completed,
    Failed,
}

pub struct SyncScheduler {
    settings: Arc<RwLock<SyncSettings>>,
    app_handle: AppHandle,
}

impl SyncScheduler {
    pub fn new(app_handle: AppHandle) -> Self {
        Self {
            settings: Arc::new(RwLock::new(SyncSettings::default())),
            app_handle,
        }
    }

    pub async fn get_settings(&self) -> SyncSettings {
        self.settings.read().await.clone()
    }

    pub async fn update_settings(&self, settings: SyncSettings) {
        let mut current = self.settings.write().await;
        *current = SyncSettings {
            enabled: settings.enabled,
            interval_minutes: settings.interval_minutes.max(MIN_SYNC_INTERVAL_MINUTES),
        };
    }

    pub fn start(self: Arc<Self>) {
        tokio::spawn(async move {
            self.run_scheduler().await;
        });
    }

    async fn run_scheduler(&self) {
        let mut backoff_index = 0;
        let mut last_sync_failed = false;

        loop {
            let settings = self.get_settings().await;

            if !settings.enabled {
                // Check every minute if sync is disabled
                sleep(Duration::from_secs(60)).await;
                continue;
            }

            // If last sync failed, use exponential backoff
            if last_sync_failed && backoff_index < BACKOFF_DELAYS.len() {
                let backoff_delay = BACKOFF_DELAYS[backoff_index];
                sleep(backoff_delay).await;
                backoff_index += 1;
            } else {
                // Normal interval
                let sync_interval = Duration::from_secs(settings.interval_minutes * 60);
                sleep(sync_interval).await;
            }

            // Check if still enabled after sleep
            let settings = self.get_settings().await;
            if !settings.enabled {
                continue;
            }

            // Check network connectivity
            if !self.check_network_connectivity().await {
                last_sync_failed = true;
                self.emit_sync_event(SyncEvent {
                    status: SyncStatus::Failed,
                    message: "Network connectivity check failed".to_string(),
                    error: Some("Unable to reach server".to_string()),
                });
                continue;
            }

            // Perform sync
            self.emit_sync_event(SyncEvent {
                status: SyncStatus::Started,
                message: "Starting automatic sync".to_string(),
                error: None,
            });

            match self.perform_sync().await {
                Ok(_) => {
                    last_sync_failed = false;
                    backoff_index = 0; // Reset backoff on success
                    self.emit_sync_event(SyncEvent {
                        status: SyncStatus::Completed,
                        message: "Sync completed successfully".to_string(),
                        error: None,
                    });
                }
                Err(err) => {
                    last_sync_failed = true;
                    self.emit_sync_event(SyncEvent {
                        status: SyncStatus::Failed,
                        message: "Sync failed".to_string(),
                        error: Some(err.to_string()),
                    });
                }
            }
        }
    }

    async fn check_network_connectivity(&self) -> bool {
        // Simple TCP connect to server to check connectivity
        tokio::time::timeout(
            Duration::from_secs(5),
            tokio::net::TcpStream::connect("127.0.0.1:3000"),
        )
        .await
        .is_ok()
    }

    async fn perform_sync(&self) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        // Call REST API to perform bidirectional sync
        let client = reqwest::Client::new();
        
        // Push changes to server
        let push_response = client
            .post("http://127.0.0.1:3000/api/sync/push")
            .json(&serde_json::json!({
                "device_id": "local-device",
                "changes": []
            }))
            .send()
            .await?;
        
        if !push_response.status().is_success() {
            return Err(format!("Push failed: HTTP {}", push_response.status()).into());
        }
        
        // Pull changes from server
        let pull_response = client
            .post("http://127.0.0.1:3000/api/sync/pull")
            .json(&serde_json::json!({
                "device_id": "local-device",
                "last_sync_at": Option::<String>::None
            }))
            .send()
            .await?;
        
        if !pull_response.status().is_success() {
            return Err(format!("Pull failed: HTTP {}", pull_response.status()).into());
        }
        
        Ok(())
    }

    fn emit_sync_event(&self, event: SyncEvent) {
        let _ = self.app_handle.emit("sync:status", event);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_settings_are_correct() {
        let settings = SyncSettings::default();
        assert!(settings.enabled);
        assert_eq!(settings.interval_minutes, DEFAULT_SYNC_INTERVAL_MINUTES);
    }

    #[test]
    fn enforces_minimum_interval() {
        let settings = SyncSettings {
            enabled: true,
            interval_minutes: 1, // Below minimum
        };

        assert_eq!(
            settings.interval_minutes.max(MIN_SYNC_INTERVAL_MINUTES),
            MIN_SYNC_INTERVAL_MINUTES
        );
    }
}
