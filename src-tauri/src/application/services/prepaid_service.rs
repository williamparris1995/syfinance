use crate::application::dtos::{PrepaidDetailDto, TopUpRecordDto, TopUpRequest};
use crate::domain::aggregates::{AccountType, Ownership, Reminder, ReminderType};
use crate::domain::repositories::{AccountRepository, PrepaidRepository, TransactionRepository};
use crate::domain::value_objects::{Money, SyncMetadata, TopUpRecord, TransactionEntry};
use rust_decimal::Decimal;
use std::sync::Arc;
use uuid::Uuid;

#[derive(Debug)]
pub enum PrepaidServiceError {
    AccountNotFound(Uuid),
    NotPrepaidAccount(Uuid),
    SourceAccountNotFound(Uuid),
    // TODO: will be used when balance validation is added to top_up
    #[allow(dead_code)]
    InsufficientBalance,
    RepositoryError(String),
    TransactionError(String),
}

impl std::fmt::Display for PrepaidServiceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::AccountNotFound(id) => write!(f, "account not found: {id}"),
            Self::NotPrepaidAccount(id) => write!(f, "account is not a prepaid account: {id}"),
            Self::SourceAccountNotFound(id) => write!(f, "source account not found: {id}"),
            Self::InsufficientBalance => write!(f, "insufficient balance"),
            Self::RepositoryError(msg) => write!(f, "repository error: {msg}"),
            Self::TransactionError(msg) => write!(f, "transaction error: {msg}"),
        }
    }
}

impl std::error::Error for PrepaidServiceError {}

impl From<sqlx::Error> for PrepaidServiceError {
    fn from(err: sqlx::Error) -> Self {
        Self::RepositoryError(err.to_string())
    }
}

pub struct PrepaidService<PR, AR, TR>
where
    PR: PrepaidRepository,
    AR: AccountRepository,
    TR: TransactionRepository,
{
    prepaid_repo: Arc<PR>,
    account_repo: Arc<AR>,
    transaction_repo: Arc<TR>,
}

impl<PR, AR, TR> PrepaidService<PR, AR, TR>
where
    PR: PrepaidRepository,
    AR: AccountRepository,
    TR: TransactionRepository,
{
    pub fn new(prepaid_repo: Arc<PR>, account_repo: Arc<AR>, transaction_repo: Arc<TR>) -> Self {
        Self {
            prepaid_repo,
            account_repo,
            transaction_repo,
        }
    }

    pub async fn top_up(&self, request: TopUpRequest) -> Result<Uuid, PrepaidServiceError> {
        let prepaid_account = self
            .account_repo
            .find_by_id(request.account_id)
            .await?
            .ok_or(PrepaidServiceError::AccountNotFound(request.account_id))?;

        if prepaid_account.account_type != AccountType::Prepaid {
            return Err(PrepaidServiceError::NotPrepaidAccount(request.account_id));
        }

        let source_account = self
            .account_repo
            .find_by_id(request.source_account_id)
            .await?
            .ok_or(PrepaidServiceError::SourceAccountNotFound(
                request.source_account_id,
            ))?;

        let bonus_amount = request.bonus_amount.unwrap_or(Decimal::ZERO);
        let total_credited = request.paid_amount + bonus_amount;

        let transaction_id = Uuid::new_v4();
        let device_id = Uuid::new_v4();

        let prepaid_chart = prepaid_account.chart_code.as_deref().unwrap_or("1021");
        let source_chart = source_account.chart_code.as_deref().unwrap_or("1002");

        let total_money = Money::new(total_credited, &prepaid_account.currency_code)
            .map_err(|e| PrepaidServiceError::TransactionError(e.to_string()))?;
        let paid_money = Money::new(request.paid_amount, &prepaid_account.currency_code)
            .map_err(|e| PrepaidServiceError::TransactionError(e.to_string()))?;

        // Build entries: debit prepaid (increase asset), credit source (decrease asset)
        let mut entries = vec![
            TransactionEntry::new(
                prepaid_account.id,
                prepaid_chart,
                Some(total_money),
                None,
                format!("Top up: {}", prepaid_account.name),
            )
            .map_err(|e| PrepaidServiceError::TransactionError(e.to_string()))?,
            TransactionEntry::new(
                source_account.id,
                source_chart,
                None,
                Some(paid_money),
                format!("Top up from: {}", source_account.name),
            )
            .map_err(|e| PrepaidServiceError::TransactionError(e.to_string()))?,
        ];

        // If there is a bonus, add a third entry: credit income account for bonus
        if bonus_amount > Decimal::ZERO {
            let bonus_income_account = self.find_bonus_income_account().await?;
            let bonus_money = Money::new(bonus_amount, &prepaid_account.currency_code)
                .map_err(|e| PrepaidServiceError::TransactionError(e.to_string()))?;
            let bonus_chart = bonus_income_account.chart_code.as_deref().unwrap_or("4901");
            let bonus_entry = TransactionEntry::new(
                bonus_income_account.id,
                bonus_chart,
                None,
                Some(bonus_money),
                format!("Top up bonus: {}", prepaid_account.name),
            )
            .map_err(|e| PrepaidServiceError::TransactionError(e.to_string()))?;
            entries.push(bonus_entry);
        }

        let transaction = crate::domain::aggregates::Transaction::new(
            transaction_id,
            request.top_up_date,
            format!("Top up {} - {}", request.paid_amount, prepaid_account.name),
            entries,
            SyncMetadata::new(device_id),
        )
        .map_err(|e| PrepaidServiceError::TransactionError(e.to_string()))?;

        self.transaction_repo.create(&transaction).await?;

        let record_id = Uuid::new_v4();
        let record = TopUpRecord::new(
            record_id,
            request.account_id,
            transaction_id,
            request.paid_amount,
            bonus_amount,
            request.top_up_date,
            request.expiry_date,
            request.source_account_id,
            request.description,
        );

        self.prepaid_repo.create_top_up_record(&record).await?;

        Ok(record_id)
    }

    pub async fn get_prepaid_detail(
        &self,
        account_id: Uuid,
    ) -> Result<PrepaidDetailDto, PrepaidServiceError> {
        let account = self
            .account_repo
            .find_by_id(account_id)
            .await?
            .ok_or(PrepaidServiceError::AccountNotFound(account_id))?;

        if account.account_type != AccountType::Prepaid {
            return Err(PrepaidServiceError::NotPrepaidAccount(account_id));
        }

        let balances = self
            .account_repo
            .compute_balances_for_all_accounts()
            .await?;
        let net_change = balances.get(&account_id).copied().unwrap_or(Decimal::ZERO);
        let balance = account.initial_balance.amount + net_change;

        let records = self
            .prepaid_repo
            .find_top_up_records_by_account(account_id)
            .await?;

        let total_paid: Decimal = records.iter().map(|r| r.paid_amount).sum();
        let total_bonus: Decimal = records.iter().map(|r| r.bonus_amount).sum();
        let total_credited: Decimal = records.iter().map(|r| r.total_credited).sum();

        let record_dtos: Vec<TopUpRecordDto> = records
            .iter()
            .map(|r| TopUpRecordDto {
                id: r.id,
                account_id: r.account_id,
                transaction_id: r.transaction_id,
                paid_amount: r.paid_amount.to_string(),
                bonus_amount: r.bonus_amount.to_string(),
                total_credited: r.total_credited.to_string(),
                top_up_date: r.top_up_date,
                expiry_date: r.expiry_date,
                source_account_id: r.source_account_id,
                description: r.description.clone(),
                created_at: r.created_at.to_rfc3339(),
                updated_at: r.updated_at.to_rfc3339(),
            })
            .collect();
        let total_consumption = (account.initial_balance.amount + total_credited) - balance;

        Ok(PrepaidDetailDto {
            account_id: account.id,
            account_name: account.name,
            currency_code: account.currency_code,
            balance: balance.to_string(),
            low_balance_threshold: account.low_balance_threshold.map(|t| t.to_string()),
            total_paid: total_paid.to_string(),
            total_bonus: total_bonus.to_string(),
            total_credited: total_credited.to_string(),
            total_consumption: total_consumption.to_string(),
            records: record_dtos,
        })
    }

    pub async fn get_top_up_records(
        &self,
        account_id: Uuid,
    ) -> Result<Vec<TopUpRecordDto>, PrepaidServiceError> {
        let records = self
            .prepaid_repo
            .find_top_up_records_by_account(account_id)
            .await?;

        Ok(records
            .iter()
            .map(|r| TopUpRecordDto {
                id: r.id,
                account_id: r.account_id,
                transaction_id: r.transaction_id,
                paid_amount: r.paid_amount.to_string(),
                bonus_amount: r.bonus_amount.to_string(),
                total_credited: r.total_credited.to_string(),
                top_up_date: r.top_up_date,
                expiry_date: r.expiry_date,
                source_account_id: r.source_account_id,
                description: r.description.clone(),
                created_at: r.created_at.to_rfc3339(),
                updated_at: r.updated_at.to_rfc3339(),
            })
            .collect())
    }

    // TODO: will be used when low-balance protection is added to top_up
    #[allow(dead_code)]
    pub async fn check_balance_sufficient(
        &self,
        account_id: Uuid,
        amount: Decimal,
    ) -> Result<bool, PrepaidServiceError> {
        let account = self
            .account_repo
            .find_by_id(account_id)
            .await?
            .ok_or(PrepaidServiceError::AccountNotFound(account_id))?;

        if account.account_type != AccountType::Prepaid {
            return Err(PrepaidServiceError::NotPrepaidAccount(account_id));
        }

        let balances = self
            .account_repo
            .compute_balances_for_all_accounts()
            .await?;
        let net_change = balances.get(&account_id).copied().unwrap_or(Decimal::ZERO);
        let balance = account.initial_balance.amount + net_change;

        Ok(balance >= amount)
    }

    /// Checks if a prepaid account's balance has fallen below its low balance threshold.
    /// Returns a Reminder if the balance is below threshold, or None otherwise.
    ///
    /// Note: Low-balance checking is handled by the PrepaidAlertScheduler which
    /// runs periodically. This method remains available for ad-hoc checks.
    // Kept for ad-hoc use; periodic checks are handled by PrepaidAlertScheduler
    #[allow(dead_code)]
    pub async fn check_low_balance_alert(
        &self,
        account_id: Uuid,
    ) -> Result<Option<Reminder>, PrepaidServiceError> {
        let account = self
            .account_repo
            .find_by_id(account_id)
            .await?
            .ok_or(PrepaidServiceError::AccountNotFound(account_id))?;

        if account.account_type != AccountType::Prepaid {
            return Err(PrepaidServiceError::NotPrepaidAccount(account_id));
        }

        let threshold = match account.low_balance_threshold {
            Some(t) => t,
            None => return Ok(None),
        };

        let balances = self
            .account_repo
            .compute_balances_for_all_accounts()
            .await?;
        let net_change = balances.get(&account_id).copied().unwrap_or(Decimal::ZERO);
        let balance = account.initial_balance.amount + net_change;

        if balance < threshold {
            let reminder = Reminder::create(
                Uuid::new_v4(),
                ReminderType::PrepaidLowBalance,
                Some(account_id),
                format!("Low balance alert: {}", account.name),
                format!(
                    "Account {} balance ({}) is below threshold ({})",
                    account.name, balance, threshold
                ),
                chrono::Utc::now() + chrono::Duration::hours(1),
                None,
                crate::domain::aggregates::reminder::Priority::High,
                SyncMetadata::new(Uuid::new_v4()),
            )
            .map_err(|e| PrepaidServiceError::TransactionError(e.to_string()))?;
            return Ok(Some(reminder));
        }

        Ok(None)
    }

    async fn find_bonus_income_account(
        &self,
    ) -> Result<crate::domain::aggregates::Account, PrepaidServiceError> {
        // Find external income account with chart_code "490101" (L3), fallback to "4901" (L2)
        let external_accounts = self
            .account_repo
            .find_by_ownership(&Ownership::External)
            .await?;

        let bonus_account = external_accounts
            .iter()
            .find(|a| a.chart_code.as_deref() == Some("490101"))
            .or_else(|| {
                external_accounts
                    .iter()
                    .find(|a| a.chart_code.as_deref() == Some("4901"))
            });

        match bonus_account {
            Some(account) => Ok(account.clone()),
            None => Err(PrepaidServiceError::RepositoryError(
                "bonus income account with chart_code 490101 or 4901 not found".to_string(),
            )),
        }
    }
}
