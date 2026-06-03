use crate::application::services::report_service::{
    BalanceSheet, DashboardSummary, IncomeStatement, MonthlyTrendItem, ReportService, YoyComparison,
};
use serde::Deserialize;
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

#[derive(Debug, Deserialize)]
pub struct ReportDateQuery {
    pub start_date: String,
    pub end_date: String,
}

#[tauri::command]
pub async fn get_balance_sheet(
    state: State<'_, ReportCommandState>,
    as_of_date: String,
) -> Result<BalanceSheet, String> {
    state.service.get_balance_sheet(&as_of_date).await
}

#[tauri::command]
pub async fn get_income_statement(
    state: State<'_, ReportCommandState>,
    query: ReportDateQuery,
) -> Result<IncomeStatement, String> {
    state.service.get_income_statement(&query.start_date, &query.end_date).await
}

#[tauri::command]
pub async fn get_dashboard_summary(
    state: State<'_, ReportCommandState>,
    query: ReportDateQuery,
) -> Result<DashboardSummary, String> {
    state.service.get_dashboard_summary(&query.start_date, &query.end_date).await
}

#[tauri::command]
pub async fn get_monthly_trend(
    state: State<'_, ReportCommandState>,
    query: ReportDateQuery,
) -> Result<Vec<MonthlyTrendItem>, String> {
    state.service.get_monthly_trend(&query.start_date, &query.end_date).await
}
