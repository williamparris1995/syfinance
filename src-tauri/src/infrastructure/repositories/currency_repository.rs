use crate::domain::{
    repositories::CurrencyRepository,
    value_objects::{Currency, CurrencyValidationError},
};
use rust_decimal::Decimal;
use sqlx::{sqlite::SqlitePool, Row};
use std::str::FromStr;
use uuid::Uuid;

#[derive(Clone)]
pub struct SqliteCurrencyRepository {
    pool: SqlitePool,
}

impl SqliteCurrencyRepository {
    #[allow(dead_code)]
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn row_to_currency(row: &sqlx::sqlite::SqliteRow) -> Result<Currency, sqlx::Error> {
        let code: String = row.try_get("code")?;
        let symbol: String = row.try_get("symbol")?;
        let exchange_rate_raw: String = row.try_get("exchange_rate")?;
        let exchange_rate = Decimal::from_str(&exchange_rate_raw)
            .map_err(|error| sqlx::Error::Decode(Box::new(error)))?;

        Currency::new(code, symbol, exchange_rate)
            .map_err(|error: CurrencyValidationError| sqlx::Error::Decode(Box::new(error)))
    }

    pub async fn find_by_code_with_timestamp(&self, code: &str) -> sqlx::Result<Option<(Currency, String)>> {
        let row = sqlx::query(
            r#"
            SELECT code, symbol, CAST(exchange_rate AS TEXT) AS exchange_rate, updated_at
            FROM currencies
            WHERE code = ?
            "#,
        )
        .bind(code)
        .fetch_optional(&self.pool)
        .await?;

        match row {
            Some(row) => {
                let currency = Self::row_to_currency(&row)?;
                let updated_at: String = row.try_get("updated_at")?;
                Ok(Some((currency, updated_at)))
            }
            None => Ok(None),
        }
    }

    pub async fn list_all_with_timestamps(&self) -> sqlx::Result<Vec<(Currency, String)>> {
        let rows = sqlx::query(
            r#"
            SELECT code, symbol, CAST(exchange_rate AS TEXT) AS exchange_rate, updated_at
            FROM currencies
            ORDER BY code ASC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        rows.iter()
            .map(|row| {
                let currency = Self::row_to_currency(row)?;
                let updated_at: String = row.try_get("updated_at")?;
                Ok((currency, updated_at))
            })
            .collect()
    }
}

impl CurrencyRepository for SqliteCurrencyRepository {
    async fn create(&self, currency: &Currency) -> sqlx::Result<()> {
        sqlx::query(
            r#"
            INSERT INTO currencies (id, code, symbol, exchange_rate)
            VALUES (?, ?, ?, ?)
            "#,
        )
        .bind(Uuid::new_v4().to_string())
        .bind(&currency.code)
        .bind(&currency.symbol)
        .bind(currency.exchange_rate.to_string())
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn find_by_code(&self, code: &str) -> sqlx::Result<Option<Currency>> {
        let row = sqlx::query(
            r#"
            SELECT code, symbol, CAST(exchange_rate AS TEXT) AS exchange_rate
            FROM currencies
            WHERE code = ?
            "#,
        )
        .bind(code)
        .fetch_optional(&self.pool)
        .await?;

        row.map(|row| Self::row_to_currency(&row)).transpose()
    }

    async fn list_all(&self) -> sqlx::Result<Vec<Currency>> {
        let rows = sqlx::query(
            r#"
            SELECT code, symbol, CAST(exchange_rate AS TEXT) AS exchange_rate
            FROM currencies
            ORDER BY code ASC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(Self::row_to_currency).collect()
    }

    async fn update_rate(&self, code: &str, exchange_rate: Decimal) -> sqlx::Result<bool> {
        let result = sqlx::query(
            r#"
            UPDATE currencies
            SET exchange_rate = ?, updated_at = CURRENT_TIMESTAMP
            WHERE code = ?
            "#,
        )
        .bind(exchange_rate.to_string())
        .bind(code)
        .execute(&self.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }
}
