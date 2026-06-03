use serde::{Deserialize, Serialize};
use sqlx::{Row, SqlitePool};
use tauri::State;
use tracing::{error, info};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchResultDto {
    pub result_type: String, // "account", "transaction", "debt", "goal", "tag"
    pub id: String,
    pub title: String,
    pub subtitle: String,
    pub rank: f64,
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
    // Escape special FTS5 characters in the query
    let escaped_query: String = query
        .chars()
        .filter(|c| !['*', '^', '#'].contains(c))
        .map(|c| {
            if c == '"' {
                "\"\"".to_string()
            } else {
                c.to_string()
            }
        })
        .collect();

    let fts_query = format!("\"{}\"*", escaped_query);
    let mut results = Vec::new();

    // Search accounts
    let accounts = sqlx::query(
        "SELECT a.id, a.name, a.account_type, f.rank \
         FROM fts_accounts f \
         JOIN accounts a ON a.rowid = f.rowid \
         WHERE f.name MATCH ? AND a.deleted_at IS NULL \
         ORDER BY f.rank \
         LIMIT 5",
    )
    .bind(&fts_query)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| {
        error!(operation = "global_search_accounts", error = %e, "FTS5 search failed");
        format!("Search failed: {}", e)
    })?;

    for row in accounts {
        let id: String = row.try_get("id").unwrap_or_default();
        let name: String = row.try_get("name").unwrap_or_default();
        let account_type: String = row.try_get("account_type").unwrap_or_default();
        let rank: f64 = row.try_get("rank").unwrap_or_default();
        results.push(SearchResultDto {
            result_type: "account".to_string(),
            id,
            title: name,
            subtitle: account_type,
            rank,
        });
    }

    // Search transactions
    let transactions = sqlx::query(
        "SELECT t.id, t.description, t.transaction_date, f.rank \
         FROM fts_transactions f \
         JOIN transactions t ON t.rowid = f.rowid \
         WHERE f.description MATCH ? AND t.deleted_at IS NULL \
         ORDER BY f.rank \
         LIMIT 5",
    )
    .bind(&fts_query)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| {
        error!(operation = "global_search_transactions", error = %e, "FTS5 search failed");
        format!("Search failed: {}", e)
    })?;

    for row in transactions {
        let id: String = row.try_get("id").unwrap_or_default();
        let description: String = row.try_get("description").unwrap_or_default();
        let date: String = row.try_get("transaction_date").unwrap_or_default();
        let rank: f64 = row.try_get("rank").unwrap_or_default();
        results.push(SearchResultDto {
            result_type: "transaction".to_string(),
            id,
            title: description,
            subtitle: date,
            rank,
        });
    }

    // Search debts (by counterparty in debt_details)
    let debts = sqlx::query(
        "SELECT d.id, d.counterparty, a.name, f.rank \
         FROM fts_debts f \
         JOIN debt_details d ON d.rowid = f.rowid \
         JOIN accounts a ON a.id = d.account_id \
         WHERE f.counterparty MATCH ? AND d.deleted_at IS NULL \
         ORDER BY f.rank \
         LIMIT 5",
    )
    .bind(&fts_query)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| {
        error!(operation = "global_search_debts", error = %e, "FTS5 search failed");
        format!("Search failed: {}", e)
    })?;

    for row in debts {
        let id: String = row.try_get("id").unwrap_or_default();
        let counterparty: String = row.try_get("counterparty").unwrap_or_default();
        let account_name: String = row.try_get("name").unwrap_or_default();
        let rank: f64 = row.try_get("rank").unwrap_or_default();
        results.push(SearchResultDto {
            result_type: "debt".to_string(),
            id,
            title: counterparty,
            subtitle: account_name,
            rank,
        });
    }

    // Search goals
    let goals = sqlx::query(
        "SELECT g.id, g.name, g.goal_type, f.rank \
         FROM fts_goals f \
         JOIN goals g ON g.rowid = f.rowid \
         WHERE f.name MATCH ? \
         ORDER BY f.rank \
         LIMIT 5",
    )
    .bind(&fts_query)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| {
        error!(operation = "global_search_goals", error = %e, "FTS5 search failed");
        format!("Search failed: {}", e)
    })?;

    for row in goals {
        let id: String = row.try_get("id").unwrap_or_default();
        let name: String = row.try_get("name").unwrap_or_default();
        let goal_type: String = row.try_get("goal_type").unwrap_or_default();
        let rank: f64 = row.try_get("rank").unwrap_or_default();
        results.push(SearchResultDto {
            result_type: "goal".to_string(),
            id,
            title: name,
            subtitle: goal_type,
            rank,
        });
    }

    // Search tags
    let tags = sqlx::query(
        "SELECT t.id, t.name, t.color, f.rank \
         FROM fts_tags f \
         JOIN tags t ON t.rowid = f.rowid \
         WHERE f.name MATCH ? AND t.deleted_at IS NULL \
         ORDER BY f.rank \
         LIMIT 5",
    )
    .bind(&fts_query)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| {
        error!(operation = "global_search_tags", error = %e, "FTS5 search failed");
        format!("Search failed: {}", e)
    })?;

    for row in tags {
        let id: String = row.try_get("id").unwrap_or_default();
        let name: String = row.try_get("name").unwrap_or_default();
        let color: String = row.try_get("color").unwrap_or_default();
        let rank: f64 = row.try_get("rank").unwrap_or_default();
        results.push(SearchResultDto {
            result_type: "tag".to_string(),
            id,
            title: name,
            subtitle: color,
            rank,
        });
    }

    // Sort all results by rank (lower is better relevance)
    results.sort_by(|a, b| {
        a.rank
            .partial_cmp(&b.rank)
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    Ok(results)
}

#[tauri::command]
pub async fn rebuild_search_index(state: State<'_, SearchCommandState>) -> Result<(), String> {
    info!("Rebuilding FTS5 search index");

    sqlx::query("INSERT INTO fts_accounts(fts_accounts) VALUES('rebuild')")
        .execute(&state.pool)
        .await
        .map_err(|e| {
            error!(operation = "rebuild_search_index_accounts", error = %e, "Failed to rebuild accounts FTS index");
            format!("Failed to rebuild accounts index: {}", e)
        })?;

    sqlx::query("INSERT INTO fts_transactions(fts_transactions) VALUES('rebuild')")
        .execute(&state.pool)
        .await
        .map_err(|e| {
            error!(operation = "rebuild_search_index_transactions", error = %e, "Failed to rebuild transactions FTS index");
            format!("Failed to rebuild transactions index: {}", e)
        })?;

    sqlx::query("INSERT INTO fts_debts(fts_debts) VALUES('rebuild')")
        .execute(&state.pool)
        .await
        .map_err(|e| {
            error!(operation = "rebuild_search_index_debts", error = %e, "Failed to rebuild debts FTS index");
            format!("Failed to rebuild debts index: {}", e)
        })?;

    sqlx::query("INSERT INTO fts_goals(fts_goals) VALUES('rebuild')")
        .execute(&state.pool)
        .await
        .map_err(|e| {
            error!(operation = "rebuild_search_index_goals", error = %e, "Failed to rebuild goals FTS index");
            format!("Failed to rebuild goals index: {}", e)
        })?;

    sqlx::query("INSERT INTO fts_tags(fts_tags) VALUES('rebuild')")
        .execute(&state.pool)
        .await
        .map_err(|e| {
            error!(operation = "rebuild_search_index_tags", error = %e, "Failed to rebuild tags FTS index");
            format!("Failed to rebuild tags index: {}", e)
        })?;

    info!("FTS5 search index rebuilt successfully");
    Ok(())
}
