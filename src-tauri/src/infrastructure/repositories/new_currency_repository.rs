use async_trait::async_trait;
use sqlx::{Row, SqlitePool};

use crate::domain::aggregates::currency::Currency;

#[async_trait]
pub trait NewCurrencyRepository {
    async fn find_all(&self) -> Result<Vec<Currency>, String>;
    async fn find_by_code(&self, code: &str) -> Result<Option<Currency>, String>;
    async fn find_active(&self) -> Result<Vec<Currency>, String>;
    async fn save(&self, currency: &Currency) -> Result<(), String>;
    async fn update_exchange_rate(&self, code: &str, rate: f64) -> Result<(), String>;
    async fn delete(&self, code: &str) -> Result<(), String>;
}

pub struct SqliteNewCurrencyRepository {
    pool: SqlitePool,
}

impl SqliteNewCurrencyRepository {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn row_to_currency(row: &sqlx::sqlite::SqliteRow) -> Result<Currency, String> {
        let id: String = row
            .try_get("id")
            .map_err(|e| format!("Failed to read id: {}", e))?;
        let code: String = row
            .try_get("code")
            .map_err(|e| format!("Failed to read code: {}", e))?;
        let name: String = row
            .try_get("name")
            .map_err(|e| format!("Failed to read name: {}", e))?;
        let symbol: String = row
            .try_get("symbol")
            .map_err(|e| format!("Failed to read symbol: {}", e))?;
        let exchange_rate_raw: String = row
            .try_get("exchange_rate")
            .map_err(|e| format!("Failed to read exchange_rate: {}", e))?;
        let exchange_rate: f64 = exchange_rate_raw
            .parse()
            .map_err(|e| format!("Invalid exchange_rate value '{}': {}", exchange_rate_raw, e))?;

        Currency::new(id, code, name, symbol, exchange_rate)
    }
}

#[async_trait]
impl NewCurrencyRepository for SqliteNewCurrencyRepository {
    async fn find_all(&self) -> Result<Vec<Currency>, String> {
        let rows = sqlx::query(
            r#"
            SELECT id, code, name, symbol, CAST(exchange_rate AS TEXT) AS exchange_rate,
                   updated_at, is_active
            FROM currencies
            ORDER BY code
            "#,
        )
        .fetch_all(&self.pool)
        .await
        .map_err(|e| format!("Failed to fetch currencies: {}", e))?;

        rows.iter()
            .map(Self::row_to_currency)
            .collect::<Result<Vec<_>, _>>()
    }

    async fn find_by_code(&self, code: &str) -> Result<Option<Currency>, String> {
        let row = sqlx::query(
            r#"
            SELECT id, code, name, symbol, CAST(exchange_rate AS TEXT) AS exchange_rate,
                   updated_at, is_active
            FROM currencies
            WHERE code = ?
            "#,
        )
        .bind(code)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| format!("Failed to fetch currency: {}", e))?;

        row.as_ref().map(Self::row_to_currency).transpose()
    }

    async fn find_active(&self) -> Result<Vec<Currency>, String> {
        let rows = sqlx::query(
            r#"
            SELECT id, code, name, symbol, CAST(exchange_rate AS TEXT) AS exchange_rate,
                   updated_at, is_active
            FROM currencies
            WHERE is_active = TRUE
            ORDER BY code
            "#,
        )
        .fetch_all(&self.pool)
        .await
        .map_err(|e| format!("Failed to fetch active currencies: {}", e))?;

        rows.iter()
            .map(Self::row_to_currency)
            .collect::<Result<Vec<_>, _>>()
    }

    async fn save(&self, currency: &Currency) -> Result<(), String> {
        sqlx::query(
            r#"
            INSERT INTO currencies (id, code, name, symbol, exchange_rate, updated_at, is_active)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (code) DO UPDATE SET
                name = excluded.name,
                symbol = excluded.symbol,
                exchange_rate = excluded.exchange_rate,
                updated_at = excluded.updated_at,
                is_active = excluded.is_active
            "#,
        )
        .bind(currency.id())
        .bind(currency.code())
        .bind(currency.name())
        .bind(currency.symbol())
        .bind(currency.exchange_rate().rate())
        .bind(currency.exchange_rate().updated_at())
        .bind(currency.is_active())
        .execute(&self.pool)
        .await
        .map_err(|e| format!("Failed to save currency: {}", e))?;

        Ok(())
    }

    async fn update_exchange_rate(&self, code: &str, rate: f64) -> Result<(), String> {
        let now = chrono::Utc::now().naive_utc();
        sqlx::query(
            r#"
            UPDATE currencies
            SET exchange_rate = ?, updated_at = ?
            WHERE code = ?
            "#,
        )
        .bind(rate)
        .bind(now)
        .bind(code)
        .execute(&self.pool)
        .await
        .map_err(|e| format!("Failed to update exchange rate: {}", e))?;

        Ok(())
    }

    async fn delete(&self, code: &str) -> Result<(), String> {
        sqlx::query("DELETE FROM currencies WHERE code = ?")
            .bind(code)
            .execute(&self.pool)
            .await
            .map_err(|e| format!("Failed to delete currency: {}", e))?;

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use sqlx::sqlite::SqlitePoolOptions;

    async fn setup_test_db() -> SqlitePool {
        let pool = SqlitePoolOptions::new()
            .connect(":memory:")
            .await
            .unwrap();

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS currencies (
                id TEXT PRIMARY KEY NOT NULL,
                code VARCHAR(3) NOT NULL UNIQUE,
                name VARCHAR(50) NOT NULL DEFAULT '',
                symbol VARCHAR(10) NOT NULL,
                exchange_rate DECIMAL(20,10) NOT NULL DEFAULT 1.0,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                is_active BOOLEAN NOT NULL DEFAULT TRUE,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                CHECK (exchange_rate > 0)
            )
            "#,
        )
        .execute(&pool)
        .await
        .unwrap();

        pool
    }

    #[tokio::test]
    async fn test_save_and_find_currency() {
        let pool = setup_test_db().await;
        let repo = SqliteNewCurrencyRepository::new(pool);

        let currency = Currency::new(
            "test-id".to_string(),
            "USD".to_string(),
            "美元".to_string(),
            "$".to_string(),
            7.25,
        )
        .unwrap();

        repo.save(&currency).await.unwrap();

        let found = repo.find_by_code("USD").await.unwrap();
        assert!(found.is_some());
        let found = found.unwrap();
        assert_eq!(found.id(), "test-id");
        assert_eq!(found.code(), "USD");
        assert_eq!(found.name(), "美元");
    }

    #[tokio::test]
    async fn test_update_exchange_rate() {
        let pool = setup_test_db().await;
        let repo = SqliteNewCurrencyRepository::new(pool);

        let currency = Currency::new(
            "test-id".to_string(),
            "USD".to_string(),
            "美元".to_string(),
            "$".to_string(),
            7.25,
        )
        .unwrap();

        repo.save(&currency).await.unwrap();

        repo.update_exchange_rate("USD", 7.30).await.unwrap();

        let found = repo.find_by_code("USD").await.unwrap().unwrap();
        assert!((found.exchange_rate().rate() - 7.30).abs() < 0.001);
    }

    #[tokio::test]
    async fn test_find_all() {
        let pool = setup_test_db().await;
        let repo = SqliteNewCurrencyRepository::new(pool);

        let usd = Currency::new(
            "id-usd".to_string(),
            "USD".to_string(),
            "美元".to_string(),
            "$".to_string(),
            7.25,
        )
        .unwrap();
        let eur = Currency::new(
            "id-eur".to_string(),
            "EUR".to_string(),
            "欧元".to_string(),
            "€".to_string(),
            7.95,
        )
        .unwrap();

        repo.save(&usd).await.unwrap();
        repo.save(&eur).await.unwrap();

        let all = repo.find_all().await.unwrap();
        assert_eq!(all.len(), 2);
        // Should be ordered by code: EUR, USD
        assert_eq!(all[0].code(), "EUR");
        assert_eq!(all[1].code(), "USD");
    }

    #[tokio::test]
    async fn test_find_active() {
        let pool = setup_test_db().await;
        let repo = SqliteNewCurrencyRepository::new(pool);

        let usd = Currency::new(
            "id-usd".to_string(),
            "USD".to_string(),
            "美元".to_string(),
            "$".to_string(),
            7.25,
        )
        .unwrap();
        let mut eur = Currency::new(
            "id-eur".to_string(),
            "EUR".to_string(),
            "欧元".to_string(),
            "€".to_string(),
            7.95,
        )
        .unwrap();
        eur.deactivate();

        repo.save(&usd).await.unwrap();
        repo.save(&eur).await.unwrap();

        let active = repo.find_active().await.unwrap();
        assert_eq!(active.len(), 1);
        assert_eq!(active[0].code(), "USD");
    }

    #[tokio::test]
    async fn test_find_by_code_not_found() {
        let pool = setup_test_db().await;
        let repo = SqliteNewCurrencyRepository::new(pool);

        let found = repo.find_by_code("GBP").await.unwrap();
        assert!(found.is_none());
    }

    #[tokio::test]
    async fn test_save_upsert() {
        let pool = setup_test_db().await;
        let repo = SqliteNewCurrencyRepository::new(pool);

        let currency = Currency::new(
            "test-id".to_string(),
            "USD".to_string(),
            "美元".to_string(),
            "$".to_string(),
            7.25,
        )
        .unwrap();
        repo.save(&currency).await.unwrap();

        // Save again with same code but different name (upsert)
        let updated = Currency::new(
            "test-id".to_string(),
            "USD".to_string(),
            "美金".to_string(),
            "$".to_string(),
            7.30,
        )
        .unwrap();
        repo.save(&updated).await.unwrap();

        let found = repo.find_by_code("USD").await.unwrap().unwrap();
        assert_eq!(found.name(), "美金");
        assert!((found.exchange_rate().rate() - 7.30).abs() < 0.001);

        // Should still only have one entry
        let all = repo.find_all().await.unwrap();
        assert_eq!(all.len(), 1);
    }

    #[tokio::test]
    async fn test_delete() {
        let pool = setup_test_db().await;
        let repo = SqliteNewCurrencyRepository::new(pool);

        let currency = Currency::new(
            "test-id".to_string(),
            "USD".to_string(),
            "美元".to_string(),
            "$".to_string(),
            7.25,
        )
        .unwrap();
        repo.save(&currency).await.unwrap();

        repo.delete("USD").await.unwrap();

        let found = repo.find_by_code("USD").await.unwrap();
        assert!(found.is_none());
    }
}
