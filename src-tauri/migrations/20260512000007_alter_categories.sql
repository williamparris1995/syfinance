-- Add version field to categories table for version vector synchronization
ALTER TABLE categories ADD COLUMN version INTEGER NOT NULL DEFAULT 1;
