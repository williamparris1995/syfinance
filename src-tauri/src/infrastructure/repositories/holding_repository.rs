use crate::domain::aggregates::holding::{Holding, HoldingTransaction, HoldingTransactionType};
use crate::domain::repositories::HoldingRepository;
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

    const TRADE_TYPE_BUY: &str = "BUY";
    const TRADE_TYPE_SELL: &str = "SELL";
    const TRADE_TYPE_DIVIDEND: &str = "DIVIDEND";
    const TRADE_TYPE_SPLIT: &str = "SPLIT";

    fn parse_trade_type(s: &str) -> Result<HoldingTransactionType, sqlx::Error> {
        match s {
            TRADE_TYPE_BUY => Ok(HoldingTransactionType::Buy),
            TRADE_TYPE_SELL => Ok(HoldingTransactionType::Sell),
            TRADE_TYPE_DIVIDEND => Ok(HoldingTransactionType::Dividend),
            TRADE_TYPE_SPLIT => Ok(HoldingTransactionType::Split),
            _ => Err(sqlx::Error::Decode(
                format!("invalid trade type: {}", s).into(),
            )),
        }
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
        rows.iter().map(|r| Self::row_to_holding(r)).collect()
    }

    async fn find_all(&self) -> sqlx::Result<Vec<Holding>> {
        let rows = sqlx::query(
            "SELECT id, account_id, security_id, CAST(quantity AS TEXT) as quantity,
                    CAST(avg_cost AS TEXT) as avg_cost
             FROM holdings WHERE deleted_at IS NULL",
        )
        .fetch_all(&self.pool)
        .await?;
        rows.iter().map(|r| Self::row_to_holding(r)).collect()
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
        rows.iter().map(|r| Self::row_to_ht(r)).collect()
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
        rows.iter().map(|r| Self::row_to_ht(r)).collect()
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
        rows.iter().map(|r| Self::row_to_ht(r)).collect()
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
}
