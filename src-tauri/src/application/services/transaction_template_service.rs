use crate::application::dtos::{
    CreateTransactionTemplateDto, TransactionTemplateDto, UpdateTransactionTemplateDto,
};
use crate::domain::aggregates::transaction_template::{
    TemplateCycle, TemplateDirection, TransactionTemplate,
};
use crate::domain::aggregates::Transaction;
use crate::domain::repositories::{
    AccountRepository, TransactionTemplateRepository, TransactionRepository,
};
use crate::domain::value_objects::{Money, SyncMetadata, TransactionEntry};
use crate::infrastructure::repositories::{
    SqliteAccountRepository, SqliteTransactionTemplateRepository, SqliteTransactionRepository,
};
use chrono::NaiveDate;
use std::sync::Arc;
use uuid::Uuid;

pub struct TransactionTemplateService {
    template_repo: Arc<SqliteTransactionTemplateRepository>,
    account_repo: Arc<SqliteAccountRepository>,
    transaction_repo: Arc<SqliteTransactionRepository>,
}

#[derive(Debug)]
pub enum TransactionTemplateServiceError {
    NotFound(Uuid),
    AccountNotFound(Uuid),
    DestinationAccountNotFound(Uuid),
    ValidationError(String),
    RepositoryError(String),
}

impl std::fmt::Display for TransactionTemplateServiceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NotFound(id) => write!(f, "transaction template not found: {id}"),
            Self::AccountNotFound(id) => write!(f, "account not found: {id}"),
            Self::DestinationAccountNotFound(id) => {
                write!(f, "destination account not found: {id}")
            }
            Self::ValidationError(msg) => write!(f, "validation error: {msg}"),
            Self::RepositoryError(msg) => write!(f, "repository error: {msg}"),
        }
    }
}

impl std::error::Error for TransactionTemplateServiceError {}
impl From<sqlx::Error> for TransactionTemplateServiceError {
    fn from(err: sqlx::Error) -> Self {
        Self::RepositoryError(err.to_string())
    }
}

impl TransactionTemplateService {
    pub fn new(
        template_repo: Arc<SqliteTransactionTemplateRepository>,
        account_repo: Arc<SqliteAccountRepository>,
        transaction_repo: Arc<SqliteTransactionRepository>,
    ) -> Self {
        Self {
            template_repo,
            account_repo,
            transaction_repo,
        }
    }

    pub async fn create(
        &self,
        dto: CreateTransactionTemplateDto,
    ) -> Result<Uuid, TransactionTemplateServiceError> {
        let _account = self
            .account_repo
            .find_by_id(dto.source_account_id)
            .await?
            .ok_or(TransactionTemplateServiceError::AccountNotFound(
                dto.source_account_id,
            ))?;

        if let Some(dest_id) = dto.destination_account_id {
            self.account_repo
                .find_by_id(dest_id)
                .await?
                .ok_or(TransactionTemplateServiceError::DestinationAccountNotFound(dest_id))?;
        }

        let cycle = parse_cycle(&dto.cycle, dto.cycle_days)?;
        let direction = parse_direction(&dto.direction)?;

        let template = TransactionTemplate {
            id: Uuid::new_v4(),
            name: dto.name,
            description: dto.description,
            amount: dto.amount,
            direction,
            source_account_id: dto.source_account_id,
            destination_account_id: dto.destination_account_id,
            cycle,
            billing_day: dto.billing_day,
            next_date: dto.next_date,
            start_date: dto.start_date,
            end_date: dto.end_date,
            auto_record: dto.auto_record.unwrap_or(true),
            paused: false,
            last_transaction_id: None,
        };

        self.template_repo.create(&template).await?;
        Ok(template.id)
    }

    pub async fn list(
        &self,
    ) -> Result<Vec<TransactionTemplateDto>, TransactionTemplateServiceError> {
        let all = self.template_repo.find_all().await?;
        let mut dtos = Vec::new();
        for t in all {
            let account = self.account_repo.find_by_id(t.source_account_id).await?;
            let dest_account = match t.destination_account_id {
                Some(dest_id) => self.account_repo.find_by_id(dest_id).await?,
                None => None,
            };
            dtos.push(TransactionTemplateDto {
                id: t.id,
                name: t.name.clone(),
                description: t.description.clone(),
                amount: t.amount,
                direction: direction_to_str(&t.direction),
                source_account_id: t.source_account_id,
                source_account_name: account
                    .as_ref()
                    .map(|a| a.name.clone())
                    .unwrap_or_default(),
                destination_account_id: t.destination_account_id,
                destination_account_name: dest_account
                    .as_ref()
                    .map(|a| a.name.clone()),
                currency_code: account
                    .as_ref()
                    .map(|a| a.currency_code.clone())
                    .unwrap_or_default(),
                cycle: cycle_to_str(&t.cycle),
                cycle_days: match &t.cycle {
                    TemplateCycle::Custom { days } => Some(*days),
                    _ => None,
                },
                billing_day: t.billing_day,
                next_date: t.next_date,
                start_date: t.start_date,
                end_date: t.end_date,
                auto_record: t.auto_record,
                paused: t.paused,
                last_transaction_id: t.last_transaction_id,
            });
        }
        Ok(dtos)
    }

    pub async fn get_by_id(
        &self,
        id: Uuid,
    ) -> Result<TransactionTemplateDto, TransactionTemplateServiceError> {
        let t = self
            .template_repo
            .find_by_id(id)
            .await?
            .ok_or(TransactionTemplateServiceError::NotFound(id))?;
        let account = self.account_repo.find_by_id(t.source_account_id).await?;
        let dest_account = match t.destination_account_id {
            Some(dest_id) => self.account_repo.find_by_id(dest_id).await?,
            None => None,
        };
        Ok(TransactionTemplateDto {
            id: t.id,
            name: t.name.clone(),
            description: t.description.clone(),
            amount: t.amount,
            direction: direction_to_str(&t.direction),
            source_account_id: t.source_account_id,
            source_account_name: account
                .as_ref()
                .map(|a| a.name.clone())
                .unwrap_or_default(),
            destination_account_id: t.destination_account_id,
            destination_account_name: dest_account.as_ref().map(|a| a.name.clone()),
            currency_code: account
                .as_ref()
                .map(|a| a.currency_code.clone())
                .unwrap_or_default(),
            cycle: cycle_to_str(&t.cycle),
            cycle_days: match &t.cycle {
                TemplateCycle::Custom { days } => Some(*days),
                _ => None,
            },
            billing_day: t.billing_day,
            next_date: t.next_date,
            start_date: t.start_date,
            end_date: t.end_date,
            auto_record: t.auto_record,
            paused: t.paused,
            last_transaction_id: t.last_transaction_id,
        })
    }

    pub async fn update(
        &self,
        dto: UpdateTransactionTemplateDto,
    ) -> Result<(), TransactionTemplateServiceError> {
        let mut t = self
            .template_repo
            .find_by_id(dto.id)
            .await?
            .ok_or(TransactionTemplateServiceError::NotFound(dto.id))?;

        if let Some(name) = dto.name {
            t.name = name;
        }
        if let Some(desc) = dto.description {
            t.description = Some(desc);
        }
        if let Some(amount) = dto.amount {
            t.amount = amount;
        }
        if let Some(ref dir) = dto.direction {
            t.direction = parse_direction(dir)?;
        }
        if let Some(aid) = dto.source_account_id {
            self.account_repo
                .find_by_id(aid)
                .await?
                .ok_or(TransactionTemplateServiceError::AccountNotFound(aid))?;
            t.source_account_id = aid;
        }
        if let Some(ref dest_id) = dto.destination_account_id {
            self.account_repo
                .find_by_id(*dest_id)
                .await?
                .ok_or(TransactionTemplateServiceError::DestinationAccountNotFound(*dest_id))?;
            t.destination_account_id = Some(*dest_id);
        }
        if let Some(ref cyc) = dto.cycle {
            t.cycle = parse_cycle(cyc, dto.cycle_days)?;
        }
        if dto.billing_day.is_some() {
            t.billing_day = dto.billing_day;
        }
        if let Some(nd) = dto.next_date {
            t.next_date = nd;
        }
        if dto.end_date.is_some() {
            t.end_date = dto.end_date;
        }
        if let Some(ar) = dto.auto_record {
            t.auto_record = ar;
        }

        self.template_repo.update(&t).await?;
        Ok(())
    }

    pub async fn delete(&self, id: Uuid) -> Result<(), TransactionTemplateServiceError> {
        self.template_repo.soft_delete(id).await?;
        Ok(())
    }

    pub async fn pause(&self, id: Uuid) -> Result<(), TransactionTemplateServiceError> {
        self.template_repo.set_paused(id, true).await?;
        Ok(())
    }

    pub async fn resume(&self, id: Uuid) -> Result<(), TransactionTemplateServiceError> {
        self.template_repo.set_paused(id, false).await?;
        Ok(())
    }

    pub async fn process_due_templates(
        &self,
        today: NaiveDate,
    ) -> Result<usize, TransactionTemplateServiceError> {
        let due = self.template_repo.find_due(today).await?;
        let mut processed = 0;
        for t in &due {
            match self.record_template(t).await {
                Ok(txn_id) => {
                    let mut updated = t.clone();
                    updated.last_transaction_id = Some(txn_id);
                    updated.advance_to_next();
                    if let Err(e) = self
                        .template_repo
                        .update_next_date(updated.id, updated.next_date, updated.last_transaction_id)
                        .await
                    {
                        tracing::error!(
                            "Failed to update next date for template {}: {}",
                            t.id,
                            e
                        );
                        continue;
                    }
                    processed += 1;
                }
                Err(e) => {
                    tracing::error!("Failed to process template {}: {}", t.id, e);
                    continue;
                }
            }
        }
        Ok(processed)
    }

    async fn record_template(
        &self,
        t: &TransactionTemplate,
    ) -> Result<Uuid, TransactionTemplateServiceError> {
        let source_account = self
            .account_repo
            .find_by_id(t.source_account_id)
            .await?
            .ok_or(TransactionTemplateServiceError::AccountNotFound(
                t.source_account_id,
            ))?;

        let txn_id = Uuid::new_v4();
        let desc = format!("{} - {}", t.name, t.next_date);

        let source_chart = source_account.chart_code.as_deref().unwrap_or("1002");

        let entries = match &t.direction {
            TemplateDirection::Expense => {
                let amount_money = Money::new(t.amount, &source_account.currency_code)
                    .map_err(|e| TransactionTemplateServiceError::ValidationError(e.to_string()))?;
                vec![
                    TransactionEntry::new(
                        t.source_account_id,
                        "5401",
                        Some(amount_money.clone()),
                        None,
                        &t.name,
                    )
                    .map_err(|e| TransactionTemplateServiceError::ValidationError(e.to_string()))?,
                    TransactionEntry::new(
                        t.source_account_id,
                        source_chart,
                        None,
                        Some(amount_money),
                        &desc,
                    )
                    .map_err(|e| TransactionTemplateServiceError::ValidationError(e.to_string()))?,
                ]
            }
            TemplateDirection::Income => {
                let amount_money = Money::new(t.amount, &source_account.currency_code)
                    .map_err(|e| TransactionTemplateServiceError::ValidationError(e.to_string()))?;
                vec![
                    TransactionEntry::new(
                        t.source_account_id,
                        source_chart,
                        Some(amount_money.clone()),
                        None,
                        &desc,
                    )
                    .map_err(|e| TransactionTemplateServiceError::ValidationError(e.to_string()))?,
                    TransactionEntry::new(
                        t.source_account_id,
                        "4201",
                        None,
                        Some(amount_money),
                        &t.name,
                    )
                    .map_err(|e| TransactionTemplateServiceError::ValidationError(e.to_string()))?,
                ]
            }
            TemplateDirection::Transfer => {
                let dest_id = t
                    .destination_account_id
                    .ok_or(TransactionTemplateServiceError::ValidationError(
                        "destination account required for transfer".into(),
                    ))?;
                let dest_account = self
                    .account_repo
                    .find_by_id(dest_id)
                    .await?
                    .ok_or(TransactionTemplateServiceError::DestinationAccountNotFound(
                        dest_id,
                    ))?;
                let dest_chart = dest_account.chart_code.as_deref().unwrap_or("1002");
                let amount_money = Money::new(t.amount, &source_account.currency_code)
                    .map_err(|e| TransactionTemplateServiceError::ValidationError(e.to_string()))?;
                vec![
                    TransactionEntry::new(
                        dest_id,
                        dest_chart,
                        Some(amount_money.clone()),
                        None,
                        &desc,
                    )
                    .map_err(|e| TransactionTemplateServiceError::ValidationError(e.to_string()))?,
                    TransactionEntry::new(
                        t.source_account_id,
                        source_chart,
                        None,
                        Some(amount_money),
                        &desc,
                    )
                    .map_err(|e| TransactionTemplateServiceError::ValidationError(e.to_string()))?,
                ]
            }
        };

        let transaction = Transaction::new(
            txn_id,
            t.next_date,
            desc,
            entries,
            SyncMetadata::new(Uuid::new_v4()),
        )
        .map_err(|e| TransactionTemplateServiceError::ValidationError(e.to_string()))?;
        self.transaction_repo.create(&transaction).await?;
        Ok(txn_id)
    }
}

fn parse_cycle(
    s: &str,
    days: Option<u32>,
) -> Result<TemplateCycle, TransactionTemplateServiceError> {
    match s {
        "weekly" => Ok(TemplateCycle::Weekly),
        "monthly" => Ok(TemplateCycle::Monthly),
        "yearly" => Ok(TemplateCycle::Yearly),
        "custom" => Ok(TemplateCycle::Custom {
            days: days.unwrap_or(30),
        }),
        _ => Err(TransactionTemplateServiceError::ValidationError(format!(
            "invalid cycle: {s}"
        ))),
    }
}

fn parse_direction(
    s: &str,
) -> Result<TemplateDirection, TransactionTemplateServiceError> {
    match s {
        "expense" => Ok(TemplateDirection::Expense),
        "income" => Ok(TemplateDirection::Income),
        "transfer" => Ok(TemplateDirection::Transfer),
        _ => Err(TransactionTemplateServiceError::ValidationError(format!(
            "invalid direction: {s}"
        ))),
    }
}

fn direction_to_str(d: &TemplateDirection) -> String {
    match d {
        TemplateDirection::Expense => "expense".into(),
        TemplateDirection::Income => "income".into(),
        TemplateDirection::Transfer => "transfer".into(),
    }
}

fn cycle_to_str(c: &TemplateCycle) -> String {
    match c {
        TemplateCycle::Weekly => "weekly".into(),
        TemplateCycle::Monthly => "monthly".into(),
        TemplateCycle::Yearly => "yearly".into(),
        TemplateCycle::Custom { .. } => "custom".into(),
    }
}
