use crate::application::dtos::{
    CreateTransactionDto, SimpleExpenseDto, SimpleIncomeDto, SimpleTransferDto, TransactionDto,
    TransactionEntryDto,
};
use crate::domain::{
    aggregates::Transaction,
    repositories::{AccountRepository, TransactionRepository},
    value_objects::{Money, SyncMetadata, TransactionEntry},
};
use crate::infrastructure::repositories::{
    SqliteAccountRepository, SqliteTransactionRepository,
};
use std::sync::Arc;
use uuid::Uuid;

pub struct TransactionService {
    transaction_repo: Arc<SqliteTransactionRepository>,
    account_repo: Arc<SqliteAccountRepository>,
}

#[derive(Debug)]
pub enum TransactionServiceError {
    TransactionNotFound(Uuid),
    AccountNotFound(Uuid),
    CategoryNotFound(String),
    ValidationError(String),
    RepositoryError(String),
}

impl std::fmt::Display for TransactionServiceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::TransactionNotFound(id) => write!(f, "transaction not found: {id}"),
            Self::AccountNotFound(id) => write!(f, "account not found: {id}"),
            Self::CategoryNotFound(id) => write!(f, "category not found: {id}"),
            Self::ValidationError(msg) => write!(f, "validation error: {msg}"),
            Self::RepositoryError(msg) => write!(f, "repository error: {msg}"),
        }
    }
}

impl std::error::Error for TransactionServiceError {}

impl From<sqlx::Error> for TransactionServiceError {
    fn from(err: sqlx::Error) -> Self {
        Self::RepositoryError(err.to_string())
    }
}

impl TransactionService {
    pub fn new(
        transaction_repo: Arc<SqliteTransactionRepository>,
        account_repo: Arc<SqliteAccountRepository>,
    ) -> Self {
        Self {
            transaction_repo,
            account_repo,
        }
    }

    pub async fn create_transaction(
        &self,
        dto: CreateTransactionDto,
    ) -> Result<Uuid, TransactionServiceError> {
        let transaction_id = Uuid::new_v4();
        let device_id = Uuid::new_v4();

        let mut entries = Vec::new();
        for entry_dto in &dto.entries {
            let account = self
                .account_repo
                .find_by_id(entry_dto.account_id)
                .await?
                .ok_or(TransactionServiceError::AccountNotFound(
                    entry_dto.account_id,
                ))?;

            let debit_amount = entry_dto
                .debit_amount
                .map(|amt| Money::new(amt, &account.currency_code))
                .transpose()
                .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

            let credit_amount = entry_dto
                .credit_amount
                .map(|amt| Money::new(amt, &account.currency_code))
                .transpose()
                .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

            let entry = TransactionEntry::new(
                entry_dto.account_id,
                &entry_dto.chart_of_account_code,
                debit_amount,
                credit_amount,
                entry_dto.memo.as_deref().unwrap_or(""),
            )
            .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

            entries.push(entry);
        }

        let transaction = Transaction::new(
            transaction_id,
            dto.transaction_date,
            dto.description,
            entries,
            SyncMetadata::new(device_id),
        )
        .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

        if !transaction.is_balanced() {
            return Err(TransactionServiceError::ValidationError(
                "transaction is not balanced".to_string(),
            ));
        }

        self.transaction_repo.create(&transaction).await?;

        for entry in &transaction.entries {
            let mut account = self
                .account_repo
                .find_by_id(entry.account_id)
                .await?
                .ok_or(TransactionServiceError::AccountNotFound(entry.account_id))?;

            let new_balance = if let Some(debit) = &entry.debit_amount {
                account.balance.add(debit).map_err(|e| {
                    TransactionServiceError::ValidationError(format!("failed to add debit: {}", e))
                })?
            } else if let Some(credit) = &entry.credit_amount {
                account.balance.subtract(credit).map_err(|e| {
                    TransactionServiceError::ValidationError(format!(
                        "failed to subtract credit: {}",
                        e
                    ))
                })?
            } else {
                account.balance.clone()
            };

            account
                .update_balance(new_balance)
                .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

            self.account_repo.update(&account).await?;
        }

        Ok(transaction_id)
    }

    pub async fn get_transaction(
        &self,
        id: Uuid,
    ) -> Result<TransactionDto, TransactionServiceError> {
        let transaction = self
            .transaction_repo
            .find_by_id(id)
            .await?
            .ok_or(TransactionServiceError::TransactionNotFound(id))?;

        Ok(self.to_dto(transaction))
    }

    pub async fn list_transactions(&self) -> Result<Vec<TransactionDto>, TransactionServiceError> {
        let transactions = self.transaction_repo.find_all().await?;
        Ok(transactions.into_iter().map(|t| self.to_dto(t)).collect())
    }

    pub async fn get_transactions_by_account(
        &self,
        account_id: Uuid,
    ) -> Result<Vec<TransactionDto>, TransactionServiceError> {
        let transactions = self.transaction_repo.find_all().await?;
        let filtered: Vec<TransactionDto> = transactions
            .into_iter()
            .filter(|t| t.entries.iter().any(|e| e.account_id == account_id))
            .map(|t| self.to_dto(t))
            .collect();
        Ok(filtered)
    }

    pub async fn get_transactions_by_date_range(
        &self,
        start_date: chrono::NaiveDate,
        end_date: chrono::NaiveDate,
    ) -> Result<Vec<TransactionDto>, TransactionServiceError> {
        let transactions = self
            .transaction_repo
            .find_by_date_range(start_date, end_date)
            .await?;
        Ok(transactions.into_iter().map(|t| self.to_dto(t)).collect())
    }

    fn to_dto(&self, transaction: Transaction) -> TransactionDto {
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
                    category_id: None,
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

    /// 创建收入交易（简化版）
    /// 自动生成复式记账条目：借记账户（资产增加），贷记收入科目
    /// TODO: Reimplement using account-based categories (Task 9/10)
    #[allow(dead_code)]
    pub async fn create_income(
        &self,
        _dto: SimpleIncomeDto,
    ) -> Result<Uuid, TransactionServiceError> {
        todo!("create_income will be refactored to use account-based categories")
    }

    /// 创建支出交易（简化版）
    /// 自动生成复式记账条目：借记支出科目，贷记账户（资产减少）
    /// TODO: Reimplement using account-based categories (Task 9/10)
    #[allow(dead_code)]
    pub async fn create_expense(
        &self,
        _dto: SimpleExpenseDto,
    ) -> Result<Uuid, TransactionServiceError> {
        todo!("create_expense will be refactored to use account-based categories")
    }

    /// 创建转账交易（简化版）
    /// 自动生成复式记账条目：借记目标账户，贷记源账户
    pub async fn create_transfer(
        &self,
        dto: SimpleTransferDto,
    ) -> Result<Uuid, TransactionServiceError> {
        let from_account = self
            .account_repo
            .find_by_id(dto.from_account_id)
            .await?
            .ok_or(TransactionServiceError::AccountNotFound(dto.from_account_id))?;

        let to_account = self
            .account_repo
            .find_by_id(dto.to_account_id)
            .await?
            .ok_or(TransactionServiceError::AccountNotFound(dto.to_account_id))?;

        // 验证货币一致性
        if from_account.currency_code != to_account.currency_code {
            return Err(TransactionServiceError::ValidationError(
                "transfer between accounts with different currencies is not supported".to_string(),
            ));
        }

        let money = Money::new(dto.amount, &from_account.currency_code)
            .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

        // 借：目标账户（资产增加）
        let debit_entry = TransactionEntry::new(
            to_account.id,
            "1002", // 银行存款科目代码
            Some(money.clone()),
            None,
            &dto.description,
        )
        .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

        // 贷：源账户（资产减少）
        let credit_entry = TransactionEntry::new(
            from_account.id,
            "1002", // 银行存款科目代码
            None,
            Some(money),
            &dto.description,
        )
        .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

        let transaction = Transaction::new(
            Uuid::new_v4(),
            dto.date,
            dto.description.clone(),
            vec![debit_entry, credit_entry],
            SyncMetadata::new(Uuid::new_v4()),
        )
        .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

        self.transaction_repo.create(&transaction).await?;

        // 更新两个账户的余额
        let mut from_account = from_account;
        let from_new_balance = from_account
            .balance
            .subtract(&Money::new(dto.amount, &from_account.currency_code)
                .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?)
            .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;
        from_account
            .update_balance(from_new_balance)
            .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;
        self.account_repo.update(&from_account).await?;

        let mut to_account = to_account;
        let to_new_balance = to_account
            .balance
            .add(&Money::new(dto.amount, &to_account.currency_code)
                .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?)
            .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;
        to_account
            .update_balance(to_new_balance)
            .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;
        self.account_repo.update(&to_account).await?;

        Ok(transaction.id)
    }
}

// TODO: Tests will be rewritten in Tasks 9/10 after category functionality is absorbed into accounts
