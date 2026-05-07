mod application;
mod domain;
mod infrastructure;
mod presentation;

use presentation::api::create_sync_routes;
use presentation::tauri_commands::{
    account_commands::{
        create_account, delete_account, get_account, get_account_balance, list_accounts,
        update_account, AppState,
    },
    currency_commands::{
        add_currency, create_default_state as create_currency_default_state, list_currencies,
        update_currency_rate, CurrencyCommandState,
    },
    debt_commands::{
        create_debt, create_default_state as create_debt_default_state, get_debt,
        get_upcoming_payments, list_debts, record_payment, AppState as DebtAppState,
    },
    sync_commands::{
        create_default_state as create_sync_default_state, get_sync_status, sync_from_server,
        sync_to_server,
    },
    transaction_commands::{
        create_default_state, create_transaction, get_transaction, get_transactions_by_account,
        get_transactions_by_date_range, list_transactions,
    },
};

#[tokio::main]
async fn main() {
    let account_state = AppState::create_default()
        .await
        .expect("failed to initialize account command state");
    let debt_state: DebtAppState = create_debt_default_state()
        .await
        .expect("failed to initialize debt command state");
    let currency_state: CurrencyCommandState = create_currency_default_state()
        .await
        .expect("failed to initialize currency command state");
    let transaction_state = create_default_state()
        .await
        .expect("failed to initialize transaction command state");
    let sync_state = create_sync_default_state();

    // Start Axum REST API server in background
    let app = create_sync_routes();
    tokio::spawn(async move {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:3000")
            .await
            .expect("failed to bind to port 3000");
        println!("REST API server listening on http://127.0.0.1:3000");
        axum::serve(listener, app)
            .await
            .expect("failed to start axum server");
    });

    tauri::Builder::default()
        .plugin(tauri_plugin_notification::init())
        .manage(account_state)
        .manage(debt_state)
        .manage(currency_state)
        .manage(transaction_state)
        .manage(sync_state)
        .invoke_handler(tauri::generate_handler![
            create_account,
            update_account,
            delete_account,
            get_account,
            list_accounts,
            get_account_balance,
            list_currencies,
            add_currency,
            update_currency_rate,
            create_debt,
            get_debt,
            list_debts,
            record_payment,
            get_upcoming_payments,
            create_transaction,
            get_transaction,
            list_transactions,
            get_transactions_by_account,
            get_transactions_by_date_range,
            sync_to_server,
            sync_from_server,
            get_sync_status
        ])
        .setup(|_app| {
            // NotificationService::reschedule_all() should be called here once the app state is wired.
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
