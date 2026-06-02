// TODO: will be used when Chart of Accounts feature is wired
#![allow(dead_code)]

use crate::domain::{
    aggregates::{BalanceDirection, ChartOfAccounts, ChartOfAccountsError, ChartOfAccountsType},
    repositories::ChartOfAccountsRepository,
};
use chrono::{DateTime, Utc};
use sqlx::{sqlite::SqlitePool, Row};

#[derive(Clone)]
pub struct SqliteChartOfAccountsRepository {
    pool: SqlitePool,
}

impl SqliteChartOfAccountsRepository {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn row_to_chart_of_accounts(
        row: &sqlx::sqlite::SqliteRow,
    ) -> Result<ChartOfAccounts, sqlx::Error> {
        let id: String = row.try_get("id")?;
        let code: String = row.try_get("code")?;
        let name: String = row.try_get("name")?;
        let level: i32 = row.try_get("level")?;
        let account_type_str: String = row.try_get("account_type")?;
        let parent_code: Option<String> = row.try_get("parent_code")?;
        let balance_direction_str: String = row.try_get("balance_direction")?;
        let deleted_at: Option<String> = row.try_get("deleted_at")?;
        let updated_at: String = row.try_get("updated_at")?;
        let device_id: Option<String> = row.try_get("device_id")?;
        let synced_at: Option<String> = row.try_get("synced_at")?;

        let account_type = ChartOfAccountsType::from_str(&account_type_str)
            .map_err(|e: ChartOfAccountsError| sqlx::Error::Decode(Box::new(e)))?;

        let balance_direction = BalanceDirection::from_str(&balance_direction_str)
            .map_err(|e: ChartOfAccountsError| sqlx::Error::Decode(Box::new(e)))?;

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

        let deleted_at_parsed = deleted_at
            .map(|s| parse_sqlite_datetime(&s))
            .transpose()
            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

        let updated_at_parsed =
            parse_sqlite_datetime(&updated_at).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

        let synced_at_parsed = synced_at
            .map(|s| parse_sqlite_datetime(&s))
            .transpose()
            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

        Ok(ChartOfAccounts {
            id,
            code,
            name,
            level,
            account_type,
            parent_code,
            balance_direction,
            deleted_at: deleted_at_parsed,
            updated_at: updated_at_parsed,
            device_id,
            synced_at: synced_at_parsed,
        })
    }
}

impl ChartOfAccountsRepository for SqliteChartOfAccountsRepository {
    async fn create(&self, account: &ChartOfAccounts) -> sqlx::Result<()> {
        sqlx::query(
            r#"
            INSERT INTO chart_of_accounts (
                id, code, name, level, account_type, parent_code, 
                balance_direction, deleted_at, updated_at, device_id, synced_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            "#,
        )
        .bind(&account.id)
        .bind(&account.code)
        .bind(&account.name)
        .bind(account.level)
        .bind(account.account_type.to_string())
        .bind(&account.parent_code)
        .bind(account.balance_direction.to_string())
        .bind(account.deleted_at.map(|dt| dt.to_rfc3339()))
        .bind(account.updated_at.to_rfc3339())
        .bind(&account.device_id)
        .bind(account.synced_at.map(|dt| dt.to_rfc3339()))
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn update(&self, account: &ChartOfAccounts) -> sqlx::Result<bool> {
        let result = sqlx::query(
            r#"
            UPDATE chart_of_accounts
            SET name = ?, level = ?, account_type = ?, parent_code = ?,
                balance_direction = ?, deleted_at = ?, updated_at = ?,
                device_id = ?, synced_at = ?
            WHERE code = ?
            "#,
        )
        .bind(&account.name)
        .bind(account.level)
        .bind(account.account_type.to_string())
        .bind(&account.parent_code)
        .bind(account.balance_direction.to_string())
        .bind(account.deleted_at.map(|dt| dt.to_rfc3339()))
        .bind(account.updated_at.to_rfc3339())
        .bind(&account.device_id)
        .bind(account.synced_at.map(|dt| dt.to_rfc3339()))
        .bind(&account.code)
        .execute(&self.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    async fn find_by_code(&self, code: &str) -> sqlx::Result<Option<ChartOfAccounts>> {
        let row = sqlx::query(
            r#"
            SELECT id, code, name, level, account_type, parent_code, 
                   balance_direction, deleted_at, updated_at, device_id, synced_at
            FROM chart_of_accounts
            WHERE code = ? AND deleted_at IS NULL
            "#,
        )
        .bind(code)
        .fetch_optional(&self.pool)
        .await?;

        row.map(|row| Self::row_to_chart_of_accounts(&row))
            .transpose()
    }

    async fn list_by_level(&self, level: i32) -> sqlx::Result<Vec<ChartOfAccounts>> {
        let rows = sqlx::query(
            r#"
            SELECT id, code, name, level, account_type, parent_code, 
                   balance_direction, deleted_at, updated_at, device_id, synced_at
            FROM chart_of_accounts
            WHERE level = ? AND deleted_at IS NULL
            ORDER BY code ASC
            "#,
        )
        .bind(level)
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(Self::row_to_chart_of_accounts).collect()
    }

    async fn list_by_type(
        &self,
        account_type: ChartOfAccountsType,
    ) -> sqlx::Result<Vec<ChartOfAccounts>> {
        let rows = sqlx::query(
            r#"
            SELECT id, code, name, level, account_type, parent_code, 
                   balance_direction, deleted_at, updated_at, device_id, synced_at
            FROM chart_of_accounts
            WHERE account_type = ? AND deleted_at IS NULL
            ORDER BY code ASC
            "#,
        )
        .bind(account_type.to_string())
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(Self::row_to_chart_of_accounts).collect()
    }

    async fn get_children(&self, parent_code: &str) -> sqlx::Result<Vec<ChartOfAccounts>> {
        let rows = sqlx::query(
            r#"
            SELECT id, code, name, level, account_type, parent_code, 
                   balance_direction, deleted_at, updated_at, device_id, synced_at
            FROM chart_of_accounts
            WHERE parent_code = ? AND deleted_at IS NULL
            ORDER BY code ASC
            "#,
        )
        .bind(parent_code)
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(Self::row_to_chart_of_accounts).collect()
    }

    async fn list_all(&self) -> sqlx::Result<Vec<ChartOfAccounts>> {
        let rows = sqlx::query(
            r#"
            SELECT id, code, name, level, account_type, parent_code, 
                   balance_direction, deleted_at, updated_at, device_id, synced_at
            FROM chart_of_accounts
            WHERE deleted_at IS NULL
            ORDER BY code ASC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(Self::row_to_chart_of_accounts).collect()
    }
}
