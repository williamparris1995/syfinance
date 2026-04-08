use crate::application::{
    dtos::{CreateTransactionDto, TransactionDto},
    services::TransactionService,
};
use crate::infrastructure::repositories::{SqliteAccountRepository, SqliteTransactionRepository};
use std::{str::FromStr, sync::Arc};
use tauri::State;
use uuid::Uuid;

pub struct TransactionCommandState {
    service: Arc<TransactionService>,
}

impl TransactionCommandState {
    pub fn from_service(service: TransactionService) -> Self {
        Self {
            service: Arc::new(service),
        }
    }

    pub fn service(&self) -> &TransactionService {
        self.service.as_ref()
    }

    pub async fn create_default_state() -> sqlx::Result<Self> {
        let options = sqlx::sqlite::SqliteConnectOptions::from_str("sqlite::memory:")?
            .create_if_missing(true);

        let pool = sqlx::sqlite::SqlitePoolOptions::new()
            .max_connections(1)
            .connect_with(options)
            .await?;

        sqlx::migrate!("./migrations").run(&pool).await?;

        Ok(Self::from_pool(pool))
    }

    pub fn from_pool(pool: sqlx::SqlitePool) -> Self {
        let account_repo = Arc::new(SqliteAccountRepository::new(pool.clone()));
        let transaction_repo = Arc::new(SqliteTransactionRepository::new(pool));
        Self::from_service(TransactionService::new(transaction_repo, account_repo))
    }
}

pub async fn create_default_state() -> sqlx::Result<TransactionCommandState> {
    TransactionCommandState::create_default_state().await
}

pub async fn create_transaction_with_service(
    service: &TransactionService,
    dto: CreateTransactionDto,
) -> Result<Uuid, String> {
    service
        .create_transaction(dto)
        .await
        .map_err(|e| e.to_string())
}

pub async fn get_transaction_with_service(
    service: &TransactionService,
    id: Uuid,
) -> Result<TransactionDto, String> {
    service.get_transaction(id).await.map_err(|e| e.to_string())
}

pub async fn list_transactions_with_service(
    service: &TransactionService,
) -> Result<Vec<TransactionDto>, String> {
    service.list_transactions().await.map_err(|e| e.to_string())
}

pub async fn get_transactions_by_account_with_service(
    service: &TransactionService,
    account_id: Uuid,
) -> Result<Vec<TransactionDto>, String> {
    service
        .get_transactions_by_account(account_id)
        .await
        .map_err(|e| e.to_string())
}

pub async fn get_transactions_by_date_range_with_service(
    service: &TransactionService,
    start_date: chrono::NaiveDate,
    end_date: chrono::NaiveDate,
) -> Result<Vec<TransactionDto>, String> {
    service
        .get_transactions_by_date_range(start_date, end_date)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn create_transaction(
    state: State<'_, TransactionCommandState>,
    dto: CreateTransactionDto,
) -> Result<Uuid, String> {
    create_transaction_with_service(state.service(), dto).await
}

#[tauri::command]
pub async fn get_transaction(
    state: State<'_, TransactionCommandState>,
    id: Uuid,
) -> Result<TransactionDto, String> {
    get_transaction_with_service(state.service(), id).await
}

#[tauri::command]
pub async fn list_transactions(
    state: State<'_, TransactionCommandState>,
) -> Result<Vec<TransactionDto>, String> {
    list_transactions_with_service(state.service()).await
}

#[tauri::command]
pub async fn get_transactions_by_account(
    state: State<'_, TransactionCommandState>,
    account_id: Uuid,
) -> Result<Vec<TransactionDto>, String> {
    get_transactions_by_account_with_service(state.service(), account_id).await
}

#[tauri::command]
pub async fn get_transactions_by_date_range(
    state: State<'_, TransactionCommandState>,
    start_date: chrono::NaiveDate,
    end_date: chrono::NaiveDate,
) -> Result<Vec<TransactionDto>, String> {
    get_transactions_by_date_range_with_service(state.service(), start_date, end_date).await
}
