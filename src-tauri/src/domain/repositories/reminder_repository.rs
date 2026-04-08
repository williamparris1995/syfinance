use crate::domain::aggregates::Reminder;
use chrono::{DateTime, Utc};
use uuid::Uuid;

#[allow(async_fn_in_trait, dead_code)]
pub trait ReminderRepository: Send + Sync {
    async fn create(&self, reminder: &Reminder) -> sqlx::Result<()>;
    async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<Reminder>>;
    async fn find_all(&self) -> sqlx::Result<Vec<Reminder>>;
    async fn find_pending_reminders(&self, before: DateTime<Utc>) -> sqlx::Result<Vec<Reminder>>;
    async fn find_by_related_entity(&self, related_entity_id: Uuid) -> sqlx::Result<Vec<Reminder>>;
    async fn update(&self, reminder: &Reminder) -> sqlx::Result<bool>;
    async fn delete(&self, id: Uuid) -> sqlx::Result<bool>;
    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool>;
}
