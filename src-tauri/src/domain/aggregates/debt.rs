use crate::domain::value_objects::{Money, SyncMetadata};
use chrono::{Datelike, Months, NaiveDate, Utc};
use rust_decimal::Decimal;
use std::{error::Error, fmt};
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DebtType {
    BorrowedOut,
    BorrowedIn,
    CreditCard,
    Loan,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AmortizationMethod {
    EqualPrincipalInterest,
    EqualPrincipal,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PaymentSchedule {
    pub payment_date: NaiveDate,
    pub principal_amount: Money,
    pub interest_amount: Money,
    pub total_amount: Money,
    pub paid: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DebtError {
    EmptyCounterparty,
    InvalidPrincipal(Money),
    InvalidInterestRate(Decimal),
    InvalidDateRange {
        start_date: NaiveDate,
        due_date: NaiveDate,
    },
    MissingAmortizationMethod,
    PaymentNotFound(NaiveDate),
}

impl fmt::Display for DebtError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyCounterparty => write!(f, "counterparty cannot be empty"),
            Self::InvalidPrincipal(principal) => {
                write!(f, "principal must be greater than zero: {principal}")
            }
            Self::InvalidInterestRate(rate) => {
                write!(f, "interest rate must be non-negative: {rate}")
            }
            Self::InvalidDateRange {
                start_date,
                due_date,
            } => write!(
                f,
                "due date {due_date} must be after start date {start_date}"
            ),
            Self::MissingAmortizationMethod => {
                write!(f, "loan debts require an amortization method")
            }
            Self::PaymentNotFound(payment_date) => {
                write!(f, "payment not found for date {payment_date}")
            }
        }
    }
}

impl Error for DebtError {}

#[derive(Debug, Clone)]
pub struct Debt {
    pub id: Uuid,
    pub debt_type: DebtType,
    pub counterparty: String,
    pub principal: Money,
    pub interest_rate: Decimal,
    pub start_date: NaiveDate,
    pub due_date: NaiveDate,
    pub payment_schedule: Vec<PaymentSchedule>,
    pub sync_metadata: SyncMetadata,
}

impl Debt {
    pub fn create(
        id: Uuid,
        debt_type: DebtType,
        counterparty: impl Into<String>,
        principal: Money,
        interest_rate: Decimal,
        start_date: NaiveDate,
        due_date: NaiveDate,
        amortization_method: Option<AmortizationMethod>,
        sync_metadata: SyncMetadata,
    ) -> Result<Self, DebtError> {
        let counterparty = counterparty.into().trim().to_string();

        if counterparty.is_empty() {
            return Err(DebtError::EmptyCounterparty);
        }

        if principal.amount <= Decimal::ZERO {
            return Err(DebtError::InvalidPrincipal(principal));
        }

        if interest_rate < Decimal::ZERO {
            return Err(DebtError::InvalidInterestRate(interest_rate));
        }

        if due_date <= start_date {
            return Err(DebtError::InvalidDateRange {
                start_date,
                due_date,
            });
        }

        let mut debt = Self {
            id,
            debt_type,
            counterparty,
            principal,
            interest_rate,
            start_date,
            due_date,
            payment_schedule: Vec::new(),
            sync_metadata,
        };

        debt.payment_schedule = match (&debt.debt_type, amortization_method) {
            (DebtType::Loan, Some(AmortizationMethod::EqualPrincipalInterest)) => {
                debt.generate_schedule_equal_principal_interest()?
            }
            (DebtType::Loan, Some(AmortizationMethod::EqualPrincipal)) => {
                debt.generate_schedule_equal_principal()?
            }
            (DebtType::Loan, None) => return Err(DebtError::MissingAmortizationMethod),
            (_, _) => Vec::new(),
        };

        Ok(debt)
    }

    pub fn generate_schedule_equal_principal_interest(
        &self,
    ) -> Result<Vec<PaymentSchedule>, DebtError> {
        let months = term_in_months(self.start_date, self.due_date)?;
        let monthly_rate = self.interest_rate / Decimal::from(12u32);
        let raw_payment = if monthly_rate.is_zero() {
            self.principal.amount / Decimal::from(months)
        } else {
            let factor = compound_factor(monthly_rate, months);
            self.principal.amount * monthly_rate * factor / (factor - Decimal::ONE)
        };
        let payment = round_money(raw_payment);

        let mut remaining_principal = self.principal.amount;
        let mut schedule = Vec::with_capacity(months as usize);

        for installment in 1..=months {
            let raw_interest_amount = remaining_principal * monthly_rate;
            let raw_principal_amount = if installment == months {
                remaining_principal
            } else {
                raw_payment - raw_interest_amount
            };
            let interest_amount = round_money(raw_interest_amount);
            let principal_amount = if installment == months {
                round_money(remaining_principal)
            } else {
                round_money(raw_principal_amount)
            };
            let total_amount = if installment == months {
                round_money(principal_amount + interest_amount)
            } else {
                payment
            };

            schedule.push(PaymentSchedule {
                payment_date: payment_date_for_installment(self.start_date, installment as u32),
                principal_amount: money_from_decimal(
                    principal_amount,
                    &self.principal.currency_code,
                ),
                interest_amount: money_from_decimal(interest_amount, &self.principal.currency_code),
                total_amount: money_from_decimal(total_amount, &self.principal.currency_code),
                paid: false,
            });

            remaining_principal -= raw_principal_amount;
        }

        Ok(schedule)
    }

    pub fn generate_schedule_equal_principal(&self) -> Result<Vec<PaymentSchedule>, DebtError> {
        let months = term_in_months(self.start_date, self.due_date)?;
        let monthly_rate = self.interest_rate / Decimal::from(12u32);
        let regular_principal = self.principal.amount / Decimal::from(months);
        let mut remaining_principal = self.principal.amount;
        let mut schedule = Vec::with_capacity(months as usize);

        for installment in 1..=months {
            let raw_principal_amount = if installment == months {
                remaining_principal
            } else {
                regular_principal
            };
            let principal_amount = if installment == months {
                round_money(remaining_principal)
            } else {
                round_money(raw_principal_amount)
            };
            let raw_interest_amount = remaining_principal * monthly_rate;
            let interest_amount = round_money(raw_interest_amount);
            let total_amount = round_money(raw_principal_amount + raw_interest_amount);

            schedule.push(PaymentSchedule {
                payment_date: payment_date_for_installment(self.start_date, installment as u32),
                principal_amount: money_from_decimal(
                    principal_amount,
                    &self.principal.currency_code,
                ),
                interest_amount: money_from_decimal(interest_amount, &self.principal.currency_code),
                total_amount: money_from_decimal(total_amount, &self.principal.currency_code),
                paid: false,
            });

            remaining_principal -= raw_principal_amount;
        }

        Ok(schedule)
    }

    pub fn mark_payment_paid(&mut self, payment_date: NaiveDate) -> Result<(), DebtError> {
        let Some(payment) = self
            .payment_schedule
            .iter_mut()
            .find(|payment| payment.payment_date == payment_date)
        else {
            return Err(DebtError::PaymentNotFound(payment_date));
        };

        payment.paid = true;
        self.touch();
        Ok(())
    }

    pub fn remaining_balance(&self) -> Money {
        let remaining = self
            .payment_schedule
            .iter()
            .filter(|payment| !payment.paid)
            .map(|payment| payment.total_amount.amount)
            .sum::<Decimal>();

        money_from_decimal(remaining, &self.principal.currency_code)
    }

    fn touch(&mut self) {
        self.sync_metadata.updated_at = Utc::now();
        self.sync_metadata.synced_at = None;
    }
}

fn term_in_months(start_date: NaiveDate, due_date: NaiveDate) -> Result<i64, DebtError> {
    let mut months = i64::from(due_date.year() - start_date.year()) * 12
        + i64::from(due_date.month())
        - i64::from(start_date.month());

    if due_date.day() < start_date.day() {
        months -= 1;
    }

    if months <= 0 {
        Err(DebtError::InvalidDateRange {
            start_date,
            due_date,
        })
    } else {
        Ok(months)
    }
}

fn payment_date_for_installment(start_date: NaiveDate, installment: u32) -> NaiveDate {
    start_date
        .checked_add_months(Months::new(installment))
        .unwrap_or(start_date)
}

fn compound_factor(monthly_rate: Decimal, months: i64) -> Decimal {
    let mut factor = Decimal::ONE;
    let base = Decimal::ONE + monthly_rate;

    for _ in 0..months {
        factor *= base;
    }

    factor
}

fn round_money(value: Decimal) -> Decimal {
    value.round_dp(2)
}

fn money_from_decimal(amount: Decimal, currency_code: &str) -> Money {
    Money::new(round_money(amount), currency_code).unwrap()
}

#[cfg(test)]
mod tests {
    use super::*;
    use rust_decimal::Decimal;

    fn cny(amount: Decimal) -> Money {
        Money::new(amount.round_dp(2), "CNY").unwrap()
    }

    fn metadata() -> SyncMetadata {
        SyncMetadata::new(Uuid::new_v4())
    }

    fn twelve_month_term() -> (NaiveDate, NaiveDate) {
        (
            NaiveDate::from_ymd_opt(2026, 1, 1).unwrap(),
            NaiveDate::from_ymd_opt(2027, 1, 1).unwrap(),
        )
    }

    fn loan(method: AmortizationMethod) -> Debt {
        let (start_date, due_date) = twelve_month_term();

        Debt::create(
            Uuid::new_v4(),
            DebtType::Loan,
            "Bank of Tests",
            cny(Decimal::new(100_000, 0)),
            Decimal::new(5, 2),
            start_date,
            due_date,
            Some(method),
            metadata(),
        )
        .unwrap()
    }

    mod debt {
        use super::*;

        mod validation {
            use super::*;

            #[test]
            fn loan_requires_amortization_method() {
                let (start_date, due_date) = twelve_month_term();

                let result = Debt::create(
                    Uuid::new_v4(),
                    DebtType::Loan,
                    "Bank of Tests",
                    cny(Decimal::new(100_000, 0)),
                    Decimal::new(5, 2),
                    start_date,
                    due_date,
                    None,
                    metadata(),
                );

                assert!(matches!(result, Err(DebtError::MissingAmortizationMethod)));
            }

            #[test]
            fn rejects_empty_counterparty() {
                let (start_date, due_date) = twelve_month_term();

                let result = Debt::create(
                    Uuid::new_v4(),
                    DebtType::BorrowedOut,
                    "  ",
                    cny(Decimal::new(1_000, 0)),
                    Decimal::ZERO,
                    start_date,
                    due_date,
                    None,
                    metadata(),
                );

                assert!(matches!(result, Err(DebtError::EmptyCounterparty)));
            }

            #[test]
            fn rejects_non_positive_principal() {
                let (start_date, due_date) = twelve_month_term();

                let result = Debt::create(
                    Uuid::new_v4(),
                    DebtType::BorrowedIn,
                    "Friend",
                    cny(Decimal::ZERO),
                    Decimal::ZERO,
                    start_date,
                    due_date,
                    None,
                    metadata(),
                );

                assert!(matches!(result, Err(DebtError::InvalidPrincipal(_))));
            }

            #[test]
            fn rejects_due_date_before_start_date() {
                let start_date = NaiveDate::from_ymd_opt(2026, 1, 1).unwrap();
                let due_date = NaiveDate::from_ymd_opt(2025, 12, 1).unwrap();

                let result = Debt::create(
                    Uuid::new_v4(),
                    DebtType::BorrowedIn,
                    "Friend",
                    cny(Decimal::new(1_000, 0)),
                    Decimal::ZERO,
                    start_date,
                    due_date,
                    None,
                    metadata(),
                );

                assert!(matches!(result, Err(DebtError::InvalidDateRange { .. })));
            }
        }

        mod amortization {
            use super::*;

            #[test]
            fn create_generates_equal_principal_interest_schedule() {
                let debt = loan(AmortizationMethod::EqualPrincipalInterest);

                assert_eq!(debt.payment_schedule.len(), 12);
                assert_eq!(
                    debt.payment_schedule[0].total_amount,
                    cny(Decimal::new(856_075, 2))
                );
            }

            #[test]
            fn equal_principal_interest_matches_golden_master_values() {
                let debt = loan(AmortizationMethod::EqualPrincipalInterest);
                let total_interest = debt
                    .payment_schedule
                    .iter()
                    .map(|payment| payment.interest_amount.amount)
                    .sum::<Decimal>();
                let expected_total_interest = Decimal::new(272_896, 2);

                assert_eq!(
                    debt.payment_schedule[0].total_amount,
                    cny(Decimal::new(856_075, 2))
                );
                assert!(
                    (total_interest.round_dp(2) - expected_total_interest).abs()
                        <= Decimal::new(2, 2)
                );
            }

            #[test]
            fn equal_principal_matches_golden_master_values() {
                let debt = loan(AmortizationMethod::EqualPrincipal);

                assert_eq!(debt.payment_schedule.len(), 12);
                assert_eq!(
                    debt.payment_schedule[0].total_amount,
                    cny(Decimal::new(875_000, 2))
                );
                assert_eq!(
                    debt.payment_schedule[11].total_amount,
                    cny(Decimal::new(836_806, 2))
                );
            }
        }

        mod payments {
            use super::*;

            #[test]
            fn mark_payment_paid_updates_status_and_remaining_balance() {
                let mut debt = loan(AmortizationMethod::EqualPrincipalInterest);
                let first_payment_date = debt.payment_schedule[0].payment_date;
                let first_payment_amount = debt.payment_schedule[0].total_amount.clone();
                let original_remaining = debt.remaining_balance();

                debt.mark_payment_paid(first_payment_date).unwrap();

                assert!(debt.payment_schedule[0].paid);
                assert_eq!(
                    debt.remaining_balance(),
                    original_remaining.subtract(&first_payment_amount).unwrap()
                );
            }

            #[test]
            fn mark_payment_paid_rejects_unknown_schedule_date() {
                let mut debt = loan(AmortizationMethod::EqualPrincipalInterest);
                let missing_date = NaiveDate::from_ymd_opt(2030, 1, 1).unwrap();

                let result = debt.mark_payment_paid(missing_date);

                assert!(
                    matches!(result, Err(DebtError::PaymentNotFound(date)) if date == missing_date)
                );
            }
        }
    }
}
