mod application;
mod domain;
mod infrastructure;
mod presentation;

use infrastructure::notifications::{NotificationService, TauriNotificationSender};
use infrastructure::reminders::ReminderScheduler;
use infrastructure::repositories::SqliteReminderRepository;
use infrastructure::sync::SyncScheduler;
use presentation::api::create_sync_routes;
use presentation::tauri_commands::{
    account_commands::{
        create_account, delete_account, get_account, get_account_balance, list_accounts,
        update_account, AppState,
    },
    currency_commands::{
        add_currency, create_default_state_from_pool as create_currency_default_state_from_pool, list_currencies,
        update_currency_rate, CurrencyCommandState,
    },
    debt_commands::{
        create_debt, create_default_state_from_pool as create_debt_default_state_from_pool, get_debt,
        get_upcoming_payments, list_debts, record_payment, AppState as DebtAppState,
    },
    sync_commands::{
        create_default_state as create_sync_default_state, get_sync_settings, get_sync_status,
        sync_from_server, sync_to_server, update_sync_settings,
    },
    transaction_commands::{
        create_default_state_from_pool as create_default_state_from_pool, create_transaction, get_transaction, get_transactions_by_account,
        get_transactions_by_date_range, list_transactions,
    },
};
use sqlx::sqlite::SqlitePool;
use std::str::FromStr;
use std::sync::Arc;
use tauri::Manager;

#[tokio::main]
async fn main() {
    // Create a single shared database pool for all services
    let options = sqlx::sqlite::SqliteConnectOptions::from_str("sqlite::memory:")
        .expect("failed to create sqlite options")
        .create_if_missing(true);
    
    let pool = sqlx::sqlite::SqlitePoolOptions::new()
        .max_connections(5)
        .connect_with(options)
        .await
        .expect("failed to connect to database");
    
    // Run migrations once
    sqlx::migrate!("./migrations")
        .run(&pool)
        .await
        .expect("failed to run migrations");
    
    // Create all states from the same pool
    let account_state = AppState::from_pool(pool.clone());
    let debt_state: DebtAppState = create_debt_default_state_from_pool(pool.clone())
        .await
        .expect("failed to initialize debt command state");
    
    // Clone the pool before debt_state is moved
    let debt_pool = pool.clone();
    
    let currency_state: CurrencyCommandState = create_currency_default_state_from_pool(pool.clone())
        .await
        .expect("failed to initialize currency command state");
    let transaction_state = create_default_state_from_pool(pool.clone())
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
        .plugin(tauri_plugin_store::Builder::new().build())
        .manage(account_state)
        .manage(debt_state)
        .manage(currency_state)
        .manage(transaction_state)
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
            get_sync_status,
            update_sync_settings,
            get_sync_settings
        ])
        .setup(move |app| {
            // Start background sync scheduler
            let scheduler = Arc::new(SyncScheduler::new(app.handle().clone()));
            
            // Update sync_state with scheduler reference
            let sync_state_with_scheduler = sync_state.with_scheduler(Arc::clone(&scheduler));
            app.handle().manage(sync_state_with_scheduler);
            
            scheduler.start();
            
            // Initialize reminder scheduler (manual trigger for now)
            let reminder_repo = Arc::new(SqliteReminderRepository::new(
                debt_pool.clone()
            ));
            let notification_sender = Arc::new(TauriNotificationSender::new(app.handle().clone()));
            let notification_service = Arc::new(NotificationService::new(
                reminder_repo.clone(),
                notification_sender,
            ));
            let _reminder_scheduler = Arc::new(ReminderScheduler::new(
                reminder_repo,
                notification_service,
            ));
            
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
