use crate::domain::aggregates::AccountType;
use chrono::NaiveDate;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateDebtDto {
    pub account_id: Uuid,
    pub funding_account_id: Uuid,
    pub counterparty: String,
    pub principal_amount: Decimal,
    pub currency_code: String,
    pub interest_rate: Decimal,
    pub start_date: Option<NaiveDate>,
    pub due_date: Option<NaiveDate>,
    pub amortization_method: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateDebtDto {
    pub counterparty: String,
    pub interest_rate: Decimal,
    pub start_date: NaiveDate,
    pub due_date: NaiveDate,
    pub amortization_method: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PaymentScheduleDto {
    pub id: Uuid,
    pub payment_date: NaiveDate,
    pub principal_amount: String,
    pub interest_amount: String,
    pub total_amount: String,
    pub paid: bool,
    pub transaction_id: Option<Uuid>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DebtDto {
    pub account_id: Uuid,
    pub account_name: String,
    pub account_type: AccountType,
    pub counterparty: String,
    pub principal_amount: String,
    pub remaining_principal: String,
    pub currency_code: String,
    pub interest_rate: String,
    pub start_date: NaiveDate,
    pub due_date: NaiveDate,
    pub amortization_method: String,
    pub payment_schedule: Vec<PaymentScheduleDto>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecordPaymentDto {
    pub schedule_entry_id: Uuid,
    pub payment_source_account_id: Uuid,
    pub interest_account_id: Option<Uuid>,
    pub payment_amount: Option<Decimal>,
    pub payment_date: Option<NaiveDate>,
}
