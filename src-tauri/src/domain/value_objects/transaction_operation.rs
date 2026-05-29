use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum OperationType {
    Create,
    AddEntry,
    UpdateEntry,
    DeleteEntry,
    UpdateDescription,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransactionOperation {
    pub id: Uuid,
    pub transaction_id: Uuid,
    pub operation_type: OperationType,
    pub entry_id: Option<Uuid>,
    pub payload: serde_json::Value,
    pub timestamp: DateTime<Utc>,
    pub device_id: Uuid,
    pub sequence_number: u64,
}

impl TransactionOperation {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        transaction_id: Uuid,
        operation_type: OperationType,
        entry_id: Option<Uuid>,
        payload: serde_json::Value,
        device_id: Uuid,
        sequence_number: u64,
    ) -> Self {
        Self {
            id: Uuid::new_v4(),
            transaction_id,
            operation_type,
            entry_id,
            payload,
            timestamp: Utc::now(),
            device_id,
            sequence_number,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn test_operation_type_serialization() {
        let op_type = OperationType::Create;
        let serialized = serde_json::to_string(&op_type).unwrap();
        assert_eq!(serialized, "\"CREATE\"");

        let op_type = OperationType::AddEntry;
        let serialized = serde_json::to_string(&op_type).unwrap();
        assert_eq!(serialized, "\"ADD_ENTRY\"");

        let op_type = OperationType::UpdateEntry;
        let serialized = serde_json::to_string(&op_type).unwrap();
        assert_eq!(serialized, "\"UPDATE_ENTRY\"");

        let op_type = OperationType::DeleteEntry;
        let serialized = serde_json::to_string(&op_type).unwrap();
        assert_eq!(serialized, "\"DELETE_ENTRY\"");

        let op_type = OperationType::UpdateDescription;
        let serialized = serde_json::to_string(&op_type).unwrap();
        assert_eq!(serialized, "\"UPDATE_DESCRIPTION\"");
    }

    #[test]
    fn test_operation_type_deserialization() {
        let deserialized: OperationType = serde_json::from_str("\"CREATE\"").unwrap();
        assert_eq!(deserialized, OperationType::Create);

        let deserialized: OperationType = serde_json::from_str("\"ADD_ENTRY\"").unwrap();
        assert_eq!(deserialized, OperationType::AddEntry);

        let deserialized: OperationType = serde_json::from_str("\"UPDATE_ENTRY\"").unwrap();
        assert_eq!(deserialized, OperationType::UpdateEntry);

        let deserialized: OperationType = serde_json::from_str("\"DELETE_ENTRY\"").unwrap();
        assert_eq!(deserialized, OperationType::DeleteEntry);

        let deserialized: OperationType = serde_json::from_str("\"UPDATE_DESCRIPTION\"").unwrap();
        assert_eq!(deserialized, OperationType::UpdateDescription);
    }

    #[test]
    fn test_transaction_operation_creation() {
        let transaction_id = Uuid::new_v4();
        let device_id = Uuid::new_v4();
        let entry_id = Some(Uuid::new_v4());
        let payload = json!({"description": "Test transaction"});

        let operation = TransactionOperation::new(
            transaction_id,
            OperationType::Create,
            entry_id,
            payload.clone(),
            device_id,
            1,
        );

        assert_eq!(operation.transaction_id, transaction_id);
        assert_eq!(operation.operation_type, OperationType::Create);
        assert_eq!(operation.entry_id, entry_id);
        assert_eq!(operation.payload, payload);
        assert_eq!(operation.device_id, device_id);
        assert_eq!(operation.sequence_number, 1);
        assert!(operation.id != Uuid::nil());
    }

    #[test]
    fn test_transaction_operation_with_none_entry_id() {
        let transaction_id = Uuid::new_v4();
        let device_id = Uuid::new_v4();
        let payload = json!({"description": "Test transaction"});

        let operation = TransactionOperation::new(
            transaction_id,
            OperationType::Create,
            None,
            payload,
            device_id,
            1,
        );

        assert_eq!(operation.entry_id, None);
    }

    #[test]
    fn test_transaction_operation_json_serialization() {
        let transaction_id = Uuid::new_v4();
        let device_id = Uuid::new_v4();
        let entry_id = Some(Uuid::new_v4());
        let payload = json!({"description": "Test transaction"});

        let operation = TransactionOperation::new(
            transaction_id,
            OperationType::AddEntry,
            entry_id,
            payload,
            device_id,
            5,
        );

        let serialized = serde_json::to_string(&operation).unwrap();
        let deserialized: TransactionOperation = serde_json::from_str(&serialized).unwrap();

        assert_eq!(deserialized.id, operation.id);
        assert_eq!(deserialized.transaction_id, operation.transaction_id);
        assert_eq!(deserialized.operation_type, operation.operation_type);
        assert_eq!(deserialized.entry_id, operation.entry_id);
        assert_eq!(deserialized.payload, operation.payload);
        assert_eq!(deserialized.device_id, operation.device_id);
        assert_eq!(deserialized.sequence_number, operation.sequence_number);
    }

    #[test]
    fn test_transaction_operation_timestamp_is_set() {
        let transaction_id = Uuid::new_v4();
        let device_id = Uuid::new_v4();
        let payload = json!({});

        let before = Utc::now();
        let operation = TransactionOperation::new(
            transaction_id,
            OperationType::Create,
            None,
            payload,
            device_id,
            1,
        );
        let after = Utc::now();

        assert!(operation.timestamp >= before);
        assert!(operation.timestamp <= after);
    }

    #[test]
    fn test_all_operation_types() {
        let transaction_id = Uuid::new_v4();
        let device_id = Uuid::new_v4();
        let payload = json!({});

        let types = [
            OperationType::Create,
            OperationType::AddEntry,
            OperationType::UpdateEntry,
            OperationType::DeleteEntry,
            OperationType::UpdateDescription,
        ];

        for (i, op_type) in types.iter().enumerate() {
            let operation = TransactionOperation::new(
                transaction_id,
                op_type.clone(),
                None,
                payload.clone(),
                device_id,
                i as u64,
            );
            assert_eq!(operation.operation_type, *op_type);
        }
    }

    #[test]
    fn test_operation_type_equality() {
        assert_eq!(OperationType::Create, OperationType::Create);
        assert_ne!(OperationType::Create, OperationType::AddEntry);
        assert_ne!(OperationType::UpdateEntry, OperationType::DeleteEntry);
    }

    #[test]
    fn test_sequence_number_field() {
        let transaction_id = Uuid::new_v4();
        let device_id = Uuid::new_v4();
        let payload = json!({});

        let operation = TransactionOperation::new(
            transaction_id,
            OperationType::Create,
            None,
            payload,
            device_id,
            42,
        );

        assert_eq!(operation.sequence_number, 42);
    }
}
