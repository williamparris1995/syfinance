pub mod account_service;
pub mod budget_service;
pub mod debt_service;
pub mod encryption_app_service;
pub mod goal_service;
pub mod holding_service;
pub mod prepaid_service;
pub mod subscription_service;
pub mod transaction_service;
pub mod transaction_template_service;

// Re-exports form the library's public API surface, used by tests and external consumers.
// main.rs imports directly from submodules, so these appear unused to the binary target.
#[allow(unused_imports)]
pub use account_service::{AccountService, AccountServiceError};
#[allow(unused_imports)]
pub use budget_service::BudgetService;
pub use debt_service::DebtService;
pub use encryption_app_service::{EncryptionAppError, EncryptionAppService};
#[allow(unused_imports)]
pub use goal_service::{GoalService, GoalServiceError};
#[allow(unused_imports)]
pub use holding_service::{HoldingService, HoldingServiceError};
pub use prepaid_service::PrepaidService;
#[allow(unused_imports)]
pub use subscription_service::{SubscriptionService, SubscriptionServiceError};
pub use transaction_service::TransactionService;
#[allow(unused_imports)]
pub use transaction_template_service::{
    TransactionTemplateService, TransactionTemplateServiceError,
};
