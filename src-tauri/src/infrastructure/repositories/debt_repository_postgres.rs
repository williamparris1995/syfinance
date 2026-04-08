use crate::domain::{
    aggregates::{Debt, DebtType, PaymentSchedule},
    repositories::DebtRepository,
    value_objects::{Money, SyncMetadata},
};
use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use sqlx::{postgres::PgPool, Row};
use uuid::Uuid;

#[derive(Clone)]
pub struct PostgresDebtRepository {
    pool: PgPool,
}

impl PostgresDebtRepository {
    pub fn new(pool: PgPool) -> Self {
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

impl DebtRepository for PostgresDebtRepository {
    async fn create(&self, debt: &Debt) -> sqlx::Result<()> {
        let mut tx = self.pool.begin().await?;

        sqlx::query(
            r#"
            INSERT INTO debts (
                id, debt_type, counterparty, principal, currency_code,
                interest_rate, start_date, due_date, updated_at, device_id
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            ON CONFLICT (id) DO UPDATE SET
                debt_type = EXCLUDED.debt_type,
                counterparty = EXCLUDED.counterparty,
                principal = EXCLUDED.principal,
                currency_code = EXCLUDED.currency_code,
                interest_rate = EXCLUDED.interest_rate,
                start_date = EXCLUDED.start_date,
                due_date = EXCLUDED.due_date,
                updated_at = EXCLUDED.updated_at,
                device_id = EXCLUDED.device_id
            "#,
        )
        .bind(debt.id)
        .bind(Self::debt_type_to_str(&debt.debt_type))
        .bind(&debt.counterparty)
        .bind(debt.principal.amount)
        .bind(&debt.principal.currency_code)
        .bind(debt.interest_rate)
        .bind(debt.start_date)
        .bind(debt.due_date)
        .bind(debt.sync_metadata.updated_at)
        .bind(debt.sync_metadata.device_id)
        .execute(&mut *tx)
        .await?;

        for payment in &debt.payment_schedule {
            sqlx::query(
                r#"
                INSERT INTO debt_payments (
                    id, debt_id, payment_date, principal_amount, interest_amount,
                    total_amount, paid
                ) VALUES ($1, $2, $3, $4, $5, $6, $7)
                ON CONFLICT (id) DO UPDATE SET
                    payment_date = EXCLUDED.payment_date,
                    principal_amount = EXCLUDED.principal_amount,
                    interest_amount = EXCLUDED.interest_amount,
                    total_amount = EXCLUDED.total_amount,
                    paid = EXCLUDED.paid
                "#,
            )
            .bind(Uuid::new_v4())
            .bind(debt.id)
            .bind(payment.payment_date)
            .bind(payment.principal_amount.amount)
            .bind(payment.interest_amount.amount)
            .bind(payment.total_amount.amount)
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
            SELECT id, debt_type, counterparty, principal, currency_code,
                   interest_rate, start_date, due_date, updated_at, deleted_at, device_id, synced_at
            FROM debts
            WHERE id = $1 AND deleted_at IS NULL
            "#,
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await?;

        let Some(row) = row else {
            return Ok(None);
        };

        let debt_id: Uuid = row.try_get("id")?;
        let debt_type_str: String = row.try_get("debt_type")?;
        let debt_type = Self::parse_debt_type(&debt_type_str)?;
        let counterparty: String = row.try_get("counterparty")?;
        let principal_val: Decimal = row.try_get("principal")?;
        let currency_code: String = row.try_get("currency_code")?;
        let interest_rate: Decimal = row.try_get("interest_rate")?;
        let start_date: NaiveDate = row.try_get("start_date")?;
        let due_date: NaiveDate = row.try_get("due_date")?;

        let principal = Money::new(principal_val, &currency_code)
            .map_err(|e| sqlx::Error::Decode(format!("invalid money: {}", e).into()))?;

        let payment_rows = sqlx::query(
            r#"
            SELECT payment_date, principal_amount, interest_amount, total_amount, paid
            FROM debt_payments
            WHERE debt_id = $1
            ORDER BY payment_date ASC
            "#,
        )
        .bind(debt_id)
        .fetch_all(&self.pool)
        .await?;

        let mut payment_schedule = Vec::new();
        for payment_row in payment_rows {
            let payment_date: NaiveDate = payment_row.try_get("payment_date")?;
            let principal_amount: Decimal = payment_row.try_get("principal_amount")?;
            let interest_amount: Decimal = payment_row.try_get("interest_amount")?;
            let total_amount: Decimal = payment_row.try_get("total_amount")?;
            let paid: bool = payment_row.try_get("paid")?;

            payment_schedule.push(PaymentSchedule {
                payment_date,
                principal_amount: Money::new(principal_amount, &currency_code)
                    .map_err(|e| sqlx::Error::Decode(format!("invalid money: {}", e).into()))?,
                interest_amount: Money::new(interest_amount, &currency_code)
                    .map_err(|e| sqlx::Error::Decode(format!("invalid money: {}", e).into()))?,
                total_amount: Money::new(total_amount, &currency_code)
                    .map_err(|e| sqlx::Error::Decode(format!("invalid money: {}", e).into()))?,
                paid,
            });
        }

        let updated_at: DateTime<Utc> = row.try_get("updated_at")?;
        let device_id: Uuid = row.try_get("device_id")?;
        let synced_at: Option<DateTime<Utc>> = row.try_get("synced_at")?;
        let deleted_at: Option<DateTime<Utc>> = row.try_get("deleted_at")?;

        let sync_metadata = SyncMetadata {
            updated_at,
            deleted_at,
            device_id,
            synced_at,
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
            let id: Uuid = row.try_get("id")?;
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
            WHERE debt_type = $1 AND deleted_at IS NULL
            ORDER BY start_date DESC
            "#,
        )
        .bind(Self::debt_type_to_str(&debt_type))
        .fetch_all(&self.pool)
        .await?;

        let mut debts = Vec::new();
        for row in rows {
            let id: Uuid = row.try_get("id")?;
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
            WHERE due_date = $1 AND deleted_at IS NULL
            ORDER BY start_date DESC
            "#,
        )
        .bind(due_date)
        .fetch_all(&self.pool)
        .await?;

        let mut debts = Vec::new();
        for row in rows {
            let id: Uuid = row.try_get("id")?;
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
            SET counterparty = $1, principal = $2, currency_code = $3,
                interest_rate = $4, start_date = $5, due_date = $6,
                updated_at = $7, synced_at = $8
            WHERE id = $9 AND deleted_at IS NULL
            RETURNING id
            "#,
        )
        .bind(&debt.counterparty)
        .bind(debt.principal.amount)
        .bind(&debt.principal.currency_code)
        .bind(debt.interest_rate)
        .bind(debt.start_date)
        .bind(debt.due_date)
        .bind(debt.sync_metadata.updated_at)
        .bind(debt.sync_metadata.synced_at)
        .bind(debt.id)
        .fetch_optional(&mut *tx)
        .await?;

        if result.is_none() {
            return Ok(false);
        }

        sqlx::query("DELETE FROM debt_payments WHERE debt_id = $1")
            .bind(debt.id)
            .execute(&mut *tx)
            .await?;

        for payment in &debt.payment_schedule {
            sqlx::query(
                r#"
                INSERT INTO debt_payments (
                    id, debt_id, payment_date, principal_amount, interest_amount,
                    total_amount, paid
                ) VALUES ($1, $2, $3, $4, $5, $6, $7)
                "#,
            )
            .bind(Uuid::new_v4())
            .bind(debt.id)
            .bind(payment.payment_date)
            .bind(payment.principal_amount.amount)
            .bind(payment.interest_amount.amount)
            .bind(payment.total_amount.amount)
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
            SET deleted_at = NOW(), synced_at = NULL
            WHERE id = $1 AND deleted_at IS NULL
            RETURNING id
            "#,
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await?;

        Ok(result.is_some())
    }
}
