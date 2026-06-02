// TODO: will be used when PostgreSQL bidirectional sync is implemented
#![allow(dead_code)]

use async_trait::async_trait;
use chrono::{DateTime, Utc};
use std::{future::Future, sync::Arc, time::Duration};
use tokio::time::sleep;

const BACKOFF_DELAYS: [Duration; 3] = [
    Duration::from_secs(1),
    Duration::from_secs(2),
    Duration::from_secs(4),
];

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub struct SyncSummary {
    pub pushed: usize,
    pub pulled: usize,
    pub conflicts_resolved: usize,
}

impl SyncSummary {
    fn merge(self, other: Self) -> Self {
        Self {
            pushed: self.pushed + other.pushed,
            pulled: self.pulled + other.pulled,
            conflicts_resolved: self.conflicts_resolved + other.conflicts_resolved,
        }
    }
}

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum SyncError {
    #[error("sync operation failed: {0}")]
    Operation(String),
    #[error("sync operation exhausted retries after {attempts} attempts: {message}")]
    RetryExhausted { attempts: usize, message: String },
}

#[async_trait]
pub trait SyncEntity: Clone + Send + Sync + 'static {
    fn id(&self) -> String;
    fn updated_at(&self) -> DateTime<Utc>;
}

#[async_trait]
pub trait SyncRepository<E>: Send + Sync
where
    E: SyncEntity,
{
    async fn get_changes_since(&self, timestamp: DateTime<Utc>) -> Result<Vec<E>, SyncError>;
    async fn find_by_id(&self, id: &str) -> Result<Option<E>, SyncError>;
    async fn upsert(&self, entity: &E) -> Result<(), SyncError>;
    async fn mark_as_synced(&self, id: &str) -> Result<(), SyncError>;
}

pub struct SyncService<L, R> {
    local_repo: Arc<L>,
    remote_repo: Arc<R>,
}

impl<L, R> SyncService<L, R> {
    pub fn new(local_repo: Arc<L>, remote_repo: Arc<R>) -> Self {
        Self {
            local_repo,
            remote_repo,
        }
    }

    fn resolve_conflict(local_updated: DateTime<Utc>, remote_updated: DateTime<Utc>) -> bool {
        local_updated > remote_updated
    }

    async fn retry_with_backoff<F, Fut, T>(&self, mut operation: F) -> Result<T, SyncError>
    where
        F: FnMut() -> Fut,
        Fut: Future<Output = Result<T, SyncError>>,
    {
        let attempts = BACKOFF_DELAYS.len() + 1;

        for (index, delay) in BACKOFF_DELAYS.iter().enumerate() {
            match operation().await {
                Ok(value) => return Ok(value),
                Err(err) if index + 1 == attempts - 1 => {
                    return Err(SyncError::RetryExhausted {
                        attempts,
                        message: err.to_string(),
                    });
                }
                Err(_) => sleep(*delay).await,
            }
        }

        Err(SyncError::RetryExhausted {
            attempts,
            message: "retry loop exited unexpectedly".to_string(),
        })
    }
}

impl<L, R> SyncService<L, R> {
    pub async fn sync_bidirectional<E>(
        &self,
        since: DateTime<Utc>,
    ) -> Result<SyncSummary, SyncError>
    where
        E: SyncEntity,
        L: SyncRepository<E>,
        R: SyncRepository<E>,
    {
        let pushed = self.sync_local_to_remote::<E>(since).await?;
        let pulled = self.sync_remote_to_local::<E>(since).await?;

        Ok(pushed.merge(pulled))
    }

    pub async fn sync_local_to_remote<E>(
        &self,
        since: DateTime<Utc>,
    ) -> Result<SyncSummary, SyncError>
    where
        E: SyncEntity,
        L: SyncRepository<E>,
        R: SyncRepository<E>,
    {
        let changes = self
            .retry_with_backoff(|| async { self.local_repo.get_changes_since(since).await })
            .await?;

        let mut summary = SyncSummary::default();
        for entity in changes {
            let entity_id = entity.id();
            let remote = self
                .retry_with_backoff(|| async { self.remote_repo.find_by_id(&entity_id).await })
                .await?;

            let should_push = match remote {
                Some(remote_entity) => {
                    let local_wins =
                        Self::resolve_conflict(entity.updated_at(), remote_entity.updated_at());

                    if local_wins {
                        summary.conflicts_resolved += 1;
                    }

                    local_wins
                }
                None => true,
            };

            if should_push {
                self.retry_with_backoff(|| async { self.remote_repo.upsert(&entity).await })
                    .await?;
                summary.pushed += 1;
            }

            self.retry_with_backoff(|| async { self.local_repo.mark_as_synced(&entity_id).await })
                .await?;
        }

        Ok(summary)
    }

    pub async fn sync_remote_to_local<E>(
        &self,
        since: DateTime<Utc>,
    ) -> Result<SyncSummary, SyncError>
    where
        E: SyncEntity,
        L: SyncRepository<E>,
        R: SyncRepository<E>,
    {
        let changes = self
            .retry_with_backoff(|| async { self.remote_repo.get_changes_since(since).await })
            .await?;

        let mut summary = SyncSummary::default();
        for entity in changes {
            let entity_id = entity.id();
            let local = self
                .retry_with_backoff(|| async { self.local_repo.find_by_id(&entity_id).await })
                .await?;

            let should_pull = match local {
                Some(local_entity) => {
                    let local_wins =
                        Self::resolve_conflict(local_entity.updated_at(), entity.updated_at());

                    if !local_wins {
                        summary.conflicts_resolved += 1;
                    }

                    !local_wins
                }
                None => true,
            };

            if should_pull {
                self.retry_with_backoff(|| async { self.local_repo.upsert(&entity).await })
                    .await?;
                summary.pulled += 1;
            }

            self.retry_with_backoff(|| async { self.remote_repo.mark_as_synced(&entity_id).await })
                .await?;
        }

        Ok(summary)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use tokio::sync::Mutex;

    #[derive(Debug, Clone, PartialEq, Eq)]
    struct TestEntity {
        id: String,
        updated_at: DateTime<Utc>,
    }

    impl TestEntity {
        fn new(id: &str, updated_at: DateTime<Utc>) -> Self {
            Self {
                id: id.to_string(),
                updated_at,
            }
        }
    }

    #[async_trait]
    impl SyncEntity for TestEntity {
        fn id(&self) -> String {
            self.id.clone()
        }

        fn updated_at(&self) -> DateTime<Utc> {
            self.updated_at
        }
    }

    #[derive(Default)]
    struct MockSyncRepository {
        data: Mutex<HashMap<String, TestEntity>>,
        changes: Mutex<Vec<TestEntity>>,
        synced_ids: Mutex<Vec<String>>,
        fail_get_changes: AtomicUsize,
        fail_upsert: AtomicUsize,
    }

    impl MockSyncRepository {
        fn with_entities(entities: Vec<TestEntity>) -> Self {
            let data = entities
                .iter()
                .cloned()
                .map(|entity| (entity.id.clone(), entity))
                .collect();

            Self {
                data: Mutex::new(data),
                changes: Mutex::new(entities),
                synced_ids: Mutex::default(),
                fail_get_changes: AtomicUsize::new(0),
                fail_upsert: AtomicUsize::new(0),
            }
        }

        fn fail_get_changes_times(self, attempts: usize) -> Self {
            self.fail_get_changes.store(attempts, Ordering::SeqCst);
            self
        }

        async fn get_entity(&self, id: &str) -> Option<TestEntity> {
            self.data.lock().await.get(id).cloned()
        }

        async fn synced_ids(&self) -> Vec<String> {
            self.synced_ids.lock().await.clone()
        }
    }

    #[async_trait]
    impl SyncRepository<TestEntity> for MockSyncRepository {
        async fn get_changes_since(
            &self,
            timestamp: DateTime<Utc>,
        ) -> Result<Vec<TestEntity>, SyncError> {
            if self.fail_get_changes.fetch_sub(1, Ordering::SeqCst) > 0 {
                return Err(SyncError::Operation("temporary fetch failure".to_string()));
            }

            let changes = self.changes.lock().await;
            Ok(changes
                .iter()
                .filter(|entity| entity.updated_at() > timestamp)
                .cloned()
                .collect())
        }

        async fn find_by_id(&self, id: &str) -> Result<Option<TestEntity>, SyncError> {
            Ok(self.data.lock().await.get(id).cloned())
        }

        async fn upsert(&self, entity: &TestEntity) -> Result<(), SyncError> {
            if self.fail_upsert.fetch_sub(1, Ordering::SeqCst) > 0 {
                return Err(SyncError::Operation("temporary upsert failure".to_string()));
            }

            self.data
                .lock()
                .await
                .insert(entity.id.clone(), entity.clone());
            Ok(())
        }

        async fn mark_as_synced(&self, id: &str) -> Result<(), SyncError> {
            self.synced_ids.lock().await.push(id.to_string());
            Ok(())
        }
    }

    fn service() -> (
        Arc<MockSyncRepository>,
        Arc<MockSyncRepository>,
        SyncService<MockSyncRepository, MockSyncRepository>,
    ) {
        let local = Arc::new(MockSyncRepository::default());
        let remote = Arc::new(MockSyncRepository::default());
        let service = SyncService::new(Arc::clone(&local), Arc::clone(&remote));

        (local, remote, service)
    }

    #[test]
    fn resolves_conflict_with_last_write_wins() {
        let remote_updated = DateTime::parse_from_rfc3339("2026-04-08T10:00:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let local_updated = DateTime::parse_from_rfc3339("2026-04-08T10:00:01Z")
            .unwrap()
            .with_timezone(&Utc);

        assert!(
            SyncService::<MockSyncRepository, MockSyncRepository>::resolve_conflict(
                local_updated,
                remote_updated,
            )
        );
        assert!(
            !SyncService::<MockSyncRepository, MockSyncRepository>::resolve_conflict(
                remote_updated,
                local_updated,
            )
        );
    }

    #[tokio::test(start_paused = true)]
    async fn retries_until_operation_succeeds() {
        let (_local, _remote, service) = service();
        let attempts = Arc::new(AtomicUsize::new(0));
        let attempts_for_op = Arc::clone(&attempts);

        let task = tokio::spawn(async move {
            service
                .retry_with_backoff(|| {
                    let attempts = Arc::clone(&attempts_for_op);
                    async move {
                        let current = attempts.fetch_add(1, Ordering::SeqCst);
                        if current < 2 {
                            return Err(SyncError::Operation("retry me".to_string()));
                        }

                        Ok::<_, SyncError>("done")
                    }
                })
                .await
        });

        tokio::task::yield_now().await;
        tokio::time::advance(Duration::from_secs(1)).await;
        tokio::task::yield_now().await;
        tokio::time::advance(Duration::from_secs(2)).await;

        let result = task.await.unwrap().unwrap();

        assert_eq!(result, "done");
        assert_eq!(attempts.load(Ordering::SeqCst), 3);
    }

    #[tokio::test(start_paused = true)]
    async fn returns_retry_exhausted_after_max_attempts() {
        let (_local, _remote, service) = service();

        let task = tokio::spawn(async move {
            service
                .retry_with_backoff(|| async {
                    Err::<(), _>(SyncError::Operation("still failing".to_string()))
                })
                .await
        });

        tokio::task::yield_now().await;
        tokio::time::advance(Duration::from_secs(1)).await;
        tokio::task::yield_now().await;
        tokio::time::advance(Duration::from_secs(2)).await;
        tokio::task::yield_now().await;
        tokio::time::advance(Duration::from_secs(4)).await;

        let err = task.await.unwrap().unwrap_err();

        assert_eq!(
            err,
            SyncError::RetryExhausted {
                attempts: 4,
                message: "sync operation failed: still failing".to_string(),
            }
        );
    }

    #[tokio::test]
    async fn syncs_newer_local_entity_to_remote() {
        let since = DateTime::parse_from_rfc3339("2026-04-08T09:00:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let local_entity = TestEntity::new(
            "entity-1",
            DateTime::parse_from_rfc3339("2026-04-08T10:30:00Z")
                .unwrap()
                .with_timezone(&Utc),
        );
        let remote_entity = TestEntity::new(
            "entity-1",
            DateTime::parse_from_rfc3339("2026-04-08T10:00:00Z")
                .unwrap()
                .with_timezone(&Utc),
        );

        let local = Arc::new(MockSyncRepository::with_entities(
            vec![local_entity.clone()],
        ));
        let remote = Arc::new(MockSyncRepository::with_entities(vec![remote_entity]));
        let service = SyncService::new(Arc::clone(&local), Arc::clone(&remote));

        let summary = service
            .sync_local_to_remote::<TestEntity>(since)
            .await
            .unwrap();

        assert_eq!(summary.pushed, 1);
        assert_eq!(summary.conflicts_resolved, 1);
        assert_eq!(remote.get_entity("entity-1").await, Some(local_entity));
        assert_eq!(local.synced_ids().await, vec!["entity-1".to_string()]);
    }

    #[tokio::test]
    async fn syncs_remote_entity_back_to_local_when_remote_is_newer() {
        let since = DateTime::parse_from_rfc3339("2026-04-08T09:00:00Z")
            .unwrap()
            .with_timezone(&Utc);
        let local_entity = TestEntity::new(
            "entity-2",
            DateTime::parse_from_rfc3339("2026-04-08T10:00:00Z")
                .unwrap()
                .with_timezone(&Utc),
        );
        let remote_entity = TestEntity::new(
            "entity-2",
            DateTime::parse_from_rfc3339("2026-04-08T10:45:00Z")
                .unwrap()
                .with_timezone(&Utc),
        );

        let local = Arc::new(MockSyncRepository::with_entities(vec![local_entity]));
        let remote = Arc::new(MockSyncRepository::with_entities(vec![
            remote_entity.clone()
        ]));
        let service = SyncService::new(Arc::clone(&local), Arc::clone(&remote));

        let summary = service
            .sync_remote_to_local::<TestEntity>(since)
            .await
            .unwrap();

        assert_eq!(summary.pulled, 1);
        assert_eq!(summary.conflicts_resolved, 1);
        assert_eq!(local.get_entity("entity-2").await, Some(remote_entity));
        assert_eq!(remote.synced_ids().await, vec!["entity-2".to_string()]);
    }
}
