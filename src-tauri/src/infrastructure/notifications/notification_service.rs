use crate::domain::{aggregates::Reminder, repositories::ReminderRepository};
use async_trait::async_trait;
use chrono::Utc;
use std::{collections::HashMap, sync::Arc};
use tauri::{AppHandle, Manager, Runtime};
use tauri_plugin_notification::NotificationExt;
use tokio::{sync::Mutex, task::JoinHandle};
use uuid::Uuid;

#[derive(Debug, thiserror::Error)]
pub enum NotificationError {
    #[error("notification send failed: {0}")]
    SendFailed(String),
    #[error("notification click handling failed: {0}")]
    ClickFailed(String),
    #[error("repository error: {0}")]
    Repository(String),
}

#[async_trait]
pub trait NotificationSender: Send + Sync {
    async fn send(&self, reminder: &Reminder) -> Result<(), NotificationError>;

    async fn handle_click(&self) -> Result<(), NotificationError> {
        Ok(())
    }
}

pub struct TauriNotificationSender<R: Runtime> {
    app: AppHandle<R>,
}

impl<R: Runtime> TauriNotificationSender<R> {
    pub fn new(app: AppHandle<R>) -> Self {
        Self { app }
    }
}

#[async_trait]
impl<R: Runtime> NotificationSender for TauriNotificationSender<R> {
    async fn send(&self, reminder: &Reminder) -> Result<(), NotificationError> {
        let mut builder = self
            .app
            .notification()
            .builder()
            .title(reminder.title.clone())
            .auto_cancel()
            .extra("reminder_id", reminder.id.to_string());

        if !reminder.description.is_empty() {
            builder = builder.body(reminder.description.clone());
        }

        builder
            .show()
            .map_err(|err| NotificationError::SendFailed(err.to_string()))
    }

    async fn handle_click(&self) -> Result<(), NotificationError> {
        if let Some(window) = self.app.get_webview_window("main") {
            window
                .show()
                .map_err(|err| NotificationError::ClickFailed(err.to_string()))?;
            window
                .set_focus()
                .map_err(|err| NotificationError::ClickFailed(err.to_string()))?;
            return Ok(());
        }

        if let Some(window) = self.app.webview_windows().into_values().next() {
            window
                .show()
                .map_err(|err| NotificationError::ClickFailed(err.to_string()))?;
            window
                .set_focus()
                .map_err(|err| NotificationError::ClickFailed(err.to_string()))?;
        }

        Ok(())
    }
}

pub struct NotificationService<R, S>
where
    R: ReminderRepository,
    S: NotificationSender,
{
    reminder_repo: Arc<R>,
    sender: Arc<S>,
    scheduled: Arc<Mutex<HashMap<Uuid, JoinHandle<()>>>>,
}

impl<R, S> NotificationService<R, S>
where
    R: ReminderRepository,
    S: NotificationSender + 'static,
{
    pub fn new(reminder_repo: Arc<R>, sender: Arc<S>) -> Self {
        Self {
            reminder_repo,
            sender,
            scheduled: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    pub async fn send_notification(&self, reminder: &Reminder) -> Result<(), NotificationError> {
        self.sender.send(reminder).await
    }

    pub async fn schedule_notification(
        &self,
        reminder: Reminder,
    ) -> Result<(), NotificationError> {
        if reminder.notified {
            return Ok(());
        }

        self.cancel_notification(reminder.id).await?;

        let reminder_id = reminder.id;
        let sender = Arc::clone(&self.sender);
        let scheduled = Arc::clone(&self.scheduled);

        let handle = tokio::spawn(async move {
            let mut current = reminder;

            loop {
                let now = Utc::now();
                if current.remind_at > now {
                    let wait = (current.remind_at - now)
                        .to_std()
                        .unwrap_or_else(|_| std::time::Duration::from_secs(0));
                    tokio::time::sleep(wait).await;
                }

                if let Err(err) = sender.send(&current).await {
                    eprintln!("failed to send reminder {}: {}", current.id, err);
                    break;
                }

                current.notified = true;
                if let Some(next_remind_at) = current.calculate_next_occurrence() {
                    current.remind_at = next_remind_at;
                    current.notified = false;
                    continue;
                }

                break;
            }

            scheduled.lock().await.remove(&reminder_id);
        });

        self.scheduled.lock().await.insert(reminder_id, handle);
        Ok(())
    }

    pub async fn cancel_notification(&self, reminder_id: Uuid) -> Result<bool, NotificationError> {
        let handle = self.scheduled.lock().await.remove(&reminder_id);
        if let Some(handle) = handle {
            handle.abort();
            return Ok(true);
        }

        Ok(false)
    }

    pub async fn reschedule_all(&self) -> Result<usize, NotificationError> {
        let reminders = self
            .reminder_repo
            .find_all()
            .await
            .map_err(|err| NotificationError::Repository(err.to_string()))?;

        let mut scheduled_count = 0;
        for reminder in reminders.into_iter().filter(|reminder| !reminder.notified) {
            self.schedule_notification(reminder).await?;
            scheduled_count += 1;
        }

        Ok(scheduled_count)
    }

    pub async fn handle_notification_click(&self) -> Result<(), NotificationError> {
        self.sender.handle_click().await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::aggregates::{ReminderType, RepeatPattern};
    use crate::domain::value_objects::SyncMetadata;
    use chrono::Duration as ChronoDuration;
    use std::time::Duration as StdDuration;

    #[derive(Clone)]
    struct MockReminderRepository {
        reminders: Arc<Vec<Reminder>>,
    }

    impl MockReminderRepository {
        fn new(reminders: Vec<Reminder>) -> Self {
            Self {
                reminders: Arc::new(reminders),
            }
        }
    }

    impl ReminderRepository for MockReminderRepository {
        async fn create(&self, _reminder: &Reminder) -> sqlx::Result<()> {
            unimplemented!("not used in tests")
        }

        async fn find_by_id(&self, _id: Uuid) -> sqlx::Result<Option<Reminder>> {
            unimplemented!("not used in tests")
        }

        async fn find_all(&self) -> sqlx::Result<Vec<Reminder>> {
            Ok(self.reminders.as_ref().clone())
        }

        async fn find_pending_reminders(
            &self,
            _before: chrono::DateTime<Utc>,
        ) -> sqlx::Result<Vec<Reminder>> {
            unimplemented!("not used in tests")
        }

        async fn find_by_related_entity(&self, _related_entity_id: Uuid) -> sqlx::Result<Vec<Reminder>> {
            unimplemented!("not used in tests")
        }

        async fn update(&self, _reminder: &Reminder) -> sqlx::Result<bool> {
            unimplemented!("not used in tests")
        }

        async fn delete(&self, _id: Uuid) -> sqlx::Result<bool> {
            unimplemented!("not used in tests")
        }

        async fn soft_delete(&self, _id: Uuid) -> sqlx::Result<bool> {
            unimplemented!("not used in tests")
        }

        async fn get_changes_since(&self, _timestamp: chrono::DateTime<Utc>) -> sqlx::Result<Vec<Reminder>> {
            unimplemented!("not used in tests")
        }

        async fn mark_as_synced(&self, _id: Uuid) -> sqlx::Result<bool> {
            unimplemented!("not used in tests")
        }
    }

    #[derive(Default)]
    struct MockNotificationSender {
        sent: Arc<Mutex<Vec<Uuid>>>,
        clicked: Arc<Mutex<u32>>,
    }

    #[async_trait]
    impl NotificationSender for MockNotificationSender {
        async fn send(&self, reminder: &Reminder) -> Result<(), NotificationError> {
            self.sent.lock().await.push(reminder.id);
            Ok(())
        }

        async fn handle_click(&self) -> Result<(), NotificationError> {
            *self.clicked.lock().await += 1;
            Ok(())
        }
    }

    fn metadata() -> SyncMetadata {
        SyncMetadata::new(Uuid::new_v4())
    }

    fn reminder(
        title: &str,
        remind_at: chrono::DateTime<Utc>,
        repeat_pattern: Option<RepeatPattern>,
    ) -> Reminder {
        Reminder::create(
            Uuid::new_v4(),
            ReminderType::Custom,
            None,
            title,
            "Body",
            remind_at,
            repeat_pattern,
            metadata(),
        )
        .unwrap()
    }

    #[tokio::test(flavor = "current_thread", start_paused = true)]
    async fn send_notification_uses_sender() {
        let repo = Arc::new(MockReminderRepository::new(vec![]));
        let sender = Arc::new(MockNotificationSender::default());
        let service = NotificationService::new(repo, sender.clone());
        let reminder = reminder("Immediate", Utc::now(), None);

        service.send_notification(&reminder).await.unwrap();

        assert_eq!(sender.sent.lock().await.as_slice(), &[reminder.id]);
    }

    #[tokio::test(flavor = "current_thread", start_paused = true)]
    async fn schedule_notification_can_be_cancelled() {
        let repo = Arc::new(MockReminderRepository::new(vec![]));
        let sender = Arc::new(MockNotificationSender::default());
        let service = NotificationService::new(repo, sender.clone());
        let reminder = reminder("Future", Utc::now() + ChronoDuration::minutes(10), None);

        service.schedule_notification(reminder.clone()).await.unwrap();
        tokio::task::yield_now().await;

        assert!(service.cancel_notification(reminder.id).await.unwrap());
        tokio::time::advance(StdDuration::from_secs(11 * 60)).await;
        tokio::task::yield_now().await;

        assert!(sender.sent.lock().await.is_empty());
    }

    #[tokio::test(flavor = "current_thread", start_paused = true)]
    async fn schedule_notification_keeps_repeating_reminder_active() {
        let repo = Arc::new(MockReminderRepository::new(vec![]));
        let sender = Arc::new(MockNotificationSender::default());
        let service = NotificationService::new(repo, sender.clone());
        let reminder = reminder(
            "Daily",
            Utc::now() + ChronoDuration::minutes(1),
            Some(RepeatPattern::Daily),
        );

        service.schedule_notification(reminder.clone()).await.unwrap();
        tokio::task::yield_now().await;

        tokio::time::advance(StdDuration::from_secs(60)).await;
        tokio::task::yield_now().await;

        assert_eq!(sender.sent.lock().await.as_slice(), &[reminder.id]);
        assert!(service.cancel_notification(reminder.id).await.unwrap());
    }

    #[tokio::test(flavor = "current_thread", start_paused = true)]
    async fn reschedule_all_skips_notified_reminders() {
        let pending = reminder("Pending", Utc::now() - ChronoDuration::minutes(1), None);
        let mut notified = reminder("Done", Utc::now() - ChronoDuration::minutes(1), None);
        notified.notified = true;

        let repo = Arc::new(MockReminderRepository::new(vec![pending.clone(), notified]));
        let sender = Arc::new(MockNotificationSender::default());
        let service = NotificationService::new(repo, sender.clone());

        assert_eq!(service.reschedule_all().await.unwrap(), 1);
        tokio::task::yield_now().await;

        assert_eq!(sender.sent.lock().await.as_slice(), &[pending.id]);
    }

    #[tokio::test(flavor = "current_thread", start_paused = true)]
    async fn handle_notification_click_focuses_app_path() {
        let repo = Arc::new(MockReminderRepository::new(vec![]));
        let sender = Arc::new(MockNotificationSender::default());
        let service = NotificationService::new(repo, sender.clone());

        service.handle_notification_click().await.unwrap();

        assert_eq!(*sender.clicked.lock().await, 1);
    }
}
