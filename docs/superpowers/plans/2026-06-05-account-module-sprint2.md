# Account Module Sprint 2 — Remaining P2/P3 Items

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete remaining P2 fixes and high-value P3 improvements from the account audit spec.

**Architecture:** Same stack as Sprint 1. This plan covers: unified create entry, backend template i18n, created_at column, AccountWizard preview fix, and the pre-existing integration test fix.

**Spec:** `docs/superpowers/specs/2026-06-05-account-modification-audit-design.md`

**Previous plan:** `docs/superpowers/plans/2026-06-05-account-module-critical-fixes.md`

---

## File Structure

### Backend (src-tauri/)
```
src/
  application/services/account_service.rs  — MODIFY: i18n template names
  infrastructure/repositories/account_repository.rs — MODIFY: read created_at
migrations/
  20260606000003_add_created_at_to_accounts.sql  — NEW: add created_at column
tests/account_commands.rs — FIX: pre-existing FK constraint failure
```

### Frontend (src/)
```
  components/AccountWizard.tsx   — MODIFY: fix preview tags, unify with AccountForm
  lib/tauri/account.ts            — MODIFY: remove NewAccountPage route if exists
```

---

### Task 1: Fix AccountWizard Step 1 preview to show ALL subtypes (P28)

**Files:**
- Modify: `src/components/AccountWizard.tsx`

Currently the asset card preview shows only 5 types. After the Ownership refactor (Sprint 1), it should dynamically list all types.

- [ ] **Step 1: Fix the hardcoded preview in AccountWizard Step 1**

The asset card (step 1) has a hardcoded array `['Cash','Bank','CreditCard','Investment','Prepaid']`. Replace it with dynamic rendering from ASSET_TYPES. Remove the CreditCard from ASSET_TYPES preview (it belongs to LIABILITY_TYPES now) and ensure the preview matches what Step 2 shows.

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "fix(accounts): show all subtypes in wizard Step 1 preview"
```

---

### Task 2: Backend template names i18n (P14)

**Files:**
- Modify: `src-tauri/src/application/services/account_service.rs`

- [ ] **Step 1: Replace hardcoded Chinese names with i18n keys**

In `account_service.rs`, the `INVESTMENT_TEMPLATES` array has hardcoded Chinese names like `"股票账户"`. Replace with translatable keys:

```rust
const INVESTMENT_TEMPLATES: [InvestmentTemplate; 7] = [
    InvestmentTemplate { name: "stock_account", chart_code: "1101", icon: "TrendingUp", color: "#EF4444" },
    InvestmentTemplate { name: "fund_account", chart_code: "1101", icon: "BarChart3", color: "#3B82F6" },
    InvestmentTemplate { name: "etf_account", chart_code: "1101", icon: "Layers", color: "#8B5CF6" },
    InvestmentTemplate { name: "bond_account", chart_code: "1501", icon: "Landmark", color: "#10B981" },
    InvestmentTemplate { name: "gold_account", chart_code: "1101", icon: "Coins", color: "#F59E0B" },
    InvestmentTemplate { name: "option_account", chart_code: "1101", icon: "GitBranch", color: "#F97316" },
    InvestmentTemplate { name: "other_investment", chart_code: "1012", icon: "Wallet", color: "#64748B" },
];
```

- [ ] **Step 2: Update frontend INVESTMENT_TEMPLATES to use i18n keys**

In `src/lib/tauri/account.ts`, the `INVESTMENT_TEMPLATES` already uses `t('accounts.templates.stockAccount')` etc. Verify the keys match the new backend names and update if needed.

The backend now returns i18n keys instead of Chinese strings. The frontend `create_preset_investment_accounts` command should use the template names directly (they are now keys like `stock_account`). When displayed, the frontend translates them.

- [ ] **Step 3: Run backend tests**

Run: `cd src-tauri && cargo test account`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "fix(accounts): replace hardcoded Chinese template names with i18n keys"
```

---

### Task 3: Add real created_at column (P18)

**Files:**
- Create: `src-tauri/migrations/20260606000003_add_created_at_to_accounts.sql`
- Modify: `src-tauri/src/infrastructure/repositories/account_repository.rs`
- Modify: `src-tauri/src/domain/value_objects.rs` (or wherever SyncMetadata is)

- [ ] **Step 1: Create migration**

Create `20260606000003_add_created_at_to_accounts.sql`:

```sql
-- Add real created_at column to accounts
ALTER TABLE accounts ADD COLUMN created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;
```

- [ ] **Step 2: Update SyncMetadata or Account to read/write created_at**

In `account_repository.rs` row_to_account, read the `created_at` column and store it. The `AccountDto::created_at` should now use this real value instead of `sync_metadata.updated_at`.

In `account.rs`, add `created_at: DateTime<Utc>` field if not present (it should already be in AccountDto but not in Account aggregate). If the aggregate doesn't have it, add it and initialize it to `Utc::now()` in `Account::new()`.

In `account_dto.rs`, change the `From<Account>` impl:
```rust
created_at: account.created_at,  // was: account.sync_metadata.updated_at
```

- [ ] **Step 3: Run backend tests**

Run: `cd src-tauri && cargo test account`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "fix(accounts): add real created_at column to accounts"
```

---

### Task 4: Fix pre-existing integration test failure

**Files:**
- Modify: `src-tauri/tests/account_commands.rs`

The `account_command_lifecycle` integration test fails because migration `20260604000002` (category_and_chart_of_accounts) has a FK constraint error. The `categories` table adds a `category_id` FK to `transactions`, but the existing `transactions` table may have rows that violate it.

- [ ] **Step 1: Read and understand the failing migration**

Read `src-tauri/migrations/20260604000002_category_and_chart_of_accounts.sql` and `src-tauri/tests/account_commands.rs`.

- [ ] **Step 2: Fix the test or migration**

The most likely fix is to make the `category_id` column nullable or add a default, or set `category_id` to NULL for existing transactions. The FK should use `ON DELETE SET NULL`.

If the migration already uses `REFERENCES categories(id) ON DELETE SET NULL`, the issue might be that the `categories` table hasn't been seeded yet when the FK is added. Consider adding the `category_id` column as nullable first, then add the FK constraint separately after seeding.

- [ ] **Step 3: Run `cd src-tauri && cargo test account` to verify**

Expected: ALL tests pass including integration test

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "fix(tests): resolve account_command_lifecycle FK constraint failure"
```

---

This plan covers the remaining P2 items. P3 items (Decimal TEXT migration, PG repo, parent_id protection, AccountStatus activation, unified create entry rewrite, edit page route) are deferred to Sprint 3.