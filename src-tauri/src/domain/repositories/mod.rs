mod budget_repository;
mod debt_repository;
mod goal_repository;
mod prepaid_repository;
mod reminder_repository;
mod subscription_repository;
mod tag_repository;

use crate::domain::aggregates::holding::{Holding, HoldingTransaction};
use crate::domain::aggregates::security::{Security, SecurityType};
use crate::domain::aggregates::{
    Account, AccountType, ChartOfAccounts, ChartOfAccountsType, Ownership, Transaction,
};
use crate::domain::value_objects::Currency;
use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use uuid::Uuid;

pub use budget_repository::BudgetRepository;
pub use debt_repository::DebtRepository;
pub use goal_repository::GoalRepository;
pub use prepaid_repository::PrepaidRepository;
pub use reminder_repository::ReminderRepository;
pub use subscription_repository::SubscriptionRepository;
pub use tag_repository::TagRepository;

#[allow(async_fn_in_trait, dead_code)]
pub trait AccountRepository: Send + Sync {
    async fn create(&self, account: &Account) -> sqlx::Result<()>;

    async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<Account>>;

    async fn find_all(&self) -> sqlx::Result<Vec<Account>>;

    async fn find_by_type(&self, account_type: AccountType) -> sqlx::Result<Vec<Account>>;

    async fn find_by_ownership(&self, ownership: &Ownership) -> sqlx::Result<Vec<Account>>;

    async fn update(&self, account: &Account) -> sqlx::Result<bool>;

    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool>;

    async fn find_all_including_deleted(&self) -> sqlx::Result<Vec<Account>>;

    async fn get_changes_since(&self, timestamp: DateTime<Utc>) -> sqlx::Result<Vec<Account>>;

    async fn mark_as_synced(&self, id: Uuid) -> sqlx::Result<bool>;

    async fn compute_balances_for_all_accounts(
        &self,
    ) -> Result<std::collections::HashMap<Uuid, Decimal>, sqlx::Error>;

    async fn compute_balance_for_account(&self, id: Uuid) -> Result<Decimal, sqlx::Error>;
}

#[allow(async_fn_in_trait, dead_code)]
pub trait TransactionRepository: Send + Sync {
    async fn create(&self, transaction: &Transaction) -> sqlx::Result<()>;

    async fn update(&self, transaction: &Transaction) -> sqlx::Result<bool>;

    async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<Transaction>>;

    async fn find_by_date_range(
        &self,
        start_date: NaiveDate,
        end_date: NaiveDate,
    ) -> sqlx::Result<Vec<Transaction>>;

    async fn find_all(&self) -> sqlx::Result<Vec<Transaction>>;

    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool>;

    async fn get_changes_since(&self, timestamp: DateTime<Utc>) -> sqlx::Result<Vec<Transaction>>;

    async fn mark_as_synced(&self, id: Uuid) -> sqlx::Result<bool>;
}

#[allow(async_fn_in_trait, dead_code)]
pub trait CurrencyRepository: Send + Sync {
    async fn create(&self, currency: &Currency) -> sqlx::Result<()>;

    async fn find_by_code(&self, code: &str) -> sqlx::Result<Option<Currency>>;

    async fn find_active(&self) -> sqlx::Result<Vec<Currency>>;

    async fn list_all(&self) -> sqlx::Result<Vec<Currency>>;

    async fn save(&self, currency: &Currency) -> sqlx::Result<()>;

    async fn update_rate(&self, code: &str, exchange_rate: Decimal) -> sqlx::Result<bool>;

    async fn delete(&self, code: &str) -> sqlx::Result<bool>;
}

#[allow(async_fn_in_trait, dead_code)]
pub trait ChartOfAccountsRepository: Send + Sync {
    async fn create(&self, account: &ChartOfAccounts) -> sqlx::Result<()>;

    async fn update(&self, account: &ChartOfAccounts) -> sqlx::Result<bool>;

    async fn find_by_code(&self, code: &str) -> sqlx::Result<Option<ChartOfAccounts>>;

    async fn list_by_level(&self, level: i32) -> sqlx::Result<Vec<ChartOfAccounts>>;

    async fn list_by_type(
        &self,
        account_type: ChartOfAccountsType,
    ) -> sqlx::Result<Vec<ChartOfAccounts>>;

    async fn get_children(&self, parent_code: &str) -> sqlx::Result<Vec<ChartOfAccounts>>;

    async fn list_all(&self) -> sqlx::Result<Vec<ChartOfAccounts>>;
}

#[allow(async_fn_in_trait, dead_code)]
pub trait SecurityRepository: Send + Sync {
    async fn create(&self, security: &Security) -> sqlx::Result<()>;
    async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<Security>>;
    async fn find_by_symbol(&self, symbol: &str) -> sqlx::Result<Option<Security>>;
    async fn find_all(&self) -> sqlx::Result<Vec<Security>>;
    async fn find_by_type(&self, security_type: &SecurityType) -> sqlx::Result<Vec<Security>>;
    async fn update(&self, security: &Security) -> sqlx::Result<bool>;
    async fn update_price(&self, id: Uuid, price: Decimal) -> sqlx::Result<bool>;
    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool>;
}

#[allow(async_fn_in_trait, dead_code)]
pub trait HoldingRepository: Send + Sync {
    async fn find_by_account(&self, account_id: Uuid) -> sqlx::Result<Vec<Holding>>;
    async fn find_all(&self) -> sqlx::Result<Vec<Holding>>;
    async fn upsert(&self, holding: &Holding) -> sqlx::Result<()>;
    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool>;

    async fn create_transaction(&self, txn: &HoldingTransaction) -> sqlx::Result<()>;
    async fn find_transactions_by_account(
        &self,
        account_id: Uuid,
    ) -> sqlx::Result<Vec<HoldingTransaction>>;
    async fn find_transactions_by_holding(
        &self,
        account_id: Uuid,
        security_id: Uuid,
    ) -> sqlx::Result<Vec<HoldingTransaction>>;

    async fn find_transactions_by_holding_id(
        &self,
        holding_id: Uuid,
    ) -> sqlx::Result<Vec<HoldingTransaction>>;
    async fn find_holding_transaction_by_id(
        &self,
        id: Uuid,
    ) -> sqlx::Result<Option<HoldingTransaction>>;
    async fn soft_delete_holding_transaction(&self, id: Uuid) -> sqlx::Result<bool>;
    async fn soft_delete_transaction_cascade(&self, transaction_id: Uuid) -> sqlx::Result<bool>;
    #[allow(clippy::too_many_arguments)]
    async fn update_holding_transaction(
        &self,
        id: Uuid,
        quantity: Decimal,
        price: Decimal,
        fee: Decimal,
        trade_date: NaiveDate,
    ) -> sqlx::Result<()>;
    async fn update_holding_quantities(
        &self,
        holding_id: Uuid,
        quantity: Decimal,
        avg_cost: Decimal,
    ) -> sqlx::Result<()>;
    async fn soft_delete_holding_by_id(&self, holding_id: Uuid) -> sqlx::Result<bool>;
    async fn find_holding_by_id(&self, id: Uuid) -> sqlx::Result<Option<Holding>>;
}
