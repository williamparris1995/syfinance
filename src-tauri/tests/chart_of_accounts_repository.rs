use finance_app::{
    domain::{
        aggregates::{BalanceDirection, ChartOfAccounts, ChartOfAccountsType},
        repositories::ChartOfAccountsRepository,
    },
    infrastructure::repositories::SqliteChartOfAccountsRepository,
};
use sqlx::sqlite::{SqliteConnectOptions, SqlitePoolOptions};
use uuid::Uuid;

async fn setup_repository() -> SqliteChartOfAccountsRepository {
    let db_path = format!("test_chart_of_accounts_{}.db", Uuid::new_v4());
    let _ = std::fs::remove_file(&db_path);

    let options = SqliteConnectOptions::new()
        .filename(&db_path)
        .create_if_missing(true);

    let pool = SqlitePoolOptions::new()
        .max_connections(1)
        .connect_with(options)
        .await
        .expect("failed to create SQLite pool");

    sqlx::migrate!("./migrations")
        .run(&pool)
        .await
        .expect("failed to run migrations");

    SqliteChartOfAccountsRepository::new(pool)
}

#[tokio::test]
async fn test_seed_data_level1_accounts() {
    let repository = setup_repository().await;

    let level1_accounts = repository.list_by_level(1).await.unwrap();
    
    assert_eq!(level1_accounts.len(), 5, "Should have 5 level 1 accounts");
    
    let codes: Vec<String> = level1_accounts.iter().map(|a| a.code.clone()).collect();
    assert!(codes.contains(&"1000".to_string()), "Should have 资产 (1000)");
    assert!(codes.contains(&"2000".to_string()), "Should have 负债 (2000)");
    assert!(codes.contains(&"3000".to_string()), "Should have 权益 (3000)");
    assert!(codes.contains(&"4000".to_string()), "Should have 收入 (4000)");
    assert!(codes.contains(&"5000".to_string()), "Should have 支出 (5000)");
}

#[tokio::test]
async fn test_seed_data_level2_accounts() {
    let repository = setup_repository().await;

    let level2_accounts = repository.list_by_level(2).await.unwrap();
    
    assert!(level2_accounts.len() >= 8, "Should have at least 8 level 2 accounts");
    
    let codes: Vec<String> = level2_accounts.iter().map(|a| a.code.clone()).collect();
    assert!(codes.contains(&"1001".to_string()), "Should have 库存现金 (1001)");
    assert!(codes.contains(&"1002".to_string()), "Should have 银行存款 (1002)");
    assert!(codes.contains(&"1012".to_string()), "Should have 其他货币资金 (1012)");
}

#[tokio::test]
async fn test_hierarchical_query_get_children() {
    let repository = setup_repository().await;

    let children = repository.get_children("1000").await.unwrap();
    
    assert!(children.len() >= 3, "资产 (1000) should have at least 3 children");
    
    let codes: Vec<String> = children.iter().map(|a| a.code.clone()).collect();
    assert!(codes.contains(&"1001".to_string()), "Should include 库存现金 (1001)");
    assert!(codes.contains(&"1002".to_string()), "Should include 银行存款 (1002)");
    assert!(codes.contains(&"1012".to_string()), "Should include 其他货币资金 (1012)");
    
    for child in &children {
        assert_eq!(child.parent_code, Some("1000".to_string()), "All children should have parent_code = 1000");
        assert_eq!(child.level, 2, "All children should be level 2");
    }
}

#[tokio::test]
async fn test_create_and_find_account() {
    let repository = setup_repository().await;

    let account = ChartOfAccounts::new(
        Uuid::new_v4().to_string(),
        "1003".to_string(),
        "应收账款".to_string(),
        2,
        ChartOfAccountsType::Asset,
        Some("1000".to_string()),
        BalanceDirection::Debit,
    )
    .unwrap();

    repository.create(&account).await.unwrap();

    let found = repository.find_by_code("1003").await.unwrap().unwrap();
    assert_eq!(found.code, "1003");
    assert_eq!(found.name, "应收账款");
    assert_eq!(found.level, 2);
    assert_eq!(found.parent_code, Some("1000".to_string()));
}

#[tokio::test]
async fn test_list_by_type() {
    let repository = setup_repository().await;

    let asset_accounts = repository
        .list_by_type(ChartOfAccountsType::Asset)
        .await
        .unwrap();
    
    assert!(asset_accounts.len() >= 4, "Should have at least 4 asset accounts (1 level 1 + 3 level 2)");
    
    for account in &asset_accounts {
        assert_eq!(account.account_type, ChartOfAccountsType::Asset);
    }
}

#[tokio::test]
async fn test_soft_delete() {
    let repository = setup_repository().await;

    let mut account = ChartOfAccounts::new(
        Uuid::new_v4().to_string(),
        "1004".to_string(),
        "预付账款".to_string(),
        2,
        ChartOfAccountsType::Asset,
        Some("1000".to_string()),
        BalanceDirection::Debit,
    )
    .unwrap();

    repository.create(&account).await.unwrap();

    let found = repository.find_by_code("1004").await.unwrap();
    assert!(found.is_some());

    account.soft_delete();
    repository.update(&account).await.unwrap();

    let not_found = repository.find_by_code("1004").await.unwrap();
    assert!(not_found.is_none(), "Soft deleted accounts should not be returned");
}
