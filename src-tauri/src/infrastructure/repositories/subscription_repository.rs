use crate::domain::aggregates::subscription::{
    Subscription, SubscriptionCycle, SubscriptionDirection,
};
use crate::domain::repositories::SubscriptionRepository;
use chrono::{NaiveDate, Utc};
use rust_decimal::Decimal;
use sqlx::{Row, SqlitePool};
use std::str::FromStr;
use uuid::Uuid;

pub struct SqliteSubscriptionRepository {
    pool: SqlitePool,
}

impl SqliteSubscriptionRepository {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn row_to_subscription(row: &sqlx::sqlite::SqliteRow) -> Result<Subscription, sqlx::Error> {
        let cycle_str: String = row.try_get("cycle")?;
        let cycle = match cycle_str.as_str() {
            "weekly" => SubscriptionCycle::Weekly,
            "monthly" => SubscriptionCycle::Monthly,
            "yearly" => SubscriptionCycle::Yearly,
            "custom" => {
                let days: Option<i32> = row.try_get("cycle_days")?;
                SubscriptionCycle::Custom {
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
            "expense" => SubscriptionDirection::Expense,
            "income" => SubscriptionDirection::Income,
            _ => {
                return Err(sqlx::Error::Decode(
                    format!("invalid direction: {}", dir_str).into(),
                ))
            }
        };

        Ok(Subscription {
            id: Uuid::parse_str(&row.try_get::<String, _>("id")?)
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            name: row.try_get("name")?,
            amount: Decimal::from_str(&row.try_get::<String, _>("amount")?)
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            direction,
            cycle,
            billing_day: row
                .try_get::<Option<i32>, _>("billing_day")?
                .map(|d| d as u8),
            next_billing_date: NaiveDate::parse_from_str(
                &row.try_get::<String, _>("next_billing_date")?,
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
            source_account_id: Uuid::parse_str(&row.try_get::<String, _>("source_account_id")?)
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            category: row.try_get("category")?,
            description: row.try_get("description")?,
            last_transaction_id: row
                .try_get::<Option<String>, _>("last_transaction_id")?
                .map(|s| Uuid::parse_str(&s))
                .transpose()
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
        })
    }
}

impl SubscriptionRepository for SqliteSubscriptionRepository {
    async fn create(&self, s: &Subscription) -> sqlx::Result<()> {
        let (cycle_str, cycle_days) = match &s.cycle {
            SubscriptionCycle::Weekly => ("weekly", None),
            SubscriptionCycle::Monthly => ("monthly", None),
            SubscriptionCycle::Yearly => ("yearly", None),
            SubscriptionCycle::Custom { days } => ("custom", Some(*days as i32)),
        };
        sqlx::query(
            "INSERT INTO subscriptions (id, name, amount, direction, cycle, cycle_days, billing_day, next_billing_date, start_date, end_date, auto_record, paused, source_account_id, category, description, last_transaction_id, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(s.id.to_string())
        .bind(&s.name)
        .bind(s.amount.to_string())
        .bind(match s.direction {
            SubscriptionDirection::Expense => "expense",
            SubscriptionDirection::Income => "income",
        })
        .bind(cycle_str)
        .bind(cycle_days)
        .bind(s.billing_day.map(|d| d as i32))
        .bind(s.next_billing_date.to_string())
        .bind(s.start_date.to_string())
        .bind(s.end_date.map(|d| d.to_string()))
        .bind(s.auto_record as i32)
        .bind(s.paused as i32)
        .bind(s.source_account_id.to_string())
        .bind(&s.category)
        .bind(&s.description)
        .bind(s.last_transaction_id.map(|id| id.to_string()))
        .bind(Utc::now().to_rfc3339())
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<Subscription>> {
        let row = sqlx::query("SELECT * FROM subscriptions WHERE id = ? AND deleted_at IS NULL")
            .bind(id.to_string())
            .fetch_optional(&self.pool)
            .await?;
        row.map(|r| Self::row_to_subscription(&r)).transpose()
    }

    async fn find_all(&self) -> sqlx::Result<Vec<Subscription>> {
        let rows = sqlx::query(
            "SELECT * FROM subscriptions WHERE deleted_at IS NULL ORDER BY next_billing_date ASC",
        )
        .fetch_all(&self.pool)
        .await?;
        rows.iter().map(|r| Self::row_to_subscription(r)).collect()
    }

    async fn find_due(&self, today: NaiveDate) -> sqlx::Result<Vec<Subscription>> {
        let rows = sqlx::query(
            "SELECT * FROM subscriptions
             WHERE next_billing_date <= ? AND auto_record = 1 AND paused = 0 AND deleted_at IS NULL",
        )
        .bind(today.to_string())
        .fetch_all(&self.pool)
        .await?;
        rows.iter().map(|r| Self::row_to_subscription(r)).collect()
    }

    async fn update(&self, s: &Subscription) -> sqlx::Result<bool> {
        let (cycle_str, cycle_days) = match &s.cycle {
            SubscriptionCycle::Weekly => ("weekly", None),
            SubscriptionCycle::Monthly => ("monthly", None),
            SubscriptionCycle::Yearly => ("yearly", None),
            SubscriptionCycle::Custom { days } => ("custom", Some(*days as i32)),
        };
        let r = sqlx::query(
            "UPDATE subscriptions SET name=?, amount=?, direction=?, cycle=?, cycle_days=?, billing_day=?, next_billing_date=?, start_date=?, end_date=?, auto_record=?, category=?, description=?, updated_at=?
             WHERE id=? AND deleted_at IS NULL",
        )
        .bind(&s.name)
        .bind(s.amount.to_string())
        .bind(match s.direction {
            SubscriptionDirection::Expense => "expense",
            SubscriptionDirection::Income => "income",
        })
        .bind(cycle_str)
        .bind(cycle_days)
        .bind(s.billing_day.map(|d| d as i32))
        .bind(s.next_billing_date.to_string())
        .bind(s.start_date.to_string())
        .bind(s.end_date.map(|d| d.to_string()))
        .bind(s.auto_record as i32)
        .bind(&s.category)
        .bind(&s.description)
        .bind(Utc::now().to_rfc3339())
        .bind(s.id.to_string())
        .execute(&self.pool)
        .await?;
        Ok(r.rows_affected() > 0)
    }

    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool> {
        let r =
            sqlx::query("UPDATE subscriptions SET deleted_at=? WHERE id=? AND deleted_at IS NULL")
                .bind(Utc::now().to_rfc3339())
                .bind(id.to_string())
                .execute(&self.pool)
                .await?;
        Ok(r.rows_affected() > 0)
    }

    async fn update_next_billing_date(
        &self,
        id: Uuid,
        next_date: NaiveDate,
        last_tx_id: Option<Uuid>,
    ) -> sqlx::Result<bool> {
        let r = sqlx::query(
            "UPDATE subscriptions SET next_billing_date=?, last_transaction_id=?, updated_at=? WHERE id=? AND deleted_at IS NULL",
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
            "UPDATE subscriptions SET paused=?, updated_at=? WHERE id=? AND deleted_at IS NULL",
        )
        .bind(paused as i32)
        .bind(Utc::now().to_rfc3339())
        .bind(id.to_string())
        .execute(&self.pool)
        .await?;
        Ok(r.rows_affected() > 0)
    }
}
