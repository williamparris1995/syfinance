use chrono::NaiveDate;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateTransactionEntryDto {
    pub account_id: Uuid,
    pub chart_of_account_code: String,
    pub category_id: Option<Uuid>,
    pub debit_amount: Option<Decimal>,
    pub credit_amount: Option<Decimal>,
    pub memo: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateTransactionDto {
    pub transaction_date: NaiveDate,
    pub description: String,
    pub entries: Vec<CreateTransactionEntryDto>,
}

// Simplified DTOs for user-friendly transaction creation

/// 简化的收入交易 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SimpleIncomeDto {
    pub transaction_date: NaiveDate,
    pub amount: Decimal,
    pub account_id: Uuid,
    pub category_id: String,
    pub description: String,
    pub memo: Option<String>,
}

/// 简化的支出交易 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SimpleExpenseDto {
    pub transaction_date: NaiveDate,
    pub amount: Decimal,
    pub account_id: Uuid,
    pub category_id: String,
    pub description: String,
    pub memo: Option<String>,
}

/// 简化的转账交易 DTO
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SimpleTransferDto {
    pub transaction_date: NaiveDate,
    pub amount: Decimal,
    pub from_account_id: Uuid,
    pub to_account_id: Uuid,
    pub description: String,
    pub memo: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransactionEntryDto {
    pub account_id: Uuid,
    pub chart_of_account_code: String,
    pub category_id: Option<Uuid>,
    pub debit_amount: Option<String>,
    pub credit_amount: Option<String>,
    pub currency_code: String,
    pub memo: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransactionDto {
    pub id: Uuid,
    pub transaction_date: NaiveDate,
    pub description: String,
    pub entries: Vec<TransactionEntryDto>,
    pub created_at: String,
    pub updated_at: String,
}
