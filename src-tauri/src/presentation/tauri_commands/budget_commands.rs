use crate::domain::aggregates::budget::Budget;
use crate::domain::repositories::BudgetRepository;
use crate::domain::value_objects::budget_item::BudgetItem;
use crate::infrastructure::repositories::SqliteBudgetRepository;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use sqlx::sqlite::SqlitePool;
use std::str::FromStr;
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
    pool: SqlitePool,
    budget_repository: Arc<SqliteBudgetRepository>,
}

impl BudgetCommandState {
    pub fn from_pool(pool: SqlitePool) -> Self {
        Self {
            budget_repository: Arc::new(SqliteBudgetRepository::new(pool.clone())),
            pool,
        }
    }

    pub fn repository(&self) -> &SqliteBudgetRepository {
        self.budget_repository.as_ref()
    }

    pub fn pool(&self) -> &SqlitePool {
        &self.pool
    }
}

pub async fn create_default_state_from_pool(
    pool: SqlitePool,
) -> sqlx::Result<BudgetCommandState> {
    Ok(BudgetCommandState::from_pool(pool))
}

#[tauri::command]
pub async fn list_budgets(
    state: State<'_, BudgetCommandState>,
) -> Result<Vec<BudgetDto>, String> {
    state
        .repository()
        .find_all()
        .await
        .map(|budgets| budgets.into_iter().map(BudgetDto::from).collect())
        .map_err(|e| format!("Failed to list budgets: {}", e))
}

#[tauri::command]
pub async fn get_budget(
    state: State<'_, BudgetCommandState>,
    id: String,
) -> Result<Option<BudgetDto>, String> {
    state
        .repository()
        .find_by_id(&id)
        .await
        .map(|opt| opt.map(BudgetDto::from))
        .map_err(|e| format!("Failed to get budget: {}", e))
}

#[tauri::command]
pub async fn get_budget_by_month(
    state: State<'_, BudgetCommandState>,
    month: String,
) -> Result<Option<BudgetDto>, String> {
    state
        .repository()
        .find_by_month(&month)
        .await
        .map(|opt| opt.map(BudgetDto::from))
        .map_err(|e| format!("Failed to get budget: {}", e))
}

#[tauri::command]
pub async fn create_budget(
    state: State<'_, BudgetCommandState>,
    dto: CreateBudgetDto,
) -> Result<BudgetDto, String> {
    let id = uuid::Uuid::new_v4().to_string();
    let budget = Budget::new(id, dto.name, dto.month, dto.currency_code);

    state
        .repository()
        .create(&budget)
        .await
        .map_err(|e| format!("Failed to create budget: {}", e))?;

    Ok(BudgetDto::from(budget))
}

#[tauri::command]
pub async fn add_budget_item(
    state: State<'_, BudgetCommandState>,
    budget_id: String,
    dto: AddBudgetItemDto,
) -> Result<BudgetDto, String> {
    let planned_amount =
        Decimal::from_str(&dto.planned_amount).map_err(|_| "Invalid planned amount".to_string())?;

    let item_id = uuid::Uuid::new_v4().to_string();
    let item = BudgetItem::new(
        item_id,
        budget_id.clone(),
        dto.category_account_id,
        planned_amount,
        dto.notes,
    );

    state
        .repository()
        .add_item(&budget_id, &item)
        .await
        .map_err(|e| format!("Failed to add budget item: {}", e))?;

    let budget = state
        .repository()
        .find_by_id(&budget_id)
        .await
        .map_err(|e| format!("Failed to get budget: {}", e))?
        .ok_or_else(|| "Budget not found".to_string())?;

    Ok(BudgetDto::from(budget))
}

#[tauri::command]
pub async fn delete_budget(state: State<'_, BudgetCommandState>, id: String) -> Result<(), String> {
    state
        .repository()
        .delete(&id)
        .await
        .map_err(|e| format!("Failed to delete budget: {}", e))
}

#[tauri::command]
pub async fn remove_budget_item(
    state: State<'_, BudgetCommandState>,
    budget_id: String,
    item_id: String,
) -> Result<BudgetDto, String> {
    state
        .repository()
        .remove_item(&item_id)
        .await
        .map_err(|e| format!("Failed to remove budget item: {}", e))?;

    let budget = state
        .repository()
        .find_by_id(&budget_id)
        .await
        .map_err(|e| format!("Failed to get budget: {}", e))?
        .ok_or_else(|| "Budget not found".to_string())?;

    Ok(BudgetDto::from(budget))
}
