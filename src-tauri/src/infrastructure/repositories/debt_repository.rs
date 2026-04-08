use crate::domain::{
    aggregates::{Debt, DebtType, PaymentSchedule},
    repositories::DebtRepository,
    value_objects::{Money, SyncMetadata},
};
use chrono::{DateTime, NaiveDate, Utc};
use sqlx::{Row, SqlitePool};
use std::str::FromStr;
use uuid::Uuid;

pub struct SqliteDebtRepository {
    pool: SqlitePool,
}

impl SqliteDebtRepository {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn parse_debt_type(s: &str) -> Result<DebtType, sqlx::Error> {
        match s {
            "borrowed_out" => Ok(DebtType::BorrowedOut),
            "borrowed_in" => Ok(DebtType::BorrowedIn),
            "credit_card" => Ok(DebtType::CreditCard),
            "loan" => Ok(DebtType::Loan),
            _ => Err(sqlx::Error::Decode(
                format!("invalid debt type: {}", s).into(),
            )),
        }
    }

    fn debt_type_to_str(dt: &DebtType) -> &'static str {
        match dt {
            DebtType::BorrowedOut => "borrowed_out",
            DebtType::BorrowedIn => "borrowed_in",
            DebtType::CreditCard => "credit_card",
            DebtType::Loan => "loan",
        }
    }
}

impl DebtRepository for SqliteDebtRepository {
    async fn create(&self, debt: &Debt) -> sqlx::Result<()> {
        let mut tx = self.pool.begin().await?;

        sqlx::query(
            r#"
            INSERT INTO debts (
                id, debt_type, counterparty, principal, currency_code,
                interest_rate, start_date, due_date, updated_at, device_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            "#,
        )
        .bind(debt.id.to_string())
        .bind(Self::debt_type_to_str(&debt.debt_type))
        .bind(&debt.counterparty)
        .bind(debt.principal.amount.to_string())
        .bind(&debt.principal.currency_code)
        .bind(debt.interest_rate.to_string())
        .bind(debt.start_date.to_string())
        .bind(debt.due_date.to_string())
        .bind(debt.sync_metadata.updated_at.to_rfc3339())
        .bind(debt.sync_metadata.device_id.to_string())
        .execute(&mut *tx)
        .await?;

        for payment in &debt.payment_schedule {
            sqlx::query(
                r#"
                INSERT INTO debt_payments (
                    id, debt_id, payment_date, principal_amount, interest_amount,
                    total_amount, paid
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                "#,
            )
            .bind(Uuid::new_v4().to_string())
            .bind(debt.id.to_string())
            .bind(payment.payment_date.to_string())
            .bind(payment.principal_amount.amount.to_string())
            .bind(payment.interest_amount.amount.to_string())
            .bind(payment.total_amount.amount.to_string())
            .bind(payment.paid)
            .execute(&mut *tx)
            .await?;
        }

        tx.commit().await?;
        Ok(())
    }

    async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<Debt>> {
        let row = sqlx::query(
            r#"
            SELECT id, debt_type, counterparty, CAST(principal AS TEXT) as principal, currency_code,
                   CAST(interest_rate AS TEXT) as interest_rate, start_date, due_date, updated_at, deleted_at, device_id, synced_at
            FROM debts
            WHERE id = ? AND deleted_at IS NULL
            "#,
        )
        .bind(id.to_string())
        .fetch_optional(&self.pool)
        .await?;

        let Some(row) = row else {
            return Ok(None);
        };

        let debt_id: String = row.get("id");
        let debt_id = Uuid::parse_str(&debt_id).map_err(|e| {
            sqlx::Error::Decode(format!("invalid UUID: {}", e).into())
        })?;

        let debt_type_str: String = row.get("debt_type");
        let debt_type = Self::parse_debt_type(&debt_type_str)?;

        let counterparty: String = row.get("counterparty");
        let principal_val: String = row.get("principal");
        let currency_code: String = row.get("currency_code");
        let interest_rate_val: String = row.get("interest_rate");
        let start_date: String = row.get("start_date");
        let due_date: String = row.get("due_date");

        let principal = Money::new(
            rust_decimal::Decimal::from_str(&principal_val).map_err(|e| {
                sqlx::Error::Decode(format!("invalid decimal: {}", e).into())
            })?,
            &currency_code,
        )
        .map_err(|e| sqlx::Error::Decode(format!("invalid money: {}", e).into()))?;

        let interest_rate = rust_decimal::Decimal::from_str(&interest_rate_val).map_err(|e| {
            sqlx::Error::Decode(format!("invalid decimal: {}", e).into())
        })?;

        let start_date = NaiveDate::parse_from_str(&start_date, "%Y-%m-%d")
            .map_err(|e| sqlx::Error::Decode(format!("invalid date: {}", e).into()))?;

        let due_date = NaiveDate::parse_from_str(&due_date, "%Y-%m-%d")
            .map_err(|e| sqlx::Error::Decode(format!("invalid date: {}", e).into()))?;

        let payment_rows = sqlx::query(
            r#"
            SELECT payment_date, CAST(principal_amount AS TEXT) as principal_amount, 
                   CAST(interest_amount AS TEXT) as interest_amount, CAST(total_amount AS TEXT) as total_amount, paid
            FROM debt_payments
            WHERE debt_id = ?
            ORDER BY payment_date ASC
            "#,
        )
        .bind(debt_id.to_string())
        .fetch_all(&self.pool)
        .await?;

        let mut payment_schedule = Vec::new();
        for payment_row in payment_rows {
            let payment_date: String = payment_row.get("payment_date");
            let principal_amount: String = payment_row.get("principal_amount");
            let interest_amount: String = payment_row.get("interest_amount");
            let total_amount: String = payment_row.get("total_amount");
            let paid: bool = payment_row.get("paid");

            let payment_date = NaiveDate::parse_from_str(&payment_date, "%Y-%m-%d")
                .map_err(|e| sqlx::Error::Decode(format!("invalid date: {}", e).into()))?;

            payment_schedule.push(PaymentSchedule {
                payment_date,
                principal_amount: Money::new(
                    rust_decimal::Decimal::from_str(&principal_amount).map_err(|e| {
                        sqlx::Error::Decode(format!("invalid decimal: {}", e).into())
                    })?,
                    &currency_code,
                )
                .map_err(|e| sqlx::Error::Decode(format!("invalid money: {}", e).into()))?,
                interest_amount: Money::new(
                    rust_decimal::Decimal::from_str(&interest_amount).map_err(|e| {
                        sqlx::Error::Decode(format!("invalid decimal: {}", e).into())
                    })?,
                    &currency_code,
                )
                .map_err(|e| sqlx::Error::Decode(format!("invalid money: {}", e).into()))?,
                total_amount: Money::new(
                    rust_decimal::Decimal::from_str(&total_amount).map_err(|e| {
                        sqlx::Error::Decode(format!("invalid decimal: {}", e).into())
                    })?,
                    &currency_code,
                )
                .map_err(|e| sqlx::Error::Decode(format!("invalid money: {}", e).into()))?,
                paid,
            });
        }

        let updated_at: String = row.get("updated_at");
        let device_id: String = row.get("device_id");
        let synced_at: Option<String> = row.get("synced_at");
        let deleted_at: Option<String> = row.get("deleted_at");

        let sync_metadata = SyncMetadata {
            updated_at: chrono::DateTime::parse_from_rfc3339(&updated_at)
                .or_else(|_| {
                    chrono::NaiveDateTime::parse_from_str(&updated_at, "%Y-%m-%d %H:%M:%S")
                        .map(|dt| dt.and_utc().into())
                })
                .map_err(|e| sqlx::Error::Decode(format!("invalid datetime: {}", e).into()))?
                .with_timezone(&Utc),
            deleted_at: deleted_at
                .map(|s| {
                    chrono::DateTime::parse_from_rfc3339(&s)
                        .or_else(|_| {
                            chrono::NaiveDateTime::parse_from_str(&s, "%Y-%m-%d %H:%M:%S")
                                .map(|dt| dt.and_utc().into())
                        })
                        .map(|dt| dt.with_timezone(&Utc))
                })
                .transpose()
                .map_err(|e: chrono::ParseError| {
                    sqlx::Error::Decode(format!("invalid datetime: {}", e).into())
                })?,
            device_id: Uuid::parse_str(&device_id)
                .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?,
            synced_at: synced_at
                .map(|s| {
                    chrono::DateTime::parse_from_rfc3339(&s)
                        .or_else(|_| {
                            chrono::NaiveDateTime::parse_from_str(&s, "%Y-%m-%d %H:%M:%S")
                                .map(|dt| dt.and_utc().into())
                        })
                        .map(|dt| dt.with_timezone(&Utc))
                })
                .transpose()
                .map_err(|e: chrono::ParseError| {
                    sqlx::Error::Decode(format!("invalid datetime: {}", e).into())
                })?,
        };

        Ok(Some(Debt {
            id: debt_id,
            debt_type,
            counterparty,
            principal,
            interest_rate,
            start_date,
            due_date,
            payment_schedule,
            sync_metadata,
        }))
    }

    async fn find_all(&self) -> sqlx::Result<Vec<Debt>> {
        let rows = sqlx::query(
            r#"
            SELECT id
            FROM debts
            WHERE deleted_at IS NULL
            ORDER BY start_date DESC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        let mut debts = Vec::new();
        for row in rows {
            let id: String = row.get("id");
            let id = Uuid::parse_str(&id)
                .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?;

            if let Some(debt) = self.find_by_id(id).await? {
                debts.push(debt);
            }
        }

        Ok(debts)
    }

    async fn find_by_type(&self, debt_type: DebtType) -> sqlx::Result<Vec<Debt>> {
        let rows = sqlx::query(
            r#"
            SELECT id
            FROM debts
            WHERE debt_type = ? AND deleted_at IS NULL
            ORDER BY start_date DESC
            "#,
        )
        .bind(Self::debt_type_to_str(&debt_type))
        .fetch_all(&self.pool)
        .await?;

        let mut debts = Vec::new();
        for row in rows {
            let id: String = row.get("id");
            let id = Uuid::parse_str(&id)
                .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?;

            if let Some(debt) = self.find_by_id(id).await? {
                debts.push(debt);
            }
        }

        Ok(debts)
    }

    async fn find_due_by_date(&self, due_date: NaiveDate) -> sqlx::Result<Vec<Debt>> {
        let rows = sqlx::query(
            r#"
            SELECT id
            FROM debts
            WHERE due_date = ? AND deleted_at IS NULL
            ORDER BY start_date DESC
            "#,
        )
        .bind(due_date.to_string())
        .fetch_all(&self.pool)
        .await?;

        let mut debts = Vec::new();
        for row in rows {
            let id: String = row.get("id");
            let id = Uuid::parse_str(&id)
                .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?;

            if let Some(debt) = self.find_by_id(id).await? {
                debts.push(debt);
            }
        }

        Ok(debts)
    }

    async fn update(&self, debt: &Debt) -> sqlx::Result<bool> {
        let mut tx = self.pool.begin().await?;

        let result = sqlx::query(
            r#"
            UPDATE debts
            SET counterparty = ?, principal = ?, currency_code = ?,
                interest_rate = ?, start_date = ?, due_date = ?,
                updated_at = ?, synced_at = ?
            WHERE id = ? AND deleted_at IS NULL
            "#,
        )
        .bind(&debt.counterparty)
        .bind(debt.principal.amount.to_string())
        .bind(&debt.principal.currency_code)
        .bind(debt.interest_rate.to_string())
        .bind(debt.start_date.to_string())
        .bind(debt.due_date.to_string())
        .bind(debt.sync_metadata.updated_at.to_rfc3339())
        .bind(debt.sync_metadata.synced_at.map(|dt| dt.to_rfc3339()))
        .bind(debt.id.to_string())
        .execute(&mut *tx)
        .await?;

        if result.rows_affected() == 0 {
            return Ok(false);
        }

        sqlx::query("DELETE FROM debt_payments WHERE debt_id = ?")
            .bind(debt.id.to_string())
            .execute(&mut *tx)
            .await?;

        for payment in &debt.payment_schedule {
            sqlx::query(
                r#"
                INSERT INTO debt_payments (
                    id, debt_id, payment_date, principal_amount, interest_amount,
                    total_amount, paid
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                "#,
            )
            .bind(Uuid::new_v4().to_string())
            .bind(debt.id.to_string())
            .bind(payment.payment_date.to_string())
            .bind(payment.principal_amount.amount.to_string())
            .bind(payment.interest_amount.amount.to_string())
            .bind(payment.total_amount.amount.to_string())
            .bind(payment.paid)
            .execute(&mut *tx)
            .await?;
        }

        tx.commit().await?;
        Ok(true)
    }

    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool> {
        let result = sqlx::query(
            r#"
            UPDATE debts
            SET deleted_at = ?, synced_at = NULL
            WHERE id = ? AND deleted_at IS NULL
            "#,
        )
        .bind(Utc::now().to_rfc3339())
        .bind(id.to_string())
        .execute(&self.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    async fn get_changes_since(&self, timestamp: DateTime<Utc>) -> sqlx::Result<Vec<Debt>> {
        let rows = sqlx::query(
            r#"
            SELECT id
            FROM debts
            WHERE updated_at > ? AND (synced_at IS NULL OR synced_at < updated_at)
            ORDER BY updated_at ASC
            "#,
        )
        .bind(timestamp.to_rfc3339())
        .fetch_all(&self.pool)
        .await?;

        let mut debts = Vec::new();
        for row in rows {
            let id: String = row.get("id");
            let id = Uuid::parse_str(&id)
                .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?;

            if let Some(debt) = self.find_by_id(id).await? {
                debts.push(debt);
            }
        }

        Ok(debts)
    }

    async fn mark_as_synced(&self, id: Uuid) -> sqlx::Result<bool> {
        let result = sqlx::query(
            r#"
            UPDATE debts
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
