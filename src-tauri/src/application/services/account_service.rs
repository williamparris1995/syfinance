use crate::application::dtos::{AccountDto, CreateAccountDto, UpdateAccountDto};
use crate::domain::aggregates::{Account, AccountError, AccountType, Ownership};
use crate::domain::repositories::{AccountRepository, CurrencyRepository};
use crate::domain::value_objects::{Money, SyncMetadata};
use rust_decimal::Decimal;
use std::sync::Arc;
use uuid::Uuid;

pub struct AccountService<R: AccountRepository, U: CurrencyRepository> {
    account_repo: Arc<R>,
    currency_repo: Arc<U>,
}

struct InvestmentTemplate {
    name: &'static str,
    chart_code: &'static str,
    icon: &'static str,
    color: &'static str,
}

const INVESTMENT_TEMPLATES: [InvestmentTemplate; 7] = [
    InvestmentTemplate {
        name: "股票账户",
        chart_code: "1101",
        icon: "TrendingUp",
        color: "#EF4444",
    },
    InvestmentTemplate {
        name: "基金账户",
        chart_code: "1101",
        icon: "BarChart3",
        color: "#3B82F6",
    },
    InvestmentTemplate {
        name: "ETF账户",
        chart_code: "1101",
        icon: "Layers",
        color: "#8B5CF6",
    },
    InvestmentTemplate {
        name: "债券账户",
        chart_code: "1501",
        icon: "Landmark",
        color: "#10B981",
    },
    InvestmentTemplate {
        name: "黄金账户",
        chart_code: "1101",
        icon: "Coins",
        color: "#F59E0B",
    },
    InvestmentTemplate {
        name: "期权账户",
        chart_code: "1101",
        icon: "GitBranch",
        color: "#F97316",
    },
    InvestmentTemplate {
        name: "其他投资",
        chart_code: "1012",
        icon: "Wallet",
        color: "#6B7280",
    },
];

impl<R: AccountRepository, U: CurrencyRepository> AccountService<R, U> {
    pub fn new(account_repo: Arc<R>, currency_repo: Arc<U>) -> Self {
        Self {
            account_repo,
            currency_repo,
        }
    }

    pub async fn create_account<E>(
        &self,
        _executor: E,
        dto: CreateAccountDto,
    ) -> Result<AccountDto, AccountServiceError> {
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
            dto.ownership,
            &currency,
            balance,
            dto.icon,
            dto.color,
            dto.chart_code,
            dto.parent_id,
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
    ) -> Result<AccountDto, AccountServiceError> {
        let mut account = self
            .account_repo
            .find_by_id(id)
            .await?
            .ok_or(AccountServiceError::AccountNotFound(id))?;

        account.change_name(&dto.name)?;

        {
            let balance = Money::new(dto.initial_balance, &account.currency_code)
                .map_err(|e| AccountServiceError::InvalidMoney(e.to_string()))?;
            account.update_initial_balance(balance)?;
        }

        if let Some(icon) = dto.icon {
            account.update_icon(icon)?;
        }
        if let Some(color) = dto.color {
            account.update_color(color)?;
        }
        if let Some(account_number) = dto.account_number {
            account.update_account_number(Some(account_number))?;
        }
        if let Some(institution) = dto.institution {
            account.update_institution(Some(institution))?;
        }
        if let Some(credit_limit) = dto.credit_limit {
            account.update_credit_limit(Some(credit_limit))?;
        }
        if let Some(billing_day) = dto.billing_day {
            account.update_billing_day(Some(billing_day))?;
        }
        if let Some(payment_due_day) = dto.payment_due_day {
            account.update_payment_due_day(Some(payment_due_day))?;
        }
        if let Some(interest_rate) = dto.interest_rate {
            account.update_interest_rate(Some(interest_rate))?;
        }
        if let Some(chart_code) = dto.chart_code {
            account.update_chart_code(Some(chart_code))?;
        }
        if let Some(parent_id) = dto.parent_id {
            account.update_parent_id(Some(parent_id))?;
        }
        account.low_balance_threshold = dto.low_balance_threshold;

        self.account_repo.update(&account).await?;

        Ok(AccountDto::from(account))
    }

    pub async fn delete_account<E>(
        &self,
        _executor: E,
        id: Uuid,
    ) -> Result<(), AccountServiceError> {
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

    pub async fn list_accounts_by_ownership(
        &self,
        ownership: Ownership,
    ) -> Result<Vec<AccountDto>, AccountServiceError> {
        let accounts = self.account_repo.find_by_ownership(&ownership).await?;
        Ok(accounts.into_iter().map(AccountDto::from).collect())
    }

    pub async fn list_accounts_with_balances(
        &self,
    ) -> Result<Vec<AccountDto>, AccountServiceError> {
        let accounts = self
            .account_repo
            .find_all()
            .await
            .map_err(AccountServiceError::DatabaseError)?;

        let balance_changes = self
            .account_repo
            .compute_balances_for_all_accounts()
            .await
            .map_err(AccountServiceError::DatabaseError)?;

        let dtos: Vec<AccountDto> = accounts
            .into_iter()
            .map(|account| {
                let net_change = balance_changes
                    .get(&account.id)
                    .copied()
                    .unwrap_or(Decimal::ZERO);
                let current = account.initial_balance.amount + net_change;
                AccountDto {
                    initial_balance: account.initial_balance.amount,
                    current_balance: current,
                    ..account.into()
                }
            })
            .collect();

        Ok(dtos)
    }

    pub async fn get_account_balance(&self, id: Uuid) -> Result<Money, AccountServiceError> {
        let account = self
            .account_repo
            .find_by_id(id)
            .await?
            .ok_or(AccountServiceError::AccountNotFound(id))?;

        let net_change = self
            .account_repo
            .compute_balance_for_account(id)
            .await
            .map_err(AccountServiceError::DatabaseError)?;

        let current = account.initial_balance.amount + net_change;
        Ok(Money::new(current, &account.initial_balance.currency_code)
            .map_err(|e| AccountServiceError::InvalidMoney(e.to_string()))?)
    }

    pub async fn create_preset_investment_accounts<E>(
        &self,
        _executor: E,
        currency_code: &str,
    ) -> Result<Vec<AccountDto>, AccountServiceError> {
        let currency = self
            .currency_repo
            .find_by_code(currency_code)
            .await?
            .ok_or_else(|| AccountServiceError::CurrencyNotFound(currency_code.to_string()))?;

        let mut results = Vec::new();

        for template in &INVESTMENT_TEMPLATES {
            let balance = Money::new(Decimal::ZERO, currency_code)
                .map_err(|e| AccountServiceError::InvalidMoney(e.to_string()))?;

            match Account::new(
                Uuid::new_v4(),
                template.name,
                AccountType::Investment,
                Ownership::Own,
                &currency,
                balance,
                template.icon,
                template.color,
                Some(template.chart_code.to_string()),
                None,
                SyncMetadata::new(Uuid::new_v4()),
            ) {
                Ok(account) => {
                    if self.account_repo.create(&account).await.is_ok() {
                        results.push(AccountDto::from(account));
                    }
                }
                Err(_) => continue,
            }
        }

        Ok(results)
    }
}

#[derive(Debug, thiserror::Error)]
pub enum AccountServiceError {
    #[error("Account not found: {0}")]
    AccountNotFound(Uuid),

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
    use crate::domain::aggregates::AccountType;
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

        async fn find_by_ownership(&self, ownership: &Ownership) -> sqlx::Result<Vec<Account>> {
            Ok(self
                .accounts
                .lock()
                .unwrap()
                .values()
                .filter(|a| a.ownership == *ownership)
                .cloned()
                .collect())
        }

        async fn update(&self, account: &Account) -> sqlx::Result<bool> {
            let mut accounts = self.accounts.lock().unwrap();
            if let std::collections::hash_map::Entry::Occupied(mut e) = accounts.entry(account.id) {
                e.insert(account.clone());
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

        async fn get_changes_since(
            &self,
            _timestamp: chrono::DateTime<chrono::Utc>,
        ) -> sqlx::Result<Vec<Account>> {
            Ok(Vec::new())
        }

        async fn mark_as_synced(&self, _id: Uuid) -> sqlx::Result<bool> {
            Ok(true)
        }

        async fn compute_balances_for_all_accounts(
            &self,
        ) -> Result<HashMap<Uuid, Decimal>, sqlx::Error> {
            Ok(HashMap::new())
        }

        async fn compute_balance_for_account(&self, _id: Uuid) -> Result<Decimal, sqlx::Error> {
            Ok(Decimal::ZERO)
        }

        async fn get_balance_history(
            &self,
            _account_id: Uuid,
            _days: i32,
        ) -> Result<Vec<(String, Decimal)>, sqlx::Error> {
            Ok(Vec::new())
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
                Currency::new(
                    uuid::Uuid::new_v4().to_string(),
                    "CNY",
                    "CNY",
                    "Chinese Yuan",
                    Decimal::ONE,
                )
                .unwrap(),
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

        async fn find_active(&self) -> sqlx::Result<Vec<Currency>> {
            Ok(vec![])
        }

        async fn list_all(&self) -> sqlx::Result<Vec<Currency>> {
            Ok(self.currencies.lock().unwrap().values().cloned().collect())
        }

        async fn save(&self, _currency: &Currency) -> sqlx::Result<()> {
            Ok(())
        }

        async fn update_rate(&self, code: &str, exchange_rate: Decimal) -> sqlx::Result<bool> {
            let mut currencies = self.currencies.lock().unwrap();
            if let Some(currency) = currencies.get_mut(code) {
                *currency = Currency::new(
                    currency.id.clone(),
                    &currency.code,
                    &currency.code,
                    &currency.symbol,
                    exchange_rate,
                )
                .unwrap();
                Ok(true)
            } else {
                Ok(false)
            }
        }

        async fn delete(&self, _code: &str) -> sqlx::Result<bool> {
            Ok(false)
        }
    }

    #[tokio::test]
    async fn test_create_account_success() {
        let account_repo = Arc::new(MockAccountRepository::new());
        let currency_repo = Arc::new(MockCurrencyRepository::new());

        let service = AccountService::new(account_repo.clone(), currency_repo);

        let dto = CreateAccountDto {
            name: "Checking Account".to_string(),
            account_type: AccountType::Bank,
            ownership: Ownership::Own,
            currency_code: "CNY".to_string(),
            initial_balance: Decimal::new(10000, 2),
            icon: "💰".to_string(),
            color: "#10B981".to_string(),
            chart_code: None,
            parent_id: None,
        };

        let result = service.create_account((), dto).await;

        assert!(result.is_ok());
        let account_dto = result.unwrap();
        assert_eq!(account_dto.name, "Checking Account");
        assert_eq!(account_dto.initial_balance, Decimal::new(10000, 2));
    }

    #[tokio::test]
    async fn test_create_account_invalid_currency() {
        let account_repo = Arc::new(MockAccountRepository::new());
        let currency_repo = Arc::new(MockCurrencyRepository::new());

        let service = AccountService::new(account_repo, currency_repo);

        let dto = CreateAccountDto {
            name: "Invalid Account".to_string(),
            account_type: AccountType::Bank,
            ownership: Ownership::Own,
            currency_code: "USD".to_string(),
            initial_balance: Decimal::new(10000, 2),
            icon: "💰".to_string(),
            color: "#10B981".to_string(),
            chart_code: None,
            parent_id: None,
        };

        let result = service.create_account((), dto).await;

        assert!(result.is_err());
        assert!(matches!(
            result.unwrap_err(),
            AccountServiceError::CurrencyNotFound(_)
        ));
    }

    #[tokio::test]
    async fn test_update_account_name() {
        let account_repo = Arc::new(MockAccountRepository::new());
        let currency_repo = Arc::new(MockCurrencyRepository::new());

        let service = AccountService::new(account_repo.clone(), currency_repo);

        let create_dto = CreateAccountDto {
            name: "Old Name".to_string(),
            account_type: AccountType::Bank,
            ownership: Ownership::Own,
            currency_code: "CNY".to_string(),
            initial_balance: Decimal::new(10000, 2),
            icon: "💰".to_string(),
            color: "#10B981".to_string(),
            chart_code: None,
            parent_id: None,
        };

        let created = service.create_account((), create_dto).await.unwrap();

        let update_dto = UpdateAccountDto {
            name: "New Name".to_string(),
            initial_balance: Decimal::new(10000, 2),
            icon: None,
            color: None,
            currency_code: None,
            account_number: None,
            institution: None,
            credit_limit: None,
            billing_day: None,
            payment_due_day: None,
            interest_rate: None,
            chart_code: None,
            parent_id: None,
            low_balance_threshold: None,
        };

        let result = service.update_account((), created.id, update_dto).await;

        assert!(result.is_ok());
        let updated = result.unwrap();
        assert_eq!(updated.name, "New Name");
    }

    #[tokio::test]
    async fn test_update_account_all_fields() {
        let account_repo = Arc::new(MockAccountRepository::new());
        let currency_repo = Arc::new(MockCurrencyRepository::new());
        let service = AccountService::new(account_repo.clone(), currency_repo);

        let create_dto = CreateAccountDto {
            name: "Visa Card".to_string(),
            account_type: AccountType::CreditCard,
            ownership: Ownership::Own,
            currency_code: "CNY".to_string(),
            initial_balance: Decimal::new(-100, 2),
            icon: "💳".to_string(),
            color: "#10B981".to_string(),
            chart_code: None,
            parent_id: None,
        };

        let created = service.create_account((), create_dto).await.unwrap();

        let update_dto = UpdateAccountDto {
            name: "Visa Platinum".to_string(),
            initial_balance: Decimal::new(-500, 2),
            icon: Some("💰".to_string()),
            color: Some("#EF4444".to_string()),
            currency_code: None,
            account_number: Some("****1234".to_string()),
            institution: Some("ICBC".to_string()),
            credit_limit: Some(Decimal::new(50000, 2)),
            billing_day: Some(5),
            payment_due_day: Some(25),
            interest_rate: None,
            chart_code: None,
            parent_id: None,
            low_balance_threshold: None,
        };

        let result = service.update_account((), created.id, update_dto).await;

        assert!(result.is_ok());
        let updated = result.unwrap();
        assert_eq!(updated.name, "Visa Platinum");
        assert_eq!(updated.initial_balance, Decimal::new(-500, 2));
        assert_eq!(updated.icon, "💰");
        assert_eq!(updated.color, "#EF4444");
        assert_eq!(updated.account_number, Some("****1234".to_string()));
        assert_eq!(updated.institution, Some("ICBC".to_string()));
        assert_eq!(updated.credit_limit, Some(Decimal::new(50000, 2)));
        assert_eq!(updated.billing_day, Some(5));
        assert_eq!(updated.payment_due_day, Some(25));
    }

    #[tokio::test]
    async fn test_delete_account() {
        let account_repo = Arc::new(MockAccountRepository::new());
        let currency_repo = Arc::new(MockCurrencyRepository::new());

        let service = AccountService::new(account_repo.clone(), currency_repo);

        let create_dto = CreateAccountDto {
            name: "To Delete".to_string(),
            account_type: AccountType::Bank,
            ownership: Ownership::Own,
            currency_code: "CNY".to_string(),
            initial_balance: Decimal::new(10000, 2),
            icon: "💰".to_string(),
            color: "#10B981".to_string(),
            chart_code: None,
            parent_id: None,
        };

        let created = service.create_account((), create_dto).await.unwrap();

        let result = service.delete_account((), created.id).await;

        assert!(result.is_ok());

        let account = account_repo.find_by_id(created.id).await.unwrap().unwrap();
        assert!(account.sync_metadata.is_deleted());
    }

    #[tokio::test]
    async fn test_get_account_balance() {
        let account_repo = Arc::new(MockAccountRepository::new());
        let currency_repo = Arc::new(MockCurrencyRepository::new());

        let service = AccountService::new(account_repo, currency_repo);

        let create_dto = CreateAccountDto {
            name: "Balance Test".to_string(),
            account_type: AccountType::Bank,
            ownership: Ownership::Own,
            currency_code: "CNY".to_string(),
            initial_balance: Decimal::new(50000, 2),
            icon: "💰".to_string(),
            color: "#10B981".to_string(),
            chart_code: None,
            parent_id: None,
        };

        let created = service.create_account((), create_dto).await.unwrap();

        let balance = service.get_account_balance(created.id).await.unwrap();

        assert_eq!(balance.amount, Decimal::new(50000, 2));
        assert_eq!(balance.currency_code, "CNY");
    }

    #[tokio::test]
    async fn test_create_preset_investment_accounts() {
        let account_repo = Arc::new(MockAccountRepository::new());
        let currency_repo = Arc::new(MockCurrencyRepository::new());

        let service = AccountService::new(account_repo.clone(), currency_repo);

        let result = service.create_preset_investment_accounts((), "CNY").await;

        assert!(result.is_ok());
        let accounts = result.unwrap();
        assert_eq!(accounts.len(), 7);

        let names: Vec<&str> = accounts.iter().map(|a| a.name.as_str()).collect();
        assert!(names.contains(&"股票账户"));
        assert!(names.contains(&"基金账户"));
        assert!(names.contains(&"ETF账户"));
        assert!(names.contains(&"债券账户"));
        assert!(names.contains(&"黄金账户"));
        assert!(names.contains(&"期权账户"));
        assert!(names.contains(&"其他投资"));

        for account in &accounts {
            assert_eq!(account.account_type, AccountType::Investment);
            assert_eq!(account.ownership, Ownership::Own);
            assert_eq!(account.currency_code, "CNY");
        }
    }
}
