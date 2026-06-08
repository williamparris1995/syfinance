use finance_app::{
    domain::{repositories::CurrencyRepository, value_objects::Currency},
    infrastructure::repositories::currency_repository::SqliteCurrencyRepository,
};
use rust_decimal::Decimal;
use sqlx::sqlite::{SqliteConnectOptions, SqlitePoolOptions};
use std::{path::PathBuf, str::FromStr};

async fn setup_repository() -> (SqliteCurrencyRepository, PathBuf) {
    let db_path = PathBuf::from("test.db");
    let _ = std::fs::remove_file(&db_path);

    let options = SqliteConnectOptions::new()
        .filename(&db_path)
        .create_if_missing(true)
        .foreign_keys(false);

    let pool = SqlitePoolOptions::new()
        .max_connections(1)
        .connect_with(options)
        .await
        .expect("failed to create SQLite pool");

    sqlx::migrate!("./migrations")
        .run(&pool)
        .await
        .expect("failed to run migrations");

    sqlx::query("DELETE FROM currencies")
        .execute(&pool)
        .await
        .expect("failed to clear seed currencies");

    (SqliteCurrencyRepository::new(pool), db_path)
}

#[tokio::test]
async fn currency_repository_crud() {
    let (repository, _db_path) = setup_repository().await;

    let currency = Currency::new(
        "CNY",
        "CNY",
        "RMB",
        "RMB",
        Decimal::from_str("7.1000").unwrap(),
    )
    .unwrap();

    repository.create(&currency).await.unwrap();

    let found = repository.find_by_code("CNY").await.unwrap().unwrap();
    assert_eq!(found, currency);

    let listed = repository.list_all().await.unwrap();
    assert_eq!(listed, vec![currency.clone()]);

    let updated = repository
        .update_rate("CNY", Decimal::from_str("7.2500").unwrap())
        .await
        .unwrap();
    assert!(updated);

    let refreshed = repository.find_by_code("CNY").await.unwrap().unwrap();
    assert_eq!(
        refreshed.exchange_rate,
        Decimal::from_str("7.2500").unwrap()
    );
}
