use crate::domain::{
    aggregates::{Account, AccountType, Ownership},
    repositories::AccountRepository,
    value_objects::{Money, SyncMetadata},
};
use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use sqlx::{postgres::PgPool, Row};
use uuid::Uuid;

#[derive(Clone)]
pub struct PostgresAccountRepository {
    pool: PgPool,
}

impl PostgresAccountRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    fn row_to_account(row: &sqlx::postgres::PgRow) -> Result<Account, sqlx::Error> {
        let id: Uuid = row.try_get("id")?;
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
        let balance_amount: Decimal = row.try_get("balance")?;

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
        let parent_id: Option<Uuid> = row.try_get("parent_id")?;

        let updated_at: DateTime<Utc> = row.try_get("updated_at")?;
        let deleted_at: Option<DateTime<Utc>> = row.try_get("deleted_at")?;
        let device_id: Uuid = row.try_get("device_id")?;
        let synced_at: Option<DateTime<Utc>> = row.try_get("synced_at")?;

        let sync_metadata = SyncMetadata {
            updated_at,
            deleted_at,
            device_id,
            synced_at,
        };

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
            account_number: None,
            institution: None,
            credit_limit: None,
            billing_day: None,
            payment_due_day: None,
            interest_rate: None,
            sync_metadata,
            pending_events: Vec::new(),
        })
    }
}

impl AccountRepository for PostgresAccountRepository {
    async fn create(&self, account: &Account) -> sqlx::Result<()> {
        sqlx::query(
            r#"
            INSERT INTO accounts (
                id, name, account_type, ownership,
                currency_code, balance,
                icon, color, chart_code, parent_id,
                updated_at, deleted_at,
                device_id, synced_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
            ON CONFLICT (id) DO UPDATE SET
                name = EXCLUDED.name,
                ownership = EXCLUDED.ownership,
                currency_code = EXCLUDED.currency_code,
                balance = EXCLUDED.balance,
                icon = EXCLUDED.icon,
                color = EXCLUDED.color,
                chart_code = EXCLUDED.chart_code,
                parent_id = EXCLUDED.parent_id,
                updated_at = EXCLUDED.updated_at,
                deleted_at = EXCLUDED.deleted_at,
                device_id = EXCLUDED.device_id,
                synced_at = EXCLUDED.synced_at
            "#,
        )
        .bind(account.id)
        .bind(&account.name)
        .bind(account.account_type.to_string())
        .bind(account.ownership.to_string())
        .bind(&account.currency_code)
        .bind(account.balance.amount)
        .bind(&account.icon)
        .bind(&account.color)
        .bind(&account.chart_code)
        .bind(account.parent_id)
        .bind(account.sync_metadata.updated_at)
        .bind(account.sync_metadata.deleted_at)
        .bind(account.sync_metadata.device_id)
        .bind(account.sync_metadata.synced_at)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<Account>> {
        let row = sqlx::query(
            r#"
            SELECT
                id, name, account_type, ownership,
                currency_code, balance,
                icon, color, chart_code, parent_id,
                updated_at, deleted_at, device_id, synced_at
            FROM accounts
            WHERE id = $1 AND deleted_at IS NULL
            "#,
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await?;

        row.map(|row| Self::row_to_account(&row)).transpose()
    }

    async fn find_all(&self) -> sqlx::Result<Vec<Account>> {
        let rows = sqlx::query(
            r#"
            SELECT
                id, name, account_type, ownership,
                currency_code, balance,
                icon, color, chart_code, parent_id,
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
                id, name, account_type, ownership,
                currency_code, balance,
                icon, color, chart_code, parent_id,
                updated_at, deleted_at, device_id, synced_at
            FROM accounts
            WHERE account_type = $1 AND deleted_at IS NULL
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
                id, name, account_type, ownership,
                currency_code, balance,
                icon, color, chart_code, parent_id,
                updated_at, deleted_at, device_id, synced_at
            FROM accounts
            WHERE ownership = $1 AND deleted_at IS NULL
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
                name = $1,
                balance = $2,
                icon = $3,
                color = $4,
                chart_code = $5,
                parent_id = $6,
                account_number = $7,
                institution = $8,
                credit_limit = $9,
                billing_day = $10,
                payment_due_day = $11,
                interest_rate = $12,
                updated_at = $13,
                deleted_at = $14,
                device_id = $15,
                synced_at = $16
            WHERE id = $17
            RETURNING id
            "#,
        )
        .bind(&account.name)
        .bind(account.balance.amount.to_string())
        .bind(&account.icon)
        .bind(&account.color)
        .bind(&account.chart_code)
        .bind(account.parent_id.map(|id| id.to_string()))
        .bind(&account.account_number)
        .bind(&account.institution)
        .bind(account.credit_limit.as_ref().map(|m| m.amount.to_string()))
        .bind(account.billing_day.map(|d| d as i32))
        .bind(account.payment_due_day.map(|d| d as i32))
        .bind(account.interest_rate.map(|r| r.to_string()))
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
            SET deleted_at = NOW()
            WHERE id = $1 AND deleted_at IS NULL
            RETURNING id
            "#,
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await?;

        Ok(result.is_some())
    }

    async fn find_all_including_deleted(&self) -> sqlx::Result<Vec<Account>> {
        let rows = sqlx::query(
            r#"
            SELECT
                id, name, account_type, ownership,
                currency_code, balance,
                icon, color, chart_code, parent_id,
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
                id, name, account_type, ownership,
                currency_code, balance,
                icon, color, chart_code, parent_id,
                updated_at, deleted_at, device_id, synced_at
            FROM accounts
            WHERE updated_at > $1 AND (synced_at IS NULL OR synced_at < updated_at)
            ORDER BY updated_at ASC
            "#,
        )
        .bind(timestamp)
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(Self::row_to_account).collect()
    }

    async fn mark_as_synced(&self, id: Uuid) -> sqlx::Result<bool> {
        let result = sqlx::query(
            r#"
            UPDATE accounts
            SET synced_at = NOW()
            WHERE id = $1
            RETURNING id
            "#,
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await?;

        Ok(result.is_some())
    }
}
