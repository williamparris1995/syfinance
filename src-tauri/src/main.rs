// Allow unused code during development - many components are not yet integrated
#![allow(dead_code)]
#![allow(unused_imports)]

mod application;
mod domain;
mod infrastructure;
mod presentation;

use application::services::subscription_service::SubscriptionService;
use application::services::transaction_template_service::TransactionTemplateService;
use infrastructure::notifications::{NotificationService, TauriNotificationSender};
use infrastructure::reminders::ReminderScheduler;
use infrastructure::repositories::{
    SqliteAccountRepository, SqliteReminderRepository, SqliteSubscriptionRepository,
    SqliteTransactionRepository, SqliteTransactionTemplateRepository,
};
use infrastructure::sync::SyncScheduler;
use presentation::api::create_sync_routes;
use presentation::tauri_commands::{
    account_commands::{
        create_account, delete_account, get_account, get_account_balance,
        get_account_balance_history, list_accounts, list_accounts_by_ownership,
        list_accounts_with_balances, setup_preset_investment_accounts, update_account, AppState,
    },
    backup_commands::{
        create_backup, create_backup_state, delete_backup, get_backup_diff, get_backup_metadata,
        get_cloud_presets, get_cloud_settings, list_backups, list_cloud_backups, restore_backup,
        save_cloud_settings, test_cloud_connection, upload_to_cloud, BackupCommandState,
    },
    budget_commands::{
        add_budget_item, clone_budget_to_month, compute_budget_actuals, create_budget,
        delete_budget, get_budget, get_budget_by_month, list_budgets, remove_budget_item,
        BudgetCommandState,
    },
    cloud_sync_commands::{
        cloud_sync_now, create_cloud_sync_state, get_cloud_sync_settings, get_cloud_sync_status,
        update_cloud_sync_settings, CloudSyncCommandState,
    },
    currency_commands::{
        add_currency, create_default_state_from_pool as create_currency_default_state_from_pool,
        fetch_exchange_rates, list_currencies, update_currency_rate, CurrencyCommandState,
    },
    debt_commands::{
        create_debt, create_default_state_from_pool as create_debt_default_state_from_pool,
        delete_debt, get_debt, get_upcoming_payments, list_debts, record_payment, update_debt,
        AppState as DebtAppState,
    },
    encryption_commands::{
        create_encryption_default_state, disable_encryption, get_encryption_status,
        lock_encryption, setup_encryption, unlock_encryption, unlock_encryption_keychain,
        EncryptionCommandState,
    },
    export_commands::{create_export_default_state, export_all_data, export_csv, ExportCommandState},
    goal_commands::{
        complete_goal, create_default_state_from_pool as create_goal_default_state_from_pool,
        create_goal, delete_goal, get_goal, list_goals, sync_goal_progress, update_goal,
        update_goal_progress, GoalCommandState,
    },
    holding_commands::{
        buy_holding, create_default_state_from_pool as create_holding_default_state,
        create_security, delete_holding_trade, fetch_security_price, list_holding_transactions,
        list_holdings, list_securities, record_dividend, record_split, search_securities,
        sell_holding, update_holding_trade, update_security_price, AppState as HoldingCommandState,
    },
    prepaid_commands::{
        create_default_state_from_pool as create_prepaid_default_state, get_prepaid_detail,
        get_top_up_records, top_up, PrepaidCommandState,
    },
    reminder_commands::{
        complete_reminder, create_reminder, create_reminder_default_state_from_pool,
        delete_reminder, get_reminder, list_reminders, update_reminder, ReminderCommandState,
    },
    search_commands::{create_search_default_state, global_search, SearchCommandState},
    subscription_commands::{
        create_default_state_from_pool as create_subscription_default_state, create_subscription,
        delete_subscription, get_subscription, list_subscription_transactions, list_subscriptions,
        pause_subscription, resume_subscription, update_subscription, SubscriptionCommandState,
    },
    transaction_template_commands::{
        create_template_default_state_from_pool,
        create_transaction_template, delete_transaction_template, get_transaction_template,
        list_transaction_templates, pause_transaction_template, resume_transaction_template,
        update_transaction_template, TransactionTemplateCommandState,
    },
    sync_commands::{
        create_default_state as create_sync_default_state, get_sync_settings, get_sync_status,
        sync_from_server, sync_to_server, update_sync_settings,
    },
    tag_commands::{
        add_tag_to_transaction,
        create_default_state_from_pool as create_tag_default_state_from_pool, create_tag,
        delete_tag, get_transaction_tags, list_tags, remove_tag_from_transaction, TagCommandState,
    },
    transaction_commands::{
        batch_delete_transactions, create_default_state_from_pool, create_simple_expense,
        create_simple_income, create_simple_transfer, create_transaction, delete_transaction,
        get_transaction, get_transactions_by_account, get_transactions_by_date_range,
        list_transactions, update_transaction,
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
    let budget_state = BudgetCommandState::from_pool(pool.clone());
    let debt_state: DebtAppState = create_debt_default_state_from_pool(pool.clone())
        .await
        .expect("failed to initialize debt command state");
    let holding_state: HoldingCommandState = create_holding_default_state(pool.clone())
        .await
        .expect("failed to initialize holding command state");
    let prepaid_state: PrepaidCommandState = create_prepaid_default_state(pool.clone())
        .await
        .expect("failed to initialize prepaid command state");
    let subscription_state: SubscriptionCommandState =
        create_subscription_default_state(pool.clone())
            .await
            .expect("failed to initialize subscription command state");
    let template_state: TransactionTemplateCommandState =
        create_template_default_state_from_pool(pool.clone())
            .await
            .expect("failed to initialize transaction template command state");

    // Clone the pool before debt_state is moved
    let debt_pool = pool.clone();

    let currency_state: CurrencyCommandState =
        create_currency_default_state_from_pool(pool.clone())
            .await
            .expect("failed to initialize currency command state");
    let goal_state: GoalCommandState = create_goal_default_state_from_pool(pool.clone())
        .await
        .expect("failed to initialize goal command state");
    let transaction_state = create_default_state_from_pool(pool.clone())
        .await
        .expect("failed to initialize transaction command state");
    let tag_state: TagCommandState = create_tag_default_state_from_pool(pool.clone())
        .await
        .expect("failed to initialize tag command state");
    let search_state = create_search_default_state(pool.clone());
    let reminder_state: ReminderCommandState = create_reminder_default_state_from_pool(pool.clone())
        .await
        .expect("failed to initialize reminder command state");
    let export_state = create_export_default_state(pool.clone());
    let encryption_state = create_encryption_default_state(pool.clone());
    let encryption_service = encryption_state.service.clone();
    let sync_state = create_sync_default_state();
    let backup_state = create_backup_state(
        pool.clone(),
        app_dir.join("backups"),
        encryption_state.service.clone(),
    );
    let cloud_sync_state = create_cloud_sync_state(
        pool.clone(),
        app_dir.join("backups"),
        encryption_state.service.clone(),
    );

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
        .plugin(tauri_plugin_dialog::init())
        .manage(account_state)
        .manage(budget_state)
        .manage(debt_state)
        .manage(currency_state)
        .manage(goal_state)
        .manage(transaction_state)
        .manage(holding_state)
        .manage(prepaid_state)
        .manage(subscription_state)
        .manage(template_state)
        .manage(tag_state)
        .manage(search_state)
        .manage(reminder_state)
        .manage(export_state)
        .manage(encryption_state)
        .manage(backup_state)
        .manage(cloud_sync_state)
        .invoke_handler(tauri::generate_handler![
            create_account,
            update_account,
            delete_account,
            get_account,
            list_accounts,
            list_accounts_by_ownership,
            list_accounts_with_balances,
            get_account_balance,
            get_account_balance_history,
            setup_preset_investment_accounts,
            list_budgets,
            get_budget,
            get_budget_by_month,
            create_budget,
            add_budget_item,
            delete_budget,
            remove_budget_item,
            compute_budget_actuals,
            clone_budget_to_month,
            list_currencies,
            add_currency,
            update_currency_rate,
            fetch_exchange_rates,
            create_debt,
            update_debt,
            delete_debt,
            get_debt,
            list_debts,
            record_payment,
            get_upcoming_payments,
            create_security,
            list_securities,
            update_security_price,
            buy_holding,
            sell_holding,
            list_goals,
            get_goal,
            create_goal,
            update_goal,
            update_goal_progress,
            complete_goal,
            delete_goal,
            sync_goal_progress,
            list_holdings,
            list_holding_transactions,
            delete_holding_trade,
            update_holding_trade,
            record_dividend,
            record_split,
            search_securities,
            fetch_security_price,
            top_up,
            get_prepaid_detail,
            get_top_up_records,
            create_subscription,
            list_subscriptions,
            get_subscription,
            update_subscription,
            delete_subscription,
            pause_subscription,
            resume_subscription,
            list_subscription_transactions,
            create_transaction_template,
            list_transaction_templates,
            get_transaction_template,
            update_transaction_template,
            delete_transaction_template,
            pause_transaction_template,
            resume_transaction_template,
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
            batch_delete_transactions,
            list_tags,
            create_tag,
            delete_tag,
            add_tag_to_transaction,
            remove_tag_from_transaction,
            get_transaction_tags,
            global_search,
            list_reminders,
            get_reminder,
            create_reminder,
            update_reminder,
            delete_reminder,
            complete_reminder,
            export_all_data,
            export_csv,
            get_encryption_status,
            setup_encryption,
            unlock_encryption,
            unlock_encryption_keychain,
            lock_encryption,
            disable_encryption,
            create_backup,
            list_backups,
            get_backup_metadata,
            get_backup_diff,
            delete_backup,
            restore_backup,
            get_cloud_presets,
            get_cloud_settings,
            save_cloud_settings,
            test_cloud_connection,
            upload_to_cloud,
            list_cloud_backups,
            sync_to_server,
            sync_from_server,
            get_sync_status,
            update_sync_settings,
            get_sync_settings,
            cloud_sync_now,
            get_cloud_sync_status,
            update_cloud_sync_settings,
            get_cloud_sync_settings
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

            // Start subscription auto-record scheduler
            let sub_pool = pool.clone();
            tokio::spawn(async move {
                let sub_repo = Arc::new(SqliteSubscriptionRepository::new(sub_pool.clone()));
                let sub_acc_repo = Arc::new(SqliteAccountRepository::new(sub_pool.clone()));
                let sub_tx_repo = Arc::new(SqliteTransactionRepository::new(sub_pool.clone()));
                let sub_svc = SubscriptionService::new(sub_repo, sub_acc_repo, sub_tx_repo);
                let mut interval = tokio::time::interval(tokio::time::Duration::from_secs(300));
                loop {
                    interval.tick().await;
                    let today = chrono::Utc::now().date_naive();
                    if let Err(e) = sub_svc.process_due_subscriptions(today).await {
                        error!("Failed to process subscriptions: {}", e);
                    }
                }
            });
            info!("Subscription scheduler started (checking every 5 minutes)");

            // Start transaction template auto-record scheduler
            let tpl_pool = pool.clone();
            tokio::spawn(async move {
                let tpl_repo = Arc::new(SqliteTransactionTemplateRepository::new(tpl_pool.clone()));
                let tpl_acc_repo = Arc::new(SqliteAccountRepository::new(tpl_pool.clone()));
                let tpl_tx_repo = Arc::new(SqliteTransactionRepository::new(tpl_pool.clone()));
                let tpl_svc = TransactionTemplateService::new(tpl_repo, tpl_acc_repo, tpl_tx_repo);
                let mut interval = tokio::time::interval(tokio::time::Duration::from_secs(300));
                loop {
                    interval.tick().await;
                    let today = chrono::Utc::now().date_naive();
                    if let Err(e) = tpl_svc.process_due_templates(today).await {
                        error!("Failed to process transaction templates: {}", e);
                    }
                }
            });
            info!("Transaction template scheduler started (checking every 5 minutes)");

            // Start cloud sync scheduler
            {
                let cloud_pool = pool.clone();
                let cloud_backup_dir = app_dir.join("backups");
                let svc = Arc::new(
                    crate::infrastructure::sync::cloud_sync_service::CloudSyncService::new(
                        cloud_pool,
                        cloud_backup_dir,
                        encryption_service.clone(),
                    ),
                );
                let scheduler = Arc::new(
                    crate::infrastructure::sync::cloud_sync_scheduler::CloudSyncScheduler::new(
                        app.handle().clone(),
                        svc,
                    ),
                );
                scheduler.start();
            }

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
