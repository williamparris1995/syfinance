use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

// DTOs for sync operations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EntityChange {
    pub entity_type: String,
    pub entity_id: String,
    pub operation: ChangeOperation,
    pub data: serde_json::Value,
    pub timestamp: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ChangeOperation {
    Create,
    Update,
    Delete,
}

#[derive(Debug, Deserialize)]
pub struct PushRequest {
    pub changes: Vec<EntityChange>,
}

#[derive(Debug, Serialize)]
pub struct PushResponse {
    pub synced_count: usize,
    pub conflicts: Vec<Conflict>,
}

#[derive(Debug, Serialize)]
pub struct Conflict {
    pub entity_type: String,
    pub entity_id: String,
    pub reason: String,
}

#[derive(Debug, Deserialize)]
pub struct PullRequest {
    pub last_sync_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Serialize)]
pub struct PullResponse {
    pub changes: Vec<EntityChange>,
}

#[derive(Debug, Serialize)]
pub struct SyncStatus {
    pub last_sync_at: Option<DateTime<Utc>>,
    pub pending_changes: usize,
    pub is_syncing: bool,
}

#[derive(Debug, Serialize)]
pub struct RegisterResponse {
    pub account_id: String,
    pub device_id: String,
}
