use rust_decimal::Decimal;
use sqlx::SqlitePool;
use tracing::info;

pub struct BudgetService {
    pool: SqlitePool,
}

impl BudgetService {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    /// Compute actual spending for each budget item from transaction entries.
    pub async fn compute_budget_actuals(&self, budget_id: &str) -> Result<(), String> {
        info!(budget_id = budget_id, "Computing budget actuals");

        // 1. Get the budget month
        let budget_month: (String,) =
            sqlx::query_as("SELECT month FROM budgets WHERE id = ?")
                .bind(budget_id)
                .fetch_one(&self.pool)
                .await
                .map_err(|e| format!("Budget not found: {}", e))?;

        let month = &budget_month.0; // e.g. "2026-06"

        // 2. Get all budget items
        let items: Vec<(String, String)> = sqlx::query_as(
            "SELECT id, category_account_id FROM budget_items WHERE budget_id = ?",
        )
        .bind(budget_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| format!("Failed to fetch budget items: {}", e))?;

        if items.is_empty() {
            return Ok(());
        }

        // 3. Build date range for the month
        let start_date = format!("{}-01", month);
        let end_date = format!("{}-{}", month, last_day_of_month(month));

        // 4. For each item, compute actual from transactions
        for (item_id, category_account_id) in &items {
            let actual: (String,) = sqlx::query_as(
                "SELECT CAST(COALESCE(SUM(COALESCE(e.debit_amount, 0)), 0) AS TEXT) \
                 FROM transaction_entries e \
                 JOIN transactions t ON e.transaction_id = t.id \
                 WHERE e.deleted_at IS NULL \
                 AND t.deleted_at IS NULL \
                 AND e.account_id = ? \
                 AND t.transaction_date >= ? \
                 AND t.transaction_date <= ?",
            )
            .bind(category_account_id)
            .bind(&start_date)
            .bind(&end_date)
            .fetch_one(&self.pool)
            .await
            .map_err(|e| format!("Failed to compute actual for item {}: {}", item_id, e))?;

            let amount = actual.0.parse::<Decimal>().unwrap_or(Decimal::ZERO);

            sqlx::query("UPDATE budget_items SET actual_amount = ? WHERE id = ?")
                .bind(amount.to_string())
                .bind(item_id)
                .execute(&self.pool)
                .await
                .map_err(|e| format!("Failed to update actual: {}", e))?;

            info!(
                item_id = item_id,
                category_account_id = category_account_id,
                actual = %amount,
                "Updated budget item actual"
            );
        }

        Ok(())
    }

    /// Clone a budget to another month, copying items with planned amounts and resetting actuals.
    pub async fn clone_budget_to_month(
        &self,
        source_budget_id: &str,
        target_month: &str,
    ) -> Result<String, String> {
        info!(source_id = source_budget_id, target_month = target_month, "Cloning budget");

        // 1. Verify source budget exists
        let _source: (String, String) = sqlx::query_as(
            "SELECT name, currency_code FROM budgets WHERE id = ?",
        )
        .bind(source_budget_id)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| format!("Source budget not found: {}", e))?;

        // 2. Check target month doesn't already have a budget
        let exists: Option<(String,)> = sqlx::query_as(
            "SELECT id FROM budgets WHERE month = ?",
        )
        .bind(target_month)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| format!("Check failed: {}", e))?;

        if exists.is_some() {
            return Err(format!("Budget already exists for {}", target_month));
        }

        // 3. Create new budget from source
        let new_id = uuid::Uuid::new_v4().to_string();
        sqlx::query(
            "INSERT INTO budgets (id, name, month, total_amount, currency_code, is_active, created_at, updated_at) \
             SELECT ?, name, ?, total_amount, currency_code, 1, datetime('now'), datetime('now') \
             FROM budgets WHERE id = ?",
        )
        .bind(&new_id)
        .bind(target_month)
        .bind(source_budget_id)
        .execute(&self.pool)
        .await
        .map_err(|e| format!("Failed to clone budget: {}", e))?;

        // 4. Copy items with planned amounts, reset actual to 0
        sqlx::query(
            "INSERT INTO budget_items (id, budget_id, category_account_id, planned_amount, actual_amount, notes, created_at, updated_at) \
             SELECT LOWER(HEX(RANDOMBLOB(16))), ?, category_account_id, planned_amount, '0', notes, datetime('now'), datetime('now') \
             FROM budget_items WHERE budget_id = ?",
        )
        .bind(&new_id)
        .bind(source_budget_id)
        .execute(&self.pool)
        .await
        .map_err(|e| format!("Failed to clone budget items: {}", e))?;

        info!(new_id = new_id, "Budget cloned successfully");
        Ok(new_id)
    }
}

fn last_day_of_month(month: &str) -> String {
    let parts: Vec<&str> = month.split('-').collect();
    if parts.len() < 2 {
        return "31".to_string();
    }
    let year: i32 = parts[0].parse().unwrap_or(2026);
    let month_num: u32 = parts[1].parse().unwrap_or(1);
    let days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    let mut d = days[(month_num - 1) as usize];
    if month_num == 2 && (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) {
        d = 29;
    }
    format!("{:02}", d)
}
