use crate::application::{
    dtos::{PrepaidDetailDto, TopUpRecordDto, TopUpRequest},
    services::PrepaidService,
};
use crate::infrastructure::repositories::{
    SqliteAccountRepository, SqlitePrepaidRepository, SqliteTransactionRepository,
};
use sqlx::sqlite::SqlitePool;
use std::sync::Arc;
use tauri::State;
use uuid::Uuid;

type ConcretePrepaidService =
    PrepaidService<SqlitePrepaidRepository, SqliteAccountRepository, SqliteTransactionRepository>;

pub struct PrepaidCommandState {
    // TODO: will be used when prepaid commands need direct pool access
    #[allow(dead_code)]
    pool: SqlitePool,
    prepaid_service: ConcretePrepaidService,
}

impl PrepaidCommandState {
    pub fn from_pool(pool: SqlitePool) -> Self {
        let prepaid_repo = Arc::new(SqlitePrepaidRepository::new(pool.clone()));
        let account_repo = Arc::new(SqliteAccountRepository::new(pool.clone()));
        let transaction_repo = Arc::new(SqliteTransactionRepository::new(pool.clone()));

        Self {
            prepaid_service: PrepaidService::new(prepaid_repo, account_repo, transaction_repo),
            pool,
        }
    }

    pub fn service(&self) -> &ConcretePrepaidService {
        &self.prepaid_service
    }

    // TODO: will be used when prepaid commands need direct pool access
    #[allow(dead_code)]
    pub fn pool(&self) -> &SqlitePool {
        &self.pool
    }
}

pub async fn create_default_state_from_pool(pool: SqlitePool) -> sqlx::Result<PrepaidCommandState> {
    Ok(PrepaidCommandState::from_pool(pool))
}

#[tauri::command]
pub async fn top_up(
    state: State<'_, PrepaidCommandState>,
    request: TopUpRequest,
) -> Result<Uuid, String> {
    state
        .service()
        .top_up(request)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn get_prepaid_detail(
    state: State<'_, PrepaidCommandState>,
    account_id: String,
) -> Result<PrepaidDetailDto, String> {
    let account_id = Uuid::parse_str(&account_id).map_err(|e| e.to_string())?;
    state
        .service()
        .get_prepaid_detail(account_id)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn get_top_up_records(
    state: State<'_, PrepaidCommandState>,
    account_id: String,
) -> Result<Vec<TopUpRecordDto>, String> {
    let account_id = Uuid::parse_str(&account_id).map_err(|e| e.to_string())?;
    state
        .service()
        .get_top_up_records(account_id)
        .await
        .map_err(|e| e.to_string())
}
