use sqlx::sqlite::SqlitePool;
use std::str::FromStr;

#[path = "../src/application/dtos/category_dto.rs"]
mod category_dto;

#[path = "../src/application/services/category_service.rs"]
mod category_service;

#[path = "../src/domain/aggregates/category.rs"]
mod category;

#[path = "../src/domain/value_objects/sync_metadata.rs"]
mod sync_metadata;

#[path = "../src/domain/repositories/category_repository.rs"]
mod category_repository;

#[path = "../src/infrastructure/repositories/category_repository.rs"]
mod sqlite_category_repository;

use category_dto::CategoryDto;
use category_service::CategoryService;
use sqlite_category_repository::SqliteCategoryRepository;
use std::sync::Arc;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let db_path = std::env::var("APPDATA")
        .map(|appdata| format!("{}/finance-app/finance.db", appdata))
        .unwrap_or_else(|_| "finance.db".to_string());

    println!("Connecting to database: {}", db_path);

    let options = sqlx::sqlite::SqliteConnectOptions::from_str(&format!("sqlite:{}", db_path))?
        .create_if_missing(false);

    let pool = SqlitePool::connect_with(options).await?;

    let category_repo = Arc::new(SqliteCategoryRepository::new(pool.clone()));
    let category_service = CategoryService::new(category_repo);

    println!("\n=== Testing list_categories ===");
    match category_service.list_categories().await {
        Ok(categories) => {
            println!("Successfully retrieved {} categories", categories.len());
            for category in categories {
                let dto = CategoryDto::from(category);
                println!("  - {} ({}): {}", dto.name, dto.category_type, dto.updated_at);
            }
        }
        Err(e) => {
            println!("ERROR: {:?}", e);
            return Err(format!("Failed to list categories: {:?}", e).into());
        }
    }

    Ok(())
}
