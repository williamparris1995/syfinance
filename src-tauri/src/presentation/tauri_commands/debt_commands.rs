use crate::application::{
    dtos::{CreateDebtDto, DebtDto, RecordPaymentDto, UpdateDebtDto},
    services::DebtService,
};
use crate::infrastructure::repositories::{
    SqliteAccountRepository, SqliteDebtRepository, SqliteTransactionRepository,
};
use sqlx::sqlite::{SqliteConnectOptions, SqlitePool, SqlitePoolOptions};
use std::{str::FromStr, sync::Arc};
use tauri::State;
use uuid::Uuid;

pub struct AppState {
    #[allow(dead_code)]
    pool: SqlitePool,
    debt_service: DebtService,
}

impl AppState {
    // TODO: will be used when debt integration tests are added
    #[allow(dead_code)]
    pub async fn create_default() -> sqlx::Result<Self> {
        let options = SqliteConnectOptions::from_str("sqlite::memory:")?.create_if_missing(true);
        let pool = SqlitePoolOptions::new()
            .max_connections(1)
            .connect_with(options)
            .await?;

        sqlx::migrate!("./migrations").run(&pool).await?;

        Ok(Self::from_pool(pool))
    }

    pub fn from_pool(pool: SqlitePool) -> Self {
        let debt_repo = Arc::new(SqliteDebtRepository::new(pool.clone()));
        let account_repo = Arc::new(SqliteAccountRepository::new(pool.clone()));
        let transaction_repo = Arc::new(SqliteTransactionRepository::new(pool.clone()));

        Self {
            debt_service: DebtService::new(debt_repo, account_repo, transaction_repo),
            pool,
        }
    }

    pub fn service(&self) -> &DebtService {
        &self.debt_service
    }

    // TODO: will be used when debt commands need direct pool access
    #[allow(dead_code)]
    pub fn pool(&self) -> &SqlitePool {
        &self.pool
    }
}

// TODO: will be used when debt integration tests are added
#[allow(dead_code)]
pub async fn create_default_state() -> sqlx::Result<AppState> {
    AppState::create_default().await
}

pub async fn create_default_state_from_pool(pool: SqlitePool) -> sqlx::Result<AppState> {
    Ok(AppState::from_pool(pool))
}

#[tauri::command]
pub async fn create_debt(
    state: State<'_, AppState>,
    dto: CreateDebtDto,
) -> Result<DebtDto, String> {
    let account_id = dto.account_id;
    let _txn_id = state
        .service()
        .create_debt(dto)
        .await
        .map_err(|e| e.to_string())?;

    state
        .service()
        .get_debt(account_id)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn get_debt(state: State<'_, AppState>, id: Uuid) -> Result<DebtDto, String> {
    state
        .service()
        .get_debt(id)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn list_debts(state: State<'_, AppState>) -> Result<Vec<DebtDto>, String> {
    state
        .service()
        .list_debts()
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn record_payment(
    state: State<'_, AppState>,
    dto: RecordPaymentDto,
) -> Result<Uuid, String> {
    state
        .service()
        .record_payment(dto)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn get_upcoming_payments(
    state: State<'_, AppState>,
    days_ahead: i32,
) -> Result<Vec<DebtDto>, String> {
    state
        .service()
        .get_upcoming_payments(days_ahead)
        .await
        .map(|results| results.into_iter().map(|(debt, _)| debt).collect())
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn update_debt(
    state: State<'_, AppState>,
    account_id: Uuid,
    dto: UpdateDebtDto,
) -> Result<DebtDto, String> {
    state
        .service()
        .update_debt(account_id, dto)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn delete_debt(state: State<'_, AppState>, account_id: Uuid) -> Result<(), String> {
    state
        .service()
        .delete_debt(account_id)
        .await
        .map_err(|e| e.to_string())
}
