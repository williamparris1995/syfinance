-- Migration: Add version field to accounts table
-- Date: 2026-05-12
-- Description: Add version field for version vector synchronization

ALTER TABLE accounts ADD COLUMN version INTEGER NOT NULL DEFAULT 1;
