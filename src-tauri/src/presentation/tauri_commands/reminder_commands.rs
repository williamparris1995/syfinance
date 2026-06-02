use crate::domain::aggregates::reminder::Priority;
use crate::domain::aggregates::{Reminder, ReminderType, RepeatPattern};
use crate::domain::repositories::ReminderRepository;
use crate::domain::value_objects::SyncMetadata;
use crate::infrastructure::repositories::SqliteReminderRepository;
use serde::{Deserialize, Serialize};
use sqlx::sqlite::SqlitePool;
use std::str::FromStr;
use std::sync::Arc;
use tauri::State;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReminderDto {
    pub id: String,
    pub reminder_type: String,
    pub related_entity_id: Option<String>,
    pub title: String,
    pub description: String,
    pub remind_at: String,
    pub repeat_pattern: Option<String>,
    pub priority: String,
    pub notified: bool,
    pub last_notified_at: Option<String>,
    pub notification_count: u32,
}

impl From<Reminder> for ReminderDto {
    fn from(r: Reminder) -> Self {
        Self {
            id: r.id.to_string(),
            reminder_type: r.reminder_type.as_str().to_string(),
            related_entity_id: r.related_entity_id.map(|id| id.to_string()),
            title: r.title,
            description: r.description,
            remind_at: r.remind_at.to_rfc3339(),
            repeat_pattern: r.repeat_pattern.as_ref().map(|p| p.as_str().to_string()),
            priority: serde_json::to_string(&r.priority)
                .unwrap_or_else(|_| "\"NORMAL\"".to_string())
                .trim_matches('"')
                .to_string(),
            notified: r.notified,
            last_notified_at: r.last_notified_at.map(|dt| dt.to_rfc3339()),
            notification_count: r.notification_count,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateReminderDto {
    pub title: String,
    pub description: Option<String>,
    pub reminder_type: Option<String>,
    pub related_entity_id: Option<String>,
    pub remind_at: String,
    pub repeat_pattern: Option<String>,
    pub priority: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateReminderDto {
    pub title: Option<String>,
    pub description: Option<String>,
    pub remind_at: Option<String>,
    pub repeat_pattern: Option<String>,
    pub priority: Option<String>,
}

pub struct ReminderCommandState {
    #[allow(dead_code)]
    pool: SqlitePool,
    reminder_repository: Arc<SqliteReminderRepository>,
}

impl ReminderCommandState {
    pub fn from_pool(pool: SqlitePool) -> Self {
        Self {
            reminder_repository: Arc::new(SqliteReminderRepository::new(pool.clone())),
            pool,
        }
    }

    pub fn repository(&self) -> &SqliteReminderRepository {
        self.reminder_repository.as_ref()
    }

    // TODO: will be used when reminder commands need direct pool access
    #[allow(dead_code)]
    pub fn pool(&self) -> &SqlitePool {
        &self.pool
    }
}

pub async fn create_reminder_default_state_from_pool(
    pool: SqlitePool,
) -> sqlx::Result<ReminderCommandState> {
    Ok(ReminderCommandState::from_pool(pool))
}

#[tauri::command]
pub async fn list_reminders(
    state: State<'_, ReminderCommandState>,
) -> Result<Vec<ReminderDto>, String> {
    state
        .repository()
        .find_all()
        .await
        .map(|reminders| reminders.into_iter().map(ReminderDto::from).collect())
        .map_err(|e| format!("Failed to list reminders: {}", e))
}

#[tauri::command]
pub async fn get_reminder(
    state: State<'_, ReminderCommandState>,
    id: String,
) -> Result<ReminderDto, String> {
    let id = Uuid::parse_str(&id).map_err(|e| format!("Invalid ID: {}", e))?;
    state
        .repository()
        .find_by_id(id)
        .await
        .map_err(|e| format!("Failed to get reminder: {}", e))?
        .map(ReminderDto::from)
        .ok_or_else(|| "Reminder not found".to_string())
}

#[tauri::command]
pub async fn create_reminder(
    state: State<'_, ReminderCommandState>,
    dto: CreateReminderDto,
) -> Result<ReminderDto, String> {
    let reminder_type = match dto.reminder_type.as_deref() {
        Some("debt_payment") => ReminderType::DebtPayment,
        Some("bill_due") => ReminderType::BillDue,
        Some("prepaid_low_balance") => ReminderType::PrepaidLowBalance,
        _ => ReminderType::Custom,
    };

    let related_entity_id = dto
        .related_entity_id
        .map(|s| Uuid::parse_str(&s))
        .transpose()
        .map_err(|e| format!("Invalid related entity ID: {}", e))?;

    let remind_at = chrono::DateTime::parse_from_rfc3339(&dto.remind_at)
        .map_err(|e| format!("Invalid remind_at datetime: {}", e))?
        .with_timezone(&chrono::Utc);

    let repeat_pattern = dto
        .repeat_pattern
        .as_deref()
        .map(RepeatPattern::from_str)
        .transpose()
        .map_err(|e| format!("Invalid repeat pattern: {}", e))?;

    let priority = match dto.priority.as_deref() {
        Some(p) => serde_json::from_str::<Priority>(&format!("\"{}\"", p))
            .map_err(|e| format!("Invalid priority: {}", e))?,
        None => Priority::Normal,
    };

    let id = Uuid::new_v4();
    let device_id = Uuid::new_v4();
    let sync_metadata = SyncMetadata::new(device_id);

    let reminder = Reminder::create(
        id,
        reminder_type,
        related_entity_id,
        dto.title,
        dto.description.unwrap_or_default(),
        remind_at,
        repeat_pattern,
        priority,
        sync_metadata,
    )
    .map_err(|e| e.to_string())?;

    state
        .repository()
        .create(&reminder)
        .await
        .map_err(|e| format!("Failed to create reminder: {}", e))?;

    Ok(ReminderDto::from(reminder))
}

#[tauri::command]
pub async fn update_reminder(
    state: State<'_, ReminderCommandState>,
    id: String,
    dto: UpdateReminderDto,
) -> Result<ReminderDto, String> {
    let uuid = Uuid::parse_str(&id).map_err(|e| format!("Invalid ID: {}", e))?;

    let mut reminder = state
        .repository()
        .find_by_id(uuid)
        .await
        .map_err(|e| format!("Failed to get reminder: {}", e))?
        .ok_or_else(|| "Reminder not found".to_string())?;

    if let Some(title) = dto.title {
        reminder.title = title;
    }
    if let Some(description) = dto.description {
        reminder.description = description;
    }
    if let Some(remind_at_str) = dto.remind_at {
        reminder.remind_at = chrono::DateTime::parse_from_rfc3339(&remind_at_str)
            .map_err(|e| format!("Invalid remind_at datetime: {}", e))?
            .with_timezone(&chrono::Utc);
    }
    if let Some(pattern_str) = dto.repeat_pattern {
        reminder.repeat_pattern = if pattern_str.is_empty() {
            None
        } else {
            Some(
                RepeatPattern::from_str(&pattern_str)
                    .map_err(|e| format!("Invalid repeat pattern: {}", e))?,
            )
        };
    }
    if let Some(priority_str) = dto.priority {
        reminder.priority = serde_json::from_str::<Priority>(&format!("\"{}\"", priority_str))
            .map_err(|e| format!("Invalid priority: {}", e))?;
    }

    reminder.sync_metadata.updated_at = chrono::Utc::now();
    reminder.sync_metadata.synced_at = None;

    state
        .repository()
        .update(&reminder)
        .await
        .map_err(|e| format!("Failed to update reminder: {}", e))?;

    Ok(ReminderDto::from(reminder))
}

#[tauri::command]
pub async fn delete_reminder(
    state: State<'_, ReminderCommandState>,
    id: String,
) -> Result<(), String> {
    let id = Uuid::parse_str(&id).map_err(|e| format!("Invalid ID: {}", e))?;
    state
        .repository()
        .soft_delete(id)
        .await
        .map_err(|e| format!("Failed to delete reminder: {}", e))?;
    Ok(())
}

#[tauri::command]
pub async fn complete_reminder(
    state: State<'_, ReminderCommandState>,
    id: String,
) -> Result<(), String> {
    let uuid = Uuid::parse_str(&id).map_err(|e| format!("Invalid ID: {}", e))?;

    let mut reminder = state
        .repository()
        .find_by_id(uuid)
        .await
        .map_err(|e| format!("Failed to get reminder: {}", e))?
        .ok_or_else(|| "Reminder not found".to_string())?;

    reminder.mark_notified();

    state
        .repository()
        .update(&reminder)
        .await
        .map_err(|e| format!("Failed to complete reminder: {}", e))?;

    Ok(())
}
