use crate::domain::{
    aggregates::{Account, AccountType},
    repositories::AccountRepository,
    value_objects::{Money, SyncMetadata},
};
use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use sqlx::{sqlite::SqlitePool, Row};
use std::str::FromStr;
use uuid::Uuid;

#[derive(Clone)]
pub struct SqliteAccountRepository {
    pool: SqlitePool,
}

impl SqliteAccountRepository {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn row_to_account(row: &sqlx::sqlite::SqliteRow) -> Result<Account, sqlx::Error> {
        let id: String = row.try_get("id")?;
        let id = Uuid::from_str(&id).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

        let name: String = row.try_get("name")?;
        
        let account_type_str: String = row.try_get("account_type")?;
        let account_type = match account_type_str.as_str() {
            "cash" => AccountType::Cash,
            "bank" => AccountType::Bank,
            "credit_card" => AccountType::CreditCard,
            "investment" => AccountType::Investment,
            "loan" => AccountType::Loan,
            "other" => AccountType::Other,
            _ => return Err(sqlx::Error::Decode(format!("Invalid account type: {}", account_type_str).into())),
        };

        let chart_of_account_code: String = row.try_get("chart_of_account_code")?;
        let currency_code: String = row.try_get("currency_code")?;
        
        let balance_str: String = row.try_get("balance")?;
        let balance_amount = Decimal::from_str(&balance_str)
            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;
        
        let balance = Money::new(balance_amount, &currency_code)
            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

        let updated_at: String = row.try_get("updated_at")?;
        let deleted_at: Option<String> = row.try_get("deleted_at")?;
        let device_id: Option<String> = row.try_get("device_id")?;
        let synced_at: Option<String> = row.try_get("synced_at")?;

        // Parse SQLite datetime format (YYYY-MM-DD HH:MM:SS) to RFC3339
        let parse_sqlite_datetime = |s: &str| -> Result<DateTime<Utc>, chrono::ParseError> {
            // Try RFC3339 first (for programmatically inserted data)
            if let Ok(dt) = DateTime::parse_from_rfc3339(s) {
                return Ok(dt.with_timezone(&Utc));
            }
            // Try SQLite format: "YYYY-MM-DD HH:MM:SS"
            chrono::NaiveDateTime::parse_from_str(s, "%Y-%m-%d %H:%M:%S")
                .map(|ndt| DateTime::<Utc>::from_naive_utc_and_offset(ndt, Utc))
        };

        let updated_at_parsed = parse_sqlite_datetime(&updated_at)
            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

        let deleted_at_parsed = deleted_at
            .map(|s| parse_sqlite_datetime(&s))
            .transpose()
            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

        let device_id_parsed = device_id
            .map(|s| Uuid::from_str(&s).map_err(|e| sqlx::Error::Decode(Box::new(e))))
            .transpose()?;

        let synced_at_parsed = synced_at
            .map(|s| parse_sqlite_datetime(&s))
            .transpose()
            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

        let sync_metadata = SyncMetadata {
            updated_at: updated_at_parsed,
            deleted_at: deleted_at_parsed,
            device_id: device_id_parsed.unwrap_or_else(Uuid::new_v4),
            synced_at: synced_at_parsed,
        };

        // Reconstruct Account using public fields
        Ok(Account {
            id,
            name,
            account_type,
            chart_of_account_code,
            currency_code,
            balance,
            sync_metadata,
            pending_events: Vec::new(),
        })
    }
}

impl AccountRepository for SqliteAccountRepository {
    async fn create(&self, account: &Account) -> sqlx::Result<()> {
        sqlx::query(
            r#"
            INSERT INTO accounts (
                id, name, account_type, chart_of_account_code, 
                currency_code, balance, updated_at, deleted_at, 
                device_id, synced_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            "#,
        )
        .bind(account.id.to_string())
        .bind(&account.name)
        .bind(account.account_type.to_string())
        .bind(&account.chart_of_account_code)
        .bind(&account.currency_code)
        .bind(account.balance.amount.to_string())
        .bind(account.sync_metadata.updated_at.to_rfc3339())
        .bind(account.sync_metadata.deleted_at.map(|dt| dt.to_rfc3339()))
        .bind(account.sync_metadata.device_id.to_string())
        .bind(account.sync_metadata.synced_at.map(|dt| dt.to_rfc3339()))
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<Account>> {
        let row = sqlx::query(
            r#"
            SELECT 
                id, name, account_type, chart_of_account_code,
                currency_code, CAST(balance AS TEXT) AS balance,
                updated_at, deleted_at, device_id, synced_at
            FROM accounts
            WHERE id = ? AND deleted_at IS NULL
            "#,
        )
        .bind(id.to_string())
        .fetch_optional(&self.pool)
        .await?;

        row.map(|row| Self::row_to_account(&row)).transpose()
    }

    async fn find_all(&self) -> sqlx::Result<Vec<Account>> {
        let rows = sqlx::query(
            r#"
            SELECT 
                id, name, account_type, chart_of_account_code,
                currency_code, CAST(balance AS TEXT) AS balance,
                updated_at, deleted_at, device_id, synced_at
            FROM accounts
            WHERE deleted_at IS NULL
            ORDER BY name ASC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(Self::row_to_account).collect()
    }

    async fn find_by_type(&self, account_type: AccountType) -> sqlx::Result<Vec<Account>> {
        let rows = sqlx::query(
            r#"
            SELECT 
                id, name, account_type, chart_of_account_code,
                currency_code, CAST(balance AS TEXT) AS balance,
                updated_at, deleted_at, device_id, synced_at
            FROM accounts
            WHERE account_type = ? AND deleted_at IS NULL
            ORDER BY name ASC
            "#,
        )
        .bind(account_type.to_string())
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(Self::row_to_account).collect()
    }

    async fn update(&self, account: &Account) -> sqlx::Result<bool> {
        let result = sqlx::query(
            r#"
            UPDATE accounts
            SET 
                name = ?,
                balance = ?,
                updated_at = ?,
                deleted_at = ?,
                device_id = ?,
                synced_at = ?
            WHERE id = ?
            "#,
        )
        .bind(&account.name)
        .bind(account.balance.amount.to_string())
        .bind(account.sync_metadata.updated_at.to_rfc3339())
        .bind(account.sync_metadata.deleted_at.map(|dt| dt.to_rfc3339()))
        .bind(account.sync_metadata.device_id.to_string())
        .bind(account.sync_metadata.synced_at.map(|dt| dt.to_rfc3339()))
        .bind(account.id.to_string())
        .execute(&self.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool> {
        let result = sqlx::query(
            r#"
            UPDATE accounts
            SET deleted_at = CURRENT_TIMESTAMP
            WHERE id = ? AND deleted_at IS NULL
            "#,
        )
        .bind(id.to_string())
        .execute(&self.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    async fn find_all_including_deleted(&self) -> sqlx::Result<Vec<Account>> {
        let rows = sqlx::query(
            r#"
            SELECT 
                id, name, account_type, chart_of_account_code,
                currency_code, CAST(balance AS TEXT) AS balance,
                updated_at, deleted_at, device_id, synced_at
            FROM accounts
            ORDER BY name ASC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(Self::row_to_account).collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{
        aggregates::{
            chart_of_accounts::{BalanceDirection, ChartOfAccounts},
            Account, AccountType, ChartOfAccountsType,
        },
        value_objects::Currency,
    };
    use rust_decimal::Decimal;
    use sqlx::sqlite::SqlitePoolOptions;

    async fn setup_test_db() -> SqlitePool {
        let pool = SqlitePoolOptions::new()
            .connect("sqlite::memory:")
            .await
            .unwrap();

        // Create accounts table
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS accounts (
                id TEXT PRIMARY KEY NOT NULL,
                name VARCHAR(100) NOT NULL,
                account_type VARCHAR(20) NOT NULL,
                chart_of_account_code VARCHAR(10) NOT NULL,
                currency_code VARCHAR(3) NOT NULL,
                balance DECIMAL(20,2) NOT NULL,
                deleted_at TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                device_id TEXT,
                synced_at TIMESTAMP
            )
            "#,
        )
        .execute(&pool)
        .await
        .unwrap();

        pool
    }

    fn create_test_account(name: &str, account_type: AccountType, balance: Decimal) -> Account {
        let chart_code = match account_type {
            AccountType::Cash => "1001",
            AccountType::Bank => "1002",
            AccountType::CreditCard => "2201",
            AccountType::Loan => "2001",
            _ => "1012",
        };

        let chart_type = match account_type {
            AccountType::Cash | AccountType::Bank | AccountType::Investment => {
                ChartOfAccountsType::Asset
            }
            AccountType::CreditCard | AccountType::Loan => ChartOfAccountsType::Liability,
            _ => ChartOfAccountsType::Asset,
        };

        let chart = ChartOfAccounts::new(
            format!("coa-{}", chart_code),
            chart_code.to_string(),
            format!("Chart {}", chart_code),
            2,
            chart_type,
            Some("1000".to_string()),
            BalanceDirection::Debit,
        )
        .unwrap();

        let currency = Currency::new("USD", "$", Decimal::ONE).unwrap();
        let money = Money::new(balance, "USD").unwrap();
        let sync_metadata = SyncMetadata::new(Uuid::new_v4());

        Account::new(
            Uuid::new_v4(),
            name,
            account_type,
            &chart,
            &currency,
            money,
            sync_metadata,
        )
        .unwrap()
    }

    #[tokio::test]
    async fn test_create_and_find_by_id() {
        let pool = setup_test_db().await;
        let repo = SqliteAccountRepository::new(pool);

        let account = create_test_account("Checking", AccountType::Bank, Decimal::new(10000, 2));
        let account_id = account.id;

        repo.create(&account).await.unwrap();

        let found = repo.find_by_id(account_id).await.unwrap();
        assert!(found.is_some());
        let found = found.unwrap();
        assert_eq!(found.name, "Checking");
        assert_eq!(found.balance.amount, Decimal::new(10000, 2));
    }

    #[tokio::test]
    async fn test_find_all_excludes_deleted() {
        let pool = setup_test_db().await;
        let repo = SqliteAccountRepository::new(pool);

        let account1 = create_test_account("Savings", AccountType::Bank, Decimal::new(50000, 2));
        let account2 = create_test_account("Wallet", AccountType::Cash, Decimal::new(1000, 2));

        repo.create(&account1).await.unwrap();
        repo.create(&account2).await.unwrap();

        repo.soft_delete(account1.id).await.unwrap();

        let all = repo.find_all().await.unwrap();
        assert_eq!(all.len(), 1);
        assert_eq!(all[0].name, "Wallet");
    }

    #[tokio::test]
    async fn test_find_by_type() {
        let pool = setup_test_db().await;
        let repo = SqliteAccountRepository::new(pool);

        let account1 = create_test_account("Checking", AccountType::Bank, Decimal::new(10000, 2));
        let account2 = create_test_account("Wallet", AccountType::Cash, Decimal::new(1000, 2));
        let account3 = create_test_account("Savings", AccountType::Bank, Decimal::new(50000, 2));

        repo.create(&account1).await.unwrap();
        repo.create(&account2).await.unwrap();
        repo.create(&account3).await.unwrap();

        let banks = repo.find_by_type(AccountType::Bank).await.unwrap();
        assert_eq!(banks.len(), 2);
    }

    #[tokio::test]
    async fn test_update_account() {
        let pool = setup_test_db().await;
        let repo = SqliteAccountRepository::new(pool);

        let mut account = create_test_account("Checking", AccountType::Bank, Decimal::new(10000, 2));
        repo.create(&account).await.unwrap();

        account.change_name("Primary Checking").unwrap();
        account.update_balance(Money::new(Decimal::new(15000, 2), "USD").unwrap()).unwrap();

        let updated = repo.update(&account).await.unwrap();
        assert!(updated);

        let found = repo.find_by_id(account.id).await.unwrap().unwrap();
        assert_eq!(found.name, "Primary Checking");
        assert_eq!(found.balance.amount, Decimal::new(15000, 2));
    }

    #[tokio::test]
    async fn test_soft_delete() {
        let pool = setup_test_db().await;
        let repo = SqliteAccountRepository::new(pool);

        let account = create_test_account("Old Account", AccountType::Bank, Decimal::new(0, 2));
        let account_id = account.id;
        repo.create(&account).await.unwrap();

        let deleted = repo.soft_delete(account_id).await.unwrap();
        assert!(deleted);

        let found = repo.find_by_id(account_id).await.unwrap();
        assert!(found.is_none());
    }

    #[tokio::test]
    async fn test_find_all_including_deleted() {
        let pool = setup_test_db().await;
        let repo = SqliteAccountRepository::new(pool);

        let account1 = create_test_account("Active", AccountType::Bank, Decimal::new(10000, 2));
        let account2 = create_test_account("Deleted", AccountType::Cash, Decimal::new(1000, 2));

        repo.create(&account1).await.unwrap();
        repo.create(&account2).await.unwrap();
        repo.soft_delete(account2.id).await.unwrap();

        let all = repo.find_all_including_deleted().await.unwrap();
        assert_eq!(all.len(), 2);
    }

    #[tokio::test]
    async fn test_money_serialization_preserves_precision() {
        let pool = setup_test_db().await;
        let repo = SqliteAccountRepository::new(pool);

        let account = create_test_account("Precise", AccountType::Bank, Decimal::new(123456, 2));
        let account_id = account.id;
        repo.create(&account).await.unwrap();

        let found = repo.find_by_id(account_id).await.unwrap().unwrap();
        assert_eq!(found.balance.amount, Decimal::new(123456, 2));
        assert_eq!(found.balance.currency_code, "USD");
    }
}
