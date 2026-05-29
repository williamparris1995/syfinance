#![allow(clippy::disallowed_methods)]

use sqlx::sqlite::SqlitePool;
use sqlx::Row;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let db_path = std::env::var("APPDATA")
        .map(|appdata| format!("{}/finance-app/finance.db", appdata))
        .unwrap_or_else(|_| "finance.db".to_string());

    println!("Connecting to database: {}", db_path);

    let pool = SqlitePool::connect(&format!("sqlite:{}", db_path)).await?;

    println!("\n=== Checking chart_of_accounts table ===");
    let rows = sqlx::query("SELECT code, name, updated_at FROM chart_of_accounts LIMIT 5")
        .fetch_all(&pool)
        .await?;

    for row in rows {
        let code: String = row.try_get("code")?;
        let name: String = row.try_get("name")?;
        let updated_at: String = row.try_get("updated_at")?;
        println!(
            "Code: {}, Name: {}, updated_at: '{}' (len: {}, bytes: {:?})",
            code,
            name,
            updated_at,
            updated_at.len(),
            updated_at.as_bytes()
        );
    }

    println!("\n=== Checking categories table ===");
    let rows = sqlx::query("SELECT id, name, updated_at FROM categories LIMIT 5")
        .fetch_all(&pool)
        .await?;

    for row in rows {
        let id: String = row.try_get("id")?;
        let name: String = row.try_get("name")?;
        let updated_at: String = row.try_get("updated_at")?;
        println!(
            "ID: {}, Name: {}, updated_at: '{}' (len: {}, bytes: {:?})",
            id,
            name,
            updated_at,
            updated_at.len(),
            updated_at.as_bytes()
        );
    }

    Ok(())
}
