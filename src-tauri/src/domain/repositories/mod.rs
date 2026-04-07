use crate::domain::value_objects::Currency;
use rust_decimal::Decimal;

#[allow(dead_code)]
pub trait AccountRepository: Send + Sync {}

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
