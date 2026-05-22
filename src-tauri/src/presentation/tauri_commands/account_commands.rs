use crate::application::{
    dtos::{AccountBalanceDto, AccountDto, CreateAccountDto, UpdateAccountDto},
    services::{AccountService, AccountServiceError},
};
use crate::domain::aggregates::Ownership;
use crate::infrastructure::repositories::{SqliteAccountRepository, SqliteCurrencyRepository};
use sqlx::sqlite::{SqliteConnectOptions, SqlitePool, SqlitePoolOptions};
use std::{str::FromStr, sync::Arc};
use tauri::State;
use uuid::Uuid;

pub type AccountServiceType = AccountService<SqliteAccountRepository, SqliteCurrencyRepository>;

pub struct AppState {
    pool: SqlitePool,
    account_service: AccountServiceType,
}

impl AppState {
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
        let account_repo = Arc::new(SqliteAccountRepository::new(pool.clone()));
        let currency_repo = Arc::new(SqliteCurrencyRepository::new(pool.clone()));

        Self {
            account_service: AccountService::new(account_repo, currency_repo),
            pool,
        }
    }

    pub fn service(&self) -> &AccountServiceType {
        &self.account_service
    }

    pub fn pool(&self) -> &SqlitePool {
        &self.pool
    }
}

pub async fn create_account_with_state(
    state: &AppState,
    dto: CreateAccountDto,
) -> Result<AccountDto, String> {
    state
        .service()
        .create_account(state.pool(), dto)
        .await
        .map_err(|error: AccountServiceError| error.to_string())
}

pub async fn update_account_with_state(
    state: &AppState,
    id: Uuid,
    dto: UpdateAccountDto,
) -> Result<AccountDto, String> {
    state
        .service()
        .update_account(state.pool(), id, dto)
        .await
        .map_err(|error: AccountServiceError| error.to_string())
}

pub async fn delete_account_with_state(state: &AppState, id: Uuid) -> Result<(), String> {
    state
        .service()
        .delete_account(state.pool(), id)
        .await
        .map_err(|error: AccountServiceError| error.to_string())
}

pub async fn get_account_with_state(state: &AppState, id: Uuid) -> Result<AccountDto, String> {
    state
        .service()
        .get_account(id)
        .await
        .map_err(|error: AccountServiceError| error.to_string())
}

pub async fn list_accounts_with_state(state: &AppState) -> Result<Vec<AccountDto>, String> {
    state
        .service()
        .list_accounts()
        .await
        .map_err(|error: AccountServiceError| error.to_string())
}

pub async fn get_account_balance_with_state(
    state: &AppState,
    id: Uuid,
) -> Result<AccountBalanceDto, String> {
    state
        .service()
        .get_account_balance(id)
        .await
        .map(AccountBalanceDto::from)
        .map_err(|error: AccountServiceError| error.to_string())
}

pub async fn list_accounts_by_ownership_with_state(
    state: &AppState,
    ownership: Ownership,
) -> Result<Vec<AccountDto>, String> {
    state
        .service()
        .list_accounts_by_ownership(ownership)
        .await
        .map_err(|error: AccountServiceError| error.to_string())
}

#[tauri::command]
pub async fn create_account(
    state: State<'_, AppState>,
    dto: CreateAccountDto,
) -> Result<AccountDto, String> {
    create_account_with_state(state.inner(), dto).await
}

#[tauri::command]
pub async fn update_account(
    state: State<'_, AppState>,
    id: Uuid,
    dto: UpdateAccountDto,
) -> Result<AccountDto, String> {
    update_account_with_state(state.inner(), id, dto).await
}

#[tauri::command]
pub async fn delete_account(state: State<'_, AppState>, id: Uuid) -> Result<(), String> {
    delete_account_with_state(state.inner(), id).await
}

#[tauri::command]
pub async fn get_account(state: State<'_, AppState>, id: Uuid) -> Result<AccountDto, String> {
    get_account_with_state(state.inner(), id).await
}

#[tauri::command]
pub async fn list_accounts(state: State<'_, AppState>) -> Result<Vec<AccountDto>, String> {
    list_accounts_with_state(state.inner()).await
}

#[tauri::command]
pub async fn get_account_balance(
    state: State<'_, AppState>,
    id: Uuid,
) -> Result<AccountBalanceDto, String> {
    get_account_balance_with_state(state.inner(), id).await
}

#[tauri::command]
pub async fn list_accounts_by_ownership(
    state: State<'_, AppState>,
    ownership: Ownership,
) -> Result<Vec<AccountDto>, String> {
    list_accounts_by_ownership_with_state(state.inner(), ownership).await
}
