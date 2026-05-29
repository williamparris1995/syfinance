use crate::domain::value_objects::Money;
use std::{error::Error, fmt};
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TransactionEntryError {
    BothDebitAndCreditProvided,
    MissingDebitAndCredit,
}

impl fmt::Display for TransactionEntryError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BothDebitAndCreditProvided => {
                write!(f, "transaction entry cannot contain both debit and credit")
            }
            Self::MissingDebitAndCredit => {
                write!(f, "transaction entry must contain either debit or credit")
            }
        }
    }
}

impl Error for TransactionEntryError {}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TransactionEntry {
    pub id: Uuid,
    pub account_id: Uuid,
    pub chart_of_account_code: String,
    pub debit_amount: Option<Money>,
    pub credit_amount: Option<Money>,
    pub note: String,
}

impl TransactionEntry {
    pub fn new(
        account_id: Uuid,
        chart_of_account_code: impl Into<String>,
        debit_amount: Option<Money>,
        credit_amount: Option<Money>,
        note: impl Into<String>,
    ) -> Result<Self, TransactionEntryError> {
        let entry = Self {
            id: Uuid::new_v4(),
            account_id,
            chart_of_account_code: chart_of_account_code.into().trim().to_string(),
            debit_amount,
            credit_amount,
            note: note.into().trim().to_string(),
        };

        entry.validate()?;
        Ok(entry)
    }

    pub fn validate(&self) -> Result<(), TransactionEntryError> {
        match (&self.debit_amount, &self.credit_amount) {
            (Some(_), Some(_)) => Err(TransactionEntryError::BothDebitAndCreditProvided),
            (None, None) => Err(TransactionEntryError::MissingDebitAndCredit),
            _ => Ok(()),
        }
    }

    pub fn currency_code(&self) -> Option<&str> {
        self.debit_amount
            .as_ref()
            .map(|money| money.currency_code.as_str())
            .or_else(|| {
                self.credit_amount
                    .as_ref()
                    .map(|money| money.currency_code.as_str())
            })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rust_decimal::Decimal;

    fn money(amount: i64, currency_code: &str) -> Money {
        Money::new(Decimal::new(amount, 2), currency_code).unwrap()
    }

    mod transaction_entry {
        use super::*;

        mod business_rules {
            use super::*;

            #[test]
            fn accepts_debit_only_entries() {
                let entry = TransactionEntry::new(
                    Uuid::new_v4(),
                    "1002",
                    Some(money(5_000_00, "CNY")),
                    None,
                    "salary deposit",
                )
                .unwrap();

                assert!(entry.debit_amount.is_some());
                assert!(entry.credit_amount.is_none());
            }

            #[test]
            fn rejects_entries_with_both_debit_and_credit() {
                let result = TransactionEntry::new(
                    Uuid::new_v4(),
                    "1002",
                    Some(money(5_000_00, "CNY")),
                    Some(money(5_000_00, "CNY")),
                    "invalid",
                );

                assert!(matches!(
                    result,
                    Err(TransactionEntryError::BothDebitAndCreditProvided)
                ));
            }

            #[test]
            fn rejects_entries_without_debit_or_credit() {
                let result = TransactionEntry::new(Uuid::new_v4(), "1002", None, None, "invalid");

                assert!(matches!(
                    result,
                    Err(TransactionEntryError::MissingDebitAndCredit)
                ));
            }
        }
    }
}
