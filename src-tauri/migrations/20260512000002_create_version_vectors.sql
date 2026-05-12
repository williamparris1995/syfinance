-- Create version_vectors table for conflict detection
-- This table tracks version numbers for each entity (Account/Category) on each device
-- Used for detecting concurrent updates in multi-device synchronization

CREATE TABLE IF NOT EXISTS version_vectors (
    entity_type VARCHAR(20) NOT NULL,
    entity_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (entity_type, entity_id, device_id),
    CHECK (entity_type IN ('account', 'category'))
);

-- Index for efficient lookups by entity
CREATE INDEX idx_version_vectors_entity ON version_vectors(entity_type, entity_id);
