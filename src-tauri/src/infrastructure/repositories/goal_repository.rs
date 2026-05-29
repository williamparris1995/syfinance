use crate::domain::aggregates::goal::{Goal, GoalType};
use crate::domain::repositories::GoalRepository;
use chrono::NaiveDate;
use rust_decimal::Decimal;
use sqlx::{Row, SqlitePool};
use std::str::FromStr;

#[derive(Clone)]
pub struct SqliteGoalRepository {
    pool: SqlitePool,
}

impl SqliteGoalRepository {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn row_to_goal(row: &sqlx::sqlite::SqliteRow) -> Result<Goal, sqlx::Error> {
        let id: String = row.try_get("id")?;
        let name: String = row.try_get("name")?;
        let goal_type_str: String = row.try_get("goal_type")?;
        let target_amount_raw: String = row.try_get("target_amount")?;
        let current_amount_raw: String = row.try_get("current_amount")?;
        let currency_code: String = row.try_get("currency_code")?;
        let deadline: Option<NaiveDate> = row.try_get("deadline")?;
        let linked_account_id: Option<String> = row.try_get("linked_account_id")?;
        let notes: Option<String> = row.try_get("notes")?;
        let is_completed: bool = row.try_get("is_completed")?;
        let completed_at: Option<String> = row.try_get("completed_at")?;

        let target_amount = Decimal::from_str(&target_amount_raw).map_err(|e| {
            sqlx::Error::Decode(format!("target_amount='{target_amount_raw}': {e}").into())
        })?;
        let current_amount = Decimal::from_str(&current_amount_raw).map_err(|e| {
            sqlx::Error::Decode(format!("current_amount='{current_amount_raw}': {e}").into())
        })?;

        Ok(Goal {
            id,
            name,
            goal_type: GoalType::from_str(&goal_type_str),
            target_amount,
            current_amount,
            currency_code,
            deadline,
            linked_account_id,
            notes,
            is_completed,
            completed_at,
        })
    }

    const SELECT_COLUMNS: &'static str =
        "id, name, goal_type, CAST(target_amount AS TEXT) AS target_amount, CAST(current_amount AS TEXT) AS current_amount, currency_code, deadline, linked_account_id, notes, is_completed, completed_at";
}

impl GoalRepository for SqliteGoalRepository {
    async fn create(&self, goal: &Goal) -> sqlx::Result<()> {
        let now = chrono::Utc::now().to_rfc3339();
        sqlx::query(
            r#"
            INSERT INTO goals (id, name, goal_type, target_amount, current_amount, currency_code, deadline, linked_account_id, notes, is_completed, completed_at, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            "#,
        )
        .bind(&goal.id)
        .bind(&goal.name)
        .bind(goal.goal_type.as_str())
        .bind(goal.target_amount.to_string())
        .bind(goal.current_amount.to_string())
        .bind(&goal.currency_code)
        .bind(goal.deadline)
        .bind(&goal.linked_account_id)
        .bind(&goal.notes)
        .bind(goal.is_completed)
        .bind(&goal.completed_at)
        .bind(&now)
        .bind(&now)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn find_by_id(&self, id: &str) -> sqlx::Result<Option<Goal>> {
        let sql = format!("SELECT {} FROM goals WHERE id = ?", Self::SELECT_COLUMNS);
        let row = sqlx::query(&sql)
            .bind(id)
            .fetch_optional(&self.pool)
            .await?;

        row.map(|r| Self::row_to_goal(&r)).transpose()
    }

    async fn find_all(&self) -> sqlx::Result<Vec<Goal>> {
        let sql = format!(
            "SELECT {} FROM goals ORDER BY created_at DESC",
            Self::SELECT_COLUMNS
        );
        let rows = sqlx::query(&sql).fetch_all(&self.pool).await?;

        rows.iter().map(Self::row_to_goal).collect()
    }

    async fn find_active(&self) -> sqlx::Result<Vec<Goal>> {
        let sql = format!(
            "SELECT {} FROM goals WHERE is_completed = FALSE ORDER BY deadline ASC",
            Self::SELECT_COLUMNS
        );
        let rows = sqlx::query(&sql).fetch_all(&self.pool).await?;

        rows.iter().map(Self::row_to_goal).collect()
    }

    async fn find_completed(&self) -> sqlx::Result<Vec<Goal>> {
        let sql = format!(
            "SELECT {} FROM goals WHERE is_completed = TRUE ORDER BY completed_at DESC",
            Self::SELECT_COLUMNS
        );
        let rows = sqlx::query(&sql).fetch_all(&self.pool).await?;

        rows.iter().map(Self::row_to_goal).collect()
    }

    async fn update(&self, goal: &Goal) -> sqlx::Result<()> {
        let now = chrono::Utc::now().to_rfc3339();
        sqlx::query(
            r#"
            UPDATE goals
            SET name = ?, goal_type = ?, target_amount = ?, current_amount = ?, currency_code = ?, deadline = ?, linked_account_id = ?, notes = ?, is_completed = ?, completed_at = ?, updated_at = ?
            WHERE id = ?
            "#,
        )
        .bind(&goal.name)
        .bind(goal.goal_type.as_str())
        .bind(goal.target_amount.to_string())
        .bind(goal.current_amount.to_string())
        .bind(&goal.currency_code)
        .bind(goal.deadline)
        .bind(&goal.linked_account_id)
        .bind(&goal.notes)
        .bind(goal.is_completed)
        .bind(&goal.completed_at)
        .bind(&now)
        .bind(&goal.id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn delete(&self, id: &str) -> sqlx::Result<()> {
        sqlx::query("DELETE FROM goals WHERE id = ?")
            .bind(id)
            .execute(&self.pool)
            .await?;

        Ok(())
    }

    async fn add_progress(&self, id: &str, amount: Decimal) -> sqlx::Result<()> {
        let now = chrono::Utc::now().to_rfc3339();
        sqlx::query(
            r#"
            UPDATE goals
            SET current_amount = current_amount + ?, updated_at = ?
            WHERE id = ?
            "#,
        )
        .bind(amount.to_string())
        .bind(&now)
        .bind(id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use sqlx::sqlite::SqlitePoolOptions;

    async fn setup_test_db() -> SqlitePool {
        let pool = SqlitePoolOptions::new()
            .connect("sqlite::memory:")
            .await
            .unwrap();

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS goals (
                id TEXT PRIMARY KEY NOT NULL,
                name VARCHAR(100) NOT NULL,
                goal_type VARCHAR(20) NOT NULL,
                target_amount DECIMAL(20,10) NOT NULL,
                current_amount DECIMAL(20,10) NOT NULL DEFAULT 0,
                currency_code VARCHAR(3) NOT NULL DEFAULT 'CNY',
                deadline DATE,
                linked_account_id TEXT,
                notes TEXT,
                is_completed BOOLEAN NOT NULL DEFAULT FALSE,
                completed_at TIMESTAMP,
                created_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00',
                updated_at TIMESTAMP NOT NULL DEFAULT '2026-01-01 00:00:00'
            )
            "#,
        )
        .execute(&pool)
        .await
        .unwrap();

        pool
    }

    #[tokio::test]
    async fn test_create_and_find_goal() {
        let pool = setup_test_db().await;
        let repo = SqliteGoalRepository::new(pool);

        let goal = Goal::new(
            "test-id".to_string(),
            "买车基金".to_string(),
            GoalType::Savings,
            Decimal::new(200000, 0),
            "CNY".to_string(),
        );

        repo.create(&goal).await.unwrap();

        let found = repo.find_by_id("test-id").await.unwrap();
        assert!(found.is_some());
        let found = found.unwrap();
        assert_eq!(found.name, "买车基金");
        assert_eq!(found.goal_type, GoalType::Savings);
        assert!(!found.is_completed);
    }

    #[tokio::test]
    async fn test_find_all() {
        let pool = setup_test_db().await;
        let repo = SqliteGoalRepository::new(pool);

        let goal1 = Goal::new(
            "id-1".to_string(),
            "Goal 1".to_string(),
            GoalType::Savings,
            Decimal::new(10000, 0),
            "CNY".to_string(),
        );
        let goal2 = Goal::new(
            "id-2".to_string(),
            "Goal 2".to_string(),
            GoalType::Investment,
            Decimal::new(50000, 0),
            "CNY".to_string(),
        );

        repo.create(&goal1).await.unwrap();
        repo.create(&goal2).await.unwrap();

        let all = repo.find_all().await.unwrap();
        assert_eq!(all.len(), 2);
    }

    #[tokio::test]
    async fn test_find_active() {
        let pool = setup_test_db().await;
        let repo = SqliteGoalRepository::new(pool);

        let goal1 = Goal::new(
            "id-1".to_string(),
            "Active Goal".to_string(),
            GoalType::Savings,
            Decimal::new(10000, 0),
            "CNY".to_string(),
        );
        let mut goal2 = Goal::new(
            "id-2".to_string(),
            "Completed Goal".to_string(),
            GoalType::Savings,
            Decimal::new(10000, 0),
            "CNY".to_string(),
        );
        goal2.mark_completed();

        repo.create(&goal1).await.unwrap();
        repo.create(&goal2).await.unwrap();

        let active = repo.find_active().await.unwrap();
        assert_eq!(active.len(), 1);
        assert_eq!(active[0].name, "Active Goal");
    }

    #[tokio::test]
    async fn test_update_goal() {
        let pool = setup_test_db().await;
        let repo = SqliteGoalRepository::new(pool);

        let mut goal = Goal::new(
            "test-id".to_string(),
            "买车基金".to_string(),
            GoalType::Savings,
            Decimal::new(200000, 0),
            "CNY".to_string(),
        );

        repo.create(&goal).await.unwrap();

        goal.name = "买房基金".to_string();
        goal.add_progress(Decimal::new(50000, 0));
        repo.update(&goal).await.unwrap();

        let found = repo.find_by_id("test-id").await.unwrap().unwrap();
        assert_eq!(found.name, "买房基金");
        assert_eq!(found.current_amount, Decimal::new(50000, 0));
    }

    #[tokio::test]
    async fn test_delete_goal() {
        let pool = setup_test_db().await;
        let repo = SqliteGoalRepository::new(pool);

        let goal = Goal::new(
            "test-id".to_string(),
            "买车基金".to_string(),
            GoalType::Savings,
            Decimal::new(200000, 0),
            "CNY".to_string(),
        );

        repo.create(&goal).await.unwrap();
        repo.delete("test-id").await.unwrap();

        let found = repo.find_by_id("test-id").await.unwrap();
        assert!(found.is_none());
    }

    #[tokio::test]
    async fn test_add_progress() {
        let pool = setup_test_db().await;
        let repo = SqliteGoalRepository::new(pool);

        let goal = Goal::new(
            "test-id".to_string(),
            "买车基金".to_string(),
            GoalType::Savings,
            Decimal::new(200000, 0),
            "CNY".to_string(),
        );

        repo.create(&goal).await.unwrap();
        repo.add_progress("test-id", Decimal::new(50000, 0))
            .await
            .unwrap();

        let found = repo.find_by_id("test-id").await.unwrap().unwrap();
        assert_eq!(found.current_amount, Decimal::new(50000, 0));
    }
}
