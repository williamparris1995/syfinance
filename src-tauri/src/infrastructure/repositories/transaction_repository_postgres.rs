use crate::domain::{
    aggregates::Transaction,
    repositories::TransactionRepository,
    value_objects::{Money, SyncMetadata, TransactionEntry},
};
use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use sqlx::{postgres::PgPool, Row};
use uuid::Uuid;

#[derive(Clone)]
pub struct PostgresTransactionRepository {
    pool: PgPool,
}

impl PostgresTransactionRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    async fn load_entries(
        &self,
        transaction_id: Uuid,
        executor: &mut sqlx::PgConnection,
    ) -> sqlx::Result<Vec<TransactionEntry>> {
        let rows = sqlx::query(
            r#"
            SELECT 
                id, account_id, chart_of_account_code,
                debit_amount, credit_amount, note
            FROM transaction_entries
            WHERE transaction_id = $1 AND deleted_at IS NULL
            ORDER BY id
            "#,
        )
        .bind(transaction_id)
        .fetch_all(&mut *executor)
        .await?;

        let mut entries = Vec::new();
        for row in rows {
            let _id: Uuid = row.try_get("id")?;
            let account_id: Uuid = row.try_get("account_id")?;
            let chart_of_account_code: String = row.try_get("chart_of_account_code")?;
            let debit_amount: Option<Decimal> = row.try_get("debit_amount")?;
            let credit_amount: Option<Decimal> = row.try_get("credit_amount")?;
            let note: Option<String> = row.try_get("note")?;

            // Get currency from account
            let currency_code: String =
                sqlx::query_scalar("SELECT currency_code FROM accounts WHERE id = $1")
                    .bind(account_id)
                    .fetch_one(&mut *executor)
                    .await?;

            let debit_money = debit_amount
                .map(|amt| Money::new(amt, &currency_code))
                .transpose()
                .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let credit_money = credit_amount
                .map(|amt| Money::new(amt, &currency_code))
                .transpose()
                .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let entry = TransactionEntry::new(
                account_id,
                &chart_of_account_code,
                debit_money,
                credit_money,
                note.as_deref().unwrap_or(""),
            )
            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            entries.push(entry);
        }

        Ok(entries)
    }
}

impl TransactionRepository for PostgresTransactionRepository {
    async fn create(&self, transaction: &Transaction) -> sqlx::Result<()> {
        let mut tx = self.pool.begin().await?;

        // Insert transaction with UPSERT
        sqlx::query(
            r#"
            INSERT INTO transactions (
                id, transaction_date, description,
                updated_at, deleted_at, device_id, synced_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            ON CONFLICT (id) DO UPDATE SET
                transaction_date = EXCLUDED.transaction_date,
                description = EXCLUDED.description,
                updated_at = EXCLUDED.updated_at,
                deleted_at = EXCLUDED.deleted_at,
                device_id = EXCLUDED.device_id,
                synced_at = EXCLUDED.synced_at
            "#,
        )
        .bind(transaction.id)
        .bind(transaction.transaction_date)
        .bind(&transaction.description)
        .bind(transaction.sync_metadata.updated_at)
        .bind(transaction.sync_metadata.deleted_at)
        .bind(transaction.sync_metadata.device_id)
        .bind(transaction.sync_metadata.synced_at)
        .execute(&mut *tx)
        .await?;

        // Insert all entries with UPSERT
        for entry in &transaction.entries {
            let (debit_amount, credit_amount) = match (&entry.debit_amount, &entry.credit_amount) {
                (Some(debit), None) => (Some(debit.amount), None),
                (None, Some(credit)) => (None, Some(credit.amount)),
                _ => (None, None),
            };

            sqlx::query(
                r#"
                INSERT INTO transaction_entries (
                    id, transaction_id, account_id, chart_of_account_code,
                    debit_amount, credit_amount, note,
                    updated_at, deleted_at, device_id, synced_at
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
                ON CONFLICT (id) DO UPDATE SET
                    account_id = EXCLUDED.account_id,
                    chart_of_account_code = EXCLUDED.chart_of_account_code,
                    debit_amount = EXCLUDED.debit_amount,
                    credit_amount = EXCLUDED.credit_amount,
                    note = EXCLUDED.note,
                    updated_at = EXCLUDED.updated_at,
                    deleted_at = EXCLUDED.deleted_at,
                    device_id = EXCLUDED.device_id,
                    synced_at = EXCLUDED.synced_at
                "#,
            )
            .bind(entry.id)
            .bind(transaction.id)
            .bind(entry.account_id)
            .bind(&entry.chart_of_account_code)
            .bind(debit_amount)
            .bind(credit_amount)
            .bind(&entry.note)
            .bind(transaction.sync_metadata.updated_at)
            .bind(transaction.sync_metadata.deleted_at)
            .bind(transaction.sync_metadata.device_id)
            .bind(transaction.sync_metadata.synced_at)
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
            SET transaction_date = $1,
                description = $2,
                updated_at = NOW()
            WHERE id = $3 AND deleted_at IS NULL
            RETURNING id
            "#,
        )
        .bind(transaction.transaction_date)
        .bind(&transaction.description)
        .bind(transaction.id)
        .fetch_optional(&mut *tx)
        .await?;

        if result.is_some() {
            // Soft delete old entries
            sqlx::query(
                r#"
                UPDATE transaction_entries
                SET deleted_at = NOW()
                WHERE transaction_id = $1 AND deleted_at IS NULL
                "#,
            )
            .bind(transaction.id)
            .execute(&mut *tx)
            .await?;

            // Insert new entries
            for entry in &transaction.entries {
                let (debit_amount, credit_amount) = match (&entry.debit_amount, &entry.credit_amount) {
                    (Some(debit), None) => (Some(debit.amount), None),
                    (None, Some(credit)) => (None, Some(credit.amount)),
                    _ => (None, None),
                };

                sqlx::query(
                    r#"
                    INSERT INTO transaction_entries (
                        id, transaction_id, account_id, chart_of_account_code,
                        debit_amount, credit_amount, note,
                        updated_at, deleted_at, device_id, synced_at
                    )
                    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
                    "#,
                )
                .bind(entry.id)
                .bind(transaction.id)
                .bind(entry.account_id)
                .bind(&entry.chart_of_account_code)
                .bind(debit_amount)
                .bind(credit_amount)
                .bind(&entry.note)
                .bind(transaction.sync_metadata.updated_at)
                .bind(transaction.sync_metadata.deleted_at)
                .bind(transaction.sync_metadata.device_id)
                .bind(transaction.sync_metadata.synced_at)
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
            WHERE id = $1 AND deleted_at IS NULL
            "#,
        )
        .bind(id)
        .fetch_optional(&mut *conn)
        .await?;

        if let Some(row) = row {
            let id: Uuid = row.try_get("id")?;
            let transaction_date: NaiveDate = row.try_get("transaction_date")?;
            let description: String = row.try_get("description")?;
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

            let entries = self.load_entries(id, &mut conn).await?;

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
            WHERE transaction_date BETWEEN $1 AND $2 AND deleted_at IS NULL
            ORDER BY transaction_date DESC, id DESC
            "#,
        )
        .bind(start_date)
        .bind(end_date)
        .fetch_all(&mut *conn)
        .await?;

        let mut transactions = Vec::new();
        for row in rows {
            let id: Uuid = row.try_get("id")?;
            let transaction_date: NaiveDate = row.try_get("transaction_date")?;
            let description: String = row.try_get("description")?;
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

            let entries = self.load_entries(id, &mut conn).await?;

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
            let id: Uuid = row.try_get("id")?;
            let transaction_date: NaiveDate = row.try_get("transaction_date")?;
            let description: String = row.try_get("description")?;
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

            let entries = self.load_entries(id, &mut conn).await?;

            let transaction =
                Transaction::new(id, transaction_date, description, entries, sync_metadata)
                    .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            transactions.push(transaction);
        }

        Ok(transactions)
    }

    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool> {
        let mut tx = self.pool.begin().await?;

        // Soft delete transaction with RETURNING
        let result = sqlx::query(
            r#"
            UPDATE transactions
            SET deleted_at = NOW()
            WHERE id = $1 AND deleted_at IS NULL
            RETURNING id
            "#,
        )
        .bind(id)
        .fetch_optional(&mut *tx)
        .await?;

        if result.is_some() {
            // Soft delete all entries
            sqlx::query(
                r#"
                UPDATE transaction_entries
                SET deleted_at = NOW()
                WHERE transaction_id = $1 AND deleted_at IS NULL
                "#,
            )
            .bind(id)
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
            WHERE updated_at > $1 AND (synced_at IS NULL OR synced_at < updated_at)
            ORDER BY updated_at ASC
            "#,
        )
        .bind(timestamp)
        .fetch_all(&mut *conn)
        .await?;

        let mut transactions = Vec::new();
        for row in rows {
            let id: Uuid = row.try_get("id")?;
            let transaction_date: NaiveDate = row.try_get("transaction_date")?;
            let description: String = row.try_get("description")?;
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

            let entries = self.load_entries(id, &mut conn).await?;

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
            SET synced_at = NOW()
            WHERE id = $1
            RETURNING id
            "#,
        )
        .bind(id)
        .fetch_optional(&mut *tx)
        .await?;

        if result.is_some() {
            // Also mark entries as synced
            sqlx::query(
                r#"
                UPDATE transaction_entries
                SET synced_at = NOW()
                WHERE transaction_id = $1
                "#,
            )
            .bind(id)
            .execute(&mut *tx)
            .await?;

            tx.commit().await?;
            Ok(true)
        } else {
            Ok(false)
        }
    }
}
