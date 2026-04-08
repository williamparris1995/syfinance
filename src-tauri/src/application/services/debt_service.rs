use crate::application::dtos::{CreateDebtDto, DebtDto, PaymentScheduleDto, RecordPaymentDto};
use crate::domain::{
    aggregates::{AmortizationMethod, Debt, DebtType, Reminder, ReminderType},
    repositories::{DebtRepository, ReminderRepository},
    value_objects::{Money, SyncMetadata},
};
use chrono::{Duration, NaiveDate};
use std::sync::Arc;
use uuid::Uuid;

pub struct DebtService<D: DebtRepository, R: ReminderRepository> {
    debt_repo: Arc<D>,
    reminder_repo: Arc<R>,
}

#[derive(Debug)]
pub enum DebtServiceError {
    DebtNotFound(Uuid),
    PaymentNotFound(NaiveDate),
    ValidationError(String),
    RepositoryError(String),
}

impl std::fmt::Display for DebtServiceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::DebtNotFound(id) => write!(f, "debt not found: {id}"),
            Self::PaymentNotFound(date) => write!(f, "payment not found for date: {date}"),
            Self::ValidationError(msg) => write!(f, "validation error: {msg}"),
            Self::RepositoryError(msg) => write!(f, "repository error: {msg}"),
        }
    }
}

impl std::error::Error for DebtServiceError {}

impl From<sqlx::Error> for DebtServiceError {
    fn from(err: sqlx::Error) -> Self {
        Self::RepositoryError(err.to_string())
    }
}

impl<D: DebtRepository, R: ReminderRepository> DebtService<D, R> {
    pub fn new(debt_repo: Arc<D>, reminder_repo: Arc<R>) -> Self {
        Self {
            debt_repo,
            reminder_repo,
        }
    }

    pub async fn create_debt(&self, dto: CreateDebtDto) -> Result<Uuid, DebtServiceError> {
        let debt_id = Uuid::new_v4();
        let device_id = Uuid::new_v4();

        let debt_type = parse_debt_type(&dto.debt_type)?;
        let amortization_method = dto
            .amortization_method
            .as_ref()
            .map(|s| parse_amortization_method(s))
            .transpose()?;

        let principal = Money::new(dto.principal_amount, &dto.currency_code)
            .map_err(|e| DebtServiceError::ValidationError(e.to_string()))?;

        let debt = Debt::create(
            debt_id,
            debt_type,
            dto.counterparty,
            principal,
            dto.interest_rate,
            dto.start_date,
            dto.due_date,
            amortization_method,
            SyncMetadata::new(device_id),
        )
        .map_err(|e| DebtServiceError::ValidationError(e.to_string()))?;

        self.debt_repo.create(&debt).await?;

        for payment in &debt.payment_schedule {
            if !payment.paid {
                let reminder_date = payment.payment_date - Duration::days(3);
                let reminder_id = Uuid::new_v4();

                let reminder = Reminder::create(
                    reminder_id,
                    ReminderType::DebtPayment,
                    Some(debt_id),
                    format!("Payment due: {}", debt.counterparty),
                    format!(
                        "Payment of {} {} due on {}",
                        payment.total_amount.amount,
                        payment.total_amount.currency_code,
                        payment.payment_date
                    ),
                    reminder_date.and_hms_opt(9, 0, 0).unwrap().and_utc(),
                    None,
                    SyncMetadata::new(device_id),
                )
                .map_err(|e| DebtServiceError::ValidationError(e.to_string()))?;

                self.reminder_repo.create(&reminder).await?;
            }
        }

        Ok(debt_id)
    }

    pub async fn get_debt(&self, id: Uuid) -> Result<DebtDto, DebtServiceError> {
        let debt = self
            .debt_repo
            .find_by_id(id)
            .await?
            .ok_or(DebtServiceError::DebtNotFound(id))?;

        Ok(self.to_dto(debt))
    }

    pub async fn list_debts(&self) -> Result<Vec<DebtDto>, DebtServiceError> {
        let debts = self.debt_repo.find_all().await?;
        Ok(debts.into_iter().map(|d| self.to_dto(d)).collect())
    }

    pub async fn record_payment(
        &self,
        dto: RecordPaymentDto,
    ) -> Result<(), DebtServiceError> {
        let mut debt = self
            .debt_repo
            .find_by_id(dto.debt_id)
            .await?
            .ok_or(DebtServiceError::DebtNotFound(dto.debt_id))?;

        debt.mark_payment_paid(dto.payment_date)
            .map_err(|e| DebtServiceError::ValidationError(e.to_string()))?;

        self.debt_repo.update(&debt).await?;

        let all_paid = debt.payment_schedule.iter().all(|p| p.paid);
        if all_paid {
            let reminders = self
                .reminder_repo
                .find_by_related_entity(dto.debt_id)
                .await?;

            for reminder in reminders {
                self.reminder_repo.delete(reminder.id).await?;
            }
        }

        Ok(())
    }

    pub async fn get_upcoming_payments(
        &self,
        days_ahead: i64,
    ) -> Result<Vec<(DebtDto, PaymentScheduleDto)>, DebtServiceError> {
        let debts = self.debt_repo.find_all().await?;
        let cutoff_date = chrono::Utc::now().date_naive() + Duration::days(days_ahead);

        let mut upcoming = Vec::new();

        for debt in debts {
            for payment in &debt.payment_schedule {
                if !payment.paid && payment.payment_date <= cutoff_date {
                    let payment_dto = PaymentScheduleDto {
                        payment_date: payment.payment_date,
                        principal_amount: payment.principal_amount.amount.to_string(),
                        interest_amount: payment.interest_amount.amount.to_string(),
                        total_amount: payment.total_amount.amount.to_string(),
                        currency_code: payment.total_amount.currency_code.clone(),
                        paid: payment.paid,
                    };
                    upcoming.push((self.to_dto(debt.clone()), payment_dto));
                }
            }
        }

        Ok(upcoming)
    }

    fn to_dto(&self, debt: Debt) -> DebtDto {
        let remaining_balance = debt.remaining_balance().amount.to_string();
        DebtDto {
            id: debt.id,
            debt_type: debt_type_to_string(&debt.debt_type),
            counterparty: debt.counterparty,
            principal_amount: debt.principal.amount.to_string(),
            currency_code: debt.principal.currency_code,
            interest_rate: debt.interest_rate.to_string(),
            start_date: debt.start_date,
            due_date: debt.due_date,
            payment_schedule: debt
                .payment_schedule
                .iter()
                .map(|p| PaymentScheduleDto {
                    payment_date: p.payment_date,
                    principal_amount: p.principal_amount.amount.to_string(),
                    interest_amount: p.interest_amount.amount.to_string(),
                    total_amount: p.total_amount.amount.to_string(),
                    currency_code: p.total_amount.currency_code.clone(),
                    paid: p.paid,
                })
                .collect(),
            remaining_balance,
            created_at: debt.sync_metadata.updated_at.to_rfc3339(),
            updated_at: debt.sync_metadata.updated_at.to_rfc3339(),
        }
    }
}

fn parse_debt_type(s: &str) -> Result<DebtType, DebtServiceError> {
    match s {
        "borrowed_out" => Ok(DebtType::BorrowedOut),
        "borrowed_in" => Ok(DebtType::BorrowedIn),
        "credit_card" => Ok(DebtType::CreditCard),
        "loan" => Ok(DebtType::Loan),
        _ => Err(DebtServiceError::ValidationError(format!(
            "invalid debt type: {s}"
        ))),
    }
}

fn debt_type_to_string(dt: &DebtType) -> String {
    match dt {
        DebtType::BorrowedOut => "borrowed_out".to_string(),
        DebtType::BorrowedIn => "borrowed_in".to_string(),
        DebtType::CreditCard => "credit_card".to_string(),
        DebtType::Loan => "loan".to_string(),
    }
}

fn parse_amortization_method(s: &str) -> Result<AmortizationMethod, DebtServiceError> {
    match s {
        "equal_principal_interest" => Ok(AmortizationMethod::EqualPrincipalInterest),
        "equal_principal" => Ok(AmortizationMethod::EqualPrincipal),
        _ => Err(DebtServiceError::ValidationError(format!(
            "invalid amortization method: {s}"
        ))),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::repositories::{DebtRepository, ReminderRepository};
    use crate::infrastructure::repositories::{SqliteDebtRepository, SqliteReminderRepository};
    use chrono::NaiveDate;
    use rust_decimal::Decimal;
    use sqlx::sqlite::{SqliteConnectOptions, SqlitePoolOptions};
    use std::str::FromStr;

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

    #[tokio::test]
    async fn test_create_debt_generates_schedule_and_reminders() {
        let pool = setup_test_db().await;
        let debt_repo = Arc::new(SqliteDebtRepository::new(pool.clone()));
        let reminder_repo = Arc::new(SqliteReminderRepository::new(pool.clone()));
        let service = DebtService::new(debt_repo.clone(), reminder_repo.clone());

        let dto = CreateDebtDto {
            debt_type: "loan".to_string(),
            counterparty: "Test Bank".to_string(),
            principal_amount: Decimal::new(100_000, 0),
            currency_code: "CNY".to_string(),
            interest_rate: Decimal::new(5, 2),
            start_date: NaiveDate::from_ymd_opt(2026, 1, 1).unwrap(),
            due_date: NaiveDate::from_ymd_opt(2027, 1, 1).unwrap(),
            amortization_method: Some("equal_principal_interest".to_string()),
        };

        let debt_id = service.create_debt(dto).await.unwrap();
        assert_ne!(debt_id, Uuid::nil());

        let debt = debt_repo.find_by_id(debt_id).await.unwrap().unwrap();
        assert_eq!(debt.payment_schedule.len(), 12);

        let reminders = reminder_repo
            .find_by_related_entity(debt_id)
            .await
            .unwrap();
        assert_eq!(reminders.len(), 12);
    }

    #[tokio::test]
    async fn test_get_debt() {
        let pool = setup_test_db().await;
        let debt_repo = Arc::new(SqliteDebtRepository::new(pool.clone()));
        let reminder_repo = Arc::new(SqliteReminderRepository::new(pool.clone()));
        let service = DebtService::new(debt_repo.clone(), reminder_repo.clone());

        let dto = CreateDebtDto {
            debt_type: "borrowed_in".to_string(),
            counterparty: "Friend".to_string(),
            principal_amount: Decimal::new(5_000, 0),
            currency_code: "CNY".to_string(),
            interest_rate: Decimal::ZERO,
            start_date: NaiveDate::from_ymd_opt(2026, 4, 1).unwrap(),
            due_date: NaiveDate::from_ymd_opt(2026, 10, 1).unwrap(),
            amortization_method: None,
        };

        let debt_id = service.create_debt(dto).await.unwrap();
        let retrieved = service.get_debt(debt_id).await.unwrap();

        assert_eq!(retrieved.id, debt_id);
        assert_eq!(retrieved.counterparty, "Friend");
        assert_eq!(retrieved.debt_type, "borrowed_in");
    }

    #[tokio::test]
    async fn test_list_debts() {
        let pool = setup_test_db().await;
        let debt_repo = Arc::new(SqliteDebtRepository::new(pool.clone()));
        let reminder_repo = Arc::new(SqliteReminderRepository::new(pool.clone()));
        let service = DebtService::new(debt_repo.clone(), reminder_repo.clone());

        let dto1 = CreateDebtDto {
            debt_type: "borrowed_out".to_string(),
            counterparty: "Alice".to_string(),
            principal_amount: Decimal::new(1_000, 0),
            currency_code: "CNY".to_string(),
            interest_rate: Decimal::ZERO,
            start_date: NaiveDate::from_ymd_opt(2026, 4, 1).unwrap(),
            due_date: NaiveDate::from_ymd_opt(2026, 5, 1).unwrap(),
            amortization_method: None,
        };

        let dto2 = CreateDebtDto {
            debt_type: "borrowed_in".to_string(),
            counterparty: "Bob".to_string(),
            principal_amount: Decimal::new(2_000, 0),
            currency_code: "CNY".to_string(),
            interest_rate: Decimal::ZERO,
            start_date: NaiveDate::from_ymd_opt(2026, 4, 1).unwrap(),
            due_date: NaiveDate::from_ymd_opt(2026, 6, 1).unwrap(),
            amortization_method: None,
        };

        service.create_debt(dto1).await.unwrap();
        service.create_debt(dto2).await.unwrap();

        let debts = service.list_debts().await.unwrap();
        assert_eq!(debts.len(), 2);
    }

    #[tokio::test]
    async fn test_record_payment_updates_schedule() {
        let pool = setup_test_db().await;
        let debt_repo = Arc::new(SqliteDebtRepository::new(pool.clone()));
        let reminder_repo = Arc::new(SqliteReminderRepository::new(pool.clone()));
        let service = DebtService::new(debt_repo.clone(), reminder_repo.clone());

        let dto = CreateDebtDto {
            debt_type: "loan".to_string(),
            counterparty: "Test Bank".to_string(),
            principal_amount: Decimal::new(100_000, 0),
            currency_code: "CNY".to_string(),
            interest_rate: Decimal::new(5, 2),
            start_date: NaiveDate::from_ymd_opt(2026, 1, 1).unwrap(),
            due_date: NaiveDate::from_ymd_opt(2027, 1, 1).unwrap(),
            amortization_method: Some("equal_principal_interest".to_string()),
        };

        let debt_id = service.create_debt(dto).await.unwrap();
        let debt = debt_repo.find_by_id(debt_id).await.unwrap().unwrap();
        let first_payment_date = debt.payment_schedule[0].payment_date;

        let payment_dto = RecordPaymentDto {
            debt_id,
            payment_date: first_payment_date,
            transaction_id: Uuid::new_v4(),
        };

        service.record_payment(payment_dto).await.unwrap();

        let updated_debt = debt_repo.find_by_id(debt_id).await.unwrap().unwrap();
        assert!(updated_debt.payment_schedule[0].paid);
    }

    #[tokio::test]
    async fn test_record_all_payments_deletes_reminders() {
        let pool = setup_test_db().await;
        let debt_repo = Arc::new(SqliteDebtRepository::new(pool.clone()));
        let reminder_repo = Arc::new(SqliteReminderRepository::new(pool.clone()));
        let service = DebtService::new(debt_repo.clone(), reminder_repo.clone());

        let dto = CreateDebtDto {
            debt_type: "loan".to_string(),
            counterparty: "Test Bank".to_string(),
            principal_amount: Decimal::new(100_000, 0),
            currency_code: "CNY".to_string(),
            interest_rate: Decimal::new(5, 2),
            start_date: NaiveDate::from_ymd_opt(2026, 1, 1).unwrap(),
            due_date: NaiveDate::from_ymd_opt(2027, 1, 1).unwrap(),
            amortization_method: Some("equal_principal_interest".to_string()),
        };

        let debt_id = service.create_debt(dto).await.unwrap();
        let debt = debt_repo.find_by_id(debt_id).await.unwrap().unwrap();

        for payment in &debt.payment_schedule {
            let payment_dto = RecordPaymentDto {
                debt_id,
                payment_date: payment.payment_date,
                transaction_id: Uuid::new_v4(),
            };
            service.record_payment(payment_dto).await.unwrap();
        }

        let reminders = reminder_repo
            .find_by_related_entity(debt_id)
            .await
            .unwrap();
        assert_eq!(reminders.len(), 0);
    }

    #[tokio::test]
    async fn test_get_upcoming_payments() {
        let pool = setup_test_db().await;
        let debt_repo = Arc::new(SqliteDebtRepository::new(pool.clone()));
        let reminder_repo = Arc::new(SqliteReminderRepository::new(pool.clone()));
        let service = DebtService::new(debt_repo.clone(), reminder_repo.clone());

        let today = chrono::Utc::now().date_naive();
        let dto = CreateDebtDto {
            debt_type: "loan".to_string(),
            counterparty: "Test Bank".to_string(),
            principal_amount: Decimal::new(100_000, 0),
            currency_code: "CNY".to_string(),
            interest_rate: Decimal::new(5, 2),
            start_date: today - Duration::days(60),
            due_date: today + Duration::days(300),
            amortization_method: Some("equal_principal_interest".to_string()),
        };

        service.create_debt(dto).await.unwrap();

        let upcoming = service.get_upcoming_payments(30).await.unwrap();
        assert!(!upcoming.is_empty());
    }
}
