use sqlx::{sqlite::SqlitePool, Row};
use std::env;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let db_path = format!(
        "{}/finance-app/finance.db",
        env::var("APPDATA").unwrap()
    );
    
    println!("Connecting to database: {}", db_path);
    let pool = SqlitePool::connect(&format!("sqlite:{}", db_path)).await?;
    
    println!("\n=== Testing category query ===");
    let row = sqlx::query("SELECT id, name, category_type, updated_at FROM categories LIMIT 1")
        .fetch_one(&pool)
        .await?;
    
    let id: String = row.try_get("id")?;
    let name: String = row.try_get("name")?;
    let category_type: String = row.try_get("category_type")?;
    let updated_at: String = row.try_get("updated_at")?;
    
    println!("ID: {}", id);
    println!("Name: {}", name);
    println!("Type: {}", category_type);
    println!("Updated at: {}", updated_at);
    println!("Updated at length: {}", updated_at.len());
    println!("Updated at bytes: {:?}", updated_at.as_bytes());
    
    Ok(())
}
