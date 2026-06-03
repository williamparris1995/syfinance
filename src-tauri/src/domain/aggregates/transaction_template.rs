use chrono::{Days, Months, NaiveDate};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TemplateDirection {
    Expense,
    Income,
    Transfer,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TemplateCycle {
    Weekly,
    Monthly,
    Yearly,
    Custom { days: u32 },
}

#[derive(Debug, Clone)]
pub struct TransactionTemplate {
    pub id: uuid::Uuid,
    pub name: String,
    pub description: Option<String>,
    pub amount: Decimal,
    pub direction: TemplateDirection,
    pub source_account_id: uuid::Uuid,
    pub destination_account_id: Option<uuid::Uuid>,
    pub cycle: TemplateCycle,
    pub billing_day: Option<u8>,
    pub next_date: NaiveDate,
    pub start_date: NaiveDate,
    pub end_date: Option<NaiveDate>,
    pub auto_record: bool,
    pub paused: bool,
    pub last_transaction_id: Option<uuid::Uuid>,
}

impl TransactionTemplate {
    // TODO: will be used when template service uses domain methods directly
    #[allow(dead_code)]
    pub fn is_due(&self, today: NaiveDate) -> bool {
        !self.paused && self.next_date <= today && self.end_date.is_none_or(|end| today <= end)
    }

    pub fn calculate_next_date(&self) -> Option<NaiveDate> {
        match &self.cycle {
            TemplateCycle::Weekly => self.next_date.checked_add_days(Days::new(7)),
            TemplateCycle::Monthly => self.next_date.checked_add_months(Months::new(1)),
            TemplateCycle::Yearly => self.next_date.checked_add_months(Months::new(12)),
            TemplateCycle::Custom { days } => {
                self.next_date.checked_add_days(Days::new(*days as u64))
            }
        }
    }

    pub fn advance_to_next(&mut self) {
        if let Some(next) = self.calculate_next_date() {
            self.next_date = next;
        }
    }

    // TODO: will be used when pause is routed through domain method
    #[allow(dead_code)]
    pub fn pause(&mut self) {
        self.paused = true;
    }

    // TODO: will be used when resume is routed through domain method
    #[allow(dead_code)]
    pub fn resume(&mut self) {
        self.paused = false;
    }
}
