use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BudgetItem {
    pub id: String,
    pub budget_id: String,
    pub category_account_id: String,
    pub planned_amount: Decimal,
    pub actual_amount: Decimal,
    pub notes: Option<String>,
}

impl BudgetItem {
    pub fn new(
        id: String,
        budget_id: String,
        category_account_id: String,
        planned_amount: Decimal,
        notes: Option<String>,
    ) -> Self {
        Self {
            id,
            budget_id,
            category_account_id,
            planned_amount,
            actual_amount: Decimal::ZERO,
            notes,
        }
    }

    pub fn remaining(&self) -> Decimal {
        self.planned_amount - self.actual_amount
    }

    pub fn usage_percentage(&self) -> f64 {
        if self.planned_amount.is_zero() {
            return 0.0;
        }
        let ratio = self.actual_amount / self.planned_amount;
        ratio.to_string().parse::<f64>().unwrap_or(0.0) * 100.0
    }

    pub fn is_over_budget(&self) -> bool {
        self.actual_amount > self.planned_amount
    }

    pub fn record_actual(&mut self, amount: Decimal) {
        self.actual_amount = amount;
    }
}
