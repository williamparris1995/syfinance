use crate::application::{
    dtos::{CreateTransactionDto, TransactionDto},
    services::TransactionService,
};
use crate::infrastructure::repositories::{SqliteAccountRepository, SqliteTransactionRepository};
use rust_decimal::Decimal;
use std::{str::FromStr, sync::Arc};
use tauri::State;
use uuid::Uuid;

const DATE_FORMAT: &str = "%Y-%m-%d";

fn parse_amount(amount: &str) -> Result<Decimal, String> {
    Decimal::from_str(amount).map_err(|e| format!("invalid amount: {}", e))
}

fn parse_date(date: &str) -> Result<chrono::NaiveDate, String> {
    chrono::NaiveDate::parse_from_str(date, DATE_FORMAT)
        .map_err(|e| format!("invalid date format: {}", e))
}

fn parse_uuid(id: &str, field_name: &str) -> Result<uuid::Uuid, String> {
    uuid::Uuid::parse_str(id).map_err(|e| format!("invalid {}: {}", field_name, e))
}

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

pub async fn create_default_state_from_pool(
    pool: sqlx::SqlitePool,
) -> sqlx::Result<TransactionCommandState> {
    Ok(TransactionCommandState::from_pool(pool))
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

pub async fn update_transaction_with_service(
    service: &TransactionService,
    id: Uuid,
    dto: CreateTransactionDto,
) -> Result<Uuid, String> {
    service
        .update_transaction(id, dto)
        .await
        .map_err(|e| e.to_string())
}

pub async fn delete_transaction_with_service(
    service: &TransactionService,
    id: Uuid,
) -> Result<(), String> {
    service
        .delete_transaction(id)
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

#[tauri::command]
#[allow(clippy::too_many_arguments)]
pub async fn create_simple_income(
    state: State<'_, TransactionCommandState>,
    debit_account_id: String,
    credit_account_id: String,
    amount: String,
    date: String,
    description: String,
) -> Result<String, String> {
    use crate::application::dtos::SimpleIncomeDto;

    let amount = parse_amount(&amount)?;
    let date = parse_date(&date)?;
    let debit_account_id = parse_uuid(&debit_account_id, "debit_account_id")?;
    let credit_account_id = parse_uuid(&credit_account_id, "credit_account_id")?;

    let dto = SimpleIncomeDto {
        debit_account_id,
        credit_account_id,
        amount,
        date,
        description,
    };

    state
        .service()
        .create_income(dto)
        .await
        .map(|id| id.to_string())
        .map_err(|e| e.to_string())
}

#[tauri::command]
#[allow(clippy::too_many_arguments)]
pub async fn create_simple_expense(
    state: State<'_, TransactionCommandState>,
    debit_account_id: String,
    credit_account_id: String,
    amount: String,
    date: String,
    description: String,
) -> Result<String, String> {
    use crate::application::dtos::SimpleExpenseDto;

    let amount = parse_amount(&amount)?;
    let date = parse_date(&date)?;
    let debit_account_id = parse_uuid(&debit_account_id, "debit_account_id")?;
    let credit_account_id = parse_uuid(&credit_account_id, "credit_account_id")?;

    let dto = SimpleExpenseDto {
        debit_account_id,
        credit_account_id,
        amount,
        date,
        description,
    };

    state
        .service()
        .create_expense(dto)
        .await
        .map(|id| id.to_string())
        .map_err(|e| e.to_string())
}

#[tauri::command]
#[allow(clippy::too_many_arguments)]
pub async fn create_simple_transfer(
    state: State<'_, TransactionCommandState>,
    from_account_id: String,
    to_account_id: String,
    amount: String,
    date: String,
    description: String,
) -> Result<String, String> {
    use crate::application::dtos::SimpleTransferDto;

    let amount = parse_amount(&amount)?;
    let date = parse_date(&date)?;
    let from_account_id = parse_uuid(&from_account_id, "from_account_id")?;
    let to_account_id = parse_uuid(&to_account_id, "to_account_id")?;

    let dto = SimpleTransferDto {
        from_account_id,
        to_account_id,
        amount,
        date,
        description,
    };

    state
        .service()
        .create_transfer(dto)
        .await
        .map(|id| id.to_string())
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn update_transaction(
    state: State<'_, TransactionCommandState>,
    id: String,
    dto: CreateTransactionDto,
) -> Result<String, String> {
    let id = parse_uuid(&id, "id")?;
    update_transaction_with_service(state.service(), id, dto)
        .await
        .map(|id| id.to_string())
}

#[tauri::command]
pub async fn delete_transaction(
    state: State<'_, TransactionCommandState>,
    id: String,
) -> Result<(), String> {
    let id = parse_uuid(&id, "id")?;
    delete_transaction_with_service(state.service(), id).await
}
