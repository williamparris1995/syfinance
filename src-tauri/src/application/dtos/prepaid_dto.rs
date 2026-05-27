use chrono::NaiveDate;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TopUpRequest {
    pub account_id: Uuid,
    pub source_account_id: Uuid,
    pub paid_amount: Decimal,
    pub bonus_amount: Option<Decimal>,
    pub top_up_date: NaiveDate,
    pub expiry_date: Option<NaiveDate>,
    pub description: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TopUpRecordDto {
    pub id: Uuid,
    pub account_id: Uuid,
    pub transaction_id: Uuid,
    pub paid_amount: String,
    pub bonus_amount: String,
    pub total_credited: String,
    pub top_up_date: NaiveDate,
    pub expiry_date: Option<NaiveDate>,
    pub source_account_id: Uuid,
    pub description: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrepaidDetailDto {
    pub account_id: Uuid,
    pub account_name: String,
    pub currency_code: String,
    pub balance: String,
    pub low_balance_threshold: Option<String>,
    pub total_paid: String,
    pub total_bonus: String,
    pub total_credited: String,
    pub records: Vec<TopUpRecordDto>,
}
