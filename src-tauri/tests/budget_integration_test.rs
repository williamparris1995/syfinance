use finance_app::application::services::BudgetService;
use finance_app::domain::aggregates::budget::Budget;
use finance_app::domain::repositories::BudgetRepository;
use finance_app::domain::value_objects::budget_item::BudgetItem;
use finance_app::infrastructure::repositories::SqliteBudgetRepository;
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

fn setup_service(pool: sqlx::SqlitePool) -> BudgetService {
    let repo = Arc::new(SqliteBudgetRepository::new(pool.clone()));
    BudgetService::new(repo, pool)
}

/// Insert a minimal account row so FK constraints on budget_items.category_account_id pass.
async fn seed_account(pool: &sqlx::SqlitePool, id: &str) {
    sqlx::query(
        "INSERT INTO accounts (id, name, account_type, currency_code, initial_balance, ownership, updated_at, device_id)
         VALUES (?, ?, 'expense', 'CNY', 0, 'own', datetime('now'), ?)",
    )
    .bind(id)
    .bind(format!("Account {}", id))
    .bind(Uuid::new_v4().to_string())
    .execute(pool)
    .await
    .expect("seed account");
}

#[tokio::test]
async fn test_create_budget_with_items() {
    let pool = setup_test_db().await;
    let service = setup_service(pool.clone());

    let budget = service
        .create_budget(
            "June Budget".to_string(),
            "2026-06".to_string(),
            "CNY".to_string(),
        )
        .await
        .expect("create budget");

    assert_eq!(budget.name, "June Budget");
    assert_eq!(budget.month, "2026-06");
    assert_eq!(budget.currency_code, "CNY");
    assert!(budget.is_active);
    assert!(budget.items.is_empty());

    // Seed accounts for FK constraint
    seed_account(&pool, "cat-food").await;
    seed_account(&pool, "cat-transport").await;

    // Add a budget item
    let budget = service
        .add_budget_item(
            budget.id.clone(),
            "cat-food".to_string(),
            "3000".to_string(),
            Some("Food budget".to_string()),
        )
        .await
        .expect("add budget item");

    assert_eq!(budget.items.len(), 1);
    assert_eq!(budget.items[0].category_account_id, "cat-food");
    assert_eq!(budget.items[0].planned_amount, Decimal::new(3000, 0));
    assert_eq!(budget.items[0].actual_amount, Decimal::ZERO);

    // Add another item
    let budget = service
        .add_budget_item(
            budget.id.clone(),
            "cat-transport".to_string(),
            "1500".to_string(),
            None,
        )
        .await
        .expect("add second item");

    assert_eq!(budget.items.len(), 2);
}

#[tokio::test]
async fn test_list_budgets() {
    let pool = setup_test_db().await;
    let service = setup_service(pool);

    service
        .create_budget(
            "April Budget".to_string(),
            "2026-04".to_string(),
            "CNY".to_string(),
        )
        .await
        .expect("create budget 1");
    service
        .create_budget(
            "May Budget".to_string(),
            "2026-05".to_string(),
            "CNY".to_string(),
        )
        .await
        .expect("create budget 2");

    let budgets = service.list_budgets().await.expect("list budgets");
    assert_eq!(budgets.len(), 2);
    // Ordered by month DESC
    assert_eq!(budgets[0].month, "2026-05");
    assert_eq!(budgets[1].month, "2026-04");
}

#[tokio::test]
async fn test_get_budget_by_month() {
    let pool = setup_test_db().await;
    let service = setup_service(pool);

    service
        .create_budget(
            "June Budget".to_string(),
            "2026-06".to_string(),
            "CNY".to_string(),
        )
        .await
        .expect("create budget");

    let found = service
        .get_budget_by_month("2026-06")
        .await
        .expect("get by month");
    assert!(found.is_some());
    assert_eq!(found.unwrap().name, "June Budget");

    let not_found = service
        .get_budget_by_month("2026-07")
        .await
        .expect("get by month");
    assert!(not_found.is_none());
}

#[tokio::test]
async fn test_update_budget_item_planned_amount() {
    let pool = setup_test_db().await;
    let service = setup_service(pool.clone());

    seed_account(&pool, "cat-food").await;

    let budget = service
        .create_budget(
            "Budget".to_string(),
            "2026-06".to_string(),
            "CNY".to_string(),
        )
        .await
        .expect("create budget");

    let budget = service
        .add_budget_item(
            budget.id.clone(),
            "cat-food".to_string(),
            "3000".to_string(),
            None,
        )
        .await
        .expect("add item");

    let item_id = budget.items[0].id.clone();

    // Update planned amount directly via repo
    let repo = SqliteBudgetRepository::new(pool);
    let mut item = budget.items[0].clone();
    item.planned_amount = Decimal::new(5000, 0);
    item.notes = Some("Updated budget".to_string());
    repo.update_item(&item).await.expect("update item");

    let updated = service
        .get_budget(&budget.id)
        .await
        .expect("get budget")
        .unwrap();

    assert_eq!(updated.items.len(), 1);
    assert_eq!(updated.items[0].id, item_id);
    assert_eq!(updated.items[0].planned_amount, Decimal::new(5000, 0));
    assert_eq!(updated.items[0].notes, Some("Updated budget".to_string()));
}

#[tokio::test]
async fn test_compute_budget_actuals() {
    let pool = setup_test_db().await;
    let service = setup_service(pool.clone());

    seed_account(&pool, "cat-expense").await;

    // Create a budget
    let budget = service
        .create_budget(
            "June Budget".to_string(),
            "2026-06".to_string(),
            "CNY".to_string(),
        )
        .await
        .expect("create budget");

    // Add a budget item with a category account id
    let category_account_id = "cat-expense";
    service
        .add_budget_item(
            budget.id.clone(),
            category_account_id.to_string(),
            "5000".to_string(),
            None,
        )
        .await
        .expect("add item");

    // Insert a transaction entry for that category_account_id within the budget month
    let tx_id = Uuid::new_v4().to_string();
    sqlx::query(
        "INSERT INTO transactions (id, transaction_date, description, updated_at, device_id)
         VALUES (?, '2026-06-15', 'Grocery shopping', datetime('now'), ?)",
    )
    .bind(&tx_id)
    .bind(Uuid::new_v4().to_string())
    .execute(&pool)
    .await
    .expect("insert transaction");

    let entry_id = Uuid::new_v4().to_string();
    sqlx::query(
        "INSERT INTO transaction_entries (id, transaction_id, account_id, chart_of_account_code, debit_amount, updated_at)
         VALUES (?, ?, ?, '5101', '2500.00', datetime('now'))",
    )
    .bind(&entry_id)
    .bind(&tx_id)
    .bind(category_account_id)
    .execute(&pool)
    .await
    .expect("insert entry");

    // Compute actuals
    service
        .compute_budget_actuals(&budget.id)
        .await
        .expect("compute actuals");

    let updated = service
        .get_budget(&budget.id)
        .await
        .expect("get budget")
        .unwrap();

    assert_eq!(updated.items.len(), 1);
    assert_eq!(updated.items[0].actual_amount, Decimal::new(2500, 0));
}

#[tokio::test]
async fn test_clone_budget_to_next_month() {
    let pool = setup_test_db().await;
    let service = setup_service(pool.clone());

    seed_account(&pool, "cat-food").await;
    seed_account(&pool, "cat-transport").await;

    // Create a budget with items
    let budget = service
        .create_budget(
            "June Budget".to_string(),
            "2026-06".to_string(),
            "CNY".to_string(),
        )
        .await
        .expect("create budget");

    let budget = service
        .add_budget_item(
            budget.id.clone(),
            "cat-food".to_string(),
            "3000".to_string(),
            Some("Food".to_string()),
        )
        .await
        .expect("add item");

    service
        .add_budget_item(
            budget.id.clone(),
            "cat-transport".to_string(),
            "1500".to_string(),
            None,
        )
        .await
        .expect("add second item");

    // Clone to July
    let new_id = service
        .clone_budget_to_month(&budget.id, "2026-07")
        .await
        .expect("clone budget");

    let cloned = service
        .get_budget(&new_id)
        .await
        .expect("get cloned")
        .unwrap();

    assert_eq!(cloned.month, "2026-07");
    assert_eq!(cloned.name, "June Budget");
    assert_eq!(cloned.currency_code, "CNY");
    assert_eq!(cloned.items.len(), 2);

    // Verify items have planned amounts preserved but actuals reset
    for item in &cloned.items {
        assert_eq!(item.actual_amount, Decimal::ZERO);
    }

    // Cloning to same month again should fail
    let result = service.clone_budget_to_month(&budget.id, "2026-07").await;
    assert!(result.is_err());
}

#[tokio::test]
async fn test_remove_budget_item() {
    let pool = setup_test_db().await;
    let service = setup_service(pool.clone());

    seed_account(&pool, "cat-food").await;

    let budget = service
        .create_budget(
            "Budget".to_string(),
            "2026-06".to_string(),
            "CNY".to_string(),
        )
        .await
        .expect("create budget");

    let budget = service
        .add_budget_item(
            budget.id.clone(),
            "cat-food".to_string(),
            "3000".to_string(),
            None,
        )
        .await
        .expect("add item");

    assert_eq!(budget.items.len(), 1);
    let item_id = &budget.items[0].id;

    let budget = service
        .remove_budget_item(&budget.id, item_id)
        .await
        .expect("remove item");

    assert!(budget.items.is_empty());
}

#[tokio::test]
async fn test_delete_budget() {
    let pool = setup_test_db().await;
    let service = setup_service(pool.clone());

    seed_account(&pool, "cat-food").await;

    let budget = service
        .create_budget(
            "Budget".to_string(),
            "2026-06".to_string(),
            "CNY".to_string(),
        )
        .await
        .expect("create budget");

    let budget_id = budget.id.clone();

    // Add an item
    service
        .add_budget_item(
            budget_id.clone(),
            "cat-food".to_string(),
            "3000".to_string(),
            None,
        )
        .await
        .expect("add item");

    service
        .delete_budget(&budget_id)
        .await
        .expect("delete budget");

    let found = service.get_budget(&budget_id).await.expect("get budget");
    assert!(found.is_none());

    let all = service.list_budgets().await.expect("list budgets");
    assert!(all.is_empty());
}

#[tokio::test]
async fn test_budget_domain_methods() {
    let mut budget = Budget::new(
        "test-id".to_string(),
        "Test Budget".to_string(),
        "2026-06".to_string(),
        "CNY".to_string(),
    );

    let item1 = BudgetItem::new(
        "item-1".to_string(),
        "test-id".to_string(),
        "cat-food".to_string(),
        Decimal::new(3000, 0),
        None,
    );
    let item2 = BudgetItem::new(
        "item-2".to_string(),
        "test-id".to_string(),
        "cat-transport".to_string(),
        Decimal::new(2000, 0),
        None,
    );

    budget.add_item(item1);
    budget.add_item(item2);

    assert_eq!(budget.total_amount, Decimal::new(5000, 0));
    assert_eq!(budget.total_actual(), Decimal::ZERO);
    assert_eq!(budget.total_remaining(), Decimal::new(5000, 0));

    // Simulate actual spending that exceeds the item's planned amount
    budget.items[0].record_actual(Decimal::new(3500, 0));
    // total_actual = 3500, total_amount = 5000, so NOT over budget overall
    assert!(!budget.is_over_budget(), "3500 < 5000, not over budget");
    assert_eq!(budget.total_remaining(), Decimal::new(1500, 0));

    // Now overspend overall
    budget.items[1].record_actual(Decimal::new(2500, 0));
    // total_actual = 6000, total_amount = 5000
    assert!(budget.is_over_budget(), "6000 > 5000, over budget");
    assert_eq!(budget.total_remaining(), Decimal::new(-1000, 0));

    let pct = budget.overall_usage_percentage();
    assert!(
        (pct - 120.0).abs() < 0.01,
        "usage should be ~120%, got {pct}"
    );
}
