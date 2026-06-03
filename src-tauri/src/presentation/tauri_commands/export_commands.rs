use serde::{Deserialize, Serialize};
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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExportCsvResult {
    pub file_path: String,
    pub rows_exported: usize,
}

#[tauri::command]
pub async fn export_csv(
    state: State<'_, ExportCommandState>,
    app: tauri::AppHandle,
) -> Result<ExportCsvResult, String> {
    use tauri_plugin_dialog::DialogExt;

    let (tx, rx) = tokio::sync::oneshot::channel::<Option<String>>();

    app.dialog()
        .file()
        .set_title("Export CSV")
        .set_file_name("finance-export.csv")
        .add_filter("CSV", &["csv"])
        .save_file(move |path: Option<tauri_plugin_dialog::FilePath>| {
            let _ = tx.send(path.map(|p| match p {
                tauri_plugin_dialog::FilePath::Path(p) => p.to_string_lossy().to_string(),
                tauri_plugin_dialog::FilePath::Url(u) => u.to_string(),
            }));
        });

    let file_path = rx
        .await
        .map_err(|e| format!("Dialog error: {}", e))?
        .ok_or_else(|| "Export cancelled".to_string())?;

    tracing::info!(file_path = %file_path, "Exporting CSV");

    let mut wtr =
        csv::Writer::from_path(&file_path).map_err(|e| format!("Failed to create CSV: {}", e))?;

    wtr.write_record(&["table", "id", "field", "value"])
        .map_err(|e| format!("CSV write error: {}", e))?;

    let tables = [
        "accounts",
        "transactions",
        "transaction_entries",
        "debt_details",
        "debt_payment_schedule",
        "goals",
        "budgets",
        "budget_items",
        "tags",
        "transaction_tags",
    ];

    let mut total_rows = 0usize;

    for table in &tables {
        let rows: Vec<serde_json::Value> = sqlx::query(&format!("SELECT * FROM {}", table))
            .fetch_all(&state.pool)
            .await
            .map_err(|e| format!("Query {} failed: {}", table, e))?
            .into_iter()
            .map(|row| row_to_json(&row))
            .collect();

        for row in &rows {
            if let Some(obj) = row.as_object() {
                let id = obj.get("id").and_then(|v| v.as_str()).unwrap_or("unknown");
                for (key, value) in obj {
                    if key == "id" {
                        continue;
                    }
                    let val_str = match value {
                        serde_json::Value::Null => String::new(),
                        serde_json::Value::String(s) => s.clone(),
                        other => other.to_string(),
                    };
                    wtr.write_record(&[table, id, key, &val_str])
                        .map_err(|e| format!("CSV write error: {}", e))?;
                    total_rows += 1;
                }
            }
        }
    }

    wtr.flush().map_err(|e| format!("CSV flush error: {}", e))?;

    tracing::info!(file_path = %file_path, rows = total_rows, "CSV export complete");

    Ok(ExportCsvResult {
        file_path,
        rows_exported: total_rows,
    })
}
