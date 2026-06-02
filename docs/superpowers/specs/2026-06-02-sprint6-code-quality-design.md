# Sprint 6: Code Quality Design

**Date:** 2026-06-02
**Status:** Approved
**Sprint:** 6 of 7
**Effort:** ~5 days
**Preceded by:** Sprint 5 (complete)
**Follows:** `2026-06-01-improvement-task-plan.md`

---

## Goal

Eliminate all i18n violations, remove dead code, and enforce consistent DDD architecture across Budget and Goals modules.

---

## Execution Order

```
Task 21 (i18n) → Task 22 (Dead Code) → Task 23 (DDD Refactor)
```

Tasks are independent; this order minimizes risk by starting with the simplest changes.

---

## Task 21: i18n — Replace Hardcoded Strings with Translation Keys

### Scope

66 hardcoded strings across 8 files. Every toast message and validation error must use `t()`.

### Files Affected

| File | Has `useTranslation`? | Strings to Fix |
|------|----------------------|----------------|
| `src/hooks/useGoal.ts` | No — needs import | 12 |
| `src/hooks/useBudget.ts` | No — needs import | 10 |
| `src/hooks/useCurrency.ts` | Partially (only `useFetchExchangeRates`) | 6 |
| `src/hooks/useTag.ts` | No — needs import | 12 |
| `src/hooks/useTransactionTemplate.ts` | No — needs import | 5 |
| `src/hooks/useReminder.ts` | No — needs import | 8 |
| `src/pages/GoalsPage.tsx` | Yes | 3 |
| `src/components/SimpleTransactionForm.tsx` | Yes | 10 |

### Implementation

1. **Add `useTranslation()` to 5 hook files** that don't have it yet:
   - `useGoal.ts`, `useBudget.ts`, `useCurrency.ts` (extend to all mutations), `useTag.ts`, `useTransactionTemplate.ts`, `useReminder.ts`
   - Pattern: `const { t } = useTranslation();` inside each mutation hook function

2. **Add i18n keys to both locale files** (`src/i18n/locales/en.json` and `zh.json`):

   **Toast keys** (under `toast.` namespace):
   ```
   toast.goalCreated / toast.goalUpdated / toast.goalProgressUpdated
   toast.goalCompleted / toast.goalDeleted / toast.goalProgressSynced
   toast.goalCreateFailed / toast.goalUpdateFailed / toast.goalProgressFailed
   toast.goalCompleteFailed / toast.goalDeleteFailed / toast.goalProgressSyncFailed

   toast.budgetCreated / toast.budgetItemAdded / toast.budgetDeleted
   toast.budgetItemRemoved / toast.budgetCloned
   toast.budgetCreateFailed / toast.budgetItemAddFailed / toast.budgetDeleteFailed
   toast.budgetItemRemoveFailed / toast.budgetCloneFailed

   toast.currencyAdded / toast.rateUpdated / toast.currencyDeleted
   toast.currencyAddFailed / toast.rateUpdateFailed / toast.currencyDeleteFailed

   toast.tagCreated / toast.tagDeleted / toast.tagUpdated
   toast.tagSoftDeleted / toast.tagAdded / toast.tagRemoved
   toast.tagCreateFailed / toast.tagDeleteFailed / toast.tagUpdateFailed
   toast.tagSoftDeleteFailed / toast.tagAddFailed / toast.tagRemoveFailed

   toast.templateCreated / toast.templateUpdated / toast.templateDeleted
   toast.templatePaused / toast.templateResumed

   toast.reminderCreated / toast.reminderUpdated / toast.reminderDeleted
   toast.reminderCompleted
   toast.reminderCreateFailed / toast.reminderUpdateFailed
   toast.reminderDeleteFailed / toast.reminderCompleteFailed
   ```

   **Validation error keys** (under `validation.` namespace):
   ```
   validation.goalNameRequired / validation.goalAmountRequired
   validation.validAmountRequired
   validation.selectOwnAccount / validation.selectExternalAccount
   ```

   **Label keys** (under `transactions.` namespace):
   ```
   transactions.creditOwnAccount / transactions.debitOwnAccount
   transactions.debitExternalAccount / transactions.creditExternalAccount
   transactions.selectAccount / transactions.selectExternalAccount
   ```

3. **Replace all hardcoded strings** with `t('key')` calls

4. **Verify** with `pnpm lint` — ESLint `i18next/no-literal-string` should pass

### Acceptance Criteria

- [ ] Zero hardcoded Chinese/English toast messages in hooks and components
- [ ] `pnpm lint` passes with no i18n violations
- [ ] Both `en.json` and `zh.json` have all new keys

---

## Task 22: Dead Code Cleanup

### Cleanup Items

| # | Item | Action | File(s) |
|---|------|--------|---------|
| 1 | Legacy `debt.rs` aggregate (520 lines) | **DELETE** | `src-tauri/src/domain/aggregates/debt.rs` |
| 2 | `debt` module export | **DELETE** `pub mod debt;` and `pub use debt::{...};` | `src-tauri/src/domain/aggregates/mod.rs` (lines 4, 19) |
| 3 | Global `#![allow(dead_code)]` | **DELETE** from both files | `src-tauri/src/lib.rs` (lines 1-3), `src-tauri/src/main.rs` (lines 1-3) |
| 4 | `infrastructure/database/` placeholder | **DELETE** file and `mod database;` declaration | `src-tauri/src/infrastructure/database/mod.rs` |
| 5 | GoalRepository `find_active`/`find_completed` | **DELETE** from trait, impl, and test | `src-tauri/src/domain/repositories/goal_repository.rs`, `src-tauri/src/infrastructure/repositories/goal_repository.rs` |

### Post-Cleanup: Handle Surfaced Warnings

After removing the global `#![allow(dead_code)]` from `lib.rs` and `main.rs`, `cargo check` will surface previously suppressed warnings. For each warning:

- **If genuinely unused**: delete the dead code
- **If planned for future use** (e.g., PostgreSQL repos, ChartOfAccounts): add targeted `#[allow(dead_code)]` with a `// TODO: <reason>` comment
- **Review per-item suppressions** in:
  - `backup_service.rs` — 6 instances (lines 374, 383, 420, 454, 476, 558)
  - `currency_repository.rs` — 1 instance (line 17)
  - `value_objects/mod.rs` — 7 `#[allow(unused_imports)]` (lines 10-22)

### Acceptance Criteria

- [ ] `debt.rs` deleted, `debt_details.rs` is the only debt model
- [ ] No global `#![allow(dead_code)]` or `#![allow(unused_imports)]` in `lib.rs`/`main.rs`
- [ ] `cargo check` passes (with only targeted per-item suppressions)
- [ ] No `infrastructure/database/` placeholder directory

---

## Task 23: DDD Architecture — Add Application Service Layer for Budget and Goals

### Current Problem

- `budget_commands.rs` and `goal_commands.rs` import `SqliteBudgetRepository`/`SqliteGoalRepository` directly, bypassing the application service layer
- Business logic (UUID generation, aggregate construction, multi-step operations) lives in command handlers
- This violates the DDD pattern used by all other modules (Debts, Subscriptions, Holdings)

### Pattern Reference

Follow the established pattern from `debt_service.rs` and `holding_service.rs`:

```rust
pub struct GoalService {
    goal_repo: Arc<SqliteGoalRepository>,
    account_repo: Arc<SqliteAccountRepository>,
}

pub enum GoalServiceError {
    NotFound(String),
    ValidationError(String),
    RepositoryError(String),
}

impl Display for GoalServiceError { ... }
impl Error for GoalServiceError { ... }
impl From<sqlx::Error> for GoalServiceError { ... }
```

### Part A: Refactor `BudgetService`

**File:** `src-tauri/src/application/services/budget_service.rs`

Current state: holds a raw `SqlitePool` and implements `compute_budget_actuals` + `clone_budget_to_month` with raw SQL. Needs:

1. **Change constructor** to accept `Arc<SqliteBudgetRepository>` instead of `SqlitePool`
2. **Add CRUD methods** (currently in `budget_commands.rs`):

   | Method | Logic to Extract |
   |--------|-----------------|
   | `list_budgets()` | Repo delegation + DTO mapping |
   | `get_budget(id)` | Repo delegation + DTO mapping |
   | `get_budget_by_month(month)` | Repo delegation + DTO mapping |
   | `create_budget(name, month, currency_code)` | UUID gen, `Budget::new()` construction, repo create |
   | `add_budget_item(budget_id, category_account_id, planned_amount, notes)` | Decimal parse, UUID gen, `BudgetItem::new()`, repo add + re-fetch |
   | `delete_budget(id)` | Repo delegation |
   | `remove_budget_item(budget_id, item_id)` | Repo remove + re-fetch |

3. **Refactor existing methods** to use repository instead of raw SQL where feasible

### Part B: Create `GoalService`

**New file:** `src-tauri/src/application/services/goal_service.rs`

Dependencies: `Arc<SqliteGoalRepository>`, `Arc<SqliteAccountRepository>` (for `sync_goal_progress`)

Methods to implement:

| Method | Key Logic |
|--------|-----------|
| `list_goals()` | Repo delegation |
| `get_goal(id)` | Repo delegation |
| `create_goal(dto)` | UUID gen, Decimal parse, GoalType parse, deadline parse, account linking, aggregate construction |
| `update_goal(id, dto)` | Partial update of 7 fields (name, goal_type, target_amount, currency_code, deadline, linked_account_id, notes) |
| `update_goal_progress(id, amount)` | Decimal parse, `add_progress`, auto-complete check (`current >= target`) |
| `complete_goal(id)` | `mark_completed()` domain call |
| `delete_goal(id)` | Repo delegation |
| `sync_goal_progress(goal_id)` | Multi-repo orchestration: load goal → read account balance → compute net change from transaction_entries → update progress |

### Part C: Register and Wire

1. Add `pub mod goal_service;` and `pub use goal_service::{GoalService, GoalServiceError};` to `src-tauri/src/application/services/mod.rs`
2. Change `BudgetCommandState` to hold `Arc<BudgetService>` instead of `Arc<SqliteBudgetRepository>` + `SqlitePool`
3. Create `GoalCommandState` holding `Arc<GoalService>`
4. Slim down both command files — each command becomes a thin wrapper that delegates to the service

### Acceptance Criteria

- [ ] `GoalService` exists with all 8 methods
- [ ] `BudgetService` has full CRUD + existing compute/clone methods
- [ ] Neither `budget_commands.rs` nor `goal_commands.rs` imports repository types directly
- [ ] All business logic (UUID gen, aggregate construction, multi-repo orchestration) lives in service layer
- [ ] `cargo check` passes
- [ ] `make check` passes

---

## Verification

After all three tasks, run:

```bash
# Frontend
pnpm lint          # i18n + ESLint checks
pnpm type-check    # TypeScript compilation

# Backend
make check         # Format + clippy + quality checks
make test          # All Rust tests pass

# Full app
pnpm tauri dev     # Manual smoke test
```

---

## Risks

| Risk | Mitigation |
|------|------------|
| Removing global `#![allow(dead_code)]` surfaces many warnings | Triage each: delete if unused, add targeted `#[allow]` with TODO comment if planned |
| `useTranslation()` in custom hooks may cause re-render issues | Pattern is standard React Query + i18next; `t` function is stable reference |
| BudgetService refactor touches raw SQL in `compute_budget_actuals` | Keep raw SQL for complex aggregation queries, but wrap behind service method |
| GoalService `sync_goal_progress` queries multiple tables | Inject `AccountRepository` to avoid raw SQL in service |
