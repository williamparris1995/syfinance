use crate::domain::aggregates::{Account, AccountType};
use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateAccountDto {
    pub name: String,
    pub account_type: AccountType,
    pub chart_of_account_code: String,
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
    pub chart_of_account_code: String,
    pub currency_code: String,
    pub balance: Decimal,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
}

impl From<Account> for AccountDto {
    fn from(account: Account) -> Self {
        Self {
            id: account.id,
            name: account.name,
            account_type: account.account_type,
            chart_of_account_code: account.chart_of_account_code,
            currency_code: account.currency_code.clone(),
            balance: account.balance.amount,
            created_at: account.sync_metadata.updated_at,
            updated_at: account.sync_metadata.updated_at,
            deleted_at: account.sync_metadata.deleted_at,
        }
    }
}
