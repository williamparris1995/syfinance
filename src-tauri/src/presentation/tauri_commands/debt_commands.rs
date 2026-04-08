use crate::application::{
    dtos::{CreateDebtDto, DebtDto, RecordPaymentDto, UpcomingPaymentDto},
    services::DebtService,
};
use crate::infrastructure::repositories::{SqliteDebtRepository, SqliteReminderRepository};
use sqlx::sqlite::{SqliteConnectOptions, SqlitePool, SqlitePoolOptions};
use std::{str::FromStr, sync::Arc};
use tauri::State;
use uuid::Uuid;

pub type DebtServiceType = DebtService<SqliteDebtRepository, SqliteReminderRepository>;

pub struct AppState {
    service: DebtServiceType,
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
        let debt_repo = Arc::new(SqliteDebtRepository::new(pool.clone()));
        let reminder_repo = Arc::new(SqliteReminderRepository::new(pool));

        Self {
            service: DebtService::new(debt_repo, reminder_repo),
        }
    }

    pub fn service(&self) -> &DebtServiceType {
        &self.service
    }
}

pub async fn create_default_state() -> sqlx::Result<AppState> {
    AppState::create_default().await
}

pub async fn create_debt_with_state(
    state: &AppState,
    dto: CreateDebtDto,
) -> Result<DebtDto, String> {
    let debt_id = state
        .service()
        .create_debt(dto)
        .await
        .map_err(|error| error.to_string())?;

    state
        .service()
        .get_debt(debt_id)
        .await
        .map_err(|error| error.to_string())
}

pub async fn get_debt_with_state(state: &AppState, id: Uuid) -> Result<DebtDto, String> {
    state
        .service()
        .get_debt(id)
        .await
        .map_err(|error| error.to_string())
}

pub async fn list_debts_with_state(state: &AppState) -> Result<Vec<DebtDto>, String> {
    state
        .service()
        .list_debts()
        .await
        .map_err(|error| error.to_string())
}

pub async fn record_payment_with_state(
    state: &AppState,
    dto: RecordPaymentDto,
) -> Result<(), String> {
    state
        .service()
        .record_payment(dto)
        .await
        .map_err(|error| error.to_string())
}

pub async fn get_upcoming_payments_with_state(
    state: &AppState,
    days_ahead: i64,
) -> Result<Vec<UpcomingPaymentDto>, String> {
    state
        .service()
        .get_upcoming_payments(days_ahead)
        .await
        .map(|payments| {
            payments
                .into_iter()
                .map(|(debt, payment)| UpcomingPaymentDto { debt, payment })
                .collect()
        })
        .map_err(|error| error.to_string())
}

#[tauri::command]
pub async fn create_debt(
    state: State<'_, AppState>,
    dto: CreateDebtDto,
) -> Result<DebtDto, String> {
    create_debt_with_state(state.inner(), dto).await
}

#[tauri::command]
pub async fn get_debt(state: State<'_, AppState>, id: Uuid) -> Result<DebtDto, String> {
    get_debt_with_state(state.inner(), id).await
}

#[tauri::command]
pub async fn list_debts(state: State<'_, AppState>) -> Result<Vec<DebtDto>, String> {
    list_debts_with_state(state.inner()).await
}

#[tauri::command]
pub async fn record_payment(
    state: State<'_, AppState>,
    dto: RecordPaymentDto,
) -> Result<(), String> {
    record_payment_with_state(state.inner(), dto).await
}

#[tauri::command]
pub async fn get_upcoming_payments(
    state: State<'_, AppState>,
    days_ahead: i64,
) -> Result<Vec<UpcomingPaymentDto>, String> {
    get_upcoming_payments_with_state(state.inner(), days_ahead).await
}
