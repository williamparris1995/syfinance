use chrono::NaiveDate;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum GoalType {
    Savings,
    DebtPayoff,
    Investment,
}

impl GoalType {
    pub fn as_str(&self) -> &str {
        match self {
            GoalType::Savings => "savings",
            GoalType::DebtPayoff => "debt_payoff",
            GoalType::Investment => "investment",
        }
    }

    pub fn from_str(s: &str) -> Self {
        match s {
            "savings" => GoalType::Savings,
            "debt_payoff" => GoalType::DebtPayoff,
            "investment" => GoalType::Investment,
            _ => GoalType::Savings,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Goal {
    pub id: String,
    pub name: String,
    pub goal_type: GoalType,
    pub target_amount: Decimal,
    pub current_amount: Decimal,
    pub currency_code: String,
    pub deadline: Option<NaiveDate>,
    pub linked_account_id: Option<String>,
    pub notes: Option<String>,
    pub is_completed: bool,
    pub completed_at: Option<String>,
}

impl Goal {
    pub fn new(
        id: String,
        name: String,
        goal_type: GoalType,
        target_amount: Decimal,
        currency_code: String,
    ) -> Self {
        Self {
            id,
            name,
            goal_type,
            target_amount,
            current_amount: Decimal::ZERO,
            currency_code,
            deadline: None,
            linked_account_id: None,
            notes: None,
            is_completed: false,
            completed_at: None,
        }
    }

    pub fn progress_percentage(&self) -> f64 {
        if self.target_amount.is_zero() {
            return 0.0;
        }
        let ratio = self.current_amount / self.target_amount;
        ratio.to_string().parse::<f64>().unwrap_or(0.0) * 100.0
    }

    pub fn remaining_amount(&self) -> Decimal {
        self.target_amount - self.current_amount
    }

    pub fn is_overdue(&self) -> bool {
        if let Some(deadline) = self.deadline {
            let today = chrono::Utc::now().naive_utc().date();
            deadline < today && !self.is_completed
        } else {
            false
        }
    }

    pub fn add_progress(&mut self, amount: Decimal) {
        self.current_amount += amount;
        if self.current_amount >= self.target_amount {
            self.mark_completed();
        }
    }

    pub fn mark_completed(&mut self) {
        self.is_completed = true;
        self.completed_at = Some(chrono::Utc::now().to_rfc3339());
    }

    pub fn set_deadline(&mut self, deadline: NaiveDate) {
        self.deadline = Some(deadline);
    }

    pub fn link_account(&mut self, account_id: String) {
        self.linked_account_id = Some(account_id);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_goal_creation() {
        let goal = Goal::new(
            "test-id".to_string(),
            "买车基金".to_string(),
            GoalType::Savings,
            Decimal::new(200000, 0),
            "CNY".to_string(),
        );
        assert_eq!(goal.name, "买车基金");
        assert_eq!(goal.goal_type, GoalType::Savings);
        assert!(!goal.is_completed);
    }

    #[test]
    fn test_progress_percentage() {
        let mut goal = Goal::new(
            "test-id".to_string(),
            "买车基金".to_string(),
            GoalType::Savings,
            Decimal::new(200000, 0),
            "CNY".to_string(),
        );
        goal.add_progress(Decimal::new(100000, 0));
        assert!((goal.progress_percentage() - 50.0).abs() < 0.01);
    }

    #[test]
    fn test_mark_completed() {
        let mut goal = Goal::new(
            "test-id".to_string(),
            "买车基金".to_string(),
            GoalType::Savings,
            Decimal::new(200000, 0),
            "CNY".to_string(),
        );
        goal.add_progress(Decimal::new(200000, 0));
        assert!(goal.is_completed);
        assert!(goal.completed_at.is_some());
    }
}
