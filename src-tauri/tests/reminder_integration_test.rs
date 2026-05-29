use async_trait::async_trait;
use chrono::{Duration, Utc};
use finance_app::domain::aggregates::reminder::Priority;
use finance_app::domain::aggregates::{Reminder, ReminderType, RepeatPattern};
use finance_app::domain::repositories::ReminderRepository;
use finance_app::domain::value_objects::SyncMetadata;
use finance_app::infrastructure::notifications::{NotificationSender, NotificationService};
use finance_app::infrastructure::reminders::ReminderScheduler;
use std::sync::{Arc, Mutex};
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

    fn count_notified(&self) -> usize {
        self.reminders
            .lock()
            .unwrap()
            .iter()
            .filter(|r| r.notified)
            .count()
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
            .filter(|r| {
                r.remind_at <= before && !r.notified && r.sync_metadata.deleted_at.is_none()
            })
            .cloned()
            .collect())
    }

    async fn find_by_related_entity(&self, related_entity_id: Uuid) -> sqlx::Result<Vec<Reminder>> {
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

impl TestNotificationSender {
    fn sent_count(&self) -> usize {
        self.sent.lock().unwrap().len()
    }

    fn was_sent(&self, id: Uuid) -> bool {
        self.sent.lock().unwrap().contains(&id)
    }
}

#[async_trait]
impl NotificationSender for TestNotificationSender {
    async fn send(
        &self,
        reminder: &Reminder,
    ) -> Result<(), finance_app::infrastructure::notifications::NotificationError> {
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
        Priority::Normal,
        metadata(),
    )
    .unwrap()
}

#[tokio::test]
async fn reminder_integration_triggers_notification_for_due_reminder() {
    let repo = Arc::new(MockReminderRepository::new());
    let sender = Arc::new(TestNotificationSender::default());
    let notification_service = Arc::new(NotificationService::new(repo.clone(), sender.clone()));
    let scheduler = ReminderScheduler::new(repo.clone(), notification_service);

    let past_reminder = reminder("Payment Due", Utc::now() - Duration::minutes(5), None);
    let reminder_id = past_reminder.id;
    repo.add_reminder(past_reminder);

    scheduler
        .check_and_trigger_reminders()
        .await
        .expect("check should succeed");

    assert!(sender.was_sent(reminder_id), "notification should be sent");

    let updated = repo
        .find_by_id(reminder_id)
        .await
        .expect("find should succeed")
        .expect("reminder should exist");
    assert!(updated.notified, "reminder should be marked as notified");
}

#[tokio::test]
async fn reminder_integration_creates_next_occurrence_for_recurring() {
    let repo = Arc::new(MockReminderRepository::new());
    let sender = Arc::new(TestNotificationSender::default());
    let notification_service = Arc::new(NotificationService::new(repo.clone(), sender.clone()));
    let scheduler = ReminderScheduler::new(repo.clone(), notification_service);

    let start_time = Utc::now() - Duration::minutes(1);
    let recurring = reminder("Monthly Payment", start_time, Some(RepeatPattern::Monthly));
    let original_id = recurring.id;
    repo.add_reminder(recurring);

    scheduler
        .check_and_trigger_reminders()
        .await
        .expect("first check should succeed");

    let all_reminders = repo.get_all();
    assert_eq!(
        all_reminders.len(),
        2,
        "should have original and next occurrence"
    );

    let original = all_reminders
        .iter()
        .find(|r| r.id == original_id)
        .expect("original should exist");
    assert!(original.notified, "original should be notified");

    let next = all_reminders
        .iter()
        .find(|r| r.id != original_id)
        .expect("next occurrence should exist");
    assert!(!next.notified, "next occurrence should not be notified");
    assert!(
        next.remind_at > start_time,
        "next occurrence should be in future"
    );

    scheduler
        .check_and_trigger_reminders()
        .await
        .expect("second check should succeed");

    assert_eq!(
        sender.sent_count(),
        1,
        "should only send one notification (next is in future)"
    );
}

#[tokio::test]
async fn reminder_integration_skips_future_reminders() {
    let repo = Arc::new(MockReminderRepository::new());
    let sender = Arc::new(TestNotificationSender::default());
    let notification_service = Arc::new(NotificationService::new(repo.clone(), sender.clone()));
    let scheduler = ReminderScheduler::new(repo.clone(), notification_service);

    let future = reminder("Future Reminder", Utc::now() + Duration::hours(2), None);
    let reminder_id = future.id;
    repo.add_reminder(future);

    scheduler
        .check_and_trigger_reminders()
        .await
        .expect("check should succeed");

    assert_eq!(sender.sent_count(), 0, "no notifications should be sent");

    let unchanged = repo
        .find_by_id(reminder_id)
        .await
        .expect("find should succeed")
        .expect("reminder should exist");
    assert!(!unchanged.notified, "reminder should not be notified");
}

#[tokio::test]
async fn reminder_integration_skips_already_notified() {
    let repo = Arc::new(MockReminderRepository::new());
    let sender = Arc::new(TestNotificationSender::default());
    let notification_service = Arc::new(NotificationService::new(repo.clone(), sender.clone()));
    let scheduler = ReminderScheduler::new(repo.clone(), notification_service);

    let mut notified = reminder("Already Notified", Utc::now() - Duration::minutes(10), None);
    notified.mark_notified();
    repo.add_reminder(notified);

    scheduler
        .check_and_trigger_reminders()
        .await
        .expect("check should succeed");

    assert_eq!(
        sender.sent_count(),
        0,
        "no notifications should be sent for already notified reminders"
    );
}

#[tokio::test]
async fn reminder_integration_handles_multiple_due_reminders() {
    let repo = Arc::new(MockReminderRepository::new());
    let sender = Arc::new(TestNotificationSender::default());
    let notification_service = Arc::new(NotificationService::new(repo.clone(), sender.clone()));
    let scheduler = ReminderScheduler::new(repo.clone(), notification_service);

    let reminder1 = reminder("Reminder 1", Utc::now() - Duration::minutes(5), None);
    let reminder2 = reminder("Reminder 2", Utc::now() - Duration::minutes(3), None);
    let reminder3 = reminder("Reminder 3", Utc::now() - Duration::minutes(1), None);

    let id1 = reminder1.id;
    let id2 = reminder2.id;
    let id3 = reminder3.id;

    repo.add_reminder(reminder1);
    repo.add_reminder(reminder2);
    repo.add_reminder(reminder3);

    scheduler
        .check_and_trigger_reminders()
        .await
        .expect("check should succeed");

    assert_eq!(sender.sent_count(), 3, "all three reminders should be sent");
    assert!(sender.was_sent(id1));
    assert!(sender.was_sent(id2));
    assert!(sender.was_sent(id3));

    assert_eq!(repo.count_notified(), 3, "all should be marked as notified");
}
