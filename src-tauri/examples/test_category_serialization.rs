#![allow(clippy::disallowed_methods)]

use sqlx::{sqlite::SqlitePool, Row};
use std::env;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let db_path = format!("{}/finance-app/finance.db", env::var("APPDATA").unwrap());

    println!("Connecting to database: {}", db_path);
    let pool = SqlitePool::connect(&format!("sqlite:{}", db_path)).await?;

    println!("\n=== Testing CategoryDto serialization ===");

    // Simulate what the repository does
    let row = sqlx::query("SELECT id, name, icon, color, category_type, chart_code, parent_id, updated_at, deleted_at FROM categories LIMIT 1")
        .fetch_one(&pool)
        .await?;

    let id: String = row.try_get("id")?;
    let name: String = row.try_get("name")?;
    let icon: String = row.try_get("icon")?;
    let color: String = row.try_get("color")?;
    let category_type: String = row.try_get("category_type")?;
    let chart_code: String = row.try_get("chart_code")?;
    let parent_id: Option<String> = row.try_get("parent_id")?;
    let updated_at: String = row.try_get("updated_at")?;
    let deleted_at: Option<String> = row.try_get("deleted_at")?;

    println!("Raw data from DB:");
    println!("  id: {}", id);
    println!("  name: {}", name);
    println!("  icon: {}", icon);
    println!("  color: {}", color);
    println!("  category_type: {}", category_type);
    println!("  chart_code: {}", chart_code);
    println!("  parent_id: {:?}", parent_id);
    println!("  updated_at: {}", updated_at);
    println!("  deleted_at: {:?}", deleted_at);

    // Try to serialize as JSON
    let json_obj = serde_json::json!({
        "id": id,
        "name": name,
        "icon": icon,
        "color": color,
        "category_type": category_type,
        "chart_code": chart_code,
        "parent_id": parent_id,
        "created_at": updated_at,
        "updated_at": updated_at,
        "deleted_at": deleted_at,
    });

    println!("\n=== JSON serialization ===");
    let json_str = serde_json::to_string_pretty(&json_obj)?;
    println!("{}", json_str);

    Ok(())
}
