use crate::domain::aggregates::goal::{Goal, GoalType};
use crate::domain::repositories::GoalRepository;
use crate::infrastructure::repositories::SqliteGoalRepository;
use chrono::NaiveDate;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use sqlx::sqlite::SqlitePool;
use std::str::FromStr;
use std::sync::Arc;
use tauri::State;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GoalDto {
    pub id: String,
    pub name: String,
    pub goal_type: String,
    pub target_amount: String,
    pub current_amount: String,
    pub progress_percentage: f64,
    pub remaining_amount: String,
    pub currency_code: String,
    pub deadline: Option<String>,
    pub linked_account_id: Option<String>,
    pub notes: Option<String>,
    pub is_completed: bool,
    pub is_overdue: bool,
    pub completed_at: Option<String>,
}

impl From<Goal> for GoalDto {
    fn from(goal: Goal) -> Self {
        // Compute borrowed values before moving owned fields
        let progress_percentage = goal.progress_percentage();
        let remaining_amount = goal.remaining_amount().to_string();
        let is_overdue = goal.is_overdue();

        Self {
            id: goal.id,
            name: goal.name,
            goal_type: goal.goal_type.as_str().to_string(),
            target_amount: goal.target_amount.to_string(),
            current_amount: goal.current_amount.to_string(),
            progress_percentage,
            remaining_amount,
            currency_code: goal.currency_code,
            deadline: goal.deadline.map(|d| d.to_string()),
            linked_account_id: goal.linked_account_id,
            notes: goal.notes,
            is_completed: goal.is_completed,
            is_overdue,
            completed_at: goal.completed_at,
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct CreateGoalDto {
    pub name: String,
    pub goal_type: String,
    pub target_amount: String,
    pub currency_code: String,
    pub deadline: Option<String>,
    pub linked_account_id: Option<String>,
    pub notes: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateGoalDto {
    pub name: Option<String>,
    pub goal_type: Option<String>,
    pub target_amount: Option<String>,
    pub currency_code: Option<String>,
    pub deadline: Option<String>,
    pub linked_account_id: Option<String>,
    pub notes: Option<String>,
}

pub struct GoalCommandState {
    pool: SqlitePool,
    goal_repository: Arc<SqliteGoalRepository>,
}

impl GoalCommandState {
    pub fn from_pool(pool: SqlitePool) -> Self {
        Self {
            goal_repository: Arc::new(SqliteGoalRepository::new(pool.clone())),
            pool,
        }
    }

    pub fn repository(&self) -> &SqliteGoalRepository {
        self.goal_repository.as_ref()
    }

    pub fn pool(&self) -> &SqlitePool {
        &self.pool
    }
}

pub async fn create_default_state_from_pool(
    pool: SqlitePool,
) -> sqlx::Result<GoalCommandState> {
    Ok(GoalCommandState::from_pool(pool))
}

#[tauri::command]
pub async fn list_goals(
    state: State<'_, GoalCommandState>,
) -> Result<Vec<GoalDto>, String> {
    state
        .repository()
        .find_all()
        .await
        .map(|goals| goals.into_iter().map(GoalDto::from).collect())
        .map_err(|e| format!("Failed to list goals: {}", e))
}

#[tauri::command]
pub async fn get_goal(
    state: State<'_, GoalCommandState>,
    id: String,
) -> Result<Option<GoalDto>, String> {
    state
        .repository()
        .find_by_id(&id)
        .await
        .map(|opt| opt.map(GoalDto::from))
        .map_err(|e| format!("Failed to get goal: {}", e))
}

#[tauri::command]
pub async fn create_goal(
    state: State<'_, GoalCommandState>,
    dto: CreateGoalDto,
) -> Result<GoalDto, String> {
    let id = uuid::Uuid::new_v4().to_string();
    let target_amount = Decimal::from_str(&dto.target_amount)
        .map_err(|_| "Invalid target amount".to_string())?;
    let goal_type = GoalType::from_str(&dto.goal_type);

    let mut goal = Goal::new(id, dto.name, goal_type, target_amount, dto.currency_code);

    if let Some(deadline_str) = dto.deadline {
        let deadline = NaiveDate::parse_from_str(&deadline_str, "%Y-%m-%d")
            .map_err(|_| "Invalid deadline date".to_string())?;
        goal.set_deadline(deadline);
    }

    if let Some(account_id) = dto.linked_account_id {
        goal.link_account(account_id);
    }

    goal.notes = dto.notes;

    state
        .repository()
        .create(&goal)
        .await
        .map_err(|e| format!("Failed to create goal: {}", e))?;

    Ok(GoalDto::from(goal))
}

#[tauri::command]
pub async fn update_goal(
    state: State<'_, GoalCommandState>,
    id: String,
    dto: UpdateGoalDto,
) -> Result<GoalDto, String> {
    let mut goal = state
        .repository()
        .find_by_id(&id)
        .await
        .map_err(|e| format!("Failed to get goal: {}", e))?
        .ok_or_else(|| "Goal not found".to_string())?;

    if let Some(name) = dto.name {
        goal.name = name;
    }
    if let Some(goal_type_str) = dto.goal_type {
        goal.goal_type = GoalType::from_str(&goal_type_str);
    }
    if let Some(target_amount_str) = dto.target_amount {
        goal.target_amount = Decimal::from_str(&target_amount_str)
            .map_err(|_| "Invalid target amount".to_string())?;
    }
    if let Some(currency_code) = dto.currency_code {
        goal.currency_code = currency_code;
    }
    if let Some(deadline_str) = dto.deadline {
        if deadline_str.is_empty() {
            goal.deadline = None;
        } else {
            let deadline = NaiveDate::parse_from_str(&deadline_str, "%Y-%m-%d")
                .map_err(|_| "Invalid deadline date".to_string())?;
            goal.deadline = Some(deadline);
        }
    }
    if let Some(account_id) = dto.linked_account_id {
        if account_id.is_empty() {
            goal.linked_account_id = None;
        } else {
            goal.linked_account_id = Some(account_id);
        }
    }
    if let Some(notes) = dto.notes {
        goal.notes = if notes.is_empty() { None } else { Some(notes) };
    }

    state
        .repository()
        .update(&goal)
        .await
        .map_err(|e| format!("Failed to update goal: {}", e))?;

    Ok(GoalDto::from(goal))
}

#[tauri::command]
pub async fn update_goal_progress(
    state: State<'_, GoalCommandState>,
    id: String,
    amount: String,
) -> Result<GoalDto, String> {
    let amount = Decimal::from_str(&amount)
        .map_err(|_| "Invalid amount".to_string())?;

    state
        .repository()
        .add_progress(&id, amount)
        .await
        .map_err(|e| format!("Failed to update progress: {}", e))?;

    let goal = state
        .repository()
        .find_by_id(&id)
        .await
        .map_err(|e| format!("Failed to get goal: {}", e))?
        .ok_or_else(|| "Goal not found".to_string())?;

    // Auto-complete if target reached
    if !goal.is_completed && goal.current_amount >= goal.target_amount {
        let mut goal = goal;
        goal.mark_completed();
        state
            .repository()
            .update(&goal)
            .await
            .map_err(|e| format!("Failed to complete goal: {}", e))?;
        return Ok(GoalDto::from(goal));
    }

    Ok(GoalDto::from(goal))
}

#[tauri::command]
pub async fn complete_goal(
    state: State<'_, GoalCommandState>,
    id: String,
) -> Result<GoalDto, String> {
    let mut goal = state
        .repository()
        .find_by_id(&id)
        .await
        .map_err(|e| format!("Failed to get goal: {}", e))?
        .ok_or_else(|| "Goal not found".to_string())?;

    goal.mark_completed();

    state
        .repository()
        .update(&goal)
        .await
        .map_err(|e| format!("Failed to complete goal: {}", e))?;

    Ok(GoalDto::from(goal))
}

#[tauri::command]
pub async fn delete_goal(
    state: State<'_, GoalCommandState>,
    id: String,
) -> Result<(), String> {
    state
        .repository()
        .delete(&id)
        .await
        .map_err(|e| format!("Failed to delete goal: {}", e))
}
