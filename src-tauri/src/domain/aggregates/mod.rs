pub mod account;
pub mod budget;
pub mod chart_of_accounts;
pub mod debt_details;
pub mod goal;
pub mod holding;
pub mod reminder;
pub mod security;
pub mod subscription;
pub mod tag;
pub mod transaction;
pub mod transaction_template;

// Re-exports form the library's public API surface, used by tests and external consumers.
// main.rs imports directly from submodules, so these appear unused to the binary target.
#[allow(unused_imports)]
pub use account::{Account, AccountError, AccountType, Ownership};
#[allow(unused_imports)]
pub use chart_of_accounts::{
    AccountType as ChartOfAccountsType, BalanceDirection, ChartOfAccounts, ChartOfAccountsError,
};
#[allow(unused_imports)]
pub use holding::{Holding, HoldingTransaction, HoldingTransactionType};
#[allow(unused_imports)]
pub use reminder::{Reminder, ReminderError, ReminderType, RepeatPattern};
#[allow(unused_imports)]
pub use subscription::{Subscription, SubscriptionCycle, SubscriptionDirection};
#[allow(unused_imports)]
pub use tag::Tag;
#[allow(unused_imports)]
pub use transaction::{Transaction, TransactionError, TransactionEvent};
#[allow(unused_imports)]
pub use transaction_template::{TemplateCycle, TemplateDirection, TransactionTemplate};
