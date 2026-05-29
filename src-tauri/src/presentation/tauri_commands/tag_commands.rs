use crate::domain::aggregates::tag::Tag;
use crate::domain::repositories::TagRepository;
use crate::infrastructure::repositories::SqliteTagRepository;
use serde::{Deserialize, Serialize};
use sqlx::sqlite::SqlitePool;
use std::sync::Arc;
use tauri::State;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TagDto {
    pub id: String,
    pub name: String,
    pub color: String,
}

impl From<Tag> for TagDto {
    fn from(tag: Tag) -> Self {
        Self {
            id: tag.id,
            name: tag.name,
            color: tag.color,
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct CreateTagDto {
    pub name: String,
    pub color: String,
}

pub struct TagCommandState {
    pool: SqlitePool,
    tag_repository: Arc<SqliteTagRepository>,
}

impl TagCommandState {
    pub fn from_pool(pool: SqlitePool) -> Self {
        Self {
            tag_repository: Arc::new(SqliteTagRepository::new(pool.clone())),
            pool,
        }
    }

    pub fn repository(&self) -> &SqliteTagRepository {
        self.tag_repository.as_ref()
    }

    pub fn pool(&self) -> &SqlitePool {
        &self.pool
    }
}

pub async fn create_default_state_from_pool(
    pool: SqlitePool,
) -> sqlx::Result<TagCommandState> {
    Ok(TagCommandState::from_pool(pool))
}

#[tauri::command]
pub async fn list_tags(state: State<'_, TagCommandState>) -> Result<Vec<TagDto>, String> {
    state
        .repository()
        .find_all()
        .await
        .map(|tags| tags.into_iter().map(TagDto::from).collect())
        .map_err(|e| format!("Failed to list tags: {}", e))
}

#[tauri::command]
pub async fn create_tag(
    state: State<'_, TagCommandState>,
    dto: CreateTagDto,
) -> Result<TagDto, String> {
    let id = uuid::Uuid::new_v4().to_string();
    let tag = Tag::new(id, dto.name, dto.color);
    state
        .repository()
        .create(&tag)
        .await
        .map_err(|e| format!("Failed to create tag: {}", e))?;
    Ok(TagDto::from(tag))
}

#[tauri::command]
pub async fn delete_tag(state: State<'_, TagCommandState>, id: String) -> Result<(), String> {
    state
        .repository()
        .delete(&id)
        .await
        .map_err(|e| format!("Failed to delete tag: {}", e))
}

#[tauri::command]
pub async fn add_tag_to_transaction(
    state: State<'_, TagCommandState>,
    transaction_id: String,
    tag_id: String,
) -> Result<(), String> {
    state
        .repository()
        .add_to_transaction(&transaction_id, &tag_id)
        .await
        .map_err(|e| format!("Failed to add tag to transaction: {}", e))
}

#[tauri::command]
pub async fn remove_tag_from_transaction(
    state: State<'_, TagCommandState>,
    transaction_id: String,
    tag_id: String,
) -> Result<(), String> {
    state
        .repository()
        .remove_from_transaction(&transaction_id, &tag_id)
        .await
        .map_err(|e| format!("Failed to remove tag from transaction: {}", e))
}

#[tauri::command]
pub async fn get_transaction_tags(
    state: State<'_, TagCommandState>,
    transaction_id: String,
) -> Result<Vec<TagDto>, String> {
    state
        .repository()
        .find_by_transaction(&transaction_id)
        .await
        .map(|tags| tags.into_iter().map(TagDto::from).collect())
        .map_err(|e| format!("Failed to get transaction tags: {}", e))
}
