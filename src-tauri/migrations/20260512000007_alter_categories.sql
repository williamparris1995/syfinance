-- Migration: Add version column to categories
-- Note: categories table is dropped in 20260522000001, this migration is kept
-- only because sqlx requires already-applied migration files to exist.
ALTER TABLE categories ADD COLUMN version INTEGER NOT NULL DEFAULT 1;
