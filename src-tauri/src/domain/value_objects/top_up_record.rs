use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TopUpRecord {
    pub id: Uuid,
    pub account_id: Uuid,
    pub transaction_id: Uuid,
    pub paid_amount: Decimal,
    pub bonus_amount: Decimal,
    pub total_credited: Decimal,
    pub top_up_date: NaiveDate,
    pub expiry_date: Option<NaiveDate>,
    pub source_account_id: Uuid,
    pub description: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl TopUpRecord {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        id: Uuid,
        account_id: Uuid,
        transaction_id: Uuid,
        paid_amount: Decimal,
        bonus_amount: Decimal,
        top_up_date: NaiveDate,
        expiry_date: Option<NaiveDate>,
        source_account_id: Uuid,
        description: Option<String>,
    ) -> Self {
        let total_credited = paid_amount + bonus_amount;
        let now = Utc::now();
        Self {
            id,
            account_id,
            transaction_id,
            paid_amount,
            bonus_amount,
            total_credited,
            top_up_date,
            expiry_date,
            source_account_id,
            description,
            created_at: now,
            updated_at: now,
        }
    }
}
