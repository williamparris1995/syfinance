use crate::domain::aggregates::{Debt, DebtType};
use chrono::NaiveDate;
use uuid::Uuid;

#[allow(async_fn_in_trait, dead_code)]
pub trait DebtRepository: Send + Sync {
    async fn create(&self, debt: &Debt) -> sqlx::Result<()>;

    async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<Debt>>;

    async fn find_all(&self) -> sqlx::Result<Vec<Debt>>;

    async fn find_by_type(&self, debt_type: DebtType) -> sqlx::Result<Vec<Debt>>;

    async fn find_due_by_date(&self, due_date: NaiveDate) -> sqlx::Result<Vec<Debt>>;

    async fn update(&self, debt: &Debt) -> sqlx::Result<bool>;

    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool>;
}
