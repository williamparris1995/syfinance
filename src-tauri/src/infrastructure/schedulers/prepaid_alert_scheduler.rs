use chrono::Utc;
use sqlx::SqlitePool;
use tracing::{error, info};
use uuid::Uuid;

use crate::domain::aggregates::reminder::{Priority, Reminder, ReminderType};
use crate::domain::repositories::ReminderRepository;
use crate::domain::value_objects::SyncMetadata;
use crate::infrastructure::repositories::SqliteReminderRepository;

/// Background scheduler that checks for expiring prepaid top-up records
/// and low-balance prepaid accounts, creating reminders as needed.
pub struct PrepaidAlertScheduler {
    pool: SqlitePool,
}

impl PrepaidAlertScheduler {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    /// Check for prepaid top-up records expiring within 7 days.
    pub async fn check_expiry_alerts(&self) -> Result<(), String> {
        info!("Checking prepaid expiry alerts");

        let repo = SqliteReminderRepository::new(self.pool.clone());

        let rows: Vec<(String, String, String, String)> = sqlx::query_as(
            "SELECT tr.id, tr.account_id, a.name, tr.expiry_date
            FROM top_up_records tr
            JOIN accounts a ON a.id = tr.account_id
            WHERE tr.expiry_date IS NOT NULL
              AND date(tr.expiry_date) <= date('now', '+7 days')
              AND date(tr.expiry_date) >= date('now')
              AND NOT EXISTS (
                  SELECT 1 FROM reminders r
                  WHERE r.related_entity_id = tr.account_id
                    AND r.notified = 0
                    AND r.deleted_at IS NULL
              )",
        )
        .fetch_all(&self.pool)
        .await
        .map_err(|e| format!("Failed to query expiring top-up records: {}", e))?;

        for (record_id, account_id, account_name, expiry_date) in &rows {
            let account_uuid = account_id
                .parse::<Uuid>()
                .map_err(|e| format!("Invalid account_id: {}", e))?;

            let reminder = Reminder::create(
                Uuid::new_v4(),
                ReminderType::PrepaidLowBalance,
                Some(account_uuid),
                format!("Prepaid expiry: {}", account_name),
                format!(
                    "Top-up record for {} expires on {}. Record ID: {}",
                    account_name, expiry_date, record_id
                ),
                Utc::now() + chrono::Duration::hours(1),
                None,
                Priority::High,
                SyncMetadata::new(Uuid::new_v4()),
            )
            .map_err(|e| format!("Failed to create reminder: {}", e))?;

            repo.create(&reminder)
                .await
                .map_err(|e| format!("Failed to persist reminder: {}", e))?;

            info!(
                account_name = account_name,
                expiry_date = expiry_date,
                "Created expiry reminder for prepaid account"
            );
        }

        info!(count = rows.len(), "Prepaid expiry check complete");
        Ok(())
    }

    /// Check for prepaid accounts with balance below their threshold.
    pub async fn check_low_balance_alerts(&self) -> Result<(), String> {
        info!("Checking prepaid low-balance alerts");

        let repo = SqliteReminderRepository::new(self.pool.clone());

        let rows: Vec<(String, String, String)> = sqlx::query_as(
            "SELECT a.id, a.name, CAST(a.low_balance_threshold AS TEXT) as threshold
            FROM accounts a
            WHERE a.account_type = 'prepaid'
              AND a.deleted_at IS NULL
              AND a.low_balance_threshold IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1 FROM reminders r
                  WHERE r.related_entity_id = a.id
                    AND r.notified = 0
                    AND r.deleted_at IS NULL
              )",
        )
        .fetch_all(&self.pool)
        .await
        .map_err(|e| format!("Failed to query low-balance accounts: {}", e))?;

        for (account_id_str, account_name, threshold_str) in &rows {
            let account_id = account_id_str
                .parse::<Uuid>()
                .map_err(|e| format!("Invalid account_id: {}", e))?;

            let balance_row: Option<(String,)> = sqlx::query_as(
                "SELECT CAST(a.initial_balance + COALESCE(SUM(
                    CASE
                        WHEN e.debit_amount IS NOT NULL THEN e.debit_amount
                        WHEN e.credit_amount IS NOT NULL THEN -e.credit_amount
                        ELSE 0
                    END
                ), 0) AS TEXT) as balance
                FROM accounts a
                LEFT JOIN transaction_entries e ON e.account_id = a.id AND e.deleted_at IS NULL
                LEFT JOIN transactions t ON t.id = e.transaction_id AND t.deleted_at IS NULL
                WHERE a.id = ?",
            )
            .bind(account_id_str)
            .fetch_optional(&self.pool)
            .await
            .map_err(|e| format!("Failed to compute balance: {}", e))?;

            let balance_str = balance_row.map(|(b,)| b).unwrap_or_else(|| "0".to_string());
            let balance: rust_decimal::Decimal =
                balance_str.parse().unwrap_or(rust_decimal::Decimal::ZERO);
            let threshold: rust_decimal::Decimal =
                threshold_str.parse().unwrap_or(rust_decimal::Decimal::ZERO);

            if balance < threshold {
                let reminder = Reminder::create(
                    Uuid::new_v4(),
                    ReminderType::PrepaidLowBalance,
                    Some(account_id),
                    format!("Low balance alert: {}", account_name),
                    format!(
                        "Account {} balance ({}) is below threshold ({})",
                        account_name, balance, threshold
                    ),
                    Utc::now() + chrono::Duration::hours(1),
                    None,
                    Priority::High,
                    SyncMetadata::new(Uuid::new_v4()),
                )
                .map_err(|e| format!("Failed to create reminder: {}", e))?;

                repo.create(&reminder)
                    .await
                    .map_err(|e| format!("Failed to persist reminder: {}", e))?;

                info!(
                    account_name = account_name,
                    balance = %balance,
                    threshold = %threshold,
                    "Created low-balance reminder for prepaid account"
                );
            }
        }

        info!(
            candidates = rows.len(),
            "Prepaid low-balance check complete"
        );
        Ok(())
    }

    /// Run all prepaid alert checks.
    pub async fn run_all_checks(&self) -> Result<(), String> {
        if let Err(e) = self.check_expiry_alerts().await {
            error!(error = %e, "Prepaid expiry alert check failed");
        }
        if let Err(e) = self.check_low_balance_alerts().await {
            error!(error = %e, "Prepaid low-balance alert check failed");
        }
        Ok(())
    }
}
