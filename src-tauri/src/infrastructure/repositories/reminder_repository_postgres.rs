use crate::domain::{
    aggregates::{Reminder, ReminderType, RepeatPattern},
    repositories::ReminderRepository,
    value_objects::SyncMetadata,
};
use chrono::{DateTime, Utc};
use sqlx::{postgres::PgPool, Row};
use uuid::Uuid;

#[derive(Clone)]
pub struct PostgresReminderRepository {
    pool: PgPool,
}

impl PostgresReminderRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

impl ReminderRepository for PostgresReminderRepository {
    async fn create(&self, reminder: &Reminder) -> sqlx::Result<()> {
        sqlx::query(
            r#"
            INSERT INTO reminders (
                id, reminder_type, related_entity_id, title, description,
                remind_at, repeat_pattern, notified, priority, last_notified_at,
                notification_count, os_task_id, updated_at, device_id
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
            ON CONFLICT (id) DO UPDATE SET
                reminder_type = EXCLUDED.reminder_type,
                related_entity_id = EXCLUDED.related_entity_id,
                title = EXCLUDED.title,
                description = EXCLUDED.description,
                remind_at = EXCLUDED.remind_at,
                repeat_pattern = EXCLUDED.repeat_pattern,
                notified = EXCLUDED.notified,
                priority = EXCLUDED.priority,
                last_notified_at = EXCLUDED.last_notified_at,
                notification_count = EXCLUDED.notification_count,
                os_task_id = EXCLUDED.os_task_id,
                updated_at = EXCLUDED.updated_at,
                device_id = EXCLUDED.device_id
            "#,
        )
        .bind(reminder.id)
        .bind(reminder.reminder_type.as_str())
        .bind(reminder.related_entity_id)
        .bind(&reminder.title)
        .bind(&reminder.description)
        .bind(reminder.remind_at)
        .bind(reminder.repeat_pattern.as_ref().map(|p| p.as_str()))
        .bind(reminder.notified)
        .bind(serde_json::to_string(&reminder.priority).unwrap())
        .bind(reminder.last_notified_at)
        .bind(reminder.notification_count as i32)
        .bind(&reminder.os_task_id)
        .bind(reminder.sync_metadata.updated_at)
        .bind(reminder.sync_metadata.device_id)
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
            WHERE id = $1 AND deleted_at IS NULL
            "#,
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await?;

        let Some(row) = row else {
            return Ok(None);
        };

        let id: Uuid = row.try_get("id")?;
        let reminder_type: String = row.try_get("reminder_type")?;
        let reminder_type = ReminderType::from_str(&reminder_type)
            .map_err(|e| sqlx::Error::Decode(format!("invalid reminder type: {}", e).into()))?;

        let related_entity_id: Option<Uuid> = row.try_get("related_entity_id")?;
        let title: String = row.try_get("title")?;
        let description: String = row.try_get("description")?;
        let remind_at: DateTime<Utc> = row.try_get("remind_at")?;

        let repeat_pattern: Option<String> = row.try_get("repeat_pattern")?;
        let repeat_pattern = repeat_pattern
            .map(|s| RepeatPattern::from_str(&s))
            .transpose()
            .map_err(|e| sqlx::Error::Decode(format!("invalid repeat pattern: {}", e).into()))?;

        let notified: bool = row.try_get("notified")?;

        let priority: String = row.try_get("priority")?;
        let priority = serde_json::from_str(&priority)
            .map_err(|e| sqlx::Error::Decode(format!("invalid priority: {}", e).into()))?;

        let last_notified_at: Option<DateTime<Utc>> = row.try_get("last_notified_at")?;
        let notification_count: i32 = row.try_get("notification_count")?;
        let notification_count = notification_count as u32;
        let os_task_id: Option<String> = row.try_get("os_task_id")?;

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
            let id: Uuid = row.try_get("id")?;
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
            WHERE remind_at <= $1 AND notified = false AND deleted_at IS NULL
            ORDER BY remind_at ASC
            "#,
        )
        .bind(before)
        .fetch_all(&self.pool)
        .await?;

        let mut reminders = Vec::new();
        for row in rows {
            let id: Uuid = row.try_get("id")?;
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
            WHERE related_entity_id = $1 AND deleted_at IS NULL
            ORDER BY remind_at ASC
            "#,
        )
        .bind(related_entity_id)
        .fetch_all(&self.pool)
        .await?;

        let mut reminders = Vec::new();
        for row in rows {
            let id: Uuid = row.try_get("id")?;
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
            SET reminder_type = $1, related_entity_id = $2, title = $3, description = $4,
                remind_at = $5, repeat_pattern = $6, notified = $7,
                updated_at = $8, synced_at = $9
            WHERE id = $10 AND deleted_at IS NULL
            RETURNING id
            "#,
        )
        .bind(reminder.reminder_type.as_str())
        .bind(reminder.related_entity_id)
        .bind(&reminder.title)
        .bind(&reminder.description)
        .bind(reminder.remind_at)
        .bind(reminder.repeat_pattern.as_ref().map(|p| p.as_str()))
        .bind(reminder.notified)
        .bind(reminder.sync_metadata.updated_at)
        .bind(reminder.sync_metadata.synced_at)
        .bind(reminder.id)
        .fetch_optional(&self.pool)
        .await?;

        Ok(result.is_some())
    }

    async fn delete(&self, id: Uuid) -> sqlx::Result<bool> {
        let result = sqlx::query("DELETE FROM reminders WHERE id = $1 RETURNING id")
            .bind(id)
            .fetch_optional(&self.pool)
            .await?;

        Ok(result.is_some())
    }

    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool> {
        let result = sqlx::query(
            r#"
            UPDATE reminders
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

    async fn get_changes_since(&self, timestamp: DateTime<Utc>) -> sqlx::Result<Vec<Reminder>> {
        let rows = sqlx::query(
            r#"
            SELECT id
            FROM reminders
            WHERE updated_at > $1 AND (synced_at IS NULL OR synced_at < updated_at)
            ORDER BY updated_at ASC
            "#,
        )
        .bind(timestamp)
        .fetch_all(&self.pool)
        .await?;

        let mut reminders = Vec::new();
        for row in rows {
            let id: Uuid = row.try_get("id")?;
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
            SET synced_at = NOW()
            WHERE id = $1
            RETURNING id
            "#,
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await?;

        Ok(result.is_some())
    }
}
