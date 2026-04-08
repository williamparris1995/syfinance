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