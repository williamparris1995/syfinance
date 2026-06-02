use crate::domain::aggregates::goal::{Goal, GoalType};
use crate::domain::repositories::GoalRepository;
use crate::infrastructure::repositories::{SqliteAccountRepository, SqliteGoalRepository};
use chrono::NaiveDate;
use rust_decimal::Decimal;
use sqlx::SqlitePool;
use std::str::FromStr;
use std::sync::Arc;
use tracing::info;

pub struct GoalService {
    goal_repo: Arc<SqliteGoalRepository>,
    // Reserved for future use (e.g., account validation on link)
    #[allow(dead_code)]
    account_repo: Arc<SqliteAccountRepository>,
    pool: SqlitePool,
}

#[derive(Debug)]
pub enum GoalServiceError {
    NotFound(String),
    ValidationError(String),
    RepositoryError(String),
}

impl std::fmt::Display for GoalServiceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NotFound(id) => write!(f, "goal not found: {id}"),
            Self::ValidationError(msg) => write!(f, "validation error: {msg}"),
            Self::RepositoryError(msg) => write!(f, "repository error: {msg}"),
        }
    }
}

impl std::error::Error for GoalServiceError {}

impl From<sqlx::Error> for GoalServiceError {
    fn from(err: sqlx::Error) -> Self {
        Self::RepositoryError(err.to_string())
    }
}

impl GoalService {
    pub fn new(
        goal_repo: Arc<SqliteGoalRepository>,
        account_repo: Arc<SqliteAccountRepository>,
        pool: SqlitePool,
    ) -> Self {
        Self {
            goal_repo,
            account_repo,
            pool,
        }
    }

    pub async fn list_goals(&self) -> Result<Vec<Goal>, GoalServiceError> {
        info!("Listing all goals");
        self.goal_repo.find_all().await.map_err(Into::into)
    }

    pub async fn get_goal(&self, id: &str) -> Result<Option<Goal>, GoalServiceError> {
        info!(goal_id = id, "Getting goal");
        self.goal_repo.find_by_id(id).await.map_err(Into::into)
    }

    #[allow(clippy::too_many_arguments)]
    pub async fn create_goal(
        &self,
        name: String,
        goal_type_str: String,
        target_amount_str: String,
        currency_code: String,
        deadline: Option<String>,
        linked_account_id: Option<String>,
        notes: Option<String>,
    ) -> Result<Goal, GoalServiceError> {
        info!(name = name, "Creating goal");

        let id = uuid::Uuid::new_v4().to_string();
        let target_amount = Decimal::from_str(&target_amount_str)
            .map_err(|_| GoalServiceError::ValidationError("Invalid target amount".to_string()))?;
        let goal_type = GoalType::from_str(&goal_type_str);

        let mut goal = Goal::new(id, name, goal_type, target_amount, currency_code);

        if let Some(deadline_str) = deadline {
            let deadline_date =
                NaiveDate::parse_from_str(&deadline_str, "%Y-%m-%d").map_err(|_| {
                    GoalServiceError::ValidationError("Invalid deadline date".to_string())
                })?;
            goal.set_deadline(deadline_date);
        }

        if let Some(account_id) = linked_account_id {
            goal.link_account(account_id);
        }

        goal.notes = notes;

        self.goal_repo.create(&goal).await?;

        info!(goal_id = goal.id, "Goal created successfully");
        Ok(goal)
    }

    #[allow(clippy::too_many_arguments)]
    pub async fn update_goal(
        &self,
        id: &str,
        name: Option<String>,
        goal_type_str: Option<String>,
        target_amount_str: Option<String>,
        currency_code: Option<String>,
        deadline: Option<String>,
        linked_account_id: Option<String>,
        notes: Option<String>,
    ) -> Result<Goal, GoalServiceError> {
        info!(goal_id = id, "Updating goal");

        let mut goal = self
            .goal_repo
            .find_by_id(id)
            .await?
            .ok_or_else(|| GoalServiceError::NotFound(id.to_string()))?;

        if let Some(n) = name {
            goal.name = n;
        }
        if let Some(gt) = goal_type_str {
            goal.goal_type = GoalType::from_str(&gt);
        }
        if let Some(ta) = target_amount_str {
            goal.target_amount = Decimal::from_str(&ta).map_err(|_| {
                GoalServiceError::ValidationError("Invalid target amount".to_string())
            })?;
        }
        if let Some(cc) = currency_code {
            goal.currency_code = cc;
        }
        if let Some(ds) = deadline {
            if ds.is_empty() {
                goal.deadline = None;
            } else {
                let d = NaiveDate::parse_from_str(&ds, "%Y-%m-%d").map_err(|_| {
                    GoalServiceError::ValidationError("Invalid deadline date".to_string())
                })?;
                goal.deadline = Some(d);
            }
        }
        if let Some(aid) = linked_account_id {
            if aid.is_empty() {
                goal.linked_account_id = None;
            } else {
                goal.linked_account_id = Some(aid);
            }
        }
        if let Some(n) = notes {
            goal.notes = if n.is_empty() { None } else { Some(n) };
        }

        self.goal_repo.update(&goal).await?;

        info!(goal_id = id, "Goal updated successfully");
        Ok(goal)
    }

    pub async fn update_goal_progress(
        &self,
        id: &str,
        amount_str: String,
    ) -> Result<Goal, GoalServiceError> {
        info!(goal_id = id, "Updating goal progress");

        let amount = Decimal::from_str(&amount_str)
            .map_err(|_| GoalServiceError::ValidationError("Invalid amount".to_string()))?;

        self.goal_repo.add_progress(id, amount).await?;

        let goal = self
            .goal_repo
            .find_by_id(id)
            .await?
            .ok_or_else(|| GoalServiceError::NotFound(id.to_string()))?;

        // Auto-complete if target reached
        if !goal.is_completed && goal.current_amount >= goal.target_amount {
            let mut goal = goal;
            goal.mark_completed();
            self.goal_repo.update(&goal).await?;
            info!(goal_id = id, "Goal auto-completed");
            return Ok(goal);
        }

        info!(goal_id = id, "Goal progress updated");
        Ok(goal)
    }

    pub async fn complete_goal(&self, id: &str) -> Result<Goal, GoalServiceError> {
        info!(goal_id = id, "Completing goal");

        let mut goal = self
            .goal_repo
            .find_by_id(id)
            .await?
            .ok_or_else(|| GoalServiceError::NotFound(id.to_string()))?;

        goal.mark_completed();

        self.goal_repo.update(&goal).await?;

        info!(goal_id = id, "Goal completed");
        Ok(goal)
    }

    pub async fn delete_goal(&self, id: &str) -> Result<(), GoalServiceError> {
        info!(goal_id = id, "Deleting goal");
        self.goal_repo.delete(id).await?;
        info!(goal_id = id, "Goal deleted");
        Ok(())
    }

    pub async fn sync_goal_progress(&self, goal_id: &str) -> Result<Goal, GoalServiceError> {
        info!(
            goal_id = goal_id,
            "Syncing goal progress from linked account"
        );

        // 1. Get goal with linked_account_id
        let goal = self
            .goal_repo
            .find_by_id(goal_id)
            .await?
            .ok_or_else(|| GoalServiceError::NotFound(goal_id.to_string()))?;

        let account_id = goal.linked_account_id.ok_or_else(|| {
            GoalServiceError::ValidationError("Goal has no linked account".to_string())
        })?;

        // 2. Get account initial balance
        let initial_balance: (String,) =
            sqlx::query_as("SELECT CAST(initial_balance AS TEXT) FROM accounts WHERE id = ?")
                .bind(&account_id)
                .fetch_one(&self.pool)
                .await
                .map_err(|e| {
                    GoalServiceError::RepositoryError(format!("Linked account not found: {}", e))
                })?;

        let initial = initial_balance
            .0
            .parse::<Decimal>()
            .unwrap_or(Decimal::ZERO);

        // 3. Compute net change from transactions
        let net_change: (String,) = sqlx::query_as(
            "SELECT CAST(COALESCE(SUM(CASE WHEN e.debit_amount IS NOT NULL THEN e.debit_amount ELSE 0 END \
             - CASE WHEN e.credit_amount IS NOT NULL THEN e.credit_amount ELSE 0 END), 0) AS TEXT) \
             FROM transaction_entries e \
             JOIN transactions t ON e.transaction_id = t.id \
             WHERE e.deleted_at IS NULL AND t.deleted_at IS NULL AND e.account_id = ?",
        )
        .bind(&account_id)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| GoalServiceError::RepositoryError(format!("Failed to compute balance: {}", e)))?;

        let change = net_change.0.parse::<Decimal>().unwrap_or(Decimal::ZERO);
        let current_balance = initial + change;

        // 4. Update goal progress
        self.goal_repo
            .add_progress(goal_id, current_balance)
            .await?;

        // 5. Return updated goal
        let updated = self
            .goal_repo
            .find_by_id(goal_id)
            .await?
            .ok_or_else(|| GoalServiceError::NotFound(goal_id.to_string()))?;

        info!(
            goal_id = goal_id,
            account_id = account_id,
            balance = %current_balance,
            "Goal progress synced from account balance"
        );

        Ok(updated)
    }
}
