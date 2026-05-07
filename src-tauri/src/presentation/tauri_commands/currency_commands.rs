use crate::domain::{
    repositories::CurrencyRepository,
    value_objects::{Currency, CurrencyValidationError},
};
use crate::infrastructure::repositories::SqliteCurrencyRepository;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use sqlx::sqlite::{SqliteConnectOptions, SqlitePool, SqlitePoolOptions};
use std::{str::FromStr, sync::Arc};
use tauri::State;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CurrencyDto {
    pub code: String,
    pub symbol: String,
    pub exchange_rate: String,
    pub updated_at: String,
}

impl CurrencyDto {
    pub fn from_currency_with_timestamp(currency: Currency, updated_at: String) -> Self {
        Self {
            code: currency.code,
            symbol: currency.symbol,
            exchange_rate: currency.exchange_rate.to_string(),
            updated_at,
        }
    }
}

pub struct CurrencyCommandState {
    pool: SqlitePool,
    currency_repository: Arc<SqliteCurrencyRepository>,
}

impl CurrencyCommandState {
    pub async fn create_default_state() -> sqlx::Result<Self> {
        let options = SqliteConnectOptions::from_str("sqlite::memory:")?.create_if_missing(true);
        let pool = SqlitePoolOptions::new()
            .max_connections(1)
            .connect_with(options)
            .await?;

        sqlx::migrate!("./migrations").run(&pool).await?;

        Ok(Self::from_pool(pool))
    }

    pub fn from_pool(pool: SqlitePool) -> Self {
        Self {
            currency_repository: Arc::new(SqliteCurrencyRepository::new(pool.clone())),
            pool,
        }
    }

    pub fn repository(&self) -> &SqliteCurrencyRepository {
        self.currency_repository.as_ref()
    }

    pub fn pool(&self) -> &SqlitePool {
        &self.pool
    }
}

pub async fn create_default_state() -> sqlx::Result<CurrencyCommandState> {
    CurrencyCommandState::create_default_state().await
}

fn currency_validation_error_message(error: CurrencyValidationError) -> String {
    match error {
        CurrencyValidationError::InvalidCode(code) => {
            format!("invalid currency code '{code}': expected 3 uppercase letters")
        }
    }
}

fn database_error_message(error: sqlx::Error) -> String {
    match error {
        sqlx::Error::RowNotFound => "currency not found".to_string(),
        sqlx::Error::Database(database_error) => match database_error.message() {
            "UNIQUE constraint failed: currencies.code" => {
                "currency already exists".to_string()
            }
            message => message.to_string(),
        },
        _ => "an unexpected database error occurred".to_string(),
    }
}

fn parse_exchange_rate(exchange_rate: &str) -> Result<Decimal, String> {
    Decimal::from_str(exchange_rate)
        .map_err(|_| format!("invalid exchange rate '{exchange_rate}'"))
}

pub async fn list_currencies_with_service(
    state: &CurrencyCommandState,
) -> Result<Vec<CurrencyDto>, String> {
    state
        .repository()
        .list_all_with_timestamps()
        .await
        .map(|currencies| {
            currencies
                .into_iter()
                .map(|(currency, updated_at)| CurrencyDto::from_currency_with_timestamp(currency, updated_at))
                .collect()
        })
        .map_err(database_error_message)
}

pub async fn add_currency_with_service(
    state: &CurrencyCommandState,
    code: String,
    symbol: String,
    exchange_rate: String,
) -> Result<(), String> {
    let exchange_rate = parse_exchange_rate(&exchange_rate)?;
    let currency = Currency::new(code, symbol, exchange_rate)
        .map_err(currency_validation_error_message)?;

    if state
        .repository()
        .find_by_code(&currency.code)
        .await
        .map_err(database_error_message)?
        .is_some()
    {
        return Err("currency already exists".to_string());
    }

    state
        .repository()
        .create(&currency)
        .await
        .map_err(database_error_message)
}

pub async fn update_currency_rate_with_service(
    state: &CurrencyCommandState,
    code: String,
    exchange_rate: String,
) -> Result<(), String> {
    let exchange_rate = parse_exchange_rate(&exchange_rate)?;

    let updated = state
        .repository()
        .update_rate(&code, exchange_rate)
        .await
        .map_err(database_error_message)?;

    if updated {
        Ok(())
    } else {
        Err("currency not found".to_string())
    }
}

#[tauri::command]
pub async fn list_currencies(
    state: State<'_, CurrencyCommandState>,
) -> Result<Vec<CurrencyDto>, String> {
    list_currencies_with_service(state.inner()).await
}

#[tauri::command]
pub async fn add_currency(
    state: State<'_, CurrencyCommandState>,
    code: String,
    symbol: String,
    exchange_rate: String,
) -> Result<(), String> {
    add_currency_with_service(state.inner(), code, symbol, exchange_rate).await
}

#[tauri::command]
pub async fn update_currency_rate(
    state: State<'_, CurrencyCommandState>,
    code: String,
    exchange_rate: String,
) -> Result<(), String> {
    update_currency_rate_with_service(state.inner(), code, exchange_rate).await
}
