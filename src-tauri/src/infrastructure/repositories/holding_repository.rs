use crate::domain::aggregates::holding::{Holding, HoldingTransaction, HoldingTransactionType};
use crate::domain::repositories::HoldingRepository;
use crate::domain::value_objects::{build_cursor, PaginatedResult, PageInfo, SortCursor};
use chrono::{NaiveDate, Utc};
use rust_decimal::Decimal;
use sqlx::{Row, SqlitePool};
use std::str::FromStr;
use uuid::Uuid;

pub struct SqliteHoldingRepository {
    pool: SqlitePool,
}

impl SqliteHoldingRepository {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
    pub fn pool(&self) -> &SqlitePool {
        &self.pool
    }

    fn parse_trade_type(s: &str) -> Result<HoldingTransactionType, sqlx::Error> {
        serde_json::from_value(serde_json::Value::String(s.to_string()))
            .map_err(|_| sqlx::Error::Decode(format!("invalid trade type: {}", s).into()))
    }

    fn row_to_holding(row: &sqlx::sqlite::SqliteRow) -> Result<Holding, sqlx::Error> {
        let id_str: String = row.try_get("id")?;
        let acc_str: String = row.try_get("account_id")?;
        let sec_str: String = row.try_get("security_id")?;
        let qty_str: String = row.try_get("quantity")?;
        let cost_str: String = row.try_get("avg_cost")?;
        Ok(Holding::new(
            Uuid::parse_str(&id_str).map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            Uuid::parse_str(&acc_str).map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            Uuid::parse_str(&sec_str).map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            Decimal::from_str(&qty_str)
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            Decimal::from_str(&cost_str)
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
        ))
    }

    fn row_to_ht(row: &sqlx::sqlite::SqliteRow) -> Result<HoldingTransaction, sqlx::Error> {
        let id_str: String = row.try_get("id")?;
        let acc_str: String = row.try_get("account_id")?;
        let sec_str: String = row.try_get("security_id")?;
        let type_str: String = row.try_get("type")?;
        let qty_str: String = row.try_get("quantity")?;
        let price_str: String = row.try_get("price")?;
        let amt_str: String = row.try_get("amount")?;
        let fee_str: String = row.try_get("fee")?;
        let date_str: String = row.try_get("trade_date")?;
        let txn_id: Option<String> = row.try_get("transaction_id")?;
        let notes: Option<String> = row.try_get("notes")?;
        Ok(HoldingTransaction {
            id: Uuid::parse_str(&id_str)
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            account_id: Uuid::parse_str(&acc_str)
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            security_id: Uuid::parse_str(&sec_str)
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            trade_type: Self::parse_trade_type(&type_str)?,
            quantity: Decimal::from_str(&qty_str)
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            price: Decimal::from_str(&price_str)
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            amount: Decimal::from_str(&amt_str)
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            fee: Decimal::from_str(&fee_str)
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            trade_date: NaiveDate::parse_from_str(&date_str, "%Y-%m-%d")
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            transaction_id: txn_id
                .map(|s| Uuid::parse_str(&s))
                .transpose()
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            notes,
        })
    }
}

impl HoldingRepository for SqliteHoldingRepository {
    async fn find_by_account(&self, account_id: Uuid) -> sqlx::Result<Vec<Holding>> {
        let rows = sqlx::query(
            "SELECT id, account_id, security_id, CAST(quantity AS TEXT) as quantity,
                    CAST(avg_cost AS TEXT) as avg_cost
             FROM holdings WHERE account_id = ? AND deleted_at IS NULL",
        )
        .bind(account_id.to_string())
        .fetch_all(&self.pool)
        .await?;
        rows.iter().map(Self::row_to_holding).collect()
    }

    async fn find_all(&self) -> sqlx::Result<Vec<Holding>> {
        let rows = sqlx::query(
            "SELECT id, account_id, security_id, CAST(quantity AS TEXT) as quantity,
                    CAST(avg_cost AS TEXT) as avg_cost
             FROM holdings WHERE deleted_at IS NULL",
        )
        .fetch_all(&self.pool)
        .await?;
        rows.iter().map(Self::row_to_holding).collect()
    }

    async fn upsert(&self, h: &Holding) -> sqlx::Result<()> {
        sqlx::query(
            "INSERT INTO holdings (id, account_id, security_id, quantity, avg_cost, updated_at)
             VALUES (?, ?, ?, ?, ?, ?)
             ON CONFLICT(account_id, security_id) DO UPDATE SET
             quantity=excluded.quantity, avg_cost=excluded.avg_cost, updated_at=excluded.updated_at,
             deleted_at=NULL",
        )
        .bind(h.id.to_string())
        .bind(h.account_id.to_string())
        .bind(h.security_id.to_string())
        .bind(h.quantity.to_string())
        .bind(h.avg_cost.to_string())
        .bind(Utc::now().to_rfc3339())
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool> {
        let r = sqlx::query("UPDATE holdings SET deleted_at=? WHERE id=? AND deleted_at IS NULL")
            .bind(Utc::now().to_rfc3339())
            .bind(id.to_string())
            .execute(&self.pool)
            .await?;
        Ok(r.rows_affected() > 0)
    }

    async fn create_transaction(&self, txn: &HoldingTransaction) -> sqlx::Result<()> {
        sqlx::query(
            "INSERT INTO holding_transactions (id, account_id, security_id, type, quantity, price, amount, fee, trade_date, transaction_id, notes, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
        )
        .bind(txn.id.to_string()).bind(txn.account_id.to_string()).bind(txn.security_id.to_string())
        .bind(txn.trade_type.to_string()).bind(txn.quantity.to_string()).bind(txn.price.to_string())
        .bind(txn.amount.to_string()).bind(txn.fee.to_string()).bind(txn.trade_date.to_string())
        .bind(txn.transaction_id.map(|id| id.to_string())).bind(&txn.notes)
        .bind(Utc::now().to_rfc3339()).execute(&self.pool).await?;
        Ok(())
    }

    async fn find_transactions_by_account(
        &self,
        account_id: Uuid,
    ) -> sqlx::Result<Vec<HoldingTransaction>> {
        let rows = sqlx::query(
            "SELECT id, account_id, security_id, type, CAST(quantity AS TEXT) as quantity,
                    CAST(price AS TEXT) as price, CAST(amount AS TEXT) as amount,
                    CAST(fee AS TEXT) as fee, trade_date, transaction_id, notes
             FROM holding_transactions WHERE account_id = ? AND deleted_at IS NULL ORDER BY trade_date DESC"
        ).bind(account_id.to_string()).fetch_all(&self.pool).await?;
        rows.iter().map(Self::row_to_ht).collect()
    }

    async fn find_transactions_by_holding(
        &self,
        account_id: Uuid,
        security_id: Uuid,
    ) -> sqlx::Result<Vec<HoldingTransaction>> {
        let rows = sqlx::query(
            "SELECT id, account_id, security_id, type, CAST(quantity AS TEXT) as quantity,
                    CAST(price AS TEXT) as price, CAST(amount AS TEXT) as amount,
                    CAST(fee AS TEXT) as fee, trade_date, transaction_id, notes
             FROM holding_transactions WHERE account_id = ? AND security_id = ? AND deleted_at IS NULL ORDER BY trade_date DESC"
        ).bind(account_id.to_string()).bind(security_id.to_string()).fetch_all(&self.pool).await?;
        rows.iter().map(Self::row_to_ht).collect()
    }

    async fn find_transactions_by_holding_id(
        &self,
        holding_id: Uuid,
    ) -> sqlx::Result<Vec<HoldingTransaction>> {
        // First get the holding to find account_id and security_id
        let holding_row = sqlx::query(
            "SELECT account_id, security_id FROM holdings WHERE id = ? AND deleted_at IS NULL",
        )
        .bind(holding_id.to_string())
        .fetch_one(&self.pool)
        .await?;

        let account_id: String = holding_row.try_get("account_id")?;
        let security_id: String = holding_row.try_get("security_id")?;

        let rows = sqlx::query(
            "SELECT id, account_id, security_id, type, CAST(quantity AS TEXT) as quantity,
                    CAST(price AS TEXT) as price, CAST(amount AS TEXT) as amount,
                    CAST(fee AS TEXT) as fee, trade_date, transaction_id, notes
             FROM holding_transactions
             WHERE account_id = ? AND security_id = ? AND deleted_at IS NULL
             ORDER BY trade_date ASC",
        )
        .bind(&account_id)
        .bind(&security_id)
        .fetch_all(&self.pool)
        .await?;
        rows.iter().map(Self::row_to_ht).collect()
    }

    async fn find_holding_transaction_by_id(
        &self,
        id: Uuid,
    ) -> sqlx::Result<Option<HoldingTransaction>> {
        let row = sqlx::query(
            "SELECT id, account_id, security_id, type, CAST(quantity AS TEXT) as quantity,
                    CAST(price AS TEXT) as price, CAST(amount AS TEXT) as amount,
                    CAST(fee AS TEXT) as fee, trade_date, transaction_id, notes
             FROM holding_transactions WHERE id = ? AND deleted_at IS NULL",
        )
        .bind(id.to_string())
        .fetch_optional(&self.pool)
        .await?;
        row.map(|r| Self::row_to_ht(&r)).transpose()
    }

    async fn soft_delete_holding_transaction(&self, id: Uuid) -> sqlx::Result<bool> {
        let r = sqlx::query(
            "UPDATE holding_transactions SET deleted_at=? WHERE id=? AND deleted_at IS NULL",
        )
        .bind(chrono::Utc::now().to_rfc3339())
        .bind(id.to_string())
        .execute(&self.pool)
        .await?;
        Ok(r.rows_affected() > 0)
    }

    async fn soft_delete_transaction_cascade(&self, transaction_id: Uuid) -> sqlx::Result<bool> {
        // Soft-delete transaction entries
        sqlx::query("UPDATE transaction_entries SET deleted_at=? WHERE transaction_id=? AND deleted_at IS NULL")
            .bind(chrono::Utc::now().to_rfc3339()).bind(transaction_id.to_string())
            .execute(&self.pool).await?;
        // Soft-delete transaction
        let r =
            sqlx::query("UPDATE transactions SET deleted_at=? WHERE id=? AND deleted_at IS NULL")
                .bind(chrono::Utc::now().to_rfc3339())
                .bind(transaction_id.to_string())
                .execute(&self.pool)
                .await?;
        Ok(r.rows_affected() > 0)
    }

    async fn update_holding_transaction(
        &self,
        id: Uuid,
        quantity: Decimal,
        price: Decimal,
        fee: Decimal,
        trade_date: NaiveDate,
    ) -> sqlx::Result<()> {
        let amount = quantity * price;
        sqlx::query(
            "UPDATE holding_transactions SET quantity=?, price=?, amount=?, fee=?, trade_date=?, updated_at=? WHERE id=? AND deleted_at IS NULL"
        )
        .bind(quantity.to_string()).bind(price.to_string()).bind(amount.to_string())
        .bind(fee.to_string()).bind(trade_date.to_string())
        .bind(chrono::Utc::now().to_rfc3339()).bind(id.to_string())
        .execute(&self.pool).await?;
        Ok(())
    }

    async fn update_holding_quantities(
        &self,
        holding_id: Uuid,
        quantity: Decimal,
        avg_cost: Decimal,
    ) -> sqlx::Result<()> {
        sqlx::query(
            "UPDATE holdings SET quantity=?, avg_cost=?, updated_at=? WHERE id=? AND deleted_at IS NULL"
        )
        .bind(quantity.to_string()).bind(avg_cost.to_string())
        .bind(chrono::Utc::now().to_rfc3339()).bind(holding_id.to_string())
        .execute(&self.pool).await?;
        Ok(())
    }

    async fn soft_delete_holding_by_id(&self, holding_id: Uuid) -> sqlx::Result<bool> {
        let r = sqlx::query("UPDATE holdings SET deleted_at=? WHERE id=? AND deleted_at IS NULL")
            .bind(chrono::Utc::now().to_rfc3339())
            .bind(holding_id.to_string())
            .execute(&self.pool)
            .await?;
        Ok(r.rows_affected() > 0)
    }

    async fn find_holding_by_id(&self, id: Uuid) -> sqlx::Result<Option<Holding>> {
        let row = sqlx::query(
            "SELECT id, account_id, security_id, CAST(quantity AS TEXT) as quantity,
                    CAST(avg_cost AS TEXT) as avg_cost
             FROM holdings WHERE id = ? AND deleted_at IS NULL",
        )
        .bind(id.to_string())
        .fetch_optional(&self.pool)
        .await?;
        row.map(|r| Self::row_to_holding(&r)).transpose()
    }

    async fn find_transactions_paginated(
        &self,
        holding_id: Uuid,
        first: i64,
        after: Option<&str>,
        before: Option<&str>,
    ) -> sqlx::Result<PaginatedResult<HoldingTransaction>> {
        let limit = first.min(200) + 1;

        // Resolve holding_id -> (account_id, security_id)
        let holding_row = sqlx::query(
            "SELECT account_id, security_id FROM holdings WHERE id = ? AND deleted_at IS NULL",
        )
        .bind(holding_id.to_string())
        .fetch_optional(&self.pool)
        .await?;

        let holding_row = holding_row.ok_or_else(|| {
            sqlx::Error::RowNotFound
        })?;
        let account_id: String = holding_row.try_get("account_id")?;
        let security_id: String = holding_row.try_get("security_id")?;

        // Handle backward paging
        if let Some(before_cursor) = before {
            return self
                .fetch_ht_page_backward(
                    &account_id,
                    &security_id,
                    before_cursor,
                    first,
                    limit,
                )
                .await;
        }

        // Decode forward cursor
        let (cursor_date, cursor_id) = if let Some(after_str) = after {
            let cursor = SortCursor::decode(after_str)
                .map_err(|e| sqlx::Error::Decode(e.into()))?;
            let date = cursor
                .get("trade_date")
                .ok_or_else(|| {
                    sqlx::Error::Decode("Missing trade_date in cursor".into())
                })?
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
            "SELECT id, account_id, security_id, type, CAST(quantity AS TEXT) as quantity, \
             CAST(price AS TEXT) as price, CAST(amount AS TEXT) as amount, \
             CAST(fee AS TEXT) as fee, trade_date, transaction_id, notes \
             FROM holding_transactions WHERE account_id = ? AND security_id = ? AND deleted_at IS NULL",
        );

        if cursor_date.is_some() {
            sql.push_str(" AND (trade_date, id) < (?, ?)");
        }

        sql.push_str(" ORDER BY trade_date DESC, id DESC LIMIT ?");

        let mut query = sqlx::query(&sql);
        query = query.bind(&account_id).bind(&security_id);

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

        let items: Vec<HoldingTransaction> = page_rows
            .iter()
            .map(Self::row_to_ht)
            .collect::<Result<Vec<_>, _>>()?;

        // Build cursors
        let next_cursor = if has_next_page && !page_rows.is_empty() {
            let last = &page_rows[page_rows.len() - 1];
            let last_date: String = last.try_get("trade_date")?;
            let last_id: String = last.try_get("id")?;
            build_cursor(vec![("trade_date", last_date), ("id", last_id)])
        } else {
            None
        };

        let prev_cursor = if after.is_some() && !page_rows.is_empty() {
            let first_row = &page_rows[0];
            let first_date: String = first_row.try_get("trade_date")?;
            let first_id: String = first_row.try_get("id")?;
            build_cursor(vec![("trade_date", first_date), ("id", first_id)])
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

impl SqliteHoldingRepository {
    /// Backward paging for holding transactions.
    async fn fetch_ht_page_backward(
        &self,
        account_id: &str,
        security_id: &str,
        before_cursor: &str,
        first: i64,
        limit: i64,
    ) -> sqlx::Result<PaginatedResult<HoldingTransaction>> {
        let cursor = SortCursor::decode(before_cursor)
            .map_err(|e| sqlx::Error::Decode(e.into()))?;
        let cursor_date = cursor
            .get("trade_date")
            .ok_or_else(|| sqlx::Error::Decode("Missing trade_date in cursor".into()))?;
        let cursor_id = cursor
            .get("id")
            .ok_or_else(|| sqlx::Error::Decode("Missing id in cursor".into()))?;

        let sql = format!(
            "SELECT id, account_id, security_id, type, CAST(quantity AS TEXT) as quantity, \
             CAST(price AS TEXT) as price, CAST(amount AS TEXT) as amount, \
             CAST(fee AS TEXT) as fee, trade_date, transaction_id, notes \
             FROM holding_transactions \
             WHERE account_id = ? AND security_id = ? AND deleted_at IS NULL \
             AND (trade_date, id) > (?, ?) \
             ORDER BY trade_date ASC, id ASC LIMIT ?"
        );

        let rows = sqlx::query(&sql)
            .bind(account_id)
            .bind(security_id)
            .bind(cursor_date)
            .bind(cursor_id)
            .bind(limit)
            .fetch_all(&self.pool)
            .await?;

        let has_prev_page = rows.len() > first as usize;
        let page_rows = if has_prev_page {
            &rows[..first as usize]
        } else {
            &rows
        };

        // Reverse to maintain descending order
        let mut items: Vec<HoldingTransaction> = page_rows
            .iter()
            .map(Self::row_to_ht)
            .collect::<Result<Vec<_>, _>>()?;
        items.reverse();

        let next_cursor = if !items.is_empty() {
            // After reversal, "last" is the oldest
            // Use original page_rows in ascending order for cursor extraction
            let last = &page_rows[page_rows.len() - 1];
            let last_date: String = last.try_get("trade_date")?;
            let last_id: String = last.try_get("id")?;
            build_cursor(vec![("trade_date", last_date), ("id", last_id)])
        } else {
            None
        };

        let prev_cursor = if !items.is_empty() {
            let first_row = &page_rows[0];
            let first_date: String = first_row.try_get("trade_date")?;
            let first_id: String = first_row.try_get("id")?;
            build_cursor(vec![("trade_date", first_date), ("id", first_id)])
        } else {
            None
        };

        Ok(PaginatedResult {
            items,
            page_info: PageInfo {
                has_next_page: true,
                has_prev_page,
                next_cursor,
                prev_cursor,
            },
        })
    }
}
