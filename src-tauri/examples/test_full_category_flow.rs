use finance_app::application::dtos::CategoryDto;
use finance_app::application::services::CategoryService;
use finance_app::infrastructure::repositories::SqliteCategoryRepository;
use sqlx::sqlite::SqlitePool;
use std::env;
use std::sync::Arc;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let db_path = format!(
        "{}/finance-app/finance.db",
        env::var("APPDATA").unwrap()
    );
    
    println!("Testing full category flow...");
    println!("Connecting to: {}", db_path);
    
    let pool = SqlitePool::connect(&format!("sqlite:{}", db_path)).await?;
    let repo = Arc::new(SqliteCategoryRepository::new(pool));
    let service = CategoryService::new(repo);
    
    println!("\n=== Calling list_categories ===");
    match service.list_categories().await {
        Ok(categories) => {
            println!("Success! Found {} categories", categories.len());
            
            if let Some(first) = categories.first() {
                println!("\n=== First category (domain model) ===");
                println!("ID: {}", first.id);
                println!("Name: {}", first.name);
                println!("Type: {:?}", first.category_type);
                println!("Updated at: {}", first.sync_metadata.updated_at);
                
                println!("\n=== Converting to DTO ===");
                let dto = CategoryDto::from(first.clone());
                
                println!("DTO ID: {}", dto.id);
                println!("DTO Name: {}", dto.name);
                println!("DTO Updated at: {}", dto.updated_at);
                
                println!("\n=== Serializing to JSON ===");
                match serde_json::to_string_pretty(&dto) {
                    Ok(json) => println!("{}", json),
                    Err(e) => println!("Serialization error: {}", e),
                }
            }
        }
        Err(e) => {
            println!("Error: {:?}", e);
        }
    }
    
    Ok(())
}
