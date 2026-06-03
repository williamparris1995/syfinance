use crate::domain::{
    repositories::CurrencyRepository,
    value_objects::{Currency, CurrencyValidationError},
};
use chrono::Utc;
use rust_decimal::Decimal;
use sqlx::{sqlite::SqlitePool, Row};
use std::str::FromStr;

#[derive(Clone)]
pub struct SqliteCurrencyRepository {
    pool: SqlitePool,
}

impl SqliteCurrencyRepository {
    // TODO: will be used when currency repo is constructed outside of DI context
    #[allow(dead_code)]
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn row_to_currency(row: &sqlx::sqlite::SqliteRow) -> Result<Currency, sqlx::Error> {
        let id: String = row.try_get("id")?;
        let code: String = row.try_get("code")?;
        let name: String = row.try_get("name").unwrap_or_default();
        let symbol: String = row.try_get("symbol")?;
        let exchange_rate_raw: String = row.try_get("exchange_rate")?;
        let exchange_rate = Decimal::from_str(&exchange_rate_raw)
            .map_err(|error| sqlx::Error::Decode(Box::new(error)))?;
        let is_active: bool = row.try_get("is_active").unwrap_or(true);

        Currency::new(id, code, name, symbol, exchange_rate)
            .map(|mut c| {
                c.is_active = is_active;
                c
            })
            .map_err(|error: CurrencyValidationError| sqlx::Error::Decode(Box::new(error)))
    }

    // TODO: will be used when currency rate caching is implemented
    #[allow(dead_code)]
    pub async fn find_by_code_with_timestamp(
        &self,
        code: &str,
    ) -> sqlx::Result<Option<(Currency, String)>> {
        let row = sqlx::query(
            r#"
            SELECT id, code, name, symbol, CAST(exchange_rate AS TEXT) AS exchange_rate, updated_at, is_active
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
            SELECT id, code, name, symbol, CAST(exchange_rate AS TEXT) AS exchange_rate, updated_at, is_active
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
            INSERT INTO currencies (id, code, name, symbol, exchange_rate, is_active)
            VALUES (?, ?, ?, ?, ?, ?)
            "#,
        )
        .bind(&currency.id)
        .bind(&currency.code)
        .bind(&currency.name)
        .bind(&currency.symbol)
        .bind(currency.exchange_rate.to_string())
        .bind(currency.is_active)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn find_by_code(&self, code: &str) -> sqlx::Result<Option<Currency>> {
        let row = sqlx::query(
            r#"
            SELECT id, code, name, symbol, CAST(exchange_rate AS TEXT) AS exchange_rate, is_active
            FROM currencies
            WHERE code = ?
            "#,
        )
        .bind(code)
        .fetch_optional(&self.pool)
        .await?;

        row.map(|row| Self::row_to_currency(&row)).transpose()
    }

    async fn find_active(&self) -> sqlx::Result<Vec<Currency>> {
        let rows = sqlx::query(
            r#"
            SELECT id, code, name, symbol, CAST(exchange_rate AS TEXT) AS exchange_rate, is_active
            FROM currencies
            WHERE is_active = TRUE
            ORDER BY code ASC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(Self::row_to_currency).collect()
    }

    async fn list_all(&self) -> sqlx::Result<Vec<Currency>> {
        let rows = sqlx::query(
            r#"
            SELECT id, code, name, symbol, CAST(exchange_rate AS TEXT) AS exchange_rate, is_active
            FROM currencies
            ORDER BY code ASC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(Self::row_to_currency).collect()
    }

    async fn save(&self, currency: &Currency) -> sqlx::Result<()> {
        sqlx::query(
            r#"
            INSERT INTO currencies (id, code, name, symbol, exchange_rate, is_active)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT (code) DO UPDATE SET
                name = excluded.name,
                symbol = excluded.symbol,
                exchange_rate = excluded.exchange_rate,
                is_active = excluded.is_active,
                updated_at = CURRENT_TIMESTAMP
            "#,
        )
        .bind(&currency.id)
        .bind(&currency.code)
        .bind(&currency.name)
        .bind(&currency.symbol)
        .bind(currency.exchange_rate.to_string())
        .bind(currency.is_active)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn update_rate(&self, code: &str, exchange_rate: Decimal) -> sqlx::Result<bool> {
        let now = Utc::now().to_rfc3339();
        let result = sqlx::query(
            r#"
            UPDATE currencies
            SET exchange_rate = ?, updated_at = ?
            WHERE code = ?
            "#,
        )
        .bind(exchange_rate.to_string())
        .bind(&now)
        .bind(code)
        .execute(&self.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    async fn delete(&self, code: &str) -> sqlx::Result<bool> {
        let result = sqlx::query("DELETE FROM currencies WHERE code = ?")
            .bind(code)
            .execute(&self.pool)
            .await?;

        Ok(result.rows_affected() > 0)
    }
}
