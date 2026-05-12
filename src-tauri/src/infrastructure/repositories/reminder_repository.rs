use crate::domain::{
    aggregates::{Reminder, ReminderType, RepeatPattern},
    repositories::ReminderRepository,
    value_objects::SyncMetadata,
};
use chrono::{DateTime, Utc};
use sqlx::{Row, SqlitePool};
use uuid::Uuid;

pub struct SqliteReminderRepository {
    pool: SqlitePool,
}

impl SqliteReminderRepository {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl ReminderRepository for SqliteReminderRepository {
    async fn create(&self, reminder: &Reminder) -> sqlx::Result<()> {
        sqlx::query(
            r#"
            INSERT INTO reminders (
                id, reminder_type, related_entity_id, title, description,
                remind_at, repeat_pattern, notified, priority, last_notified_at,
                notification_count, os_task_id, updated_at, device_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            "#,
        )
        .bind(reminder.id.to_string())
        .bind(reminder.reminder_type.as_str())
        .bind(reminder.related_entity_id.map(|id| id.to_string()))
        .bind(&reminder.title)
        .bind(&reminder.description)
        .bind(reminder.remind_at.to_rfc3339())
        .bind(reminder.repeat_pattern.as_ref().map(|p| p.as_str()))
        .bind(reminder.notified)
        .bind(serde_json::to_string(&reminder.priority).unwrap())
        .bind(reminder.last_notified_at.map(|dt| dt.to_rfc3339()))
        .bind(reminder.notification_count as i64)
        .bind(&reminder.os_task_id)
        .bind(reminder.sync_metadata.updated_at.to_rfc3339())
        .bind(reminder.sync_metadata.device_id.to_string())
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<Reminder>> {
        let row = sqlx::query(
            r#"
            SELECT id, reminder_type, related_entity_id, title, description,
                   remind_at, repeat_pattern, notified, priority, last_notified_at,
                   notification_count, os_task_id, updated_at, deleted_at, device_id, synced_at
            FROM reminders
            WHERE id = ? AND deleted_at IS NULL
            "#,
        )
        .bind(id.to_string())
        .fetch_optional(&self.pool)
        .await?;

        let Some(row) = row else {
            return Ok(None);
        };

        let id: String = row.get("id");
        let id = Uuid::parse_str(&id)
            .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?;

        let reminder_type: String = row.get("reminder_type");
        let reminder_type = ReminderType::from_str(&reminder_type)
            .map_err(|e| sqlx::Error::Decode(format!("invalid reminder type: {}", e).into()))?;

        let related_entity_id: Option<String> = row.get("related_entity_id");
        let related_entity_id = related_entity_id
            .map(|s| Uuid::parse_str(&s))
            .transpose()
            .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?;

        let title: String = row.get("title");
        let description: String = row.get("description");

        let remind_at: String = row.get("remind_at");
        let remind_at = DateTime::parse_from_rfc3339(&remind_at)
            .or_else(|_| {
                chrono::NaiveDateTime::parse_from_str(&remind_at, "%Y-%m-%d %H:%M:%S")
                    .map(|dt| dt.and_utc().into())
            })
            .map_err(|e| sqlx::Error::Decode(format!("invalid datetime: {}", e).into()))?
            .with_timezone(&Utc);

        let repeat_pattern: Option<String> = row.get("repeat_pattern");
        let repeat_pattern = repeat_pattern
            .map(|s| RepeatPattern::from_str(&s))
            .transpose()
            .map_err(|e| sqlx::Error::Decode(format!("invalid repeat pattern: {}", e).into()))?;

        let notified: bool = row.get("notified");

        let priority: String = row.get("priority");
        let priority = serde_json::from_str(&priority)
            .map_err(|e| sqlx::Error::Decode(format!("invalid priority: {}", e).into()))?;

        let last_notified_at: Option<String> = row.get("last_notified_at");
        let last_notified_at = last_notified_at
            .map(|s| {
                DateTime::parse_from_rfc3339(&s)
                    .or_else(|_| {
                        chrono::NaiveDateTime::parse_from_str(&s, "%Y-%m-%d %H:%M:%S")
                            .map(|dt| dt.and_utc().into())
                    })
                    .map(|dt| dt.with_timezone(&Utc))
            })
            .transpose()
            .map_err(|e: chrono::ParseError| {
                sqlx::Error::Decode(format!("invalid datetime: {}", e).into())
            })?;

        let notification_count: i64 = row.get("notification_count");
        let notification_count = notification_count as u32;

        let os_task_id: Option<String> = row.get("os_task_id");

        let updated_at: String = row.get("updated_at");
        let device_id: String = row.get("device_id");
        let synced_at: Option<String> = row.get("synced_at");
        let deleted_at: Option<String> = row.get("deleted_at");

        let sync_metadata = SyncMetadata {
            updated_at: DateTime::parse_from_rfc3339(&updated_at)
                .or_else(|_| {
                    chrono::NaiveDateTime::parse_from_str(&updated_at, "%Y-%m-%d %H:%M:%S")
                        .map(|dt| dt.and_utc().into())
                })
                .map_err(|e| sqlx::Error::Decode(format!("invalid datetime: {}", e).into()))?
                .with_timezone(&Utc),
            deleted_at: deleted_at
                .map(|s| {
                    DateTime::parse_from_rfc3339(&s)
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
                    DateTime::parse_from_rfc3339(&s)
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

        Ok(Some(Reminder {
            id,
            reminder_type,
            related_entity_id,
            title,
            description,
            remind_at,
            repeat_pattern,
            notified,
            priority,
            last_notified_at,
            notification_count,
            os_task_id,
            sync_metadata,
        }))
    }

    async fn find_all(&self) -> sqlx::Result<Vec<Reminder>> {
        let rows = sqlx::query(
            r#"
            SELECT id
            FROM reminders
            WHERE deleted_at IS NULL
            ORDER BY remind_at ASC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        let mut reminders = Vec::new();
        for row in rows {
            let id: String = row.get("id");
            let id = Uuid::parse_str(&id)
                .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?;

            if let Some(reminder) = self.find_by_id(id).await? {
                reminders.push(reminder);
            }
        }

        Ok(reminders)
    }

    async fn find_pending_reminders(&self, before: DateTime<Utc>) -> sqlx::Result<Vec<Reminder>> {
        let rows = sqlx::query(
            r#"
            SELECT id
            FROM reminders
            WHERE remind_at <= ? AND notified = 0 AND deleted_at IS NULL
            ORDER BY remind_at ASC
            "#,
        )
        .bind(before.to_rfc3339())
        .fetch_all(&self.pool)
        .await?;

        let mut reminders = Vec::new();
        for row in rows {
            let id: String = row.get("id");
            let id = Uuid::parse_str(&id)
                .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?;

            if let Some(reminder) = self.find_by_id(id).await? {
                reminders.push(reminder);
            }
        }

        Ok(reminders)
    }

    async fn find_by_related_entity(&self, related_entity_id: Uuid) -> sqlx::Result<Vec<Reminder>> {
        let rows = sqlx::query(
            r#"
            SELECT id
            FROM reminders
            WHERE related_entity_id = ? AND deleted_at IS NULL
            ORDER BY remind_at ASC
            "#,
        )
        .bind(related_entity_id.to_string())
        .fetch_all(&self.pool)
        .await?;

        let mut reminders = Vec::new();
        for row in rows {
            let id: String = row.get("id");
            let id = Uuid::parse_str(&id)
                .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?;

            if let Some(reminder) = self.find_by_id(id).await? {
                reminders.push(reminder);
            }
        }

        Ok(reminders)
    }

    async fn update(&self, reminder: &Reminder) -> sqlx::Result<bool> {
        let result = sqlx::query(
            r#"
            UPDATE reminders
            SET reminder_type = ?, related_entity_id = ?, title = ?, description = ?,
                remind_at = ?, repeat_pattern = ?, notified = ?,
                updated_at = ?, synced_at = ?
            WHERE id = ? AND deleted_at IS NULL
            "#,
        )
        .bind(reminder.reminder_type.as_str())
        .bind(reminder.related_entity_id.map(|id| id.to_string()))
        .bind(&reminder.title)
        .bind(&reminder.description)
        .bind(reminder.remind_at.to_rfc3339())
        .bind(reminder.repeat_pattern.as_ref().map(|p| p.as_str()))
        .bind(reminder.notified)
        .bind(reminder.sync_metadata.updated_at.to_rfc3339())
        .bind(reminder.sync_metadata.synced_at.map(|dt| dt.to_rfc3339()))
        .bind(reminder.id.to_string())
        .execute(&self.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    async fn delete(&self, id: Uuid) -> sqlx::Result<bool> {
        let result = sqlx::query("DELETE FROM reminders WHERE id = ?")
            .bind(id.to_string())
            .execute(&self.pool)
            .await?;

        Ok(result.rows_affected() > 0)
    }

    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool> {
        let result = sqlx::query(
            r#"
            UPDATE reminders
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

    async fn get_changes_since(&self, timestamp: DateTime<Utc>) -> sqlx::Result<Vec<Reminder>> {
        let rows = sqlx::query(
            r#"
            SELECT id
            FROM reminders
            WHERE updated_at > ? AND (synced_at IS NULL OR synced_at < updated_at)
            ORDER BY updated_at ASC
            "#,
        )
        .bind(timestamp.to_rfc3339())
        .fetch_all(&self.pool)
        .await?;

        let mut reminders = Vec::new();
        for row in rows {
            let id: String = row.get("id");
            let id = Uuid::parse_str(&id)
                .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?;

            if let Some(reminder) = self.find_by_id(id).await? {
                reminders.push(reminder);
            }
        }

        Ok(reminders)
    }

    async fn mark_as_synced(&self, id: Uuid) -> sqlx::Result<bool> {
        let result = sqlx::query(
            r#"
            UPDATE reminders
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
