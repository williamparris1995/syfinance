use crate::domain::{
    aggregates::debt_details::{AmortizationMethod, DebtDetails, PaymentScheduleEntry},
    repositories::DebtRepository,
};
use chrono::{NaiveDate, Utc};
use rust_decimal::Decimal;
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

impl DebtRepository for SqliteDebtRepository {
    async fn create_debt_details(&self, debt: &DebtDetails) -> sqlx::Result<()> {
        let mut tx = self.pool.begin().await?;

        sqlx::query(
            r#"
            INSERT INTO debt_details (
                id, account_id, counterparty, interest_rate, amortization_method,
                start_date, due_date, total_principal, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            "#,
        )
        .bind(debt.id.to_string())
        .bind(debt.account_id.to_string())
        .bind(&debt.counterparty)
        .bind(debt.interest_rate.to_string())
        .bind(Self::amortization_method_to_str(&debt.amortization_method))
        .bind(debt.start_date.to_string())
        .bind(debt.due_date.to_string())
        .bind(debt.total_principal.to_string())
        .bind(Utc::now().to_rfc3339())
        .execute(&mut *tx)
        .await?;

        for entry in &debt.payment_schedule {
            sqlx::query(
                r#"
                INSERT INTO debt_payment_schedule (
                    id, debt_id, payment_date, principal_amount, interest_amount,
                    total_amount, paid, transaction_id, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                "#,
            )
            .bind(entry.id.to_string())
            .bind(debt.id.to_string())
            .bind(entry.payment_date.to_string())
            .bind(entry.principal_amount.to_string())
            .bind(entry.interest_amount.to_string())
            .bind(entry.total_amount.to_string())
            .bind(entry.paid)
            .bind(entry.transaction_id.map(|id| id.to_string()))
            .bind(Utc::now().to_rfc3339())
            .execute(&mut *tx)
            .await?;
        }

        tx.commit().await?;
        Ok(())
    }

    async fn find_debt_details_by_id(&self, id: Uuid) -> sqlx::Result<Option<DebtDetails>> {
        let row = sqlx::query(
            r#"
            SELECT id, account_id, counterparty, CAST(interest_rate AS TEXT) as interest_rate,
                   amortization_method, start_date, due_date, CAST(total_principal AS TEXT) as total_principal
            FROM debt_details
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
        let _debt_id = Uuid::parse_str(&debt_id)
            .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?;

        let details = self.row_to_debt_details(&row).await?;
        Ok(Some(details))
    }

    async fn find_debt_details_by_account_id(
        &self,
        account_id: Uuid,
    ) -> sqlx::Result<Option<DebtDetails>> {
        let row = sqlx::query(
            r#"
            SELECT id, account_id, counterparty, CAST(interest_rate AS TEXT) as interest_rate,
                   amortization_method, start_date, due_date, CAST(total_principal AS TEXT) as total_principal
            FROM debt_details
            WHERE account_id = ? AND deleted_at IS NULL
            "#,
        )
        .bind(account_id.to_string())
        .fetch_optional(&self.pool)
        .await?;

        let Some(row) = row else {
            return Ok(None);
        };

        let details = self.row_to_debt_details(&row).await?;
        Ok(Some(details))
    }

    async fn find_all_debt_details(&self) -> sqlx::Result<Vec<DebtDetails>> {
        let rows = sqlx::query(
            r#"
            SELECT id, account_id, counterparty, CAST(interest_rate AS TEXT) as interest_rate,
                   amortization_method, start_date, due_date, CAST(total_principal AS TEXT) as total_principal
            FROM debt_details
            WHERE deleted_at IS NULL
            ORDER BY start_date DESC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        let mut debts = Vec::new();
        for row in rows {
            debts.push(self.row_to_debt_details(&row).await?);
        }
        Ok(debts)
    }

    async fn update_debt_details(&self, debt: &DebtDetails) -> sqlx::Result<bool> {
        let result = sqlx::query(
            r#"
            UPDATE debt_details
            SET counterparty = ?, interest_rate = ?, amortization_method = ?,
                start_date = ?, due_date = ?, total_principal = ?, updated_at = ?
            WHERE id = ? AND deleted_at IS NULL
            "#,
        )
        .bind(&debt.counterparty)
        .bind(debt.interest_rate.to_string())
        .bind(Self::amortization_method_to_str(&debt.amortization_method))
        .bind(debt.start_date.to_string())
        .bind(debt.due_date.to_string())
        .bind(debt.total_principal.to_string())
        .bind(Utc::now().to_rfc3339())
        .bind(debt.id.to_string())
        .execute(&self.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    async fn soft_delete_debt_details(&self, id: Uuid) -> sqlx::Result<bool> {
        let result = sqlx::query(
            r#"
            UPDATE debt_details
            SET deleted_at = ?
            WHERE id = ? AND deleted_at IS NULL
            "#,
        )
        .bind(Utc::now().to_rfc3339())
        .bind(id.to_string())
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
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                "#,
            )
            .bind(entry.id.to_string())
            .bind(entry.debt_id.to_string())
            .bind(entry.payment_date.to_string())
            .bind(entry.principal_amount.to_string())
            .bind(entry.interest_amount.to_string())
            .bind(entry.total_amount.to_string())
            .bind(entry.paid)
            .bind(entry.transaction_id.map(|id| id.to_string()))
            .bind(Utc::now().to_rfc3339())
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
            SELECT id, debt_id, payment_date,
                   CAST(principal_amount AS TEXT) as principal_amount,
                   CAST(interest_amount AS TEXT) as interest_amount,
                   CAST(total_amount AS TEXT) as total_amount,
                   paid, transaction_id
            FROM debt_payment_schedule
            WHERE debt_id = ? AND deleted_at IS NULL
            ORDER BY payment_date ASC
            "#,
        )
        .bind(debt_id.to_string())
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
            SET paid = ?, transaction_id = ?, updated_at = ?
            WHERE id = ? AND deleted_at IS NULL
            "#,
        )
        .bind(entry.paid)
        .bind(entry.transaction_id.map(|id| id.to_string()))
        .bind(Utc::now().to_rfc3339())
        .bind(entry.id.to_string())
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
                   CAST(d.interest_rate AS TEXT) as interest_rate, d.amortization_method,
                   d.start_date, d.due_date, CAST(d.total_principal AS TEXT) as total_principal,
                   s.id as schedule_id, s.payment_date,
                   CAST(s.principal_amount AS TEXT) as principal_amount,
                   CAST(s.interest_amount AS TEXT) as interest_amount,
                   CAST(s.total_amount AS TEXT) as total_amount,
                   s.paid, s.transaction_id
            FROM debt_payment_schedule s
            JOIN debt_details d ON s.debt_id = d.id
            WHERE s.payment_date BETWEEN ? AND ?
              AND s.paid = 0
              AND s.deleted_at IS NULL
              AND d.deleted_at IS NULL
            ORDER BY s.payment_date ASC
            "#,
        )
        .bind(today.to_string())
        .bind(end_date.to_string())
        .fetch_all(&self.pool)
        .await?;

        let mut results = Vec::new();
        for row in rows {
            let debt = self.row_to_debt_details(&row).await?;
            let entry = row_to_schedule_entry(&row)?;
            results.push((debt, entry));
        }
        Ok(results)
    }
}

impl SqliteDebtRepository {
    async fn row_to_debt_details(
        &self,
        row: &sqlx::sqlite::SqliteRow,
    ) -> Result<DebtDetails, sqlx::Error> {
        let debt_id_str: String = row.try_get("debt_id").or_else(|_| {
            let id: String = row.try_get("id")?;
            Ok::<_, sqlx::Error>(id)
        })?;
        let debt_id = Uuid::parse_str(&debt_id_str)
            .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?;

        let account_id_str: String = row.try_get("account_id")?;
        let account_id = Uuid::parse_str(&account_id_str)
            .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?;

        let counterparty: String = row.try_get("counterparty")?;

        let interest_rate_str: String = row.try_get("interest_rate")?;
        let interest_rate = Decimal::from_str(&interest_rate_str)
            .map_err(|e| sqlx::Error::Decode(format!("invalid decimal: {}", e).into()))?;

        let amortization_method_str: String = row.try_get("amortization_method")?;
        let amortization_method = Self::parse_amortization_method(&amortization_method_str)?;

        let start_date_str: String = row.try_get("start_date")?;
        let start_date = NaiveDate::parse_from_str(&start_date_str, "%Y-%m-%d")
            .map_err(|e| sqlx::Error::Decode(format!("invalid date: {}", e).into()))?;

        let due_date_str: String = row.try_get("due_date")?;
        let due_date = NaiveDate::parse_from_str(&due_date_str, "%Y-%m-%d")
            .map_err(|e| sqlx::Error::Decode(format!("invalid date: {}", e).into()))?;

        let total_principal_str: String = row.try_get("total_principal")?;
        let total_principal = Decimal::from_str(&total_principal_str)
            .map_err(|e| sqlx::Error::Decode(format!("invalid decimal: {}", e).into()))?;

        let schedule = self.find_schedule_by_debt_id(debt_id).await?;

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
}

fn row_to_schedule_entry(
    row: &sqlx::sqlite::SqliteRow,
) -> Result<PaymentScheduleEntry, sqlx::Error> {
    let entry_id_str: String = row
        .try_get("schedule_id")
        .or_else(|_| {
            let id: String = row.try_get("id")?;
            Ok::<_, sqlx::Error>(id)
        })?;
    let entry_id = Uuid::parse_str(&entry_id_str)
        .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?;

    let debt_id_from_row: String = row
        .try_get("debt_id")
        .or_else(|_| {
            let id: String = row.try_get("debt_id")?;
            Ok::<_, sqlx::Error>(id)
        })?;
    let debt_id = Uuid::parse_str(&debt_id_from_row)
        .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?;

    let payment_date_str: String = row.try_get("payment_date")?;
    let payment_date = NaiveDate::parse_from_str(&payment_date_str, "%Y-%m-%d")
        .map_err(|e| sqlx::Error::Decode(format!("invalid date: {}", e).into()))?;

    let principal_amount_str: String = row.try_get("principal_amount")?;
    let principal_amount = Decimal::from_str(&principal_amount_str)
        .map_err(|e| sqlx::Error::Decode(format!("invalid decimal: {}", e).into()))?;

    let interest_amount_str: String = row.try_get("interest_amount")?;
    let interest_amount = Decimal::from_str(&interest_amount_str)
        .map_err(|e| sqlx::Error::Decode(format!("invalid decimal: {}", e).into()))?;

    let total_amount_str: String = row.try_get("total_amount")?;
    let total_amount = Decimal::from_str(&total_amount_str)
        .map_err(|e| sqlx::Error::Decode(format!("invalid decimal: {}", e).into()))?;

    let paid: bool = row.try_get("paid")?;

    let transaction_id: Option<String> = row.try_get("transaction_id")?;
    let transaction_id = transaction_id
        .map(|s| Uuid::parse_str(&s))
        .transpose()
        .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?;

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
