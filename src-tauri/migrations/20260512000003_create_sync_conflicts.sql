-- Create sync_conflicts table for recording synchronization conflicts
-- When concurrent update conflicts are detected, conflict information is saved to this table
-- for resolution by users or the system

CREATE TABLE IF NOT EXISTS sync_conflicts (
    id TEXT PRIMARY KEY NOT NULL,
    entity_type VARCHAR(20) NOT NULL,
    entity_id TEXT NOT NULL,
    local_version TEXT NOT NULL,
    remote_version TEXT NOT NULL,
    conflict_type VARCHAR(20) NOT NULL,
    detected_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP,
    resolution VARCHAR(20),
    CHECK (entity_type IN ('account', 'category', 'transaction', 'debt')),
    CHECK (conflict_type IN ('UPDATE_UPDATE', 'DELETE_UPDATE', 'UPDATE_DELETE'))
);

-- Index for querying conflicts by entity
CREATE INDEX idx_sync_conflicts_entity ON sync_conflicts(entity_type, entity_id);

-- Partial index for fast querying of unresolved conflicts
CREATE INDEX idx_sync_conflicts_unresolved ON sync_conflicts(resolved_at) WHERE resolved_at IS NULL;
