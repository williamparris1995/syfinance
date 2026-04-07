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

## [2026-04-07] Task 5: Currency Domain + SQLite Repository - COMPLETED
- Added `Currency` as a domain value object with ISO 4217 validation limited to exactly 3 uppercase ASCII letters.
- Implemented `CurrencyRepository` and a SQLite-backed repository that stores Decimal rates as text and maps rows back into domain objects.
- Integration tests need a clean currencies table because the base migration seeds CNY, USD, and EUR by default.
- For SQLite tests on Windows, `SqliteConnectOptions` with a fixed `test.db` path was the most reliable setup.

## Task 6: ChartOfAccounts Aggregate (2026-04-07)

### Implementation Details
- Created ChartOfAccounts aggregate with �й����׼�� (Chinese Accounting Standards) structure
- Implemented 3-level hierarchical account system (level 1: 4 digits, level 2: 4 digits, level 3: 6 digits)
- Added validation for code format, parent-child relationships, and account types
- Repository supports hierarchical queries (get_children) and filtering by level/type

### Technical Decisions
- Used INSERT OR IGNORE in seed migration to handle idempotent migrations
- Implemented datetime parsing for both SQLite format (YYYY-MM-DD HH:MM:SS) and RFC3339
- Added update() method to repository for soft delete operations
- Removed duplicate seed data from initial migration (20260407000002) to avoid conflicts

### Standard Accounts Seeded
**Level 1 (һ����Ŀ):**
- 1000: �ʲ� (Assets) - debit
- 2000: ��ծ (Liabilities) - credit
- 3000: Ȩ�� (Equity) - credit
- 4000: ���� (Income) - credit
- 5000: ֧�� (Expenses) - debit

**Level 2 (������Ŀ):**
- 1001: ����ֽ�, 1002: ���д��, 1012: ���������ʽ� (Assets)
- 2001: ���ڽ��, 2201: Ӧ���˿� (Liabilities)
- 4001: ��Ӫҵ������ (Income)
- 5001: ��Ӫҵ��ɱ�, 5201: ������� (Expenses)

### Test Results
- 11 unit tests passed (validation rules)
- 6 integration tests passed (CRUD, hierarchical queries, seed data verification)
- Evidence saved to .sisyphus/evidence/task-6-seed-data.txt and task-6-hierarchy-test.txt

### Gotchas
- SQLite CURRENT_TIMESTAMP returns format incompatible with chrono::DateTime::parse_from_rfc3339
- Solution: Use datetime('now') in migrations and parse both formats in repository
- Soft delete requires update() method, not create() with same code (UNIQUE constraint)

## [2026-04-07] Task 7: Money Value Object - COMPLETED
- Added `Money` as a Decimal-backed value object with currency-code validation, 2-decimal precision enforcement, same-currency arithmetic, comparison helpers, and exchange-rate conversion.
- Display formatting uses basic localized symbols for common currencies and thousands separators (example: `¥1,234.56`).
- Property-based tests with proptest passed for commutativity and associativity, and `cargo test money` passed end-to-end.
- Cargo still needs the full executable path `$env:USERPROFILE\.cargo\bin\cargo.exe` in this environment.
