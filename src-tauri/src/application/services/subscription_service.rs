use crate::application::dtos::{
    CreateSubscriptionDto, SubscriptionDto, SubscriptionFilters, TransactionDto,
    TransactionEntryDto, UpdateSubscriptionDto,
};
use crate::domain::aggregates::subscription::{
    Subscription, SubscriptionCycle, SubscriptionDirection,
};
use crate::domain::aggregates::Transaction;
use crate::domain::repositories::{
    AccountRepository, SubscriptionRepository, TransactionRepository,
};
use crate::domain::value_objects::{Money, SyncMetadata, TransactionEntry};
use crate::infrastructure::repositories::{
    SqliteAccountRepository, SqliteSubscriptionRepository, SqliteTransactionRepository,
};
use chrono::NaiveDate;
use rust_decimal::Decimal;
use std::sync::Arc;
use uuid::Uuid;

pub struct SubscriptionService {
    subscription_repo: Arc<SqliteSubscriptionRepository>,
    account_repo: Arc<SqliteAccountRepository>,
    transaction_repo: Arc<SqliteTransactionRepository>,
}

#[derive(Debug)]
pub enum SubscriptionServiceError {
    NotFound(Uuid),
    AccountNotFound(Uuid),
    ValidationError(String),
    RepositoryError(String),
}

impl std::fmt::Display for SubscriptionServiceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NotFound(id) => write!(f, "subscription not found: {id}"),
            Self::AccountNotFound(id) => write!(f, "account not found: {id}"),
            Self::ValidationError(msg) => write!(f, "validation error: {msg}"),
            Self::RepositoryError(msg) => write!(f, "repository error: {msg}"),
        }
    }
}

impl std::error::Error for SubscriptionServiceError {}
impl From<sqlx::Error> for SubscriptionServiceError {
    fn from(err: sqlx::Error) -> Self {
        Self::RepositoryError(err.to_string())
    }
}

impl SubscriptionService {
    pub fn new(
        subscription_repo: Arc<SqliteSubscriptionRepository>,
        account_repo: Arc<SqliteAccountRepository>,
        transaction_repo: Arc<SqliteTransactionRepository>,
    ) -> Self {
        Self {
            subscription_repo,
            account_repo,
            transaction_repo,
        }
    }

    pub async fn create(
        &self,
        dto: CreateSubscriptionDto,
    ) -> Result<Uuid, SubscriptionServiceError> {
        let _account = self
            .account_repo
            .find_by_id(dto.source_account_id)
            .await?
            .ok_or(SubscriptionServiceError::AccountNotFound(
                dto.source_account_id,
            ))?;

        let cycle = parse_cycle(&dto.cycle, dto.cycle_days)?;
        let direction = parse_direction(&dto.direction)?;

        let subscription = Subscription {
            id: Uuid::new_v4(),
            name: dto.name,
            amount: dto.amount,
            direction,
            cycle,
            billing_day: dto.billing_day,
            next_billing_date: dto.next_billing_date,
            start_date: dto.start_date,
            end_date: dto.end_date,
            auto_record: dto.auto_record.unwrap_or(true),
            paused: false,
            source_account_id: dto.source_account_id,
            category: dto.category,
            description: dto.description,
            last_transaction_id: None,
        };

        self.subscription_repo.create(&subscription).await?;
        Ok(subscription.id)
    }

    pub async fn list(
        &self,
        filters: SubscriptionFilters,
    ) -> Result<Vec<SubscriptionDto>, SubscriptionServiceError> {
        let all = self.subscription_repo.find_all().await?;
        let mut dtos = Vec::new();
        for s in all {
            if let Some(ref dir) = filters.direction {
                if direction_to_str(&s.direction) != *dir {
                    continue;
                }
            }
            if let Some(ref cyc) = filters.cycle {
                if cycle_to_str(&s.cycle) != *cyc {
                    continue;
                }
            }
            if let Some(paused) = filters.paused {
                if s.paused != paused {
                    continue;
                }
            }

            let account = self.account_repo.find_by_id(s.source_account_id).await?;
            dtos.push(SubscriptionDto {
                id: s.id,
                name: s.name.clone(),
                amount: s.amount,
                direction: direction_to_str(&s.direction),
                cycle: cycle_to_str(&s.cycle),
                cycle_days: match &s.cycle {
                    SubscriptionCycle::Custom { days } => Some(*days),
                    _ => None,
                },
                billing_day: s.billing_day,
                next_billing_date: s.next_billing_date,
                start_date: s.start_date,
                end_date: s.end_date,
                auto_record: s.auto_record,
                paused: s.paused,
                source_account_id: s.source_account_id,
                source_account_name: account.as_ref().map(|a| a.name.clone()).unwrap_or_default(),
                currency_code: account
                    .as_ref()
                    .map(|a| a.currency_code.clone())
                    .unwrap_or_default(),
                category: s.category.clone(),
                description: s.description.clone(),
                last_transaction_id: s.last_transaction_id,
            });
        }
        Ok(dtos)
    }

    pub async fn get_by_id(&self, id: Uuid) -> Result<SubscriptionDto, SubscriptionServiceError> {
        let s = self
            .subscription_repo
            .find_by_id(id)
            .await?
            .ok_or(SubscriptionServiceError::NotFound(id))?;
        let account = self.account_repo.find_by_id(s.source_account_id).await?;
        Ok(SubscriptionDto {
            id: s.id,
            name: s.name.clone(),
            amount: s.amount,
            direction: direction_to_str(&s.direction),
            cycle: cycle_to_str(&s.cycle),
            cycle_days: match &s.cycle {
                SubscriptionCycle::Custom { days } => Some(*days),
                _ => None,
            },
            billing_day: s.billing_day,
            next_billing_date: s.next_billing_date,
            start_date: s.start_date,
            end_date: s.end_date,
            auto_record: s.auto_record,
            paused: s.paused,
            source_account_id: s.source_account_id,
            source_account_name: account.as_ref().map(|a| a.name.clone()).unwrap_or_default(),
            currency_code: account
                .as_ref()
                .map(|a| a.currency_code.clone())
                .unwrap_or_default(),
            category: s.category.clone(),
            description: s.description.clone(),
            last_transaction_id: s.last_transaction_id,
        })
    }

    pub async fn update(&self, dto: UpdateSubscriptionDto) -> Result<(), SubscriptionServiceError> {
        let mut s = self
            .subscription_repo
            .find_by_id(dto.id)
            .await?
            .ok_or(SubscriptionServiceError::NotFound(dto.id))?;

        if let Some(name) = dto.name {
            s.name = name;
        }
        if let Some(amount) = dto.amount {
            s.amount = amount;
        }
        if let Some(ref dir) = dto.direction {
            s.direction = parse_direction(dir)?;
        }
        if let Some(ref cyc) = dto.cycle {
            s.cycle = parse_cycle(cyc, dto.cycle_days)?;
        }
        if dto.billing_day.is_some() {
            s.billing_day = dto.billing_day;
        }
        if let Some(nbd) = dto.next_billing_date {
            s.next_billing_date = nbd;
        }
        if dto.end_date.is_some() {
            s.end_date = dto.end_date;
        }
        if let Some(ar) = dto.auto_record {
            s.auto_record = ar;
        }
        if let Some(aid) = dto.source_account_id {
            self.account_repo
                .find_by_id(aid)
                .await?
                .ok_or(SubscriptionServiceError::AccountNotFound(aid))?;
            s.source_account_id = aid;
        }
        if dto.category.is_some() {
            s.category = dto.category;
        }
        if dto.description.is_some() {
            s.description = dto.description;
        }

        self.subscription_repo.update(&s).await?;
        Ok(())
    }

    pub async fn delete(&self, id: Uuid) -> Result<(), SubscriptionServiceError> {
        self.subscription_repo.soft_delete(id).await?;
        Ok(())
    }

    pub async fn pause(&self, id: Uuid) -> Result<(), SubscriptionServiceError> {
        self.subscription_repo.set_paused(id, true).await?;
        Ok(())
    }

    pub async fn resume(&self, id: Uuid) -> Result<(), SubscriptionServiceError> {
        self.subscription_repo.set_paused(id, false).await?;
        Ok(())
    }

    pub async fn process_due_subscriptions(
        &self,
        today: NaiveDate,
    ) -> Result<usize, SubscriptionServiceError> {
        let due = self.subscription_repo.find_due(today).await?;
        let mut processed = 0;
        for s in &due {
            match self.record_subscription(s).await {
                Ok(txn_id) => {
                    let mut updated = s.clone();
                    updated.last_transaction_id = Some(txn_id);
                    updated.advance_to_next();
                    if let Err(e) = self
                        .subscription_repo
                        .update_next_billing_date(
                            updated.id,
                            updated.next_billing_date,
                            updated.last_transaction_id,
                        )
                        .await
                    {
                        tracing::error!("Failed to update next billing for {}: {}", s.id, e);
                        continue;
                    }
                    processed += 1;
                }
                Err(e) => {
                    tracing::error!("Failed to process subscription {}: {}", s.id, e);
                    continue;
                }
            }
        }
        Ok(processed)
    }

    async fn record_subscription(
        &self,
        s: &Subscription,
    ) -> Result<Uuid, SubscriptionServiceError> {
        let account = self
            .account_repo
            .find_by_id(s.source_account_id)
            .await?
            .ok_or(SubscriptionServiceError::AccountNotFound(
                s.source_account_id,
            ))?;

        let txn_id = Uuid::new_v4();
        let desc = format!("{} - {}", s.name, s.next_billing_date);

        let source_chart = account.chart_code.as_deref().unwrap_or("1002");

        let entries = match s.direction {
            SubscriptionDirection::Expense => {
                let amount_money = Money::new(s.amount, &account.currency_code)
                    .map_err(|e| SubscriptionServiceError::ValidationError(e.to_string()))?;
                vec![
                    TransactionEntry::new(
                        s.source_account_id,
                        "5401",
                        Some(amount_money.clone()),
                        None,
                        &s.name,
                    )
                    .map_err(|e| SubscriptionServiceError::ValidationError(e.to_string()))?,
                    TransactionEntry::new(
                        s.source_account_id,
                        source_chart,
                        None,
                        Some(amount_money),
                        &desc,
                    )
                    .map_err(|e| SubscriptionServiceError::ValidationError(e.to_string()))?,
                ]
            }
            SubscriptionDirection::Income => {
                let amount_money = Money::new(s.amount, &account.currency_code)
                    .map_err(|e| SubscriptionServiceError::ValidationError(e.to_string()))?;
                vec![
                    TransactionEntry::new(
                        s.source_account_id,
                        source_chart,
                        Some(amount_money.clone()),
                        None,
                        &desc,
                    )
                    .map_err(|e| SubscriptionServiceError::ValidationError(e.to_string()))?,
                    TransactionEntry::new(
                        s.source_account_id,
                        "4201",
                        None,
                        Some(amount_money),
                        &s.name,
                    )
                    .map_err(|e| SubscriptionServiceError::ValidationError(e.to_string()))?,
                ]
            }
        };

        let transaction = Transaction::new(
            txn_id,
            s.next_billing_date,
            desc,
            entries,
            SyncMetadata::new(Uuid::new_v4()),
        )
        .map_err(|e| SubscriptionServiceError::ValidationError(e.to_string()))?;
        self.transaction_repo.create(&transaction).await?;
        Ok(txn_id)
    }

    pub async fn list_transactions(
        &self,
        subscription_id: Uuid,
    ) -> Result<Vec<TransactionDto>, SubscriptionServiceError> {
        let s = self
            .subscription_repo
            .find_by_id(subscription_id)
            .await?
            .ok_or(SubscriptionServiceError::NotFound(subscription_id))?;
        let all_txns = self.transaction_repo.find_all().await?;
        let prefix = format!("{} - ", s.name);
        let matching: Vec<_> = all_txns
            .into_iter()
            .filter(|t| t.description.starts_with(&prefix))
            .collect();

        let mut dtos = Vec::new();
        for txn in matching {
            dtos.push(transaction_to_dto(txn));
        }
        Ok(dtos)
    }
}

fn transaction_to_dto(transaction: Transaction) -> TransactionDto {
    TransactionDto {
        id: transaction.id,
        transaction_date: transaction.transaction_date,
        description: transaction.description,
        entries: transaction
            .entries
            .iter()
            .map(|e| TransactionEntryDto {
                account_id: e.account_id,
                chart_of_account_code: e.chart_of_account_code.clone(),
                debit_amount: e.debit_amount.as_ref().map(|m| m.amount.to_string()),
                credit_amount: e.credit_amount.as_ref().map(|m| m.amount.to_string()),
                currency_code: e.currency_code().unwrap_or("UNKNOWN").to_string(),
                memo: if e.note.is_empty() {
                    None
                } else {
                    Some(e.note.clone())
                },
            })
            .collect(),
        created_at: transaction.sync_metadata.updated_at.to_rfc3339(),
        updated_at: transaction.sync_metadata.updated_at.to_rfc3339(),
    }
}

fn parse_cycle(s: &str, days: Option<u32>) -> Result<SubscriptionCycle, SubscriptionServiceError> {
    match s {
        "weekly" => Ok(SubscriptionCycle::Weekly),
        "monthly" => Ok(SubscriptionCycle::Monthly),
        "yearly" => Ok(SubscriptionCycle::Yearly),
        "custom" => Ok(SubscriptionCycle::Custom {
            days: days.unwrap_or(30),
        }),
        _ => Err(SubscriptionServiceError::ValidationError(format!(
            "invalid cycle: {s}"
        ))),
    }
}

fn parse_direction(s: &str) -> Result<SubscriptionDirection, SubscriptionServiceError> {
    match s {
        "expense" => Ok(SubscriptionDirection::Expense),
        "income" => Ok(SubscriptionDirection::Income),
        _ => Err(SubscriptionServiceError::ValidationError(format!(
            "invalid direction: {s}"
        ))),
    }
}

fn direction_to_str(d: &SubscriptionDirection) -> String {
    match d {
        SubscriptionDirection::Expense => "expense".into(),
        SubscriptionDirection::Income => "income".into(),
    }
}

fn cycle_to_str(c: &SubscriptionCycle) -> String {
    match c {
        SubscriptionCycle::Weekly => "weekly".into(),
        SubscriptionCycle::Monthly => "monthly".into(),
        SubscriptionCycle::Yearly => "yearly".into(),
        SubscriptionCycle::Custom { .. } => "custom".into(),
    }
}
