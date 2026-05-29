use crate::domain::repositories::PrepaidRepository;
use crate::domain::value_objects::TopUpRecord;
use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use sqlx::{Row, SqlitePool};
use std::str::FromStr;
use uuid::Uuid;

pub struct SqlitePrepaidRepository {
    pool: SqlitePool,
}

impl SqlitePrepaidRepository {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

fn parse_sqlite_datetime(s: &str) -> Result<DateTime<Utc>, chrono::ParseError> {
    if let Ok(dt) = DateTime::parse_from_rfc3339(s) {
        return Ok(dt.with_timezone(&Utc));
    }
    chrono::NaiveDateTime::parse_from_str(s, "%Y-%m-%d %H:%M:%S")
        .map(|ndt| DateTime::<Utc>::from_naive_utc_and_offset(ndt, Utc))
}

fn row_to_top_up_record(row: &sqlx::sqlite::SqliteRow) -> Result<TopUpRecord, sqlx::Error> {
    let id_str: String = row.try_get("id")?;
    let id = Uuid::parse_str(&id_str)
        .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?;

    let account_id_str: String = row.try_get("account_id")?;
    let account_id = Uuid::parse_str(&account_id_str)
        .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?;

    let transaction_id_str: String = row.try_get("transaction_id")?;
    let transaction_id = Uuid::parse_str(&transaction_id_str)
        .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?;

    let paid_amount_str: String = row.try_get("paid_amount")?;
    let paid_amount = Decimal::from_str(&paid_amount_str)
        .map_err(|e| sqlx::Error::Decode(format!("invalid decimal: {}", e).into()))?;

    let bonus_amount_str: String = row.try_get("bonus_amount")?;
    let bonus_amount = Decimal::from_str(&bonus_amount_str)
        .map_err(|e| sqlx::Error::Decode(format!("invalid decimal: {}", e).into()))?;

    let total_credited_str: String = row.try_get("total_credited")?;
    let total_credited = Decimal::from_str(&total_credited_str)
        .map_err(|e| sqlx::Error::Decode(format!("invalid decimal: {}", e).into()))?;

    let top_up_date_str: String = row.try_get("top_up_date")?;
    let top_up_date = NaiveDate::parse_from_str(&top_up_date_str, "%Y-%m-%d")
        .map_err(|e| sqlx::Error::Decode(format!("invalid date: {}", e).into()))?;

    let expiry_date_str: Option<String> = row.try_get("expiry_date")?;
    let expiry_date = expiry_date_str
        .map(|s| {
            NaiveDate::parse_from_str(&s, "%Y-%m-%d")
                .map_err(|e| sqlx::Error::Decode(format!("invalid date: {}", e).into()))
        })
        .transpose()?;

    let source_account_id_str: String = row.try_get("source_account_id")?;
    let source_account_id = Uuid::parse_str(&source_account_id_str)
        .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?;

    let description: Option<String> = row.try_get("description")?;

    let created_at_str: String = row.try_get("created_at")?;
    let created_at = parse_sqlite_datetime(&created_at_str)
        .map_err(|e| sqlx::Error::Decode(format!("invalid datetime: {}", e).into()))?;

    let updated_at_str: String = row.try_get("updated_at")?;
    let updated_at = parse_sqlite_datetime(&updated_at_str)
        .map_err(|e| sqlx::Error::Decode(format!("invalid datetime: {}", e).into()))?;

    Ok(TopUpRecord {
        id,
        account_id,
        transaction_id,
        paid_amount,
        bonus_amount,
        total_credited,
        top_up_date,
        expiry_date,
        source_account_id,
        description,
        created_at,
        updated_at,
    })
}

impl PrepaidRepository for SqlitePrepaidRepository {
    async fn create_top_up_record(&self, record: &TopUpRecord) -> sqlx::Result<()> {
        sqlx::query(
            r#"
            INSERT INTO top_up_records (
                id, account_id, transaction_id, paid_amount, bonus_amount,
                total_credited, top_up_date, expiry_date, source_account_id,
                description, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            "#,
        )
        .bind(record.id.to_string())
        .bind(record.account_id.to_string())
        .bind(record.transaction_id.to_string())
        .bind(record.paid_amount.to_string())
        .bind(record.bonus_amount.to_string())
        .bind(record.total_credited.to_string())
        .bind(record.top_up_date.to_string())
        .bind(record.expiry_date.map(|d| d.to_string()))
        .bind(record.source_account_id.to_string())
        .bind(&record.description)
        .bind(record.created_at.to_rfc3339())
        .bind(record.updated_at.to_rfc3339())
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn find_top_up_records_by_account(
        &self,
        account_id: Uuid,
    ) -> sqlx::Result<Vec<TopUpRecord>> {
        let rows = sqlx::query(
            r#"
            SELECT id, account_id, transaction_id,
                   CAST(paid_amount AS TEXT) as paid_amount,
                   CAST(bonus_amount AS TEXT) as bonus_amount,
                   CAST(total_credited AS TEXT) as total_credited,
                   top_up_date, expiry_date, source_account_id,
                   description, created_at, updated_at
            FROM top_up_records
            WHERE account_id = ?
            ORDER BY top_up_date DESC
            "#,
        )
        .bind(account_id.to_string())
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(|r| row_to_top_up_record(r)).collect()
    }

    async fn find_top_up_record_by_id(&self, id: Uuid) -> sqlx::Result<Option<TopUpRecord>> {
        let row = sqlx::query(
            r#"
            SELECT id, account_id, transaction_id,
                   CAST(paid_amount AS TEXT) as paid_amount,
                   CAST(bonus_amount AS TEXT) as bonus_amount,
                   CAST(total_credited AS TEXT) as total_credited,
                   top_up_date, expiry_date, source_account_id,
                   description, created_at, updated_at
            FROM top_up_records
            WHERE id = ?
            "#,
        )
        .bind(id.to_string())
        .fetch_optional(&self.pool)
        .await?;

        row.as_ref().map(|r| row_to_top_up_record(r)).transpose()
    }

    async fn find_top_up_record_by_transaction(
        &self,
        transaction_id: Uuid,
    ) -> sqlx::Result<Option<TopUpRecord>> {
        let row = sqlx::query(
            r#"
            SELECT id, account_id, transaction_id,
                   CAST(paid_amount AS TEXT) as paid_amount,
                   CAST(bonus_amount AS TEXT) as bonus_amount,
                   CAST(total_credited AS TEXT) as total_credited,
                   top_up_date, expiry_date, source_account_id,
                   description, created_at, updated_at
            FROM top_up_records
            WHERE transaction_id = ?
            "#,
        )
        .bind(transaction_id.to_string())
        .fetch_optional(&self.pool)
        .await?;

        row.as_ref().map(|r| row_to_top_up_record(r)).transpose()
    }
}
