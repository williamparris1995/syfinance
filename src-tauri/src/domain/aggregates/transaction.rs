use crate::domain::value_objects::{
    Money, OperationType, SyncMetadata, TransactionEntry, TransactionEntryError,
    TransactionOperation,
};
use chrono::{NaiveDate, Utc};
use std::{error::Error, fmt};
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TransactionEvent {
    TransactionCreated {
        transaction_id: Uuid,
        entry_count: usize,
    },
    TransactionUpdated {
        transaction_id: Uuid,
        entry_count: usize,
    },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TransactionError {
    EntryValidation(TransactionEntryError),
    MinimumEntries {
        actual: usize,
    },
    MixedCurrencies {
        expected: String,
        actual: String,
    },
    UnbalancedTransaction {
        debit_total: Money,
        credit_total: Money,
    },
}

impl fmt::Display for TransactionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EntryValidation(error) => write!(f, "{error}"),
            Self::MinimumEntries { actual } => {
                write!(f, "transactions require at least 2 entries, got {actual}")
            }
            Self::MixedCurrencies { expected, actual } => {
                write!(f, "transaction entries must share the same currency: expected {expected}, got {actual}")
            }
            Self::UnbalancedTransaction {
                debit_total,
                credit_total,
            } => write!(
                f,
                "transaction is not balanced: debits {debit_total} != credits {credit_total}"
            ),
        }
    }
}

impl Error for TransactionError {}

impl From<TransactionEntryError> for TransactionError {
    fn from(value: TransactionEntryError) -> Self {
        Self::EntryValidation(value)
    }
}

#[derive(Debug, Clone)]
pub struct Transaction {
    pub id: Uuid,
    pub transaction_date: NaiveDate,
    pub description: String,
    pub entries: Vec<TransactionEntry>,
    pub sync_metadata: SyncMetadata,
    pub(crate) pending_events: Vec<TransactionEvent>,
    pub operations: Vec<TransactionOperation>,
}

impl Transaction {
    pub fn new(
        id: Uuid,
        transaction_date: NaiveDate,
        description: impl Into<String>,
        entries: Vec<TransactionEntry>,
        sync_metadata: SyncMetadata,
    ) -> Result<Self, TransactionError> {
        let mut transaction = Self {
            id,
            transaction_date,
            description: description.into().trim().to_string(),
            entries,
            sync_metadata,
            pending_events: Vec::new(),
            operations: Vec::new(),
        };

        transaction.validate()?;
        transaction
            .pending_events
            .push(TransactionEvent::TransactionCreated {
                transaction_id: transaction.id,
                entry_count: transaction.entries.len(),
            });
        Ok(transaction)
    }

    /// Reconstruct a Transaction from persistence without validation.
    /// Used by repository read paths — transactions were validated on write.
    pub fn reconstitute(
        id: Uuid,
        transaction_date: NaiveDate,
        description: impl Into<String>,
        entries: Vec<TransactionEntry>,
        sync_metadata: SyncMetadata,
    ) -> Self {
        Self {
            id,
            transaction_date,
            description: description.into().trim().to_string(),
            entries,
            sync_metadata,
            pending_events: Vec::new(),
            operations: Vec::new(),
        }
    }

    pub fn add_entry(&mut self, entry: TransactionEntry) -> Result<(), TransactionError> {
        let original_len = self.entries.len();
        self.entries.push(entry);

        if let Err(error) = self.validate() {
            self.entries.truncate(original_len);
            return Err(error);
        }

        self.touch();
        self.pending_events
            .push(TransactionEvent::TransactionUpdated {
                transaction_id: self.id,
                entry_count: self.entries.len(),
            });
        Ok(())
    }

    pub fn is_balanced(&self) -> bool {
        match self.totals() {
            Ok((debit_total, credit_total)) => debit_total.amount == credit_total.amount,
            Err(_) => false,
        }
    }

    pub fn validate(&self) -> Result<(), TransactionError> {
        if self.entries.len() < 2 {
            return Err(TransactionError::MinimumEntries {
                actual: self.entries.len(),
            });
        }

        let (debit_total, credit_total) = self.totals()?;
        if debit_total.amount != credit_total.amount {
            return Err(TransactionError::UnbalancedTransaction {
                debit_total,
                credit_total,
            });
        }

        Ok(())
    }

    pub fn pull_events(&mut self) -> Vec<TransactionEvent> {
        std::mem::take(&mut self.pending_events)
    }

    pub fn record_operation(
        &mut self,
        operation_type: OperationType,
        entry_id: Option<Uuid>,
        payload: serde_json::Value,
        device_id: Uuid,
        sequence_number: u64,
    ) {
        let operation = TransactionOperation::new(
            self.id,
            operation_type,
            entry_id,
            payload,
            device_id,
            sequence_number,
        );
        self.operations.push(operation);
    }

    pub fn get_operations(&self) -> &[TransactionOperation] {
        &self.operations
    }

    pub fn clear_operations(&mut self) {
        self.operations.clear();
    }

    fn totals(&self) -> Result<(Money, Money), TransactionError> {
        let mut currency_code: Option<&str> = None;
        let mut debit_total: Option<Money> = None;
        let mut credit_total: Option<Money> = None;

        for entry in &self.entries {
            entry.validate()?;

            let entry_currency = entry
                .currency_code()
                .ok_or(TransactionError::EntryValidation(
                    TransactionEntryError::MissingDebitAndCredit,
                ))?;

            if let Some(expected_currency) = currency_code {
                if expected_currency != entry_currency {
                    return Err(TransactionError::MixedCurrencies {
                        expected: expected_currency.to_string(),
                        actual: entry_currency.to_string(),
                    });
                }
            } else {
                currency_code = Some(entry_currency);
                debit_total =
                    Some(Money::new(rust_decimal::Decimal::ZERO, entry_currency).unwrap());
                credit_total =
                    Some(Money::new(rust_decimal::Decimal::ZERO, entry_currency).unwrap());
            }

            if let Some(amount) = &entry.debit_amount {
                let current = debit_total.as_ref().unwrap();
                debit_total = Some(current.add(amount).unwrap());
            }

            if let Some(amount) = &entry.credit_amount {
                let current = credit_total.as_ref().unwrap();
                credit_total = Some(current.add(amount).unwrap());
            }
        }

        Ok((debit_total.unwrap(), credit_total.unwrap()))
    }

    fn touch(&mut self) {
        self.sync_metadata.updated_at = Utc::now();
        self.sync_metadata.synced_at = None;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rust_decimal::Decimal;

    fn money(amount: i64, currency_code: &str) -> Money {
        Money::new(Decimal::new(amount, 2), currency_code).unwrap()
    }

    fn debit_entry(amount: i64, currency_code: &str) -> TransactionEntry {
        TransactionEntry::new(
            Uuid::new_v4(),
            "1002",
            Some(money(amount, currency_code)),
            None,
            "debit",
        )
        .unwrap()
    }

    fn credit_entry(amount: i64, currency_code: &str) -> TransactionEntry {
        TransactionEntry::new(
            Uuid::new_v4(),
            "4001",
            None,
            Some(money(amount, currency_code)),
            "credit",
        )
        .unwrap()
    }

    fn metadata() -> SyncMetadata {
        SyncMetadata::new(Uuid::new_v4())
    }

    mod transaction {
        use super::*;

        mod double_entry {
            use super::*;

            #[test]
            fn balanced_transaction_succeeds() {
                let transaction = Transaction::new(
                    Uuid::new_v4(),
                    NaiveDate::from_ymd_opt(2026, 4, 7).unwrap(),
                    "Salary received",
                    vec![debit_entry(5_000_00, "CNY"), credit_entry(5_000_00, "CNY")],
                    metadata(),
                )
                .unwrap();

                assert!(transaction.is_balanced());
                assert_eq!(transaction.entries.len(), 2);
            }

            #[test]
            fn unbalanced_transaction_fails() {
                let result = Transaction::new(
                    Uuid::new_v4(),
                    NaiveDate::from_ymd_opt(2026, 4, 7).unwrap(),
                    "Unbalanced",
                    vec![debit_entry(5_000_00, "CNY"), credit_entry(4_999_00, "CNY")],
                    metadata(),
                );

                assert!(matches!(
                    result,
                    Err(TransactionError::UnbalancedTransaction { .. })
                ));
            }

            #[test]
            fn single_entry_transaction_fails() {
                let result = Transaction::new(
                    Uuid::new_v4(),
                    NaiveDate::from_ymd_opt(2026, 4, 7).unwrap(),
                    "Single entry",
                    vec![debit_entry(5_000_00, "CNY")],
                    metadata(),
                );

                assert!(matches!(
                    result,
                    Err(TransactionError::MinimumEntries { actual: 1 })
                ));
            }

            #[test]
            fn mixed_currency_transaction_fails() {
                let result = Transaction::new(
                    Uuid::new_v4(),
                    NaiveDate::from_ymd_opt(2026, 4, 7).unwrap(),
                    "FX mismatch",
                    vec![debit_entry(5_000_00, "CNY"), credit_entry(5_000_00, "USD")],
                    metadata(),
                );

                assert!(matches!(
                    result,
                    Err(TransactionError::MixedCurrencies { .. })
                ));
            }

            #[test]
            fn add_entry_requires_transaction_to_remain_balanced() {
                let mut transaction = Transaction::new(
                    Uuid::new_v4(),
                    NaiveDate::from_ymd_opt(2026, 4, 7).unwrap(),
                    "Salary received",
                    vec![debit_entry(5_000_00, "CNY"), credit_entry(5_000_00, "CNY")],
                    metadata(),
                )
                .unwrap();

                let result = transaction.add_entry(debit_entry(100, "CNY"));

                assert!(matches!(
                    result,
                    Err(TransactionError::UnbalancedTransaction { .. })
                ));
                assert_eq!(transaction.entries.len(), 2);
            }
        }

        mod domain_events {
            use super::*;

            #[test]
            fn emits_created_event() {
                let transaction_id = Uuid::new_v4();
                let mut transaction = Transaction::new(
                    transaction_id,
                    NaiveDate::from_ymd_opt(2026, 4, 7).unwrap(),
                    "Salary received",
                    vec![debit_entry(5_000_00, "CNY"), credit_entry(5_000_00, "CNY")],
                    metadata(),
                )
                .unwrap();

                let events = transaction.pull_events();
                assert!(matches!(
                    events.as_slice(),
                    [TransactionEvent::TransactionCreated {
                        transaction_id: event_id,
                        entry_count: 2,
                    }] if *event_id == transaction_id
                ));
            }

            #[test]
            fn emits_updated_event_when_entry_is_added() {
                let transaction_id = Uuid::new_v4();
                let mut transaction = Transaction::new(
                    transaction_id,
                    NaiveDate::from_ymd_opt(2026, 4, 7).unwrap(),
                    "Expense split",
                    vec![
                        debit_entry(5_000_00, "CNY"),
                        credit_entry(2_500_00, "CNY"),
                        credit_entry(2_500_00, "CNY"),
                    ],
                    metadata(),
                )
                .unwrap();

                transaction.pull_events();
                transaction.add_entry(credit_entry(0, "CNY")).unwrap();

                let events = transaction.pull_events();
                assert!(matches!(
                    events.as_slice(),
                    [TransactionEvent::TransactionUpdated {
                        transaction_id: event_id,
                        entry_count: 4,
                    }] if *event_id == transaction_id
                ));
            }

            #[test]
            fn failed_entry_addition_emits_no_event() {
                let mut transaction = Transaction::new(
                    Uuid::new_v4(),
                    NaiveDate::from_ymd_opt(2026, 4, 7).unwrap(),
                    "Expense split",
                    vec![
                        debit_entry(5_000_00, "CNY"),
                        credit_entry(2_500_00, "CNY"),
                        credit_entry(2_500_00, "CNY"),
                    ],
                    metadata(),
                )
                .unwrap();

                transaction.pull_events();
                transaction.add_entry(credit_entry(100, "CNY")).unwrap_err();

                let events = transaction.pull_events();
                assert!(events.is_empty());
            }
        }

        mod operation_logging {
            use super::*;

            #[test]
            fn record_operation_adds_to_operations_list() {
                let mut transaction = Transaction::new(
                    Uuid::new_v4(),
                    NaiveDate::from_ymd_opt(2026, 4, 7).unwrap(),
                    "Test transaction",
                    vec![debit_entry(5_000_00, "CNY"), credit_entry(5_000_00, "CNY")],
                    metadata(),
                )
                .unwrap();

                let device_id = Uuid::new_v4();
                let entry_id = Uuid::new_v4();
                let payload = serde_json::json!({"amount": 5000});

                transaction.record_operation(
                    OperationType::Create,
                    Some(entry_id),
                    payload,
                    device_id,
                    1,
                );

                assert_eq!(transaction.get_operations().len(), 1);
                let op = &transaction.get_operations()[0];
                assert_eq!(op.transaction_id, transaction.id);
                assert_eq!(op.device_id, device_id);
                assert_eq!(op.sequence_number, 1);
            }

            #[test]
            fn get_operations_returns_all_recorded_operations() {
                let mut transaction = Transaction::new(
                    Uuid::new_v4(),
                    NaiveDate::from_ymd_opt(2026, 4, 7).unwrap(),
                    "Test transaction",
                    vec![debit_entry(5_000_00, "CNY"), credit_entry(5_000_00, "CNY")],
                    metadata(),
                )
                .unwrap();

                let device_id = Uuid::new_v4();

                transaction.record_operation(
                    OperationType::Create,
                    None,
                    serde_json::json!({}),
                    device_id,
                    1,
                );
                transaction.record_operation(
                    OperationType::AddEntry,
                    None,
                    serde_json::json!({}),
                    device_id,
                    2,
                );
                transaction.record_operation(
                    OperationType::UpdateEntry,
                    None,
                    serde_json::json!({}),
                    device_id,
                    3,
                );

                let operations = transaction.get_operations();
                assert_eq!(operations.len(), 3);
                assert!(matches!(
                    operations[0].operation_type,
                    OperationType::Create
                ));
                assert!(matches!(
                    operations[1].operation_type,
                    OperationType::AddEntry
                ));
                assert!(matches!(
                    operations[2].operation_type,
                    OperationType::UpdateEntry
                ));
            }

            #[test]
            fn clear_operations_removes_all_operations() {
                let mut transaction = Transaction::new(
                    Uuid::new_v4(),
                    NaiveDate::from_ymd_opt(2026, 4, 7).unwrap(),
                    "Test transaction",
                    vec![debit_entry(5_000_00, "CNY"), credit_entry(5_000_00, "CNY")],
                    metadata(),
                )
                .unwrap();

                let device_id = Uuid::new_v4();

                transaction.record_operation(
                    OperationType::Create,
                    None,
                    serde_json::json!({}),
                    device_id,
                    1,
                );
                transaction.record_operation(
                    OperationType::AddEntry,
                    None,
                    serde_json::json!({}),
                    device_id,
                    2,
                );

                assert_eq!(transaction.get_operations().len(), 2);

                transaction.clear_operations();

                assert_eq!(transaction.get_operations().len(), 0);
            }
        }
    }
}
