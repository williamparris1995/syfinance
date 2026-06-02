use crate::application::services::goal_service::GoalService;
use crate::domain::aggregates::goal::Goal;
use crate::infrastructure::repositories::{SqliteAccountRepository, SqliteGoalRepository};
use serde::{Deserialize, Serialize};
use sqlx::sqlite::SqlitePool;
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
    service: Arc<GoalService>,
}

impl GoalCommandState {
    pub fn from_pool(pool: SqlitePool) -> Self {
        let goal_repo = Arc::new(SqliteGoalRepository::new(pool.clone()));
        let account_repo = Arc::new(SqliteAccountRepository::new(pool.clone()));
        let service = Arc::new(GoalService::new(goal_repo, account_repo, pool));
        Self { service }
    }

    pub fn service(&self) -> &GoalService {
        self.service.as_ref()
    }
}

pub async fn create_default_state_from_pool(pool: SqlitePool) -> sqlx::Result<GoalCommandState> {
    Ok(GoalCommandState::from_pool(pool))
}

#[tauri::command]
pub async fn list_goals(state: State<'_, GoalCommandState>) -> Result<Vec<GoalDto>, String> {
    state
        .service()
        .list_goals()
        .await
        .map(|goals| goals.into_iter().map(GoalDto::from).collect())
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn get_goal(
    state: State<'_, GoalCommandState>,
    id: String,
) -> Result<Option<GoalDto>, String> {
    state
        .service()
        .get_goal(&id)
        .await
        .map(|opt| opt.map(GoalDto::from))
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn create_goal(
    state: State<'_, GoalCommandState>,
    dto: CreateGoalDto,
) -> Result<GoalDto, String> {
    state
        .service()
        .create_goal(
            dto.name,
            dto.goal_type,
            dto.target_amount,
            dto.currency_code,
            dto.deadline,
            dto.linked_account_id,
            dto.notes,
        )
        .await
        .map(GoalDto::from)
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn update_goal(
    state: State<'_, GoalCommandState>,
    id: String,
    dto: UpdateGoalDto,
) -> Result<GoalDto, String> {
    state
        .service()
        .update_goal(
            &id,
            dto.name,
            dto.goal_type,
            dto.target_amount,
            dto.currency_code,
            dto.deadline,
            dto.linked_account_id,
            dto.notes,
        )
        .await
        .map(GoalDto::from)
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn update_goal_progress(
    state: State<'_, GoalCommandState>,
    id: String,
    amount: String,
) -> Result<GoalDto, String> {
    state
        .service()
        .update_goal_progress(&id, amount)
        .await
        .map(GoalDto::from)
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn complete_goal(
    state: State<'_, GoalCommandState>,
    id: String,
) -> Result<GoalDto, String> {
    state
        .service()
        .complete_goal(&id)
        .await
        .map(GoalDto::from)
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn delete_goal(state: State<'_, GoalCommandState>, id: String) -> Result<(), String> {
    state
        .service()
        .delete_goal(&id)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn sync_goal_progress(
    state: State<'_, GoalCommandState>,
    goal_id: String,
) -> Result<GoalDto, String> {
    state
        .service()
        .sync_goal_progress(&goal_id)
        .await
        .map(GoalDto::from)
        .map_err(|e| e.to_string())
}
