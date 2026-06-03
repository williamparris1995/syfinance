use crate::domain::aggregates::transaction_template::{
    TemplateCycle, TemplateDirection, TransactionTemplate,
};
use crate::domain::repositories::TransactionTemplateRepository;
use chrono::{NaiveDate, Utc};
use rust_decimal::Decimal;
use sqlx::{Row, SqlitePool};
use std::str::FromStr;
use uuid::Uuid;

pub struct SqliteTransactionTemplateRepository {
    pool: SqlitePool,
}

impl SqliteTransactionTemplateRepository {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn row_to_template(row: &sqlx::sqlite::SqliteRow) -> Result<TransactionTemplate, sqlx::Error> {
        let cycle_str: String = row.try_get("cycle")?;
        let cycle = match cycle_str.as_str() {
            "weekly" => TemplateCycle::Weekly,
            "monthly" => TemplateCycle::Monthly,
            "yearly" => TemplateCycle::Yearly,
            "custom" => {
                let days: Option<i32> = row.try_get("cycle_days")?;
                TemplateCycle::Custom {
                    days: days.unwrap_or(30) as u32,
                }
            }
            _ => {
                return Err(sqlx::Error::Decode(
                    format!("invalid cycle: {}", cycle_str).into(),
                ))
            }
        };

        let dir_str: String = row.try_get("direction")?;
        let direction = match dir_str.as_str() {
            "expense" => TemplateDirection::Expense,
            "income" => TemplateDirection::Income,
            "transfer" => TemplateDirection::Transfer,
            _ => {
                return Err(sqlx::Error::Decode(
                    format!("invalid direction: {}", dir_str).into(),
                ))
            }
        };

        Ok(TransactionTemplate {
            id: Uuid::parse_str(&row.try_get::<String, _>("id")?)
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            name: row.try_get("name")?,
            description: row.try_get("description")?,
            amount: Decimal::from_str(&row.try_get::<String, _>("amount")?)
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            direction,
            source_account_id: Uuid::parse_str(&row.try_get::<String, _>("source_account_id")?)
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            destination_account_id: row
                .try_get::<Option<String>, _>("destination_account_id")?
                .map(|s| Uuid::parse_str(&s))
                .transpose()
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            cycle,
            billing_day: row
                .try_get::<Option<i32>, _>("billing_day")?
                .map(|d| d as u8),
            next_date: NaiveDate::parse_from_str(
                &row.try_get::<String, _>("next_date")?,
                "%Y-%m-%d",
            )
            .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            start_date: NaiveDate::parse_from_str(
                &row.try_get::<String, _>("start_date")?,
                "%Y-%m-%d",
            )
            .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            end_date: row
                .try_get::<Option<String>, _>("end_date")?
                .map(|s| NaiveDate::parse_from_str(&s, "%Y-%m-%d"))
                .transpose()
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            auto_record: row.try_get::<i32, _>("auto_record")? != 0,
            paused: row.try_get::<i32, _>("paused")? != 0,
            last_transaction_id: row
                .try_get::<Option<String>, _>("last_transaction_id")?
                .map(|s| Uuid::parse_str(&s))
                .transpose()
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            category: row.try_get("category")?,
        })
    }
}

impl TransactionTemplateRepository for SqliteTransactionTemplateRepository {
    async fn create(&self, t: &TransactionTemplate) -> sqlx::Result<()> {
        let (cycle_str, cycle_days) = match &t.cycle {
            TemplateCycle::Weekly => ("weekly", None),
            TemplateCycle::Monthly => ("monthly", None),
            TemplateCycle::Yearly => ("yearly", None),
            TemplateCycle::Custom { days } => ("custom", Some(*days as i32)),
        };
        sqlx::query(
            "INSERT INTO transaction_templates (id, name, description, amount, direction, source_account_id, destination_account_id, cycle, cycle_days, billing_day, next_date, start_date, end_date, auto_record, paused, last_transaction_id, category, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(t.id.to_string())
        .bind(&t.name)
        .bind(&t.description)
        .bind(t.amount.to_string())
        .bind(match &t.direction {
            TemplateDirection::Expense => "expense",
            TemplateDirection::Income => "income",
            TemplateDirection::Transfer => "transfer",
        })
        .bind(t.source_account_id.to_string())
        .bind(t.destination_account_id.map(|id| id.to_string()))
        .bind(cycle_str)
        .bind(cycle_days)
        .bind(t.billing_day.map(|d| d as i32))
        .bind(t.next_date.to_string())
        .bind(t.start_date.to_string())
        .bind(t.end_date.map(|d| d.to_string()))
        .bind(t.auto_record as i32)
        .bind(t.paused as i32)
        .bind(t.last_transaction_id.map(|id| id.to_string()))
        .bind(&t.category)
        .bind(Utc::now().to_rfc3339())
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<TransactionTemplate>> {
        let row =
            sqlx::query("SELECT * FROM transaction_templates WHERE id = ? AND deleted_at IS NULL")
                .bind(id.to_string())
                .fetch_optional(&self.pool)
                .await?;
        row.map(|r| Self::row_to_template(&r)).transpose()
    }

    async fn find_all(&self) -> sqlx::Result<Vec<TransactionTemplate>> {
        let rows = sqlx::query(
            "SELECT * FROM transaction_templates WHERE deleted_at IS NULL ORDER BY next_date ASC",
        )
        .fetch_all(&self.pool)
        .await?;
        rows.iter().map(Self::row_to_template).collect()
    }

    async fn find_due(&self, today: NaiveDate) -> sqlx::Result<Vec<TransactionTemplate>> {
        let rows = sqlx::query(
            "SELECT * FROM transaction_templates
             WHERE next_date <= ? AND auto_record = 1 AND paused = 0 AND deleted_at IS NULL",
        )
        .bind(today.to_string())
        .fetch_all(&self.pool)
        .await?;
        rows.iter().map(Self::row_to_template).collect()
    }

    async fn update(&self, t: &TransactionTemplate) -> sqlx::Result<bool> {
        let (cycle_str, cycle_days) = match &t.cycle {
            TemplateCycle::Weekly => ("weekly", None),
            TemplateCycle::Monthly => ("monthly", None),
            TemplateCycle::Yearly => ("yearly", None),
            TemplateCycle::Custom { days } => ("custom", Some(*days as i32)),
        };
        let r = sqlx::query(
            "UPDATE transaction_templates SET name=?, description=?, amount=?, direction=?, source_account_id=?, destination_account_id=?, cycle=?, cycle_days=?, billing_day=?, next_date=?, start_date=?, end_date=?, auto_record=?, category=?, updated_at=?
             WHERE id=? AND deleted_at IS NULL",
        )
        .bind(&t.name)
        .bind(&t.description)
        .bind(t.amount.to_string())
        .bind(match &t.direction {
            TemplateDirection::Expense => "expense",
            TemplateDirection::Income => "income",
            TemplateDirection::Transfer => "transfer",
        })
        .bind(t.source_account_id.to_string())
        .bind(t.destination_account_id.map(|id| id.to_string()))
        .bind(cycle_str)
        .bind(cycle_days)
        .bind(t.billing_day.map(|d| d as i32))
        .bind(t.next_date.to_string())
        .bind(t.start_date.to_string())
        .bind(t.end_date.map(|d| d.to_string()))
        .bind(t.auto_record as i32)
        .bind(&t.category)
        .bind(Utc::now().to_rfc3339())
        .bind(t.id.to_string())
        .execute(&self.pool)
        .await?;
        Ok(r.rows_affected() > 0)
    }

    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool> {
        let r = sqlx::query(
            "UPDATE transaction_templates SET deleted_at=? WHERE id=? AND deleted_at IS NULL",
        )
        .bind(Utc::now().to_rfc3339())
        .bind(id.to_string())
        .execute(&self.pool)
        .await?;
        Ok(r.rows_affected() > 0)
    }

    async fn update_next_date(
        &self,
        id: Uuid,
        next_date: NaiveDate,
        last_tx_id: Option<Uuid>,
    ) -> sqlx::Result<bool> {
        let r = sqlx::query(
            "UPDATE transaction_templates SET next_date=?, last_transaction_id=?, updated_at=? WHERE id=? AND deleted_at IS NULL",
        )
        .bind(next_date.to_string())
        .bind(last_tx_id.map(|id| id.to_string()))
        .bind(Utc::now().to_rfc3339())
        .bind(id.to_string())
        .execute(&self.pool)
        .await?;
        Ok(r.rows_affected() > 0)
    }

    async fn set_paused(&self, id: Uuid, paused: bool) -> sqlx::Result<bool> {
        let r = sqlx::query(
            "UPDATE transaction_templates SET paused=?, updated_at=? WHERE id=? AND deleted_at IS NULL",
        )
        .bind(paused as i32)
        .bind(Utc::now().to_rfc3339())
        .bind(id.to_string())
        .execute(&self.pool)
        .await?;
        Ok(r.rows_affected() > 0)
    }
}
