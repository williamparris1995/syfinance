use crate::domain::{
    aggregates::{Account, AccountType, Ownership},
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
            "income" => AccountType::Income,
            "expense" => AccountType::Expense,
            _ => {
                return Err(sqlx::Error::Decode(
                    format!("Invalid account type: {}", account_type_str).into(),
                ))
            }
        };

        let currency_code: String = row.try_get("currency_code")?;

        let balance_str: String = row.try_get("balance")?;
        let balance_amount =
            Decimal::from_str(&balance_str).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

        let balance = Money::new(balance_amount, &currency_code)
            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

        // Read new columns from unified accounts
        let ownership_str: String = row.try_get("ownership")?;
        let ownership = match ownership_str.as_str() {
            "own" => Ownership::Own,
            "external" => Ownership::External,
            _ => {
                return Err(sqlx::Error::Decode(
                    format!("Invalid ownership: {}", ownership_str).into(),
                ))
            }
        };

        let icon: String = row.try_get("icon")?;
        let color: String = row.try_get("color")?;
        let chart_code: Option<String> = row.try_get("chart_code")?;

        let parent_id_str: Option<String> = row.try_get("parent_id")?;
        let parent_id = parent_id_str
            .map(|s| Uuid::from_str(&s).map_err(|e| sqlx::Error::Decode(Box::new(e))))
            .transpose()?;

        // Read optional fields
        let account_number: Option<String> = row.try_get("account_number")?;
        let institution: Option<String> = row.try_get("institution")?;

        let credit_limit_str: Option<String> = row.try_get("credit_limit")?;
        let credit_limit = credit_limit_str
            .map(|s| {
                let amount = Decimal::from_str(&s).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;
                Money::new(amount, &currency_code).map_err(|e| sqlx::Error::Decode(Box::new(e)))
            })
            .transpose()?;

        let billing_day: Option<i64> = row.try_get("billing_day")?;
        let billing_day = billing_day.map(|d| d as u8);

        let payment_due_day: Option<i64> = row.try_get("payment_due_day")?;
        let payment_due_day = payment_due_day.map(|d| d as u8);

        let interest_rate_str: Option<String> = row.try_get("interest_rate")?;
        let interest_rate = interest_rate_str
            .map(|s| Decimal::from_str(&s).map_err(|e| sqlx::Error::Decode(Box::new(e))))
            .transpose()?;

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

        let updated_at_parsed =
            parse_sqlite_datetime(&updated_at).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

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
            ownership,
            currency_code,
            balance,
            icon,
            color,
            chart_code,
            parent_id,
            account_number,
            institution,
            credit_limit,
            billing_day,
            payment_due_day,
            interest_rate,
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
                id, name, account_type, ownership, currency_code, balance,
                icon, color, chart_code, parent_id,
                account_number, institution, credit_limit, billing_day,
                payment_due_day, interest_rate,
                updated_at, deleted_at, device_id, synced_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            "#,
        )
        .bind(account.id.to_string())
        .bind(&account.name)
        .bind(account.account_type.to_string())
        .bind(account.ownership.to_string())
        .bind(&account.currency_code)
        .bind(account.balance.amount.to_string())
        .bind(&account.icon)
        .bind(&account.color)
        .bind(&account.chart_code)
        .bind(account.parent_id.map(|id| id.to_string()))
        .bind(&account.account_number)
        .bind(&account.institution)
        .bind(account.credit_limit.as_ref().map(|m| m.amount.to_string()))
        .bind(account.billing_day.map(|d| d as i64))
        .bind(account.payment_due_day.map(|d| d as i64))
        .bind(account.interest_rate.map(|r| r.to_string()))
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
                id, name, account_type, ownership, currency_code,
                CAST(balance AS TEXT) AS balance,
                icon, color, chart_code, parent_id,
                account_number, institution,
                CAST(credit_limit AS TEXT) AS credit_limit,
                billing_day, payment_due_day,
                CAST(interest_rate AS TEXT) AS interest_rate,
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
                id, name, account_type, ownership, currency_code,
                CAST(balance AS TEXT) AS balance,
                icon, color, chart_code, parent_id,
                account_number, institution,
                CAST(credit_limit AS TEXT) AS credit_limit,
                billing_day, payment_due_day,
                CAST(interest_rate AS TEXT) AS interest_rate,
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
                id, name, account_type, ownership, currency_code,
                CAST(balance AS TEXT) AS balance,
                icon, color, chart_code, parent_id,
                account_number, institution,
                CAST(credit_limit AS TEXT) AS credit_limit,
                billing_day, payment_due_day,
                CAST(interest_rate AS TEXT) AS interest_rate,
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

    async fn find_by_ownership(&self, ownership: &Ownership) -> sqlx::Result<Vec<Account>> {
        let rows = sqlx::query(
            r#"
            SELECT
                id, name, account_type, ownership, currency_code,
                CAST(balance AS TEXT) AS balance,
                icon, color, chart_code, parent_id,
                account_number, institution,
                CAST(credit_limit AS TEXT) AS credit_limit,
                billing_day, payment_due_day,
                CAST(interest_rate AS TEXT) AS interest_rate,
                updated_at, deleted_at, device_id, synced_at
            FROM accounts
            WHERE ownership = ? AND deleted_at IS NULL
            ORDER BY name ASC
            "#,
        )
        .bind(ownership.to_string())
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
        let now = Utc::now().to_rfc3339();
        let result = sqlx::query(
            r#"
            UPDATE accounts
            SET deleted_at = ?
            WHERE id = ? AND deleted_at IS NULL
            "#,
        )
        .bind(&now)
        .bind(id.to_string())
        .execute(&self.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    async fn find_all_including_deleted(&self) -> sqlx::Result<Vec<Account>> {
        let rows = sqlx::query(
            r#"
            SELECT 
                id, name, account_type, ownership, currency_code,
                CAST(balance AS TEXT) AS balance,
                icon, color, chart_code, parent_id,
                account_number, institution,
                CAST(credit_limit AS TEXT) AS credit_limit,
                billing_day, payment_due_day,
                CAST(interest_rate AS TEXT) AS interest_rate,
                updated_at, deleted_at, device_id, synced_at
            FROM accounts
            ORDER BY name ASC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(Self::row_to_account).collect()
    }

    async fn get_changes_since(&self, timestamp: DateTime<Utc>) -> sqlx::Result<Vec<Account>> {
        let rows = sqlx::query(
            r#"
            SELECT 
                id, name, account_type, ownership, currency_code,
                CAST(balance AS TEXT) AS balance,
                icon, color, chart_code, parent_id,
                account_number, institution,
                CAST(credit_limit AS TEXT) AS credit_limit,
                billing_day, payment_due_day,
                CAST(interest_rate AS TEXT) AS interest_rate,
                updated_at, deleted_at, device_id, synced_at
            FROM accounts
            WHERE updated_at > ? AND (synced_at IS NULL OR synced_at < updated_at)
            ORDER BY updated_at ASC
            "#,
        )
        .bind(timestamp.to_rfc3339())
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(Self::row_to_account).collect()
    }

    async fn mark_as_synced(&self, id: Uuid) -> sqlx::Result<bool> {
        let result = sqlx::query(
            r#"
            UPDATE accounts
            SET synced_at = ?
            WHERE id = ?
            "#,
        )
        .bind(Utc::now().to_rfc3339())
        .bind(id.to_string())
        .execute(&self.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{
        aggregates::{Account, AccountType},
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
                ownership VARCHAR(10) NOT NULL DEFAULT 'own',
                currency_code VARCHAR(3) NOT NULL,
                balance DECIMAL(20,2) NOT NULL,
                icon VARCHAR(10) NOT NULL DEFAULT '📁',
                color VARCHAR(7) NOT NULL DEFAULT '#6B7280',
                chart_code VARCHAR(10),
                parent_id TEXT REFERENCES accounts(id) ON DELETE SET NULL,
                account_number VARCHAR(50),
                institution VARCHAR(100),
                credit_limit DECIMAL(20,2),
                billing_day INTEGER,
                payment_due_day INTEGER,
                interest_rate DECIMAL(10,6),
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
        let currency = Currency::new("USD", "$", Decimal::ONE).unwrap();
        let money = Money::new(balance, "USD").unwrap();
        let sync_metadata = SyncMetadata::new(Uuid::new_v4());

        Account::new(
            Uuid::new_v4(),
            name,
            account_type,
            Ownership::Own,
            &currency,
            money,
            "💰",
            "#10B981",
            None,
            None,
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

        let mut account =
            create_test_account("Checking", AccountType::Bank, Decimal::new(10000, 2));
        repo.create(&account).await.unwrap();

        account.change_name("Primary Checking").unwrap();
        account
            .update_balance(Money::new(Decimal::new(15000, 2), "USD").unwrap())
            .unwrap();

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

    #[tokio::test]
    async fn test_get_changes_since() {
        let pool = setup_test_db().await;
        let repo = SqliteAccountRepository::new(pool);

        let account1 = create_test_account("Account1", AccountType::Bank, Decimal::new(10000, 2));
        let account2 = create_test_account("Account2", AccountType::Cash, Decimal::new(5000, 2));

        repo.create(&account1).await.unwrap();
        repo.create(&account2).await.unwrap();

        // Mark account1 as synced
        repo.mark_as_synced(account1.id).await.unwrap();

        // Get changes since 1 hour ago
        let one_hour_ago = Utc::now() - chrono::Duration::hours(1);
        let changes = repo.get_changes_since(one_hour_ago).await.unwrap();

        // Should only return account2 (not synced)
        assert_eq!(changes.len(), 1);
        assert_eq!(changes[0].name, "Account2");
    }

    #[tokio::test]
    async fn test_mark_as_synced() {
        let pool = setup_test_db().await;
        let repo = SqliteAccountRepository::new(pool);

        let account = create_test_account("Test", AccountType::Bank, Decimal::new(10000, 2));
        let account_id = account.id;

        repo.create(&account).await.unwrap();

        // Initially synced_at should be None
        let found = repo.find_by_id(account_id).await.unwrap().unwrap();
        assert!(found.sync_metadata.synced_at.is_none());

        // Mark as synced
        let marked = repo.mark_as_synced(account_id).await.unwrap();
        assert!(marked);

        // Now synced_at should be set
        let found = repo.find_by_id(account_id).await.unwrap().unwrap();
        assert!(found.sync_metadata.synced_at.is_some());
    }
}
