use crate::domain::aggregates::debt_details::{DebtDetails, PaymentScheduleEntry};
use uuid::Uuid;

#[allow(async_fn_in_trait, dead_code)]
pub trait DebtRepository: Send + Sync {
    async fn create_debt_details(&self, debt: &DebtDetails) -> sqlx::Result<()>;

    async fn find_debt_details_by_id(&self, id: Uuid) -> sqlx::Result<Option<DebtDetails>>;

    async fn find_debt_details_by_account_id(
        &self,
        account_id: Uuid,
    ) -> sqlx::Result<Option<DebtDetails>>;

    async fn find_all_debt_details(&self) -> sqlx::Result<Vec<DebtDetails>>;

    async fn update_debt_details(&self, debt: &DebtDetails) -> sqlx::Result<bool>;

    async fn soft_delete_debt_details(&self, id: Uuid) -> sqlx::Result<bool>;

    async fn create_schedule_entries(&self, entries: &[PaymentScheduleEntry]) -> sqlx::Result<()>;

    async fn find_schedule_by_debt_id(
        &self,
        debt_id: Uuid,
    ) -> sqlx::Result<Vec<PaymentScheduleEntry>>;

    async fn update_schedule_entry(&self, entry: &PaymentScheduleEntry) -> sqlx::Result<bool>;

    async fn get_upcoming_payments(
        &self,
        days_ahead: i32,
    ) -> sqlx::Result<Vec<(DebtDetails, PaymentScheduleEntry)>>;
}
