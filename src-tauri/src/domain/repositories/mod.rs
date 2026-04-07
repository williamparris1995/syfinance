use crate::domain::aggregates::{Account, AccountType, ChartOfAccounts, ChartOfAccountsType};
use crate::domain::value_objects::Currency;
use rust_decimal::Decimal;
use uuid::Uuid;

#[allow(async_fn_in_trait, dead_code)]
pub trait AccountRepository: Send + Sync {
    async fn create(&self, account: &Account) -> sqlx::Result<()>;

    async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<Account>>;

    async fn find_all(&self) -> sqlx::Result<Vec<Account>>;

    async fn find_by_type(&self, account_type: AccountType) -> sqlx::Result<Vec<Account>>;

    async fn update(&self, account: &Account) -> sqlx::Result<bool>;

    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool>;

    async fn find_all_including_deleted(&self) -> sqlx::Result<Vec<Account>>;
}

#[allow(dead_code)]
pub trait TransactionRepository: Send + Sync {}

#[allow(dead_code)]
pub trait DebtRepository: Send + Sync {}

#[allow(dead_code)]
pub trait ReminderRepository: Send + Sync {}

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
