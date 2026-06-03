use crate::application::services::report_service::{ReportService, YoyComparison};
use sqlx::SqlitePool;
use std::sync::Arc;
use tauri::State;

pub struct ReportCommandState {
    service: Arc<ReportService>,
}

impl ReportCommandState {
    pub fn from_pool(pool: SqlitePool) -> Self {
        Self {
            service: Arc::new(ReportService::new(Arc::new(pool))),
        }
    }
}

#[tauri::command]
pub async fn get_yoy_comparison(
    state: State<'_, ReportCommandState>,
    year1: u32,
    year2: u32,
) -> Result<YoyComparison, String> {
    state.service.get_yoy_comparison(year1, year2).await
}
