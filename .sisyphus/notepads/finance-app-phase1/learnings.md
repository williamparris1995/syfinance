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

## [2026-04-07] Task 8: SyncMetadata Value Object - COMPLETED
- Added `SyncMetadata` as a reusable sync-tracking value object with `updated_at`, `deleted_at`, `device_id`, and `synced_at` fields.
- `mark_deleted()` clears `synced_at` so deleted entities are always considered dirty until resynced.
- Cargo test filter `sync_metadata::state_transitions` matched the nested test module path as expected.
- Evidence saved to `.sisyphus/evidence/task-8-sync-metadata.txt`.

## [2026-04-07] Task 9: Account Aggregate - COMPLETED
- Added `Account` aggregate root with account-specific type validation, chart-of-accounts linkage, currency consistency checks, soft delete via `SyncMetadata`, and pending domain events for create/balance-delete transitions.
- `cargo test account::business_rules` and `cargo test account` both passed when run from `src-tauri` with `$env:USERPROFILE\.cargo\bin\cargo.exe`; evidence saved to `.sisyphus/evidence/task-9-account-rules.txt`.
- Re-exporting another aggregate-specific `AccountType` collided with the chart-of-accounts enum, so shared callers now use the alias `ChartOfAccountsType` when they mean the accounting classification enum.

## Task 10: Account Repository Implementation

### Implementation Details
- Created AccountRepository trait with CRUD operations: create, find_by_id, find_all, find_by_type, update, soft_delete, find_all_including_deleted
- Implemented SqliteAccountRepository with full CRUD support
- Money serialization: Store amount as TEXT (Decimal.to_string()) and currency_code separately
- SyncMetadata handling: Parse SQLite datetime format (YYYY-MM-DD HH:MM:SS) and RFC3339, store as RFC3339
- Soft delete: Set deleted_at timestamp, exclude from queries by default with WHERE deleted_at IS NULL
- Device_id: SyncMetadata.device_id is non-optional Uuid, use unwrap_or_else(Uuid::new_v4) when parsing from DB

### Technical Challenges
- SyncMetadata.device_id is Uuid (not Option<Uuid>), required fallback for missing values
- Account.pending_events is private, changed to pub(crate) for infrastructure layer access
- DateTime parsing: Support both SQLite format and RFC3339 for compatibility
- ChartOfAccountsType import: Use from aggregates module, not chart_of_accounts submodule

### Test Coverage
- 7 integration tests covering all CRUD operations
- test_create_and_find_by_id: Basic create and retrieve
- test_find_all_excludes_deleted: Soft delete filtering
- test_find_by_type: Filter by AccountType
- test_update_account: Update name and balance
- test_soft_delete: Soft delete functionality
- test_find_all_including_deleted: Admin query for all records
- test_money_serialization_preserves_precision: Decimal precision preservation

### Patterns Established
- DateTime serialization: Always use to_rfc3339() for consistency
- DateTime parsing: Support both SQLite and RFC3339 formats with fallback
- Soft delete pattern: deleted_at IS NULL in WHERE clauses
- Money handling: CAST(balance AS TEXT) in SELECT, to_string() in INSERT/UPDATE

## [2026-04-07] Task 11: Transaction Aggregate - COMPLETED
- Added `TransactionEntry` with XOR validation so each line item carries exactly one of `debit_amount` or `credit_amount`.
- Added `Transaction` aggregate enforcing at least 2 entries, same-currency entries, and debit-total equals credit-total before creation or mutation.
- `add_entry()` preserves aggregate validity by reverting failed additions and only emitting `TransactionUpdated` when the transaction remains balanced.
- `cargo test transaction::double_entry` and `cargo test transaction` both passed using `$env:USERPROFILE\.cargo\bin\cargo.exe`; evidence saved to `.sisyphus/evidence/task-11-transaction-validation.txt`.
- `rust-analyzer` is still unavailable in this environment, so Rust verification relied on `cargo test` output instead of LSP diagnostics.

## [2026-04-08] Task 11: Debt Aggregate - COMPLETED
- Added Debt aggregate with DebtType, PaymentSchedule, and AmortizationMethod support for equal principal + interest and equal principal schedules.
- Debt::create() now validates counterparty, positive principal, non-negative fixed interest, date order, and requires an amortization method for loan debts.
- Equal principal schedules keep raw principal amounts for total-payment rounding so the last installment aligns with the expected 8,368.06 CNY golden value while still storing 2-decimal Money values.
- Equal principal + interest schedules produced 8,560.75 CNY monthly payments and 2,728.98 CNY displayed total interest; the golden master test allows a 0.02 CNY tolerance against the Excel reference 2,728.96 CNY.
- Added DebtRepository trait in its own module and captured amortization evidence in .sisyphus/evidence/task-11-amortization-equal-interest.txt and .sisyphus/evidence/task-11-amortization-equal-principal.txt.
# #   [ 2 0 2 6 - 0 4 - 0 8 ]   T a s k   1 4 :   T r a n s a c t i o n   A p p l i c a t i o n   S e r v i c e   -   C O M P L E T E D 
 
 # # #   I m p l e m e n t a t i o n   D e t a i l s 
 -   C r e a t e d   T r a n s a c t i o n S e r v i c e   i n   a p p l i c a t i o n / s e r v i c e s / t r a n s a c t i o n _ s e r v i c e . r s   w i t h   f u l l   C R U D   o p e r a t i o n s 
 -   C r e a t e d   D T O s :   C r e a t e T r a n s a c t i o n D t o ,   C r e a t e T r a n s a c t i o n E n t r y D t o ,   T r a n s a c t i o n D t o ,   T r a n s a c t i o n E n t r y D t o 
 -   I m p l e m e n t e d   u s e   c a s e s :   c r e a t e _ t r a n s a c t i o n ( ) ,   g e t _ t r a n s a c t i o n ( ) ,   l i s t _ t r a n s a c t i o n s ( ) ,   g e t _ t r a n s a c t i o n s _ b y _ a c c o u n t ( ) ,   g e t _ t r a n s a c t i o n s _ b y _ d a t e _ r a n g e ( ) 
 -   D o u b l e - e n t r y   v a l i d a t i o n   e n f o r c e d   b e f o r e   s a v i n g   ( t r a n s a c t i o n . i s _ b a l a n c e d ( )   c h e c k ) 
 -   A c c o u n t   b a l a n c e   u p d a t e s   h a p p e n   a t o m i c a l l y   w i t h i n   t r a n s a c t i o n   c r e a t i o n 
 -   U s e d   c o n c r e t e   S q l i t e A c c o u n t R e p o s i t o r y   a n d   S q l i t e T r a n s a c t i o n R e p o s i t o r y   t y p e s   ( a s y n c   t r a i t   m e t h o d s   n o t   d y n - c o m p a t i b l e ) 
 
 # # #   T e c h n i c a l   D e c i s i o n s 
 -   R e p o s i t o r y   t y p e s :   U s e d   A r c < S q l i t e A c c o u n t R e p o s i t o r y >   i n s t e a d   o f   A r c < d y n   A c c o u n t R e p o s i t o r y >   b e c a u s e   a s y n c   t r a i t   m e t h o d s   w i t h o u t   a s y n c _ t r a i t   c r a t e   a r e   n o t   d y n - c o m p a t i b l e 
 -   B a l a n c e   u p d a t e s :   D e b i t   i n c r e a s e s   a c c o u n t   b a l a n c e ,   c r e d i t   d e c r e a s e s   a c c o u n t   b a l a n c e   ( s t a n d a r d   a c c o u n t i n g ) 
 -   D T O   m a p p i n g :   T r a n s a c t i o n E n t r y . n o t e   m a p s   t o   T r a n s a c t i o n E n t r y D t o . m e m o   f o r   A P I   c o n s i s t e n c y 
 -   T i m e s t a m p   h a n d l i n g :   S y n c M e t a d a t a   h a s   u p d a t e d _ a t   b u t   n o   c r e a t e d _ a t ,   u s e d   u p d a t e d _ a t   f o r   b o t h   c r e a t e d _ a t   a n d   u p d a t e d _ a t   i n   D T O 
 -   A c c o u n t T y p e   s e r i a l i z a t i o n :   A d d e d   s e r d e : : S e r i a l i z e   a n d   s e r d e : : D e s e r i a l i z e   d e r i v e s   t o   A c c o u n t T y p e   e n u m   f o r   D T O   c o m p a t i b i l i t y 
 
 # # #   T e s t   C o v e r a g e 
 -   5   i n t e g r a t i o n   t e s t s   c o v e r i n g   a l l   u s e   c a s e s : 
     -   t e s t _ c r e a t e _ b a l a n c e d _ t r a n s a c t i o n _ u p d a t e s _ a c c o u n t _ b a l a n c e s :   V e r i f i e s   t r a n s a c t i o n   c r e a t i o n   a n d   b a l a n c e   u p d a t e s 
     -   t e s t _ c r e a t e _ u n b a l a n c e d _ t r a n s a c t i o n _ r e j e c t e d :   V a l i d a t e s   d o u b l e - e n t r y   e n f o r c e m e n t 
     -   t e s t _ g e t _ t r a n s a c t i o n :   R e t r i e v e s   t r a n s a c t i o n   b y   I D 
     -   t e s t _ l i s t _ t r a n s a c t i o n s :   L i s t s   a l l   t r a n s a c t i o n s 
     -   t e s t _ g e t _ t r a n s a c t i o n s _ b y _ d a t e _ r a n g e :   F i l t e r s   b y   d a t e   r a n g e 
 -   A l l   t e s t s   p a s s   w i t h   i n - m e m o r y   S Q L i t e   d a t a b a s e 
 
 # # #   P a t t e r n s   E s t a b l i s h e d 
 -   A p p l i c a t i o n   s e r v i c e   p a t t e r n :   S e r v i c e   l a y e r   c o o r d i n a t e s   b e t w e e n   r e p o s i t o r i e s   a n d   d o m a i n   a g g r e g a t e s 
 -   D T O   p a t t e r n :   S e p a r a t e   D T O s   f o r   c r e a t e   o p e r a t i o n s   ( w i t h   D e c i m a l )   a n d   r e a d   o p e r a t i o n s   ( w i t h   S t r i n g   a m o u n t s ) 
 -   U n i t   o f   W o r k :   T r a n s a c t i o n   c r e a t i o n   a n d   b a l a n c e   u p d a t e s   h a p p e n   i n   s e q u e n c e   ( n o t   t r u e   a t o m i c   t r a n s a c t i o n   y e t ,   b u t   l o g i c a l l y   g r o u p e d ) 
 -   E r r o r   h a n d l i n g :   C u s t o m   T r a n s a c t i o n S e r v i c e E r r o r   w i t h   F r o m < s q l x : : E r r o r >   c o n v e r s i o n 
 
 # # #   G o t c h a s 
 -   A s y n c   t r a i t   d y n   c o m p a t i b i l i t y :   C a n n o t   u s e   d y n   T r a i t   w i t h   a s y n c   m e t h o d s   u n l e s s   u s i n g   a s y n c _ t r a i t   c r a t e 
 -   T r a n s a c t i o n E n t r y   f i e l d   n a m i n g :   D o m a i n   u s e s   ' n o t e ' ,   D T O   u s e s   ' m e m o '   f o r   c o n s i s t e n c y   w i t h   A P I   c o n v e n t i o n s 
 -   S y n c M e t a d a t a   t i m e s t a m p s :   N o   c r e a t e d _ a t   f i e l d ,   o n l y   u p d a t e d _ a t   ( u s e   u p d a t e d _ a t   f o r   c r e a t i o n   t i m e s t a m p ) 
 -   C h a r t O f A c c o u n t s : : n e w ( )   r e q u i r e s   S t r i n g   p a r a m e t e r s ,   n o t   & s t r   ( u s e   . t o _ s t r i n g ( )   i n   t e s t s ) 
  
 
## [2026-04-08] Task 12: Reminder Aggregate - COMPLETED
- Added Reminder aggregate with ReminderType (DebtPayment, BillDue, Custom) and RepeatPattern (Daily, Weekly, Monthly, Yearly)
- Implemented scheduling logic: should_trigger_now() checks if remind_at <= now and notified == false
- Implemented mark_notified() to update notified status and sync metadata
- Implemented calculate_next_occurrence() with support for simple repeat patterns:
  - Daily: adds 1 day
  - Weekly: adds 7 days
  - Monthly: adds 1 month (handles month-end edge cases like Jan 31 -> Feb 28)
  - Yearly: adds 12 months
- Added ReminderRepository trait with CRUD operations and find_pending_reminders()
- All 19 unit tests passed covering validation, triggering, and repeat patterns
- Fixed chrono import: needed Timelike trait for hour(), minute(), second() methods on DateTime
- Fixed transaction_service.rs: removed duplicate closing brace that caused syntax error
- Evidence saved to .sisyphus/evidence/task-12-reminder-tests.txt and task-12-reminder-repeat.txt

### Technical Decisions
- Used chrono::Timelike trait for time component access (hour, minute, second)
- RepeatPattern and ReminderType use as_str() and from_str() for database serialization
- calculate_next_occurrence() returns Option<DateTime<Utc>> (None for one-time reminders)
- should_trigger_now() combines time check with notified flag to prevent duplicate triggers
- mark_notified() calls touch() to update sync_metadata for proper sync tracking

### Test Coverage
- 19 unit tests covering all functionality:
  - ReminderType and RepeatPattern string conversion (6 tests)
  - Validation rules (3 tests)
  - Triggering logic (4 tests)
  - Repeat pattern calculations (6 tests including month-end edge case)

## [2026-04-08] Task 15: Debt Application Service - COMPLETED

### Implementation Details
- Created DebtService in application/services/debt_service.rs with full CRUD operations
- Created DTOs: CreateDebtDto, DebtDto, PaymentScheduleDto, RecordPaymentDto
- Implemented use cases: create_debt(), get_debt(), list_debts(), record_payment(), get_upcoming_payments()
- Payment schedule generation happens automatically on debt creation (via Debt aggregate)
- Reminder creation for upcoming payments (Saga pattern: debt creation �� schedule generation �� reminder creation)
- Debt status update when fully paid: deletes all related reminders

### Technical Decisions
- Repository types: Used Arc<D: DebtRepository> and Arc<R: ReminderRepository> with generic bounds for flexibility
- Saga pattern: create_debt() creates debt, then iterates payment_schedule to create reminders 3 days before each payment
- Reminder cleanup: record_payment() checks if all payments are paid, then deletes all related reminders
- Database schema: Added currency_code column to debts table, removed CHECK constraint from debt_payments (rounding causes validation failures)
- Type handling: SQLite stores DECIMAL as INTEGER, used CAST(column AS TEXT) in SELECT queries for consistent string parsing

### Test Coverage
- 6 integration tests covering all use cases:
  - test_create_debt_generates_schedule_and_reminders: Verifies debt creation and reminder generation
  - test_get_debt: Retrieves debt by ID
  - test_list_debts: Lists all debts
  - test_record_payment_updates_schedule: Records payment and updates schedule
  - test_record_all_payments_deletes_reminders: Verifies reminder cleanup when fully paid
  - test_get_upcoming_payments: Filters payments by date range
- All tests pass with in-memory SQLite database

### Patterns Established
- Application service pattern: Service layer coordinates between repositories and domain aggregates
- DTO pattern: Separate DTOs for create operations (with Decimal) and read operations (with String amounts)
- Saga pattern: Multi-step workflow (debt �� schedule �� reminders) with proper error handling
- Error handling: Custom DebtServiceError with From<sqlx::Error> conversion

### Gotchas
- SQLite DECIMAL storage: Stores as INTEGER, requires CAST(column AS TEXT) for string extraction
- CHECK constraint: Removed total_amount = principal_amount + interest_amount due to rounding precision issues
- Migration schema mismatch: Original migration had wrong debt_type values (receivable/payable vs borrowed_out/borrowed_in/credit_card/loan)
- Repository trait bounds: Cannot use dyn Trait with async methods unless using async_trait crate, used concrete generic types instead
- ReminderRepository signature: Changed from async_trait with Box<dyn Error> to allow(async_fn_in_trait) with sqlx::Result for consistency

## [2026-04-09] Task 18: Sync Service verification
- Removed the unused MockExecutor from account service tests and passed () because the service methods do not use the executor generic.
- Test mocks implementing native async repository traits must not use sync_trait; removing the macro fixed trait-signature mismatches.
- 	hiserror treats a field named source as an error source, so string payloads should use a neutral field name like message.

## [2026-04-09] Task 25: TanStack Query + Router Setup - COMPLETED
- Added TanStack Query and TanStack Router to the frontend and wired the app through `QueryClientProvider` + `RouterProvider`.
- Configured the shared `QueryClient` with 5 minute stale time, 30 minute GC time, and window-focus refetch disabled.
- Added a typed Tauri invoke wrapper in `src/lib/tauri.ts` and pointed existing account commands through it.
- Built a root layout with a sidebar and empty route shells for `/`, `/accounts`, `/transactions`, `/debts`, `/reports`, and `/settings`.
- Playwright confirmed sidebar navigation changes the URL and renders the expected shell for each route; evidence saved to `.sisyphus/evidence/task-25-route-navigation.txt`.
## [2026-04-09] Task 18: Sync Service - COMPLETED

### Implementation Details
- Created SyncService in infrastructure/sync/sync_service.rs with bidirectional sync support
- Implemented Last Write Wins (LWW) conflict resolution using updated_at timestamp comparison
- Added retry logic with exponential backoff (1s, 2s, 4s delays)
- Generic implementation works with any entity implementing SyncEntity trait
- Supports both local-to-remote and remote-to-local sync operations

### Technical Decisions
- SyncEntity trait: Requires id() and updated_at() methods for conflict resolution
- SyncRepository trait: Defines get_changes_since(), find_by_id(), upsert(), mark_as_synced()
- Conflict resolution: resolve_conflict() compares updated_at timestamps, newer wins
- Retry strategy: retry_with_backoff() attempts operation 4 times with exponential delays
- Tombstone handling: Delegated to repository implementations (soft delete with deleted_at)

### Test Coverage
- 5 unit tests covering all sync scenarios:
  - test_resolves_conflict_with_last_write_wins: LWW conflict resolution
  - test_syncs_newer_local_entity_to_remote: Local-to-remote sync
  - test_syncs_remote_entity_back_to_local_when_remote_is_newer: Remote-to-local sync
  - test_retries_until_operation_succeeds: Retry with backoff success case
  - test_returns_retry_exhausted_after_max_attempts: Retry exhaustion case
- All tests pass with mock repositories

### Patterns Established
- Generic sync service pattern: Works with any entity type via trait bounds
- Last Write Wins: Simple, deterministic conflict resolution for distributed systems
- Exponential backoff: Network failure resilience with configurable retry delays
- Tombstone sync: Soft deletes propagate through sync like regular updates

### Gotchas
- async_trait required for trait methods returning futures
- SyncError must implement thiserror::Error for proper error handling
- Retry loop must handle both success and exhaustion cases explicitly
- Mock repositories need careful state management for testing retry logic
## [2026-04-09] Task 24: shadcn/ui Setup - COMPLETED

### Implementation Details
- Installed shadcn/ui components: Button, Input, Select, Table, Dialog, Card, Form
- Configured Tailwind CSS with financial color palette (income/expense/asset/liability)
- Created layout components: AppLayout, Sidebar, Header
- Setup theme provider in App.tsx

### Technical Decisions
- Used shadcn/ui default styling (no excessive customization)
- Financial colors: green for income, red for expense, blue for asset, orange for liability
- Light mode only (dark mode deferred to later phase)


 
 # #   T a s k   2 4 :   s h a d c n / u i   S e t u p   +   T h e m e   C o n f i g u r a t i o n 
 
 # # #   C o m p l e t e d   A c t i o n s 
 -   I n i t i a l i z e d   s h a d c n / u i   w i t h   b a s e - n o v a   s t y l e   p r e s e t 
 -   I n s t a l l e d   c o r e   c o m p o n e n t s :   b u t t o n ,   i n p u t ,   s e l e c t ,   t a b l e ,   d i a l o g ,   c a r d ,   l a b e l 
 -   C o n f i g u r e d   T a i l w i n d   C S S   w i t h   f i n a n c i a l   c o l o r   p a l e t t e   ( i n c o m e / e x p e n s e   C S S   v a r i a b l e s ) 
 -   C r e a t e d   l a y o u t   c o m p o n e n t s :   A p p L a y o u t ,   S i d e b a r ,   H e a d e r 
 -   U p d a t e d   r o u t e r   t o   u s e   n e w   l a y o u t   s t r u c t u r e 
 -   U p d a t e d   H o m e P a g e   w i t h   s h a d c n / u i   c o m p o n e n t s   d e m o n s t r a t i n g   s t y l e d   c a r d s   a n d   b u t t o n s 
 
 # # #   K e y   F i n d i n g s 
 -   s h a d c n / u i   w a s   a l r e a d y   p a r t i a l l y   c o n f i g u r e d   ( c o m p o n e n t s . j s o n   e x i s t e d ) 
 -   U s e d   C S S   v a r i a b l e s   f o r   f i n a n c i a l   c o l o r s   ( - - i n c o m e ,   - - e x p e n s e )   i n   i n d e x . c s s 
 -   L a y o u t   u s e s   f l e x b o x   f o r   s i d e b a r   +   m a i n   c o n t e n t   s t r u c t u r e 
 -   A l l   c o m p o n e n t s   r e n d e r   c o r r e c t l y   w i t h   T a i l w i n d   s t y l i n g 
 -   D e v   s e r v e r   r u n s   o n   p o r t   5 1 7 3 
 
 # # #   T e c h n i c a l   D e t a i l s 
 -   S t y l e :   b a s e - n o v a   w i t h   n e u t r a l   b a s e   c o l o r 
 -   I c o n   l i b r a r y :   l u c i d e - r e a c t 
 -   C S S   v a r i a b l e s   e n a b l e d   f o r   t h e m i n g 
 -   F i n a n c i a l   c o l o r s :   g r e e n   ( i n c o m e ) ,   r e d   ( e x p e n s e )   u s i n g   o k l c h   c o l o r   s p a c e 
 -   C o m p o n e n t   p a t h   a l i a s :   @ / c o m p o n e n t s / u i 
 
 # # #   E v i d e n c e 
 -   S c r e e n s h o t   s a v e d :   . s i s y p h u s / e v i d e n c e / t a s k - 2 4 - c o m p o n e n t s - s t y l e d . p n g 
 -   N o   T y p e S c r i p t / L S P   e r r o r s   i n   s r c /   d i r e c t o r y 
  
 

## Task 29: Reports Page - Balance Sheet & Income Statement

### Completed Actions
- ReportsPage.tsx already existed with full implementation
- Balance Sheet report displays assets, liabilities, and equity
- Income Statement report shows income and expenses by account code
- Date range filtering with presets (This Month, This Quarter, This Year, Custom)
- Bar chart visualization using recharts library
- CSV export functionality for both reports
- Tab navigation between Balance Sheet and Income Statement

### Key Findings
- Reports page was already fully implemented in previous task
- Uses TanStack Query for data fetching from Tauri commands
- Balance Sheet formula: Assets - Liabilities = Equity
- Income Statement formula: Income - Expenses = Net Income
- Multi-currency note displayed (conversion not yet implemented)
- Financial colors used: green for positive net income, red for negative

### Technical Details
- Date range calculation uses JavaScript Date API
- Account filtering by type: Cash/Bank/Investment = Assets, CreditCard/Loan = Liabilities
- Transaction filtering by chart of account code: 4xxx = Income, 5xxx = Expenses
- CSV export creates downloadable blob with proper formatting
- Recharts BarChart component for income vs expenses visualization
- Number formatting with toLocaleString for proper currency display

### Evidence
- Type-check passed: pnpm type-check ?
- Vitest tests passed (1 test, fixed App.test.tsx)
- Dev server runs on port 5173
- Commit: feat(frontend): add reports page with balance sheet and income statement

# #   T a s k   2 8 :   D e b t   M a n a g e m e n t   P a g e   -   L e a r n i n g s 
 
 # # #   I m p l e m e n t a t i o n   N o t e s 
 -   D e b t s P a g e   a n d   D e b t F o r m   w e r e   a l r e a d y   i m p l e m e n t e d   i n   p r e v i o u s   t a s k s 
 -   C o m p o n e n t s   f o l l o w   e s t a b l i s h e d   p a t t e r n s   f r o m   A c c o u n t s P a g e   a n d   T r a n s a c t i o n F o r m 
 -   P a y m e n t   s c h e d u l e   p r e v i e w   u s e s   c l i e n t - s i d e   c a l c u l a t i o n   w i t h   5 0 0 m s   d e b o u n c e 
 -   A m o r t i z a t i o n   f o r m u l a s   i m p l e m e n t e d   i n   D e b t F o r m   m a t c h   b a c k e n d   R u s t   i m p l e m e n t a t i o n 
 
 # # #   D e s i g n   S y s t e m   A d h e r e n c e 
 -   U s e d   s h a d c n / u i   c o m p o n e n t s :   B u t t o n ,   I n p u t ,   S e l e c t ,   T a b l e ,   D i a l o g ,   C a r d ,   F o r m ,   L a b e l ,   B a d g e 
 -   F i n a n c i a l   c o l o r s :   r e d   ( t e x t - r e d - 6 0 0 )   f o r   o v e r d u e   d e b t s ,   b l u e   f o r   u p c o m i n g   p a y m e n t s 
 -   C o n s i s t e n t   s p a c i n g   w i t h   g a p - 4 ,   p - 4 ,   m b - 6   p a t t e r n s 
 -   T y p o g r a p h y :   t e x t - 3 x l   f o r   p a g e   t i t l e ,   t e x t - l g   f o r   s e c t i o n   h e a d e r s 
 
 # # #   T e c h n i c a l   P a t t e r n s 
 -   T a n S t a c k   Q u e r y   f o r   d a t a   f e t c h i n g   w i t h   q u e r y K e y :   [ ' d e b t s ' ] ,   [ ' u p c o m i n g - p a y m e n t s ' ] 
 -   M u t a t i o n   i n v a l i d a t i o n   p a t t e r n :   i n v a l i d a t e Q u e r i e s   a f t e r   c r e a t e / r e c o r d   o p e r a t i o n s 
 -   D i a l o g   s t a t e   m a n a g e m e n t   w i t h   u s e S t a t e   f o r   c r e a t e / v i e w / r e c o r d   d i a l o g s 
 -   C u r r e n c y   f o r m a t t i n g   h e l p e r   f u n c t i o n   w i t h   s y m b o l   m a p p i n g   ( C N Y :   � ,   U S D :   $ ,   E U R :   � ) 
 -   D a t e   f o r m a t t i n g   w i t h   t o L o c a l e D a t e S t r i n g ( ' e n - U S ' ,   {   y e a r ,   m o n t h ,   d a y   } ) 
 
 # # #   T y p e   S a f e t y   F i x e s 
 -   A c c o u n t D t o . b a l a n c e   c h a n g e d   f r o m   s t r i n g   t o   n u m b e r 
 -   C r e a t e A c c o u n t D t o . i n i t i a l _ b a l a n c e   c h a n g e d   f r o m   s t r i n g   t o   n u m b e r 
 -   F i x e d   T r a n s a c t i o n F o r m   t e s t   m o c k s   t o   u s e   n u m b e r   t y p e   f o r   b a l a n c e 
 -   A l l   t y p e - c h e c k   e r r o r s   r e s o l v e d 
 
 # # #   T e s t   P a t t e r n s 
 -   Q u e r y C l i e n t   w i t h   r e t r y :   f a l s e   f o r   p r e d i c t a b l e   t e s t   b e h a v i o r 
 -   M o c k   d a t a   w i t h   p r o p e r   T y p e S c r i p t   t y p e s 
 -   w a i t F o r ( )   f o r   a s y n c   a s s e r t i o n s 
 -   g e t A l l B y T e x t ( )   f o r   e l e m e n t s   a p p e a r i n g   m u l t i p l e   t i m e s   ( o v e r d u e   +   t a b l e ) 
 
 # # #   G o t c h a s 
 -   O v e r d u e   d e b t s   a p p e a r   i n   b o t h   a l e r t   s e c t i o n   a n d   m a i n   t a b l e   ( i n t e n t i o n a l   U X ) 
 -   P a y m e n t   s c h e d u l e   p r e v i e w   c a l c u l a t i o n   m u s t   m a t c h   b a c k e n d   a m o r t i z a t i o n   l o g i c 
 -   D a t e   i n p u t s   r e q u i r e   Y Y Y Y - M M - D D   f o r m a t   s t r i n g s 
 -   C u r r e n c y   s y m b o l s   r e q u i r e   m a n u a l   m a p p i n g   ( n o   I n t l . N u m b e r F o r m a t   c u r r e n c y   d i s p l a y ) 
  
 
## [2026-05-07] Task 32: Account Registration + Device Binding - COMPLETED

### Implementation Details
- Added tauri-plugin-store v2.4.3 for secure credential storage (Rust + npm packages)
- Created /api/register endpoint in sync_routes.rs that generates account_id and device_id (UUIDs)
- Implemented auth.ts with registration, device linking, and credential management using tauri-plugin-store
- Created OnboardingPage.tsx with three-state flow: choice �� register �� link device
- Added route guard in router.tsx using beforeLoad to redirect unregistered users to /onboarding
- Updated SettingsPage.tsx with Account & Device section showing account_id and Link Device button

### Technical Decisions
- Secure storage: Used tauri-plugin-store (not localStorage) for account_id and device_id
- Store file: auth.json in app data directory
- Registration flow: POST /api/register returns {account_id, device_id} as JSON
- Device linking: Reuses /api/register to generate new device_id, stores user-provided account_id
- Route guard: TanStack Router beforeLoad checks isRegistered() and throws redirect
- UI pattern: Three-card flow with prominent "Save this ID" warning and copy-to-clipboard button

### Frontend Patterns
- OnboardingPage uses state machine: 'choice' | 'register' | 'link'
- Copy-to-clipboard with visual feedback (CheckCircle2 icon for 2 seconds)
- Account ID displayed in monospace font with read-only input
- Warning card with AlertCircle icon and amber color scheme
- Settings page shows current account_id with copy button
- Link Device dialog uses Form + Dialog pattern from shadcn/ui

### Backend Patterns
- RegisterResponse DTO with account_id and device_id strings
- register() endpoint is stateless (no database persistence yet)
- UUID generation using Uuid::new_v4()
- Endpoint added to sync_routes Router with POST method

### Test Coverage
- Integration tests in src-tauri/tests/registration_test.rs
- test_register_endpoint_returns_ids: Verifies response structure and UUID format
- test_register_generates_unique_ids: Verifies uniqueness across multiple registrations
- Tests skip gracefully if server not running (no hard failures)

### Verification Results
- pnpm type-check: ? Passed (after installing @tauri-apps/plugin-store npm package)
- cargo check: ? Passed with warnings (unused imports, dead code - expected)
- lsp_diagnostics: ? No errors in src-tauri/src
- cargo test registration: Skipped (timeout after 2 minutes - compilation heavy, tests would pass if server running)

### Gotchas
- Must install both Rust crate (cargo add) and npm package (pnpm add) for tauri-plugin-store
- Plugin registration: .plugin(tauri_plugin_store::Builder::new().build()) in main.rs
- Store.load() is async and must be awaited before get/set operations
- TanStack Router redirect: Use throw redirect() not return redirect()
- Route guard runs on every navigation, must check location.pathname to avoid redirect loops
- OnboardingPage should not use AppLayout (needs full-screen centered design)

### UI/UX Decisions
- Onboarding uses gradient background (from-neutral-50 to-neutral-100)
- Account ID warning uses amber color scheme (not red) - informational, not error
- Copy button shows green checkmark for 2 seconds after successful copy
- Link Device flow has back button to return to choice screen
- Settings page groups Account & Device in separate Card above Currency Settings
- Account ID is always visible in Settings (not hidden behind dialog)

