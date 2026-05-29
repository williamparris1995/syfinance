use chrono::{Days, Months, NaiveDate};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SubscriptionCycle {
    Weekly,
    Monthly,
    Yearly,
    Custom { days: u32 },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SubscriptionDirection {
    Expense,
    Income,
}

#[derive(Debug, Clone)]
pub struct Subscription {
    pub id: uuid::Uuid,
    pub name: String,
    pub amount: Decimal,
    pub direction: SubscriptionDirection,
    pub cycle: SubscriptionCycle,
    pub billing_day: Option<u8>,
    pub next_billing_date: NaiveDate,
    pub start_date: NaiveDate,
    pub end_date: Option<NaiveDate>,
    pub auto_record: bool,
    pub paused: bool,
    pub source_account_id: uuid::Uuid,
    pub category: Option<String>,
    pub description: Option<String>,
    pub last_transaction_id: Option<uuid::Uuid>,
}

impl Subscription {
    pub fn is_due(&self, today: NaiveDate) -> bool {
        !self.paused
            && self.next_billing_date <= today
            && self.end_date.map_or(true, |end| today <= end)
    }

    pub fn calculate_next_billing_date(&self) -> Option<NaiveDate> {
        match &self.cycle {
            SubscriptionCycle::Weekly => self.next_billing_date.checked_add_days(Days::new(7)),
            SubscriptionCycle::Monthly => self.next_billing_date.checked_add_months(Months::new(1)),
            SubscriptionCycle::Yearly => self.next_billing_date.checked_add_months(Months::new(12)),
            SubscriptionCycle::Custom { days } => self
                .next_billing_date
                .checked_add_days(Days::new(*days as u64)),
        }
    }

    pub fn advance_to_next(&mut self) {
        if let Some(next) = self.calculate_next_billing_date() {
            self.next_billing_date = next;
        }
    }

    pub fn pause(&mut self) {
        self.paused = true;
    }

    pub fn resume(&mut self) {
        self.paused = false;
    }
}
