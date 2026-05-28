use crate::domain::aggregates::budget::Budget;
use crate::domain::repositories::BudgetRepository;
use crate::domain::value_objects::budget_item::BudgetItem;
use chrono::Utc;
use rust_decimal::Decimal;
use sqlx::{Row, SqlitePool};
use std::str::FromStr;

#[derive(Clone)]
pub struct SqliteBudgetRepository {
    pool: SqlitePool,
}

impl SqliteBudgetRepository {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn row_to_budget_item(row: &sqlx::sqlite::SqliteRow) -> Result<BudgetItem, sqlx::Error> {
        let id: String = row.try_get("id")?;
        let budget_id: String = row.try_get("budget_id")?;
        let category_account_id: String = row.try_get("category_account_id")?;
        let planned_amount_raw: String = row.try_get("planned_amount")?;
        let actual_amount_raw: String = row.try_get("actual_amount")?;
        let notes: Option<String> = row.try_get("notes")?;

        let planned_amount = Decimal::from_str(&planned_amount_raw)
            .map_err(|e| sqlx::Error::Decode(format!("planned_amount='{planned_amount_raw}': {e}").into()))?;
        let actual_amount = Decimal::from_str(&actual_amount_raw)
            .map_err(|e| sqlx::Error::Decode(format!("actual_amount='{actual_amount_raw}': {e}").into()))?;

        Ok(BudgetItem {
            id,
            budget_id,
            category_account_id,
            planned_amount,
            actual_amount,
            notes,
        })
    }

    async fn find_items_by_budget_id(&self, budget_id: &str) -> sqlx::Result<Vec<BudgetItem>> {
        let rows = sqlx::query(
            r#"
            SELECT id, budget_id, category_account_id,
                   CAST(planned_amount AS TEXT) AS planned_amount,
                   CAST(actual_amount AS TEXT) AS actual_amount,
                   notes
            FROM budget_items
            WHERE budget_id = ?
            "#,
        )
        .bind(budget_id)
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(Self::row_to_budget_item).collect()
    }
}

impl BudgetRepository for SqliteBudgetRepository {
    async fn create(&self, budget: &Budget) -> sqlx::Result<()> {
        let now = Utc::now().to_rfc3339();
        sqlx::query(
            r#"
            INSERT INTO budgets (id, name, month, total_amount, currency_code, is_active, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            "#,
        )
        .bind(&budget.id)
        .bind(&budget.name)
        .bind(&budget.month)
        .bind(budget.total_amount.to_string())
        .bind(&budget.currency_code)
        .bind(budget.is_active)
        .bind(&now)
        .bind(&now)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn find_by_id(&self, id: &str) -> sqlx::Result<Option<Budget>> {
        let row = sqlx::query(
            r#"
            SELECT id, name, month, CAST(total_amount AS TEXT) AS total_amount, currency_code, is_active
            FROM budgets
            WHERE id = ?
            "#,
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await?;

        match row {
            Some(row) => {
                let id: String = row.try_get("id")?;
                let name: String = row.try_get("name")?;
                let month: String = row.try_get("month")?;
                let total_amount_raw: String = row.try_get("total_amount")?;
                let currency_code: String = row.try_get("currency_code")?;
                let is_active: bool = row.try_get("is_active")?;

                let total_amount = Decimal::from_str(&total_amount_raw)
                    .map_err(|e| sqlx::Error::Decode(format!("total_amount='{total_amount_raw}': {e}").into()))?;

                let items = self.find_items_by_budget_id(&id).await?;

                Ok(Some(Budget {
                    id,
                    name,
                    month,
                    total_amount,
                    currency_code,
                    is_active,
                    items,
                }))
            }
            None => Ok(None),
        }
    }

    async fn find_by_month(&self, month: &str) -> sqlx::Result<Option<Budget>> {
        let row = sqlx::query(
            r#"
            SELECT id, name, month, CAST(total_amount AS TEXT) AS total_amount, currency_code, is_active
            FROM budgets
            WHERE month = ? AND is_active = TRUE
            "#,
        )
        .bind(month)
        .fetch_optional(&self.pool)
        .await?;

        match row {
            Some(row) => {
                let id: String = row.try_get("id")?;
                let name: String = row.try_get("name")?;
                let month: String = row.try_get("month")?;
                let total_amount_raw: String = row.try_get("total_amount")?;
                let currency_code: String = row.try_get("currency_code")?;
                let is_active: bool = row.try_get("is_active")?;

                let total_amount = Decimal::from_str(&total_amount_raw)
                    .map_err(|e| sqlx::Error::Decode(format!("total_amount='{total_amount_raw}': {e}").into()))?;

                let items = self.find_items_by_budget_id(&id).await?;

                Ok(Some(Budget {
                    id,
                    name,
                    month,
                    total_amount,
                    currency_code,
                    is_active,
                    items,
                }))
            }
            None => Ok(None),
        }
    }

    async fn find_all(&self) -> sqlx::Result<Vec<Budget>> {
        let rows = sqlx::query(
            r#"
            SELECT id, name, month, CAST(total_amount AS TEXT) AS total_amount, currency_code, is_active
            FROM budgets
            ORDER BY month DESC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        let mut budgets = Vec::new();
        for row in rows {
            let id: String = row.try_get("id")?;
            let name: String = row.try_get("name")?;
            let month: String = row.try_get("month")?;
            let total_amount_raw: String = row.try_get("total_amount")?;
            let currency_code: String = row.try_get("currency_code")?;
            let is_active: bool = row.try_get("is_active")?;

            let total_amount = Decimal::from_str(&total_amount_raw)
                .map_err(|e| sqlx::Error::Decode(format!("total_amount='{total_amount_raw}': {e}").into()))?;

            let items = self.find_items_by_budget_id(&id).await?;

            budgets.push(Budget {
                id,
                name,
                month,
                total_amount,
                currency_code,
                is_active,
                items,
            });
        }

        Ok(budgets)
    }

    async fn update(&self, budget: &Budget) -> sqlx::Result<()> {
        let now = Utc::now().to_rfc3339();
        sqlx::query(
            r#"
            UPDATE budgets
            SET name = ?, total_amount = ?, currency_code = ?, is_active = ?, updated_at = ?
            WHERE id = ?
            "#,
        )
        .bind(&budget.name)
        .bind(budget.total_amount.to_string())
        .bind(&budget.currency_code)
        .bind(budget.is_active)
        .bind(&now)
        .bind(&budget.id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn delete(&self, id: &str) -> sqlx::Result<()> {
        sqlx::query("DELETE FROM budgets WHERE id = ?")
            .bind(id)
            .execute(&self.pool)
            .await?;

        Ok(())
    }

    async fn add_item(&self, budget_id: &str, item: &BudgetItem) -> sqlx::Result<()> {
        let now = Utc::now().to_rfc3339();
        sqlx::query(
            r#"
            INSERT INTO budget_items (id, budget_id, category_account_id, planned_amount, actual_amount, notes, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            "#,
        )
        .bind(&item.id)
        .bind(budget_id)
        .bind(&item.category_account_id)
        .bind(item.planned_amount.to_string())
        .bind(item.actual_amount.to_string())
        .bind(&item.notes)
        .bind(&now)
        .bind(&now)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn update_item(&self, item: &BudgetItem) -> sqlx::Result<()> {
        let now = Utc::now().to_rfc3339();
        sqlx::query(
            r#"
            UPDATE budget_items
            SET planned_amount = ?, actual_amount = ?, notes = ?, updated_at = ?
            WHERE id = ?
            "#,
        )
        .bind(item.planned_amount.to_string())
        .bind(item.actual_amount.to_string())
        .bind(&item.notes)
        .bind(&now)
        .bind(&item.id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn remove_item(&self, item_id: &str) -> sqlx::Result<()> {
        sqlx::query("DELETE FROM budget_items WHERE id = ?")
            .bind(item_id)
            .execute(&self.pool)
            .await?;

        Ok(())
    }

    async fn update_actual_amount(
        &self,
        budget_id: &str,
        category_account_id: &str,
        amount: Decimal,
    ) -> sqlx::Result<()> {
        let now = Utc::now().to_rfc3339();
        sqlx::query(
            r#"
            UPDATE budget_items
            SET actual_amount = ?, updated_at = ?
            WHERE budget_id = ? AND category_account_id = ?
            "#,
        )
        .bind(amount.to_string())
        .bind(&now)
        .bind(budget_id)
        .bind(category_account_id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::value_objects::budget_item::BudgetItem;
    use rust_decimal::Decimal;
    use sqlx::sqlite::SqlitePoolOptions;

    async fn setup_test_db() -> SqlitePool {
        let pool = SqlitePoolOptions::new()
            .connect("sqlite::memory:")
            .await
            .unwrap();

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS budgets (
                id TEXT PRIMARY KEY NOT NULL,
                name VARCHAR(100) NOT NULL,
                month VARCHAR(7) NOT NULL,
                total_amount DECIMAL(20,10) NOT NULL DEFAULT 0,
                currency_code VARCHAR(3) NOT NULL DEFAULT 'CNY',
                is_active BOOLEAN NOT NULL DEFAULT TRUE,
                created_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00',
                updated_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00',
                UNIQUE(month, currency_code)
            )
            "#,
        )
        .execute(&pool)
        .await
        .unwrap();

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS budget_items (
                id TEXT PRIMARY KEY NOT NULL,
                budget_id TEXT NOT NULL,
                category_account_id TEXT NOT NULL,
                planned_amount DECIMAL(20,10) NOT NULL DEFAULT 0,
                actual_amount DECIMAL(20,10) NOT NULL DEFAULT 0,
                notes TEXT,
                created_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00',
                updated_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00',
                FOREIGN KEY (budget_id) REFERENCES budgets(id) ON DELETE CASCADE
            )
            "#,
        )
        .execute(&pool)
        .await
        .unwrap();

        pool
    }

    #[tokio::test]
    async fn test_create_and_find_budget() {
        let pool = setup_test_db().await;
        let repo = SqliteBudgetRepository::new(pool);

        let budget = Budget::new(
            "test-id".to_string(),
            "5月预算".to_string(),
            "2026-05".to_string(),
            "CNY".to_string(),
        );

        repo.create(&budget).await.unwrap();

        let found = repo.find_by_id("test-id").await.unwrap();
        assert!(found.is_some());
        let found = found.unwrap();
        assert_eq!(found.name, "5月预算");
        assert_eq!(found.month, "2026-05");
        assert_eq!(found.currency_code, "CNY");
        assert!(found.is_active);
    }

    #[tokio::test]
    async fn test_find_by_month() {
        let pool = setup_test_db().await;
        let repo = SqliteBudgetRepository::new(pool);

        let budget = Budget::new(
            "test-id".to_string(),
            "5月预算".to_string(),
            "2026-05".to_string(),
            "CNY".to_string(),
        );

        repo.create(&budget).await.unwrap();

        let found = repo.find_by_month("2026-05").await.unwrap();
        assert!(found.is_some());
        assert_eq!(found.unwrap().name, "5月预算");
    }

    #[tokio::test]
    async fn test_find_all() {
        let pool = setup_test_db().await;
        let repo = SqliteBudgetRepository::new(pool);

        let budget1 = Budget::new(
            "test-id-1".to_string(),
            "4月预算".to_string(),
            "2026-04".to_string(),
            "CNY".to_string(),
        );
        let budget2 = Budget::new(
            "test-id-2".to_string(),
            "5月预算".to_string(),
            "2026-05".to_string(),
            "CNY".to_string(),
        );

        repo.create(&budget1).await.unwrap();
        repo.create(&budget2).await.unwrap();

        let all = repo.find_all().await.unwrap();
        assert_eq!(all.len(), 2);
        // Should be ordered by month DESC
        assert_eq!(all[0].month, "2026-05");
        assert_eq!(all[1].month, "2026-04");
    }

    #[tokio::test]
    async fn test_update_budget() {
        let pool = setup_test_db().await;
        let repo = SqliteBudgetRepository::new(pool);

        let mut budget = Budget::new(
            "test-id".to_string(),
            "5月预算".to_string(),
            "2026-05".to_string(),
            "CNY".to_string(),
        );

        repo.create(&budget).await.unwrap();

        budget.name = "5月预算（修改）".to_string();
        budget.total_amount = Decimal::new(10000, 0);
        repo.update(&budget).await.unwrap();

        let found = repo.find_by_id("test-id").await.unwrap().unwrap();
        assert_eq!(found.name, "5月预算（修改）");
        assert_eq!(found.total_amount, Decimal::new(10000, 0));
    }

    #[tokio::test]
    async fn test_delete_budget() {
        let pool = setup_test_db().await;
        let repo = SqliteBudgetRepository::new(pool);

        let budget = Budget::new(
            "test-id".to_string(),
            "5月预算".to_string(),
            "2026-05".to_string(),
            "CNY".to_string(),
        );

        repo.create(&budget).await.unwrap();
        repo.delete("test-id").await.unwrap();

        let found = repo.find_by_id("test-id").await.unwrap();
        assert!(found.is_none());
    }

    #[tokio::test]
    async fn test_add_and_find_items() {
        let pool = setup_test_db().await;
        let repo = SqliteBudgetRepository::new(pool);

        let budget = Budget::new(
            "test-id".to_string(),
            "5月预算".to_string(),
            "2026-05".to_string(),
            "CNY".to_string(),
        );

        repo.create(&budget).await.unwrap();

        let item = BudgetItem::new(
            "item-1".to_string(),
            "test-id".to_string(),
            "food-account".to_string(),
            Decimal::new(3000, 0),
            Some("餐饮预算".to_string()),
        );

        repo.add_item("test-id", &item).await.unwrap();

        let found = repo.find_by_id("test-id").await.unwrap().unwrap();
        assert_eq!(found.items.len(), 1);
        assert_eq!(found.items[0].category_account_id, "food-account");
        assert_eq!(found.items[0].planned_amount, Decimal::new(3000, 0));
    }

    #[tokio::test]
    async fn test_update_item() {
        let pool = setup_test_db().await;
        let repo = SqliteBudgetRepository::new(pool);

        let budget = Budget::new(
            "test-id".to_string(),
            "5月预算".to_string(),
            "2026-05".to_string(),
            "CNY".to_string(),
        );

        repo.create(&budget).await.unwrap();

        let mut item = BudgetItem::new(
            "item-1".to_string(),
            "test-id".to_string(),
            "food-account".to_string(),
            Decimal::new(3000, 0),
            None,
        );

        repo.add_item("test-id", &item).await.unwrap();

        item.planned_amount = Decimal::new(5000, 0);
        item.notes = Some("修改后的预算".to_string());
        repo.update_item(&item).await.unwrap();

        let found = repo.find_by_id("test-id").await.unwrap().unwrap();
        assert_eq!(found.items[0].planned_amount, Decimal::new(5000, 0));
        assert_eq!(found.items[0].notes, Some("修改后的预算".to_string()));
    }

    #[tokio::test]
    async fn test_remove_item() {
        let pool = setup_test_db().await;
        let repo = SqliteBudgetRepository::new(pool);

        let budget = Budget::new(
            "test-id".to_string(),
            "5月预算".to_string(),
            "2026-05".to_string(),
            "CNY".to_string(),
        );

        repo.create(&budget).await.unwrap();

        let item = BudgetItem::new(
            "item-1".to_string(),
            "test-id".to_string(),
            "food-account".to_string(),
            Decimal::new(3000, 0),
            None,
        );

        repo.add_item("test-id", &item).await.unwrap();
        repo.remove_item("item-1").await.unwrap();

        let found = repo.find_by_id("test-id").await.unwrap().unwrap();
        assert!(found.items.is_empty());
    }

    #[tokio::test]
    async fn test_update_actual_amount() {
        let pool = setup_test_db().await;
        let repo = SqliteBudgetRepository::new(pool);

        let budget = Budget::new(
            "test-id".to_string(),
            "5月预算".to_string(),
            "2026-05".to_string(),
            "CNY".to_string(),
        );

        repo.create(&budget).await.unwrap();

        let item = BudgetItem::new(
            "item-1".to_string(),
            "test-id".to_string(),
            "food-account".to_string(),
            Decimal::new(3000, 0),
            None,
        );

        repo.add_item("test-id", &item).await.unwrap();

        repo.update_actual_amount("test-id", "food-account", Decimal::new(2500, 0))
            .await
            .unwrap();

        let found = repo.find_by_id("test-id").await.unwrap().unwrap();
        assert_eq!(found.items[0].actual_amount, Decimal::new(2500, 0));
    }
}
