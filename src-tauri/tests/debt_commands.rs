use chrono::{Duration, NaiveDate};
use finance_app::application::dtos::{CreateDebtDto, RecordPaymentDto};
use finance_app::presentation::tauri_commands::debt_commands::{
    create_debt_with_state, get_debt_with_state, get_upcoming_payments_with_state,
    list_debts_with_state, record_payment_with_state, AppState,
};
use rust_decimal::Decimal;
use uuid::Uuid;

async fn setup_test_state() -> AppState {
    AppState::create_default().await.expect("state")
}

fn loan_dto(counterparty: &str, start_date: NaiveDate, due_date: NaiveDate) -> CreateDebtDto {
    CreateDebtDto {
        debt_type: "loan".into(),
        counterparty: counterparty.into(),
        principal_amount: Decimal::new(100_000, 0),
        currency_code: "CNY".into(),
        interest_rate: Decimal::new(5, 2),
        start_date,
        due_date,
        amortization_method: Some("equal_principal_interest".into()),
    }
}

#[tokio::test]
async fn debt_command_lifecycle() {
    let state = setup_test_state().await;
    let debt = create_debt_with_state(
        &state,
        loan_dto(
            "Test Bank",
            NaiveDate::from_ymd_opt(2026, 1, 1).unwrap(),
            NaiveDate::from_ymd_opt(2027, 1, 1).unwrap(),
        ),
    )
    .await
    .expect("create debt");

    assert_eq!(debt.counterparty, "Test Bank");
    assert!(!debt.payment_schedule.is_empty());

    let fetched = get_debt_with_state(&state, debt.id)
        .await
        .expect("get debt");
    assert_eq!(fetched.id, debt.id);

    let listed = list_debts_with_state(&state).await.expect("list debts");
    assert_eq!(listed.len(), 1);

    let first_payment_date = debt.payment_schedule[0].payment_date;
    record_payment_with_state(
        &state,
        RecordPaymentDto {
            debt_id: debt.id,
            payment_date: first_payment_date,
            transaction_id: Uuid::new_v4(),
        },
    )
    .await
    .expect("record payment");

    let updated = get_debt_with_state(&state, debt.id)
        .await
        .expect("get updated debt");
    assert!(updated.payment_schedule[0].paid);
}

#[tokio::test]
async fn get_upcoming_payments_returns_due_installments() {
    let state = setup_test_state().await;
    let today = chrono::Utc::now().date_naive();

    create_debt_with_state(
        &state,
        loan_dto(
            "Upcoming Bank",
            today - Duration::days(60),
            today + Duration::days(300),
        ),
    )
    .await
    .expect("create debt");

    let upcoming = get_upcoming_payments_with_state(&state, 30)
        .await
        .expect("upcoming payments");

    assert!(!upcoming.is_empty());
    assert_eq!(upcoming[0].debt.counterparty, "Upcoming Bank");
}
