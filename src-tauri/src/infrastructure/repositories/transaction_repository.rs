use crate::domain::{
    aggregates::Transaction,
    repositories::TransactionRepository,
    value_objects::{Money, SyncMetadata, TransactionEntry},
};
use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use sqlx::{sqlite::SqlitePool, Row};
use std::str::FromStr;
use uuid::Uuid;

#[derive(Clone)]
pub struct SqliteTransactionRepository {
    pool: SqlitePool,
}

impl SqliteTransactionRepository {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn parse_sqlite_datetime(s: &str) -> Result<DateTime<Utc>, chrono::ParseError> {
        // Try RFC3339 first (for programmatically inserted data)
        if let Ok(dt) = DateTime::parse_from_rfc3339(s) {
            return Ok(dt.with_timezone(&Utc));
        }
        // Try SQLite format: "YYYY-MM-DD HH:MM:SS"
        chrono::NaiveDateTime::parse_from_str(s, "%Y-%m-%d %H:%M:%S")
            .map(|ndt| DateTime::<Utc>::from_naive_utc_and_offset(ndt, Utc))
    }

    async fn load_entries(
        &self,
        transaction_id: Uuid,
        executor: &mut sqlx::SqliteConnection,
    ) -> sqlx::Result<Vec<TransactionEntry>> {
        let rows = sqlx::query(
            r#"
            SELECT 
                id, account_id, chart_of_account_code,
                CAST(debit_amount AS TEXT) AS debit_amount,
                CAST(credit_amount AS TEXT) AS credit_amount,
                note
            FROM transaction_entries
            WHERE transaction_id = ? AND deleted_at IS NULL
            ORDER BY id
            "#,
        )
        .bind(transaction_id.to_string())
        .fetch_all(&mut *executor)
        .await?;

        let mut entries = Vec::new();
        for row in rows {
            let _id: String = row.try_get("id")?;

            let account_id: String = row.try_get("account_id")?;
            let account_id =
                Uuid::from_str(&account_id).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let chart_of_account_code: String = row.try_get("chart_of_account_code")?;

            let debit_amount_str: Option<String> = row.try_get("debit_amount")?;
            let credit_amount_str: Option<String> = row.try_get("credit_amount")?;

            let note: Option<String> = row.try_get("note")?;

            // Parse amounts and determine currency
            let debit_amount = if let Some(s) = debit_amount_str {
                if s != "null" && !s.is_empty() {
                    let amount =
                        Decimal::from_str(&s).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;
                    // Get currency from the amount - we need to query the account
                    // For now, we'll store currency in the entry or derive it
                    // Since TransactionEntry needs Money, we need currency code
                    // Let's query the account to get currency
                    let currency_code: String =
                        sqlx::query_scalar("SELECT currency_code FROM accounts WHERE id = ?")
                            .bind(account_id.to_string())
                            .fetch_one(&mut *executor)
                            .await?;

                    Some(
                        Money::new(amount, &currency_code)
                            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?,
                    )
                } else {
                    None
                }
            } else {
                None
            };

            let credit_amount = if let Some(s) = credit_amount_str {
                if s != "null" && !s.is_empty() {
                    let amount =
                        Decimal::from_str(&s).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;
                    let currency_code: String =
                        sqlx::query_scalar("SELECT currency_code FROM accounts WHERE id = ?")
                            .bind(account_id.to_string())
                            .fetch_one(&mut *executor)
                            .await?;

                    Some(
                        Money::new(amount, &currency_code)
                            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?,
                    )
                } else {
                    None
                }
            } else {
                None
            };

            let entry = TransactionEntry::new(
                account_id,
                &chart_of_account_code,
                debit_amount,
                credit_amount,
                note.as_deref().unwrap_or(""),
            )
            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            entries.push(entry);
        }

        Ok(entries)
    }
}

impl TransactionRepository for SqliteTransactionRepository {
    async fn create(&self, transaction: &Transaction) -> sqlx::Result<()> {
        let mut tx = self.pool.begin().await?;

        // Insert transaction
        sqlx::query(
            r#"
            INSERT INTO transactions (
                id, transaction_date, description,
                updated_at, deleted_at, device_id, synced_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            "#,
        )
        .bind(transaction.id.to_string())
        .bind(transaction.transaction_date.to_string())
        .bind(&transaction.description)
        .bind(transaction.sync_metadata.updated_at.to_rfc3339())
        .bind(
            transaction
                .sync_metadata
                .deleted_at
                .map(|dt| dt.to_rfc3339()),
        )
        .bind(transaction.sync_metadata.device_id.to_string())
        .bind(
            transaction
                .sync_metadata
                .synced_at
                .map(|dt| dt.to_rfc3339()),
        )
        .execute(&mut *tx)
        .await?;

        // Insert all entries
        for entry in &transaction.entries {
            let (debit_amount, credit_amount) = match (&entry.debit_amount, &entry.credit_amount) {
                (Some(debit), None) => (Some(debit.amount.to_string()), None),
                (None, Some(credit)) => (None, Some(credit.amount.to_string())),
                _ => (None, None),
            };

            sqlx::query(
                r#"
                INSERT INTO transaction_entries (
                    id, transaction_id, account_id, chart_of_account_code,
                    debit_amount, credit_amount, note,
                    updated_at, deleted_at, device_id, synced_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                "#,
            )
            .bind(entry.id.to_string())
            .bind(transaction.id.to_string())
            .bind(entry.account_id.to_string())
            .bind(&entry.chart_of_account_code)
            .bind(debit_amount)
            .bind(credit_amount)
            .bind(&entry.note)
            .bind(transaction.sync_metadata.updated_at.to_rfc3339())
            .bind(
                transaction
                    .sync_metadata
                    .deleted_at
                    .map(|dt| dt.to_rfc3339()),
            )
            .bind(transaction.sync_metadata.device_id.to_string())
            .bind(
                transaction
                    .sync_metadata
                    .synced_at
                    .map(|dt| dt.to_rfc3339()),
            )
            .execute(&mut *tx)
            .await?;
        }

        tx.commit().await?;
        Ok(())
    }

    async fn update(&self, transaction: &Transaction) -> sqlx::Result<bool> {
        let mut tx = self.pool.begin().await?;

        let result = sqlx::query(
            r#"
            UPDATE transactions
            SET transaction_date = ?,
                description = ?,
                updated_at = ?
            WHERE id = ? AND deleted_at IS NULL
            "#,
        )
        .bind(transaction.transaction_date.to_string())
        .bind(&transaction.description)
        .bind(Utc::now().to_rfc3339())
        .bind(transaction.id.to_string())
        .execute(&mut *tx)
        .await?;

        if result.rows_affected() > 0 {
            // Soft delete old entries
            sqlx::query(
                r#"
                UPDATE transaction_entries
                SET deleted_at = CURRENT_TIMESTAMP
                WHERE transaction_id = ? AND deleted_at IS NULL
                "#,
            )
            .bind(transaction.id.to_string())
            .execute(&mut *tx)
            .await?;

            // Insert new entries
            for entry in &transaction.entries {
                let (debit_amount, credit_amount) = match (&entry.debit_amount, &entry.credit_amount) {
                    (Some(debit), None) => (Some(debit.amount.to_string()), None),
                    (None, Some(credit)) => (None, Some(credit.amount.to_string())),
                    _ => (None, None),
                };

                sqlx::query(
                    r#"
                    INSERT INTO transaction_entries (
                        id, transaction_id, account_id, chart_of_account_code,
                        debit_amount, credit_amount, note,
                        updated_at, deleted_at, device_id, synced_at
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    "#,
                )
                .bind(entry.id.to_string())
                .bind(transaction.id.to_string())
                .bind(entry.account_id.to_string())
                .bind(&entry.chart_of_account_code)
                .bind(debit_amount)
                .bind(credit_amount)
                .bind(&entry.note)
                .bind(transaction.sync_metadata.updated_at.to_rfc3339())
                .bind(transaction.sync_metadata.deleted_at.map(|dt| dt.to_rfc3339()))
                .bind(transaction.sync_metadata.device_id.to_string())
                .bind(transaction.sync_metadata.synced_at.map(|dt| dt.to_rfc3339()))
                .execute(&mut *tx)
                .await?;
            }

            tx.commit().await?;
            Ok(true)
        } else {
            Ok(false)
        }
    }

    async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<Transaction>> {
        let mut conn = self.pool.acquire().await?;

        let row = sqlx::query(
            r#"
            SELECT 
                id, transaction_date, description,
                updated_at, deleted_at, device_id, synced_at
            FROM transactions
            WHERE id = ? AND deleted_at IS NULL
            "#,
        )
        .bind(id.to_string())
        .fetch_optional(&mut *conn)
        .await?;

        if let Some(row) = row {
            let id: String = row.try_get("id")?;
            let id = Uuid::from_str(&id).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let transaction_date: String = row.try_get("transaction_date")?;
            let transaction_date = NaiveDate::parse_from_str(&transaction_date, "%Y-%m-%d")
                .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let description: String = row.try_get("description")?;

            let updated_at: String = row.try_get("updated_at")?;
            let deleted_at: Option<String> = row.try_get("deleted_at")?;
            let device_id: String = row.try_get("device_id")?;
            let synced_at: Option<String> = row.try_get("synced_at")?;

            let updated_at_parsed = Self::parse_sqlite_datetime(&updated_at)
                .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let deleted_at_parsed = deleted_at
                .map(|s| Self::parse_sqlite_datetime(&s))
                .transpose()
                .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let device_id_parsed =
                Uuid::from_str(&device_id).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let synced_at_parsed = synced_at
                .map(|s| Self::parse_sqlite_datetime(&s))
                .transpose()
                .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let sync_metadata = SyncMetadata {
                updated_at: updated_at_parsed,
                deleted_at: deleted_at_parsed,
                device_id: device_id_parsed,
                synced_at: synced_at_parsed,
            };

            // Load entries
            let entries = self.load_entries(id, &mut conn).await?;

            // Reconstruct Transaction
            let transaction =
                Transaction::new(id, transaction_date, description, entries, sync_metadata)
                    .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            Ok(Some(transaction))
        } else {
            Ok(None)
        }
    }

    async fn find_by_date_range(
        &self,
        start_date: NaiveDate,
        end_date: NaiveDate,
    ) -> sqlx::Result<Vec<Transaction>> {
        let mut conn = self.pool.acquire().await?;

        let rows = sqlx::query(
            r#"
            SELECT 
                id, transaction_date, description,
                updated_at, deleted_at, device_id, synced_at
            FROM transactions
            WHERE transaction_date BETWEEN ? AND ? AND deleted_at IS NULL
            ORDER BY transaction_date DESC, id DESC
            "#,
        )
        .bind(start_date.to_string())
        .bind(end_date.to_string())
        .fetch_all(&mut *conn)
        .await?;

        let mut transactions = Vec::new();
        for row in rows {
            let id: String = row.try_get("id")?;
            let id = Uuid::from_str(&id).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let transaction_date: String = row.try_get("transaction_date")?;
            let transaction_date = NaiveDate::parse_from_str(&transaction_date, "%Y-%m-%d")
                .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let description: String = row.try_get("description")?;

            let updated_at: String = row.try_get("updated_at")?;
            let deleted_at: Option<String> = row.try_get("deleted_at")?;
            let device_id: String = row.try_get("device_id")?;
            let synced_at: Option<String> = row.try_get("synced_at")?;

            let updated_at_parsed = Self::parse_sqlite_datetime(&updated_at)
                .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let deleted_at_parsed = deleted_at
                .map(|s| Self::parse_sqlite_datetime(&s))
                .transpose()
                .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let device_id_parsed =
                Uuid::from_str(&device_id).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let synced_at_parsed = synced_at
                .map(|s| Self::parse_sqlite_datetime(&s))
                .transpose()
                .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let sync_metadata = SyncMetadata {
                updated_at: updated_at_parsed,
                deleted_at: deleted_at_parsed,
                device_id: device_id_parsed,
                synced_at: synced_at_parsed,
            };

            // Load entries
            let entries = self.load_entries(id, &mut conn).await?;

            // Reconstruct Transaction
            let transaction =
                Transaction::new(id, transaction_date, description, entries, sync_metadata)
                    .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            transactions.push(transaction);
        }

        Ok(transactions)
    }

    async fn find_all(&self) -> sqlx::Result<Vec<Transaction>> {
        let mut conn = self.pool.acquire().await?;

        let rows = sqlx::query(
            r#"
            SELECT 
                id, transaction_date, description,
                updated_at, deleted_at, device_id, synced_at
            FROM transactions
            WHERE deleted_at IS NULL
            ORDER BY transaction_date DESC, id DESC
            "#,
        )
        .fetch_all(&mut *conn)
        .await?;

        let mut transactions = Vec::new();
        for row in rows {
            let id: String = row.try_get("id")?;
            let id = Uuid::from_str(&id).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let transaction_date: String = row.try_get("transaction_date")?;
            let transaction_date = NaiveDate::parse_from_str(&transaction_date, "%Y-%m-%d")
                .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let description: String = row.try_get("description")?;

            let updated_at: String = row.try_get("updated_at")?;
            let deleted_at: Option<String> = row.try_get("deleted_at")?;
            let device_id: String = row.try_get("device_id")?;
            let synced_at: Option<String> = row.try_get("synced_at")?;

            let updated_at_parsed = Self::parse_sqlite_datetime(&updated_at)
                .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let deleted_at_parsed = deleted_at
                .map(|s| Self::parse_sqlite_datetime(&s))
                .transpose()
                .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let device_id_parsed =
                Uuid::from_str(&device_id).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let synced_at_parsed = synced_at
                .map(|s| Self::parse_sqlite_datetime(&s))
                .transpose()
                .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let sync_metadata = SyncMetadata {
                updated_at: updated_at_parsed,
                deleted_at: deleted_at_parsed,
                device_id: device_id_parsed,
                synced_at: synced_at_parsed,
            };

            // Load entries
            let entries = self.load_entries(id, &mut conn).await?;

            // Reconstruct Transaction
            let transaction =
                Transaction::new(id, transaction_date, description, entries, sync_metadata)
                    .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            transactions.push(transaction);
        }

        Ok(transactions)
    }

    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool> {
        let mut tx = self.pool.begin().await?;

        // Soft delete transaction
        let result = sqlx::query(
            r#"
            UPDATE transactions
            SET deleted_at = CURRENT_TIMESTAMP
            WHERE id = ? AND deleted_at IS NULL
            "#,
        )
        .bind(id.to_string())
        .execute(&mut *tx)
        .await?;

        if result.rows_affected() > 0 {
            // Soft delete all entries
            sqlx::query(
                r#"
                UPDATE transaction_entries
                SET deleted_at = CURRENT_TIMESTAMP
                WHERE transaction_id = ? AND deleted_at IS NULL
                "#,
            )
            .bind(id.to_string())
            .execute(&mut *tx)
            .await?;

            tx.commit().await?;
            Ok(true)
        } else {
            Ok(false)
        }
    }

    async fn get_changes_since(&self, timestamp: DateTime<Utc>) -> sqlx::Result<Vec<Transaction>> {
        let mut conn = self.pool.acquire().await?;

        let rows = sqlx::query(
            r#"
            SELECT 
                id, transaction_date, description,
                updated_at, deleted_at, device_id, synced_at
            FROM transactions
            WHERE updated_at > ? AND (synced_at IS NULL OR synced_at < updated_at)
            ORDER BY updated_at ASC
            "#,
        )
        .bind(timestamp.to_rfc3339())
        .fetch_all(&mut *conn)
        .await?;

        let mut transactions = Vec::new();
        for row in rows {
            let id: String = row.try_get("id")?;
            let id = Uuid::from_str(&id).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let transaction_date: String = row.try_get("transaction_date")?;
            let transaction_date = NaiveDate::parse_from_str(&transaction_date, "%Y-%m-%d")
                .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let description: String = row.try_get("description")?;

            let updated_at: String = row.try_get("updated_at")?;
            let deleted_at: Option<String> = row.try_get("deleted_at")?;
            let device_id: String = row.try_get("device_id")?;
            let synced_at: Option<String> = row.try_get("synced_at")?;

            let updated_at_parsed = Self::parse_sqlite_datetime(&updated_at)
                .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let deleted_at_parsed = deleted_at
                .map(|s| Self::parse_sqlite_datetime(&s))
                .transpose()
                .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let device_id_parsed =
                Uuid::from_str(&device_id).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let synced_at_parsed = synced_at
                .map(|s| Self::parse_sqlite_datetime(&s))
                .transpose()
                .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let sync_metadata = SyncMetadata {
                updated_at: updated_at_parsed,
                deleted_at: deleted_at_parsed,
                device_id: device_id_parsed,
                synced_at: synced_at_parsed,
            };

            // Load entries
            let entries = self.load_entries(id, &mut conn).await?;

            // Reconstruct Transaction
            let transaction =
                Transaction::new(id, transaction_date, description, entries, sync_metadata)
                    .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            transactions.push(transaction);
        }

        Ok(transactions)
    }

    async fn mark_as_synced(&self, id: Uuid) -> sqlx::Result<bool> {
        let mut tx = self.pool.begin().await?;

        let result = sqlx::query(
            r#"
            UPDATE transactions
            SET synced_at = ?
            WHERE id = ?
            "#,
        )
        .bind(Utc::now().to_rfc3339())
        .bind(id.to_string())
        .execute(&mut *tx)
        .await?;

        if result.rows_affected() > 0 {
            // Also mark entries as synced
            sqlx::query(
                r#"
                UPDATE transaction_entries
                SET synced_at = ?
                WHERE transaction_id = ?
                "#,
            )
            .bind(Utc::now().to_rfc3339())
            .bind(id.to_string())
            .execute(&mut *tx)
            .await?;

            tx.commit().await?;
            Ok(true)
        } else {
            Ok(false)
        }
    }
}
