use crate::application::dtos::{CategoryDto, CreateCategoryDto, UpdateCategoryDto};
use crate::application::services::CategoryService;
use crate::infrastructure::repositories::SqliteCategoryRepository;
use sqlx::sqlite::SqlitePool;
use std::sync::Arc;
use tauri::State;
use uuid::Uuid;

pub struct CategoryCommandState {
    service: Arc<CategoryService<SqliteCategoryRepository>>,
}

impl CategoryCommandState {
    pub fn from_pool(pool: SqlitePool) -> Self {
        let repo = Arc::new(SqliteCategoryRepository::new(pool));
        Self {
            service: Arc::new(CategoryService::new(repo)),
        }
    }
}

pub async fn create_default_state_from_pool(
    pool: SqlitePool,
) -> sqlx::Result<CategoryCommandState> {
    Ok(CategoryCommandState::from_pool(pool))
}

#[tauri::command]
pub async fn list_categories(
    category_type: Option<String>,
    state: State<'_, CategoryCommandState>,
) -> Result<Vec<CategoryDto>, String> {
    state
        .service
        .list_categories(category_type)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn create_category(
    dto: CreateCategoryDto,
    state: State<'_, CategoryCommandState>,
) -> Result<CategoryDto, String> {
    state
        .service
        .create_category(dto)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn update_category(
    id: String,
    dto: UpdateCategoryDto,
    state: State<'_, CategoryCommandState>,
) -> Result<CategoryDto, String> {
    let id = Uuid::parse_str(&id).map_err(|e| e.to_string())?;
    state
        .service
        .update_category(id, dto)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn delete_category(
    id: String,
    state: State<'_, CategoryCommandState>,
) -> Result<(), String> {
    let id = Uuid::parse_str(&id).map_err(|e| e.to_string())?;
    state
        .service
        .delete_category(id)
        .await
        .map_err(|e| e.to_string())
}
