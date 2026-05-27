use crate::domain::aggregates::subscription::Subscription;
use chrono::NaiveDate;
use uuid::Uuid;

#[allow(async_fn_in_trait, dead_code)]
pub trait SubscriptionRepository: Send + Sync {
    async fn create(&self, subscription: &Subscription) -> sqlx::Result<()>;
    async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<Subscription>>;
    async fn find_all(&self) -> sqlx::Result<Vec<Subscription>>;
    async fn find_due(&self, today: NaiveDate) -> sqlx::Result<Vec<Subscription>>;
    async fn update(&self, subscription: &Subscription) -> sqlx::Result<bool>;
    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool>;
    async fn update_next_billing_date(
        &self,
        id: Uuid,
        next_date: NaiveDate,
        last_tx_id: Option<Uuid>,
    ) -> sqlx::Result<bool>;
    async fn set_paused(&self, id: Uuid, paused: bool) -> sqlx::Result<bool>;
}
