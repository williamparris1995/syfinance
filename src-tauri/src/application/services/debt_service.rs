use crate::application::dtos::{CreateDebtDto, DebtDto, PaymentScheduleDto, RecordPaymentDto, UpdateDebtDto};
use crate::domain::{
    aggregates::{
        debt_details::{AmortizationMethod, DebtDetails, PaymentScheduleEntry},
        Account, AccountType, Ownership, Transaction,
    },
    repositories::{AccountRepository, DebtRepository, TransactionRepository},
    value_objects::{Currency, Money, SyncMetadata, TransactionEntry},
};
use crate::infrastructure::repositories::{
    SqliteAccountRepository, SqliteDebtRepository, SqliteTransactionRepository,
};
use chrono::NaiveDate;
use rust_decimal::Decimal;
use std::sync::Arc;
use uuid::Uuid;

pub struct DebtService {
    debt_repo: Arc<SqliteDebtRepository>,
    account_repo: Arc<SqliteAccountRepository>,
    transaction_repo: Arc<SqliteTransactionRepository>,
}

#[derive(Debug)]
pub enum DebtServiceError {
    DebtNotFound(Uuid),
    AccountNotFound(Uuid),
    ScheduleEntryNotFound(Uuid),
    ScheduleEntryAlreadyPaid(Uuid),
    ValidationError(String),
    RepositoryError(String),
}

impl std::fmt::Display for DebtServiceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::DebtNotFound(id) => write!(f, "debt not found: {id}"),
            Self::AccountNotFound(id) => write!(f, "account not found: {id}"),
            Self::ScheduleEntryNotFound(id) => write!(f, "schedule entry not found: {id}"),
            Self::ScheduleEntryAlreadyPaid(id) => write!(f, "schedule entry already paid: {id}"),
            Self::ValidationError(msg) => write!(f, "validation error: {msg}"),
            Self::RepositoryError(msg) => write!(f, "repository error: {msg}"),
        }
    }
}

impl std::error::Error for DebtServiceError {}

impl From<sqlx::Error> for DebtServiceError {
    fn from(err: sqlx::Error) -> Self {
        Self::RepositoryError(err.to_string())
    }
}

impl DebtService {
    pub fn new(
        debt_repo: Arc<SqliteDebtRepository>,
        account_repo: Arc<SqliteAccountRepository>,
        transaction_repo: Arc<SqliteTransactionRepository>,
    ) -> Self {
        Self {
            debt_repo,
            account_repo,
            transaction_repo,
        }
    }

    pub async fn create_debt(&self, dto: CreateDebtDto) -> Result<Uuid, DebtServiceError> {
        let debt_account = self
            .account_repo
            .find_by_id(dto.account_id)
            .await?
            .ok_or(DebtServiceError::AccountNotFound(dto.account_id))?;

        let funding_account = self
            .account_repo
            .find_by_id(dto.funding_account_id)
            .await?
            .ok_or(DebtServiceError::AccountNotFound(dto.funding_account_id))?;

        let details_id = Uuid::new_v4();

        let amortization_method = dto
            .amortization_method
            .as_ref()
            .map(|s| parse_amortization_method(s))
            .transpose()?
            .unwrap_or(AmortizationMethod::LumpSum);

        let today = chrono::Utc::now().date_naive();
        let start_date = dto.start_date.unwrap_or(today);
        let due_date = dto.due_date.unwrap_or_else(|| {
            today + chrono::Duration::days(365)
        });

        let mut debt_details = DebtDetails::new(
            details_id,
            dto.account_id,
            dto.counterparty,
            dto.interest_rate,
            amortization_method,
            start_date,
            due_date,
            dto.principal_amount,
        );
        debt_details.generate_schedule();

        // Create initial disbursement transaction
        let device_id = Uuid::new_v4();
        let transaction_id = Uuid::new_v4();
        let principal = Money::new(dto.principal_amount, &debt_account.currency_code)
            .map_err(|e| DebtServiceError::ValidationError(e.to_string()))?;

        let debt_chart = debt_account
            .chart_code
            .as_deref()
            .unwrap_or_else(|| default_chart_code(&debt_account.account_type));
        let funding_chart = funding_account
            .chart_code
            .as_deref()
            .unwrap_or("1002");

        let txn_note = format!("{} - {}", debt_account.name, debt_details.counterparty);
        let entries = if is_liability_type(&debt_account.account_type) {
            vec![
                TransactionEntry::new(
                    funding_account.id,
                    funding_chart,
                    Some(principal.clone()),
                    None,
                    &format!("{}: {}", debt_details.counterparty, funding_account.name),
                ).map_err(|e| DebtServiceError::ValidationError(e.to_string()))?,
                TransactionEntry::new(
                    debt_account.id,
                    debt_chart,
                    None,
                    Some(principal),
                    &format!("{}: {}", debt_details.counterparty, debt_account.name),
                ).map_err(|e| DebtServiceError::ValidationError(e.to_string()))?,
            ]
        } else {
            vec![
                TransactionEntry::new(
                    debt_account.id,
                    debt_chart,
                    Some(principal.clone()),
                    None,
                    &format!("{}: {}", debt_details.counterparty, debt_account.name),
                ).map_err(|e| DebtServiceError::ValidationError(e.to_string()))?,
                TransactionEntry::new(
                    funding_account.id,
                    funding_chart,
                    None,
                    Some(principal),
                    &format!("{}: {}", debt_details.counterparty, funding_account.name),
                ).map_err(|e| DebtServiceError::ValidationError(e.to_string()))?,
            ]
        };

        let transaction = Transaction::new(
            transaction_id,
            today,
            format!("{} - {}", debt_details.counterparty, debt_account.name),
            entries,
            SyncMetadata::new(device_id),
        ).map_err(|e| DebtServiceError::ValidationError(e.to_string()))?;

        self.transaction_repo.create(&transaction).await?;
        self.debt_repo.create_debt_details(&debt_details).await?;

        Ok(transaction_id)
    }

    pub async fn get_debt(&self, account_id: Uuid) -> Result<DebtDto, DebtServiceError> {
        let account = self
            .account_repo
            .find_by_id(account_id)
            .await?
            .ok_or(DebtServiceError::AccountNotFound(account_id))?;

        let debt = self
            .debt_repo
            .find_debt_details_by_account_id(account_id)
            .await?
            .ok_or(DebtServiceError::DebtNotFound(account_id))?;

        Ok(self.to_dto(account, debt))
    }

    pub async fn list_debts(&self) -> Result<Vec<DebtDto>, DebtServiceError> {
        let all_debts = self.debt_repo.find_all_debt_details().await?;
        let mut dtos = Vec::new();

        for debt in all_debts {
            if let Ok(Some(account)) = self.account_repo.find_by_id(debt.account_id).await {
                dtos.push(self.to_dto(account, debt));
            }
        }

        Ok(dtos)
    }

    pub async fn record_payment(
        &self,
        dto: RecordPaymentDto,
    ) -> Result<Uuid, DebtServiceError> {
        let schedule = self
            .debt_repo
            .find_schedule_by_debt_id(
                self.find_schedule_debt_id(dto.schedule_entry_id).await?,
            )
            .await?;

        let entry = schedule
            .iter()
            .find(|e| e.id == dto.schedule_entry_id)
            .ok_or(DebtServiceError::ScheduleEntryNotFound(dto.schedule_entry_id))?;

        if entry.paid {
            return Err(DebtServiceError::ScheduleEntryAlreadyPaid(
                dto.schedule_entry_id,
            ));
        }

        let debt = self
            .debt_repo
            .find_debt_details_by_id(entry.debt_id)
            .await?
            .ok_or(DebtServiceError::DebtNotFound(entry.debt_id))?;

        let debt_account = self
            .account_repo
            .find_by_id(debt.account_id)
            .await?
            .ok_or(DebtServiceError::AccountNotFound(debt.account_id))?;

        let source_account = self
            .account_repo
            .find_by_id(dto.payment_source_account_id)
            .await?
            .ok_or(DebtServiceError::AccountNotFound(
                dto.payment_source_account_id,
            ))?;

        let transaction_id = Uuid::new_v4();
        let device_id = Uuid::new_v4();

        let entries = if is_liability_type(&debt_account.account_type) {
            build_liability_repayment_entries(
                &debt_account,
                &source_account,
                &dto,
                entry,
                transaction_id,
            )
            .await?
        } else {
            build_receivable_recovery_entries(
                &debt_account,
                &source_account,
                &dto,
                entry,
                transaction_id,
            )
            .await?
        };

        let transaction = Transaction::new(
            transaction_id,
            chrono::Utc::now().date_naive(),
            debt.counterparty.clone(),
            entries,
            SyncMetadata::new(device_id),
        )
        .map_err(|e| DebtServiceError::ValidationError(e.to_string()))?;

        self.transaction_repo.create(&transaction).await?;

        let mut updated_entry = entry.clone();
        updated_entry.paid = true;
        updated_entry.transaction_id = Some(transaction_id);
        self.debt_repo.update_schedule_entry(&updated_entry).await?;

        Ok(transaction_id)
    }

    pub async fn get_upcoming_payments(
        &self,
        days_ahead: i32,
    ) -> Result<Vec<(DebtDto, PaymentScheduleDto)>, DebtServiceError> {
        let upcoming = self.debt_repo.get_upcoming_payments(days_ahead).await?;
        let mut results = Vec::new();

        for (debt, entry) in upcoming {
            if let Ok(Some(account)) = self.account_repo.find_by_id(debt.account_id).await {
                results.push((self.to_dto(account, debt), self.to_schedule_dto(&entry)));
            }
        }

        Ok(results)
    }

    async fn find_schedule_debt_id(
        &self,
        schedule_entry_id: Uuid,
    ) -> Result<Uuid, DebtServiceError> {
        let all_debts = self.debt_repo.find_all_debt_details().await?;
        for debt in &all_debts {
            let schedule = self.debt_repo.find_schedule_by_debt_id(debt.id).await?;
            if schedule.iter().any(|e| e.id == schedule_entry_id) {
                return Ok(debt.id);
            }
        }
        Err(DebtServiceError::ScheduleEntryNotFound(schedule_entry_id))
    }

    fn to_dto(&self, account: Account, debt: DebtDetails) -> DebtDto {
        let remaining = debt.remaining_principal();
        DebtDto {
            account_id: account.id,
            account_name: account.name,
            account_type: account.account_type,
            counterparty: debt.counterparty,
            principal_amount: debt.total_principal.to_string(),
            remaining_principal: remaining.to_string(),
            currency_code: account.currency_code,
            interest_rate: debt.interest_rate.to_string(),
            start_date: debt.start_date,
            due_date: debt.due_date,
            amortization_method: debt.amortization_method.to_string(),
            payment_schedule: debt
                .payment_schedule
                .iter()
                .map(|e| self.to_schedule_dto(e))
                .collect(),
        }
    }

    fn to_schedule_dto(&self, entry: &PaymentScheduleEntry) -> PaymentScheduleDto {
        PaymentScheduleDto {
            id: entry.id,
            payment_date: entry.payment_date,
            principal_amount: entry.principal_amount.to_string(),
            interest_amount: entry.interest_amount.to_string(),
            total_amount: entry.total_amount.to_string(),
            paid: entry.paid,
            transaction_id: entry.transaction_id,
        }
    }

    pub async fn update_debt(
        &self,
        account_id: Uuid,
        dto: UpdateDebtDto,
    ) -> Result<DebtDto, DebtServiceError> {
        let mut debt = self
            .debt_repo
            .find_debt_details_by_account_id(account_id)
            .await?
            .ok_or(DebtServiceError::DebtNotFound(account_id))?;

        debt.counterparty = dto.counterparty;
        debt.interest_rate = dto.interest_rate;
        debt.start_date = dto.start_date;
        debt.due_date = dto.due_date;
        debt.amortization_method = parse_amortization_method(&dto.amortization_method)?;

        self.debt_repo.update_debt_details(&debt).await?;

        let account = self
            .account_repo
            .find_by_id(account_id)
            .await?
            .ok_or(DebtServiceError::AccountNotFound(account_id))?;

        Ok(self.to_dto(account, debt))
    }

    pub async fn delete_debt(&self, account_id: Uuid) -> Result<(), DebtServiceError> {
        let debt = self
            .debt_repo
            .find_debt_details_by_account_id(account_id)
            .await?
            .ok_or(DebtServiceError::DebtNotFound(account_id))?;

        let schedule = self.debt_repo.find_schedule_by_debt_id(debt.id).await?;
        for mut entry in schedule {
            entry.paid = true; // mark as resolved (won't show in upcoming)
            let _ = self.debt_repo.update_schedule_entry(&entry).await;
        }

        self.debt_repo.soft_delete_debt_details(debt.id).await?;
        Ok(())
    }
}

fn is_liability_type(account_type: &AccountType) -> bool {
    matches!(
        account_type,
        AccountType::BorrowedIn | AccountType::CreditCard
    )
}

fn default_chart_code(account_type: &AccountType) -> &str {
    match account_type {
        AccountType::BorrowedOut => "1221",
        AccountType::BorrowedIn => "2001",
        AccountType::CreditCard => "2202",
        AccountType::Investment => "1101",
        AccountType::Cash => "1001",
        AccountType::Bank => "1002",
        _ => "2001",
    }
}

async fn build_liability_repayment_entries(
    debt_account: &Account,
    source_account: &Account,
    _dto: &RecordPaymentDto,
    entry: &PaymentScheduleEntry,
    _transaction_id: Uuid,
) -> Result<Vec<TransactionEntry>, DebtServiceError> {
    // 借: 长期借款(debt account) ¥principal  (liability decreases)
    // 借: 利息支出(interest account) ¥interest  (expense)
    //     贷: 银行存款(payment source)  ¥total  (asset decreases)

    let principal = Money::new(entry.principal_amount, &debt_account.currency_code)
        .map_err(|e| DebtServiceError::ValidationError(e.to_string()))?;
    let total = Money::new(entry.total_amount, &source_account.currency_code)
        .map_err(|e| DebtServiceError::ValidationError(e.to_string()))?;

    let debt_chart = debt_account
        .chart_code
        .as_deref()
        .unwrap_or_else(|| default_chart_code(&debt_account.account_type));

    let source_chart = source_account
        .chart_code
        .as_deref()
        .unwrap_or("1002");

    let debit_debt = TransactionEntry::new(
        debt_account.id,
        debt_chart,
        Some(principal.clone()),
        None,
        &debt_account.name,
    )
    .map_err(|e| DebtServiceError::ValidationError(e.to_string()))?;

    let credit_source = TransactionEntry::new(
        source_account.id,
        source_chart,
        None,
        Some(total.clone()),
        &source_account.name,
    )
    .map_err(|e| DebtServiceError::ValidationError(e.to_string()))?;

    if entry.interest_amount > Decimal::ZERO {
        let interest = Money::new(entry.interest_amount, &debt_account.currency_code)
            .map_err(|e| DebtServiceError::ValidationError(e.to_string()))?;

        let interest_chart = "5201";

        let debit_interest = TransactionEntry::new(
            debt_account.id,
            interest_chart,
            Some(interest),
            None,
            &debt_account.name,
        )
        .map_err(|e| DebtServiceError::ValidationError(e.to_string()))?;

        Ok(vec![debit_debt, debit_interest, credit_source])
    } else {
        Ok(vec![debit_debt, credit_source])
    }
}

async fn build_receivable_recovery_entries(
    debt_account: &Account,
    dest_account: &Account,
    _dto: &RecordPaymentDto,
    entry: &PaymentScheduleEntry,
    _transaction_id: Uuid,
) -> Result<Vec<TransactionEntry>, DebtServiceError> {
    // 借: 银行存款(receiving account)  ¥total  (asset increases)
    //     贷: 其他应收款(debt account)  ¥principal  (receivable decreases)
    //     贷: 利息收入(income account)  ¥interest (if any)  (income)

    let total = Money::new(entry.total_amount, &debt_account.currency_code)
        .map_err(|e| DebtServiceError::ValidationError(e.to_string()))?;

    let principal = Money::new(entry.principal_amount, &debt_account.currency_code)
        .map_err(|e| DebtServiceError::ValidationError(e.to_string()))?;

    let dest_chart = dest_account
        .chart_code
        .as_deref()
        .unwrap_or("1002");

    let debt_chart = debt_account
        .chart_code
        .as_deref()
        .unwrap_or_else(|| default_chart_code(&debt_account.account_type));

    let debit_dest = TransactionEntry::new(
        dest_account.id,
        dest_chart,
        Some(total.clone()),
        None,
        &dest_account.name,
    )
    .map_err(|e| DebtServiceError::ValidationError(e.to_string()))?;

    let credit_debt = TransactionEntry::new(
        debt_account.id,
        debt_chart,
        None,
        Some(principal),
        &debt_account.name,
    )
    .map_err(|e| DebtServiceError::ValidationError(e.to_string()))?;

    let mut entries = vec![debit_dest, credit_debt];

    if entry.interest_amount > Decimal::ZERO {
        let interest = Money::new(entry.interest_amount, &debt_account.currency_code)
            .map_err(|e| DebtServiceError::ValidationError(e.to_string()))?;

        let income_chart = "4001";

        let credit_interest = TransactionEntry::new(
            debt_account.id,
            income_chart,
            None,
            Some(interest),
            &debt_account.name,
        )
        .map_err(|e| DebtServiceError::ValidationError(e.to_string()))?;

        entries.push(credit_interest);
    }

    Ok(entries)
}

fn parse_amortization_method(s: &str) -> Result<AmortizationMethod, DebtServiceError> {
    match s {
        "EqualPrincipalInterest" | "equal_principal_interest" => {
            Ok(AmortizationMethod::EqualPrincipalInterest)
        }
        "EqualPrincipal" | "equal_principal" => Ok(AmortizationMethod::EqualPrincipal),
        "LumpSum" | "lump_sum" => Ok(AmortizationMethod::LumpSum),
        _ => Err(DebtServiceError::ValidationError(format!(
            "invalid amortization method: {s}"
        ))),
    }
}
