use crate::domain::aggregates::security::{Security, SecurityType};
use crate::domain::repositories::SecurityRepository;
use chrono::Utc;
use rust_decimal::Decimal;
use sqlx::{Row, SqlitePool};
use std::str::FromStr;
use uuid::Uuid;

pub struct SqliteSecurityRepository {
    pool: SqlitePool,
}

impl SqliteSecurityRepository {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn parse_type(s: &str) -> Result<SecurityType, sqlx::Error> {
        match s {
            "stock" => Ok(SecurityType::Stock),
            "fund" => Ok(SecurityType::Fund),
            "etf" => Ok(SecurityType::Etf),
            "bond" => Ok(SecurityType::Bond),
            "gold" => Ok(SecurityType::Gold),
            "option" => Ok(SecurityType::Option),
            "other" => Ok(SecurityType::Other),
            _ => Err(sqlx::Error::Decode(
                format!("invalid security type: {}", s).into(),
            )),
        }
    }

    fn row_to_security(row: &sqlx::sqlite::SqliteRow) -> Result<Security, sqlx::Error> {
        let id_str: String = row.try_get("id")?;
        let id = Uuid::parse_str(&id_str)
            .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?;
        let symbol: String = row.try_get("symbol")?;
        let name: String = row.try_get("name")?;
        let type_str: String = row.try_get("type")?;
        let security_type = Self::parse_type(&type_str)?;
        let exchange: Option<String> = row.try_get("exchange")?;
        let currency_code: String = row.try_get("currency_code")?;
        let price_str: Option<String> = row.try_get("current_price")?;
        let current_price = price_str
            .map(|s| Decimal::from_str(&s))
            .transpose()
            .map_err(|e| sqlx::Error::Decode(format!("invalid decimal: {}", e).into()))?;
        Ok(Security::new(
            id,
            symbol,
            name,
            security_type,
            exchange,
            currency_code,
            current_price,
        ))
    }
}

impl SecurityRepository for SqliteSecurityRepository {
    async fn create(&self, s: &Security) -> sqlx::Result<()> {
        sqlx::query(
            "INSERT INTO securities (id, symbol, name, type, exchange, currency_code, current_price, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
        )
        .bind(s.id.to_string()).bind(&s.symbol).bind(&s.name)
        .bind(s.security_type.to_string()).bind(&s.exchange).bind(&s.currency_code)
        .bind(s.current_price.map(|p| p.to_string())).bind(Utc::now().to_rfc3339())
        .execute(&self.pool).await?;
        Ok(())
    }

    async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<Security>> {
        let row = sqlx::query(
            "SELECT id, symbol, name, type, exchange, currency_code, CAST(current_price AS TEXT) as current_price
             FROM securities WHERE id = ? AND deleted_at IS NULL"
        ).bind(id.to_string()).fetch_optional(&self.pool).await?;
        row.map(|r| Self::row_to_security(&r)).transpose()
    }

    async fn find_by_symbol(&self, symbol: &str) -> sqlx::Result<Option<Security>> {
        let row = sqlx::query(
            "SELECT id, symbol, name, type, exchange, currency_code, CAST(current_price AS TEXT) as current_price
             FROM securities WHERE symbol = ? AND deleted_at IS NULL"
        ).bind(symbol).fetch_optional(&self.pool).await?;
        row.map(|r| Self::row_to_security(&r)).transpose()
    }

    async fn find_all(&self) -> sqlx::Result<Vec<Security>> {
        let rows = sqlx::query(
            "SELECT id, symbol, name, type, exchange, currency_code, CAST(current_price AS TEXT) as current_price
             FROM securities WHERE deleted_at IS NULL ORDER BY symbol"
        ).fetch_all(&self.pool).await?;
        rows.iter().map(|r| Self::row_to_security(r)).collect()
    }

    async fn find_by_type(&self, st: &SecurityType) -> sqlx::Result<Vec<Security>> {
        let rows = sqlx::query(
            "SELECT id, symbol, name, type, exchange, currency_code, CAST(current_price AS TEXT) as current_price
             FROM securities WHERE type = ? AND deleted_at IS NULL ORDER BY symbol"
        ).bind(st.to_string()).fetch_all(&self.pool).await?;
        rows.iter().map(|r| Self::row_to_security(r)).collect()
    }

    async fn update(&self, s: &Security) -> sqlx::Result<bool> {
        let result = sqlx::query(
            "UPDATE securities SET symbol=?, name=?, type=?, exchange=?, currency_code=?, current_price=?, updated_at=?
             WHERE id=? AND deleted_at IS NULL"
        )
        .bind(&s.symbol).bind(&s.name).bind(s.security_type.to_string())
        .bind(&s.exchange).bind(&s.currency_code)
        .bind(s.current_price.map(|p| p.to_string())).bind(Utc::now().to_rfc3339())
        .bind(s.id.to_string()).execute(&self.pool).await?;
        Ok(result.rows_affected() > 0)
    }

    async fn update_price(&self, id: Uuid, price: Decimal) -> sqlx::Result<bool> {
        let result = sqlx::query(
            "UPDATE securities SET current_price=?, updated_at=? WHERE id=? AND deleted_at IS NULL",
        )
        .bind(price.to_string())
        .bind(Utc::now().to_rfc3339())
        .bind(id.to_string())
        .execute(&self.pool)
        .await?;
        Ok(result.rows_affected() > 0)
    }

    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool> {
        let result =
            sqlx::query("UPDATE securities SET deleted_at=? WHERE id=? AND deleted_at IS NULL")
                .bind(Utc::now().to_rfc3339())
                .bind(id.to_string())
                .execute(&self.pool)
                .await?;
        Ok(result.rows_affected() > 0)
    }
}
