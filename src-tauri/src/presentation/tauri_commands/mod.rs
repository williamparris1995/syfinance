pub mod account_commands;
pub mod backup_commands;
pub mod budget_commands;
pub mod category_commands;
pub mod cloud_sync_commands;
pub mod currency_commands;
pub mod debt_commands;
pub mod encryption_commands;
pub mod export_commands;
pub mod goal_commands;
pub mod holding_commands;
pub mod prepaid_commands;
pub mod reminder_commands;
pub mod report_commands;
pub mod search_commands;
pub mod sync_commands;
pub mod tag_commands;
pub mod transaction_commands;
pub mod transaction_template_commands;

// Re-exports form the library's public API surface, used by tests and external consumers.
// main.rs imports directly from submodules, so these appear unused to the binary target.
#[allow(unused_imports)]
pub use account_commands::{
    archive_account, create_account, delete_account, get_account, get_account_balance,
    hide_account, list_accounts, list_accounts_by_ownership, list_accounts_with_balances,
    reactivate_account, update_account, AppState,
};
#[allow(unused_imports)]
pub use backup_commands::{
    authorize_cloud_provider, create_backup, create_backup_state, delete_backup,
    get_auto_backup_settings, get_backup_diff, get_backup_metadata, get_cloud_presets,
    get_cloud_settings, list_backups, list_cloud_backups, read_auto_backup_settings,
    save_cloud_settings, test_cloud_connection, update_auto_backup_last_run,
    update_auto_backup_settings, upload_to_cloud, AutoBackupSettings, BackupCommandState,
};
#[allow(unused_imports)]
pub use budget_commands::{
    add_budget_item, compute_budget_actuals, create_budget, delete_budget, get_budget,
    get_budget_by_month, list_budgets, remove_budget_item, BudgetCommandState,
};
#[allow(unused_imports)]
pub use category_commands::{
    create_category, delete_category, list_categories, update_category, CategoryCommandState,
};
#[allow(unused_imports)]
pub use cloud_sync_commands::{
    cloud_sync_now, create_cloud_sync_state, get_cloud_sync_settings, get_cloud_sync_status,
    update_cloud_sync_settings, CloudSyncCommandState,
};
#[allow(unused_imports)]
pub use currency_commands::{
    add_currency, create_default_state as create_currency_default_state, list_currencies,
    update_currency_rate, CurrencyCommandState,
};
#[allow(unused_imports)]
pub use debt_commands::{
    create_debt, create_default_state as create_debt_default_state, delete_debt, get_debt,
    get_upcoming_payments, list_debts, record_payment, update_debt, AppState as DebtCommandState,
};
#[allow(unused_imports)]
pub use encryption_commands::{
    create_encryption_default_state, disable_encryption, get_encryption_status, lock_encryption,
    setup_encryption, unlock_encryption, unlock_encryption_keychain, EncryptionCommandState,
};
#[allow(unused_imports)]
pub use export_commands::{create_export_default_state, export_all_data, ExportCommandState};
#[allow(unused_imports)]
pub use goal_commands::{
    complete_goal, create_default_state_from_pool as create_goal_default_state_from_pool,
    create_goal, delete_goal, get_goal, list_goals, update_goal, update_goal_progress,
    GoalCommandState,
};
#[allow(unused_imports)]
pub use holding_commands::{
    buy_holding, create_security, list_holdings, list_securities, record_dividend, record_split,
    sell_holding, update_security_price, AppState as HoldingCommandState,
};
#[allow(unused_imports)]
pub use prepaid_commands::{get_prepaid_detail, get_top_up_records, top_up, PrepaidCommandState};
#[allow(unused_imports)]
pub use reminder_commands::{
    complete_reminder, create_reminder, create_reminder_default_state_from_pool, delete_reminder,
    get_reminder, list_reminders, update_reminder, ReminderCommandState,
};
#[allow(unused_imports)]
pub use report_commands::{get_yoy_comparison, ReportCommandState};
#[allow(unused_imports)]
pub use search_commands::{
    create_search_default_state, global_search, rebuild_search_index, SearchCommandState,
};
#[allow(unused_imports)]
pub use sync_commands::{
    create_default_state as create_sync_default_state, get_sync_settings, get_sync_status,
    sync_from_server, sync_to_server, update_sync_settings, SyncCommandState,
};
#[allow(unused_imports)]
pub use tag_commands::{
    add_tag_to_transaction, create_default_state_from_pool as create_tag_default_state_from_pool,
    create_tag, delete_tag, get_transaction_tags, list_tags, remove_tag_from_transaction,
    soft_delete_tag, update_tag, TagCommandState,
};
#[allow(unused_imports)]
pub use transaction_commands::{
    create_transaction, delete_transaction, get_transaction, get_transactions_by_account,
    get_transactions_by_date_range, list_transactions, update_transaction, TransactionCommandState,
};
#[allow(unused_imports)]
pub use transaction_template_commands::{
    create_template_default_state_from_pool, create_transaction_template,
    delete_transaction_template, get_transaction_template, list_template_transactions,
    list_transaction_templates, pause_transaction_template, resume_transaction_template,
    update_transaction_template, TransactionTemplateCommandState,
};
