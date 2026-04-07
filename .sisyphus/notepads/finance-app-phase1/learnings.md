# Learnings - Finance App Phase 1

## [2026-04-07] Session Start
- Starting Wave 1: Foundation tasks (8 tasks in parallel)
- Project is currently empty (only .git, .omx, .sisyphus directories)
- Target: Tauri 2.x + React + TypeScript + Rust backend with DDD architecture

## [2026-04-07] Task 1: Project Scaffolding - COMPLETED
- Successfully initialized Tauri 2.x project with React 19 + TypeScript
- Project structure created:
  - Frontend: src/pages/, src/components/, src/lib/
  - Backend DDD layers: src-tauri/src/domain/, application/, infrastructure/, presentation/
- Dependencies configured:
  - Rust: axum, sqlx, tokio, serde, rust_decimal, chrono
  - Frontend: React 19, Vite 6, Tailwind CSS 3.4, TypeScript 5.8
- Build verification: Both cargo build and pnpm install succeed
- Dev server: Vite runs on port 5173
- Cargo path: Must use full path $env:USERPROFILE\.cargo\bin\cargo.exe as cargo not in PATH

## [2026-04-07] Task 2: Database Schema - COMPLETED
- Created 9 migration files for SQLite/PostgreSQL compatibility
- All migrations applied successfully using sqlx migrate run
- Tables created:
  1. currencies (with CNY, USD, EUR defaults)
  2. chart_of_accounts (with 中国会计准则 default accounts)
  3. accounts
  4. transactions
  5. transaction_entries (with double-entry triggers)
  6. debts
  7. debt_payments
  8. reminders
  9. sync_metadata
- Key features implemented:
  - UUIDs for all primary keys (TEXT type in SQLite, UUID in PostgreSQL)
  - DECIMAL(20,2) for money amounts
  - Soft delete (deleted_at) on all synced tables
  - Sync metadata (updated_at, device_id, synced_at) on all synced tables
  - Double-entry bookkeeping enforced via SQLite triggers
  - Foreign keys with ON DELETE RESTRICT
  - Proper indexes on frequently queried columns
  - CHECK constraints for data validation
- 中国会计准则 chart of accounts:
  - 1001-1221: 资产 (Assets) - cash, bank, receivables
  - 2001-2501: 负债 (Liabilities) - loans, payables
  - 3001-4001: 权益 (Equity) - capital, profit
  - 6001-6111: 收入 (Income) - revenue, investment income
  - 6401-6603: 支出 (Expenses) - costs, fees
- sqlx-cli installation: Must use full cargo path for installation
- Database creation: Must run 'sqlx database create' before migrations
- Evidence captured: migration output and constraint test documentation

## [2026-04-07] Task 3: DDD Module Structure - COMPLETED
- Added the full Rust module skeleton under `src-tauri/src/` for domain, application, infrastructure, and presentation layers.
- Added dependency-injection traits in `src-tauri/src/domain/repositories/mod.rs` for the core repository abstractions.
- `cargo check` completed successfully and evidence was saved to `.sisyphus/evidence/task-3-module-check.txt`.
- `rust-analyzer` was not available to the LSP diagnostics tool in this environment, so verification relied on `cargo check` output.

## [2026-04-07] Task 4: Test Infrastructure - COMPLETED
- Added Vitest with React Testing Library and jsdom for frontend unit testing.
- Added `vitest.config.ts` plus a shared `vitest.setup.ts` so JSX tests run under jsdom with jest-dom matchers.
- Added example smoke tests in `src/__tests__/App.test.tsx` and `src-tauri/tests/smoke.rs` to prove both test runners execute.
- Verified `cargo test` and `pnpm vitest run` both pass; evidence saved under `.sisyphus/evidence/`.
- Cargo still needs the full executable path `$env:USERPROFILE\.cargo\bin\cargo.exe` in this environment.
