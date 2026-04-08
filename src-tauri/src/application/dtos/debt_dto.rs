use chrono::NaiveDate;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateDebtDto {
    pub debt_type: String,
    pub counterparty: String,
    pub principal_amount: Decimal,
    pub currency_code: String,
    pub interest_rate: Decimal,
    pub start_date: NaiveDate,
    pub due_date: NaiveDate,
    pub amortization_method: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PaymentScheduleDto {
    pub payment_date: NaiveDate,
    pub principal_amount: String,
    pub interest_amount: String,
    pub total_amount: String,
    pub currency_code: String,
    pub paid: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DebtDto {
    pub id: Uuid,
    pub debt_type: String,
    pub counterparty: String,
    pub principal_amount: String,
    pub currency_code: String,
    pub interest_rate: String,
    pub start_date: NaiveDate,
    pub due_date: NaiveDate,
    pub payment_schedule: Vec<PaymentScheduleDto>,
    pub remaining_balance: String,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecordPaymentDto {
    pub debt_id: Uuid,
    pub payment_date: NaiveDate,
    pub transaction_id: Uuid,
}
