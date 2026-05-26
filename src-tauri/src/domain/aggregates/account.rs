use crate::domain::value_objects::{Currency, Money, SyncMetadata};
use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use std::{error::Error, fmt};
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum AccountType {
    Cash,
    Bank,
    CreditCard,
    Investment,
    Loan,
    BorrowedOut,
    BorrowedIn,
    Other,
    Income,
    Expense,
}

impl fmt::Display for AccountType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Cash => write!(f, "cash"),
            Self::Bank => write!(f, "bank"),
            Self::CreditCard => write!(f, "credit_card"),
            Self::Investment => write!(f, "investment"),
            Self::Loan => write!(f, "loan"),
            Self::BorrowedOut => write!(f, "borrowed_out"),
            Self::BorrowedIn => write!(f, "borrowed_in"),
            Self::Other => write!(f, "other"),
            Self::Income => write!(f, "income"),
            Self::Expense => write!(f, "expense"),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum Ownership {
    #[serde(rename = "own")]
    Own,
    #[serde(rename = "external")]
    External,
}

impl fmt::Display for Ownership {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Own => write!(f, "own"),
            Self::External => write!(f, "external"),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AccountEvent {
    AccountCreated {
        account_id: Uuid,
        account_type: AccountType,
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
    CurrencyMismatch {
        expected: String,
        actual: String,
    },
    NegativeBalanceNotAllowed {
        account_type: AccountType,
        balance: Decimal,
    },
    InvalidBillingDay,
    InvalidPaymentDueDay,
    InvalidInterestRate,
    DeletedAccount,
}

impl fmt::Display for AccountError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyName => write!(f, "account name cannot be empty"),
            Self::CurrencyMismatch { expected, actual } => {
                write!(f, "currency mismatch: expected {expected}, got {actual}")
            }
            Self::NegativeBalanceNotAllowed {
                account_type,
                balance,
            } => write!(
                f,
                "{account_type} accounts cannot have a negative balance: {balance}"
            ),
            Self::InvalidBillingDay => write!(f, "billing day must be between 1 and 31"),
            Self::InvalidPaymentDueDay => write!(f, "payment due day must be between 1 and 31"),
            Self::InvalidInterestRate => write!(f, "interest rate must be non-negative"),
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
    pub ownership: Ownership,
    pub currency_code: String,
    pub initial_balance: Money,
    pub icon: String,
    pub color: String,
    pub chart_code: Option<String>,
    pub parent_id: Option<Uuid>,
    pub account_number: Option<String>,
    pub institution: Option<String>,
    pub credit_limit: Option<Money>,
    pub billing_day: Option<u8>,
    pub payment_due_day: Option<u8>,
    pub interest_rate: Option<Decimal>,
    pub sync_metadata: SyncMetadata,
    pub(crate) pending_events: Vec<AccountEvent>,
}

impl Account {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        id: Uuid,
        name: impl Into<String>,
        account_type: AccountType,
        ownership: Ownership,
        currency: &Currency,
        initial_balance: Money,
        icon: impl Into<String>,
        color: impl Into<String>,
        chart_code: Option<String>,
        parent_id: Option<Uuid>,
        sync_metadata: SyncMetadata,
    ) -> Result<Self, AccountError> {
        let name = name.into().trim().to_string();
        let icon = icon.into().trim().to_string();
        let color = color.into().trim().to_string();

        if name.is_empty() {
            return Err(AccountError::EmptyName);
        }

        validate_balance(&account_type, &currency.code, &initial_balance)?;

        let mut account = Self {
            id,
            name,
            account_type: account_type.clone(),
            ownership,
            currency_code: currency.code.clone(),
            initial_balance,
            icon,
            color,
            chart_code,
            parent_id,
            account_number: None,
            institution: None,
            credit_limit: None,
            billing_day: None,
            payment_due_day: None,
            interest_rate: None,
            sync_metadata,
            pending_events: Vec::new(),
        };

        account.pending_events.push(AccountEvent::AccountCreated {
            account_id: account.id,
            account_type,
        });

        Ok(account)
    }

    pub fn update_initial_balance(&mut self, initial_balance: Money) -> Result<(), AccountError> {
        self.ensure_not_deleted()?;
        validate_balance(&self.account_type, &self.currency_code, &initial_balance)?;

        let previous_balance = self.initial_balance.clone();
        self.initial_balance = initial_balance.clone();
        self.touch();
        self.pending_events.push(AccountEvent::BalanceUpdated {
            account_id: self.id,
            previous_balance,
            new_balance: initial_balance,
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

    pub fn update_icon(&mut self, icon: impl Into<String>) -> Result<(), AccountError> {
        self.ensure_not_deleted()?;
        self.icon = icon.into().trim().to_string();
        self.touch();
        Ok(())
    }

    pub fn update_color(&mut self, color: impl Into<String>) -> Result<(), AccountError> {
        self.ensure_not_deleted()?;
        self.color = color.into().trim().to_string();
        self.touch();
        Ok(())
    }

    pub fn update_currency_code(&mut self, currency_code: String) -> Result<(), AccountError> {
        self.ensure_not_deleted()?;
        if currency_code != self.currency_code {
            return Err(AccountError::CurrencyMismatch {
                expected: self.currency_code.clone(),
                actual: currency_code,
            });
        }
        Ok(())
    }

    pub fn update_account_number(
        &mut self,
        account_number: Option<String>,
    ) -> Result<(), AccountError> {
        self.ensure_not_deleted()?;
        self.account_number = account_number;
        self.touch();
        Ok(())
    }

    pub fn update_institution(&mut self, institution: Option<String>) -> Result<(), AccountError> {
        self.ensure_not_deleted()?;
        self.institution = institution;
        self.touch();
        Ok(())
    }

    pub fn update_credit_limit(
        &mut self,
        credit_limit: Option<Decimal>,
    ) -> Result<(), AccountError> {
        self.ensure_not_deleted()?;
        self.credit_limit = credit_limit
            .map(|amount| Money::new(amount, &self.currency_code))
            .transpose()
            .map_err(|e| AccountError::CurrencyMismatch {
                expected: self.currency_code.clone(),
                actual: e.to_string(),
            })?;
        self.touch();
        Ok(())
    }

    pub fn update_billing_day(&mut self, billing_day: Option<i32>) -> Result<(), AccountError> {
        self.ensure_not_deleted()?;
        if let Some(day) = billing_day {
            if !(1..=31).contains(&day) {
                return Err(AccountError::InvalidBillingDay);
            }
            self.billing_day = Some(day as u8);
        } else {
            self.billing_day = None;
        }
        self.touch();
        Ok(())
    }

    pub fn update_payment_due_day(
        &mut self,
        payment_due_day: Option<i32>,
    ) -> Result<(), AccountError> {
        self.ensure_not_deleted()?;
        if let Some(day) = payment_due_day {
            if !(1..=31).contains(&day) {
                return Err(AccountError::InvalidPaymentDueDay);
            }
            self.payment_due_day = Some(day as u8);
        } else {
            self.payment_due_day = None;
        }
        self.touch();
        Ok(())
    }

    pub fn update_interest_rate(
        &mut self,
        interest_rate: Option<Decimal>,
    ) -> Result<(), AccountError> {
        self.ensure_not_deleted()?;
        if let Some(rate) = interest_rate {
            if rate < Decimal::ZERO {
                return Err(AccountError::InvalidInterestRate);
            }
            self.interest_rate = Some(rate);
        } else {
            self.interest_rate = None;
        }
        self.touch();
        Ok(())
    }

    pub fn update_chart_code(&mut self, chart_code: Option<String>) -> Result<(), AccountError> {
        self.ensure_not_deleted()?;
        self.chart_code = chart_code;
        self.touch();
        Ok(())
    }

    pub fn update_parent_id(&mut self, parent_id: Option<Uuid>) -> Result<(), AccountError> {
        self.ensure_not_deleted()?;
        self.parent_id = parent_id;
        self.touch();
        Ok(())
    }

    pub fn soft_delete(&mut self) -> Result<(), AccountError> {
        self.ensure_not_deleted()?;
        self.sync_metadata.mark_deleted();

        if let Some(deleted_at) = self.sync_metadata.deleted_at {
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
        AccountType::Cash | AccountType::Bank | AccountType::Investment | AccountType::BorrowedOut
    ) && balance.amount < Decimal::ZERO
    {
        return Err(AccountError::NegativeBalanceNotAllowed {
            account_type: account_type.clone(),
            balance: balance.amount,
        });
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

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
                    Ownership::Own,
                    &currency("CNY"),
                    money(-100, "CNY"),
                    "💰",
                    "#10B981",
                    None,
                    None,
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
                    Ownership::Own,
                    &currency("CNY"),
                    money(-100, "CNY"),
                    "💳",
                    "#10B981",
                    None,
                    None,
                    metadata(),
                );

                assert!(result.is_ok());
                assert_eq!(result.unwrap().initial_balance.amount, Decimal::new(-100, 2));
            }

            #[test]
            fn balance_currency_mismatch_fails() {
                let result = Account::new(
                    Uuid::new_v4(),
                    "Savings",
                    AccountType::Bank,
                    Ownership::Own,
                    &currency("CNY"),
                    money(100, "USD"),
                    "💰",
                    "#10B981",
                    None,
                    None,
                    metadata(),
                );

                assert!(matches!(result, Err(AccountError::CurrencyMismatch { .. })));
            }

            #[test]
            fn investment_account_with_negative_balance_fails() {
                let result = Account::new(
                    Uuid::new_v4(),
                    "Brokerage",
                    AccountType::Investment,
                    Ownership::Own,
                    &currency("USD"),
                    money(-1, "USD"),
                    "💰",
                    "#10B981",
                    None,
                    None,
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
                    Ownership::Own,
                    &currency("CNY"),
                    money(100, "CNY"),
                    "💰",
                    "#10B981",
                    None,
                    None,
                    metadata(),
                )
                .unwrap();

                let result = account.update_initial_balance(money(100, "USD"));

                assert!(matches!(result, Err(AccountError::CurrencyMismatch { .. })));
            }

            #[test]
            fn update_balance_allows_negative_credit_card_balance() {
                let mut account = Account::new(
                    Uuid::new_v4(),
                    "Visa",
                    AccountType::CreditCard,
                    Ownership::Own,
                    &currency("CNY"),
                    money(0, "CNY"),
                    "💳",
                    "#10B981",
                    None,
                    None,
                    metadata(),
                )
                .unwrap();

                account.update_initial_balance(money(-500, "CNY")).unwrap();

                assert_eq!(account.initial_balance.amount, Decimal::new(-500, 2));
            }

            #[test]
            fn soft_delete_marks_sync_metadata_deleted() {
                let mut account = Account::new(
                    Uuid::new_v4(),
                    "Savings",
                    AccountType::Bank,
                    Ownership::Own,
                    &currency("CNY"),
                    money(100, "CNY"),
                    "💰",
                    "#10B981",
                    None,
                    None,
                    metadata(),
                )
                .unwrap();

                account.soft_delete().unwrap();

                assert!(account.sync_metadata.is_deleted());
            }

            #[test]
            fn update_icon_changes_icon_and_touches_metadata() {
                let mut account = Account::new(
                    Uuid::new_v4(),
                    "Wallet",
                    AccountType::Bank,
                    Ownership::Own,
                    &currency("CNY"),
                    money(100, "CNY"),
                    "💰",
                    "#10B981",
                    None,
                    None,
                    metadata(),
                )
                .unwrap();

                let before = account.sync_metadata.updated_at;
                account.update_icon("💳").unwrap();

                assert_eq!(account.icon, "💳");
                assert!(account.sync_metadata.updated_at >= before);
                assert!(account.sync_metadata.synced_at.is_none());
            }

            #[test]
            fn update_color_changes_color() {
                let mut account = Account::new(
                    Uuid::new_v4(),
                    "Wallet",
                    AccountType::Bank,
                    Ownership::Own,
                    &currency("CNY"),
                    money(100, "CNY"),
                    "💰",
                    "#10B981",
                    None,
                    None,
                    metadata(),
                )
                .unwrap();

                account.update_color("#EF4444").unwrap();
                assert_eq!(account.color, "#EF4444");
            }

            #[test]
            fn update_currency_code_rejects_mismatch() {
                let mut account = Account::new(
                    Uuid::new_v4(),
                    "Wallet",
                    AccountType::Bank,
                    Ownership::Own,
                    &currency("CNY"),
                    money(100, "CNY"),
                    "💰",
                    "#10B981",
                    None,
                    None,
                    metadata(),
                )
                .unwrap();

                let result = account.update_currency_code("USD".to_string());
                assert!(result.is_err());
            }

            #[test]
            fn update_billing_day_rejects_out_of_range() {
                let mut account = Account::new(
                    Uuid::new_v4(),
                    "Wallet",
                    AccountType::Bank,
                    Ownership::Own,
                    &currency("CNY"),
                    money(100, "CNY"),
                    "💰",
                    "#10B981",
                    None,
                    None,
                    metadata(),
                )
                .unwrap();

                assert!(account.update_billing_day(Some(32)).is_err());
                assert!(account.update_billing_day(Some(0)).is_err());
                assert!(account.update_billing_day(Some(15)).is_ok());
                assert_eq!(account.billing_day, Some(15));
            }

            #[test]
            fn update_payment_due_day_rejects_out_of_range() {
                let mut account = Account::new(
                    Uuid::new_v4(),
                    "Wallet",
                    AccountType::Bank,
                    Ownership::Own,
                    &currency("CNY"),
                    money(100, "CNY"),
                    "💰",
                    "#10B981",
                    None,
                    None,
                    metadata(),
                )
                .unwrap();

                assert!(account.update_payment_due_day(Some(32)).is_err());
                assert!(account.update_payment_due_day(Some(1)).is_ok());
            }

            #[test]
            fn update_interest_rate_rejects_negative() {
                let mut account = Account::new(
                    Uuid::new_v4(),
                    "Wallet",
                    AccountType::Bank,
                    Ownership::Own,
                    &currency("CNY"),
                    money(100, "CNY"),
                    "💰",
                    "#10B981",
                    None,
                    None,
                    metadata(),
                )
                .unwrap();

                assert!(
                    account
                        .update_interest_rate(Some(Decimal::new(-1, 2)))
                        .is_err()
                );
                assert!(account.update_interest_rate(Some(Decimal::new(5, 1))).is_ok());
                assert_eq!(account.interest_rate, Some(Decimal::new(5, 1)));
            }

            #[test]
            fn update_credit_limit_stores_money_value() {
                let mut account = Account::new(
                    Uuid::new_v4(),
                    "Visa",
                    AccountType::CreditCard,
                    Ownership::Own,
                    &currency("CNY"),
                    money(-100, "CNY"),
                    "💳",
                    "#10B981",
                    None,
                    None,
                    metadata(),
                )
                .unwrap();

                account
                    .update_credit_limit(Some(Decimal::new(50000, 2)))
                    .unwrap();
                assert_eq!(
                    account.credit_limit.as_ref().unwrap().amount,
                    Decimal::new(50000, 2)
                );
                assert_eq!(
                    account.credit_limit.as_ref().unwrap().currency_code,
                    "CNY"
                );
            }

            #[test]
            fn setters_reject_on_deleted_account() {
                let mut account = Account::new(
                    Uuid::new_v4(),
                    "Wallet",
                    AccountType::Bank,
                    Ownership::Own,
                    &currency("CNY"),
                    money(100, "CNY"),
                    "💰",
                    "#10B981",
                    None,
                    None,
                    metadata(),
                )
                .unwrap();

                account.soft_delete().unwrap();

                assert!(account.update_icon("x").is_err());
                assert!(account.update_color("x").is_err());
                assert!(account.update_billing_day(Some(1)).is_err());
                assert!(account.update_payment_due_day(Some(1)).is_err());
                assert!(account.update_interest_rate(Some(Decimal::ONE)).is_err());
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
                    Ownership::Own,
                    &currency("CNY"),
                    money(100, "CNY"),
                    "💰",
                    "#10B981",
                    None,
                    None,
                    metadata(),
                )
                .unwrap();

                let created_events = account.pull_events();
                assert!(matches!(
                    created_events.as_slice(),
                    [AccountEvent::AccountCreated { account_id: event_id, .. }]
                    if *event_id == account_id
                ));

                account.update_initial_balance(money(250, "CNY")).unwrap();

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
                    Ownership::Own,
                    &currency("CNY"),
                    money(-1000, "CNY"),
                    "💰",
                    "#10B981",
                    None,
                    None,
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
