use crate::domain::{
    aggregates::{Account, AccountType},
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
    pub currency_code: String,
    pub initial_balance: Decimal,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateAccountDto {
    pub name: Option<String>,
    pub balance: Option<Decimal>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountDto {
    pub id: Uuid,
    pub name: String,
    pub account_type: AccountType,
    pub currency_code: String,
    pub balance: Decimal,
    pub account_number: Option<String>,
    pub institution: Option<String>,
    pub credit_limit: Option<Decimal>,
    pub billing_day: Option<u8>,
    pub payment_due_day: Option<u8>,
    pub interest_rate: Option<Decimal>,
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
            currency_code: account.currency_code.clone(),
            balance: account.balance.amount,
            account_number: account.account_number,
            institution: account.institution,
            credit_limit: account.credit_limit.map(|m| m.amount),
            billing_day: account.billing_day,
            payment_due_day: account.payment_due_day,
            interest_rate: account.interest_rate,
            created_at: account.sync_metadata.updated_at,
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
