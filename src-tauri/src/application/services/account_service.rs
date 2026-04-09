use crate::application::dtos::{AccountDto, CreateAccountDto, UpdateAccountDto};
use crate::domain::aggregates::{Account, AccountError};
use crate::domain::repositories::{
    AccountRepository, ChartOfAccountsRepository, CurrencyRepository,
};
use crate::domain::value_objects::{Money, SyncMetadata};
use std::sync::Arc;
use uuid::Uuid;

pub struct AccountService<R: AccountRepository, C: ChartOfAccountsRepository, U: CurrencyRepository>
{
    account_repo: Arc<R>,
    chart_of_accounts_repo: Arc<C>,
    currency_repo: Arc<U>,
}

impl<R: AccountRepository, C: ChartOfAccountsRepository, U: CurrencyRepository>
    AccountService<R, C, U>
{
    pub fn new(
        account_repo: Arc<R>,
        chart_of_accounts_repo: Arc<C>,
        currency_repo: Arc<U>,
    ) -> Self {
        Self {
            account_repo,
            chart_of_accounts_repo,
            currency_repo,
        }
    }

    pub async fn create_account<E>(
        &self,
        _executor: E,
        dto: CreateAccountDto,
    ) -> Result<AccountDto, AccountServiceError>
    {
        let chart_of_accounts = self
            .chart_of_accounts_repo
            .find_by_code(&dto.chart_of_account_code)
            .await?
            .ok_or_else(|| {
                AccountServiceError::ChartOfAccountNotFound(dto.chart_of_account_code.clone())
            })?;

        let currency = self
            .currency_repo
            .find_by_code(&dto.currency_code)
            .await?
            .ok_or_else(|| AccountServiceError::CurrencyNotFound(dto.currency_code.clone()))?;

        let balance = Money::new(dto.initial_balance, &dto.currency_code)
            .map_err(|e| AccountServiceError::InvalidMoney(e.to_string()))?;

        let account = Account::new(
            Uuid::new_v4(),
            dto.name,
            dto.account_type,
            &chart_of_accounts,
            &currency,
            balance,
            SyncMetadata::new(Uuid::new_v4()),
        )?;

        self.account_repo.create(&account).await?;

        Ok(AccountDto::from(account))
    }

    pub async fn update_account<E>(
        &self,
        _executor: E,
        id: Uuid,
        dto: UpdateAccountDto,
    ) -> Result<AccountDto, AccountServiceError>
    {
        let mut account = self
            .account_repo
            .find_by_id(id)
            .await?
            .ok_or(AccountServiceError::AccountNotFound(id))?;

        if let Some(name) = dto.name {
            account.change_name(name)?;
        }

        if let Some(balance_amount) = dto.balance {
            let balance = Money::new(balance_amount, &account.currency_code)
                .map_err(|e| AccountServiceError::InvalidMoney(e.to_string()))?;
            account.update_balance(balance)?;
        }

        self.account_repo.update(&account).await?;

        Ok(AccountDto::from(account))
    }

    pub async fn delete_account<E>(
        &self,
        _executor: E,
        id: Uuid,
    ) -> Result<(), AccountServiceError>
    {
        let mut account = self
            .account_repo
            .find_by_id(id)
            .await?
            .ok_or(AccountServiceError::AccountNotFound(id))?;

        account.soft_delete()?;

        self.account_repo.update(&account).await?;

        Ok(())
    }

    pub async fn get_account(&self, id: Uuid) -> Result<AccountDto, AccountServiceError> {
        let account = self
            .account_repo
            .find_by_id(id)
            .await?
            .ok_or(AccountServiceError::AccountNotFound(id))?;

        Ok(AccountDto::from(account))
    }

    pub async fn list_accounts(&self) -> Result<Vec<AccountDto>, AccountServiceError> {
        let accounts = self.account_repo.find_all().await?;
        Ok(accounts.into_iter().map(AccountDto::from).collect())
    }

    pub async fn get_account_balance(&self, id: Uuid) -> Result<Money, AccountServiceError> {
        let account = self
            .account_repo
            .find_by_id(id)
            .await?
            .ok_or(AccountServiceError::AccountNotFound(id))?;

        Ok(account.balance)
    }
}

#[derive(Debug, thiserror::Error)]
pub enum AccountServiceError {
    #[error("Account not found: {0}")]
    AccountNotFound(Uuid),

    #[error("Chart of accounts not found: {0}")]
    ChartOfAccountNotFound(String),

    #[error("Currency not found: {0}")]
    CurrencyNotFound(String),

    #[error("Invalid money: {0}")]
    InvalidMoney(String),

    #[error("Account domain error: {0}")]
    AccountError(#[from] AccountError),

    #[error("Database error: {0}")]
    DatabaseError(#[from] sqlx::Error),
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::aggregates::{AccountType, ChartOfAccounts, ChartOfAccountsType};
    use crate::domain::value_objects::Currency;
    use rust_decimal::Decimal;
    use std::collections::HashMap;
    use std::sync::Mutex;

    struct MockAccountRepository {
        accounts: Mutex<HashMap<Uuid, Account>>,
    }

    impl MockAccountRepository {
        fn new() -> Self {
            Self {
                accounts: Mutex::new(HashMap::new()),
            }
        }
    }

    impl AccountRepository for MockAccountRepository {
        async fn create(&self, account: &Account) -> sqlx::Result<()> {
            self.accounts
                .lock()
                .unwrap()
                .insert(account.id, account.clone());
            Ok(())
        }

        async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<Account>> {
            Ok(self.accounts.lock().unwrap().get(&id).cloned())
        }

        async fn find_all(&self) -> sqlx::Result<Vec<Account>> {
            Ok(self.accounts.lock().unwrap().values().cloned().collect())
        }

        async fn find_by_type(&self, account_type: AccountType) -> sqlx::Result<Vec<Account>> {
            Ok(self
                .accounts
                .lock()
                .unwrap()
                .values()
                .filter(|a| a.account_type == account_type)
                .cloned()
                .collect())
        }

        async fn update(&self, account: &Account) -> sqlx::Result<bool> {
            let mut accounts = self.accounts.lock().unwrap();
            if accounts.contains_key(&account.id) {
                accounts.insert(account.id, account.clone());
                Ok(true)
            } else {
                Ok(false)
            }
        }

        async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool> {
            let mut accounts = self.accounts.lock().unwrap();
            if let Some(account) = accounts.get_mut(&id) {
                let mut acc = account.clone();
                acc.soft_delete().unwrap();
                accounts.insert(id, acc);
                Ok(true)
            } else {
                Ok(false)
            }
        }

        async fn find_all_including_deleted(&self) -> sqlx::Result<Vec<Account>> {
            Ok(self.accounts.lock().unwrap().values().cloned().collect())
        }

        async fn get_changes_since(&self, _timestamp: chrono::DateTime<chrono::Utc>) -> sqlx::Result<Vec<Account>> {
            Ok(Vec::new())
        }

        async fn mark_as_synced(&self, _id: Uuid) -> sqlx::Result<bool> {
            Ok(true)
        }
    }

    struct MockChartOfAccountsRepository {
        charts: Mutex<HashMap<String, ChartOfAccounts>>,
    }

    impl MockChartOfAccountsRepository {
        fn new() -> Self {
            let mut charts = HashMap::new();
            charts.insert(
                "1002".to_string(),
                ChartOfAccounts::new(
                    "coa-1002".to_string(),
                    "1002".to_string(),
                    "Bank".to_string(),
                    2,
                    ChartOfAccountsType::Asset,
                    Some("1000".to_string()),
                    crate::domain::aggregates::chart_of_accounts::BalanceDirection::Debit,
                )
                .unwrap(),
            );
            Self {
                charts: Mutex::new(charts),
            }
        }
    }

    impl ChartOfAccountsRepository for MockChartOfAccountsRepository {
        async fn create(&self, account: &ChartOfAccounts) -> sqlx::Result<()> {
            self.charts
                .lock()
                .unwrap()
                .insert(account.code.clone(), account.clone());
            Ok(())
        }

        async fn update(&self, account: &ChartOfAccounts) -> sqlx::Result<bool> {
            let mut charts = self.charts.lock().unwrap();
            if charts.contains_key(&account.code) {
                charts.insert(account.code.clone(), account.clone());
                Ok(true)
            } else {
                Ok(false)
            }
        }

        async fn find_by_code(&self, code: &str) -> sqlx::Result<Option<ChartOfAccounts>> {
            Ok(self.charts.lock().unwrap().get(code).cloned())
        }

        async fn list_by_level(&self, level: i32) -> sqlx::Result<Vec<ChartOfAccounts>> {
            Ok(self
                .charts
                .lock()
                .unwrap()
                .values()
                .filter(|c| c.level == level)
                .cloned()
                .collect())
        }

        async fn list_by_type(
            &self,
            account_type: ChartOfAccountsType,
        ) -> sqlx::Result<Vec<ChartOfAccounts>> {
            Ok(self
                .charts
                .lock()
                .unwrap()
                .values()
                .filter(|c| c.account_type == account_type)
                .cloned()
                .collect())
        }

        async fn get_children(&self, parent_code: &str) -> sqlx::Result<Vec<ChartOfAccounts>> {
            Ok(self
                .charts
                .lock()
                .unwrap()
                .values()
                .filter(|c| c.parent_code.as_deref() == Some(parent_code))
                .cloned()
                .collect())
        }

        async fn list_all(&self) -> sqlx::Result<Vec<ChartOfAccounts>> {
            Ok(self.charts.lock().unwrap().values().cloned().collect())
        }
    }

    struct MockCurrencyRepository {
        currencies: Mutex<HashMap<String, Currency>>,
    }

    impl MockCurrencyRepository {
        fn new() -> Self {
            let mut currencies = HashMap::new();
            currencies.insert(
                "CNY".to_string(),
                Currency::new("CNY", "Chinese Yuan", Decimal::ONE).unwrap(),
            );
            Self {
                currencies: Mutex::new(currencies),
            }
        }
    }

    impl CurrencyRepository for MockCurrencyRepository {
        async fn create(&self, currency: &Currency) -> sqlx::Result<()> {
            self.currencies
                .lock()
                .unwrap()
                .insert(currency.code.clone(), currency.clone());
            Ok(())
        }

        async fn find_by_code(&self, code: &str) -> sqlx::Result<Option<Currency>> {
            Ok(self.currencies.lock().unwrap().get(code).cloned())
        }

        async fn list_all(&self) -> sqlx::Result<Vec<Currency>> {
            Ok(self.currencies.lock().unwrap().values().cloned().collect())
        }

        async fn update_rate(&self, code: &str, exchange_rate: Decimal) -> sqlx::Result<bool> {
            let mut currencies = self.currencies.lock().unwrap();
            if let Some(currency) = currencies.get_mut(code) {
                *currency =
                    Currency::new(&currency.code, &currency.symbol, exchange_rate).unwrap();
                Ok(true)
            } else {
                Ok(false)
            }
        }
    }

    #[tokio::test]
    async fn test_create_account_success() {
        let account_repo = Arc::new(MockAccountRepository::new());
        let chart_repo = Arc::new(MockChartOfAccountsRepository::new());
        let currency_repo = Arc::new(MockCurrencyRepository::new());

        let service = AccountService::new(account_repo.clone(), chart_repo, currency_repo);

        let dto = CreateAccountDto {
            name: "Checking Account".to_string(),
            account_type: AccountType::Bank,
            chart_of_account_code: "1002".to_string(),
            currency_code: "CNY".to_string(),
            initial_balance: Decimal::new(10000, 2),
        };

        let result = service.create_account((), dto).await;

        assert!(result.is_ok());
        let account_dto = result.unwrap();
        assert_eq!(account_dto.name, "Checking Account");
        assert_eq!(account_dto.balance, Decimal::new(10000, 2));
    }

    #[tokio::test]
    async fn test_create_account_invalid_chart_of_accounts() {
        let account_repo = Arc::new(MockAccountRepository::new());
        let chart_repo = Arc::new(MockChartOfAccountsRepository::new());
        let currency_repo = Arc::new(MockCurrencyRepository::new());

        let service = AccountService::new(account_repo, chart_repo, currency_repo);

        let dto = CreateAccountDto {
            name: "Invalid Account".to_string(),
            account_type: AccountType::Bank,
            chart_of_account_code: "9999".to_string(),
            currency_code: "CNY".to_string(),
            initial_balance: Decimal::new(10000, 2),
        };

        let result = service.create_account((), dto).await;

        assert!(result.is_err());
        assert!(matches!(
            result.unwrap_err(),
            AccountServiceError::ChartOfAccountNotFound(_)
        ));
    }

    #[tokio::test]
    async fn test_update_account_name() {
        let account_repo = Arc::new(MockAccountRepository::new());
        let chart_repo = Arc::new(MockChartOfAccountsRepository::new());
        let currency_repo = Arc::new(MockCurrencyRepository::new());

        let service = AccountService::new(account_repo.clone(), chart_repo, currency_repo);

        let create_dto = CreateAccountDto {
            name: "Old Name".to_string(),
            account_type: AccountType::Bank,
            chart_of_account_code: "1002".to_string(),
            currency_code: "CNY".to_string(),
            initial_balance: Decimal::new(10000, 2),
        };

        let created = service
            .create_account((), create_dto)
            .await
            .unwrap();

        let update_dto = UpdateAccountDto {
            name: Some("New Name".to_string()),
            balance: None,
        };

        let result = service
            .update_account((), created.id, update_dto)
            .await;

        assert!(result.is_ok());
        let updated = result.unwrap();
        assert_eq!(updated.name, "New Name");
    }

    #[tokio::test]
    async fn test_delete_account() {
        let account_repo = Arc::new(MockAccountRepository::new());
        let chart_repo = Arc::new(MockChartOfAccountsRepository::new());
        let currency_repo = Arc::new(MockCurrencyRepository::new());

        let service = AccountService::new(account_repo.clone(), chart_repo, currency_repo);

        let create_dto = CreateAccountDto {
            name: "To Delete".to_string(),
            account_type: AccountType::Bank,
            chart_of_account_code: "1002".to_string(),
            currency_code: "CNY".to_string(),
            initial_balance: Decimal::new(10000, 2),
        };

        let created = service
            .create_account((), create_dto)
            .await
            .unwrap();

        let result = service.delete_account((), created.id).await;

        assert!(result.is_ok());

        let account = account_repo.find_by_id(created.id).await.unwrap().unwrap();
        assert!(account.sync_metadata.is_deleted());
    }

    #[tokio::test]
    async fn test_get_account_balance() {
        let account_repo = Arc::new(MockAccountRepository::new());
        let chart_repo = Arc::new(MockChartOfAccountsRepository::new());
        let currency_repo = Arc::new(MockCurrencyRepository::new());

        let service = AccountService::new(account_repo, chart_repo, currency_repo);

        let create_dto = CreateAccountDto {
            name: "Balance Test".to_string(),
            account_type: AccountType::Bank,
            chart_of_account_code: "1002".to_string(),
            currency_code: "CNY".to_string(),
            initial_balance: Decimal::new(50000, 2),
        };

        let created = service
            .create_account((), create_dto)
            .await
            .unwrap();

        let balance = service.get_account_balance(created.id).await.unwrap();

        assert_eq!(balance.amount, Decimal::new(50000, 2));
        assert_eq!(balance.currency_code, "CNY");
    }
}
