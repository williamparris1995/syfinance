// Allow unused code during development - many components are not yet integrated
#![allow(dead_code)]
#![allow(unused_imports)]

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
        list_accounts_by_ownership, list_accounts_with_balances, update_account, AppState,
    },
    currency_commands::{
        add_currency, create_default_state_from_pool as create_currency_default_state_from_pool,
        list_currencies, update_currency_rate, CurrencyCommandState,
    },
    debt_commands::{
        create_debt, create_default_state_from_pool as create_debt_default_state_from_pool,
        delete_debt, get_debt, get_upcoming_payments, list_debts, record_payment,
        update_debt, AppState as DebtAppState,
    },
    sync_commands::{
        create_default_state as create_sync_default_state, get_sync_settings, get_sync_status,
        sync_from_server, sync_to_server, update_sync_settings,
    },
    transaction_commands::{
        create_default_state_from_pool, create_simple_expense, create_simple_income,
        create_simple_transfer, create_transaction, get_transaction,
        get_transactions_by_account, get_transactions_by_date_range, list_transactions,
        update_transaction, delete_transaction,
    },
};
use sqlx::sqlite::SqlitePool;
use std::str::FromStr;
use std::sync::Arc;
use tauri::Manager;
use tracing::{error, info};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() {
    // Get app data directory for persistent storage
    let app_data_dir = std::env::var("APPDATA")
        .or_else(|_| std::env::var("HOME").map(|h| format!("{}/.local/share", h)))
        .unwrap_or_else(|_| ".".to_string());

    let app_dir = std::path::Path::new(&app_data_dir).join("finance-app");
    std::fs::create_dir_all(&app_dir).expect("failed to create app data directory");

    // Initialize logging with file output
    let log_dir = app_dir.join("logs");
    std::fs::create_dir_all(&log_dir).expect("failed to create logs directory");

    let file_appender = tracing_appender::rolling::daily(log_dir, "finance-app.log");
    let (non_blocking, _guard) = tracing_appender::non_blocking(file_appender);

    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info,finance_app=debug".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .with(tracing_subscriber::fmt::layer().with_writer(non_blocking))
        .init();

    info!("Finance app starting...");

    let db_dir = &app_dir;
    let db_path = db_dir.join("finance.db");
    let db_url = format!("sqlite:{}", db_path.display());

    info!("Using database at: {}", db_path.display());

    // Run migrations with FK checks disabled (PRAGMA is no-op inside transactions)
    let migrate_options = sqlx::sqlite::SqliteConnectOptions::from_str(&db_url)
        .expect("failed to create sqlite options")
        .create_if_missing(true)
        .foreign_keys(false);

    let migrate_pool = sqlx::sqlite::SqlitePoolOptions::new()
        .max_connections(1)
        .connect_with(migrate_options)
        .await
        .expect("failed to connect to migration database");

    sqlx::migrate!("./migrations")
        .run(&migrate_pool)
        .await
        .expect("failed to run migrations");

    drop(migrate_pool);

    // Create the real pool with FK enforcement enabled
    let options = sqlx::sqlite::SqliteConnectOptions::from_str(&db_url)
        .expect("failed to create sqlite options")
        .create_if_missing(true)
        .foreign_keys(true);

    let pool = sqlx::sqlite::SqlitePoolOptions::new()
        .max_connections(5)
        .connect_with(options)
        .await
        .expect("failed to connect to database");

    // Create all states from the same pool
    let account_state = AppState::from_pool(pool.clone());
    let debt_state: DebtAppState = create_debt_default_state_from_pool(pool.clone())
        .await
        .expect("failed to initialize debt command state");

    // Clone the pool before debt_state is moved
    let debt_pool = pool.clone();

    let currency_state: CurrencyCommandState =
        create_currency_default_state_from_pool(pool.clone())
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
        info!("REST API server listening on http://127.0.0.1:3000");
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
            list_accounts_by_ownership,
            list_accounts_with_balances,
            get_account_balance,
            list_currencies,
            add_currency,
            update_currency_rate,
            create_debt,
            get_debt,
            list_debts,
            record_payment,
            get_upcoming_payments,
            update_debt,
            delete_debt,
            create_transaction,
            get_transaction,
            list_transactions,
            get_transactions_by_account,
            get_transactions_by_date_range,
            create_simple_income,
            create_simple_expense,
            create_simple_transfer,
            update_transaction,
            delete_transaction,
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

            // Start reminder scheduler with periodic checks
            let reminder_repo = Arc::new(SqliteReminderRepository::new(debt_pool.clone()));
            let notification_sender = Arc::new(TauriNotificationSender::new(app.handle().clone()));
            let notification_service = Arc::new(NotificationService::new(
                reminder_repo.clone(),
                notification_sender,
            ));
            let reminder_scheduler =
                Arc::new(ReminderScheduler::new(reminder_repo, notification_service));

            // Spawn background task to check reminders every 5 minutes
            tokio::spawn(async move {
                let mut interval = tokio::time::interval(tokio::time::Duration::from_secs(300)); // 5 minutes
                loop {
                    interval.tick().await;
                    if let Err(e) = reminder_scheduler.check_and_trigger_reminders().await {
                        error!("Failed to check reminders: {}", e);
                    }
                }
            });

            info!("Reminder scheduler started (checking every 5 minutes)");

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
