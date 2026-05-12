use crate::application::dtos::{CategoryDto, CreateCategoryDto, UpdateCategoryDto};
use crate::application::services::{CategoryService, CategoryServiceError};
use crate::domain::aggregates::CategoryType;
use crate::infrastructure::repositories::SqliteCategoryRepository;
use sqlx::sqlite::SqlitePool;
use std::sync::Arc;
use tauri::State;

pub type CategoryServiceType = CategoryService<SqliteCategoryRepository>;

pub struct CategoryAppState {
    pool: SqlitePool,
    category_service: CategoryServiceType,
}

impl CategoryAppState {
    pub fn from_pool(pool: SqlitePool) -> Self {
        let category_repo = Arc::new(SqliteCategoryRepository::new(pool.clone()));

        Self {
            category_service: CategoryService::new(category_repo),
            pool,
        }
    }

    pub fn service(&self) -> &CategoryServiceType {
        &self.category_service
    }

    pub fn pool(&self) -> &SqlitePool {
        &self.pool
    }
}

#[tauri::command]
pub async fn create_category(
    state: State<'_, CategoryAppState>,
    dto: CreateCategoryDto,
) -> Result<CategoryDto, String> {
    state
        .service()
        .create_category(
            dto.name,
            dto.icon,
            dto.color,
            dto.category_type,
            dto.chart_code,
            dto.parent_id,
        )
        .await
        .map(CategoryDto::from)
        .map_err(|error: CategoryServiceError| error.to_string())
}

#[tauri::command]
pub async fn update_category(
    state: State<'_, CategoryAppState>,
    id: String,
    dto: UpdateCategoryDto,
) -> Result<CategoryDto, String> {
    let category = state
        .service()
        .get_category(id.clone())
        .await
        .map_err(|error: CategoryServiceError| error.to_string())?;

    state
        .service()
        .update_category(
            id,
            dto.name.unwrap_or(category.name),
            dto.icon.unwrap_or(category.icon),
            dto.color.unwrap_or(category.color),
        )
        .await
        .map(CategoryDto::from)
        .map_err(|error: CategoryServiceError| error.to_string())
}

#[tauri::command]
pub async fn delete_category(state: State<'_, CategoryAppState>, id: String) -> Result<(), String> {
    state
        .service()
        .delete_category(id)
        .await
        .map_err(|error: CategoryServiceError| error.to_string())
}

#[tauri::command]
pub async fn get_category(
    state: State<'_, CategoryAppState>,
    id: String,
) -> Result<CategoryDto, String> {
    state
        .service()
        .get_category(id)
        .await
        .map(CategoryDto::from)
        .map_err(|error: CategoryServiceError| error.to_string())
}

#[tauri::command]
pub async fn list_categories(
    state: State<'_, CategoryAppState>,
) -> Result<Vec<CategoryDto>, String> {
    state
        .service()
        .list_categories()
        .await
        .map(|categories| categories.into_iter().map(CategoryDto::from).collect())
        .map_err(|error: CategoryServiceError| error.to_string())
}

#[tauri::command]
pub async fn list_categories_by_type(
    state: State<'_, CategoryAppState>,
    category_type: CategoryType,
) -> Result<Vec<CategoryDto>, String> {
    state
        .service()
        .list_categories_by_type(category_type)
        .await
        .map(|categories| categories.into_iter().map(CategoryDto::from).collect())
        .map_err(|error: CategoryServiceError| error.to_string())
}
