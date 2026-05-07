use crate::domain::repositories::ReminderRepository;
use crate::infrastructure::notifications::{NotificationService, NotificationSender};
use chrono::Utc;
use std::sync::Arc;

pub struct ReminderScheduler<R, S>
where
    R: ReminderRepository,
    S: NotificationSender,
{
    reminder_repo: Arc<R>,
    notification_service: Arc<NotificationService<R, S>>,
}

impl<R, S> ReminderScheduler<R, S>
where
    R: ReminderRepository + 'static,
    S: NotificationSender + 'static,
{
    pub fn new(
        reminder_repo: Arc<R>,
        notification_service: Arc<NotificationService<R, S>>,
    ) -> Self {
        Self {
            reminder_repo,
            notification_service,
        }
    }

    pub async fn check_and_trigger_reminders(&self) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let now = Utc::now();
        let pending_reminders = self
            .reminder_repo
            .find_pending_reminders(now)
            .await
            .map_err(|e| format!("failed to fetch pending reminders: {}", e))?;

        for mut reminder in pending_reminders {
            if reminder.should_trigger_now() {
                if let Err(err) = self.notification_service.send_notification(&reminder).await {
                    eprintln!("failed to send notification for reminder {}: {}", reminder.id, err);
                    continue;
                }

                reminder.mark_notified();

                if let Err(err) = self.reminder_repo.update(&reminder).await {
                    eprintln!("failed to mark reminder {} as notified: {}", reminder.id, err);
                    continue;
                }

                if let Some(next_remind_at) = reminder.calculate_next_occurrence() {
                    let mut next_reminder = reminder.clone();
                    next_reminder.id = uuid::Uuid::new_v4();
                    next_reminder.remind_at = next_remind_at;
                    next_reminder.notified = false;
                    next_reminder.sync_metadata.updated_at = Utc::now();
                    next_reminder.sync_metadata.synced_at = None;

                    if let Err(err) = self.reminder_repo.create(&next_reminder).await {
                        eprintln!(
                            "failed to create next occurrence for reminder {}: {}",
                            reminder.id, err
                        );
                    }
                }
            }
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::aggregates::{Reminder, ReminderType, RepeatPattern};
    use crate::domain::value_objects::SyncMetadata;
    use crate::infrastructure::notifications::NotificationSender;
    use async_trait::async_trait;
    use chrono::Duration as ChronoDuration;
    use std::sync::Mutex;
    use uuid::Uuid;

    #[derive(Clone)]
    struct MockReminderRepository {
        reminders: Arc<Mutex<Vec<Reminder>>>,
    }

    impl MockReminderRepository {
        fn new() -> Self {
            Self {
                reminders: Arc::new(Mutex::new(Vec::new())),
            }
        }

        fn add_reminder(&self, reminder: Reminder) {
            self.reminders.lock().unwrap().push(reminder);
        }

        fn get_all(&self) -> Vec<Reminder> {
            self.reminders.lock().unwrap().clone()
        }
    }

    impl ReminderRepository for MockReminderRepository {
        async fn create(&self, reminder: &Reminder) -> sqlx::Result<()> {
            self.reminders.lock().unwrap().push(reminder.clone());
            Ok(())
        }

        async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<Reminder>> {
            Ok(self
                .reminders
                .lock()
                .unwrap()
                .iter()
                .find(|r| r.id == id)
                .cloned())
        }

        async fn find_all(&self) -> sqlx::Result<Vec<Reminder>> {
            Ok(self.reminders.lock().unwrap().clone())
        }

        async fn find_pending_reminders(
            &self,
            before: chrono::DateTime<Utc>,
        ) -> sqlx::Result<Vec<Reminder>> {
            Ok(self
                .reminders
                .lock()
                .unwrap()
                .iter()
                .filter(|r| r.remind_at <= before && !r.notified && r.sync_metadata.deleted_at.is_none())
                .cloned()
                .collect())
        }

        async fn find_by_related_entity(
            &self,
            related_entity_id: Uuid,
        ) -> sqlx::Result<Vec<Reminder>> {
            Ok(self
                .reminders
                .lock()
                .unwrap()
                .iter()
                .filter(|r| r.related_entity_id == Some(related_entity_id))
                .cloned()
                .collect())
        }

        async fn update(&self, reminder: &Reminder) -> sqlx::Result<bool> {
            let mut reminders = self.reminders.lock().unwrap();
            if let Some(pos) = reminders.iter().position(|r| r.id == reminder.id) {
                reminders[pos] = reminder.clone();
                Ok(true)
            } else {
                Ok(false)
            }
        }

        async fn delete(&self, id: Uuid) -> sqlx::Result<bool> {
            let mut reminders = self.reminders.lock().unwrap();
            if let Some(pos) = reminders.iter().position(|r| r.id == id) {
                reminders.remove(pos);
                Ok(true)
            } else {
                Ok(false)
            }
        }

        async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool> {
            let mut reminders = self.reminders.lock().unwrap();
            if let Some(reminder) = reminders.iter_mut().find(|r| r.id == id) {
                reminder.sync_metadata.deleted_at = Some(Utc::now());
                Ok(true)
            } else {
                Ok(false)
            }
        }

        async fn get_changes_since(
            &self,
            timestamp: chrono::DateTime<Utc>,
        ) -> sqlx::Result<Vec<Reminder>> {
            Ok(self
                .reminders
                .lock()
                .unwrap()
                .iter()
                .filter(|r| r.sync_metadata.updated_at > timestamp)
                .cloned()
                .collect())
        }

        async fn mark_as_synced(&self, id: Uuid) -> sqlx::Result<bool> {
            let mut reminders = self.reminders.lock().unwrap();
            if let Some(reminder) = reminders.iter_mut().find(|r| r.id == id) {
                reminder.sync_metadata.synced_at = Some(Utc::now());
                Ok(true)
            } else {
                Ok(false)
            }
        }
    }

    #[derive(Default, Clone)]
    struct TestNotificationSender {
        sent: Arc<Mutex<Vec<Uuid>>>,
    }

    #[async_trait]
    impl NotificationSender for TestNotificationSender {
        async fn send(&self, reminder: &Reminder) -> Result<(), crate::infrastructure::notifications::NotificationError> {
            self.sent.lock().unwrap().push(reminder.id);
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
            "Test description",
            remind_at,
            repeat_pattern,
            metadata(),
        )
        .unwrap()
    }

    #[tokio::test]
    async fn check_and_trigger_sends_notification_for_due_reminder() {
        let repo = Arc::new(MockReminderRepository::new());
        let sender = Arc::new(TestNotificationSender::default());
        let notification_service = Arc::new(NotificationService::new(repo.clone(), sender.clone()));
        let scheduler = ReminderScheduler::new(repo.clone(), notification_service);

        let past_reminder = reminder("Past", Utc::now() - ChronoDuration::minutes(5), None);
        repo.add_reminder(past_reminder.clone());

        scheduler.check_and_trigger_reminders().await.unwrap();

        assert_eq!(sender.sent.lock().unwrap().as_slice(), &[past_reminder.id]);

        let updated = repo.find_by_id(past_reminder.id).await.unwrap().unwrap();
        assert!(updated.notified);
    }

    #[tokio::test]
    async fn check_and_trigger_creates_next_occurrence_for_recurring() {
        let repo = Arc::new(MockReminderRepository::new());
        let sender = Arc::new(TestNotificationSender::default());
        let notification_service = Arc::new(NotificationService::new(repo.clone(), sender.clone()));
        let scheduler = ReminderScheduler::new(repo.clone(), notification_service);

        let recurring = reminder(
            "Monthly",
            Utc::now() - ChronoDuration::minutes(1),
            Some(RepeatPattern::Monthly),
        );
        repo.add_reminder(recurring.clone());

        scheduler.check_and_trigger_reminders().await.unwrap();

        let all_reminders = repo.get_all();
        assert_eq!(all_reminders.len(), 2);

        let original = all_reminders.iter().find(|r| r.id == recurring.id).unwrap();
        assert!(original.notified);

        let next = all_reminders.iter().find(|r| r.id != recurring.id).unwrap();
        assert!(!next.notified);
        assert!(next.remind_at > recurring.remind_at);
    }

    #[tokio::test]
    async fn check_and_trigger_skips_future_reminders() {
        let repo = Arc::new(MockReminderRepository::new());
        let sender = Arc::new(TestNotificationSender::default());
        let notification_service = Arc::new(NotificationService::new(repo.clone(), sender.clone()));
        let scheduler = ReminderScheduler::new(repo.clone(), notification_service);

        let future = reminder("Future", Utc::now() + ChronoDuration::hours(1), None);
        repo.add_reminder(future.clone());

        scheduler.check_and_trigger_reminders().await.unwrap();

        assert!(sender.sent.lock().unwrap().is_empty());

        let unchanged = repo.find_by_id(future.id).await.unwrap().unwrap();
        assert!(!unchanged.notified);
    }

    #[tokio::test]
    async fn check_and_trigger_skips_already_notified() {
        let repo = Arc::new(MockReminderRepository::new());
        let sender = Arc::new(TestNotificationSender::default());
        let notification_service = Arc::new(NotificationService::new(repo.clone(), sender.clone()));
        let scheduler = ReminderScheduler::new(repo.clone(), notification_service);

        let mut notified = reminder("Notified", Utc::now() - ChronoDuration::minutes(5), None);
        notified.mark_notified();
        repo.add_reminder(notified.clone());

        scheduler.check_and_trigger_reminders().await.unwrap();

        assert!(sender.sent.lock().unwrap().is_empty());
    }
}
