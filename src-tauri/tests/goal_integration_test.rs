use finance_app::application::services::GoalService;
use finance_app::domain::aggregates::goal::{Goal, GoalType};
use finance_app::infrastructure::repositories::{SqliteAccountRepository, SqliteGoalRepository};
use rust_decimal::Decimal;
use sqlx::sqlite::{SqliteConnectOptions, SqlitePoolOptions};
use std::str::FromStr;
use std::sync::Arc;

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

fn setup_service(pool: sqlx::SqlitePool) -> GoalService {
    let goal_repo = Arc::new(SqliteGoalRepository::new(pool.clone()));
    let account_repo = Arc::new(SqliteAccountRepository::new(pool.clone()));
    GoalService::new(goal_repo, account_repo, pool)
}

#[tokio::test]
async fn test_create_savings_goal() {
    let pool = setup_test_db().await;
    let service = setup_service(pool);

    let goal = service
        .create_goal(
            "Emergency Fund".to_string(),
            "savings".to_string(),
            "50000".to_string(),
            "CNY".to_string(),
            Some("2026-12-31".to_string()),
            None,
            Some("Build emergency fund".to_string()),
        )
        .await
        .expect("create savings goal");

    assert_eq!(goal.name, "Emergency Fund");
    assert_eq!(goal.goal_type, GoalType::Savings);
    assert_eq!(goal.target_amount, Decimal::new(50000, 0));
    assert_eq!(goal.current_amount, Decimal::ZERO);
    assert_eq!(goal.currency_code, "CNY");
    assert!(!goal.is_completed);
    assert!(goal.deadline.is_some());
    assert_eq!(goal.notes, Some("Build emergency fund".to_string()));
}

#[tokio::test]
async fn test_create_debt_payoff_goal() {
    let pool = setup_test_db().await;
    let service = setup_service(pool);

    let goal = service
        .create_goal(
            "Pay off credit card".to_string(),
            "debt_payoff".to_string(),
            "20000".to_string(),
            "CNY".to_string(),
            None,
            None,
            None,
        )
        .await
        .expect("create debt payoff goal");

    assert_eq!(goal.goal_type, GoalType::DebtPayoff);
    assert!(goal.deadline.is_none());
}

#[tokio::test]
async fn test_create_investment_goal() {
    let pool = setup_test_db().await;
    let service = setup_service(pool.clone());

    // Seed an account for the linked_account_id FK constraint
    sqlx::query(
        "INSERT INTO accounts (id, name, account_type, currency_code, initial_balance, ownership, updated_at, device_id)
         VALUES ('account-123', 'Investment Account', 'investment', 'CNY', 0, 'own', datetime('now'), ?)",
    )
    .bind(uuid::Uuid::new_v4().to_string())
    .execute(&pool)
    .await
    .expect("seed account");

    let goal = service
        .create_goal(
            "Stock portfolio".to_string(),
            "investment".to_string(),
            "100000".to_string(),
            "CNY".to_string(),
            Some("2027-06-30".to_string()),
            Some("account-123".to_string()),
            None,
        )
        .await
        .expect("create investment goal");

    assert_eq!(goal.goal_type, GoalType::Investment);
    assert_eq!(goal.linked_account_id, Some("account-123".to_string()));
}

#[tokio::test]
async fn test_list_goals() {
    let pool = setup_test_db().await;
    let service = setup_service(pool);

    service
        .create_goal(
            "Goal 1".to_string(),
            "savings".to_string(),
            "10000".to_string(),
            "CNY".to_string(),
            None,
            None,
            None,
        )
        .await
        .expect("create goal 1");

    service
        .create_goal(
            "Goal 2".to_string(),
            "investment".to_string(),
            "50000".to_string(),
            "CNY".to_string(),
            None,
            None,
            None,
        )
        .await
        .expect("create goal 2");

    let goals = service.list_goals().await.expect("list goals");
    assert_eq!(goals.len(), 2);
}

#[tokio::test]
async fn test_update_goal_progress() {
    let pool = setup_test_db().await;
    let service = setup_service(pool);

    let goal = service
        .create_goal(
            "Savings Goal".to_string(),
            "savings".to_string(),
            "10000".to_string(),
            "CNY".to_string(),
            None,
            None,
            None,
        )
        .await
        .expect("create goal");

    let goal_id = goal.id.clone();

    // Add progress
    let updated = service
        .update_goal_progress(&goal_id, "3000".to_string())
        .await
        .expect("update progress");

    assert_eq!(updated.current_amount, Decimal::new(3000, 0));
    assert!(!updated.is_completed);

    // Progress percentage check
    let pct = updated.progress_percentage();
    assert!(
        (pct - 30.0).abs() < 0.01,
        "progress should be ~30%, got {pct}"
    );
}

#[tokio::test]
async fn test_goal_auto_complete_on_target_reached() {
    let pool = setup_test_db().await;
    let service = setup_service(pool);

    let goal = service
        .create_goal(
            "Small Goal".to_string(),
            "savings".to_string(),
            "5000".to_string(),
            "CNY".to_string(),
            None,
            None,
            None,
        )
        .await
        .expect("create goal");

    let goal_id = goal.id.clone();

    // Progress to target
    let updated = service
        .update_goal_progress(&goal_id, "5000".to_string())
        .await
        .expect("update progress to target");

    assert!(
        updated.is_completed,
        "goal should auto-complete when target reached"
    );
    assert!(updated.completed_at.is_some());
}

#[tokio::test]
async fn test_complete_goal_manually() {
    let pool = setup_test_db().await;
    let service = setup_service(pool);

    let goal = service
        .create_goal(
            "Manual Complete Goal".to_string(),
            "savings".to_string(),
            "10000".to_string(),
            "CNY".to_string(),
            None,
            None,
            None,
        )
        .await
        .expect("create goal");

    let goal_id = goal.id.clone();
    assert!(!goal.is_completed);

    let completed = service
        .complete_goal(&goal_id)
        .await
        .expect("complete goal");

    assert!(completed.is_completed);
    assert!(completed.completed_at.is_some());
}

#[tokio::test]
async fn test_update_goal() {
    let pool = setup_test_db().await;
    let service = setup_service(pool);

    let goal = service
        .create_goal(
            "Original Name".to_string(),
            "savings".to_string(),
            "10000".to_string(),
            "CNY".to_string(),
            Some("2026-12-31".to_string()),
            None,
            None,
        )
        .await
        .expect("create goal");

    let goal_id = goal.id.clone();

    let updated = service
        .update_goal(
            &goal_id,
            Some("Updated Name".to_string()),
            Some("investment".to_string()),
            Some("20000".to_string()),
            None,
            None,
            None,
            Some("Updated notes".to_string()),
        )
        .await
        .expect("update goal");

    assert_eq!(updated.name, "Updated Name");
    assert_eq!(updated.goal_type, GoalType::Investment);
    assert_eq!(updated.target_amount, Decimal::new(20000, 0));
    assert_eq!(updated.notes, Some("Updated notes".to_string()));
    // Deadline unchanged since we passed None
    assert!(updated.deadline.is_some());
}

#[tokio::test]
async fn test_delete_goal() {
    let pool = setup_test_db().await;
    let service = setup_service(pool);

    let goal = service
        .create_goal(
            "To Delete".to_string(),
            "savings".to_string(),
            "5000".to_string(),
            "CNY".to_string(),
            None,
            None,
            None,
        )
        .await
        .expect("create goal");

    let goal_id = goal.id.clone();

    service.delete_goal(&goal_id).await.expect("delete goal");

    let found = service.get_goal(&goal_id).await.expect("get goal");
    assert!(found.is_none());

    let all = service.list_goals().await.expect("list goals");
    assert!(all.is_empty());
}

#[tokio::test]
async fn test_goal_progress_calculation() {
    let mut goal = Goal::new(
        "test-id".to_string(),
        "Test Goal".to_string(),
        GoalType::Savings,
        Decimal::new(100000, 0),
        "CNY".to_string(),
    );

    assert_eq!(goal.progress_percentage(), 0.0);
    assert_eq!(goal.remaining_amount(), Decimal::new(100000, 0));

    goal.add_progress(Decimal::new(25000, 0));
    let pct = goal.progress_percentage();
    assert!(
        (pct - 25.0).abs() < 0.01,
        "progress should be 25%, got {pct}"
    );
    assert_eq!(goal.remaining_amount(), Decimal::new(75000, 0));

    // Add enough to complete
    goal.add_progress(Decimal::new(75000, 0));
    assert!(goal.is_completed);
    assert_eq!(goal.remaining_amount(), Decimal::ZERO);
}
