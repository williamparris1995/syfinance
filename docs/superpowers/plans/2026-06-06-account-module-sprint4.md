# Account Module Sprint 4 — Deferred P3 Items Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Complete the remaining deferred P3 items from the account audit — edit page route, change confirmation, negative balance review, Decimal migration, and type chain simplification.

**Architecture:** Same stack as Sprints 1-3. These are larger-scoped items that improve UX and code quality.

**Spec:** `docs/superpowers/specs/2026-06-05-account-modification-audit-design.md`

**Previous plans:**
- Sprint 1: `docs/superpowers/plans/2026-06-05-account-module-critical-fixes.md` ✅
- Sprint 2: `docs/superpowers/plans/2026-06-05-account-module-sprint2.md` ✅
- Sprint 3: `docs/superpowers/plans/2026-06-06-account-module-sprint3.md` ✅

---

## Task 1: Edit Page Route — Sheet → Full Page (P5/P30)

**Current state:** Account editing happens in a right-side Sheet (`sm:max-w-lg`). This is too narrow for the form, and immutable fields (type/ownership/currency) are just grayed out without explanation.

**Target state:** Editing an account navigates to `/accounts/:id/edit`, a full-width page with proper layout.

**Files:**
- Create: `src/pages/AccountEditPage.tsx`
- Modify: `src/routes/__root.tsx` (or route file) — add `/accounts/:id/edit` route
- Modify: `src/pages/AccountsPage.tsx` — edit button navigates instead of opening Sheet

### Steps:

- [ ] **Step 1: Create AccountEditPage component**

Create `src/pages/AccountEditPage.tsx` that:
- Uses `useParams()` to get the account ID
- Fetches account data with `useQuery({ queryKey: ['accounts'], queryFn: listAccountsWithBalances })` then filters
- Uses `useMutation` for the update
- Renders the existing `<AccountForm mode="edit" initialData={account} onSubmit={handleSubmit} onCancel={() => navigate('/accounts')} isLoading={isPending} />`
- Has a back button to return to `/accounts`

- [ ] **Step 2: Add route**

In the router config, add a route for `/accounts/:id/edit` pointing to `AccountEditPage`.

- [ ] **Step 3: Update AccountsPage edit button**

In `AccountsPage.tsx`, change the edit button from opening a Sheet to navigating:
```tsx
onClick={() => navigate({ to: '/accounts/$accountId/edit', params: { accountId: account.id } })}
```

Remove the edit Sheet entirely (the one with `isSheetOpen && !!editingAccount`).

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat(accounts): replace edit Sheet with full page route"
```

---

## Task 2: Change Confirmation Dialog (P6)

**Current state:** Editing an account saves immediately with no confirmation. For a financial app, users should see what they're about to change before saving.

**Files:**
- Create: `src/components/AccountChangesDialog.tsx`
- Modify: `src/pages/AccountEditPage.tsx` (or `AccountForm.tsx`)

### Steps:

- [ ] **Step 1: Create AccountChangesDialog component**

This dialog shows before saving edits. It compares `initialData` with current form values and lists the changes:

```tsx
interface ChangeItem {
  field: string;      // i18n key for the field name
  oldValue: string;   // formatted old value
  newValue: string;   // formatted new value
}
```

The dialog:
- Title: "确认修改" / "Confirm Changes"
- Body: A list of changed fields with old → new values
- Footer: [取消] [确认保存] buttons, destructive styling for significant changes (like balance changes)
- Only shown when there are actual changes (skip if nothing changed)

- [ ] **Step 2: Wire it into the edit flow**

In `AccountEditPage.tsx`, before calling `updateMutation.mutate()`, compute the diff and show the dialog if there are changes. If no changes, show a toast "没有修改" / "No changes".

- [ ] **Step 3: Add i18n keys**

In both locale files, add keys for the change confirmation dialog field names (account name, initial balance, icon, color, account number, institution, credit limit, etc.)

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat(accounts): add change confirmation dialog before saving edits"
```

---

## Task 3: Review Negative Balance Validation Logic (P10)

**Current state:** `validate_balance()` in `account.rs` prohibits negative initial balances for Cash/Bank/Investment/BorrowedOut/Prepaid. But:
- CreditCard and BorrowedIn already allow negative balances (they're Liability now)
- A user might want to start a bank account with a negative balance (overdraft)
- The rule only prevents creation with negative — transactions can make it negative

**Decision:** Relax the rule. Only Cash should be prohibited from negative initial balance. All other types allow it. Rationale:
- Bank accounts can have overdrafts
- Investment accounts can have losses
- BorrowedOut/Prepaid: edge cases but not dangerous
- The real protection should be warnings, not prohibition

**Files:**
- Modify: `src-tauri/src/domain/aggregates/account.rs` — update `validate_balance`
- Modify: `src/components/AccountForm.tsx` — remove Zod negative balance validation for non-Cash types

### Steps:

- [ ] **Step 1: Relax validate_balance in Rust**

Change `validate_balance()` to only prohibit negative for `AccountType::Cash`:

```rust
fn validate_balance(
    account_type: &AccountType,
    currency_code: &str,
    balance: &Money,
) -> Result<(), AccountError> {
    if balance.currency_code != currency_code {
        return Err(AccountError::CurrencyMismatch {
            expected: currency_code.to_string(),
            actual: balance.currency_code.clone(),
        });
    }

    // Only Cash accounts cannot start with a negative balance.
    // All other types (Bank, CreditCard, Investment, etc.) allow it.
    if matches!(account_type, AccountType::Cash) && balance.amount < Decimal::ZERO {
        return Err(AccountError::NegativeBalanceNotAllowed {
            account_type: account_type.clone(),
            balance: balance.amount,
        });
    }

    Ok(())
}
```

- [ ] **Step 2: Update frontend Zod validation**

In `AccountForm.tsx`, the Zod schema currently has no explicit negative balance validation (the backend enforces it). No frontend change needed since the backend is the authority. But if the frontend has any `min(0)` Zod rules for initial_balance, remove them for non-Cash types.

- [ ] **Step 3: Update tests**

Update the Rust test `investment_account_with_negative_balance_balance_fails` to expect success (investment CAN start negative now). Add a new test `cash_account_with_negative_balance_still_fails` to verify Cash still can't.

- [ ] **Step 4: Run tests and commit**

```bash
git add -A && git commit -m "refactor(accounts): relax negative balance validation — only Cash prohibited"
```

---

## Task 4: Simplify billing_day/payment_due_day Type Chain (P19)

**Current state:** The type chain for billing fields is:
- Frontend: string (Zod validates "1"-"31")
- DTO: i32
- Domain: u8
- DB: INTEGER
- Read-back: i64 → u8

This is unnecessarily complex and error-prone. Simplify to use i32 throughout (DB INTEGER is already the right type).

**Files:**
- Modify: `src-tauri/src/domain/aggregates/account.rs` — change `billing_day` and `payment_due_day` from `u8` to `i32`
- Modify: `src-tauri/src/application/dtos/account_dto.rs` — verify DTO uses i32 (it already does)
- Modify: `src-tauri/src/infrastructure/repositories/account_repository.rs` — remove the `as u8` / `as i32` casts

### Steps:

- [ ] **Step 1: Change domain types from u8 to i32**

In `account.rs`, change:
```rust
pub billing_day: Option<i32>,    // was Option<u8>
pub payment_due_day: Option<i32>, // was Option<u8>
```

And in `AccountDto`, change:
```rust
pub billing_day: Option<i32>,    // was Option<u8>
pub payment_due_day: Option<i32>, // was Option<u8>
```

- [ ] **Step 2: Remove DB read-back casts**

In `account_repository.rs`, `row_to_account()`, change:
```rust
let billing_day: Option<i32> = row.try_get("billing_day")?;
let payment_due_day: Option<i32> = row.try_get("payment_due_day")?;
```

Remove the `.map(|d| d as u8)` and `.map(|d| d as i32)` casts.

In the `update()` method, change the bind from `account.billing_day.map(|d| d as i32)` to just `account.billing_day`.

- [ ] **Step 3: Update frontend TypeScript types**

In `src/lib/tauri/account.ts`, `AccountDto` already has `billing_day?: number | null` and `payment_due_day?: number | null` — no change needed.

- [ ] **Step 4: Run tests and commit**

```bash
git add -A && git commit -m "refactor(accounts): simplify billing_day/payment_due_day type chain to i32 throughout"
```

---

## Task 5: Remove UpdateAccountDto from Frontend (P20 cleanup)

**Note:** This was partially done in Sprint 3 (backend `UpdateAccountDto` was removed). Now clean up any remaining frontend reference.

**Files:**
- Check: `src/lib/tauri/account.ts` — verify `UpdateAccountDto` is fully removed
- Check: `src/components/AccountForm.tsx` — verify no `UpdateAccountDto` references
- Check: `src/pages/AccountsPage.tsx` — verify no `UpdateAccountDto` references

### Steps:

- [ ] **Step 1: Search entire frontend for `UpdateAccountDto` references**

```bash
grep -r "UpdateAccountDto" src/
```

If any remain, replace them with `PatchAccountDto`.

- [ ] **Step 2: Verify type check passes**

- [ ] **Step 3: Commit** (only if changes were needed)

```bash
git add -A && git commit -m "cleanup(accounts): remove remaining UpdateAccountDto references from frontend"
```

---

This plan covers all remaining deferred P3 items. After completion, the audit specification will be fully implemented.