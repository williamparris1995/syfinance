use crate::domain::value_objects::SyncMetadata;
use chrono::{DateTime, Duration, Months, Timelike, Utc};
use serde::{Deserialize, Serialize};
use std::{error::Error, fmt};
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ReminderType {
    DebtPayment,
    BillDue,
    Custom,
}

impl ReminderType {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::DebtPayment => "debt_payment",
            Self::BillDue => "bill_due",
            Self::Custom => "custom",
        }
    }

    #[allow(clippy::should_implement_trait)]
    pub fn from_str(s: &str) -> Result<Self, ReminderError> {
        match s {
            "debt_payment" => Ok(Self::DebtPayment),
            "bill_due" => Ok(Self::BillDue),
            "custom" => Ok(Self::Custom),
            _ => Err(ReminderError::InvalidReminderType(s.to_string())),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RepeatPattern {
    Daily,
    Weekly,
    Monthly,
    Yearly,
}

impl RepeatPattern {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Daily => "daily",
            Self::Weekly => "weekly",
            Self::Monthly => "monthly",
            Self::Yearly => "yearly",
        }
    }

    #[allow(clippy::should_implement_trait)]
    pub fn from_str(s: &str) -> Result<Self, ReminderError> {
        match s {
            "daily" => Ok(Self::Daily),
            "weekly" => Ok(Self::Weekly),
            "monthly" => Ok(Self::Monthly),
            "yearly" => Ok(Self::Yearly),
            _ => Err(ReminderError::InvalidRepeatPattern(s.to_string())),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Priority {
    Low,
    Normal,
    High,
    Urgent,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ReminderError {
    EmptyTitle,
    InvalidReminderType(String),
    InvalidRepeatPattern(String),
    InvalidPriority(String),
    RemindAtInPast(DateTime<Utc>),
}

impl fmt::Display for ReminderError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyTitle => write!(f, "title cannot be empty"),
            Self::InvalidReminderType(t) => write!(f, "invalid reminder type: {t}"),
            Self::InvalidRepeatPattern(p) => write!(f, "invalid repeat pattern: {p}"),
            Self::InvalidPriority(p) => write!(f, "invalid priority: {p}"),
            Self::RemindAtInPast(dt) => write!(f, "remind_at cannot be in the past: {dt}"),
        }
    }
}

impl Error for ReminderError {}

#[derive(Debug, Clone)]
pub struct Reminder {
    pub id: Uuid,
    pub reminder_type: ReminderType,
    pub related_entity_id: Option<Uuid>,
    pub title: String,
    pub description: String,
    pub remind_at: DateTime<Utc>,
    pub repeat_pattern: Option<RepeatPattern>,
    pub notified: bool,
    pub priority: Priority,
    pub last_notified_at: Option<DateTime<Utc>>,
    pub notification_count: u32,
    pub os_task_id: Option<String>,
    pub sync_metadata: SyncMetadata,
}

impl Reminder {
    #[allow(clippy::too_many_arguments)]
    pub fn create(
        id: Uuid,
        reminder_type: ReminderType,
        related_entity_id: Option<Uuid>,
        title: impl Into<String>,
        description: impl Into<String>,
        remind_at: DateTime<Utc>,
        repeat_pattern: Option<RepeatPattern>,
        priority: Priority,
        sync_metadata: SyncMetadata,
    ) -> Result<Self, ReminderError> {
        let title = title.into().trim().to_string();
        let description = description.into().trim().to_string();

        if title.is_empty() {
            return Err(ReminderError::EmptyTitle);
        }

        Ok(Self {
            id,
            reminder_type,
            related_entity_id,
            title,
            description,
            remind_at,
            repeat_pattern,
            notified: false,
            priority,
            last_notified_at: None,
            notification_count: 0,
            os_task_id: None,
            sync_metadata,
        })
    }

    pub fn should_trigger_now(&self) -> bool {
        if self.notified {
            return false;
        }

        let now = Utc::now();
        self.remind_at <= now
    }

    pub fn mark_notified(&mut self) {
        self.notified = true;
        self.last_notified_at = Some(Utc::now());
        self.notification_count += 1;
        self.touch();
    }

    pub fn set_os_task_id(&mut self, task_id: String) {
        self.os_task_id = Some(task_id);
    }

    pub fn should_notify(&self) -> bool {
        // Check if 24 hours have passed since last notification
        match self.last_notified_at {
            None => true,
            Some(last) => {
                let now = Utc::now();
                let duration = now.signed_duration_since(last);
                duration.num_hours() >= 24
            }
        }
    }

    pub fn calculate_next_occurrence(&self) -> Option<DateTime<Utc>> {
        let pattern = self.repeat_pattern.as_ref()?;

        match pattern {
            RepeatPattern::Daily => Some(self.remind_at + Duration::days(1)),
            RepeatPattern::Weekly => Some(self.remind_at + Duration::weeks(1)),
            RepeatPattern::Monthly => {
                let date = self.remind_at.date_naive();
                let next_month = date.checked_add_months(Months::new(1))?;
                Some(
                    next_month
                        .and_hms_opt(
                            self.remind_at.hour(),
                            self.remind_at.minute(),
                            self.remind_at.second(),
                        )?
                        .and_utc(),
                )
            }
            RepeatPattern::Yearly => {
                let date = self.remind_at.date_naive();
                let next_year = date.checked_add_months(Months::new(12))?;
                Some(
                    next_year
                        .and_hms_opt(
                            self.remind_at.hour(),
                            self.remind_at.minute(),
                            self.remind_at.second(),
                        )?
                        .and_utc(),
                )
            }
        }
    }

    fn touch(&mut self) {
        self.sync_metadata.updated_at = Utc::now();
        self.sync_metadata.synced_at = None;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn metadata() -> SyncMetadata {
        SyncMetadata::new(Uuid::new_v4())
    }

    fn future_time() -> DateTime<Utc> {
        Utc::now() + Duration::hours(1)
    }

    fn past_time() -> DateTime<Utc> {
        Utc::now() - Duration::hours(1)
    }

    mod reminder_type {
        use super::*;

        #[test]
        fn converts_to_string() {
            assert_eq!(ReminderType::DebtPayment.as_str(), "debt_payment");
            assert_eq!(ReminderType::BillDue.as_str(), "bill_due");
            assert_eq!(ReminderType::Custom.as_str(), "custom");
        }

        #[test]
        fn parses_from_string() {
            assert_eq!(
                ReminderType::from_str("debt_payment").unwrap(),
                ReminderType::DebtPayment
            );
            assert_eq!(
                ReminderType::from_str("bill_due").unwrap(),
                ReminderType::BillDue
            );
            assert_eq!(
                ReminderType::from_str("custom").unwrap(),
                ReminderType::Custom
            );
        }

        #[test]
        fn rejects_invalid_type() {
            assert!(ReminderType::from_str("invalid").is_err());
        }
    }

    mod repeat_pattern {
        use super::*;

        #[test]
        fn converts_to_string() {
            assert_eq!(RepeatPattern::Daily.as_str(), "daily");
            assert_eq!(RepeatPattern::Weekly.as_str(), "weekly");
            assert_eq!(RepeatPattern::Monthly.as_str(), "monthly");
            assert_eq!(RepeatPattern::Yearly.as_str(), "yearly");
        }

        #[test]
        fn parses_from_string() {
            assert_eq!(
                RepeatPattern::from_str("daily").unwrap(),
                RepeatPattern::Daily
            );
            assert_eq!(
                RepeatPattern::from_str("weekly").unwrap(),
                RepeatPattern::Weekly
            );
            assert_eq!(
                RepeatPattern::from_str("monthly").unwrap(),
                RepeatPattern::Monthly
            );
            assert_eq!(
                RepeatPattern::from_str("yearly").unwrap(),
                RepeatPattern::Yearly
            );
        }

        #[test]
        fn rejects_invalid_pattern() {
            assert!(RepeatPattern::from_str("hourly").is_err());
        }
    }

    mod validation {
        use super::*;

        #[test]
        fn rejects_empty_title() {
            let result = Reminder::create(
                Uuid::new_v4(),
                ReminderType::Custom,
                None,
                "  ",
                "Description",
                future_time(),
                None,
                Priority::Normal,
                metadata(),
            );

            assert!(matches!(result, Err(ReminderError::EmptyTitle)));
        }

        #[test]
        fn trims_title_and_description() {
            let reminder = Reminder::create(
                Uuid::new_v4(),
                ReminderType::Custom,
                None,
                "  Test Title  ",
                "  Test Description  ",
                future_time(),
                None,
                Priority::Normal,
                metadata(),
            )
            .unwrap();

            assert_eq!(reminder.title, "Test Title");
            assert_eq!(reminder.description, "Test Description");
        }

        #[test]
        fn creates_valid_reminder() {
            let id = Uuid::new_v4();
            let related_id = Uuid::new_v4();
            let remind_at = future_time();

            let reminder = Reminder::create(
                id,
                ReminderType::DebtPayment,
                Some(related_id),
                "Payment Due",
                "Monthly payment",
                remind_at,
                Some(RepeatPattern::Monthly),
                Priority::High,
                metadata(),
            )
            .unwrap();

            assert_eq!(reminder.id, id);
            assert_eq!(reminder.reminder_type, ReminderType::DebtPayment);
            assert_eq!(reminder.related_entity_id, Some(related_id));
            assert_eq!(reminder.title, "Payment Due");
            assert_eq!(reminder.description, "Monthly payment");
            assert_eq!(reminder.remind_at, remind_at);
            assert_eq!(reminder.repeat_pattern, Some(RepeatPattern::Monthly));
            assert_eq!(reminder.priority, Priority::High);
            assert!(!reminder.notified);
            assert_eq!(reminder.notification_count, 0);
            assert!(reminder.last_notified_at.is_none());
            assert!(reminder.os_task_id.is_none());
        }
    }

    mod triggering {
        use super::*;

        #[test]
        fn should_trigger_when_time_has_passed() {
            let reminder = Reminder::create(
                Uuid::new_v4(),
                ReminderType::Custom,
                None,
                "Test",
                "",
                past_time(),
                None,
                Priority::Normal,
                metadata(),
            )
            .unwrap();

            assert!(reminder.should_trigger_now());
        }

        #[test]
        fn should_not_trigger_when_time_is_future() {
            let reminder = Reminder::create(
                Uuid::new_v4(),
                ReminderType::Custom,
                None,
                "Test",
                "",
                future_time(),
                None,
                Priority::Normal,
                metadata(),
            )
            .unwrap();

            assert!(!reminder.should_trigger_now());
        }

        #[test]
        fn should_not_trigger_when_already_notified() {
            let mut reminder = Reminder::create(
                Uuid::new_v4(),
                ReminderType::Custom,
                None,
                "Test",
                "",
                past_time(),
                None,
                Priority::Normal,
                metadata(),
            )
            .unwrap();

            reminder.mark_notified();

            assert!(!reminder.should_trigger_now());
        }

        #[test]
        fn mark_notified_updates_status_and_sync() {
            let mut reminder = Reminder::create(
                Uuid::new_v4(),
                ReminderType::Custom,
                None,
                "Test",
                "",
                past_time(),
                None,
                Priority::Normal,
                metadata(),
            )
            .unwrap();

            let original_updated_at = reminder.sync_metadata.updated_at;
            std::thread::sleep(std::time::Duration::from_millis(10));

            reminder.mark_notified();

            assert!(reminder.notified);
            assert!(reminder.sync_metadata.updated_at > original_updated_at);
            assert!(reminder.sync_metadata.synced_at.is_none());
            assert_eq!(reminder.notification_count, 1);
            assert!(reminder.last_notified_at.is_some());
        }
    }

    mod repeat_patterns {
        use super::*;
        use chrono::NaiveDate;

        #[test]
        fn daily_pattern_adds_one_day() {
            let remind_at = NaiveDate::from_ymd_opt(2026, 4, 8)
                .unwrap()
                .and_hms_opt(10, 0, 0)
                .unwrap()
                .and_utc();

            let reminder = Reminder::create(
                Uuid::new_v4(),
                ReminderType::Custom,
                None,
                "Daily",
                "",
                remind_at,
                Some(RepeatPattern::Daily),
                Priority::Normal,
                metadata(),
            )
            .unwrap();

            let next = reminder.calculate_next_occurrence().unwrap();
            let expected = NaiveDate::from_ymd_opt(2026, 4, 9)
                .unwrap()
                .and_hms_opt(10, 0, 0)
                .unwrap()
                .and_utc();

            assert_eq!(next, expected);
        }

        #[test]
        fn weekly_pattern_adds_seven_days() {
            let remind_at = NaiveDate::from_ymd_opt(2026, 4, 8)
                .unwrap()
                .and_hms_opt(10, 0, 0)
                .unwrap()
                .and_utc();

            let reminder = Reminder::create(
                Uuid::new_v4(),
                ReminderType::Custom,
                None,
                "Weekly",
                "",
                remind_at,
                Some(RepeatPattern::Weekly),
                Priority::Normal,
                metadata(),
            )
            .unwrap();

            let next = reminder.calculate_next_occurrence().unwrap();
            let expected = NaiveDate::from_ymd_opt(2026, 4, 15)
                .unwrap()
                .and_hms_opt(10, 0, 0)
                .unwrap()
                .and_utc();

            assert_eq!(next, expected);
        }

        #[test]
        fn monthly_pattern_adds_one_month() {
            let remind_at = NaiveDate::from_ymd_opt(2026, 4, 8)
                .unwrap()
                .and_hms_opt(10, 30, 0)
                .unwrap()
                .and_utc();

            let reminder = Reminder::create(
                Uuid::new_v4(),
                ReminderType::Custom,
                None,
                "Monthly",
                "",
                remind_at,
                Some(RepeatPattern::Monthly),
                Priority::Normal,
                metadata(),
            )
            .unwrap();

            let next = reminder.calculate_next_occurrence().unwrap();
            let expected = NaiveDate::from_ymd_opt(2026, 5, 8)
                .unwrap()
                .and_hms_opt(10, 30, 0)
                .unwrap()
                .and_utc();

            assert_eq!(next, expected);
        }

        #[test]
        fn yearly_pattern_adds_one_year() {
            let remind_at = NaiveDate::from_ymd_opt(2026, 4, 8)
                .unwrap()
                .and_hms_opt(10, 30, 0)
                .unwrap()
                .and_utc();

            let reminder = Reminder::create(
                Uuid::new_v4(),
                ReminderType::Custom,
                None,
                "Yearly",
                "",
                remind_at,
                Some(RepeatPattern::Yearly),
                Priority::Normal,
                metadata(),
            )
            .unwrap();

            let next = reminder.calculate_next_occurrence().unwrap();
            let expected = NaiveDate::from_ymd_opt(2027, 4, 8)
                .unwrap()
                .and_hms_opt(10, 30, 0)
                .unwrap()
                .and_utc();

            assert_eq!(next, expected);
        }

        #[test]
        fn no_repeat_pattern_returns_none() {
            let reminder = Reminder::create(
                Uuid::new_v4(),
                ReminderType::Custom,
                None,
                "One-time",
                "",
                future_time(),
                None,
                Priority::Normal,
                metadata(),
            )
            .unwrap();

            assert!(reminder.calculate_next_occurrence().is_none());
        }

        #[test]
        fn monthly_pattern_handles_month_end() {
            let remind_at = NaiveDate::from_ymd_opt(2026, 1, 31)
                .unwrap()
                .and_hms_opt(10, 0, 0)
                .unwrap()
                .and_utc();

            let reminder = Reminder::create(
                Uuid::new_v4(),
                ReminderType::Custom,
                None,
                "Monthly",
                "",
                remind_at,
                Some(RepeatPattern::Monthly),
                Priority::Normal,
                metadata(),
            )
            .unwrap();

            let next = reminder.calculate_next_occurrence().unwrap();
            let expected = NaiveDate::from_ymd_opt(2026, 2, 28)
                .unwrap()
                .and_hms_opt(10, 0, 0)
                .unwrap()
                .and_utc();

            assert_eq!(next, expected);
        }
    }

    mod priority {
        use super::*;

        #[test]
        fn converts_to_string() {
            assert_eq!(serde_json::to_string(&Priority::Low).unwrap(), "\"LOW\"");
            assert_eq!(
                serde_json::to_string(&Priority::Normal).unwrap(),
                "\"NORMAL\""
            );
            assert_eq!(serde_json::to_string(&Priority::High).unwrap(), "\"HIGH\"");
            assert_eq!(
                serde_json::to_string(&Priority::Urgent).unwrap(),
                "\"URGENT\""
            );
        }

        #[test]
        fn parses_from_string() {
            assert_eq!(
                serde_json::from_str::<Priority>("\"LOW\"").unwrap(),
                Priority::Low
            );
            assert_eq!(
                serde_json::from_str::<Priority>("\"NORMAL\"").unwrap(),
                Priority::Normal
            );
            assert_eq!(
                serde_json::from_str::<Priority>("\"HIGH\"").unwrap(),
                Priority::High
            );
            assert_eq!(
                serde_json::from_str::<Priority>("\"URGENT\"").unwrap(),
                Priority::Urgent
            );
        }

        #[test]
        fn rejects_invalid_priority() {
            assert!(serde_json::from_str::<Priority>("\"CRITICAL\"").is_err());
        }
    }

    mod notification_tracking {
        use super::*;

        #[test]
        fn mark_notified_increments_count() {
            let mut reminder = Reminder::create(
                Uuid::new_v4(),
                ReminderType::Custom,
                None,
                "Test",
                "",
                past_time(),
                None,
                Priority::Normal,
                metadata(),
            )
            .unwrap();

            assert_eq!(reminder.notification_count, 0);
            assert!(reminder.last_notified_at.is_none());

            reminder.mark_notified();

            assert_eq!(reminder.notification_count, 1);
            assert!(reminder.last_notified_at.is_some());

            reminder.mark_notified();

            assert_eq!(reminder.notification_count, 2);
        }

        #[test]
        fn should_notify_returns_true_when_never_notified() {
            let reminder = Reminder::create(
                Uuid::new_v4(),
                ReminderType::Custom,
                None,
                "Test",
                "",
                past_time(),
                None,
                Priority::Normal,
                metadata(),
            )
            .unwrap();

            assert!(reminder.should_notify());
        }

        #[test]
        fn should_notify_returns_false_within_24_hours() {
            let mut reminder = Reminder::create(
                Uuid::new_v4(),
                ReminderType::Custom,
                None,
                "Test",
                "",
                past_time(),
                None,
                Priority::Normal,
                metadata(),
            )
            .unwrap();

            reminder.mark_notified();

            assert!(!reminder.should_notify());
        }

        #[test]
        fn should_notify_returns_true_after_24_hours() {
            let mut reminder = Reminder::create(
                Uuid::new_v4(),
                ReminderType::Custom,
                None,
                "Test",
                "",
                past_time(),
                None,
                Priority::Normal,
                metadata(),
            )
            .unwrap();

            // Simulate notification 25 hours ago
            reminder.last_notified_at = Some(Utc::now() - Duration::hours(25));

            assert!(reminder.should_notify());
        }

        #[test]
        fn set_os_task_id_stores_value() {
            let mut reminder = Reminder::create(
                Uuid::new_v4(),
                ReminderType::Custom,
                None,
                "Test",
                "",
                future_time(),
                None,
                Priority::Normal,
                metadata(),
            )
            .unwrap();

            assert!(reminder.os_task_id.is_none());

            reminder.set_os_task_id("task-123".to_string());

            assert_eq!(reminder.os_task_id, Some("task-123".to_string()));
        }
    }
}
