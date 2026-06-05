use crate::domain::{
    aggregates::{Account, AccountType, Ownership},
    value_objects::Money,
};
use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateAccountDto {
    pub name: String,
    pub account_type: AccountType,
    pub ownership: Ownership,
    pub currency_code: String,
    pub initial_balance: Decimal,
    pub icon: String,
    pub color: String,
    pub chart_code: Option<String>,
    pub parent_id: Option<Uuid>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateAccountDto {
    pub name: String,
    #[serde(alias = "balance")]
    pub initial_balance: Decimal,
    pub icon: Option<String>,
    pub color: Option<String>,
    pub currency_code: Option<String>,
    pub account_number: Option<String>,
    pub institution: Option<String>,
    pub credit_limit: Option<Decimal>,
    pub billing_day: Option<i32>,
    pub payment_due_day: Option<i32>,
    pub interest_rate: Option<Decimal>,
    pub chart_code: Option<String>,
    pub parent_id: Option<Uuid>,
    pub low_balance_threshold: Option<Decimal>,
}

/// Patch semantics: `Some(Some(value))` = set to value, `Some(None)` = clear, `None` = no change
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PatchAccountDto {
    pub name: String,
    #[serde(alias = "balance")]
    pub initial_balance: Decimal,
    pub icon: Option<String>,
    pub color: Option<String>,
    pub account_number: Option<Option<String>>,
    pub institution: Option<Option<String>>,
    pub credit_limit: Option<Option<Decimal>>,
    pub billing_day: Option<Option<i32>>,
    pub payment_due_day: Option<Option<i32>>,
    pub interest_rate: Option<Option<Decimal>>,
    pub chart_code: Option<Option<String>>,
    pub parent_id: Option<Option<Uuid>>,
    pub low_balance_threshold: Option<Option<Decimal>>,
}

impl From<UpdateAccountDto> for PatchAccountDto {
    fn from(dto: UpdateAccountDto) -> Self {
        Self {
            name: dto.name,
            initial_balance: dto.initial_balance,
            icon: dto.icon,
            color: dto.color,
            account_number: dto.account_number.map(Some),
            institution: dto.institution.map(Some),
            credit_limit: dto.credit_limit.map(Some),
            billing_day: dto.billing_day.map(Some),
            payment_due_day: dto.payment_due_day.map(Some),
            interest_rate: dto.interest_rate.map(Some),
            chart_code: dto.chart_code.map(Some),
            parent_id: dto.parent_id.map(Some),
            low_balance_threshold: dto.low_balance_threshold.map(Some),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountDto {
    pub id: Uuid,
    pub name: String,
    pub account_type: AccountType,
    pub ownership: Ownership,
    pub icon: String,
    pub color: String,
    pub chart_code: Option<String>,
    pub parent_id: Option<Uuid>,
    pub currency_code: String,
    pub initial_balance: Decimal,
    pub current_balance: Decimal,
    pub account_number: Option<String>,
    pub institution: Option<String>,
    pub credit_limit: Option<Decimal>,
    pub billing_day: Option<u8>,
    pub payment_due_day: Option<u8>,
    pub interest_rate: Option<Decimal>,
    pub low_balance_threshold: Option<Decimal>,
    pub status: String,
    pub opened_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountBalanceDto {
    pub amount: Decimal,
    pub currency_code: String,
}

impl From<Account> for AccountDto {
    fn from(account: Account) -> Self {
        Self {
            id: account.id,
            name: account.name,
            account_type: account.account_type,
            ownership: account.ownership,
            icon: account.icon,
            color: account.color,
            chart_code: account.chart_code,
            parent_id: account.parent_id,
            currency_code: account.currency_code.clone(),
            initial_balance: account.initial_balance.amount,
            current_balance: account.initial_balance.amount, // default, overridden by service
            account_number: account.account_number,
            institution: account.institution,
            credit_limit: account.credit_limit.map(|m| m.amount),
            billing_day: account.billing_day,
            payment_due_day: account.payment_due_day,
            interest_rate: account.interest_rate,
            low_balance_threshold: account.low_balance_threshold,
            status: account.status.to_string(),
            opened_at: account.opened_at,
            created_at: account.created_at,
            updated_at: account.sync_metadata.updated_at,
            deleted_at: account.sync_metadata.deleted_at,
        }
    }
}

impl From<Money> for AccountBalanceDto {
    fn from(balance: Money) -> Self {
        Self {
            amount: balance.amount,
            currency_code: balance.currency_code,
        }
    }
}
