use crate::domain::aggregates::budget::Budget;
use crate::domain::value_objects::budget_item::BudgetItem;
use rust_decimal::Decimal;

#[allow(async_fn_in_trait, dead_code)]
pub trait BudgetRepository: Send + Sync {
    async fn create(&self, budget: &Budget) -> sqlx::Result<()>;
    async fn find_by_id(&self, id: &str) -> sqlx::Result<Option<Budget>>;
    async fn find_by_month(&self, month: &str) -> sqlx::Result<Option<Budget>>;
    async fn find_all(&self) -> sqlx::Result<Vec<Budget>>;
    async fn update(&self, budget: &Budget) -> sqlx::Result<()>;
    async fn delete(&self, id: &str) -> sqlx::Result<()>;
    async fn add_item(&self, budget_id: &str, item: &BudgetItem) -> sqlx::Result<()>;
    async fn update_item(&self, item: &BudgetItem) -> sqlx::Result<()>;
    async fn remove_item(&self, item_id: &str) -> sqlx::Result<()>;
    async fn update_actual_amount(
        &self,
        budget_id: &str,
        category_account_id: &str,
        amount: Decimal,
    ) -> sqlx::Result<()>;
}
