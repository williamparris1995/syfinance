use chrono::NaiveDate;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// 简化的收入交易 DTO
/// 用户只需提供基本信息，系统自动生成复式记账条目
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SimpleIncomeDto {
    pub date: NaiveDate,
    pub amount: Decimal,
    pub debit_account_id: Uuid,
    pub credit_account_id: Uuid,
    pub description: String,
}

/// 简化的支出交易 DTO
/// 用户只需提供基本信息，系统自动生成复式记账条目
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SimpleExpenseDto {
    pub date: NaiveDate,
    pub amount: Decimal,
    pub debit_account_id: Uuid,
    pub credit_account_id: Uuid,
    pub description: String,
}

/// 简化的转账交易 DTO
/// 用户只需提供基本信息，系统自动生成复式记账条目
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SimpleTransferDto {
    pub date: NaiveDate,
    pub amount: Decimal,
    pub from_account_id: Uuid,
    pub to_account_id: Uuid,
    pub description: String,
}
