use crate::domain::aggregates::tag::Tag;

#[allow(async_fn_in_trait, dead_code)]
pub trait TagRepository: Send + Sync {
    async fn create(&self, tag: &Tag) -> sqlx::Result<()>;
    async fn find_all(&self) -> sqlx::Result<Vec<Tag>>;
    async fn find_by_id(&self, id: &str) -> sqlx::Result<Option<Tag>>;
    async fn delete(&self, id: &str) -> sqlx::Result<()>;
    async fn add_to_transaction(&self, transaction_id: &str, tag_id: &str) -> sqlx::Result<()>;
    async fn remove_from_transaction(&self, transaction_id: &str, tag_id: &str) -> sqlx::Result<()>;
    async fn find_by_transaction(&self, transaction_id: &str) -> sqlx::Result<Vec<Tag>>;
}
