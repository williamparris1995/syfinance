use crate::domain::value_objects::budget_item::BudgetItem;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Budget {
    pub id: String,
    pub name: String,
    pub month: String, // YYYY-MM 格式
    pub total_amount: Decimal,
    pub currency_code: String,
    pub is_active: bool,
    pub items: Vec<BudgetItem>,
}

impl Budget {
    pub fn new(id: String, name: String, month: String, currency_code: String) -> Self {
        Self {
            id,
            name,
            month,
            total_amount: Decimal::ZERO,
            currency_code,
            is_active: true,
            items: Vec::new(),
        }
    }

    // TODO: will be used when budget item editing is implemented in service layer
    #[allow(dead_code)]
    pub fn add_item(&mut self, item: BudgetItem) {
        self.total_amount += item.planned_amount;
        self.items.push(item);
    }

    // TODO: will be used when budget item removal is implemented in service layer
    #[allow(dead_code)]
    pub fn remove_item(&mut self, item_id: &str) {
        if let Some(pos) = self.items.iter().position(|i| i.id == item_id) {
            let item = self.items.remove(pos);
            self.total_amount -= item.planned_amount;
        }
    }

    // TODO: will be used when budget item amount editing is implemented in service layer
    #[allow(dead_code)]
    pub fn update_item_amount(&mut self, item_id: &str, new_amount: Decimal) {
        if let Some(item) = self.items.iter_mut().find(|i| i.id == item_id) {
            self.total_amount -= item.planned_amount;
            item.planned_amount = new_amount;
            self.total_amount += new_amount;
        }
    }

    pub fn total_actual(&self) -> Decimal {
        self.items.iter().map(|i| i.actual_amount).sum()
    }

    pub fn total_remaining(&self) -> Decimal {
        self.total_amount - self.total_actual()
    }

    pub fn overall_usage_percentage(&self) -> f64 {
        if self.total_amount.is_zero() {
            return 0.0;
        }
        let ratio = self.total_actual() / self.total_amount;
        ratio.to_string().parse::<f64>().unwrap_or(0.0) * 100.0
    }

    // TODO: will be used when budget overspend alerts are implemented
    #[allow(dead_code)]
    pub fn is_over_budget(&self) -> bool {
        self.total_actual() > self.total_amount
    }

    // TODO: will be used when budget activation toggling is implemented
    #[allow(dead_code)]
    pub fn deactivate(&mut self) {
        self.is_active = false;
    }

    // TODO: will be used when budget activation toggling is implemented
    #[allow(dead_code)]
    pub fn activate(&mut self) {
        self.is_active = true;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rust_decimal::Decimal;

    #[test]
    fn test_budget_creation() {
        let budget = Budget::new(
            "test-id".to_string(),
            "5月预算".to_string(),
            "2026-05".to_string(),
            "CNY".to_string(),
        );
        assert_eq!(budget.id, "test-id");
        assert_eq!(budget.name, "5月预算");
        assert_eq!(budget.month, "2026-05");
        assert!(budget.is_active);
        assert!(budget.items.is_empty());
    }

    #[test]
    fn test_add_item() {
        let mut budget = Budget::new(
            "test-id".to_string(),
            "5月预算".to_string(),
            "2026-05".to_string(),
            "CNY".to_string(),
        );

        let item = BudgetItem::new(
            "item-1".to_string(),
            "test-id".to_string(),
            "food-account".to_string(),
            Decimal::new(3000, 0),
            Some("餐饮预算".to_string()),
        );

        budget.add_item(item);
        assert_eq!(budget.items.len(), 1);
        assert_eq!(budget.total_amount, Decimal::new(3000, 0));
    }

    #[test]
    fn test_over_budget() {
        let mut budget = Budget::new(
            "test-id".to_string(),
            "5月预算".to_string(),
            "2026-05".to_string(),
            "CNY".to_string(),
        );

        let mut item = BudgetItem::new(
            "item-1".to_string(),
            "test-id".to_string(),
            "food-account".to_string(),
            Decimal::new(3000, 0),
            None,
        );
        item.record_actual(Decimal::new(3500, 0));
        budget.add_item(item);

        assert!(budget.is_over_budget());
        assert_eq!(budget.total_remaining(), Decimal::new(-500, 0));
    }

    #[test]
    fn test_remove_item() {
        let mut budget = Budget::new(
            "test-id".to_string(),
            "5月预算".to_string(),
            "2026-05".to_string(),
            "CNY".to_string(),
        );

        let item = BudgetItem::new(
            "item-1".to_string(),
            "test-id".to_string(),
            "food-account".to_string(),
            Decimal::new(3000, 0),
            None,
        );

        budget.add_item(item);
        assert_eq!(budget.items.len(), 1);
        assert_eq!(budget.total_amount, Decimal::new(3000, 0));

        budget.remove_item("item-1");
        assert!(budget.items.is_empty());
        assert_eq!(budget.total_amount, Decimal::ZERO);
    }
}
