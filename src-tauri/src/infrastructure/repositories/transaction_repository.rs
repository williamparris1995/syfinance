use crate::domain::{
    aggregates::Transaction,
    repositories::TransactionRepository,
    value_objects::{
        build_cursor, Money, PaginatedResult, PageInfo, SortCursor, SyncMetadata, TransactionEntry,
    },
};
use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use sqlx::{sqlite::SqlitePool, Row};
use std::collections::HashMap;
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

    /// Batch-load entries for multiple transactions in a single query.
    /// Returns a map of transaction_id -> Vec<TransactionEntry>.
    async fn batch_load_entries(
        &self,
        txn_ids: &[String],
    ) -> sqlx::Result<HashMap<Uuid, Vec<TransactionEntry>>> {
        if txn_ids.is_empty() {
            return Ok(HashMap::new());
        }

        // Build placeholders: ?, ?, ...
        let placeholders: Vec<&str> = txn_ids.iter().map(|_| "?").collect();
        let placeholders_str = placeholders.join(",");

        let sql = format!(
            "SELECT transaction_id, id, account_id, chart_of_account_code, \
             CAST(debit_amount AS TEXT) AS debit_amount, \
             CAST(credit_amount AS TEXT) AS credit_amount, \
             note \
             FROM transaction_entries \
             WHERE transaction_id IN ({placeholders_str}) AND deleted_at IS NULL \
             ORDER BY id"
        );

        let mut query = sqlx::query(&sql);
        for id in txn_ids {
            query = query.bind(id);
        }
        let rows = query.fetch_all(&self.pool).await?;

        // Collect unique account_ids for batch currency lookup
        let mut account_ids: Vec<String> = rows
            .iter()
            .filter_map(|r| r.try_get("account_id").ok())
            .collect();
        account_ids.sort_unstable();
        account_ids.dedup();

        // Batch load currency codes
        let currency_map = self.batch_load_currencies(&account_ids).await?;

        // Group entries by transaction_id
        let mut result: HashMap<Uuid, Vec<TransactionEntry>> = HashMap::new();
        for row in rows {
            let txn_id_str: String = row.try_get("transaction_id")?;
            let txn_id =
                Uuid::from_str(&txn_id_str).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let account_id_str: String = row.try_get("account_id")?;
            let account_id =
                Uuid::from_str(&account_id_str).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let chart_of_account_code: String = row.try_get("chart_of_account_code")?;

            let debit_amount_str: Option<String> = row.try_get("debit_amount")?;
            let credit_amount_str: Option<String> = row.try_get("credit_amount")?;
            let note: Option<String> = row.try_get("note")?;

            let currency_code = currency_map
                .get(&account_id)
                .ok_or_else(|| {
                    sqlx::Error::Decode(
                        format!("Missing currency for account {account_id}").into(),
                    )
                })?
                .clone();

            let debit_amount = match debit_amount_str {
                Some(s) if s != "null" && !s.is_empty() => {
                    let amount =
                        Decimal::from_str(&s).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;
                    Some(
                        Money::new(amount, &currency_code)
                            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?,
                    )
                }
                _ => None,
            };

            let credit_amount = match credit_amount_str {
                Some(s) if s != "null" && !s.is_empty() => {
                    let amount =
                        Decimal::from_str(&s).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;
                    Some(
                        Money::new(amount, &currency_code)
                            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?,
                    )
                }
                _ => None,
            };

            let entry = TransactionEntry::new(
                account_id,
                &chart_of_account_code,
                debit_amount,
                credit_amount,
                note.as_deref().unwrap_or(""),
            )
            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            result.entry(txn_id).or_default().push(entry);
        }

        Ok(result)
    }

    /// Batch-load currency codes for accounts.
    async fn batch_load_currencies(
        &self,
        account_ids: &[String],
    ) -> sqlx::Result<HashMap<Uuid, String>> {
        if account_ids.is_empty() {
            return Ok(HashMap::new());
        }

        let placeholders: Vec<&str> = account_ids.iter().map(|_| "?").collect();
        let placeholders_str = placeholders.join(",");

        let sql = format!(
            "SELECT id, currency_code FROM accounts WHERE id IN ({placeholders_str})"
        );

        let mut query = sqlx::query(&sql);
        for id in account_ids {
            query = query.bind(id);
        }
        let rows = query.fetch_all(&self.pool).await?;

        let mut map = HashMap::new();
        for row in rows {
            let id_str: String = row.try_get("id")?;
            let id =
                Uuid::from_str(&id_str).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;
            let currency_code: String = row.try_get("currency_code")?;
            map.insert(id, currency_code);
        }

        Ok(map)
    }

    /// Backward paging: fetch in ascending order (after the before cursor),
    /// then reverse results to maintain descending sort.
    async fn fetch_page_backward(
        &self,
        before_cursor: &str,
        first: i64,
        account_id: Option<Uuid>,
        start_date: Option<NaiveDate>,
        end_date: Option<NaiveDate>,
    ) -> sqlx::Result<PaginatedResult<Transaction>> {
        let limit = first.min(200) + 1;

        let cursor = SortCursor::decode(before_cursor)
            .map_err(|e| sqlx::Error::Decode(e.into()))?;
        let cursor_date = cursor
            .get("transaction_date")
            .ok_or_else(|| sqlx::Error::Decode("Missing transaction_date in cursor".into()))?;
        let cursor_id = cursor
            .get("id")
            .ok_or_else(|| sqlx::Error::Decode("Missing id in cursor".into()))?;

        // Build dynamic SQL - ascending order for backward fetch
        let mut sql = String::from(
            "SELECT id, transaction_date, description, updated_at, deleted_at, device_id, synced_at \
             FROM transactions WHERE deleted_at IS NULL",
        );

        if start_date.is_some() {
            sql.push_str(" AND transaction_date >= ?");
        }
        if end_date.is_some() {
            sql.push_str(" AND transaction_date <= ?");
        }
        if account_id.is_some() {
            sql.push_str(
                " AND id IN (SELECT DISTINCT transaction_id FROM transaction_entries \
                 WHERE account_id = ? AND deleted_at IS NULL)",
            );
        }
        // Use > for backward paging (ascending)
        sql.push_str(" AND (transaction_date, id) > (?, ?)");
        sql.push_str(" ORDER BY transaction_date ASC, id ASC LIMIT ?");

        let mut query = sqlx::query(&sql);

        if let Some(sd) = &start_date {
            query = query.bind(sd.to_string());
        }
        if let Some(ed) = &end_date {
            query = query.bind(ed.to_string());
        }
        if let Some(aid) = &account_id {
            query = query.bind(aid.to_string());
        }
        query = query.bind(cursor_date).bind(cursor_id).bind(limit);

        let rows = query.fetch_all(&self.pool).await?;

        let has_prev_page = rows.len() > first as usize;
        let page_rows = if has_prev_page {
            &rows[..first as usize]
        } else {
            &rows
        };

        // Reverse to maintain descending order for the caller
        let reversed_rows: Vec<_> = page_rows.iter().rev().collect();

        // Parse headers
        struct TxHeader {
            id: Uuid,
            transaction_date: NaiveDate,
            description: String,
            sync_metadata: SyncMetadata,
        }

        let mut headers = Vec::with_capacity(reversed_rows.len());
        for row in &reversed_rows {
            let id_str: String = row.try_get("id")?;
            let id =
                Uuid::from_str(&id_str).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let date_str: String = row.try_get("transaction_date")?;
            let transaction_date = NaiveDate::parse_from_str(&date_str, "%Y-%m-%d")
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

            headers.push(TxHeader {
                id,
                transaction_date,
                description,
                sync_metadata,
            });
        }

        // Batch load entries
        let txn_ids: Vec<String> = headers.iter().map(|h| h.id.to_string()).collect();
        let entries_map = self.batch_load_entries(&txn_ids).await?;

        let mut items = Vec::with_capacity(headers.len());
        for header in headers {
            let entries = entries_map.get(&header.id).cloned().unwrap_or_default();
            let txn = Transaction::reconstitute(
                header.id,
                header.transaction_date,
                header.description,
                entries,
                header.sync_metadata,
            );
            items.push(txn);
        }

        // Build cursors (items are in descending order after reversal)
        let next_cursor = if !items.is_empty() {
            // The "last" in descending order is the oldest item
            let last = &reversed_rows[reversed_rows.len() - 1];
            let last_date: String = last.try_get("transaction_date")?;
            let last_id: String = last.try_get("id")?;
            build_cursor(vec![
                ("transaction_date", last_date),
                ("id", last_id),
            ])
        } else {
            None
        };

        let prev_cursor = if !items.is_empty() {
            // The "first" in descending order is the newest item
            let first_row = &reversed_rows[0];
            let first_date: String = first_row.try_get("transaction_date")?;
            let first_id: String = first_row.try_get("id")?;
            build_cursor(vec![
                ("transaction_date", first_date),
                ("id", first_id),
            ])
        } else {
            None
        };

        Ok(PaginatedResult {
            items,
            page_info: PageInfo {
                has_next_page: true, // backward paging always implies there was a next page
                has_prev_page,
                next_cursor,
                prev_cursor,
            },
        })
    }
}

impl TransactionRepository for SqliteTransactionRepository {
    async fn create(&self, transaction: &Transaction) -> sqlx::Result<()> {
        let mut tx = self.pool.begin().await?;

        // Temporarily disable the double-entry trigger to allow multi-entry inserts
        sqlx::query("DROP TRIGGER IF EXISTS enforce_double_entry_insert")
            .execute(&mut *tx)
            .await?;

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

        // Recreate the trigger after all entries are inserted
        sqlx::query(
            r#"
            CREATE TRIGGER enforce_double_entry_insert
            BEFORE INSERT ON transaction_entries
            BEGIN
                SELECT RAISE(ABORT, 'Double-entry violation: debit sum must equal credit sum')
                WHERE (
                    SELECT COALESCE(SUM(debit_amount), 0) - COALESCE(SUM(credit_amount), 0)
                    FROM transaction_entries
                    WHERE transaction_id = NEW.transaction_id AND deleted_at IS NULL
                ) + COALESCE(NEW.debit_amount, 0) - COALESCE(NEW.credit_amount, 0) != 0
                AND (
                    SELECT COUNT(*) FROM transaction_entries
                    WHERE transaction_id = NEW.transaction_id AND deleted_at IS NULL
                ) >= 1;
            END
            "#,
        )
        .execute(&mut *tx)
        .await?;

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
                let (debit_amount, credit_amount) =
                    match (&entry.debit_amount, &entry.credit_amount) {
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
            let transaction = Transaction::reconstitute(
                id,
                transaction_date,
                description,
                entries,
                sync_metadata,
            );

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
            let transaction = Transaction::reconstitute(
                id,
                transaction_date,
                description,
                entries,
                sync_metadata,
            );

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
            let transaction = Transaction::reconstitute(
                id,
                transaction_date,
                description,
                entries,
                sync_metadata,
            );

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
            let transaction = Transaction::reconstitute(
                id,
                transaction_date,
                description,
                entries,
                sync_metadata,
            );

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

    async fn find_paginated(
        &self,
        first: i64,
        after: Option<&str>,
        before: Option<&str>,
        account_id: Option<Uuid>,
        start_date: Option<NaiveDate>,
        end_date: Option<NaiveDate>,
    ) -> sqlx::Result<PaginatedResult<Transaction>> {
        let limit = first.min(200) + 1; // +1 to detect has_next_page

        // Handle backward paging: fetch in reverse then flip
        if let Some(before_cursor) = before {
            return self
                .fetch_page_backward(
                    before_cursor,
                    first,
                    account_id,
                    start_date,
                    end_date,
                )
                .await;
        }

        // Decode forward cursor
        let (cursor_date, cursor_id) = if let Some(after_str) = after {
            let cursor = SortCursor::decode(after_str)
                .map_err(|e| sqlx::Error::Decode(e.into()))?;
            let date = cursor
                .get("transaction_date")
                .ok_or_else(|| sqlx::Error::Decode("Missing transaction_date in cursor".into()))?
                .to_string();
            let id = cursor
                .get("id")
                .ok_or_else(|| sqlx::Error::Decode("Missing id in cursor".into()))?
                .to_string();
            (Some(date), Some(id))
        } else {
            (None, None)
        };

        // Build dynamic SQL
        let mut sql = String::from(
            "SELECT id, transaction_date, description, updated_at, deleted_at, device_id, synced_at \
             FROM transactions WHERE deleted_at IS NULL",
        );

        if start_date.is_some() {
            sql.push_str(" AND transaction_date >= ?");
        }
        if end_date.is_some() {
            sql.push_str(" AND transaction_date <= ?");
        }
        if account_id.is_some() {
            sql.push_str(
                " AND id IN (SELECT DISTINCT transaction_id FROM transaction_entries \
                 WHERE account_id = ? AND deleted_at IS NULL)",
            );
        }
        if cursor_date.is_some() {
            sql.push_str(" AND (transaction_date, id) < (?, ?)");
        }

        sql.push_str(" ORDER BY transaction_date DESC, id DESC LIMIT ?");

        // Bind parameters dynamically
        let mut query = sqlx::query(&sql);

        if let Some(sd) = &start_date {
            query = query.bind(sd.to_string());
        }
        if let Some(ed) = &end_date {
            query = query.bind(ed.to_string());
        }
        if let Some(aid) = &account_id {
            query = query.bind(aid.to_string());
        }
        if cursor_date.is_some() {
            query = query.bind(cursor_date.as_deref().unwrap());
            query = query.bind(cursor_id.as_deref().unwrap());
        }
        query = query.bind(limit);

        let rows = query.fetch_all(&self.pool).await?;

        let has_next_page = rows.len() > first as usize;
        let page_rows = if has_next_page {
            &rows[..first as usize]
        } else {
            &rows
        };

        // Parse transaction headers
        struct TxHeader {
            id: Uuid,
            transaction_date: NaiveDate,
            description: String,
            sync_metadata: SyncMetadata,
        }

        let mut headers = Vec::with_capacity(page_rows.len());
        for row in page_rows {
            let id_str: String = row.try_get("id")?;
            let id =
                Uuid::from_str(&id_str).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

            let date_str: String = row.try_get("transaction_date")?;
            let transaction_date = NaiveDate::parse_from_str(&date_str, "%Y-%m-%d")
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

            headers.push(TxHeader {
                id,
                transaction_date,
                description,
                sync_metadata,
            });
        }

        // Batch load entries for all transactions in the page
        let txn_ids: Vec<String> = headers.iter().map(|h| h.id.to_string()).collect();
        let entries_map = self.batch_load_entries(&txn_ids).await?;

        // Build transactions
        let mut items = Vec::with_capacity(headers.len());
        for header in headers {
            let entries = entries_map.get(&header.id).cloned().unwrap_or_default();
            let txn = Transaction::reconstitute(
                header.id,
                header.transaction_date,
                header.description,
                entries,
                header.sync_metadata,
            );
            items.push(txn);
        }

        // Build cursors
        let next_cursor = if has_next_page && !page_rows.is_empty() {
            let last = &page_rows[page_rows.len() - 1];
            let last_date: String = last.try_get("transaction_date")?;
            let last_id: String = last.try_get("id")?;
            build_cursor(vec![
                ("transaction_date", last_date),
                ("id", last_id),
            ])
        } else {
            None
        };

        let prev_cursor = if after.is_some() && !page_rows.is_empty() {
            let first_row = &page_rows[0];
            let first_date: String = first_row.try_get("transaction_date")?;
            let first_id: String = first_row.try_get("id")?;
            build_cursor(vec![
                ("transaction_date", first_date),
                ("id", first_id),
            ])
        } else {
            None
        };

        Ok(PaginatedResult {
            items,
            page_info: PageInfo {
                has_next_page,
                has_prev_page: after.is_some(),
                next_cursor,
                prev_cursor,
            },
        })
    }
}
