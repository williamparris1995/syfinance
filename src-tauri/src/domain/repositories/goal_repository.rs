use crate::domain::aggregates::goal::Goal;
use rust_decimal::Decimal;

#[allow(async_fn_in_trait)]
pub trait GoalRepository: Send + Sync {
    async fn create(&self, goal: &Goal) -> sqlx::Result<()>;
    async fn find_by_id(&self, id: &str) -> sqlx::Result<Option<Goal>>;
    async fn find_all(&self) -> sqlx::Result<Vec<Goal>>;
    async fn update(&self, goal: &Goal) -> sqlx::Result<()>;
    async fn delete(&self, id: &str) -> sqlx::Result<()>;
    async fn add_progress(&self, id: &str, amount: Decimal) -> sqlx::Result<()>;
}
