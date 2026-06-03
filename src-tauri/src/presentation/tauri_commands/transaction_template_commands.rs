use crate::application::dtos::{
    CreateTransactionTemplateDto, TransactionDto, TransactionTemplateDto,
    UpdateTransactionTemplateDto,
};
use crate::application::services::transaction_template_service::TransactionTemplateService;
use crate::infrastructure::repositories::{
    SqliteAccountRepository, SqliteTransactionRepository, SqliteTransactionTemplateRepository,
};
use sqlx::sqlite::SqlitePool;
use std::sync::Arc;
use tauri::State;
use uuid::Uuid;

pub struct TransactionTemplateCommandState {
    // TODO: will be used when template commands need direct pool access
    #[allow(dead_code)]
    pool: SqlitePool,
    template_service: TransactionTemplateService,
}

impl TransactionTemplateCommandState {
    pub fn from_pool(pool: SqlitePool) -> Self {
        let template_repo = Arc::new(SqliteTransactionTemplateRepository::new(pool.clone()));
        let account_repo = Arc::new(SqliteAccountRepository::new(pool.clone()));
        let transaction_repo = Arc::new(SqliteTransactionRepository::new(pool.clone()));
        Self {
            template_service: TransactionTemplateService::new(
                template_repo,
                account_repo,
                transaction_repo,
            ),
            pool,
        }
    }

    pub fn service(&self) -> &TransactionTemplateService {
        &self.template_service
    }

    // TODO: will be used when template commands need direct pool access
    #[allow(dead_code)]
    pub fn pool(&self) -> &SqlitePool {
        &self.pool
    }
}

pub async fn create_template_default_state_from_pool(
    pool: SqlitePool,
) -> sqlx::Result<TransactionTemplateCommandState> {
    Ok(TransactionTemplateCommandState::from_pool(pool))
}

#[tauri::command]
pub async fn create_transaction_template(
    state: State<'_, TransactionTemplateCommandState>,
    dto: CreateTransactionTemplateDto,
) -> Result<String, String> {
    state
        .service()
        .create(dto)
        .await
        .map(|id| id.to_string())
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn list_transaction_templates(
    state: State<'_, TransactionTemplateCommandState>,
) -> Result<Vec<TransactionTemplateDto>, String> {
    state.service().list().await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn get_transaction_template(
    state: State<'_, TransactionTemplateCommandState>,
    id: String,
) -> Result<TransactionTemplateDto, String> {
    let id = Uuid::parse_str(&id).map_err(|e| e.to_string())?;
    state
        .service()
        .get_by_id(id)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn update_transaction_template(
    state: State<'_, TransactionTemplateCommandState>,
    dto: UpdateTransactionTemplateDto,
) -> Result<(), String> {
    state.service().update(dto).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn delete_transaction_template(
    state: State<'_, TransactionTemplateCommandState>,
    id: String,
) -> Result<(), String> {
    let id = Uuid::parse_str(&id).map_err(|e| e.to_string())?;
    state.service().delete(id).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn pause_transaction_template(
    state: State<'_, TransactionTemplateCommandState>,
    id: String,
) -> Result<(), String> {
    let id = Uuid::parse_str(&id).map_err(|e| e.to_string())?;
    state.service().pause(id).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn resume_transaction_template(
    state: State<'_, TransactionTemplateCommandState>,
    id: String,
) -> Result<(), String> {
    let id = Uuid::parse_str(&id).map_err(|e| e.to_string())?;
    state.service().resume(id).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn list_template_transactions(
    state: State<'_, TransactionTemplateCommandState>,
    template_id: String,
) -> Result<Vec<TransactionDto>, String> {
    let id = Uuid::parse_str(&template_id).map_err(|e| e.to_string())?;
    state
        .service()
        .list_transactions(id)
        .await
        .map_err(|e| e.to_string())
}
