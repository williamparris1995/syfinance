use crate::domain::{
    aggregates::debt_details::{AmortizationMethod, DebtDetails, PaymentScheduleEntry},
    repositories::DebtRepository,
};
use chrono::{NaiveDate, Utc};
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

    fn parse_amortization_method(s: &str) -> Result<AmortizationMethod, sqlx::Error> {
        match s {
            "EqualPrincipalInterest" => Ok(AmortizationMethod::EqualPrincipalInterest),
            "EqualPrincipal" => Ok(AmortizationMethod::EqualPrincipal),
            "LumpSum" => Ok(AmortizationMethod::LumpSum),
            _ => Err(sqlx::Error::Decode(
                format!("invalid amortization method: {}", s).into(),
            )),
        }
    }

    fn amortization_method_to_str(m: &AmortizationMethod) -> &'static str {
        match m {
            AmortizationMethod::EqualPrincipalInterest => "EqualPrincipalInterest",
            AmortizationMethod::EqualPrincipal => "EqualPrincipal",
            AmortizationMethod::LumpSum => "LumpSum",
        }
    }
}

impl DebtRepository for PostgresDebtRepository {
    async fn create_debt_details(&self, debt: &DebtDetails) -> sqlx::Result<()> {
        let mut tx = self.pool.begin().await?;

        // Remove any soft-deleted row with the same account_id to free UNIQUE constraint
        sqlx::query("DELETE FROM debt_payment_schedule WHERE debt_id IN (SELECT id FROM debt_details WHERE account_id = $1 AND deleted_at IS NOT NULL)")
            .bind(debt.account_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM debt_details WHERE account_id = $1 AND deleted_at IS NOT NULL")
            .bind(debt.account_id)
            .execute(&mut *tx)
            .await?;

        sqlx::query(
            r#"
            INSERT INTO debt_details (
                id, account_id, counterparty, interest_rate, amortization_method,
                start_date, due_date, total_principal, updated_at
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            ON CONFLICT (id) DO NOTHING
            "#,
        )
        .bind(debt.id)
        .bind(debt.account_id)
        .bind(&debt.counterparty)
        .bind(debt.interest_rate)
        .bind(Self::amortization_method_to_str(&debt.amortization_method))
        .bind(debt.start_date)
        .bind(debt.due_date)
        .bind(debt.total_principal)
        .bind(Utc::now())
        .execute(&mut *tx)
        .await?;

        for entry in &debt.payment_schedule {
            sqlx::query(
                r#"
                INSERT INTO debt_payment_schedule (
                    id, debt_id, payment_date, principal_amount, interest_amount,
                    total_amount, paid, transaction_id, updated_at
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
                ON CONFLICT (id) DO NOTHING
                "#,
            )
            .bind(entry.id)
            .bind(debt.id)
            .bind(entry.payment_date)
            .bind(entry.principal_amount)
            .bind(entry.interest_amount)
            .bind(entry.total_amount)
            .bind(entry.paid)
            .bind(entry.transaction_id)
            .bind(Utc::now())
            .execute(&mut *tx)
            .await?;
        }

        tx.commit().await?;
        Ok(())
    }

    async fn find_debt_details_by_id(&self, id: Uuid) -> sqlx::Result<Option<DebtDetails>> {
        let row = sqlx::query(
            r#"
            SELECT id, account_id, counterparty, interest_rate,
                   amortization_method, start_date, due_date, total_principal
            FROM debt_details
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
        let schedule = self.find_schedule_by_debt_id(debt_id).await?;

        Ok(Some(row_to_debt_details(&row, schedule)?))
    }

    async fn find_debt_details_by_account_id(
        &self,
        account_id: Uuid,
    ) -> sqlx::Result<Option<DebtDetails>> {
        let row = sqlx::query(
            r#"
            SELECT id, account_id, counterparty, interest_rate,
                   amortization_method, start_date, due_date, total_principal
            FROM debt_details
            WHERE account_id = $1 AND deleted_at IS NULL
            "#,
        )
        .bind(account_id)
        .fetch_optional(&self.pool)
        .await?;

        let Some(row) = row else {
            return Ok(None);
        };

        let debt_id: Uuid = row.try_get("id")?;
        let schedule = self.find_schedule_by_debt_id(debt_id).await?;

        Ok(Some(row_to_debt_details(&row, schedule)?))
    }

    async fn find_all_debt_details(&self) -> sqlx::Result<Vec<DebtDetails>> {
        let rows = sqlx::query(
            r#"
            SELECT id, account_id, counterparty, interest_rate,
                   amortization_method, start_date, due_date, total_principal
            FROM debt_details
            WHERE deleted_at IS NULL
            ORDER BY start_date DESC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        let mut debts = Vec::new();
        for row in rows {
            let debt_id: Uuid = row.try_get("id")?;
            let schedule = self.find_schedule_by_debt_id(debt_id).await?;
            debts.push(row_to_debt_details(&row, schedule)?);
        }
        Ok(debts)
    }

    async fn update_debt_details(&self, debt: &DebtDetails) -> sqlx::Result<bool> {
        let result = sqlx::query(
            r#"
            UPDATE debt_details
            SET counterparty = $1, interest_rate = $2, amortization_method = $3,
                start_date = $4, due_date = $5, total_principal = $6, updated_at = $7
            WHERE id = $8 AND deleted_at IS NULL
            "#,
        )
        .bind(&debt.counterparty)
        .bind(debt.interest_rate)
        .bind(Self::amortization_method_to_str(&debt.amortization_method))
        .bind(debt.start_date)
        .bind(debt.due_date)
        .bind(debt.total_principal)
        .bind(Utc::now())
        .bind(debt.id)
        .execute(&self.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    async fn soft_delete_debt_details(&self, id: Uuid) -> sqlx::Result<bool> {
        let result = sqlx::query(
            r#"
            UPDATE debt_details
            SET deleted_at = NOW()
            WHERE id = $1 AND deleted_at IS NULL
            "#,
        )
        .bind(id)
        .execute(&self.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    async fn create_schedule_entries(&self, entries: &[PaymentScheduleEntry]) -> sqlx::Result<()> {
        let mut tx = self.pool.begin().await?;

        for entry in entries {
            sqlx::query(
                r#"
                INSERT INTO debt_payment_schedule (
                    id, debt_id, payment_date, principal_amount, interest_amount,
                    total_amount, paid, transaction_id, updated_at
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
                ON CONFLICT (id) DO NOTHING
                "#,
            )
            .bind(entry.id)
            .bind(entry.debt_id)
            .bind(entry.payment_date)
            .bind(entry.principal_amount)
            .bind(entry.interest_amount)
            .bind(entry.total_amount)
            .bind(entry.paid)
            .bind(entry.transaction_id)
            .bind(Utc::now())
            .execute(&mut *tx)
            .await?;
        }

        tx.commit().await?;
        Ok(())
    }

    async fn find_schedule_by_debt_id(
        &self,
        debt_id: Uuid,
    ) -> sqlx::Result<Vec<PaymentScheduleEntry>> {
        let rows = sqlx::query(
            r#"
            SELECT id, debt_id, payment_date, principal_amount,
                   interest_amount, total_amount, paid, transaction_id
            FROM debt_payment_schedule
            WHERE debt_id = $1 AND deleted_at IS NULL
            ORDER BY payment_date ASC
            "#,
        )
        .bind(debt_id)
        .fetch_all(&self.pool)
        .await?;

        let mut entries = Vec::new();
        for row in rows {
            entries.push(row_to_schedule_entry(&row)?);
        }
        Ok(entries)
    }

    async fn update_schedule_entry(&self, entry: &PaymentScheduleEntry) -> sqlx::Result<bool> {
        let result = sqlx::query(
            r#"
            UPDATE debt_payment_schedule
            SET paid = $1, transaction_id = $2, updated_at = $3
            WHERE id = $4 AND deleted_at IS NULL
            "#,
        )
        .bind(entry.paid)
        .bind(entry.transaction_id)
        .bind(Utc::now())
        .bind(entry.id)
        .execute(&self.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    async fn get_upcoming_payments(
        &self,
        days_ahead: i32,
    ) -> sqlx::Result<Vec<(DebtDetails, PaymentScheduleEntry)>> {
        let today = Utc::now().date_naive();
        let end_date = today + chrono::Duration::days(days_ahead as i64);

        let rows = sqlx::query(
            r#"
            SELECT d.id as debt_id, d.account_id, d.counterparty,
                   d.interest_rate, d.amortization_method,
                   d.start_date, d.due_date, d.total_principal,
                   s.id as schedule_id, s.payment_date,
                   s.principal_amount, s.interest_amount, s.total_amount,
                   s.paid, s.transaction_id
            FROM debt_payment_schedule s
            JOIN debt_details d ON s.debt_id = d.id
            WHERE s.payment_date BETWEEN $1 AND $2
              AND s.paid = false
              AND s.deleted_at IS NULL
              AND d.deleted_at IS NULL
            ORDER BY s.payment_date ASC
            "#,
        )
        .bind(today)
        .bind(end_date)
        .fetch_all(&self.pool)
        .await?;

        let mut results = Vec::new();
        for row in rows {
            let schedule = vec![]; // placeholder — schedule already loaded from JOIN

            let debt_id: Uuid = row.try_get("debt_id")?;
            let account_id: Uuid = row.try_get("account_id")?;
            let counterparty: String = row.try_get("counterparty")?;
            let interest_rate: Decimal = row.try_get("interest_rate")?;
            let amortization_method_str: String = row.try_get("amortization_method")?;
            let amortization_method =
                Self::parse_amortization_method(&amortization_method_str)?;
            let start_date: NaiveDate = row.try_get("start_date")?;
            let due_date: NaiveDate = row.try_get("due_date")?;
            let total_principal: Decimal = row.try_get("total_principal")?;

            let debt = DebtDetails {
                id: debt_id,
                account_id,
                counterparty,
                interest_rate,
                amortization_method,
                start_date,
                due_date,
                total_principal,
                payment_schedule: schedule,
            };

            let entry = row_to_schedule_entry(&row)?;
            results.push((debt, entry));
        }
        Ok(results)
    }
}

fn row_to_debt_details(
    row: &sqlx::postgres::PgRow,
    schedule: Vec<PaymentScheduleEntry>,
) -> Result<DebtDetails, sqlx::Error> {
    let debt_id: Uuid = row.try_get("id")?;
    let account_id: Uuid = row.try_get("account_id")?;
    let counterparty: String = row.try_get("counterparty")?;
    let interest_rate: Decimal = row.try_get("interest_rate")?;
    let amortization_method_str: String = row.try_get("amortization_method")?;
    let amortization_method = PostgresDebtRepository::parse_amortization_method(
        &amortization_method_str,
    )?;
    let start_date: NaiveDate = row.try_get("start_date")?;
    let due_date: NaiveDate = row.try_get("due_date")?;
    let total_principal: Decimal = row.try_get("total_principal")?;

    Ok(DebtDetails {
        id: debt_id,
        account_id,
        counterparty,
        interest_rate,
        amortization_method,
        start_date,
        due_date,
        total_principal,
        payment_schedule: schedule,
    })
}

fn row_to_schedule_entry(
    row: &sqlx::postgres::PgRow,
) -> Result<PaymentScheduleEntry, sqlx::Error> {
    let entry_id: Uuid = row
        .try_get("schedule_id")
        .or_else(|_| row.try_get("id"))?;
    let debt_id: Uuid = row.try_get("debt_id")?;
    let payment_date: NaiveDate = row.try_get("payment_date")?;
    let principal_amount: Decimal = row.try_get("principal_amount")?;
    let interest_amount: Decimal = row.try_get("interest_amount")?;
    let total_amount: Decimal = row.try_get("total_amount")?;
    let paid: bool = row.try_get("paid")?;
    let transaction_id: Option<Uuid> = row.try_get("transaction_id")?;

    Ok(PaymentScheduleEntry {
        id: entry_id,
        debt_id,
        payment_date,
        principal_amount,
        interest_amount,
        total_amount,
        paid,
        transaction_id,
    })
}
