# Account Module P3 Deferred Items — Decimal Migration & PG Repository

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the final 2 deferred P3 items — migrate account monetary fields from TEXT to INTEGER cents (P16), and complete the PostgreSQL account repository (P21).

**Architecture:** Add `to_cents()`/`from_cents()` conversion to the Money value object. Create a migration that converts the 3 monetary columns in `accounts` table from DECIMAL/TEXT to INTEGER cents. Update both SQLite and PG repositories to read/write i64 cents directly. PG repository also gets the 9 missing fields. `interest_rate` stays as TEXT (it's a percentage rate, not money — converting to basis points is a separate decision).

**Spec:** `docs/superpowers/specs/2026-06-05-account-modification-audit-design.md` (P16, P21)

**Previous plans:**
- Sprint 1: `docs/superpowers/plans/2026-06-05-account-module-critical-fixes.md` ✅
- Sprint 2: `docs/superpowers/plans/2026-06-05-account-module-sprint2.md` ✅
- Sprint 3: `docs/superpowers/plans/2026-06-06-account-module-sprint3.md` ✅
- Sprint 4: `docs/superpowers/plans/2026-06-06-account-module-sprint4.md` ✅

---

## Scope Notes

**P16 scope — account module only:** The `accounts` table has 3 monetary columns to convert (`initial_balance`, `credit_limit`, `low_balance_threshold`). The `interest_rate` column stays as TEXT since it's a percentage, not a monetary amount. Other tables (transactions, debts, holdings, budgets, goals) have the same TEXT storage issue but are out of scope for this account module sprint. Follow-up sprints can apply the same pattern.

**P21 scope — account PG repository only:** Add the 9 missing fields (8 + `status`) to the PG repository's SELECT queries, `row_to_account` function, and `create` INSERT. The `update` method already writes most of these fields.

---

## Task 1: Add Cents Conversion to Money Value Object

**Files:**
- Modify: `src-tauri/src/domain/value_objects/money.rs`

### Context

The `Money` struct holds `amount: Decimal` and `currency_code: String`. Currently, DB serialization is done manually in each repository via `amount.to_string()` (TEXT) and `Decimal::from_str()` (parse). We need `to_cents()` / `from_cents()` methods for the new INTEGER storage.

### Steps:

- [ ] **Step 1: Add `to_cents` method to Money**

In `src-tauri/src/domain/value_objects/money.rs`, add these methods to the `impl Money` block:

```rust
/// Convert the monetary amount to integer cents.
/// e.g., Decimal("1234.56") → 123456i64
/// Rounds half-away-from-zero to handle floating-point imprecision.
pub fn to_cents(&self) -> i64 {
    use rust_decimal::prelude::ToPrimitive;
    // Multiply by 100 and round to nearest integer
    let cents = self.amount * Decimal::ONE_HUNDRED;
    cents.round_dp(0).to_i64().unwrap_or(0)
}

/// Create a Money from integer cents.
/// e.g., 123456i64 → Money { amount: Decimal("1234.56"), currency_code }
pub fn from_cents(cents: i64, currency_code: String) -> Self {
    Self {
        amount: Decimal::new(cents, 2), // cents / 100
        currency_code,
    }
}
```

- [ ] **Step 2: Add standalone Decimal-to-cents helper**

For `low_balance_threshold` (which is a plain `Option<Decimal>`, not wrapped in `Money`), add a free function or method:

```rust
/// Convert a Decimal amount to integer cents.
pub fn decimal_to_cents(amount: Decimal) -> i64 {
    use rust_decimal::prelude::ToPrimitive;
    let cents = amount * Decimal::ONE_HUNDRED;
    cents.round_dp(0).to_i64().unwrap_or(0)
}

/// Convert integer cents back to Decimal.
pub fn cents_to_decimal(cents: i64) -> Decimal {
    Decimal::new(cents, 2)
}
```

- [ ] **Step 3: Run tests**

```bash
cd src-tauri && cargo test --lib value_objects::money
```

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat(domain): add to_cents/from_cents conversion to Money value object"
```

---

## Task 2: Create DB Migration — Convert Monetary Columns to INTEGER

**Files:**
- Create: `src-tauri/migrations/YYYYMMDDHHMMSS_convert_accounts_monetary_to_cents.sql`

### Context

The `accounts` table currently has `initial_balance DECIMAL(20,2)`, `credit_limit DECIMAL(20,2)`, `low_balance_threshold DECIMAL(20,2)` — all stored as TEXT by SQLite. We need to convert these to INTEGER cents.

SQLite doesn't support ALTER COLUMN. The standard migration pattern is: create new table → copy data → drop old → rename.

### Steps:

- [ ] **Step 1: Read the current canonical schema**

Read `src-tauri/migrations/20260606000003_add_created_at_to_accounts.sql` to get the latest CREATE TABLE. This is the authoritative schema.

- [ ] **Step 2: Create the migration file**

Create `src-tauri/migrations/20260608000001_convert_accounts_monetary_to_cents.sql` with:

```sql
-- P16: Convert monetary TEXT columns to INTEGER cents
-- initial_balance: DECIMAL(20,2) → INTEGER (cents)
-- credit_limit: DECIMAL(20,2) → INTEGER (cents)
-- low_balance_threshold: DECIMAL(20,2) → INTEGER (cents)
-- interest_rate: DECIMAL(5,4) stays as TEXT (percentage rate, not money)

-- Step 1: Create new table with INTEGER monetary columns
CREATE TABLE accounts_new (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    account_type TEXT NOT NULL CHECK (account_type IN ('Cash', 'Bank', 'CreditCard', 'Investment', 'BorrowedOut', 'BorrowedIn', 'Prepaid', 'Other', 'Income', 'Expense')),
    ownership TEXT NOT NULL CHECK (ownership IN ('own', 'external', 'liability')),
    currency_code TEXT NOT NULL,
    initial_balance INTEGER NOT NULL,
    icon TEXT NOT NULL DEFAULT '💰',
    color TEXT NOT NULL DEFAULT '#10B981',
    chart_code TEXT,
    parent_id TEXT,
    account_number TEXT,
    institution TEXT,
    credit_limit INTEGER,
    billing_day INTEGER,
    payment_due_day INTEGER,
    interest_rate TEXT,
    low_balance_threshold INTEGER,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived', 'hidden')),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    opened_at TEXT,
    updated_at TEXT NOT NULL,
    deleted_at TEXT,
    device_id TEXT,
    synced_at TEXT,
    FOREIGN KEY (parent_id) REFERENCES accounts(id)
);

-- Step 2: Copy data with conversion
-- ROUND handles floating-point imprecision from CAST(... AS REAL)
-- Divide by 100 to get the real value, multiply by 100, round, cast to integer
INSERT INTO accounts_new (
    id, name, account_type, ownership, currency_code,
    initial_balance, icon, color, chart_code, parent_id,
    account_number, institution, credit_limit,
    billing_day, payment_due_day, interest_rate,
    low_balance_threshold, status, created_at, opened_at,
    updated_at, deleted_at, device_id, synced_at
)
SELECT
    id, name, account_type, ownership, currency_code,
    CAST(ROUND(CAST(initial_balance AS REAL) * 100) AS INTEGER),
    icon, color, chart_code, parent_id,
    account_number, institution,
    CASE WHEN credit_limit IS NOT NULL THEN CAST(ROUND(CAST(credit_limit AS REAL) * 100) AS INTEGER) ELSE NULL END,
    billing_day, payment_due_day, interest_rate,
    CASE WHEN low_balance_threshold IS NOT NULL THEN CAST(ROUND(CAST(low_balance_threshold AS REAL) * 100) AS INTEGER) ELSE NULL END,
    status, created_at, opened_at,
    updated_at, deleted_at, device_id, synced_at
FROM accounts;

-- Step 3: Drop old table and rename
DROP TABLE accounts;
ALTER TABLE accounts_new RENAME TO accounts;

-- Step 4: Recreate indexes (if any existed on the old table)
-- The original schema had no explicit indexes beyond PRIMARY KEY
```

**IMPORTANT:** Before creating this migration, check the highest migration number already in `src-tauri/migrations/` and use the next sequential number. The migration runner executes them in lexical order.

- [ ] **Step 3: Verify migration syntax**

```bash
cd src-tauri && cargo check
```

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "migrate(accounts): convert monetary columns from TEXT to INTEGER cents"
```

---

## Task 3: Update SQLite Account Repository — Use Cents

**Files:**
- Modify: `src-tauri/src/infrastructure/repositories/account_repository.rs`

### Context

The SQLite repository currently:
- Reads: `CAST(initial_balance AS TEXT)` → `String` → `Decimal::from_str()`
- Writes: `account.initial_balance.amount.to_string()`
- Balance sums: `CAST(SUM(...) AS TEXT)` → parse as Decimal

After migration:
- Reads: `row.try_get::<i64, _>("initial_balance")` → `Money::from_cents()`
- Writes: `account.initial_balance.to_cents()` (binds i64 directly)
- Balance sums: `SUM(...)` returns i64 directly, convert via `Money::from_cents()`

### Steps:

- [ ] **Step 1: Update `row_to_account()` — read monetary fields as i64 cents**

Find the `row_to_account` function. Replace the monetary field parsing:

**Old pattern (initial_balance):**
```rust
// CAST to TEXT then parse
let initial_balance_str: String = row.try_get("initial_balance")?;
let initial_balance = Decimal::from_str(&initial_balance_str)
    .map_err(|e| AccountRepoError::Database(...))?;
```

**New pattern:**
```rust
// Read as INTEGER cents
let initial_balance_cents: i64 = row.try_get("initial_balance")?;
let initial_balance = Money::from_cents(initial_balance_cents, currency_code.clone());
```

**Old pattern (credit_limit):**
```rust
let credit_limit_str: Option<String> = row.try_get("credit_limit")?;
let credit_limit = credit_limit_str.and_then(|s| {
    Decimal::from_str(&s).ok().map(|amount| Money::new(amount, currency_code.clone()))
});
```

**New pattern:**
```rust
let credit_limit_cents: Option<i64> = row.try_get("credit_limit")?;
let credit_limit = credit_limit_cents.map(|cents| Money::from_cents(cents, currency_code.clone()));
```

**Old pattern (low_balance_threshold):**
```rust
let low_balance_threshold_str: Option<String> = row.try_get("low_balance_threshold")?;
let low_balance_threshold = low_balance_threshold_str.and_then(|s| Decimal::from_str(&s).ok());
```

**New pattern:**
```rust
let low_balance_threshold_cents: Option<i64> = row.try_get("low_balance_threshold")?;
let low_balance_threshold = low_balance_threshold_cents.map(cents_to_decimal);
```

**interest_rate** stays unchanged — read as `Option<String>`, parse with `Decimal::from_str`.

- [ ] **Step 2: Remove all `CAST(... AS TEXT)` from SELECT queries**

In every SELECT query, find `CAST(initial_balance AS TEXT)` and replace with just `initial_balance`. Do the same for `credit_limit` and `low_balance_threshold`. Leave `interest_rate` CAST as-is (it stays TEXT).

**Example:** In `find_by_id`:
```sql
-- Old:
CAST(a.initial_balance AS TEXT) as initial_balance,
...
CAST(a.credit_limit AS TEXT) as credit_limit,
...
CAST(a.low_balance_threshold AS TEXT) as low_balance_threshold,

-- New:
a.initial_balance,
...
a.credit_limit,
...
a.low_balance_threshold AS low_balance_threshold,
```

Leave `interest_rate` as `CAST(a.interest_rate AS TEXT)` since it stays TEXT.

Search for ALL occurrences of `CAST.*AS TEXT` in the repository and update them.

- [ ] **Step 3: Update INSERT (create) — write as i64 cents**

In the `create()` method:

```rust
// Old:
.bind(account.initial_balance.amount.to_string())
// New:
.bind(account.initial_balance.to_cents())

// Old:
.bind(account.credit_limit.as_ref().map(|m| m.amount.to_string()))
// New:
.bind(account.credit_limit.as_ref().map(|m| m.to_cents()))

// Old:
.bind(account.low_balance_threshold.map(|t| t.to_string()))
// New:
.bind(account.low_balance_threshold.map(decimal_to_cents))
```

Leave `interest_rate` write as `.to_string()`.

- [ ] **Step 4: Update UPDATE — write as i64 cents**

Same pattern as Step 3, but in the `update()` method.

- [ ] **Step 5: Update balance computation queries**

In `compute_balances_for_all_accounts()`, `compute_balance_for_account_sqlite()`, and `get_balance_history_sqlite()`:

```rust
// Old: CAST(SUM(...) AS TEXT) → parse as Decimal
// New: SUM(...) → read as i64 → Money::from_cents()

// Example:
// Old:
let balance_str: String = row.try_get("balance")?;
let balance = Decimal::from_str(&balance_str)?;

// New:
let balance_cents: i64 = row.try_get("balance")?;
let balance = Money::from_cents(balance_cents, currency_code.clone());
```

In the SQL, change `CAST(SUM(initial_balance) AS TEXT)` to just `SUM(initial_balance)`.

- [ ] **Step 6: Run tests**

```bash
cd src-tauri && cargo test --lib "account"
```

Note: The `account_repository::tests` tests may fail due to `low_balance_threshold` column issues (pre-existing). The domain tests should all pass.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "refactor(accounts): update SQLite repository to use INTEGER cents for monetary fields"
```

---

## Task 4: Fix PostgreSQL Repository — Add Missing Fields (P21) + Use Cents

**Files:**
- Modify: `src-tauri/src/infrastructure/repositories/account_repository_postgres.rs`

### Context

The PG repository has 9 fields hardcoded to None/Active in `row_to_account`, and its SELECT queries only fetch 14 of the 22+ columns. This task adds the missing fields AND applies the same cents conversion as Task 3.

### Steps:

- [ ] **Step 1: Update SELECT column lists**

In all SELECT queries (`find_by_id`, `find_by_name`, `find_all`, `find_by_type`, `find_by_ownership`, `find_all_including_deleted`, `get_changes_since`), add the missing columns:

```
account_number, institution, credit_limit,
billing_day, payment_due_day, interest_rate,
low_balance_threshold, status, opened_at
```

The column list should now match the SQLite repository's SELECT.

- [ ] **Step 2: Update `row_to_account()` — read all fields + use cents**

Replace the hardcoded `None` values:

```rust
// Replace:
account_number: None,
institution: None,
credit_limit: None,
billing_day: None,
payment_due_day: None,
interest_rate: None,
low_balance_threshold: None,
status: AccountStatus::Active,
opened_at: None,

// With (matching SQLite pattern but using cents for monetary fields):
account_number: row.try_get("account_number")?,
institution: row.try_get("institution")?,
credit_limit: {
    let cents: Option<i64> = row.try_get("credit_limit")?;
    cents.map(|c| Money::from_cents(c, currency_code.clone()))
},
billing_day: row.try_get("billing_day")?,
payment_due_day: row.try_get("payment_due_day")?,
interest_rate: {
    let s: Option<String> = row.try_get("interest_rate")?;
    s.and_then(|v| Decimal::from_str(&v).ok())
},
low_balance_threshold: {
    let cents: Option<i64> = row.try_get("low_balance_threshold")?;
    cents.map(cents_to_decimal)
},
status: {
    let s: String = row.try_get("status")?;
    match s.as_str() {
        "archived" => AccountStatus::Archived,
        "hidden" => AccountStatus::Hidden,
        _ => AccountStatus::Active,
    }
},
opened_at: row.try_get("opened_at")?,
```

- [ ] **Step 3: Update `create()` INSERT — add missing columns + use cents**

Add `account_number`, `institution`, `credit_limit`, `billing_day`, `payment_due_day`, `interest_rate`, `low_balance_threshold`, `status`, `opened_at` to the INSERT column list and VALUES. Use cents for monetary fields:

```rust
.bind(account.account_number)           // Option<String>
.bind(account.institution)             // Option<String>
.bind(account.credit_limit.as_ref().map(|m| m.to_cents()))  // Option<i64>
.bind(account.billing_day)             // Option<i32>
.bind(account.payment_due_day)         // Option<i32>
.bind(account.interest_rate.map(|r| r.to_string()))  // Option<String> (TEXT)
.bind(account.low_balance_threshold.map(decimal_to_cents))  // Option<i64>
.bind(account.status.to_string())      // String
.bind(account.opened_at)               // Option<String>
```

- [ ] **Step 4: Verify `update()` method**

The `update()` method already writes most fields. Verify it uses cents for `credit_limit` and `low_balance_threshold`:

```rust
// Old:
.bind(account.credit_limit.as_ref().map(|m| m.amount.to_string()))
// New:
.bind(account.credit_limit.as_ref().map(|m| m.to_cents()))

// Old (if exists):
.bind(account.low_balance_threshold.map(|t| t.to_string()))
// New:
.bind(account.low_balance_threshold.map(decimal_to_cents))
```

Also verify `initial_balance` write uses cents.

- [ ] **Step 5: Run check**

```bash
cd src-tauri && cargo check
```

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "fix(accounts): complete PG repository — add 9 missing fields and use INTEGER cents"
```

---

## Task 5: Update Frontend TypeScript Types

**Files:**
- Verify: `src/lib/tauri/account.ts`

### Context

The frontend already uses `number` for monetary amounts. The API layer serializes Decimal as number in JSON. Since `rust_decimal::Decimal` serializes as string by default, and the Tauri IPC uses JSON, the serialization format depends on the serde configuration.

**IMPORTANT:** Check how `Decimal` is serialized in the DTO's `#[derive(Serialize)]`. If it serializes as a string like `"1234.56"`, the frontend already parses it to number. The change from TEXT cents in DB to Decimal in Rust domain means the API layer should be unchanged — the domain still holds `Decimal`, only the DB storage changes.

### Steps:

- [ ] **Step 1: Verify no frontend changes needed**

Read `src-tauri/src/application/dtos/account_dto.rs` to check how `Decimal` fields are serialized. If `rust_decimal` uses `#[serde(with = "...")]` or serializes as number/string, confirm the frontend already handles it.

If `Decimal` serializes as a string (e.g., `"1234.56"`), no frontend change is needed — the DB layer change is transparent.

If `Decimal` serializes as a number, still no change needed.

- [ ] **Step 2: Run frontend type check**

```bash
npx tsc --noEmit
```

- [ ] **Step 3: Commit** (only if changes were needed)

```bash
git add -A && git commit -m "chore(accounts): update frontend types for cents migration"
```

---

## Task 6: Run Full Test Suite and Verify

### Steps:

- [ ] **Step 1: Run Rust tests**

```bash
cd src-tauri && cargo test --lib
```

All account domain tests should pass. Repository tests may have pre-existing `low_balance_threshold` column issues — if so, update the test's `CREATE TABLE` to use `INTEGER` instead of `TEXT` for the monetary columns.

- [ ] **Step 2: Run frontend type check**

```bash
npx tsc --noEmit
```

- [ ] **Step 3: Run frontend lint**

```bash
pnpm lint
```

- [ ] **Step 4: Run Rust quality checks**

```bash
make check
```

- [ ] **Step 5: Commit any test fixes**

```bash
git add -A && git commit -m "fix(accounts): update tests for INTEGER cents migration"
```

---

## Task 7: Update Audit Spec Document

**Files:**
- Modify: `docs/superpowers/specs/2026-06-05-account-modification-audit-design.md`

### Steps:

- [ ] **Step 1: Update status in priority table**

Change P16 and P21 from `🔜 延期` to `✅ Sprint 5`:

```markdown
| P3 | P16 | Decimal TEXT 存储 | 数据完整性 | ✅ Sprint 5 |
| P3 | P21 | PG 仓库不完整 | 未来风险 | ✅ Sprint 5 |
```

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "docs: mark P16 and P21 as completed in audit spec"
```

---

This plan covers all remaining deferred P3 items from the account module audit. After completion, all 22 audit items will be resolved (100%).
