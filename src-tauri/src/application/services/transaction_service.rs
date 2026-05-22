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
    ValidationError(String),
    RepositoryError(String),
}

impl std::fmt::Display for TransactionServiceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::TransactionNotFound(id) => write!(f, "transaction not found: {id}"),
            Self::AccountNotFound(id) => write!(f, "account not found: {id}"),
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

    async fn reverse_balances(
        &self,
        entries: &[TransactionEntry],
    ) -> Result<(), TransactionServiceError> {
        for entry in entries {
            let mut account = self
                .account_repo
                .find_by_id(entry.account_id)
                .await?
                .ok_or(TransactionServiceError::AccountNotFound(entry.account_id))?;

            let new_balance = if let Some(debit) = &entry.debit_amount {
                account.balance.subtract(debit).map_err(|e| {
                    TransactionServiceError::ValidationError(format!(
                        "failed to reverse debit: {}",
                        e
                    ))
                })?
            } else if let Some(credit) = &entry.credit_amount {
                account.balance.add(credit).map_err(|e| {
                    TransactionServiceError::ValidationError(format!(
                        "failed to reverse credit: {}",
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
        Ok(())
    }

    pub async fn update_transaction(
        &self,
        id: Uuid,
        dto: CreateTransactionDto,
    ) -> Result<Uuid, TransactionServiceError> {
        // 1. Find old transaction
        let old = self
            .transaction_repo
            .find_by_id(id)
            .await?
            .ok_or(TransactionServiceError::TransactionNotFound(id))?;

        // 2. Reverse old account balances
        self.reverse_balances(&old.entries).await?;

        // 3. Build new entries
        let mut new_entries = Vec::new();
        for entry_dto in &dto.entries {
            let account = self
                .account_repo
                .find_by_id(entry_dto.account_id)
                .await?
                .ok_or(TransactionServiceError::AccountNotFound(entry_dto.account_id))?;

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

            new_entries.push(entry);
        }

        // 4. Build updated transaction (reuse old ID, update sync metadata)
        let updated_sync = SyncMetadata::new(old.sync_metadata.device_id);

        let updated_transaction = Transaction::new(
            id,
            dto.transaction_date,
            dto.description,
            new_entries,
            updated_sync,
        )
        .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

        if !updated_transaction.is_balanced() {
            return Err(TransactionServiceError::ValidationError(
                "updated transaction is not balanced".to_string(),
            ));
        }

        // 5. Update in repository (soft-deletes old entries, inserts new ones)
        self.transaction_repo.update(&updated_transaction).await?;

        // 6. Apply new balances
        for entry in &updated_transaction.entries {
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

        Ok(id)
    }

    pub async fn delete_transaction(
        &self,
        id: Uuid,
    ) -> Result<(), TransactionServiceError> {
        // Find transaction to reverse balances
        let transaction = self
            .transaction_repo
            .find_by_id(id)
            .await?
            .ok_or(TransactionServiceError::TransactionNotFound(id))?;

        // Reverse account balances before soft-deleting
        self.reverse_balances(&transaction.entries).await?;

        // Soft delete
        self.transaction_repo.soft_delete(id).await?;

        Ok(())
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
    /// 自动生成复式记账条目：借记自己账户（资产增加），贷记外部账户（收入来源）
    pub async fn create_income(
        &self,
        dto: SimpleIncomeDto,
    ) -> Result<Uuid, TransactionServiceError> {
        let debit_account = self
            .account_repo
            .find_by_id(dto.debit_account_id)
            .await?
            .ok_or(TransactionServiceError::AccountNotFound(dto.debit_account_id))?;

        let credit_account = self
            .account_repo
            .find_by_id(dto.credit_account_id)
            .await?
            .ok_or(TransactionServiceError::AccountNotFound(dto.credit_account_id))?;

        let money = Money::new(dto.amount, &debit_account.currency_code)
            .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

        let chart_code = credit_account.chart_code.as_deref().unwrap_or("4001");

        let debit_entry = TransactionEntry::new(
            debit_account.id,
            chart_code,
            Some(money.clone()),
            None,
            &dto.description,
        )
        .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

        let credit_entry = TransactionEntry::new(
            credit_account.id,
            chart_code,
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

        // Update own account balance (debit side = asset increase)
        let mut debit_account = debit_account;
        let new_balance = debit_account
            .balance
            .add(&Money::new(dto.amount, &debit_account.currency_code)
                .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?)
            .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;
        debit_account
            .update_balance(new_balance)
            .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;
        self.account_repo.update(&debit_account).await?;

        Ok(transaction.id)
    }

    /// 创建支出交易（简化版）
    /// 自动生成复式记账条目：借记外部账户（支出对象），贷记自己账户（资产减少）
    pub async fn create_expense(
        &self,
        dto: SimpleExpenseDto,
    ) -> Result<Uuid, TransactionServiceError> {
        let debit_account = self
            .account_repo
            .find_by_id(dto.debit_account_id)
            .await?
            .ok_or(TransactionServiceError::AccountNotFound(dto.debit_account_id))?;

        let credit_account = self
            .account_repo
            .find_by_id(dto.credit_account_id)
            .await?
            .ok_or(TransactionServiceError::AccountNotFound(dto.credit_account_id))?;

        let money = Money::new(dto.amount, &credit_account.currency_code)
            .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

        let chart_code = debit_account.chart_code.as_deref().unwrap_or("5401");

        let debit_entry = TransactionEntry::new(
            debit_account.id,
            chart_code,
            Some(money.clone()),
            None,
            &dto.description,
        )
        .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

        let credit_entry = TransactionEntry::new(
            credit_account.id,
            chart_code,
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

        // Update own account balance (credit side = asset decrease)
        let mut credit_account = credit_account;
        let new_balance = credit_account
            .balance
            .subtract(&Money::new(dto.amount, &credit_account.currency_code)
                .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?)
            .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;
        credit_account
            .update_balance(new_balance)
            .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;
        self.account_repo.update(&credit_account).await?;

        Ok(transaction.id)
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
