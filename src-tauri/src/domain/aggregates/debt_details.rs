use chrono::{Datelike, Months, NaiveDate};
use rust_decimal::Decimal;
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AmortizationMethod {
    EqualPrincipalInterest,
    EqualPrincipal,
    LumpSum,
}

impl std::fmt::Display for AmortizationMethod {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::EqualPrincipalInterest => write!(f, "EqualPrincipalInterest"),
            Self::EqualPrincipal => write!(f, "EqualPrincipal"),
            Self::LumpSum => write!(f, "LumpSum"),
        }
    }
}

#[derive(Debug, Clone)]
pub struct PaymentScheduleEntry {
    pub id: Uuid,
    pub debt_id: Uuid,
    pub payment_date: NaiveDate,
    pub principal_amount: Decimal,
    pub interest_amount: Decimal,
    pub total_amount: Decimal,
    pub paid: bool,
    pub transaction_id: Option<Uuid>,
}

#[derive(Debug, Clone)]
pub struct DebtDetails {
    pub id: Uuid,
    pub account_id: Uuid,
    pub counterparty: String,
    pub interest_rate: Decimal,
    pub amortization_method: AmortizationMethod,
    pub start_date: NaiveDate,
    pub due_date: NaiveDate,
    pub total_principal: Decimal,
    pub transaction_id: Option<Uuid>,
    pub payment_schedule: Vec<PaymentScheduleEntry>,
}

impl DebtDetails {
    pub fn new(
        id: Uuid,
        account_id: Uuid,
        counterparty: String,
        interest_rate: Decimal,
        amortization_method: AmortizationMethod,
        start_date: NaiveDate,
        due_date: NaiveDate,
        total_principal: Decimal,
    ) -> Self {
        Self {
            id,
            account_id,
            counterparty,
            interest_rate,
            amortization_method,
            start_date,
            due_date,
            total_principal,
            transaction_id: None,
            payment_schedule: Vec::new(),
        }
    }

    pub fn generate_schedule(&mut self) {
        self.payment_schedule.clear();
        match self.amortization_method {
            AmortizationMethod::LumpSum => self.generate_lump_sum(),
            AmortizationMethod::EqualPrincipalInterest => self.generate_equal_principal_interest(),
            AmortizationMethod::EqualPrincipal => self.generate_equal_principal(),
        }
    }

    fn generate_lump_sum(&mut self) {
        let months = self.term_in_months();
        let years = Decimal::from(months) / Decimal::from(12);
        let interest = (self.total_principal * self.interest_rate * years).round_dp(2);
        self.payment_schedule.push(PaymentScheduleEntry {
            id: Uuid::new_v4(),
            debt_id: self.id,
            payment_date: self.due_date,
            principal_amount: self.total_principal,
            interest_amount: interest,
            total_amount: (self.total_principal + interest).round_dp(2),
            paid: false,
            transaction_id: None,
        });
    }

    fn generate_equal_principal_interest(&mut self) {
        let months = self.term_in_months();
        let monthly_rate = self.interest_rate / Decimal::from(12u32);
        let monthly_payment = if monthly_rate.is_zero() {
            self.total_principal / Decimal::from(months)
        } else {
            let factor = compound_factor(monthly_rate, months);
            self.total_principal * monthly_rate * factor / (factor - Decimal::ONE)
        }
        .round_dp(2);

        let mut remaining = self.total_principal;
        for installment in 1..=months {
            let interest = (remaining * monthly_rate).round_dp(2);
            let principal = if installment == months {
                remaining
            } else {
                (monthly_payment - interest).max(Decimal::ZERO)
            }
            .round_dp(2);
            let total = (principal + interest).round_dp(2);
            remaining -= principal;

            self.payment_schedule.push(PaymentScheduleEntry {
                id: Uuid::new_v4(),
                debt_id: self.id,
                payment_date: add_months(self.start_date, installment as u32),
                principal_amount: principal,
                interest_amount: interest,
                total_amount: total,
                paid: false,
                transaction_id: None,
            });
        }
    }

    fn generate_equal_principal(&mut self) {
        let months = self.term_in_months();
        let monthly_rate = self.interest_rate / Decimal::from(12u32);
        let monthly_principal = (self.total_principal / Decimal::from(months)).round_dp(2);
        let mut remaining = self.total_principal;

        for installment in 1..=months {
            let interest = (remaining * monthly_rate).round_dp(2);
            let principal = if installment == months {
                remaining
            } else {
                monthly_principal
            }
            .round_dp(2);
            let total = (principal + interest).round_dp(2);
            remaining -= principal;

            self.payment_schedule.push(PaymentScheduleEntry {
                id: Uuid::new_v4(),
                debt_id: self.id,
                payment_date: add_months(self.start_date, installment as u32),
                principal_amount: principal,
                interest_amount: interest,
                total_amount: total,
                paid: false,
                transaction_id: None,
            });
        }
    }

    fn term_in_months(&self) -> i64 {
        let mut months = i64::from(self.due_date.year() - self.start_date.year()) * 12
            + i64::from(self.due_date.month() as i32 - self.start_date.month() as i32);
        if self.due_date.day() < self.start_date.day() {
            months -= 1;
        }
        months.max(1)
    }

    pub fn mark_paid(&mut self, schedule_id: Uuid, transaction_id: Uuid) -> Result<(), &'static str> {
        let entry = self
            .payment_schedule
            .iter_mut()
            .find(|e| e.id == schedule_id)
            .ok_or("Schedule entry not found")?;
        if entry.paid {
            return Err("Already paid");
        }
        entry.paid = true;
        entry.transaction_id = Some(transaction_id);
        Ok(())
    }

    pub fn remaining_principal(&self) -> Decimal {
        let paid: Decimal = self
            .payment_schedule
            .iter()
            .filter(|e| e.paid)
            .map(|e| e.principal_amount)
            .sum();
        self.total_principal - paid
    }
}

fn add_months(date: NaiveDate, months: u32) -> NaiveDate {
    date.checked_add_months(Months::new(months))
        .unwrap_or(date)
}

fn compound_factor(monthly_rate: Decimal, months: i64) -> Decimal {
    let mut factor = Decimal::ONE;
    let base = Decimal::ONE + monthly_rate;
    for _ in 0..months {
        factor *= base;
    }
    factor
}

#[cfg(test)]
mod tests {
    use super::*;

    fn dec(val: i64) -> Decimal {
        Decimal::new(val, 2)
    }

    fn dec_rate(val: i64) -> Decimal {
        Decimal::new(val, 4)
    }

    fn lump_sum_debt() -> DebtDetails {
        let mut d = DebtDetails::new(
            Uuid::new_v4(),
            Uuid::new_v4(),
            "Friend".into(),
            Decimal::ZERO,
            AmortizationMethod::LumpSum,
            NaiveDate::from_ymd_opt(2026, 1, 1).unwrap(),
            NaiveDate::from_ymd_opt(2026, 6, 1).unwrap(),
            dec(5000000),
        );
        d.generate_schedule();
        d
    }

    fn amortized_debt(method: AmortizationMethod) -> DebtDetails {
        let mut d = DebtDetails::new(
            Uuid::new_v4(),
            Uuid::new_v4(),
            "Bank".into(),
            dec_rate(500),
            method,
            NaiveDate::from_ymd_opt(2026, 1, 1).unwrap(),
            NaiveDate::from_ymd_opt(2027, 1, 1).unwrap(),
            dec(10000000),
        );
        d.generate_schedule();
        d
    }

    #[test]
    fn lump_sum_creates_single_payment_at_due_date() {
        let debt = lump_sum_debt();
        assert_eq!(debt.payment_schedule.len(), 1);
        assert_eq!(debt.payment_schedule[0].principal_amount, dec(5000000));
        assert_eq!(debt.payment_schedule[0].interest_amount, Decimal::ZERO);
        assert_eq!(
            debt.payment_schedule[0].payment_date,
            NaiveDate::from_ymd_opt(2026, 6, 1).unwrap()
        );
        assert!(!debt.payment_schedule[0].paid);
    }

    #[test]
    fn equal_principal_interest_creates_12_month_schedule() {
        let debt = amortized_debt(AmortizationMethod::EqualPrincipalInterest);
        assert_eq!(debt.payment_schedule.len(), 12);
        // First payment should be ~8,560.75 (principal + interest)
        assert_eq!(debt.payment_schedule[0].total_amount, dec(856075));
    }

    #[test]
    fn equal_principal_interest_total_interest_is_correct() {
        let debt = amortized_debt(AmortizationMethod::EqualPrincipalInterest);
        let total_interest: Decimal = debt
            .payment_schedule
            .iter()
            .map(|e| e.interest_amount)
            .sum();
        // ~2,728.96 interest on 100k at 5% for 12 months
        let diff = (total_interest - dec(272896)).abs();
        assert!(diff <= dec(2), "total_interest={total_interest}");
    }

    #[test]
    fn equal_principal_schedule_decreases_over_time() {
        let debt = amortized_debt(AmortizationMethod::EqualPrincipal);
        assert_eq!(debt.payment_schedule.len(), 12);
        assert!(debt.payment_schedule[0].total_amount > debt.payment_schedule[11].total_amount);
    }

    #[test]
    fn mark_paid_updates_entry() {
        let mut debt = lump_sum_debt();
        let entry_id = debt.payment_schedule[0].id;
        let txn_id = Uuid::new_v4();

        debt.mark_paid(entry_id, txn_id).unwrap();

        assert!(debt.payment_schedule[0].paid);
        assert_eq!(debt.payment_schedule[0].transaction_id, Some(txn_id));
    }

    #[test]
    fn mark_paid_rejects_already_paid() {
        let mut debt = lump_sum_debt();
        let entry_id = debt.payment_schedule[0].id;
        debt.mark_paid(entry_id, Uuid::new_v4()).unwrap();

        let result = debt.mark_paid(entry_id, Uuid::new_v4());
        assert_eq!(result, Err("Already paid"));
    }

    #[test]
    fn mark_paid_rejects_unknown_id() {
        let mut debt = lump_sum_debt();
        let result = debt.mark_paid(Uuid::new_v4(), Uuid::new_v4());
        assert_eq!(result, Err("Schedule entry not found"));
    }

    #[test]
    fn remaining_principal_decreases_after_payment() {
        let mut debt = lump_sum_debt();
        assert_eq!(debt.remaining_principal(), dec(5000000));

        let entry_id = debt.payment_schedule[0].id;
        debt.mark_paid(entry_id, Uuid::new_v4()).unwrap();

        assert_eq!(debt.remaining_principal(), Decimal::ZERO);
    }

    #[test]
    fn generate_schedule_replaces_existing_schedule() {
        let mut debt = lump_sum_debt();
        assert_eq!(debt.payment_schedule.len(), 1);

        debt.generate_schedule();
        assert_eq!(debt.payment_schedule.len(), 1);
    }
}
