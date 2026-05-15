use crate::application::dtos::{
    CreateTransactionDto, SimpleExpenseDto, SimpleIncomeDto, SimpleTransferDto, TransactionDto,
    TransactionEntryDto,
};
use crate::domain::{
    aggregates::Transaction,
    repositories::{AccountRepository, CategoryRepository, TransactionRepository},
    value_objects::{Money, SyncMetadata, TransactionEntry},
};
use crate::infrastructure::repositories::{
    SqliteAccountRepository, SqliteCategoryRepository, SqliteTransactionRepository,
};
use std::sync::Arc;
use uuid::Uuid;

pub struct TransactionService {
    transaction_repo: Arc<SqliteTransactionRepository>,
    account_repo: Arc<SqliteAccountRepository>,
    category_repo: Arc<SqliteCategoryRepository>,
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
        category_repo: Arc<SqliteCategoryRepository>,
    ) -> Self {
        Self {
            transaction_repo,
            account_repo,
            category_repo,
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
                entry_dto.category_id,
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
                    category_id: e.category_id,
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
    pub async fn create_income(
        &self,
        dto: SimpleIncomeDto,
    ) -> Result<Uuid, TransactionServiceError> {
        let account = self
            .account_repo
            .find_by_id(dto.account_id)
            .await?
            .ok_or(TransactionServiceError::AccountNotFound(dto.account_id))?;

        let category = self
            .category_repo
            .find_by_id(&dto.category_id.to_string())
            .await?
            .ok_or(TransactionServiceError::CategoryNotFound(
                dto.category_id.to_string(),
            ))?;

        let money = Money::new(dto.amount, &account.currency_code)
            .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

        // 借：账户（资产增加）
        let debit_entry = TransactionEntry::new(
            account.id,
            &category.chart_code,
            Some(dto.category_id),
            Some(money.clone()),
            None,
            &dto.description,
        )
        .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

        // 贷：收入科目
        let credit_entry = TransactionEntry::new(
            Uuid::nil(), // 收入科目不关联具体账户
            &category.chart_code,
            Some(dto.category_id),
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

        // 更新账户余额
        let mut account = account;
        let new_balance = account
            .balance
            .add(&Money::new(dto.amount, &account.currency_code)
                .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?)
            .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;
        account
            .update_balance(new_balance)
            .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;
        self.account_repo.update(&account).await?;

        Ok(transaction.id)
    }

    /// 创建支出交易（简化版）
    /// 自动生成复式记账条目：借记支出科目，贷记账户（资产减少）
    pub async fn create_expense(
        &self,
        dto: SimpleExpenseDto,
    ) -> Result<Uuid, TransactionServiceError> {
        let account = self
            .account_repo
            .find_by_id(dto.account_id)
            .await?
            .ok_or(TransactionServiceError::AccountNotFound(dto.account_id))?;

        let category = self
            .category_repo
            .find_by_id(&dto.category_id.to_string())
            .await?
            .ok_or(TransactionServiceError::CategoryNotFound(
                dto.category_id.to_string(),
            ))?;

        let money = Money::new(dto.amount, &account.currency_code)
            .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

        // 借：支出科目
        let debit_entry = TransactionEntry::new(
            Uuid::nil(), // 支出科目不关联具体账户
            &category.chart_code,
            Some(dto.category_id),
            Some(money.clone()),
            None,
            &dto.description,
        )
        .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;

        // 贷：账户（资产减少）
        let credit_entry = TransactionEntry::new(
            account.id,
            &category.chart_code,
            Some(dto.category_id),
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

        // 更新账户余额
        let mut account = account;
        let new_balance = account
            .balance
            .subtract(&Money::new(dto.amount, &account.currency_code)
                .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?)
            .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;
        account
            .update_balance(new_balance)
            .map_err(|e| TransactionServiceError::ValidationError(e.to_string()))?;
        self.account_repo.update(&account).await?;

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
            None,
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{
        aggregates::{Account, AccountType},
        value_objects::Currency,
    };
    use crate::infrastructure::repositories::{
        SqliteAccountRepository, SqliteCategoryRepository, SqliteTransactionRepository,
    };
    use chrono::NaiveDate;
    use rust_decimal::Decimal;
    use sqlx::sqlite::{SqliteConnectOptions, SqlitePoolOptions};
    use std::str::FromStr;

    async fn setup_test_db() -> sqlx::SqlitePool {
        let options = SqliteConnectOptions::from_str("sqlite::memory:")
            .unwrap()
            .create_if_missing(true);

        let pool = SqlitePoolOptions::new()
            .max_connections(1)
            .connect_with(options)
            .await
            .unwrap();

        sqlx::migrate!("./migrations").run(&pool).await.unwrap();

        pool
    }

    fn create_test_account(currency_code: &str) -> Account {
        Account::new(
            Uuid::new_v4(),
            "Test Account",
            AccountType::Bank,
            &Currency::new(currency_code, currency_code, Decimal::ONE).unwrap(),
            Money::new(Decimal::new(1000_00, 2), currency_code).unwrap(),
            SyncMetadata::new(Uuid::new_v4()),
        )
        .unwrap()
    }

    #[tokio::test]
    async fn test_create_balanced_transaction_updates_account_balances() {
        let pool = setup_test_db().await;
        let account_repo = Arc::new(SqliteAccountRepository::new(pool.clone()));
        let transaction_repo = Arc::new(SqliteTransactionRepository::new(pool.clone()));
        let category_repo = Arc::new(SqliteCategoryRepository::new(pool.clone()));
        let category_repo = Arc::new(SqliteCategoryRepository::new(pool.clone()));
        let service = TransactionService::new(transaction_repo, account_repo.clone(), category_repo);

        let account1 = create_test_account("CNY");
        let account2 = create_test_account("CNY");
        account_repo.create(&account1).await.unwrap();
        account_repo.create(&account2).await.unwrap();

        let dto = CreateTransactionDto {
            transaction_date: NaiveDate::from_ymd_opt(2026, 4, 8).unwrap(),
            description: "Transfer".to_string(),
            entries: vec![
                CreateTransactionEntryDto {
                    account_id: account1.id,
                    chart_of_account_code: "1002".to_string(),
                    category_id: None,
                    debit_amount: Some(Decimal::new(500_00, 2)),
                    credit_amount: None,
                    memo: Some("Debit entry".to_string()),
                },
                CreateTransactionEntryDto {
                    account_id: account2.id,
                    chart_of_account_code: "1002".to_string(),
                    category_id: None,
                    debit_amount: None,
                    credit_amount: Some(Decimal::new(500_00, 2)),
                    memo: Some("Credit entry".to_string()),
                },
            ],
        };

        let transaction_id = service.create_transaction(dto).await.unwrap();
        assert_ne!(transaction_id, Uuid::nil());

        let updated_account1 = account_repo.find_by_id(account1.id).await.unwrap().unwrap();
        let updated_account2 = account_repo.find_by_id(account2.id).await.unwrap().unwrap();

        assert_eq!(updated_account1.balance.amount, Decimal::new(1500_00, 2));
        assert_eq!(updated_account2.balance.amount, Decimal::new(500_00, 2));
    }

    #[tokio::test]
    async fn test_create_unbalanced_transaction_rejected() {
        let pool = setup_test_db().await;
        let account_repo = Arc::new(SqliteAccountRepository::new(pool.clone()));
        let transaction_repo = Arc::new(SqliteTransactionRepository::new(pool.clone()));
        let category_repo = Arc::new(SqliteCategoryRepository::new(pool.clone()));
        let service = TransactionService::new(transaction_repo, account_repo.clone(), category_repo);

        let account1 = create_test_account("CNY");
        let account2 = create_test_account("CNY");
        account_repo.create(&account1).await.unwrap();
        account_repo.create(&account2).await.unwrap();

        let dto = CreateTransactionDto {
            transaction_date: NaiveDate::from_ymd_opt(2026, 4, 8).unwrap(),
            description: "Unbalanced".to_string(),
            entries: vec![
                CreateTransactionEntryDto {
                    account_id: account1.id,
                    chart_of_account_code: "1002".to_string(),
                    category_id: None,
                    debit_amount: Some(Decimal::new(500_00, 2)),
                    credit_amount: None,
                    memo: None,
                },
                CreateTransactionEntryDto {
                    account_id: account2.id,
                    chart_of_account_code: "1002".to_string(),
                    category_id: None,
                    debit_amount: None,
                    credit_amount: Some(Decimal::new(400_00, 2)),
                    memo: None,
                },
            ],
        };

        let result = service.create_transaction(dto).await;
        assert!(matches!(
            result,
            Err(TransactionServiceError::ValidationError(_))
        ));
    }

    #[tokio::test]
    async fn test_get_transaction() {
        let pool = setup_test_db().await;
        let account_repo = Arc::new(SqliteAccountRepository::new(pool.clone()));
        let transaction_repo = Arc::new(SqliteTransactionRepository::new(pool.clone()));
        let category_repo = Arc::new(SqliteCategoryRepository::new(pool.clone()));
        let service = TransactionService::new(transaction_repo, account_repo.clone(), category_repo);

        let account1 = create_test_account("CNY");
        let account2 = create_test_account("CNY");
        account_repo.create(&account1).await.unwrap();
        account_repo.create(&account2).await.unwrap();

        let dto = CreateTransactionDto {
            transaction_date: NaiveDate::from_ymd_opt(2026, 4, 8).unwrap(),
            description: "Test Transaction".to_string(),
            entries: vec![
                CreateTransactionEntryDto {
                    account_id: account1.id,
                    chart_of_account_code: "1002".to_string(),
                    category_id: None,
                    debit_amount: Some(Decimal::new(100_00, 2)),
                    credit_amount: None,
                    memo: None,
                },
                CreateTransactionEntryDto {
                    account_id: account2.id,
                    chart_of_account_code: "1002".to_string(),
                    category_id: None,
                    debit_amount: None,
                    credit_amount: Some(Decimal::new(100_00, 2)),
                    memo: None,
                },
            ],
        };

        let transaction_id = service.create_transaction(dto).await.unwrap();
        let retrieved = service.get_transaction(transaction_id).await.unwrap();

        assert_eq!(retrieved.id, transaction_id);
        assert_eq!(retrieved.description, "Test Transaction");
        assert_eq!(retrieved.entries.len(), 2);
    }

    #[tokio::test]
    async fn test_list_transactions() {
        let pool = setup_test_db().await;
        let account_repo = Arc::new(SqliteAccountRepository::new(pool.clone()));
        let transaction_repo = Arc::new(SqliteTransactionRepository::new(pool.clone()));
        let category_repo = Arc::new(SqliteCategoryRepository::new(pool.clone()));
        let service = TransactionService::new(transaction_repo, account_repo.clone(), category_repo);

        let account1 = create_test_account("CNY");
        let account2 = create_test_account("CNY");
        account_repo.create(&account1).await.unwrap();
        account_repo.create(&account2).await.unwrap();

        let dto = CreateTransactionDto {
            transaction_date: NaiveDate::from_ymd_opt(2026, 4, 8).unwrap(),
            description: "Transaction 1".to_string(),
            entries: vec![
                CreateTransactionEntryDto {
                    account_id: account1.id,
                    chart_of_account_code: "1002".to_string(),
                    category_id: None,
                    debit_amount: Some(Decimal::new(100_00, 2)),
                    credit_amount: None,
                    memo: None,
                },
                CreateTransactionEntryDto {
                    account_id: account2.id,
                    chart_of_account_code: "1002".to_string(),
                    category_id: None,
                    debit_amount: None,
                    credit_amount: Some(Decimal::new(100_00, 2)),
                    memo: None,
                },
            ],
        };

        service.create_transaction(dto).await.unwrap();

        let transactions = service.list_transactions().await.unwrap();
        assert!(!transactions.is_empty());
    }

    #[tokio::test]
    async fn test_get_transactions_by_date_range() {
        let pool = setup_test_db().await;
        let account_repo = Arc::new(SqliteAccountRepository::new(pool.clone()));
        let transaction_repo = Arc::new(SqliteTransactionRepository::new(pool.clone()));
        let category_repo = Arc::new(SqliteCategoryRepository::new(pool.clone()));
        let service = TransactionService::new(transaction_repo, account_repo.clone(), category_repo);

        let account1 = create_test_account("CNY");
        let account2 = create_test_account("CNY");
        account_repo.create(&account1).await.unwrap();
        account_repo.create(&account2).await.unwrap();

        let dto = CreateTransactionDto {
            transaction_date: NaiveDate::from_ymd_opt(2026, 4, 8).unwrap(),
            description: "April Transaction".to_string(),
            entries: vec![
                CreateTransactionEntryDto {
                    account_id: account1.id,
                    chart_of_account_code: "1002".to_string(),
                    category_id: None,
                    debit_amount: Some(Decimal::new(100_00, 2)),
                    credit_amount: None,
                    memo: None,
                },
                CreateTransactionEntryDto {
                    account_id: account2.id,
                    chart_of_account_code: "1002".to_string(),
                    category_id: None,
                    debit_amount: None,
                    credit_amount: Some(Decimal::new(100_00, 2)),
                    memo: None,
                },
            ],
        };

        service.create_transaction(dto).await.unwrap();

        let transactions = service
            .get_transactions_by_date_range(
                NaiveDate::from_ymd_opt(2026, 4, 1).unwrap(),
                NaiveDate::from_ymd_opt(2026, 4, 30).unwrap(),
            )
            .await
            .unwrap();

        assert!(!transactions.is_empty());
    }
}
