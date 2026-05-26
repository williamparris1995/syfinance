use crate::application::{
    dtos::{CreateSecurityDto, HoldingDto, HoldingTradeDto, SecurityDto},
    services::HoldingService,
};
use crate::infrastructure::repositories::{
    SqliteAccountRepository, SqliteHoldingRepository, SqliteSecurityRepository,
    SqliteTransactionRepository,
};
use rust_decimal::Decimal;
use sqlx::sqlite::SqlitePool;
use std::sync::Arc;
use tauri::State;
use uuid::Uuid;

pub struct AppState {
    pub pool: SqlitePool,
    holding_service: HoldingService,
}

impl AppState {
    pub fn from_pool(pool: SqlitePool) -> Self {
        let security_repo = Arc::new(SqliteSecurityRepository::new(pool.clone()));
        let holding_repo = Arc::new(SqliteHoldingRepository::new(pool.clone()));
        let account_repo = Arc::new(SqliteAccountRepository::new(pool.clone()));
        let transaction_repo = Arc::new(SqliteTransactionRepository::new(pool.clone()));
        Self {
            holding_service: HoldingService::new(security_repo, holding_repo, account_repo, transaction_repo),
            pool,
        }
    }

    pub fn service(&self) -> &HoldingService { &self.holding_service }
    pub fn pool(&self) -> &SqlitePool { &self.pool }
}

pub async fn create_default_state_from_pool(pool: SqlitePool) -> sqlx::Result<AppState> {
    Ok(AppState::from_pool(pool))
}

#[tauri::command]
pub async fn create_security(state: State<'_, AppState>, dto: CreateSecurityDto) -> Result<SecurityDto, String> {
    state.service().create_security(dto).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn list_securities(state: State<'_, AppState>) -> Result<Vec<SecurityDto>, String> {
    state.service().list_securities().await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn update_security_price(state: State<'_, AppState>, id: Uuid, price: Decimal) -> Result<(), String> {
    state.service().update_security_price(id, price).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn buy_holding(state: State<'_, AppState>, dto: HoldingTradeDto) -> Result<Uuid, String> {
    state.service().buy(dto).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn sell_holding(state: State<'_, AppState>, dto: HoldingTradeDto) -> Result<Uuid, String> {
    state.service().sell(dto).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn list_holdings(state: State<'_, AppState>) -> Result<Vec<HoldingDto>, String> {
    state.service().list_holdings().await.map_err(|e| e.to_string())
}
