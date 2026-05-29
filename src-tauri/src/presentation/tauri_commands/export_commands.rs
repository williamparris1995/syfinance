use serde::Serialize;
use sqlx::{Column, Row, SqlitePool};
use tauri::State;

pub struct ExportCommandState {
    pool: SqlitePool,
}

impl ExportCommandState {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

pub async fn create_export_default_state(pool: SqlitePool) -> ExportCommandState {
    ExportCommandState::new(pool)
}

#[derive(Debug, Serialize)]
pub struct ExportDataDto {
    pub accounts: Vec<serde_json::Value>,
    pub transactions: Vec<serde_json::Value>,
    pub debts: Vec<serde_json::Value>,
    pub goals: Vec<serde_json::Value>,
    pub budgets: Vec<serde_json::Value>,
    pub tags: Vec<serde_json::Value>,
    pub exported_at: String,
}

fn row_to_json(row: &sqlx::sqlite::SqliteRow) -> serde_json::Value {
    let mut map = serde_json::Map::new();
    // Dynamically extract all columns from the row
    for i in 0..row.columns().len() {
        let col = &row.columns()[i];
        let col_name = col.name().to_string();
        // Try different types in order of likelihood
        if let Ok(val) = row.try_get::<String, _>(i) {
            map.insert(col_name, serde_json::Value::String(val));
        } else if let Ok(val) = row.try_get::<i64, _>(i) {
            map.insert(col_name, serde_json::Value::Number(val.into()));
        } else if let Ok(val) = row.try_get::<f64, _>(i) {
            if let Some(n) = serde_json::Number::from_f64(val) {
                map.insert(col_name, serde_json::Value::Number(n));
            }
        } else if let Ok(val) = row.try_get::<bool, _>(i) {
            map.insert(col_name, serde_json::Value::Bool(val));
        } else {
            // NULL or unknown type
            map.insert(col_name, serde_json::Value::Null);
        }
    }
    serde_json::Value::Object(map)
}

#[tauri::command]
pub async fn export_all_data(
    state: State<'_, ExportCommandState>,
) -> Result<ExportDataDto, String> {
    let accounts = sqlx::query("SELECT * FROM accounts")
        .fetch_all(&state.pool)
        .await
        .map_err(|e| format!("Export failed: {}", e))?
        .iter()
        .map(row_to_json)
        .collect();

    let transactions = sqlx::query("SELECT * FROM transactions")
        .fetch_all(&state.pool)
        .await
        .map_err(|e| format!("Export failed: {}", e))?
        .iter()
        .map(row_to_json)
        .collect();

    let debts = sqlx::query("SELECT * FROM debts")
        .fetch_all(&state.pool)
        .await
        .map_err(|e| format!("Export failed: {}", e))?
        .iter()
        .map(row_to_json)
        .collect();

    let goals = sqlx::query("SELECT * FROM goals")
        .fetch_all(&state.pool)
        .await
        .map_err(|e| format!("Export failed: {}", e))?
        .iter()
        .map(row_to_json)
        .collect();

    let budgets = sqlx::query("SELECT * FROM budgets")
        .fetch_all(&state.pool)
        .await
        .map_err(|e| format!("Export failed: {}", e))?
        .iter()
        .map(row_to_json)
        .collect();

    let tags = sqlx::query("SELECT * FROM tags")
        .fetch_all(&state.pool)
        .await
        .map_err(|e| format!("Export failed: {}", e))?
        .iter()
        .map(row_to_json)
        .collect();

    Ok(ExportDataDto {
        accounts,
        transactions,
        debts,
        goals,
        budgets,
        tags,
        exported_at: chrono::Utc::now().to_rfc3339(),
    })
}
