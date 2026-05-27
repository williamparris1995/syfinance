use chrono::NaiveDate;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateSubscriptionDto {
    pub name: String,
    pub amount: Decimal,
    pub direction: String,
    pub cycle: String,
    pub cycle_days: Option<u32>,
    pub billing_day: Option<u8>,
    pub next_billing_date: NaiveDate,
    pub start_date: NaiveDate,
    pub end_date: Option<NaiveDate>,
    pub auto_record: Option<bool>,
    pub source_account_id: Uuid,
    pub category: Option<String>,
    pub description: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateSubscriptionDto {
    pub id: Uuid,
    pub name: Option<String>,
    pub amount: Option<Decimal>,
    pub direction: Option<String>,
    pub cycle: Option<String>,
    pub cycle_days: Option<u32>,
    pub billing_day: Option<u8>,
    pub next_billing_date: Option<NaiveDate>,
    pub end_date: Option<NaiveDate>,
    pub auto_record: Option<bool>,
    pub source_account_id: Option<Uuid>,
    pub category: Option<String>,
    pub description: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SubscriptionDto {
    pub id: Uuid,
    pub name: String,
    pub amount: Decimal,
    pub direction: String,
    pub cycle: String,
    pub cycle_days: Option<u32>,
    pub billing_day: Option<u8>,
    pub next_billing_date: NaiveDate,
    pub start_date: NaiveDate,
    pub end_date: Option<NaiveDate>,
    pub auto_record: bool,
    pub paused: bool,
    pub source_account_id: Uuid,
    pub source_account_name: String,
    pub currency_code: String,
    pub category: Option<String>,
    pub description: Option<String>,
    pub last_transaction_id: Option<Uuid>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SubscriptionFilters {
    pub direction: Option<String>,
    pub cycle: Option<String>,
    pub paused: Option<bool>,
}
