#![allow(clippy::disallowed_methods)]

use chrono::Utc;
use sqlx::sqlite::{SqliteConnectOptions, SqlitePoolOptions};
use sqlx::Row;
use uuid::Uuid;

#[tokio::test]
async fn test_category_datetime_format() -> Result<(), Box<dyn std::error::Error>> {
    // Create in-memory database with a single connection so all queries share it
    let options = SqliteConnectOptions::new()
        .in_memory(true)
        .foreign_keys(false);
    let pool = SqlitePoolOptions::new()
        .max_connections(1)
        .connect_with(options)
        .await?;

    // Run migrations
    sqlx::migrate!("./migrations").run(&pool).await?;

    // Insert a category with RFC3339 format
    let id = Uuid::new_v4();
    let now = Utc::now().to_rfc3339();

    sqlx::query(
        r#"
        INSERT INTO categories (id, name, icon, color, category_type, parent_id, updated_at, deleted_at, device_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        "#,
    )
    .bind(id.as_bytes().to_vec())
    .bind("测试分类")
    .bind("🍔")
    .bind("#FF5733")
    .bind("expense")
    .bind(None::<Vec<u8>>)
    .bind(&now)
    .bind(None::<String>)
    .bind(Uuid::new_v4().to_string())
    .execute(&pool)
    .await?;

    // Try to read it back
    let row = sqlx::query("SELECT * FROM categories WHERE id = ?")
        .bind(id.as_bytes().to_vec())
        .fetch_one(&pool)
        .await?;

    let updated_at: String = row.try_get("updated_at")?;
    println!("Stored datetime: {}", updated_at);

    // Parse it
    let parsed = chrono::DateTime::parse_from_rfc3339(&updated_at)?;
    println!("Parsed successfully: {}", parsed);

    Ok(())
}
