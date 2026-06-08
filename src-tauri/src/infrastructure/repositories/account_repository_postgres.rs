//! PostgreSQL repository for Account aggregate.
//!
//! Planned for future multi-device sync. Currently only the SQLite
//! repository is wired into the application; these implementations will be
//! activated when the PostgreSQL sync layer is built out.

// TODO: will be used when PostgreSQL sync is implemented
#![allow(dead_code)]

use crate::domain::{
    aggregates::{
        account::AccountStatus,
        {Account, AccountType, Ownership},
    },
    repositories::AccountRepository,
    value_objects::{
        money::{cents_to_decimal, decimal_to_cents},
        Money, SyncMetadata,
    },
};
use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use sqlx::{postgres::PgPool, Row};
use std::str::FromStr;
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
            "borrowed_out" => AccountType::BorrowedOut,
            "borrowed_in" => AccountType::BorrowedIn,
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
        let initial_balance_cents: i64 = row.try_get("initial_balance")?;
        let initial_balance = Money::from_cents(initial_balance_cents, currency_code.clone());

        // Read new columns from unified accounts
        let ownership_str: String = row.try_get("ownership")?;
        let ownership = match ownership_str.as_str() {
            "own" => Ownership::Own,
            "liability" => Ownership::Liability,
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

        // Read optional fields
        let account_number: Option<String> = row.try_get("account_number")?;
        let institution: Option<String> = row.try_get("institution")?;

        let credit_limit_cents: Option<i64> = row.try_get("credit_limit")?;
        let credit_limit =
            credit_limit_cents.map(|cents| Money::from_cents(cents, currency_code.clone()));

        let billing_day: Option<i32> = row.try_get("billing_day")?;
        let payment_due_day: Option<i32> = row.try_get("payment_due_day")?;

        let interest_rate_str: Option<String> = row.try_get("interest_rate")?;
        let interest_rate = interest_rate_str
            .map(|s| {
                Decimal::from_str(&s)
                    .map_err(|e| sqlx::Error::Decode(format!("interest_rate='{s}': {e}").into()))
            })
            .transpose()?;

        let low_balance_threshold_cents: Option<i64> = row.try_get("low_balance_threshold")?;
        let low_balance_threshold = low_balance_threshold_cents.map(cents_to_decimal);

        let status_str: String = row.try_get("status")?;
        let status = match status_str.as_str() {
            "archived" => AccountStatus::Archived,
            "hidden" => AccountStatus::Hidden,
            _ => AccountStatus::Active,
        };

        let opened_at: Option<DateTime<Utc>> = row.try_get("opened_at")?;

        let created_at: DateTime<Utc> = row.try_get("created_at")?;
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
            initial_balance,
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
            low_balance_threshold,
            status,
            opened_at,
            created_at,
            sync_metadata,
            pending_events: Vec::new(),
        })
    }

    pub async fn compute_balances_for_all_accounts(
        &self,
    ) -> Result<std::collections::HashMap<Uuid, Decimal>, sqlx::Error> {
        use sqlx::FromRow;
        #[derive(FromRow)]
        struct BalanceRow {
            account_id: Uuid,
            net_change: Option<Decimal>,
        }

        let rows = sqlx::query_as::<_, BalanceRow>(
            r#"
            SELECT
                e.account_id,
                COALESCE(SUM(COALESCE(e.debit_amount, 0)), 0) -
                COALESCE(SUM(COALESCE(e.credit_amount, 0)), 0) AS net_change
            FROM transaction_entries e
            JOIN transactions t ON e.transaction_id = t.id
            WHERE e.deleted_at IS NULL AND t.deleted_at IS NULL
            GROUP BY e.account_id
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        let mut map = std::collections::HashMap::new();
        for row in rows {
            let change = row.net_change.unwrap_or(Decimal::ZERO);
            map.insert(row.account_id, change);
        }
        Ok(map)
    }

    pub async fn compute_balance_for_account_pg(&self, id: Uuid) -> Result<Decimal, sqlx::Error> {
        let row: (Decimal,) = sqlx::query_as(
            "SELECT COALESCE(SUM(COALESCE(e.debit_amount, 0)), 0) - \
             COALESCE(SUM(COALESCE(e.credit_amount, 0)), 0) \
             FROM transaction_entries e \
             JOIN transactions t ON e.transaction_id = t.id \
             WHERE e.deleted_at IS NULL AND t.deleted_at IS NULL \
             AND e.account_id = $1",
        )
        .bind(id)
        .fetch_one(&self.pool)
        .await?;

        Ok(row.0)
    }
}

impl AccountRepository for PostgresAccountRepository {
    async fn create(&self, account: &Account) -> sqlx::Result<()> {
        sqlx::query(
            r#"
            INSERT INTO accounts (
                id, name, account_type, ownership,
                currency_code, initial_balance,
                icon, color, chart_code, parent_id,
                account_number, institution, credit_limit,
                billing_day, payment_due_day, interest_rate,
                low_balance_threshold, status, opened_at,
                created_at, updated_at, deleted_at,
                device_id, synced_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
                    $11, $12, $13, $14, $15, $16, $17, $18, $19,
                    $20, $21, $22, $23, $24)
            ON CONFLICT (id) DO UPDATE SET
                name = EXCLUDED.name,
                ownership = EXCLUDED.ownership,
                currency_code = EXCLUDED.currency_code,
                initial_balance = EXCLUDED.initial_balance,
                icon = EXCLUDED.icon,
                color = EXCLUDED.color,
                chart_code = EXCLUDED.chart_code,
                parent_id = EXCLUDED.parent_id,
                account_number = EXCLUDED.account_number,
                institution = EXCLUDED.institution,
                credit_limit = EXCLUDED.credit_limit,
                billing_day = EXCLUDED.billing_day,
                payment_due_day = EXCLUDED.payment_due_day,
                interest_rate = EXCLUDED.interest_rate,
                low_balance_threshold = EXCLUDED.low_balance_threshold,
                status = EXCLUDED.status,
                opened_at = EXCLUDED.opened_at,
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
        .bind(account.initial_balance.to_cents())
        .bind(&account.icon)
        .bind(&account.color)
        .bind(&account.chart_code)
        .bind(account.parent_id)
        .bind(&account.account_number)
        .bind(&account.institution)
        .bind(account.credit_limit.as_ref().map(|m| m.to_cents()))
        .bind(account.billing_day)
        .bind(account.payment_due_day)
        .bind(account.interest_rate.map(|r| r.to_string()))
        .bind(account.low_balance_threshold.map(decimal_to_cents))
        .bind(account.status.to_string())
        .bind(account.opened_at)
        .bind(account.created_at)
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
                id, name, account_type, ownership, currency_code, initial_balance,
                icon, color, chart_code, parent_id,
                account_number, institution, credit_limit,
                billing_day, payment_due_day, interest_rate,
                low_balance_threshold, status, created_at, opened_at,
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

    async fn find_by_name(&self, name: &str) -> sqlx::Result<Option<Account>> {
        let row = sqlx::query(
            r#"
            SELECT
                id, name, account_type, ownership, currency_code, initial_balance,
                icon, color, chart_code, parent_id,
                account_number, institution, credit_limit,
                billing_day, payment_due_day, interest_rate,
                low_balance_threshold, status, created_at, opened_at,
                updated_at, deleted_at, device_id, synced_at
            FROM accounts
            WHERE name = $1 AND deleted_at IS NULL
            "#,
        )
        .bind(name)
        .fetch_optional(&self.pool)
        .await?;

        row.map(|row| Self::row_to_account(&row)).transpose()
    }

    async fn find_all(&self) -> sqlx::Result<Vec<Account>> {
        let rows = sqlx::query(
            r#"
            SELECT
                id, name, account_type, ownership, currency_code, initial_balance,
                icon, color, chart_code, parent_id,
                account_number, institution, credit_limit,
                billing_day, payment_due_day, interest_rate,
                low_balance_threshold, status, created_at, opened_at,
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
                id, name, account_type, ownership, currency_code, initial_balance,
                icon, color, chart_code, parent_id,
                account_number, institution, credit_limit,
                billing_day, payment_due_day, interest_rate,
                low_balance_threshold, status, created_at, opened_at,
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
                id, name, account_type, ownership, currency_code, initial_balance,
                icon, color, chart_code, parent_id,
                account_number, institution, credit_limit,
                billing_day, payment_due_day, interest_rate,
                low_balance_threshold, status, created_at, opened_at,
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
                initial_balance = $2,
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
                low_balance_threshold = $13,
                status = $14,
                opened_at = $15,
                updated_at = $16,
                deleted_at = $17,
                device_id = $18,
                synced_at = $19
            WHERE id = $20
            RETURNING id
            "#,
        )
        .bind(&account.name)
        .bind(account.initial_balance.to_cents())
        .bind(&account.icon)
        .bind(&account.color)
        .bind(&account.chart_code)
        .bind(account.parent_id)
        .bind(&account.account_number)
        .bind(&account.institution)
        .bind(account.credit_limit.as_ref().map(|m| m.to_cents()))
        .bind(account.billing_day)
        .bind(account.payment_due_day)
        .bind(account.interest_rate.map(|r| r.to_string()))
        .bind(account.low_balance_threshold.map(decimal_to_cents))
        .bind(account.status.to_string())
        .bind(account.opened_at)
        .bind(account.sync_metadata.updated_at)
        .bind(account.sync_metadata.deleted_at)
        .bind(account.sync_metadata.device_id)
        .bind(account.sync_metadata.synced_at)
        .bind(account.id)
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
                id, name, account_type, ownership, currency_code, initial_balance,
                icon, color, chart_code, parent_id,
                account_number, institution, credit_limit,
                billing_day, payment_due_day, interest_rate,
                low_balance_threshold, status, created_at, opened_at,
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
                id, name, account_type, ownership, currency_code, initial_balance,
                icon, color, chart_code, parent_id,
                account_number, institution, credit_limit,
                billing_day, payment_due_day, interest_rate,
                low_balance_threshold, status, created_at, opened_at,
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

    async fn compute_balances_for_all_accounts(
        &self,
    ) -> Result<std::collections::HashMap<Uuid, Decimal>, sqlx::Error> {
        PostgresAccountRepository::compute_balances_for_all_accounts(self).await
    }

    async fn compute_balance_for_account(&self, id: Uuid) -> Result<Decimal, sqlx::Error> {
        self.compute_balance_for_account_pg(id).await
    }

    async fn get_balance_history(
        &self,
        _account_id: Uuid,
        _days: i32,
    ) -> Result<Vec<(String, Decimal)>, sqlx::Error> {
        // PostgreSQL implementation not yet available
        Ok(Vec::new())
    }
}
