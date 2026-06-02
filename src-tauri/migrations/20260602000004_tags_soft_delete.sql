-- Add soft delete support for tags
ALTER TABLE tags ADD COLUMN deleted_at TEXT;
ALTER TABLE tags ADD COLUMN updated_at TEXT;

-- Create index for filtering out deleted tags efficiently
CREATE INDEX IF NOT EXISTS idx_tags_deleted_at ON tags(deleted_at);
