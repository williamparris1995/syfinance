-- Create sync_metadata table (同步元数据表)
CREATE TABLE IF NOT EXISTS sync_metadata (
    id TEXT PRIMARY KEY NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id TEXT NOT NULL,
    last_synced_at TIMESTAMP NOT NULL,
    sync_status VARCHAR(20) NOT NULL,
    CHECK (sync_status IN ('pending', 'synced', 'conflict', 'failed')),
    UNIQUE (entity_type, entity_id)
);

-- Create indexes
CREATE INDEX idx_sync_metadata_entity ON sync_metadata(entity_type, entity_id);
CREATE INDEX idx_sync_metadata_status ON sync_metadata(sync_status);
CREATE INDEX idx_sync_metadata_synced_at ON sync_metadata(last_synced_at);
