use serde::{Deserialize, Serialize};
use sqlx::{Row, SqlitePool};
use tauri::State;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchResultDto {
    pub result_type: String, // "account", "transaction", "goal"
    pub id: String,
    pub title: String,
    pub subtitle: String,
}

pub struct SearchCommandState {
    pool: SqlitePool,
}

impl SearchCommandState {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

pub async fn create_search_default_state(pool: SqlitePool) -> SearchCommandState {
    SearchCommandState::new(pool)
}

#[tauri::command]
pub async fn global_search(
    state: State<'_, SearchCommandState>,
    query: String,
) -> Result<Vec<SearchResultDto>, String> {
    let search_pattern = format!("%{}%", query);
    let mut results = Vec::new();

    // Search accounts
    let accounts =
        sqlx::query("SELECT id, name, account_type FROM accounts WHERE name LIKE ? LIMIT 5")
            .bind(&search_pattern)
            .fetch_all(&state.pool)
            .await
            .map_err(|e| format!("Search failed: {}", e))?;

    for row in accounts {
        let id: String = row.try_get("id").unwrap_or_default();
        let name: String = row.try_get("name").unwrap_or_default();
        let account_type: String = row.try_get("account_type").unwrap_or_default();
        results.push(SearchResultDto {
            result_type: "account".to_string(),
            id,
            title: name,
            subtitle: account_type,
        });
    }

    // Search transactions
    let transactions = sqlx::query(
        "SELECT id, description, transaction_date FROM transactions WHERE description LIKE ? LIMIT 5",
    )
    .bind(&search_pattern)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| format!("Search failed: {}", e))?;

    for row in transactions {
        let id: String = row.try_get("id").unwrap_or_default();
        let description: String = row.try_get("description").unwrap_or_default();
        let date: String = row.try_get("transaction_date").unwrap_or_default();
        results.push(SearchResultDto {
            result_type: "transaction".to_string(),
            id,
            title: description,
            subtitle: date,
        });
    }

    // Search goals
    let goals = sqlx::query("SELECT id, name, goal_type FROM goals WHERE name LIKE ? LIMIT 5")
        .bind(&search_pattern)
        .fetch_all(&state.pool)
        .await
        .map_err(|e| format!("Search failed: {}", e))?;

    for row in goals {
        let id: String = row.try_get("id").unwrap_or_default();
        let name: String = row.try_get("name").unwrap_or_default();
        let goal_type: String = row.try_get("goal_type").unwrap_or_default();
        results.push(SearchResultDto {
            result_type: "goal".to_string(),
            id,
            title: name,
            subtitle: goal_type,
        });
    }

    Ok(results)
}
