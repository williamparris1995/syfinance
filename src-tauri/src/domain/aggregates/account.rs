use crate::domain::{
    aggregates::chart_of_accounts::{
        AccountType as ChartOfAccountsType, ChartOfAccounts,
    },
    value_objects::{Currency, Money, SyncMetadata},
};
use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use std::{error::Error, fmt};
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AccountType {
    Cash,
    Bank,
    CreditCard,
    Investment,
    Loan,
    Other,
}

impl fmt::Display for AccountType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Cash => write!(f, "cash"),
            Self::Bank => write!(f, "bank"),
            Self::CreditCard => write!(f, "credit_card"),
            Self::Investment => write!(f, "investment"),
            Self::Loan => write!(f, "loan"),
            Self::Other => write!(f, "other"),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AccountEvent {
    AccountCreated {
        account_id: Uuid,
        account_type: AccountType,
        chart_of_account_code: String,
    },
    BalanceUpdated {
        account_id: Uuid,
        previous_balance: Money,
        new_balance: Money,
    },
    AccountDeleted {
        account_id: Uuid,
        deleted_at: DateTime<Utc>,
    },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AccountError {
    EmptyName,
    ChartOfAccountDeleted(String),
    CurrencyMismatch { expected: String, actual: String },
    InvalidChartOfAccountCode {
        account_type: AccountType,
        chart_of_account_code: String,
    },
    InvalidChartOfAccountType {
        account_type: AccountType,
        chart_of_account_type: ChartOfAccountsType,
    },
    NegativeBalanceNotAllowed {
        account_type: AccountType,
        balance: Decimal,
    },
    DeletedAccount,
}

impl fmt::Display for AccountError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyName => write!(f, "account name cannot be empty"),
            Self::ChartOfAccountDeleted(code) => {
                write!(f, "chart of accounts entry is deleted: {code}")
            }
            Self::CurrencyMismatch { expected, actual } => {
                write!(f, "currency mismatch: expected {expected}, got {actual}")
            }
            Self::InvalidChartOfAccountCode {
                account_type,
                chart_of_account_code,
            } => write!(
                f,
                "chart of accounts code {chart_of_account_code} is invalid for {account_type} accounts"
            ),
            Self::InvalidChartOfAccountType {
                account_type,
                chart_of_account_type,
            } => write!(
                f,
                "chart of accounts type {chart_of_account_type} is invalid for {account_type} accounts"
            ),
            Self::NegativeBalanceNotAllowed {
                account_type,
                balance,
            } => write!(
                f,
                "{account_type} accounts cannot have a negative balance: {balance}"
            ),
            Self::DeletedAccount => write!(f, "cannot mutate a deleted account"),
        }
    }
}

impl Error for AccountError {}

#[derive(Debug, Clone)]
pub struct Account {
    pub id: Uuid,
    pub name: String,
    pub account_type: AccountType,
    pub chart_of_account_code: String,
    pub currency_code: String,
    pub balance: Money,
    pub sync_metadata: SyncMetadata,
    pub(crate) pending_events: Vec<AccountEvent>,
}

impl Account {
    pub fn new(
        id: Uuid,
        name: impl Into<String>,
        account_type: AccountType,
        chart_of_accounts: &ChartOfAccounts,
        currency: &Currency,
        balance: Money,
        sync_metadata: SyncMetadata,
    ) -> Result<Self, AccountError> {
        let name = name.into().trim().to_string();

        if name.is_empty() {
            return Err(AccountError::EmptyName);
        }

        validate_chart_of_accounts(&account_type, chart_of_accounts)?;
        validate_balance(&account_type, &currency.code, &balance)?;

        let mut account = Self {
            id,
            name,
            account_type: account_type.clone(),
            chart_of_account_code: chart_of_accounts.code.clone(),
            currency_code: currency.code.clone(),
            balance,
            sync_metadata,
            pending_events: Vec::new(),
        };

        account.pending_events.push(AccountEvent::AccountCreated {
            account_id: account.id,
            account_type,
            chart_of_account_code: account.chart_of_account_code.clone(),
        });

        Ok(account)
    }

    pub fn update_balance(&mut self, balance: Money) -> Result<(), AccountError> {
        self.ensure_not_deleted()?;
        validate_balance(&self.account_type, &self.currency_code, &balance)?;

        let previous_balance = self.balance.clone();
        self.balance = balance.clone();
        self.touch();
        self.pending_events.push(AccountEvent::BalanceUpdated {
            account_id: self.id,
            previous_balance,
            new_balance: balance,
        });

        Ok(())
    }

    pub fn change_name(&mut self, name: impl Into<String>) -> Result<(), AccountError> {
        self.ensure_not_deleted()?;

        let name = name.into().trim().to_string();
        if name.is_empty() {
            return Err(AccountError::EmptyName);
        }

        self.name = name;
        self.touch();
        Ok(())
    }

    pub fn soft_delete(&mut self) -> Result<(), AccountError> {
        self.ensure_not_deleted()?;
        self.sync_metadata.mark_deleted();

        if let Some(deleted_at) = self.sync_metadata.deleted_at.clone() {
            self.pending_events.push(AccountEvent::AccountDeleted {
                account_id: self.id,
                deleted_at,
            });
        }

        Ok(())
    }

    pub fn pull_events(&mut self) -> Vec<AccountEvent> {
        std::mem::take(&mut self.pending_events)
    }

    fn ensure_not_deleted(&self) -> Result<(), AccountError> {
        if self.sync_metadata.is_deleted() {
            Err(AccountError::DeletedAccount)
        } else {
            Ok(())
        }
    }

    fn touch(&mut self) {
        self.sync_metadata.updated_at = Utc::now();
        self.sync_metadata.synced_at = None;
    }
}

fn validate_balance(
    account_type: &AccountType,
    currency_code: &str,
    balance: &Money,
) -> Result<(), AccountError> {
    if balance.currency_code != currency_code {
        return Err(AccountError::CurrencyMismatch {
            expected: currency_code.to_string(),
            actual: balance.currency_code.clone(),
        });
    }

    if matches!(
        account_type,
        AccountType::Cash | AccountType::Bank | AccountType::Investment
    ) && balance.amount < Decimal::ZERO
    {
        return Err(AccountError::NegativeBalanceNotAllowed {
            account_type: account_type.clone(),
            balance: balance.amount,
        });
    }

    Ok(())
}

fn validate_chart_of_accounts(
    account_type: &AccountType,
    chart_of_accounts: &ChartOfAccounts,
) -> Result<(), AccountError> {
    if chart_of_accounts.is_deleted() {
        return Err(AccountError::ChartOfAccountDeleted(
            chart_of_accounts.code.clone(),
        ));
    }

    let expected_chart_type = match account_type {
        AccountType::Cash | AccountType::Bank | AccountType::Investment => {
            Some(ChartOfAccountsType::Asset)
        }
        AccountType::CreditCard | AccountType::Loan => Some(ChartOfAccountsType::Liability),
        AccountType::Other => None,
    };

    if let Some(expected_chart_type) = expected_chart_type {
        if chart_of_accounts.account_type != expected_chart_type {
            return Err(AccountError::InvalidChartOfAccountType {
                account_type: account_type.clone(),
                chart_of_account_type: chart_of_accounts.account_type.clone(),
            });
        }
    }

    let allowed_codes = match account_type {
        AccountType::Cash => Some(&["1001", "1002", "1012"][..]),
        AccountType::Bank => Some(&["1002"][..]),
        AccountType::CreditCard => Some(&["2201"][..]),
        AccountType::Loan => Some(&["2001"][..]),
        AccountType::Investment | AccountType::Other => None,
    };

    if let Some(allowed_codes) = allowed_codes {
        if !allowed_codes
            .iter()
            .any(|code| *code == chart_of_accounts.code.as_str())
        {
            return Err(AccountError::InvalidChartOfAccountCode {
                account_type: account_type.clone(),
                chart_of_account_code: chart_of_accounts.code.clone(),
            });
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::aggregates::chart_of_accounts::BalanceDirection;

    fn chart_of_accounts(
        code: &str,
        account_type: ChartOfAccountsType,
    ) -> ChartOfAccounts {
        let level = if code.len() == 4 { 2 } else { 3 };
        ChartOfAccounts::new(
            format!("coa-{code}"),
            code.to_string(),
            format!("Chart {code}"),
            level,
            account_type,
            Some("1000".to_string()),
            BalanceDirection::Debit,
        )
        .unwrap()
    }

    fn currency(code: &str) -> Currency {
        Currency::new(code, code, Decimal::ONE).unwrap()
    }

    fn money(amount: i64, currency_code: &str) -> Money {
        Money::new(Decimal::new(amount, 2), currency_code).unwrap()
    }

    fn metadata() -> SyncMetadata {
        SyncMetadata::new(Uuid::new_v4())
    }

    mod account {
        use super::*;

        mod business_rules {
            use super::*;

            #[test]
            fn cash_account_with_negative_balance_fails() {
                let result = Account::new(
                    Uuid::new_v4(),
                    "Wallet",
                    AccountType::Cash,
                    &chart_of_accounts("1001", ChartOfAccountsType::Asset),
                    &currency("CNY"),
                    money(-100, "CNY"),
                    metadata(),
                );

                assert!(matches!(
                    result,
                    Err(AccountError::NegativeBalanceNotAllowed {
                        account_type: AccountType::Cash,
                        ..
                    })
                ));
            }

            #[test]
            fn credit_card_account_with_negative_balance_succeeds() {
                let result = Account::new(
                    Uuid::new_v4(),
                    "Visa",
                    AccountType::CreditCard,
                    &chart_of_accounts("2201", ChartOfAccountsType::Liability),
                    &currency("CNY"),
                    money(-100, "CNY"),
                    metadata(),
                );

                assert!(result.is_ok());
                assert_eq!(result.unwrap().balance.amount, Decimal::new(-100, 2));
            }

            #[test]
            fn balance_currency_mismatch_fails() {
                let result = Account::new(
                    Uuid::new_v4(),
                    "Savings",
                    AccountType::Bank,
                    &chart_of_accounts("1002", ChartOfAccountsType::Asset),
                    &currency("CNY"),
                    money(100, "USD"),
                    metadata(),
                );

                assert!(matches!(
                    result,
                    Err(AccountError::CurrencyMismatch { .. })
                ));
            }

            #[test]
            fn cash_account_rejects_invalid_chart_of_accounts_code() {
                let result = Account::new(
                    Uuid::new_v4(),
                    "Wallet",
                    AccountType::Cash,
                    &chart_of_accounts("2201", ChartOfAccountsType::Liability),
                    &currency("CNY"),
                    money(100, "CNY"),
                    metadata(),
                );

                assert!(matches!(
                    result,
                    Err(AccountError::InvalidChartOfAccountType { .. })
                        | Err(AccountError::InvalidChartOfAccountCode { .. })
                ));
            }

            #[test]
            fn bank_account_requires_bank_chart_of_accounts_code() {
                let result = Account::new(
                    Uuid::new_v4(),
                    "Checking",
                    AccountType::Bank,
                    &chart_of_accounts("1001", ChartOfAccountsType::Asset),
                    &currency("CNY"),
                    money(100, "CNY"),
                    metadata(),
                );

                assert!(matches!(
                    result,
                    Err(AccountError::InvalidChartOfAccountCode {
                        account_type: AccountType::Bank,
                        ..
                    })
                ));
            }

            #[test]
            fn investment_account_with_negative_balance_fails() {
                let result = Account::new(
                    Uuid::new_v4(),
                    "Brokerage",
                    AccountType::Investment,
                    &chart_of_accounts("1012", ChartOfAccountsType::Asset),
                    &currency("USD"),
                    money(-1, "USD"),
                    metadata(),
                );

                assert!(matches!(
                    result,
                    Err(AccountError::NegativeBalanceNotAllowed {
                        account_type: AccountType::Investment,
                        ..
                    })
                ));
            }

            #[test]
            fn update_balance_enforces_currency_rule() {
                let mut account = Account::new(
                    Uuid::new_v4(),
                    "Checking",
                    AccountType::Bank,
                    &chart_of_accounts("1002", ChartOfAccountsType::Asset),
                    &currency("CNY"),
                    money(100, "CNY"),
                    metadata(),
                )
                .unwrap();

                let result = account.update_balance(money(100, "USD"));

                assert!(matches!(
                    result,
                    Err(AccountError::CurrencyMismatch { .. })
                ));
            }

            #[test]
            fn update_balance_allows_negative_credit_card_balance() {
                let mut account = Account::new(
                    Uuid::new_v4(),
                    "Visa",
                    AccountType::CreditCard,
                    &chart_of_accounts("2201", ChartOfAccountsType::Liability),
                    &currency("CNY"),
                    money(0, "CNY"),
                    metadata(),
                )
                .unwrap();

                account.update_balance(money(-500, "CNY")).unwrap();

                assert_eq!(account.balance.amount, Decimal::new(-500, 2));
            }

            #[test]
            fn soft_delete_marks_sync_metadata_deleted() {
                let mut account = Account::new(
                    Uuid::new_v4(),
                    "Savings",
                    AccountType::Bank,
                    &chart_of_accounts("1002", ChartOfAccountsType::Asset),
                    &currency("CNY"),
                    money(100, "CNY"),
                    metadata(),
                )
                .unwrap();

                account.soft_delete().unwrap();

                assert!(account.sync_metadata.is_deleted());
            }
        }

        mod domain_events {
            use super::*;

            #[test]
            fn emits_created_and_balance_updated_events() {
                let account_id = Uuid::new_v4();
                let mut account = Account::new(
                    account_id,
                    "Checking",
                    AccountType::Bank,
                    &chart_of_accounts("1002", ChartOfAccountsType::Asset),
                    &currency("CNY"),
                    money(100, "CNY"),
                    metadata(),
                )
                .unwrap();

                let created_events = account.pull_events();
                assert!(matches!(
                    created_events.as_slice(),
                    [AccountEvent::AccountCreated { account_id: event_id, .. }]
                    if *event_id == account_id
                ));

                account.update_balance(money(250, "CNY")).unwrap();

                let balance_events = account.pull_events();
                assert!(matches!(
                    balance_events.as_slice(),
                    [AccountEvent::BalanceUpdated {
                        account_id: event_id,
                        previous_balance,
                        new_balance,
                    }]
                    if *event_id == account_id
                        && previous_balance.amount == Decimal::new(100, 2)
                        && new_balance.amount == Decimal::new(250, 2)
                ));
            }

            #[test]
            fn emits_deleted_event() {
                let account_id = Uuid::new_v4();
                let mut account = Account::new(
                    account_id,
                    "Loan",
                    AccountType::Loan,
                    &chart_of_accounts("2001", ChartOfAccountsType::Liability),
                    &currency("CNY"),
                    money(-1000, "CNY"),
                    metadata(),
                )
                .unwrap();

                account.pull_events();
                account.soft_delete().unwrap();

                let deleted_events = account.pull_events();
                assert!(matches!(
                    deleted_events.as_slice(),
                    [AccountEvent::AccountDeleted { account_id: event_id, .. }]
                    if *event_id == account_id
                ));
            }
        }
    }
}
