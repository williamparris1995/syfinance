use crate::domain::aggregates::reminder::Reminder;
use async_trait::async_trait;
use chrono::{DateTime, Utc};
use uuid::Uuid;

#[async_trait]
pub trait ReminderRepository: Send + Sync {
    async fn create(&self, reminder: &Reminder) -> Result<(), Box<dyn std::error::Error>>;
    async fn find_by_id(&self, id: Uuid) -> Result<Option<Reminder>, Box<dyn std::error::Error>>;
    async fn find_all(&self) -> Result<Vec<Reminder>, Box<dyn std::error::Error>>;
    async fn find_pending_reminders(
        &self,
        before: DateTime<Utc>,
    ) -> Result<Vec<Reminder>, Box<dyn std::error::Error>>;
    async fn update(&self, reminder: &Reminder) -> Result<(), Box<dyn std::error::Error>>;
    async fn soft_delete(&self, id: Uuid) -> Result<(), Box<dyn std::error::Error>>;
}
