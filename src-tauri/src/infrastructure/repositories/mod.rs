pub mod account_repository;
pub mod account_repository_postgres;
pub mod budget_repository;
pub mod category_repository;
pub mod chart_of_accounts_repository;
pub mod currency_repository;
pub mod debt_repository;
pub mod debt_repository_postgres;
pub mod goal_repository;
pub mod holding_repository;
pub mod prepaid_repository;
pub mod reminder_repository;
pub mod reminder_repository_postgres;
pub mod security_repository;
pub mod tag_repository;
pub mod transaction_repository;
pub mod transaction_repository_postgres;
pub mod transaction_template_repository;

pub use account_repository::SqliteAccountRepository;
// Re-exports form the library's public API surface, used by tests and external consumers.
#[allow(unused_imports)]
pub use account_repository_postgres::PostgresAccountRepository;
pub use budget_repository::SqliteBudgetRepository;
pub use category_repository::SqliteCategoryRepository;
#[allow(unused_imports)]
pub use chart_of_accounts_repository::SqliteChartOfAccountsRepository;
pub use currency_repository::SqliteCurrencyRepository;
pub use debt_repository::SqliteDebtRepository;
#[allow(unused_imports)]
pub use debt_repository_postgres::PostgresDebtRepository;
pub use goal_repository::SqliteGoalRepository;
pub use holding_repository::SqliteHoldingRepository;
pub use prepaid_repository::SqlitePrepaidRepository;
pub use reminder_repository::SqliteReminderRepository;
#[allow(unused_imports)]
pub use reminder_repository_postgres::PostgresReminderRepository;
pub use security_repository::SqliteSecurityRepository;
pub use tag_repository::SqliteTagRepository;
pub use transaction_repository::SqliteTransactionRepository;
#[allow(unused_imports)]
pub use transaction_repository_postgres::PostgresTransactionRepository;
pub use transaction_template_repository::SqliteTransactionTemplateRepository;
