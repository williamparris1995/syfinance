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
    pub status: String,
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

    pub fn start(self: Arc<Self>) {
        tokio::spawn(async move {
            self.run_scheduler().await;
        });
        info!("Cloud sync scheduler started");
    }

    async fn run_scheduler(&self) {
        let mut backoff_index: usize = 0;

        loop {
            let settings = self.service.read_sync_settings().await;

            if !settings.auto_sync_enabled {
                tokio::time::sleep(DISABLED_CHECK_INTERVAL).await;
                continue;
            }

            let status = self.service.get_status().await;
            if !status.cloud_configured {
                tokio::time::sleep(DISABLED_CHECK_INTERVAL).await;
                continue;
            }

            let interval =
                Duration::from_secs((settings.interval_minutes.max(MIN_INTERVAL_MINUTES)) * 60);
            tokio::time::sleep(interval).await;

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
                    error!(error = %e, "Cloud sync failed");
                    self.emit_event("failed", "Sync failed", Some(&e.to_string()));

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
