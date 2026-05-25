use chrono::NaiveDate;
use finance_app::application::dtos::CreateTransactionDto;
use finance_app::application::dtos::transaction_dto::CreateTransactionEntryDto;
use finance_app::application::services::TransactionService;
use finance_app::domain::{
    aggregates::{Account, AccountType, Ownership},
    repositories::AccountRepository,
    value_objects::{Currency, Money, SyncMetadata},
};
use finance_app::infrastructure::repositories::{
    SqliteAccountRepository, SqliteTransactionRepository,
};
use finance_app::presentation::tauri_commands::transaction_commands::{
    create_transaction_with_service, get_transaction_with_service,
    get_transactions_by_account_with_service, get_transactions_by_date_range_with_service,
    list_transactions_with_service,
};
use rust_decimal::Decimal;
use sqlx::sqlite::{SqliteConnectOptions, SqlitePoolOptions};
use std::{str::FromStr, sync::Arc};
use uuid::Uuid;

async fn setup_test_db() -> sqlx::SqlitePool {
    let options = SqliteConnectOptions::from_str("sqlite::memory:")
        .unwrap()
        .create_if_missing(true);

    let pool = SqlitePoolOptions::new()
        .max_connections(1)
        .connect_with(options)
        .await
        .unwrap();

    sqlx::migrate!("./migrations").run(&pool).await.unwrap();

    pool
}

fn create_test_account(currency_code: &str) -> Account {
    Account::new(
        Uuid::new_v4(),
        "Test Account",
        AccountType::Bank,
        Ownership::Own,
        &Currency::new(currency_code, currency_code, Decimal::ONE).unwrap(),
        Money::new(Decimal::new(1000_00, 2), currency_code).unwrap(),
        "💰",
        "#10B981",
        None,
        None,
        SyncMetadata::new(Uuid::new_v4()),
    )
    .unwrap()
}

async fn setup_service() -> (Arc<TransactionService>, Arc<SqliteAccountRepository>) {
    let pool = setup_test_db().await;
    let account_repo = Arc::new(SqliteAccountRepository::new(pool.clone()));
    let transaction_repo = Arc::new(SqliteTransactionRepository::new(pool.clone()));
    let service = Arc::new(TransactionService::new(
        transaction_repo.clone(),
        account_repo.clone(),
    ));

    (service, account_repo)
}

async fn seed_two_accounts(account_repo: &Arc<SqliteAccountRepository>) -> (Account, Account) {
    let account1 = create_test_account("CNY");
    let account2 = create_test_account("CNY");
    account_repo.create(&account1).await.unwrap();
    account_repo.create(&account2).await.unwrap();
    (account1, account2)
}

#[tokio::test]
async fn create_transaction_with_multiple_entries_updates_balances() {
    let (service, account_repo) = setup_service().await;
    let (account1, account2) = seed_two_accounts(&account_repo).await;

    let dto = CreateTransactionDto {
        transaction_date: NaiveDate::from_ymd_opt(2026, 4, 8).unwrap(),
        description: "Transfer".to_string(),
        entries: vec![
            CreateTransactionEntryDto {
                account_id: account1.id,
                chart_of_account_code: "1002".to_string(),
                debit_amount: Some(Decimal::new(500_00, 2)),
                credit_amount: None,
                memo: Some("Debit entry".to_string()),
            },
            CreateTransactionEntryDto {
                account_id: account2.id,
                chart_of_account_code: "1002".to_string(),
                debit_amount: None,
                credit_amount: Some(Decimal::new(500_00, 2)),
                memo: Some("Credit entry".to_string()),
            },
        ],
    };

    let transaction_id = create_transaction_with_service(service.as_ref(), dto)
        .await
        .unwrap();

    let updated_account1 = account_repo.find_by_id(account1.id).await.unwrap().unwrap();
    let updated_account2 = account_repo.find_by_id(account2.id).await.unwrap().unwrap();

    assert_ne!(transaction_id, Uuid::nil());
    assert_eq!(updated_account1.initial_balance.amount, Decimal::new(1000_00, 2));
    assert_eq!(updated_account2.initial_balance.amount, Decimal::new(1000_00, 2));
}

#[tokio::test]
async fn get_transaction_returns_created_transaction() {
    let (service, account_repo) = setup_service().await;
    let (account1, account2) = seed_two_accounts(&account_repo).await;

    let dto = CreateTransactionDto {
        transaction_date: NaiveDate::from_ymd_opt(2026, 4, 8).unwrap(),
        description: "Test Transaction".to_string(),
        entries: vec![
            CreateTransactionEntryDto {
                account_id: account1.id,
                chart_of_account_code: "1002".to_string(),
                debit_amount: Some(Decimal::new(100_00, 2)),
                credit_amount: None,
                memo: None,
            },
            CreateTransactionEntryDto {
                account_id: account2.id,
                chart_of_account_code: "1002".to_string(),
                debit_amount: None,
                credit_amount: Some(Decimal::new(100_00, 2)),
                memo: None,
            },
        ],
    };

    let transaction_id = create_transaction_with_service(service.as_ref(), dto)
        .await
        .unwrap();
    let retrieved = get_transaction_with_service(service.as_ref(), transaction_id)
        .await
        .unwrap();

    assert_eq!(retrieved.id, transaction_id);
    assert_eq!(retrieved.description, "Test Transaction");
    assert_eq!(retrieved.entries.len(), 2);
}

#[tokio::test]
async fn list_transactions_returns_saved_transactions() {
    let (service, account_repo) = setup_service().await;
    let (account1, account2) = seed_two_accounts(&account_repo).await;

    let dto = CreateTransactionDto {
        transaction_date: NaiveDate::from_ymd_opt(2026, 4, 8).unwrap(),
        description: "Transaction 1".to_string(),
        entries: vec![
            CreateTransactionEntryDto {
                account_id: account1.id,
                chart_of_account_code: "1002".to_string(),
                debit_amount: Some(Decimal::new(100_00, 2)),
                credit_amount: None,
                memo: None,
            },
            CreateTransactionEntryDto {
                account_id: account2.id,
                chart_of_account_code: "1002".to_string(),
                debit_amount: None,
                credit_amount: Some(Decimal::new(100_00, 2)),
                memo: None,
            },
        ],
    };

    create_transaction_with_service(service.as_ref(), dto)
        .await
        .unwrap();

    let transactions = list_transactions_with_service(service.as_ref())
        .await
        .unwrap();
    assert_eq!(transactions.len(), 1);
}

#[tokio::test]
async fn get_transactions_by_account_filters_results() {
    let (service, account_repo) = setup_service().await;
    let (account1, account2) = seed_two_accounts(&account_repo).await;

    let dto = CreateTransactionDto {
        transaction_date: NaiveDate::from_ymd_opt(2026, 4, 8).unwrap(),
        description: "Account filter".to_string(),
        entries: vec![
            CreateTransactionEntryDto {
                account_id: account1.id,
                chart_of_account_code: "1002".to_string(),
                debit_amount: Some(Decimal::new(200_00, 2)),
                credit_amount: None,
                memo: None,
            },
            CreateTransactionEntryDto {
                account_id: account2.id,
                chart_of_account_code: "1002".to_string(),
                debit_amount: None,
                credit_amount: Some(Decimal::new(200_00, 2)),
                memo: None,
            },
        ],
    };

    let transaction_id = create_transaction_with_service(service.as_ref(), dto)
        .await
        .unwrap();

    let transactions = get_transactions_by_account_with_service(service.as_ref(), account1.id)
        .await
        .unwrap();

    assert_eq!(transactions.len(), 1);
    assert_eq!(transactions[0].id, transaction_id);
}

#[tokio::test]
async fn get_transactions_by_date_range_filters_results() {
    let (service, account_repo) = setup_service().await;
    let (account1, account2) = seed_two_accounts(&account_repo).await;

    let dto = CreateTransactionDto {
        transaction_date: NaiveDate::from_ymd_opt(2026, 4, 8).unwrap(),
        description: "April Transaction".to_string(),
        entries: vec![
            CreateTransactionEntryDto {
                account_id: account1.id,
                chart_of_account_code: "1002".to_string(),
                debit_amount: Some(Decimal::new(300_00, 2)),
                credit_amount: None,
                memo: None,
            },
            CreateTransactionEntryDto {
                account_id: account2.id,
                chart_of_account_code: "1002".to_string(),
                debit_amount: None,
                credit_amount: Some(Decimal::new(300_00, 2)),
                memo: None,
            },
        ],
    };

    create_transaction_with_service(service.as_ref(), dto)
        .await
        .unwrap();

    let transactions = get_transactions_by_date_range_with_service(
        service.as_ref(),
        NaiveDate::from_ymd_opt(2026, 4, 1).unwrap(),
        NaiveDate::from_ymd_opt(2026, 4, 30).unwrap(),
    )
    .await
    .unwrap();

    assert_eq!(transactions.len(), 1);
}
