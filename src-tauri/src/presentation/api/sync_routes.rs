use axum::{
    extract::State,
    http::Method,
    routing::{get, post},
    Json, Router,
};
use chrono::Utc;
use std::sync::Arc;
use tokio::sync::RwLock;
use tower_http::cors::{Any, CorsLayer};

use super::dtos::{
    EntityChange, PullRequest, PullResponse, PushRequest, PushResponse, RegisterResponse,
    SyncStatus,
};
use super::error::ApiError;
use uuid::Uuid;

// Placeholder sync state - in real implementation, this would use SyncService
#[derive(Clone)]
pub struct SyncState {
    last_sync: Arc<RwLock<Option<chrono::DateTime<Utc>>>>,
    pending_changes: Arc<RwLock<Vec<EntityChange>>>,
    is_syncing: Arc<RwLock<bool>>,
}

impl SyncState {
    pub fn new() -> Self {
        Self {
            last_sync: Arc::new(RwLock::new(None)),
            pending_changes: Arc::new(RwLock::new(Vec::new())),
            is_syncing: Arc::new(RwLock::new(false)),
        }
    }
}

impl Default for SyncState {
    fn default() -> Self {
        Self::new()
    }
}

pub fn create_sync_routes() -> Router {
    let state = SyncState::new();
    
    // Configure CORS
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods([Method::GET, Method::POST, Method::OPTIONS])
        .allow_headers(Any);
    
    Router::new()
        .route("/api/register", post(register))
        .route("/api/sync/push", post(push_changes))
        .route("/api/sync/pull", post(pull_changes))
        .route("/api/sync/status", get(sync_status))
        .layer(cors)
        .with_state(state)
}

async fn push_changes(
    State(state): State<SyncState>,
    Json(payload): Json<PushRequest>,
) -> Result<Json<PushResponse>, ApiError> {
    // LIMITATION: Authentication not implemented in Phase 1
    // Phase 2 will add device token validation
    
    let mut is_syncing = state.is_syncing.write().await;
    if *is_syncing {
        return Err(ApiError::BadRequest(
            "Sync already in progress".to_string(),
        ));
    }
    *is_syncing = true;
    drop(is_syncing);

    // LIMITATION: In-memory sync only (no database persistence)
    // Phase 2 will integrate SyncService with PostgreSQL repositories
    // Current implementation: Accept all changes and store in memory
    let synced_count = payload.changes.len();
    
    // Store changes temporarily
    let mut pending = state.pending_changes.write().await;
    pending.extend(payload.changes);
    drop(pending);

    // Update last sync time
    let mut last_sync = state.last_sync.write().await;
    *last_sync = Some(Utc::now());
    drop(last_sync);

    let mut is_syncing = state.is_syncing.write().await;
    *is_syncing = false;

    Ok(Json(PushResponse {
        synced_count,
        conflicts: Vec::new(),
    }))
}

async fn pull_changes(
    State(state): State<SyncState>,
    Json(payload): Json<PullRequest>,
) -> Result<Json<PullResponse>, ApiError> {
    // LIMITATION: Authentication not implemented in Phase 1
    // Phase 2 will add device token validation
    
    // LIMITATION: In-memory sync only (no database persistence)
    // Phase 2 will integrate SyncService with PostgreSQL repositories
    // Current implementation: Return in-memory changes newer than last_sync_at
    let pending = state.pending_changes.read().await;
    
    let changes: Vec<EntityChange> = if let Some(last_sync_at) = payload.last_sync_at {
        pending
            .iter()
            .filter(|change| change.timestamp > last_sync_at)
            .cloned()
            .collect()
    } else {
        pending.clone()
    };

    Ok(Json(PullResponse { changes }))
}

async fn sync_status(
    State(state): State<SyncState>,
) -> Result<Json<SyncStatus>, ApiError> {
    let last_sync = state.last_sync.read().await;
    let pending = state.pending_changes.read().await;
    let is_syncing = state.is_syncing.read().await;

    Ok(Json(SyncStatus {
        last_sync_at: *last_sync,
        pending_changes: pending.len(),
        is_syncing: *is_syncing,
    }))
}

async fn register() -> Result<Json<RegisterResponse>, ApiError> {
    // Generate new account_id and device_id
    let account_id = Uuid::new_v4().to_string();
    let device_id = Uuid::new_v4().to_string();

    Ok(Json(RegisterResponse {
        account_id,
        device_id,
    }))
}
