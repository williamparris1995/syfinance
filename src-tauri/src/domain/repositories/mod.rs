mod debt_repository;
mod reminder_repository;

use crate::domain::aggregates::{
    Account, AccountType, Category, CategoryType, ChartOfAccounts, ChartOfAccountsType, Debt, DebtType, Reminder,
    Transaction,
};
use crate::domain::value_objects::Currency;
use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use uuid::Uuid;

pub use debt_repository::DebtRepository;
pub use reminder_repository::ReminderRepository;

#[allow(async_fn_in_trait, dead_code)]
pub trait AccountRepository: Send + Sync {
    async fn create(&self, account: &Account) -> sqlx::Result<()>;

    async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<Account>>;

    async fn find_all(&self) -> sqlx::Result<Vec<Account>>;

    async fn find_by_type(&self, account_type: AccountType) -> sqlx::Result<Vec<Account>>;

    async fn update(&self, account: &Account) -> sqlx::Result<bool>;

    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool>;

    async fn find_all_including_deleted(&self) -> sqlx::Result<Vec<Account>>;

    async fn get_changes_since(&self, timestamp: DateTime<Utc>) -> sqlx::Result<Vec<Account>>;

    async fn mark_as_synced(&self, id: Uuid) -> sqlx::Result<bool>;
}

#[allow(async_fn_in_trait, dead_code)]
pub trait TransactionRepository: Send + Sync {
    async fn create(&self, transaction: &Transaction) -> sqlx::Result<()>;

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

    async fn list_all(&self) -> sqlx::Result<Vec<Currency>>;

    async fn update_rate(&self, code: &str, exchange_rate: Decimal) -> sqlx::Result<bool>;
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
pub trait CategoryRepository: Send + Sync {
    async fn create(&self, category: &Category) -> sqlx::Result<()>;

    async fn update(&self, category: &Category) -> sqlx::Result<bool>;

    async fn find_by_id(&self, id: &str) -> sqlx::Result<Option<Category>>;

    async fn find_all(&self) -> sqlx::Result<Vec<Category>>;

    async fn find_by_type(&self, category_type: CategoryType) -> sqlx::Result<Vec<Category>>;

    async fn find_by_parent(&self, parent_id: Option<&str>) -> sqlx::Result<Vec<Category>>;

    async fn soft_delete(&self, id: &str) -> sqlx::Result<bool>;
}
