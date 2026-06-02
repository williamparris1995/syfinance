use crate::domain::value_objects::TopUpRecord;
use uuid::Uuid;

#[allow(async_fn_in_trait)]
pub trait PrepaidRepository: Send + Sync {
    async fn create_top_up_record(&self, record: &TopUpRecord) -> sqlx::Result<()>;
    async fn find_top_up_records_by_account(
        &self,
        account_id: Uuid,
    ) -> sqlx::Result<Vec<TopUpRecord>>;
    // TODO: will be used when individual top-up record lookup is needed
    #[allow(dead_code)]
    async fn find_top_up_record_by_id(&self, id: Uuid) -> sqlx::Result<Option<TopUpRecord>>;
    // TODO: will be used when linking top-up records to transactions
    #[allow(dead_code)]
    async fn find_top_up_record_by_transaction(
        &self,
        transaction_id: Uuid,
    ) -> sqlx::Result<Option<TopUpRecord>>;
}
