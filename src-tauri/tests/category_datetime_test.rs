use chrono::Utc;
use sqlx::{sqlite::SqlitePool, Row};
use uuid::Uuid;

#[tokio::test]
async fn test_category_datetime_format() -> Result<(), Box<dyn std::error::Error>> {
    // Create in-memory database
    let pool = SqlitePool::connect("sqlite::memory:").await?;
    
    // Run migrations
    sqlx::migrate!("./migrations").run(&pool).await?;
    
    // Insert a category with RFC3339 format
    let id = Uuid::new_v4();
    let now = Utc::now().to_rfc3339();
    
    sqlx::query(
        r#"
        INSERT INTO categories (id, name, icon, color, category_type, chart_code, parent_id, updated_at, deleted_at, device_id, synced_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        "#
    )
    .bind(id.to_string())
    .bind("测试分类")
    .bind("🍔")
    .bind("#FF5733")
    .bind("expense")
    .bind("5401")
    .bind(None::<String>)
    .bind(&now)
    .bind(None::<String>)
    .bind(Uuid::new_v4().to_string())
    .bind(None::<String>)
    .execute(&pool)
    .await?;
    
    // Try to read it back
    let row = sqlx::query("SELECT * FROM categories WHERE id = ?")
        .bind(id.to_string())
        .fetch_one(&pool)
        .await?;
    
    let updated_at: String = row.try_get("updated_at")?;
    println!("Stored datetime: {}", updated_at);
    
    // Parse it
    let parsed = chrono::DateTime::parse_from_rfc3339(&updated_at)?;
    println!("Parsed successfully: {}", parsed);
    
    Ok(())
}
