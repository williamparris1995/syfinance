use crate::domain::aggregates::{Category, CategoryType};
use async_trait::async_trait;
use uuid::Uuid;

#[async_trait]
pub trait CategoryRepository: Send + Sync {
    async fn find_by_id(&self, id: Uuid) -> Result<Option<Category>, sqlx::Error>;
    async fn list_by_type(
        &self,
        category_type: Option<CategoryType>,
        include_deleted: bool,
    ) -> Result<Vec<Category>, sqlx::Error>;
    async fn save(&self, category: &Category) -> Result<(), sqlx::Error>;
    async fn soft_delete(&self, id: Uuid) -> Result<(), sqlx::Error>;
}
