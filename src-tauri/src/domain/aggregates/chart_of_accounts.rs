use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::fmt;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum AccountType {
    Asset,
    Liability,
    Equity,
    Income,
    Expense,
}

impl fmt::Display for AccountType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            AccountType::Asset => write!(f, "asset"),
            AccountType::Liability => write!(f, "liability"),
            AccountType::Equity => write!(f, "equity"),
            AccountType::Income => write!(f, "income"),
            AccountType::Expense => write!(f, "expense"),
        }
    }
}

impl AccountType {
    pub fn from_str(s: &str) -> Result<Self, ChartOfAccountsError> {
        match s.to_lowercase().as_str() {
            "asset" => Ok(AccountType::Asset),
            "liability" => Ok(AccountType::Liability),
            "equity" => Ok(AccountType::Equity),
            "income" => Ok(AccountType::Income),
            "expense" => Ok(AccountType::Expense),
            _ => Err(ChartOfAccountsError::InvalidAccountType(s.to_string())),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum BalanceDirection {
    Debit,
    Credit,
}

impl fmt::Display for BalanceDirection {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            BalanceDirection::Debit => write!(f, "debit"),
            BalanceDirection::Credit => write!(f, "credit"),
        }
    }
}

impl BalanceDirection {
    pub fn from_str(s: &str) -> Result<Self, ChartOfAccountsError> {
        match s.to_lowercase().as_str() {
            "debit" => Ok(BalanceDirection::Debit),
            "credit" => Ok(BalanceDirection::Credit),
            _ => Err(ChartOfAccountsError::InvalidBalanceDirection(s.to_string())),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ChartOfAccountsError {
    InvalidCodeFormat(String),
    InvalidLevel(i32),
    InvalidAccountType(String),
    InvalidBalanceDirection(String),
    ParentCodeRequired,
    ParentCodeNotAllowed,
    InvalidParentLevel,
}

impl fmt::Display for ChartOfAccountsError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ChartOfAccountsError::InvalidCodeFormat(code) => {
                write!(
                    f,
                    "Invalid code format: {}. Level 1/2 must be 4 digits, level 3 must be 6 digits",
                    code
                )
            }
            ChartOfAccountsError::InvalidLevel(level) => {
                write!(f, "Invalid level: {}. Must be 1, 2, or 3", level)
            }
            ChartOfAccountsError::InvalidAccountType(t) => {
                write!(f, "Invalid account type: {}", t)
            }
            ChartOfAccountsError::InvalidBalanceDirection(d) => {
                write!(f, "Invalid balance direction: {}", d)
            }
            ChartOfAccountsError::ParentCodeRequired => {
                write!(f, "Parent code is required for level 2 and 3 accounts")
            }
            ChartOfAccountsError::ParentCodeNotAllowed => {
                write!(f, "Parent code is not allowed for level 1 accounts")
            }
            ChartOfAccountsError::InvalidParentLevel => {
                write!(f, "Invalid parent level relationship")
            }
        }
    }
}

impl std::error::Error for ChartOfAccountsError {}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChartOfAccounts {
    pub id: String,
    pub code: String,
    pub name: String,
    pub level: i32,
    pub account_type: AccountType,
    pub parent_code: Option<String>,
    pub balance_direction: BalanceDirection,
    pub deleted_at: Option<DateTime<Utc>>,
    pub updated_at: DateTime<Utc>,
    pub device_id: Option<String>,
    pub synced_at: Option<DateTime<Utc>>,
}

impl ChartOfAccounts {
    pub fn new(
        id: String,
        code: String,
        name: String,
        level: i32,
        account_type: AccountType,
        parent_code: Option<String>,
        balance_direction: BalanceDirection,
    ) -> Result<Self, ChartOfAccountsError> {
        // Validate level
        if !(1..=3).contains(&level) {
            return Err(ChartOfAccountsError::InvalidLevel(level));
        }

        // Validate code format based on level
        Self::validate_code_format(&code, level)?;

        // Validate parent_code requirements
        Self::validate_parent_code(level, &parent_code)?;

        Ok(Self {
            id,
            code,
            name,
            level,
            account_type,
            parent_code,
            balance_direction,
            deleted_at: None,
            updated_at: Utc::now(),
            device_id: None,
            synced_at: None,
        })
    }

    fn validate_code_format(code: &str, level: i32) -> Result<(), ChartOfAccountsError> {
        let is_valid = match level {
            1 | 2 => code.len() == 4 && code.chars().all(|c| c.is_ascii_digit()),
            3 => code.len() == 6 && code.chars().all(|c| c.is_ascii_digit()),
            _ => false,
        };

        if !is_valid {
            return Err(ChartOfAccountsError::InvalidCodeFormat(code.to_string()));
        }

        Ok(())
    }

    fn validate_parent_code(
        level: i32,
        parent_code: &Option<String>,
    ) -> Result<(), ChartOfAccountsError> {
        match level {
            1 => {
                if parent_code.is_some() {
                    return Err(ChartOfAccountsError::ParentCodeNotAllowed);
                }
            }
            2 | 3 => {
                if parent_code.is_none() {
                    return Err(ChartOfAccountsError::ParentCodeRequired);
                }
            }
            _ => {}
        }

        Ok(())
    }

    pub fn is_deleted(&self) -> bool {
        self.deleted_at.is_some()
    }

    pub fn soft_delete(&mut self) {
        self.deleted_at = Some(Utc::now());
        self.updated_at = Utc::now();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_level1_account_success() {
        let account = ChartOfAccounts::new(
            "id1".to_string(),
            "1000".to_string(),
            "资产".to_string(),
            1,
            AccountType::Asset,
            None,
            BalanceDirection::Debit,
        );

        assert!(account.is_ok());
        let account = account.unwrap();
        assert_eq!(account.code, "1000");
        assert_eq!(account.level, 1);
        assert_eq!(account.parent_code, None);
    }

    #[test]
    fn test_create_level2_account_success() {
        let account = ChartOfAccounts::new(
            "id2".to_string(),
            "1001".to_string(),
            "库存现金".to_string(),
            2,
            AccountType::Asset,
            Some("1000".to_string()),
            BalanceDirection::Debit,
        );

        assert!(account.is_ok());
        let account = account.unwrap();
        assert_eq!(account.code, "1001");
        assert_eq!(account.level, 2);
        assert_eq!(account.parent_code, Some("1000".to_string()));
    }

    #[test]
    fn test_create_level3_account_success() {
        let account = ChartOfAccounts::new(
            "id3".to_string(),
            "100101".to_string(),
            "人民币".to_string(),
            3,
            AccountType::Asset,
            Some("1001".to_string()),
            BalanceDirection::Debit,
        );

        assert!(account.is_ok());
        let account = account.unwrap();
        assert_eq!(account.code, "100101");
        assert_eq!(account.level, 3);
    }

    #[test]
    fn test_invalid_code_format_level1() {
        let account = ChartOfAccounts::new(
            "id1".to_string(),
            "100".to_string(), // Too short
            "资产".to_string(),
            1,
            AccountType::Asset,
            None,
            BalanceDirection::Debit,
        );

        assert!(matches!(
            account,
            Err(ChartOfAccountsError::InvalidCodeFormat(_))
        ));
    }

    #[test]
    fn test_invalid_code_format_level3() {
        let account = ChartOfAccounts::new(
            "id3".to_string(),
            "1001".to_string(), // Too short for level 3
            "人民币".to_string(),
            3,
            AccountType::Asset,
            Some("1001".to_string()),
            BalanceDirection::Debit,
        );

        assert!(matches!(
            account,
            Err(ChartOfAccountsError::InvalidCodeFormat(_))
        ));
    }

    #[test]
    fn test_level1_with_parent_code_fails() {
        let account = ChartOfAccounts::new(
            "id1".to_string(),
            "1000".to_string(),
            "资产".to_string(),
            1,
            AccountType::Asset,
            Some("0000".to_string()), // Should not have parent
            BalanceDirection::Debit,
        );

        assert!(matches!(
            account,
            Err(ChartOfAccountsError::ParentCodeNotAllowed)
        ));
    }

    #[test]
    fn test_level2_without_parent_code_fails() {
        let account = ChartOfAccounts::new(
            "id2".to_string(),
            "1001".to_string(),
            "库存现金".to_string(),
            2,
            AccountType::Asset,
            None, // Should have parent
            BalanceDirection::Debit,
        );

        assert!(matches!(
            account,
            Err(ChartOfAccountsError::ParentCodeRequired)
        ));
    }

    #[test]
    fn test_invalid_level() {
        let account = ChartOfAccounts::new(
            "id1".to_string(),
            "1000".to_string(),
            "资产".to_string(),
            4, // Invalid level
            AccountType::Asset,
            None,
            BalanceDirection::Debit,
        );

        assert!(matches!(
            account,
            Err(ChartOfAccountsError::InvalidLevel(4))
        ));
    }

    #[test]
    fn test_soft_delete() {
        let mut account = ChartOfAccounts::new(
            "id1".to_string(),
            "1000".to_string(),
            "资产".to_string(),
            1,
            AccountType::Asset,
            None,
            BalanceDirection::Debit,
        )
        .unwrap();

        assert!(!account.is_deleted());
        account.soft_delete();
        assert!(account.is_deleted());
    }

    #[test]
    fn test_account_type_from_str() {
        assert_eq!(AccountType::from_str("asset").unwrap(), AccountType::Asset);
        assert_eq!(AccountType::from_str("ASSET").unwrap(), AccountType::Asset);
        assert!(AccountType::from_str("invalid").is_err());
    }

    #[test]
    fn test_balance_direction_from_str() {
        assert_eq!(
            BalanceDirection::from_str("debit").unwrap(),
            BalanceDirection::Debit
        );
        assert_eq!(
            BalanceDirection::from_str("CREDIT").unwrap(),
            BalanceDirection::Credit
        );
        assert!(BalanceDirection::from_str("invalid").is_err());
    }
}
