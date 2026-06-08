use crate::application::{
    dtos::{AccountBalanceDto, AccountDto, CreateAccountDto, PatchAccountDto},
    services::{AccountService, AccountServiceError},
};
use crate::domain::aggregates::Ownership;
use crate::domain::repositories::AccountRepository;
use crate::infrastructure::repositories::{SqliteAccountRepository, SqliteCurrencyRepository};
use serde::{Deserialize, Serialize};
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
    // TODO: will be used when integration tests need account command state
    #[allow(dead_code)]
    pub async fn create_default() -> sqlx::Result<Self> {
        // Run migrations with FK checks disabled (same pattern as main.rs)
        let migrate_options = SqliteConnectOptions::from_str("sqlite::memory:")?
            .create_if_missing(true)
            .foreign_keys(false);
        let pool = SqlitePoolOptions::new()
            .max_connections(1)
            .connect_with(migrate_options)
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

    pub fn repository(&self) -> SqliteAccountRepository {
        SqliteAccountRepository::new(self.pool.clone())
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
    dto: PatchAccountDto,
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

pub async fn list_accounts_with_balances_with_state(
    state: &AppState,
) -> Result<Vec<AccountDto>, String> {
    state
        .service()
        .list_accounts_with_balances()
        .await
        .map_err(|e| e.to_string())
}

pub async fn archive_account_with_state(state: &AppState, id: Uuid) -> Result<AccountDto, String> {
    state
        .service()
        .archive_account(state.pool(), id)
        .await
        .map_err(|error: AccountServiceError| error.to_string())
}

pub async fn hide_account_with_state(state: &AppState, id: Uuid) -> Result<AccountDto, String> {
    state
        .service()
        .hide_account(state.pool(), id)
        .await
        .map_err(|error: AccountServiceError| error.to_string())
}

pub async fn reactivate_account_with_state(
    state: &AppState,
    id: Uuid,
) -> Result<AccountDto, String> {
    state
        .service()
        .reactivate_account(state.pool(), id)
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
    dto: PatchAccountDto,
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

#[tauri::command]
pub async fn list_accounts_with_balances(
    state: State<'_, AppState>,
) -> Result<Vec<AccountDto>, String> {
    list_accounts_with_balances_with_state(&state).await
}

pub async fn setup_preset_investment_accounts_with_state(
    state: &AppState,
    currency_code: Option<String>,
) -> Result<Vec<AccountDto>, String> {
    let code = currency_code.as_deref().unwrap_or("CNY");
    state
        .service()
        .create_preset_investment_accounts(state.pool(), code)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn setup_preset_investment_accounts(
    state: State<'_, AppState>,
    currency_code: Option<String>,
) -> Result<Vec<AccountDto>, String> {
    setup_preset_investment_accounts_with_state(state.inner(), currency_code).await
}

#[tauri::command]
pub async fn archive_account(state: State<'_, AppState>, id: Uuid) -> Result<AccountDto, String> {
    archive_account_with_state(state.inner(), id).await
}

#[tauri::command]
pub async fn hide_account(state: State<'_, AppState>, id: Uuid) -> Result<AccountDto, String> {
    hide_account_with_state(state.inner(), id).await
}

#[tauri::command]
pub async fn reactivate_account(
    state: State<'_, AppState>,
    id: Uuid,
) -> Result<AccountDto, String> {
    reactivate_account_with_state(state.inner(), id).await
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BalanceHistoryPoint {
    pub date: String,
    pub balance: String,
}

#[tauri::command]
pub async fn get_account_balance_history(
    state: State<'_, AppState>,
    account_id: String,
    days: Option<i32>,
) -> Result<Vec<BalanceHistoryPoint>, String> {
    let id = Uuid::parse_str(&account_id).map_err(|e| format!("Invalid account ID: {}", e))?;
    let days = days.unwrap_or(30);

    let repo = state.inner().repository();
    let history = repo
        .get_balance_history(id, days)
        .await
        .map_err(|e| format!("Failed to get balance history: {}", e))?;

    Ok(history
        .into_iter()
        .map(|(date, balance)| BalanceHistoryPoint {
            date,
            balance: balance.to_string(),
        })
        .collect())
}
