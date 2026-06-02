use crate::domain::aggregates::transaction_template::TransactionTemplate;
use chrono::NaiveDate;
use uuid::Uuid;

#[allow(async_fn_in_trait, dead_code)]
pub trait TransactionTemplateRepository: Send + Sync {
    async fn create(&self, template: &TransactionTemplate) -> sqlx::Result<()>;
    async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<TransactionTemplate>>;
    async fn find_all(&self) -> sqlx::Result<Vec<TransactionTemplate>>;
    async fn find_due(&self, today: NaiveDate) -> sqlx::Result<Vec<TransactionTemplate>>;
    async fn update(&self, template: &TransactionTemplate) -> sqlx::Result<bool>;
    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool>;
    async fn update_next_date(
        &self,
        id: Uuid,
        next_date: NaiveDate,
        last_tx_id: Option<Uuid>,
    ) -> sqlx::Result<bool>;
    async fn set_paused(&self, id: Uuid, paused: bool) -> sqlx::Result<bool>;
}
