mod application;
mod domain;
mod infrastructure;
mod presentation;

use presentation::tauri_commands::{
    account_commands::{
        create_account, delete_account, get_account, get_account_balance, list_accounts,
        update_account, AppState,
    },
    debt_commands::{
        create_debt, create_default_state as create_debt_default_state, get_debt,
        get_upcoming_payments, list_debts, record_payment, AppState as DebtAppState,
    },
    transaction_commands::{
        create_default_state, create_transaction, get_transaction, get_transactions_by_account,
        get_transactions_by_date_range, list_transactions,
    },
};

fn main() {
    let account_state = tauri::async_runtime::block_on(AppState::create_default())
        .expect("failed to initialize account command state");
    let debt_state: DebtAppState = tauri::async_runtime::block_on(create_debt_default_state())
        .expect("failed to initialize debt command state");
    let transaction_state = tauri::async_runtime::block_on(create_default_state())
        .expect("failed to initialize transaction command state");

    tauri::Builder::default()
        .plugin(tauri_plugin_notification::init())
        .manage(account_state)
        .manage(debt_state)
        .manage(transaction_state)
        .invoke_handler(tauri::generate_handler![
            create_account,
            update_account,
            delete_account,
            get_account,
            list_accounts,
            get_account_balance,
            create_debt,
            get_debt,
            list_debts,
            record_payment,
            get_upcoming_payments,
            create_transaction,
            get_transaction,
            list_transactions,
            get_transactions_by_account,
            get_transactions_by_date_range
        ])
        .setup(|_app| {
            // NotificationService::reschedule_all() should be called here once the app state is wired.
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
