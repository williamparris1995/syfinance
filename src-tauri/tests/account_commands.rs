use finance_app::{
    application::dtos::{CreateAccountDto, UpdateAccountDto},
    domain::aggregates::{AccountType, Ownership},
    presentation::tauri_commands::account_commands::{
        create_account_with_state, delete_account_with_state, get_account_balance_with_state,
        get_account_with_state, list_accounts_with_state, update_account_with_state, AppState,
    },
};
use rust_decimal::Decimal;

#[tokio::test]
async fn account_command_lifecycle() {
    let state = AppState::create_default().await.expect("state");

    let created = create_account_with_state(
        &state,
        CreateAccountDto {
            name: "Checking Account".into(),
            account_type: AccountType::Bank,
            ownership: Ownership::Own,
            currency_code: "CNY".into(),
            initial_balance: Decimal::new(100_000, 2),
            icon: "💰".into(),
            color: "#10B981".into(),
            chart_code: None,
            parent_id: None,
        },
    )
    .await
    .expect("create account");

    assert_eq!(created.name, "Checking Account");
    assert_eq!(created.initial_balance, Decimal::new(100_000, 2));

    let fetched = get_account_with_state(&state, created.id)
        .await
        .expect("get account");
    assert_eq!(fetched.id, created.id);

    let balance = get_account_balance_with_state(&state, created.id)
        .await
        .expect("get balance");
    assert_eq!(balance.amount, Decimal::new(100_000, 2));
    assert_eq!(balance.currency_code, "CNY");

    let updated = update_account_with_state(
        &state,
        created.id,
        UpdateAccountDto {
            name: "Everyday Checking".into(),
            initial_balance: Decimal::new(125_000, 2),
            icon: None,
            color: None,
            currency_code: None,
            account_number: None,
            institution: None,
            credit_limit: None,
            billing_day: None,
            payment_due_day: None,
            interest_rate: None,
            chart_code: None,
            parent_id: None,
        },
    )
    .await
    .expect("update account");

    assert_eq!(updated.name, "Everyday Checking");
    assert_eq!(updated.initial_balance, Decimal::new(125_000, 2));

    let listed = list_accounts_with_state(&state)
        .await
        .expect("list accounts");
    assert_eq!(listed.len(), 1);

    delete_account_with_state(&state, created.id)
        .await
        .expect("delete account");

    assert!(get_account_with_state(&state, created.id).await.is_err());
    assert!(list_accounts_with_state(&state).await.unwrap().is_empty());
}
