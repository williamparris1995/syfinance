use finance_app::application::dtos::{CreateSecurityDto, DividendDto, HoldingTradeDto};
use finance_app::application::services::HoldingService;
use finance_app::domain::aggregates::{
    holding::{Holding, HoldingTransaction, HoldingTransactionType},
    security::{Security, SecurityType},
    Account, AccountType, Ownership,
};
use finance_app::domain::repositories::{AccountRepository, HoldingRepository, SecurityRepository};
use finance_app::domain::value_objects::{Currency, Money, SyncMetadata};
use finance_app::infrastructure::repositories::{
    SqliteAccountRepository, SqliteHoldingRepository, SqliteSecurityRepository,
    SqliteTransactionRepository,
};
use rust_decimal::Decimal;
use sqlx::sqlite::{SqliteConnectOptions, SqlitePoolOptions};
use std::str::FromStr;
use std::sync::Arc;
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

fn setup_service(pool: sqlx::SqlitePool) -> HoldingService {
    let security_repo = Arc::new(SqliteSecurityRepository::new(pool.clone()));
    let holding_repo = Arc::new(SqliteHoldingRepository::new(pool.clone()));
    let account_repo = Arc::new(SqliteAccountRepository::new(pool.clone()));
    let transaction_repo = Arc::new(SqliteTransactionRepository::new(pool.clone()));
    HoldingService::new(security_repo, holding_repo, account_repo, transaction_repo)
}

fn create_test_account(currency_code: &str) -> Account {
    Account::new(
        Uuid::new_v4(),
        "Test Investment Account",
        AccountType::Bank,
        Ownership::Own,
        &Currency::new(
            currency_code,
            currency_code,
            currency_code,
            currency_code,
            Decimal::ONE,
        )
        .unwrap(),
        Money::new(Decimal::new(1000_0000, 2), currency_code).unwrap(),
        "🏦",
        "#3B82F6",
        None,
        None,
        SyncMetadata::new(Uuid::new_v4()),
    )
    .unwrap()
}

async fn seed_account(pool: &sqlx::SqlitePool) -> Account {
    let repo = SqliteAccountRepository::new(pool.clone());
    let account = create_test_account("CNY");
    repo.create(&account).await.expect("create account");
    account
}

async fn seed_security(pool: &sqlx::SqlitePool) -> Security {
    let repo = SqliteSecurityRepository::new(pool.clone());
    let security = Security::new(
        Uuid::new_v4(),
        "600519".to_string(),
        "Kweichow Moutai".to_string(),
        SecurityType::Stock,
        Some("SSE".to_string()),
        "CNY".to_string(),
        None,
    );
    repo.create(&security).await.expect("create security");
    security
}

#[tokio::test]
async fn test_buy_creates_holding() {
    let pool = setup_test_db().await;
    let service = setup_service(pool.clone());
    let account = seed_account(&pool).await;
    let security = seed_security(&pool).await;

    let trade = HoldingTradeDto {
        account_id: account.id,
        security_id: security.id,
        direction: "BUY".to_string(),
        quantity: Decimal::new(100, 0),
        price: Decimal::new(1800, 0),
        fee: Decimal::new(50, 0),
        trade_date: chrono::NaiveDate::from_ymd_opt(2026, 6, 1).unwrap(),
        notes: Some("Buy Moutai".to_string()),
    };

    let txn_id = service.buy(trade).await.expect("buy should succeed");
    assert_ne!(txn_id, Uuid::nil());

    // Verify holding was created
    let holding_repo = SqliteHoldingRepository::new(pool.clone());
    let holdings = holding_repo
        .find_by_account(account.id)
        .await
        .expect("find holdings");

    assert_eq!(holdings.len(), 1);
    assert_eq!(holdings[0].security_id, security.id);
    assert_eq!(holdings[0].quantity, Decimal::new(100, 0));
    // avg_cost = (100 * 1800 + 50) / 100 = 1800.50
    let expected_avg = Decimal::new(180050, 2);
    assert_eq!(holdings[0].avg_cost, expected_avg);
}

#[tokio::test]
async fn test_list_holdings() {
    let pool = setup_test_db().await;
    let service = setup_service(pool.clone());
    let account = seed_account(&pool).await;
    let security = seed_security(&pool).await;

    // Set current price for unrealized P&L
    let sec_repo = SqliteSecurityRepository::new(pool.clone());
    sec_repo
        .update_price(security.id, Decimal::new(1900, 0))
        .await
        .expect("update price");

    let trade = HoldingTradeDto {
        account_id: account.id,
        security_id: security.id,
        direction: "BUY".to_string(),
        quantity: Decimal::new(100, 0),
        price: Decimal::new(1800, 0),
        fee: Decimal::new(50, 0),
        trade_date: chrono::NaiveDate::from_ymd_opt(2026, 6, 1).unwrap(),
        notes: None,
    };

    service.buy(trade).await.expect("buy");

    let holdings = service.list_holdings().await.expect("list holdings");
    assert_eq!(holdings.len(), 1);
    assert_eq!(holdings[0].symbol, "600519");
    assert_eq!(holdings[0].quantity, Decimal::new(100, 0));
    assert_eq!(holdings[0].current_price, Some(Decimal::new(1900, 0)));
}

#[tokio::test]
async fn test_sell_partial_holding() {
    let pool = setup_test_db().await;
    let service = setup_service(pool.clone());
    let account = seed_account(&pool).await;
    let security = seed_security(&pool).await;

    // Buy first
    let buy_trade = HoldingTradeDto {
        account_id: account.id,
        security_id: security.id,
        direction: "BUY".to_string(),
        quantity: Decimal::new(100, 0),
        price: Decimal::new(1800, 0),
        fee: Decimal::new(50, 0),
        trade_date: chrono::NaiveDate::from_ymd_opt(2026, 6, 1).unwrap(),
        notes: None,
    };
    service.buy(buy_trade).await.expect("buy");

    // Sell half
    let sell_trade = HoldingTradeDto {
        account_id: account.id,
        security_id: security.id,
        direction: "SELL".to_string(),
        quantity: Decimal::new(50, 0),
        price: Decimal::new(1900, 0),
        fee: Decimal::new(30, 0),
        trade_date: chrono::NaiveDate::from_ymd_opt(2026, 6, 15).unwrap(),
        notes: None,
    };

    let txn_id = service.sell(sell_trade).await.expect("sell");
    assert_ne!(txn_id, Uuid::nil());

    // Verify holding quantity reduced
    let holding_repo = SqliteHoldingRepository::new(pool.clone());
    let holdings = holding_repo
        .find_by_account(account.id)
        .await
        .expect("find holdings");

    assert_eq!(holdings.len(), 1);
    assert_eq!(holdings[0].quantity, Decimal::new(50, 0));
}

#[tokio::test]
async fn test_sell_all_empties_holding() {
    let pool = setup_test_db().await;
    let service = setup_service(pool.clone());
    let account = seed_account(&pool).await;
    let security = seed_security(&pool).await;

    let buy_trade = HoldingTradeDto {
        account_id: account.id,
        security_id: security.id,
        direction: "BUY".to_string(),
        quantity: Decimal::new(100, 0),
        price: Decimal::new(1800, 0),
        fee: Decimal::new(50, 0),
        trade_date: chrono::NaiveDate::from_ymd_opt(2026, 6, 1).unwrap(),
        notes: None,
    };
    service.buy(buy_trade).await.expect("buy");

    // Sell all
    let sell_trade = HoldingTradeDto {
        account_id: account.id,
        security_id: security.id,
        direction: "SELL".to_string(),
        quantity: Decimal::new(100, 0),
        price: Decimal::new(1850, 0),
        fee: Decimal::new(30, 0),
        trade_date: chrono::NaiveDate::from_ymd_opt(2026, 6, 15).unwrap(),
        notes: None,
    };
    service.sell(sell_trade).await.expect("sell all");

    // Holding should be soft-deleted
    let holding_repo = SqliteHoldingRepository::new(pool.clone());
    let holdings = holding_repo
        .find_by_account(account.id)
        .await
        .expect("find holdings");
    assert!(
        holdings.is_empty(),
        "holding should be deleted after full sell"
    );
}

#[tokio::test]
async fn test_sell_insufficient_quantity_fails() {
    let pool = setup_test_db().await;
    let service = setup_service(pool.clone());
    let account = seed_account(&pool).await;
    let security = seed_security(&pool).await;

    let buy_trade = HoldingTradeDto {
        account_id: account.id,
        security_id: security.id,
        direction: "BUY".to_string(),
        quantity: Decimal::new(50, 0),
        price: Decimal::new(1800, 0),
        fee: Decimal::new(50, 0),
        trade_date: chrono::NaiveDate::from_ymd_opt(2026, 6, 1).unwrap(),
        notes: None,
    };
    service.buy(buy_trade).await.expect("buy");

    // Try to sell more than owned
    let sell_trade = HoldingTradeDto {
        account_id: account.id,
        security_id: security.id,
        direction: "SELL".to_string(),
        quantity: Decimal::new(100, 0),
        price: Decimal::new(1900, 0),
        fee: Decimal::ZERO,
        trade_date: chrono::NaiveDate::from_ymd_opt(2026, 6, 15).unwrap(),
        notes: None,
    };

    let result = service.sell(sell_trade).await;
    assert!(result.is_err(), "should fail with insufficient quantity");
}

#[tokio::test]
async fn test_record_dividend() {
    let pool = setup_test_db().await;
    let service = setup_service(pool.clone());
    let account = seed_account(&pool).await;
    let security = seed_security(&pool).await;

    // Seed the chart_of_accounts code used by dividend entries
    sqlx::query(
        "INSERT OR IGNORE INTO chart_of_accounts (id, code, name, level, account_type, parent_code, balance_direction, updated_at)
         VALUES ('coa-420101', '420101', 'Dividend Income', 3, 'income', '4201', 'credit', datetime('now'))",
    )
    .execute(&pool)
    .await
    .expect("seed chart code");

    // Buy first to create holding
    let buy_trade = HoldingTradeDto {
        account_id: account.id,
        security_id: security.id,
        direction: "BUY".to_string(),
        quantity: Decimal::new(100, 0),
        price: Decimal::new(1800, 0),
        fee: Decimal::ZERO,
        trade_date: chrono::NaiveDate::from_ymd_opt(2026, 6, 1).unwrap(),
        notes: None,
    };
    service.buy(buy_trade).await.expect("buy");

    // Record dividend
    let dividend = DividendDto {
        account_id: account.id.to_string(),
        security_id: security.id.to_string(),
        cash_per_share: "10.00".to_string(),
        quantity: "100".to_string(),
        total_amount: "1000.00".to_string(),
        fee: Some("5.00".to_string()),
        trade_date: "2026-06-15".to_string(),
        notes: Some("Annual dividend".to_string()),
    };

    let txn_id = service
        .record_dividend(dividend)
        .await
        .expect("record dividend");
    assert_ne!(txn_id, Uuid::nil());

    // Verify holding transaction was created
    let holding_repo = SqliteHoldingRepository::new(pool.clone());
    let trades = holding_repo
        .find_transactions_by_account(account.id)
        .await
        .expect("find trades");

    let dividend_trades: Vec<_> = trades
        .iter()
        .filter(|t| t.trade_type == HoldingTransactionType::Dividend)
        .collect();
    assert_eq!(dividend_trades.len(), 1);
    assert_eq!(dividend_trades[0].amount, Decimal::new(1000, 0));
    assert_eq!(dividend_trades[0].fee, Decimal::new(5, 0));

    // Verify holding quantity unchanged (dividend doesn't affect quantity)
    let holdings = holding_repo
        .find_by_account(account.id)
        .await
        .expect("find holdings");
    assert_eq!(holdings[0].quantity, Decimal::new(100, 0));
}

#[tokio::test]
async fn test_unrealized_pnl_calculation() {
    let pool = setup_test_db().await;
    let service = setup_service(pool.clone());
    let account = seed_account(&pool).await;
    let security = seed_security(&pool).await;

    // Buy at 1800
    let buy_trade = HoldingTradeDto {
        account_id: account.id,
        security_id: security.id,
        direction: "BUY".to_string(),
        quantity: Decimal::new(100, 0),
        price: Decimal::new(1800, 0),
        fee: Decimal::new(100, 0),
        trade_date: chrono::NaiveDate::from_ymd_opt(2026, 6, 1).unwrap(),
        notes: None,
    };
    service.buy(buy_trade).await.expect("buy");

    // Update price to 1900
    let sec_repo = SqliteSecurityRepository::new(pool.clone());
    sec_repo
        .update_price(security.id, Decimal::new(1900, 0))
        .await
        .expect("update price");

    let holdings = service.list_holdings().await.expect("list holdings");
    assert_eq!(holdings.len(), 1);

    let holding_dto = &holdings[0];
    // market_value = 100 * 1900 = 190000
    assert_eq!(holding_dto.market_value, Some(Decimal::new(190000, 0)));

    // unrealized_pnl = (1900 - avg_cost) * 100
    // avg_cost = (100 * 1800 + 100) / 100 = 1801
    // unrealized_pnl = (1900 - 1801) * 100 = 9900
    let expected_pnl = Decimal::new(9900, 0);
    assert_eq!(holding_dto.unrealized_pnl, Some(expected_pnl));
}

#[tokio::test]
async fn test_holding_domain_methods() {
    let holding_id = Uuid::new_v4();
    let account_id = Uuid::new_v4();
    let security_id = Uuid::new_v4();

    let mut holding = Holding::new(
        holding_id,
        account_id,
        security_id,
        Decimal::ZERO,
        Decimal::ZERO,
    );

    // Apply buy: 100 shares at 1800 with 50 fee
    let buy = HoldingTransaction {
        id: Uuid::new_v4(),
        account_id,
        security_id,
        trade_type: HoldingTransactionType::Buy,
        quantity: Decimal::new(100, 0),
        price: Decimal::new(1800, 0),
        amount: Decimal::new(180000, 0),
        fee: Decimal::new(50, 0),
        trade_date: chrono::NaiveDate::from_ymd_opt(2026, 6, 1).unwrap(),
        transaction_id: None,
        notes: None,
    };
    holding.apply_buy(&buy);

    assert_eq!(holding.quantity, Decimal::new(100, 0));
    // avg_cost = (0 + 180000 + 50) / 100 = 1800.50
    assert_eq!(holding.avg_cost, Decimal::new(180050, 2));

    // Market value at 1900
    let mv = holding.market_value(Decimal::new(1900, 0));
    assert_eq!(mv, Decimal::new(190000, 0));

    // Unrealized P&L at 1900
    let pnl = holding.unrealized_pnl(Decimal::new(1900, 0));
    // (1900 - 1800.50) * 100 = 9950
    assert_eq!(pnl, Decimal::new(9950, 0));

    // Apply sell: 50 shares at 1900 with 30 fee
    let sell = HoldingTransaction {
        id: Uuid::new_v4(),
        account_id,
        security_id,
        trade_type: HoldingTransactionType::Sell,
        quantity: Decimal::new(50, 0),
        price: Decimal::new(1900, 0),
        amount: Decimal::new(95000, 0),
        fee: Decimal::new(30, 0),
        trade_date: chrono::NaiveDate::from_ymd_opt(2026, 6, 15).unwrap(),
        transaction_id: None,
        notes: None,
    };
    let realized = holding.apply_sell(&sell);
    // realized = (1900 - 1800.50) * 50 - 30 = 4970 - 30 = 4945? No:
    // realized = (1900 - 1800.50) * 50 - 30 = 4975 - 30 = 4945
    assert_eq!(realized, Decimal::new(4945, 0));
    assert_eq!(holding.quantity, Decimal::new(50, 0));
}

#[tokio::test]
async fn test_holding_split() {
    let pool = setup_test_db().await;
    let service = setup_service(pool.clone());
    let account = seed_account(&pool).await;
    let security = seed_security(&pool).await;

    let buy_trade = HoldingTradeDto {
        account_id: account.id,
        security_id: security.id,
        direction: "BUY".to_string(),
        quantity: Decimal::new(100, 0),
        price: Decimal::new(1800, 0),
        fee: Decimal::ZERO,
        trade_date: chrono::NaiveDate::from_ymd_opt(2026, 6, 1).unwrap(),
        notes: None,
    };
    service.buy(buy_trade).await.expect("buy");

    // Get the holding
    let holding_repo = SqliteHoldingRepository::new(pool.clone());
    let holdings = holding_repo
        .find_by_account(account.id)
        .await
        .expect("find holdings");
    let _holding_id = holdings[0].id;

    // Apply 2:1 split
    let mut holding = holdings[0].clone();
    let old_avg = holding.avg_cost;
    holding.apply_split(Decimal::new(2, 0));
    assert_eq!(holding.quantity, Decimal::new(200, 0));
    assert_eq!(holding.avg_cost, old_avg / Decimal::new(2, 0));

    // Persist
    holding_repo.upsert(&holding).await.expect("upsert");

    let updated = holding_repo
        .find_by_account(account.id)
        .await
        .expect("find holdings");
    assert_eq!(updated[0].quantity, Decimal::new(200, 0));
}

#[tokio::test]
async fn test_create_security_and_list() {
    let pool = setup_test_db().await;
    let service = setup_service(pool);

    let dto = CreateSecurityDto {
        symbol: "000001".to_string(),
        name: "Ping An Bank".to_string(),
        security_type: "stock".to_string(),
        exchange: Some("SZSE".to_string()),
        currency_code: "CNY".to_string(),
    };

    let security = service.create_security(dto).await.expect("create security");
    assert_eq!(security.symbol, "000001");
    assert_eq!(security.name, "Ping An Bank");
    assert_eq!(security.security_type, "stock");

    let list = service.list_securities().await.expect("list securities");
    assert_eq!(list.len(), 1);
}
