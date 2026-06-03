use chrono::NaiveDate;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateTransactionTemplateDto {
    pub name: String,
    pub description: Option<String>,
    pub amount: Decimal,
    pub direction: String,
    pub source_account_id: Uuid,
    pub destination_account_id: Option<Uuid>,
    pub cycle: String,
    pub cycle_days: Option<u32>,
    pub billing_day: Option<u8>,
    pub next_date: NaiveDate,
    pub start_date: NaiveDate,
    pub end_date: Option<NaiveDate>,
    pub auto_record: Option<bool>,
    pub category: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateTransactionTemplateDto {
    pub id: Uuid,
    pub name: Option<String>,
    pub description: Option<String>,
    pub amount: Option<Decimal>,
    pub direction: Option<String>,
    pub source_account_id: Option<Uuid>,
    pub destination_account_id: Option<Uuid>,
    pub cycle: Option<String>,
    pub cycle_days: Option<u32>,
    pub billing_day: Option<u8>,
    pub next_date: Option<NaiveDate>,
    pub end_date: Option<NaiveDate>,
    pub auto_record: Option<bool>,
    pub category: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransactionTemplateDto {
    pub id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub amount: Decimal,
    pub direction: String,
    pub source_account_id: Uuid,
    pub source_account_name: String,
    pub destination_account_id: Option<Uuid>,
    pub destination_account_name: Option<String>,
    pub currency_code: String,
    pub cycle: String,
    pub cycle_days: Option<u32>,
    pub billing_day: Option<u8>,
    pub next_date: NaiveDate,
    pub start_date: NaiveDate,
    pub end_date: Option<NaiveDate>,
    pub auto_record: bool,
    pub paused: bool,
    pub last_transaction_id: Option<Uuid>,
    pub category: Option<String>,
}
