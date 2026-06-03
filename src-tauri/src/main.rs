mod application;
mod domain;
mod infrastructure;
mod presentation;

use application::services::transaction_template_service::TransactionTemplateService;
use infrastructure::notifications::{NotificationService, TauriNotificationSender};
use infrastructure::reminders::ReminderScheduler;
use infrastructure::schedulers::PrepaidAlertScheduler;
use infrastructure::repositories::{
    SqliteAccountRepository, SqliteReminderRepository,
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
        authorize_cloud_provider, create_backup, create_backup_state, delete_backup,
        get_auto_backup_settings, get_backup_diff, get_backup_metadata, get_cloud_presets,
        get_cloud_settings, list_backups, list_cloud_backups, read_auto_backup_settings,
        restore_backup, save_cloud_settings, test_cloud_connection, update_auto_backup_last_run,
        update_auto_backup_settings, upload_to_cloud,
    },
    budget_commands::{
        add_budget_item, clone_budget_to_month, compute_budget_actuals, create_budget,
        delete_budget, get_budget, get_budget_by_month, list_budgets, remove_budget_item,
        BudgetCommandState,
    },
    cloud_sync_commands::{
        cloud_sync_now, create_cloud_sync_state, get_cloud_sync_settings, get_cloud_sync_status,
        get_sync_status_with_conflicts, resolve_sync_conflict, update_cloud_sync_settings,
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
    },
    export_commands::{create_export_default_state, export_all_data, export_csv},
    goal_commands::{
        complete_goal, create_default_state_from_pool as create_goal_default_state_from_pool,
        create_goal, delete_goal, get_goal, list_goals, sync_goal_progress, update_goal,
        update_goal_progress, GoalCommandState,
    },
    holding_commands::{
        buy_holding, create_default_state_from_pool as create_holding_default_state,
        create_security, delete_holding_trade, fetch_security_price, list_holding_transactions,
        list_holding_transactions_paginated, list_holdings, list_securities, record_dividend,
        record_split, search_securities, sell_holding, update_holding_trade,
        update_security_price, AppState as HoldingCommandState,
    },
    prepaid_commands::{
        create_default_state_from_pool as create_prepaid_default_state, get_prepaid_detail,
        get_top_up_records, top_up, PrepaidCommandState,
    },
    reminder_commands::{
        complete_reminder, create_reminder, create_reminder_default_state_from_pool,
        delete_reminder, get_reminder, list_reminders, update_reminder, ReminderCommandState,
    },
    report_commands::{
        get_balance_sheet, get_dashboard_summary, get_income_statement, get_monthly_trend,
        get_yoy_comparison, ReportCommandState,
    },
    search_commands::{create_search_default_state, global_search, rebuild_search_index},
    sync_commands::{
        create_default_state as create_sync_default_state, get_sync_settings, get_sync_status,
        sync_from_server, sync_to_server, update_sync_settings,
    },
    tag_commands::{
        add_tag_to_transaction,
        create_default_state_from_pool as create_tag_default_state_from_pool, create_tag,
        delete_tag, get_transaction_tags, list_tags, remove_tag_from_transaction, soft_delete_tag,
        update_tag, TagCommandState,
    },
    transaction_commands::{
        batch_delete_transactions, create_default_state_from_pool, create_simple_expense,
        create_simple_income, create_simple_transfer, create_transaction, delete_transaction,
        get_transaction, get_transactions_by_account, get_transactions_by_date_range,
        list_transactions, list_transactions_paginated, update_transaction,
    },
    transaction_template_commands::{
        create_template_default_state_from_pool, create_transaction_template,
        delete_transaction_template, get_transaction_template, list_transaction_templates,
        pause_transaction_template, resume_transaction_template, update_transaction_template,
        list_template_transactions,
        TransactionTemplateCommandState,
    },
};
use sqlx::Row;
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
    let report_state = ReportCommandState::from_pool(pool.clone());

    // Rebuild FTS5 search index on startup to ensure existing data is indexed
    {
        let rebuild_pool = pool.clone();
        tokio::spawn(async move {
            // Check if FTS tables exist and rebuild
            match sqlx::query("SELECT count(*) FROM fts_accounts")
                .fetch_one(&rebuild_pool)
                .await
            {
                Ok(row) => {
                    let count: i64 = row.try_get("count(*)").unwrap_or(0);
                    if count == 0 {
                        info!("FTS5 index is empty, rebuilding from existing data");
                        if let Err(e) =
                            sqlx::query("INSERT INTO fts_accounts(fts_accounts) VALUES('rebuild')")
                                .execute(&rebuild_pool)
                                .await
                        {
                            error!(error = %e, "Failed to rebuild accounts FTS index");
                        }
                        if let Err(e) = sqlx::query(
                            "INSERT INTO fts_transactions(fts_transactions) VALUES('rebuild')",
                        )
                        .execute(&rebuild_pool)
                        .await
                        {
                            error!(error = %e, "Failed to rebuild transactions FTS index");
                        }
                        if let Err(e) =
                            sqlx::query("INSERT INTO fts_debts(fts_debts) VALUES('rebuild')")
                                .execute(&rebuild_pool)
                                .await
                        {
                            error!(error = %e, "Failed to rebuild debts FTS index");
                        }
                        if let Err(e) =
                            sqlx::query("INSERT INTO fts_goals(fts_goals) VALUES('rebuild')")
                                .execute(&rebuild_pool)
                                .await
                        {
                            error!(error = %e, "Failed to rebuild goals FTS index");
                        }
                        if let Err(e) =
                            sqlx::query("INSERT INTO fts_tags(fts_tags) VALUES('rebuild')")
                                .execute(&rebuild_pool)
                                .await
                        {
                            error!(error = %e, "Failed to rebuild tags FTS index");
                        }
                        info!("FTS5 search index rebuilt successfully");
                    } else {
                        info!(
                            "FTS5 index already populated ({} accounts), skipping rebuild",
                            count
                        );
                    }
                }
                Err(e) => {
                    error!(error = %e, "Failed to check FTS index status, skipping rebuild");
                }
            }
        });
    }
    let reminder_state: ReminderCommandState =
        create_reminder_default_state_from_pool(pool.clone())
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
        .manage(template_state)
        .manage(tag_state)
        .manage(search_state)
        .manage(report_state)
        .manage(reminder_state)
        .manage(export_state)
        .manage(encryption_state.clone())
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
            list_holding_transactions_paginated,
            delete_holding_trade,
            update_holding_trade,
            record_dividend,
            record_split,
            search_securities,
            fetch_security_price,
            top_up,
            get_prepaid_detail,
            get_top_up_records,
            create_transaction_template,
            list_transaction_templates,
            get_transaction_template,
            update_transaction_template,
            delete_transaction_template,
            pause_transaction_template,
            resume_transaction_template,
            list_template_transactions,
            create_transaction,
            get_transaction,
            list_transactions,
            list_transactions_paginated,
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
            update_tag,
            soft_delete_tag,
            add_tag_to_transaction,
            remove_tag_from_transaction,
            get_transaction_tags,
            global_search,
            rebuild_search_index,
            get_yoy_comparison,
            get_balance_sheet,
            get_income_statement,
            get_dashboard_summary,
            get_monthly_trend,
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
            authorize_cloud_provider,
            get_auto_backup_settings,
            update_auto_backup_settings,
            sync_to_server,
            sync_from_server,
            get_sync_status,
            update_sync_settings,
            get_sync_settings,
            cloud_sync_now,
            get_cloud_sync_status,
            update_cloud_sync_settings,
            get_cloud_sync_settings,
            get_sync_status_with_conflicts,
            resolve_sync_conflict
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
            let notification_service_for_reschedule = notification_service.clone();
            let reminder_scheduler =
                Arc::new(ReminderScheduler::new(reminder_repo, notification_service));

            // Reschedule pending reminders from previous sessions
            let reschedule_handle = notification_service_for_reschedule;
            tokio::spawn(async move {
                match reschedule_handle.reschedule_all().await {
                    Ok(count) => info!(count = count, "Rescheduled pending reminders"),
                    Err(e) => error!(error = %e, "Failed to reschedule pending reminders"),
                }
            });

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

            // Start prepaid alert scheduler (expiry + low-balance checks)
            {
                let pa_pool = pool.clone();
                tokio::spawn(async move {
                    let scheduler = PrepaidAlertScheduler::new(pa_pool);
                    // Run immediately on startup
                    if let Err(e) = scheduler.run_all_checks().await {
                        error!(error = %e, "Initial prepaid alert check failed");
                    }
                    // Then check every 24 hours
                    let mut interval = tokio::time::interval(tokio::time::Duration::from_secs(86400));
                    loop {
                        interval.tick().await;
                        if let Err(e) = scheduler.run_all_checks().await {
                            error!(error = %e, "Scheduled prepaid alert check failed");
                        }
                    }
                });
            }
            info!("Prepaid alert scheduler started (checking every 24 hours)");

            // Start auto backup scheduler
            {
                let ab_pool = pool.clone();
                let ab_backup_dir = app_dir.join("backups");
                let ab_encryption = encryption_state.clone();
                tokio::spawn(async move {
                    // Check every 30 minutes whether an auto backup is due
                    let mut interval = tokio::time::interval(tokio::time::Duration::from_secs(1800));
                    loop {
                        interval.tick().await;
                        let settings = match read_auto_backup_settings(&ab_pool).await {
                            Ok(s) => s,
                            Err(e) => {
                                error!("Auto backup: failed to read settings: {}", e);
                                continue;
                            }
                        };
                        if !settings.enabled {
                            continue;
                        }
                        // Check if enough time has elapsed since last backup
                        let should_run = match &settings.last_backup_at {
                            None => true,
                            Some(last) => {
                                match chrono::DateTime::parse_from_rfc3339(last) {
                                    Ok(dt) => {
                                        let now: chrono::DateTime<chrono::Utc> = chrono::Utc::now();
                                        let elapsed = now - dt.to_utc();
                                        elapsed.num_hours() >= settings.interval_hours
                                    }
                                    Err(_) => true,
                                }
                            }
                        };
                        if !should_run {
                            continue;
                        }
                        info!("Auto backup: creating scheduled backup");
                        let service = match crate::infrastructure::backup::backup_service::BackupService::new(
                            ab_pool.clone(),
                            ab_backup_dir.clone(),
                        ) {
                            Ok(s) => s,
                            Err(e) => {
                                error!("Auto backup: failed to create service: {}", e);
                                continue;
                            }
                        };
                        let encryption = if ab_encryption.service.is_unlocked() {
                            ab_encryption.service.get_encryption_service()
                        } else {
                            None
                        };
                        match service.create_backup(encryption.as_ref()).await {
                            Ok(info) => {
                                info!(filename = %info.filename, "Auto backup created");
                                // Cleanup old backups, keep last N
                                let max = settings.max_backups.max(1) as usize;
                                if let Ok(all) = service.list_backups() {
                                    if all.len() > max {
                                        for old in all.iter().skip(max) {
                                            if let Err(e) = service.delete_backup(&old.filename) {
                                                error!(filename = %old.filename, error = %e, "Auto backup: failed to delete old backup");
                                            }
                                        }
                                    }
                                }
                                if let Err(e) = update_auto_backup_last_run(&ab_pool).await {
                                    error!("Auto backup: failed to update last run: {}", e);
                                }
                            }
                            Err(e) => {
                                error!("Auto backup: failed to create backup: {}", e);
                            }
                        }
                    }
                });
            }
            info!("Auto backup scheduler started (checking every 30 minutes)");

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
