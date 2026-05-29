use chrono::NaiveDate;
use finance_app::domain::{
    aggregates::Transaction,
    repositories::TransactionRepository,
    value_objects::{Money, SyncMetadata, TransactionEntry},
};
use finance_app::infrastructure::repositories::SqliteTransactionRepository;
use rust_decimal::Decimal;
use sqlx::sqlite::SqlitePoolOptions;
use uuid::Uuid;

async fn setup_test_db() -> sqlx::SqlitePool {
    let pool = SqlitePoolOptions::new()
        .connect("sqlite::memory:")
        .await
        .unwrap();

    // Create transactions table
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS transactions (
            id TEXT PRIMARY KEY NOT NULL,
            transaction_date DATE NOT NULL,
            description TEXT,
            deleted_at TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            device_id TEXT,
            synced_at TIMESTAMP
        )
        "#,
    )
    .execute(&pool)
    .await
    .unwrap();

    // Create transaction_entries table
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS transaction_entries (
            id TEXT PRIMARY KEY NOT NULL,
            transaction_id TEXT NOT NULL,
            account_id TEXT NOT NULL,
            chart_of_account_code VARCHAR(10) NOT NULL,
            debit_amount DECIMAL(20,2),
            credit_amount DECIMAL(20,2),
            note TEXT,
            deleted_at TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            device_id TEXT,
            synced_at TIMESTAMP,
            FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE RESTRICT
        )
        "#,
    )
    .execute(&pool)
    .await
    .unwrap();

    // Create accounts table for currency lookup
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS accounts (
            id TEXT PRIMARY KEY NOT NULL,
            name VARCHAR(100) NOT NULL,
            account_type VARCHAR(20) NOT NULL,
            chart_of_account_code VARCHAR(10) NOT NULL,
            currency_code VARCHAR(3) NOT NULL,
            balance DECIMAL(20,2) NOT NULL,
            deleted_at TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            device_id TEXT,
            synced_at TIMESTAMP
        )
        "#,
    )
    .execute(&pool)
    .await
    .unwrap();

    pool
}

fn money(amount: i64, currency_code: &str) -> Money {
    Money::new(Decimal::new(amount, 2), currency_code).unwrap()
}

fn debit_entry(account_id: Uuid, amount: i64, currency_code: &str) -> TransactionEntry {
    TransactionEntry::new(
        account_id,
        "1002",
        Some(money(amount, currency_code)),
        None,
        "debit entry",
    )
    .unwrap()
}

fn credit_entry(account_id: Uuid, amount: i64, currency_code: &str) -> TransactionEntry {
    TransactionEntry::new(
        account_id,
        "4001",
        None,
        Some(money(amount, currency_code)),
        "credit entry",
    )
    .unwrap()
}

async fn create_test_account(pool: &sqlx::SqlitePool, currency_code: &str) -> Uuid {
    let account_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO accounts (
            id, name, account_type, chart_of_account_code,
            currency_code, balance, updated_at, device_id
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        "#,
    )
    .bind(account_id.to_string())
    .bind("Test Account")
    .bind("bank")
    .bind("1002")
    .bind(currency_code)
    .bind("0.00")
    .bind(chrono::Utc::now().to_rfc3339())
    .bind(Uuid::new_v4().to_string())
    .execute(pool)
    .await
    .unwrap();

    account_id
}

#[tokio::test]
async fn test_atomic_transaction_save() {
    let pool = setup_test_db().await;
    let repo = SqliteTransactionRepository::new(pool.clone());

    let account1 = create_test_account(&pool, "USD").await;
    let account2 = create_test_account(&pool, "USD").await;

    let transaction = Transaction::new(
        Uuid::new_v4(),
        NaiveDate::from_ymd_opt(2026, 4, 7).unwrap(),
        "Salary payment",
        vec![
            debit_entry(account1, 500_000, "USD"),
            credit_entry(account2, 500_000, "USD"),
        ],
        SyncMetadata::new(Uuid::new_v4()),
    )
    .unwrap();

    let transaction_id = transaction.id;

    // Save transaction atomically
    repo.create(&transaction).await.unwrap();

    // Verify transaction was saved
    let found = repo.find_by_id(transaction_id).await.unwrap();
    assert!(found.is_some());

    let found = found.unwrap();
    assert_eq!(found.id, transaction_id);
    assert_eq!(found.description, "Salary payment");
    assert_eq!(found.entries.len(), 2);
    assert!(found.is_balanced());
}

#[tokio::test]
async fn test_find_by_id_with_entries() {
    let pool = setup_test_db().await;
    let repo = SqliteTransactionRepository::new(pool.clone());

    let account1 = create_test_account(&pool, "USD").await;
    let account2 = create_test_account(&pool, "USD").await;

    let transaction = Transaction::new(
        Uuid::new_v4(),
        NaiveDate::from_ymd_opt(2026, 4, 7).unwrap(),
        "Test transaction",
        vec![
            debit_entry(account1, 10_0000, "USD"),
            credit_entry(account2, 10_0000, "USD"),
        ],
        SyncMetadata::new(Uuid::new_v4()),
    )
    .unwrap();

    let transaction_id = transaction.id;
    repo.create(&transaction).await.unwrap();

    // Find by ID should load all entries
    let found = repo.find_by_id(transaction_id).await.unwrap().unwrap();
    assert_eq!(found.entries.len(), 2);
    assert_eq!(found.entries[0].account_id, account1);
    assert_eq!(found.entries[1].account_id, account2);
}

#[tokio::test]
async fn test_find_by_date_range() {
    let pool = setup_test_db().await;
    let repo = SqliteTransactionRepository::new(pool.clone());

    let account1 = create_test_account(&pool, "USD").await;
    let account2 = create_test_account(&pool, "USD").await;

    // Create transactions on different dates
    let tx1 = Transaction::new(
        Uuid::new_v4(),
        NaiveDate::from_ymd_opt(2026, 4, 1).unwrap(),
        "April 1",
        vec![
            debit_entry(account1, 10_000, "USD"),
            credit_entry(account2, 10_000, "USD"),
        ],
        SyncMetadata::new(Uuid::new_v4()),
    )
    .unwrap();

    let tx2 = Transaction::new(
        Uuid::new_v4(),
        NaiveDate::from_ymd_opt(2026, 4, 15).unwrap(),
        "April 15",
        vec![
            debit_entry(account1, 20_000, "USD"),
            credit_entry(account2, 20_000, "USD"),
        ],
        SyncMetadata::new(Uuid::new_v4()),
    )
    .unwrap();

    let tx3 = Transaction::new(
        Uuid::new_v4(),
        NaiveDate::from_ymd_opt(2026, 5, 1).unwrap(),
        "May 1",
        vec![
            debit_entry(account1, 30_000, "USD"),
            credit_entry(account2, 30_000, "USD"),
        ],
        SyncMetadata::new(Uuid::new_v4()),
    )
    .unwrap();

    repo.create(&tx1).await.unwrap();
    repo.create(&tx2).await.unwrap();
    repo.create(&tx3).await.unwrap();

    // Query April transactions
    let april_txs = repo
        .find_by_date_range(
            NaiveDate::from_ymd_opt(2026, 4, 1).unwrap(),
            NaiveDate::from_ymd_opt(2026, 4, 30).unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(april_txs.len(), 2);
    assert_eq!(april_txs[0].description, "April 15"); // DESC order
    assert_eq!(april_txs[1].description, "April 1");
}

#[tokio::test]
async fn test_find_all() {
    let pool = setup_test_db().await;
    let repo = SqliteTransactionRepository::new(pool.clone());

    let account1 = create_test_account(&pool, "USD").await;
    let account2 = create_test_account(&pool, "USD").await;

    let tx1 = Transaction::new(
        Uuid::new_v4(),
        NaiveDate::from_ymd_opt(2026, 4, 1).unwrap(),
        "Transaction 1",
        vec![
            debit_entry(account1, 10_000, "USD"),
            credit_entry(account2, 10_000, "USD"),
        ],
        SyncMetadata::new(Uuid::new_v4()),
    )
    .unwrap();

    let tx2 = Transaction::new(
        Uuid::new_v4(),
        NaiveDate::from_ymd_opt(2026, 4, 2).unwrap(),
        "Transaction 2",
        vec![
            debit_entry(account1, 20_000, "USD"),
            credit_entry(account2, 20_000, "USD"),
        ],
        SyncMetadata::new(Uuid::new_v4()),
    )
    .unwrap();

    repo.create(&tx1).await.unwrap();
    repo.create(&tx2).await.unwrap();

    let all = repo.find_all().await.unwrap();
    assert_eq!(all.len(), 2);
}

#[tokio::test]
async fn test_soft_delete() {
    let pool = setup_test_db().await;
    let repo = SqliteTransactionRepository::new(pool.clone());

    let account1 = create_test_account(&pool, "USD").await;
    let account2 = create_test_account(&pool, "USD").await;

    let transaction = Transaction::new(
        Uuid::new_v4(),
        NaiveDate::from_ymd_opt(2026, 4, 7).unwrap(),
        "To be deleted",
        vec![
            debit_entry(account1, 10_000, "USD"),
            credit_entry(account2, 10_000, "USD"),
        ],
        SyncMetadata::new(Uuid::new_v4()),
    )
    .unwrap();

    let transaction_id = transaction.id;
    repo.create(&transaction).await.unwrap();

    // Soft delete
    let deleted = repo.soft_delete(transaction_id).await.unwrap();
    assert!(deleted);

    // Should not be found
    let found = repo.find_by_id(transaction_id).await.unwrap();
    assert!(found.is_none());

    // Verify entries are also soft deleted
    let entry_count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM transaction_entries WHERE transaction_id = ? AND deleted_at IS NULL",
    )
    .bind(transaction_id.to_string())
    .fetch_one(&pool)
    .await
    .unwrap();

    assert_eq!(entry_count, 0);
}

#[tokio::test]
async fn test_soft_delete_nonexistent() {
    let pool = setup_test_db().await;
    let repo = SqliteTransactionRepository::new(pool);

    let deleted = repo.soft_delete(Uuid::new_v4()).await.unwrap();
    assert!(!deleted);
}
