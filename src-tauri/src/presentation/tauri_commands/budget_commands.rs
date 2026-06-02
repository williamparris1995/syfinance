use crate::application::services::budget_service::BudgetService;
use crate::domain::aggregates::budget::Budget;
use crate::infrastructure::repositories::SqliteBudgetRepository;
use serde::{Deserialize, Serialize};
use sqlx::sqlite::SqlitePool;
use std::sync::Arc;
use tauri::State;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BudgetDto {
    pub id: String,
    pub name: String,
    pub month: String,
    pub total_amount: String,
    pub total_actual: String,
    pub total_remaining: String,
    pub usage_percentage: f64,
    pub currency_code: String,
    pub is_active: bool,
    pub items: Vec<BudgetItemDto>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BudgetItemDto {
    pub id: String,
    pub category_account_id: String,
    pub planned_amount: String,
    pub actual_amount: String,
    pub remaining: String,
    pub usage_percentage: f64,
    pub is_over_budget: bool,
    pub notes: Option<String>,
}

impl From<Budget> for BudgetDto {
    fn from(budget: Budget) -> Self {
        let total_actual = budget.total_actual();
        let total_remaining = budget.total_remaining();
        let usage_percentage = budget.overall_usage_percentage();

        let items: Vec<BudgetItemDto> = budget
            .items
            .iter()
            .map(|item| BudgetItemDto {
                id: item.id.clone(),
                category_account_id: item.category_account_id.clone(),
                planned_amount: item.planned_amount.to_string(),
                actual_amount: item.actual_amount.to_string(),
                remaining: item.remaining().to_string(),
                usage_percentage: item.usage_percentage(),
                is_over_budget: item.is_over_budget(),
                notes: item.notes.clone(),
            })
            .collect();

        Self {
            id: budget.id,
            name: budget.name,
            month: budget.month,
            total_amount: budget.total_amount.to_string(),
            total_actual: total_actual.to_string(),
            total_remaining: total_remaining.to_string(),
            usage_percentage,
            currency_code: budget.currency_code,
            is_active: budget.is_active,
            items,
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct CreateBudgetDto {
    pub name: String,
    pub month: String,
    pub currency_code: String,
}

#[derive(Debug, Deserialize)]
pub struct AddBudgetItemDto {
    pub category_account_id: String,
    pub planned_amount: String,
    pub notes: Option<String>,
}

pub struct BudgetCommandState {
    service: Arc<BudgetService>,
}

impl BudgetCommandState {
    pub fn from_pool(pool: SqlitePool) -> Self {
        let repo = Arc::new(SqliteBudgetRepository::new(pool.clone()));
        let service = Arc::new(BudgetService::new(repo, pool));
        Self { service }
    }

    pub fn service(&self) -> &BudgetService {
        self.service.as_ref()
    }
}

// TODO: will be used when budget integration tests are added
#[allow(dead_code)]
pub async fn create_default_state_from_pool(pool: SqlitePool) -> sqlx::Result<BudgetCommandState> {
    Ok(BudgetCommandState::from_pool(pool))
}

#[tauri::command]
pub async fn list_budgets(state: State<'_, BudgetCommandState>) -> Result<Vec<BudgetDto>, String> {
    state
        .service()
        .list_budgets()
        .await
        .map(|budgets| budgets.into_iter().map(BudgetDto::from).collect())
}

#[tauri::command]
pub async fn get_budget(
    state: State<'_, BudgetCommandState>,
    id: String,
) -> Result<Option<BudgetDto>, String> {
    state
        .service()
        .get_budget(&id)
        .await
        .map(|opt| opt.map(BudgetDto::from))
}

#[tauri::command]
pub async fn get_budget_by_month(
    state: State<'_, BudgetCommandState>,
    month: String,
) -> Result<Option<BudgetDto>, String> {
    state
        .service()
        .get_budget_by_month(&month)
        .await
        .map(|opt| opt.map(BudgetDto::from))
}

#[tauri::command]
pub async fn create_budget(
    state: State<'_, BudgetCommandState>,
    dto: CreateBudgetDto,
) -> Result<BudgetDto, String> {
    state
        .service()
        .create_budget(dto.name, dto.month, dto.currency_code)
        .await
        .map(BudgetDto::from)
}

#[tauri::command]
pub async fn add_budget_item(
    state: State<'_, BudgetCommandState>,
    budget_id: String,
    dto: AddBudgetItemDto,
) -> Result<BudgetDto, String> {
    state
        .service()
        .add_budget_item(
            budget_id,
            dto.category_account_id,
            dto.planned_amount,
            dto.notes,
        )
        .await
        .map(BudgetDto::from)
}

#[tauri::command]
pub async fn delete_budget(state: State<'_, BudgetCommandState>, id: String) -> Result<(), String> {
    state.service().delete_budget(&id).await
}

#[tauri::command]
pub async fn remove_budget_item(
    state: State<'_, BudgetCommandState>,
    budget_id: String,
    item_id: String,
) -> Result<BudgetDto, String> {
    state
        .service()
        .remove_budget_item(&budget_id, &item_id)
        .await
        .map(BudgetDto::from)
}

#[tauri::command]
pub async fn compute_budget_actuals(
    state: State<'_, BudgetCommandState>,
    budget_id: String,
) -> Result<(), String> {
    state.service().compute_budget_actuals(&budget_id).await
}

#[tauri::command]
pub async fn clone_budget_to_month(
    state: State<'_, BudgetCommandState>,
    source_budget_id: String,
    target_month: String,
) -> Result<String, String> {
    state
        .service()
        .clone_budget_to_month(&source_budget_id, &target_month)
        .await
}
