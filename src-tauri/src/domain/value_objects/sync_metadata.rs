#![allow(dead_code)]

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SyncMetadata {
    pub updated_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
    pub device_id: Uuid,
    pub synced_at: Option<DateTime<Utc>>,
}

impl SyncMetadata {
    pub fn new(device_id: Uuid) -> Self {
        let now = Utc::now();

        Self {
            updated_at: now,
            deleted_at: None,
            device_id,
            synced_at: None,
        }
    }

    pub fn mark_deleted(&mut self) {
        let now = Utc::now();

        self.deleted_at = Some(now);
        self.updated_at = now;
        self.synced_at = None;
    }

    pub fn mark_synced(&mut self) {
        self.synced_at = Some(Utc::now());
    }

    pub fn is_deleted(&self) -> bool {
        self.deleted_at.is_some()
    }

    pub fn needs_sync(&self) -> bool {
        match self.synced_at {
            Some(synced_at) => synced_at < self.updated_at,
            None => true,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::SyncMetadata;
    use uuid::Uuid;

    mod state_transitions {
        use super::{SyncMetadata, Uuid};

        #[test]
        fn tracks_sync_state_transitions() {
            let device_id = Uuid::new_v4();
            let mut metadata = SyncMetadata::new(device_id);

            assert_eq!(metadata.device_id, device_id);
            assert!(metadata.deleted_at.is_none());
            assert!(metadata.synced_at.is_none());
            assert!(metadata.needs_sync());

            metadata.mark_synced();

            assert!(metadata.synced_at.is_some());
            assert!(!metadata.needs_sync());

            metadata.mark_deleted();

            assert!(metadata.is_deleted());
            assert!(metadata.deleted_at.is_some());
            assert!(metadata.needs_sync());
        }
    }
}
