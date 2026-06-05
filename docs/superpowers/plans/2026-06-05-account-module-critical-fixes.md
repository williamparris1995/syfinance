# Account Module Critical Fixes & Ownership Refactor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix P0/P1 bugs in the account module, extend Ownership to three classes, and redesign account pages to match YNAB-caliber finance UX.

**Architecture:** Backend Rust (DDD) + React frontend (TanStack Query + react-hook-form). Changes span DB migration → domain aggregate → service → DTO → IPC → TypeScript types → UI components. Three-phase approach: (1) critical fixes, (2) Ownership refactor, (3) page redesign.

**Tech Stack:** Rust/SQLx, React/TypeScript, TanStack Query, react-hook-form/Zod, shadcn/ui, Radix, i18next

**Spec:** `docs/superpowers/specs/2026-06-05-account-modification-audit-design.md`

---

## File Structure

### Backend (src-tauri/)

```
src/
  domain/
    aggregates/account.rs          — MODIFY: add Liability, update validate_balance, add update_low_balance_threshold()
  application/
    dtos/account_dto.rs            — MODIFY: add low_balance_threshold/status/opened_at, fix UpdateAccountDto null语义
    services/account_service.rs    — MODIFY: fix update null semantics, name uniqueness check, Liability wiring
  infrastructure/
    repositories/account_repository.rs — MODIFY: row_to_account handle 'loan', Liability
  presentation/
    tauri_commands/account_commands.rs — MODIFY: add created_at column support
migrations/
  2026060X00001_migrate_loan_to_borrowed_in.sql    — NEW: data migration
  2026060X00002_add_liability_ownership.sql        — NEW: add 'liability' to CHECK + migrate CreditCard/BorrowedIn
  2026060X00003_add_created_at_to_accounts.sql     — NEW: add created_at column
```

### Frontend (src/)

```
lib/tauri/account.ts              — MODIFY: add Liability, add missing fields to AccountDto, fix UpdateAccountDto
components/
  AccountForm.tsx                  — MODIFY: null semantics, clearable fields, immutable field info
  AccountWizard.tsx                — MODIFY: 3-card Step 1, remove hardcoded preview
  AccountsPage.tsx                 — MODIFY: summary cards, grouped layout, delete dialog
  AccountDetailPanel.tsx           — MODIFY: add missing fields display
  DeleteAccountDialog.tsx          — NEW: confirmation dialog
pages/
  AccountsPage.tsx                 — MODIFY: owns layout, filter, summary cards
```

---

## Phase 1: Critical Bug Fixes (P0)

### Task 1: Fix copy-to-create flow (P1/P13)

**Files:**
- Modify: `src/pages/AccountsPage.tsx:369-379`
- Modify: `src/pages/AccountsPage.tsx:486-525`

- [ ] **Step 1: Add a dedicated createMutation for copy sheet**

In `AccountsPage.tsx`, add a new `createMutation` alongside the existing `updateMutation`:

```typescript
const createMutation = useMutation({
  mutationFn: createAccount,
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['accounts'] });
    setIsSheetOpen(false);
    setCopyingAccount(null);
    toast.success(t('accounts.accountCreated'));
  },
  onError: (error) => {
    toast.error(getUserFriendlyError(error));
  },
});
```

- [ ] **Step 2: Add handleCopySubmit handler**

```typescript
const handleCopySubmit = (data: CreateAccountDto) => {
  createMutation.mutate(data);
};
```

- [ ] **Step 3: Wire Copy Sheet to createMutation**

Change the Copy Sheet's `<AccountForm>` from `onSubmit={handleEditSubmit}` to `onSubmit={handleCopySubmit}`. The `mode` prop should already be `'create'` (default) since `editingAccount` is null for copy. Verify that `<AccountForm>` in copy mode sends a `CreateAccountDto` (not an `{ id, dto }` object).

- [ ] **Step 4: Add "(副本)" suffix to copied account name**

In `handleCopyClick`, when setting `copyingAccount`, append the suffix:

```typescript
const handleCopyClick = (account: AccountDto) => {
  setEditingAccount(null);
  setCopyingAccount({ ...account, name: `${account.name} (${t('accounts.copy')})` });
  setIsSheetOpen(true);
};
```

- [ ] **Step 5: Add i18n key for copy suffix**

In `src/i18n/locales/en.json` add under `accounts`:

```json
"copy": "Copy"
```

In `src/i18n/locales/zh.json` add:

```json
"copy": "副本"
```

- [ ] **Step 6: Run type check**

Run: `pnpm type-check`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "fix(accounts): wire copy-to-create to createAccount mutation

Replaces broken copy flow that silently failed. Copy now creates a new
account with '(副本)' suffix. Adds createMutation to AccountsPage."
```

---

### Task 2: Add missing fields to AccountDto (P17)

**Files:**
- Modify: `src-tauri/src/application/dtos/account_dto.rs:42-97`
- Modify: `src/lib/tauri/account.ts`

- [ ] **Step 1: Add low_balance_threshold, status, opened_at to AccountDto**

In `account_dto.rs`, add fields to the `AccountDto` struct:

```rust
pub struct AccountDto {
    // ... existing fields ...
    pub low_balance_threshold: Option<Decimal>,
    pub status: String,
    pub opened_at: Option<DateTime<Utc>>,
}
```

- [ ] **Step 2: Update From<Account> for AccountDto to populate new fields**

```rust
impl From<Account> for AccountDto {
    fn from(account: Account) -> Self {
        Self {
            // ... existing fields unchanged ...
            low_balance_threshold: account.low_balance_threshold,
            status: account.status.to_string(),
            opened_at: account.opened_at,
        }
    }
}
```

- [ ] **Step 3: Add Display impl for AccountStatus**

In `account.rs`, add:

```rust
impl fmt::Display for AccountStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Active => write!(f, "active"),
            Self::Archived => write!(f, "archived"),
            Self::Hidden => write!(f, "hidden"),
        }
    }
}
```

- [ ] **Step 4: Update TypeScript AccountDto interface**

In `src/lib/tauri/account.ts`, add to the `AccountDto` interface:

```typescript
low_balance_threshold?: number | null;
status: string;
opened_at?: string | null;
```

- [ ] **Step 5: Verify the low balance warning now works**

Check that `AccountsPage.tsx:154` now receives `account.low_balance_threshold` from the API response. The existing comparison `Number(account.current_balance) < Number(account.low_balance_threshold)` should function correctly once the field is present.

- [ ] **Step 6: Run backend tests**

Run: `cd src-tauri && cargo test account`
Expected: PASS

- [ ] **Step 7: Run frontend type check**

Run: `pnpm type-check`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "fix(accounts): add low_balance_threshold, status, opened_at to AccountDto

These fields were missing from the DTO, causing the low balance warning
to never trigger on the accounts list page."
```

---

### Task 3: Migrate ghost 'loan' type to 'borrowed_in' (P15)

**Files:**
- Create: `src-tauri/migrations/20260606000001_migrate_loan_to_borrowed_in.sql`
- Modify: `src-tauri/src/infrastructure/repositories/account_repository.rs`

- [ ] **Step 1: Write the migration SQL**

Create `20260606000001_migrate_loan_to_borrowed_in.sql`:

```sql
-- Migrate any legacy 'loan' account_type rows to 'borrowed_in'
-- and remove 'loan' from the CHECK constraint.
UPDATE accounts SET account_type = 'borrowed_in' WHERE account_type = 'loan';

-- Recreate the table with updated CHECK constraint (no 'loan')
CREATE TABLE accounts_backup AS SELECT * FROM accounts;
DROP TABLE accounts;

CREATE TABLE accounts (
    id TEXT PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    account_type VARCHAR(20) NOT NULL,
    currency_code VARCHAR(3) NOT NULL DEFAULT 'CNY',
    initial_balance DECIMAL(20,2) NOT NULL DEFAULT 0.00,
    ownership VARCHAR(10) NOT NULL DEFAULT 'own',
    icon VARCHAR(10) NOT NULL DEFAULT '📁',
    color VARCHAR(7) NOT NULL DEFAULT '#6B7280',
    chart_code VARCHAR(10),
    parent_id TEXT REFERENCES accounts(id) ON DELETE SET NULL,
    account_number VARCHAR(50),
    institution VARCHAR(100),
    credit_limit DECIMAL(20,2),
    billing_day INTEGER,
    payment_due_day INTEGER,
    interest_rate DECIMAL(5,4),
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    version INTEGER NOT NULL DEFAULT 1,
    low_balance_threshold DECIMAL(20,2),
    status TEXT DEFAULT 'active' CHECK(status IN ('active', 'archived', 'hidden')),
    opened_at TIMESTAMP,
    CHECK (account_type IN ('cash', 'bank', 'credit_card', 'investment',
           'borrowed_out', 'borrowed_in', 'prepaid', 'other', 'income', 'expense')),
    CHECK (billing_day IS NULL OR (billing_day >= 1 AND billing_day <= 31)),
    CHECK (payment_due_day IS NULL OR (payment_due_day >= 1 AND payment_due_day <= 31)),
    CHECK (interest_rate IS NULL OR interest_rate >= 0),
    FOREIGN KEY (currency_code) REFERENCES currencies(code) ON DELETE RESTRICT
);

INSERT INTO accounts SELECT * FROM accounts_backup;
DROP TABLE accounts_backup;

-- Recreate indexes
CREATE INDEX idx_accounts_type ON accounts(account_type);
CREATE INDEX idx_accounts_ownership ON accounts(ownership);
CREATE INDEX idx_accounts_currency ON accounts(currency_code);
CREATE INDEX idx_accounts_deleted ON accounts(deleted_at);
```

- [ ] **Step 2: Verify row_to_account no longer needs 'loan' branch**

In `account_repository.rs:22-46`, confirm the `account_type` match expression has no `"loan"` branch. The existing code already handles only the valid enum variants and falls through to an error for unknown types. The migration ensures no `'loan'` rows exist.

- [ ] **Step 3: Run backend tests + migration verification**

Run: `cd src-tauri && cargo test`
Expected: PASS (migration runs as part of app startup, 'loan' data migrated)

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "fix(accounts): migrate ghost 'loan' type to 'borrowed_in'

Removes 'loan' from the CHECK constraint and migrates any existing rows.
Prevents Decode error crash when listing accounts with legacy data."
```

---

### Task 4: Fix UpdateAccountDto null semantics — backend (P2/P7)

**Files:**
- Modify: `src-tauri/src/application/dtos/account_dto.rs:24-40`
- Modify: `src-tauri/src/application/services/account_service.rs:113-168`
- Modify: `src/domain/aggregates/account.rs` — add `update_low_balance_threshold()`

- [ ] **Step 1: Create PatchAccountDto with explicit null semantics**

In `account_dto.rs`, add a new struct after `UpdateAccountDto`:

```rust
/// Patch semantics: `Some(Some(value))` = set to value, `Some(None)` = clear, `None` = no change
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PatchAccountDto {
    pub name: String,
    pub initial_balance: Decimal,
    pub icon: Option<String>,
    pub color: Option<String>,
    pub account_number: Option<Option<String>>,
    pub institution: Option<Option<String>>,
    pub credit_limit: Option<Option<Decimal>>,
    pub billing_day: Option<Option<i32>>,
    pub payment_due_day: Option<Option<i32>>,
    pub interest_rate: Option<Option<Decimal>>,
    pub chart_code: Option<Option<String>>,
    pub parent_id: Option<Option<Uuid>>,
    pub low_balance_threshold: Option<Option<Decimal>>,
}
```

- [ ] **Step 2: Keep UpdateAccountDto for backward compat, add conversion**

Add a `From<UpdateAccountDto>` impl that converts the old sematics to the new:

```rust
impl From<UpdateAccountDto> for PatchAccountDto {
    fn from(dto: UpdateAccountDto) -> Self {
        Self {
            name: dto.name,
            initial_balance: dto.initial_balance,
            icon: dto.icon,
            color: dto.color,
            // If the frontend sends Some(value), map to Some(Some(value))
            // The old semantics can't express "clear", so we preserve old behavior
            account_number: dto.account_number.map(Some),
            institution: dto.institution.map(Some),
            credit_limit: dto.credit_limit.map(Some),
            billing_day: dto.billing_day.map(Some),
            payment_due_day: dto.payment_due_day.map(Some),
            interest_rate: dto.interest_rate.map(Some),
            chart_code: dto.chart_code.map(Some),
            parent_id: dto.parent_id.map(Some),
            low_balance_threshold: dto.low_balance_threshold.map(Some),
        }
    }
}
```

- [ ] **Step 3: Rewrite update_account to use PatchAccountDto**

In `account_service.rs`, replace the `update_account` method:

```rust
pub async fn update_account<E>(
    &self,
    _executor: E,
    id: Uuid,
    dto: PatchAccountDto,
) -> Result<AccountDto, AccountServiceError> {
    let mut account = self
        .account_repo
        .find_by_id(id)
        .await?
        .ok_or(AccountServiceError::AccountNotFound(id))?;

    account.change_name(&dto.name)?;

    {
        let balance = Money::new(dto.initial_balance, &account.currency_code)
            .map_err(|e| AccountServiceError::InvalidMoney(e.to_string()))?;
        account.update_initial_balance(balance)?;
    }

    if let Some(icon) = dto.icon {
        account.update_icon(icon)?;
    }
    if let Some(color) = dto.color {
        account.update_color(color)?;
    }
    if let Some(account_number) = dto.account_number {
        account.update_account_number(account_number)?;
    }
    if let Some(institution) = dto.institution {
        account.update_institution(institution)?;
    }
    if let Some(credit_limit) = dto.credit_limit {
        account.update_credit_limit(credit_limit)?;
    }
    if let Some(billing_day) = dto.billing_day {
        account.update_billing_day(billing_day)?;
    }
    if let Some(payment_due_day) = dto.payment_due_day {
        account.update_payment_due_day(payment_due_day)?;
    }
    if let Some(interest_rate) = dto.interest_rate {
        account.update_interest_rate(interest_rate)?;
    }
    if let Some(chart_code) = dto.chart_code {
        account.update_chart_code(chart_code)?;
    }
    if let Some(parent_id) = dto.parent_id {
        account.update_parent_id(parent_id)?;
    }
    if let Some(low_balance_threshold) = dto.low_balance_threshold {
        account.update_low_balance_threshold(low_balance_threshold)?;
    }

    self.account_repo.update(&account).await?;
    Ok(AccountDto::from(account))
}
```

- [ ] **Step 4: Add update_low_balance_threshold() to Account aggregate**

In `account.rs`, add the missing setter method:

```rust
pub fn update_low_balance_threshold(
    &mut self,
    threshold: Option<Decimal>,
) -> Result<(), AccountError> {
    self.ensure_not_deleted()?;
    self.low_balance_threshold = threshold;
    self.touch();
    Ok(())
}
```

- [ ] **Step 5: Update tauri_commands to accept PatchAccountDto**

In `account_commands.rs`, the `update_account` command should accept `PatchAccountDto` instead of `UpdateAccountDto`. The frontend will need to be updated correspondingly (handled in Task 5).

- [ ] **Step 6: Run backend tests**

Run: `cd src-tauri && cargo test account`
Expected: Some test updates needed since `update_account` now takes `PatchAccountDto`. Update the test DTOs accordingly.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "fix(accounts): introduce PatchAccountDto with null semantics

Some(Some(value)) = set, Some(None) = clear, None = no change.
This allows the frontend to clear optional fields like account_number
and institution, which was previously impossible."
```

---

### Task 5: Fix UpdateAccountDto null semantics — frontend (P2/P7)

**Files:**
- Modify: `src/lib/tauri/account.ts`
- Modify: `src/components/AccountForm.tsx:139-180`

- [ ] **Step 1: Update TypeScript interfaces**

In `src/lib/tauri/account.ts`, update `UpdateAccountDto`:

```typescript
export interface UpdateAccountDto {
  name: string;
  initial_balance: number;
  icon?: string;
  color?: string;
  // Optional fields use null for "clear", undefined for "no change"
  account_number?: string | null;
  institution?: string | null;
  credit_limit?: number | null;
  billing_day?: number | null;
  payment_due_day?: number | null;
  interest_rate?: number | null;
  chart_code?: string | null;
  low_balance_threshold?: number | null;
}
```

- [ ] **Step 2: Update AccountForm handleSubmit to send null for cleared fields**

In `AccountForm.tsx`, modify the edit-mode branch of `handleSubmit`:

```typescript
if (isEditMode && initialData) {
  const dto: UpdateAccountDto = {
    name: values.name,
    initial_balance: parseFloat(values.initial_balance),
  };

  // Always-send fields (no null semantics needed)
  if (values.icon) dto.icon = values.icon || '📁';
  if (values.color) dto.color = values.color || '#6B7280';

  // Clearable fields: empty string → null, non-empty → value, untouched → undefined
  // Helper: if initialData had a value and user cleared it, send null
  dto.account_number = values.account_number?.trim() || null;
  dto.institution = values.institution?.trim() || null;
  dto.low_balance_threshold = values.low_balance_threshold ? parseFloat(values.low_balance_threshold) : null;

  // Clearable number fields (only relevant for certain account types)
  if (values.credit_limit !== undefined) {
    dto.credit_limit = values.credit_limit ? parseFloat(values.credit_limit) : null;
  }
  if (values.billing_day !== undefined) {
    dto.billing_day = values.billing_day ? parseInt(values.billing_day) : null;
  }
  if (values.payment_due_day !== undefined) {
    dto.payment_due_day = values.payment_due_day ? parseInt(values.payment_due_day) : null;
  }
  if (values.interest_rate !== undefined) {
    dto.interest_rate = values.interest_rate ? parseFloat(values.interest_rate) : null;
  }
  if (values.chart_code !== undefined) {
    dto.chart_code = values.chart_code?.trim() || null;
  }

  onSubmit({ id: initialData.id, dto });
  return;
}
```

- [ ] **Step 3: Add clear buttons (×) to optional fields in edit mode**

For each clearable optional field in the `<details>` section, add a small clear button:

```tsx
<FormField
  control={form.control}
  name="account_number"
  render={({ field }) => (
    <FormItem>
      <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
        {t('accountForm.accountNumber')}
        <span className="text-muted-foreground/50 font-normal"> {t('common.optionalSuffix')}</span>
      </FormLabel>
      <div className="flex items-center gap-1">
        <FormControl><Input placeholder={t('accountForm.accountNumberPlaceholder')} className="h-9" {...field} /></FormControl>
        {isEditMode && field.value && (
          <Button type="button" variant="ghost" size="sm" className="h-9 w-9 p-0"
            onClick={() => field.onChange('')}>
            <X className="h-3 w-3" />
          </Button>
        )}
      </div>
      <FormMessage />
    </FormItem>
  )}
/>
```

Import `X` from `lucide-react` at the top of the file.

- [ ] **Step 4: Run type check**

Run: `pnpm type-check`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "fix(accounts): implement null semantics for optional field clearing

Frontend now sends null to clear optional fields (account_number, institution,
etc.) instead of omitting them. Adds clear buttons (×) to optional fields in
edit mode."
```

---

## Phase 2: Ownership Three-Class Model (P1 dimension 4)

### Task 6: Add Liability variant to Ownership enum + DB migration

**Files:**
- Modify: `src-tauri/src/domain/aggregates/account.rs` — Ownership enum
- Create: `src-tauri/migrations/20260606000002_add_liability_ownership.sql`

- [ ] **Step 1: Update Ownership enum in Rust**

In `account.rs`, change the `Ownership` enum:

```rust
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum Ownership {
    #[serde(rename = "own")]
    Own,
    #[serde(rename = "liability")]
    Liability,    // NEW
    #[serde(rename = "external")]
    External,
}

impl fmt::Display for Ownership {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Own => write!(f, "own"),
            Self::Liability => write!(f, "liability"),
            Self::External => write!(f, "external"),
        }
    }
}
```

- [ ] **Step 2: Update validate_balance for Liability**

In `account.rs`, update `validate_balance`:

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

    if matches!(
        account_type,
        AccountType::Cash
            | AccountType::Bank
            | AccountType::Investment
            | AccountType::BorrowedOut
            | AccountType::Prepaid
    ) && balance.amount < Decimal::ZERO
    {
        return Err(AccountError::NegativeBalanceNotAllowed {
            account_type: account_type.clone(),
            balance: balance.amount,
        });
    }

    // Liability types (CreditCard, BorrowedIn) allow negative balances
    // This was already the case — no change needed, just the comment.
    Ok(())
}
```

No logic change needed — CreditCard and BorrowedIn already allow negative balances. The change is that their `Ownership` is now `Liability` instead of `Own`.

- [ ] **Step 3: Write the migration SQL**

Create `20260606000002_add_liability_ownership.sql`:

```sql
-- Add 'liability' to ownership CHECK and migrate CreditCard/BorrowedIn

-- Migrate CreditCard and BorrowedIn accounts from 'own' to 'liability'
UPDATE accounts SET ownership = 'liability'
WHERE account_type IN ('credit_card', 'borrowed_in') AND ownership = 'own';

-- Recreate table with updated CHECK
CREATE TABLE accounts_backup AS SELECT * FROM accounts;
DROP TABLE accounts;

CREATE TABLE accounts (
    id TEXT PRIMARY KEY NOT NULL,
    name VARCHAR(100) NOT NULL,
    account_type VARCHAR(20) NOT NULL,
    currency_code VARCHAR(3) NOT NULL DEFAULT 'CNY',
    initial_balance DECIMAL(20,2) NOT NULL DEFAULT 0.00,
    ownership VARCHAR(10) NOT NULL DEFAULT 'own',
    icon VARCHAR(10) NOT NULL DEFAULT '📁',
    color VARCHAR(7) NOT NULL DEFAULT '#6B7280',
    chart_code VARCHAR(10),
    parent_id TEXT REFERENCES accounts(id) ON DELETE SET NULL,
    account_number VARCHAR(50),
    institution VARCHAR(100),
    credit_limit DECIMAL(20,2),
    billing_day INTEGER,
    payment_due_day INTEGER,
    interest_rate DECIMAL(5,4),
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    version INTEGER NOT NULL DEFAULT 1,
    low_balance_threshold DECIMAL(20,2),
    status TEXT DEFAULT 'active' CHECK(status IN ('active', 'archived', 'hidden')),
    opened_at TIMESTAMP,
    CHECK (account_type IN ('cash', 'bank', 'credit_card', 'investment',
           'borrowed_out', 'borrowed_in', 'prepaid', 'other', 'income', 'expense')),
    CHECK (ownership IN ('own', 'liability', 'external')),
    CHECK (billing_day IS NULL OR (billing_day >= 1 AND billing_day <= 31)),
    CHECK (payment_due_day IS NULL OR (payment_due_day >= 1 AND payment_due_day <= 31)),
    CHECK (interest_rate IS NULL OR interest_rate >= 0),
    FOREIGN KEY (currency_code) REFERENCES currencies(code) ON DELETE RESTRICT
);

INSERT INTO accounts SELECT * FROM accounts_backup;
DROP TABLE accounts_backup;

CREATE INDEX idx_accounts_type ON accounts(account_type);
CREATE INDEX idx_accounts_ownership ON accounts(ownership);
CREATE INDEX idx_accounts_currency ON accounts(currency_code);
CREATE INDEX idx_accounts_deleted ON accounts(deleted_at);
```

- [ ] **Step 4: Update row_to_account in account_repository.rs**

In the `ownership_str` match, add:

```rust
"liability" => Ownership::Liability,
```

- [ ] **Step 5: Update account_service.rs test DTOs**

In the test module, update any `Ownership::Own` references for CreditCard/BorrowedIn test accounts to `Ownership::Liability` where appropriate.

- [ ] **Step 6: Run backend tests**

Run: `cd src-tauri && cargo test account`
Expected: PASS (with updated tests)

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat(accounts): add Liability ownership variant

Extends Ownership from {Own, External} to {Own, Liability, External}.
Migrates CreditCard and BorrowedIn accounts to 'liability' ownership.
Updates DB CHECK constraint to include 'liability'."
```

---

### Task 7: Update frontend for Ownership::Liability

**Files:**
- Modify: `src/lib/tauri/account.ts`
- Modify: `src/components/AccountWizard.tsx`
- Modify: `src/components/AccountForm.tsx`
- Modify: `src/pages/AccountsPage.tsx`

- [ ] **Step 1: Update TypeScript Ownership type**

In `src/lib/tauri/account.ts`, update the `Ownership` type:

```typescript
export type Ownership = 'own' | 'liability' | 'external';
```

- [ ] **Step 2: Update AccountWizard Step 1 — three cards**

Replace the two-card Step 1 with three cards. Change the `AccountNature` type:

```typescript
type AccountNature = 'asset' | 'liability' | 'income-expense';

const LIABILITY_TYPES: { type: AccountType; labelKey: string; icon: React.ReactNode }[] = [
  { type: 'CreditCard', labelKey: 'accountForm.creditCardWithChinese', icon: <CreditCard className="h-5 w-5" /> },
  { type: 'BorrowedIn', labelKey: 'accountForm.borrowedInWithChinese', icon: <ArrowRightLeft className="h-5 w-5" /> },
];
```

Add a third card for liability between the asset and income-expense cards. Change the onClick to set `nature = 'liability'`. CreditCard and BorrowedIn should appear in both `ASSET_TYPES` (for display/headings) and `LIABILITY_TYPES`.

- [ ] **Step 3: Update Step 1 preview tags to include ALL subtypes**

In the asset card preview, change from hardcoded `['Cash','Bank','CreditCard','Investment','Prepaid']` to dynamically rendering all ASSET_TYPES entries. Remove the hardcoded array entirely.

- [ ] **Step 4: Update Step 2 to filter by nature**

In Step 2, `getAvailableTypes()` should return:

```typescript
const getAvailableTypes = (): { type: AccountType; labelKey: string; icon: React.ReactNode }[] => {
  if (nature === 'asset') return ASSET_TYPES.filter(t => !['CreditCard'].includes(t.type) || true); // all asset types
  if (nature === 'liability') return LIABILITY_TYPES;
  if (nature === 'income-expense') return INCOME_EXPENSE_TYPES;
  return [];
};
```

When the user picks CreditCard or BorrowedIn from an asset category listing, auto-set `ownership` to `'liability'`.

- [ ] **Step 5: Update ownership auto-assignment**

In the wizard's `handleSubmit`, update:

```typescript
const ownership: Ownership =
  accountType === 'Income' || accountType === 'Expense' ? 'external'
  : accountType === 'CreditCard' || accountType === 'BorrowedIn' ? 'liability'
  : 'own';
```

- [ ] **Step 6: Update AccountsPage TYPE_ORDER grouping**

Replace the flat `TYPE_ORDER` with three groups:

```typescript
const OWNERSHIP_GROUPS: { ownership: Ownership; labelKey: string; colorClass: string; types: AccountType[] }[] = [
  { ownership: 'own', labelKey: 'accounts.assetGroup', colorClass: 'text-emerald-600', types: ['Cash', 'Bank', 'Investment', 'BorrowedOut', 'Prepaid', 'Other'] },
  { ownership: 'liability', labelKey: 'accounts.liabilityGroup', colorClass: 'text-red-600', types: ['CreditCard', 'BorrowedIn'] },
  { ownership: 'external', labelKey: 'accounts.incomeExpenseGroup', colorClass: 'text-amber-600', types: ['Income', 'Expense'] },
];
```

Update the filter buttons to show 3 ownership groups + "All".

- [ ] **Step 7: Update AccountForm ownership toggle**

In edit mode, show ownership as a read-only tag with the correct label instead of a toggle. In create mode, the ownership is auto-determined by the account type selection (from wizard).

- [ ] **Step 8: Add i18n keys for the three groups**

In `en.json`:
```json
"accounts.assetGroup": "Asset Accounts",
"accounts.liabilityGroup": "Liability Accounts",
"accounts.incomeExpenseGroup": "Income & Expense"
```

In `zh.json`:
```json
"accounts.assetGroup": "资产账户",
"accounts.liabilityGroup": "负债账户",
"accounts.incomeExpenseGroup": "收支账户"
```

- [ ] **Step 9: Run type check + lint**

Run: `pnpm type-check && pnpm lint`
Expected: PASS

- [ ] **Step 10: Commit**

```bash
git add -A && git commit -m "feat(accounts): frontend three-class ownership — asset/liability/income-expense

Updates AccountWizard to three-card Step 1, AccountsPage grouped by
ownership class, and AccountForm ownership auto-assignment."
```

---

## Phase 3: Page Redesign (P1/P2 UX)

### Task 8: Add summary cards to AccountsPage (P23)

**Files:**
- Modify: `src/pages/AccountsPage.tsx`
- Modify: `src/lib/tauri/account.ts` — add `listAccountsByOwnership` type support

- [ ] **Step 1: Compute summary balances**

In `AccountsPage`, after the `accounts` query, add:

```typescript
const summary = useMemo(() => {
  const assets = accounts
    .filter(a => a.ownership === 'own')
    .reduce((sum, a) => sum + Number(a.current_balance), 0);
  const liabilities = accounts
    .filter(a => a.ownership === 'liability')
    .reduce((sum, a) => sum + Number(a.current_balance), 0);
  const netWorth = assets + liabilities;
  return { assets, liabilities, netWorth };
}, [accounts]);
```

- [ ] **Step 2: Render summary cards above the filter bar**

Add three cards in a grid:

```tsx
<div className="grid grid-cols-3 gap-3 mb-4">
  <div className="rounded-lg border bg-emerald-50 dark:bg-emerald-950/20 p-3">
    <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('accounts.totalAssets')}</div>
    <div className="text-xl font-bold text-emerald-600 dark:text-emerald-400">
      {formatCurrencyWithDto(summary.assets, currencies.find(c => c.code === 'CNY') || defaultCurrency)}
    </div>
  </div>
  <div className="rounded-lg border bg-red-50 dark:bg-red-950/20 p-3">
    <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('accounts.totalLiabilities')}</div>
    <div className="text-xl font-bold text-red-600 dark:text-red-400">
      {formatCurrencyWithDto(summary.liabilities, currencies.find(c => c.code === 'CNY') || defaultCurrency)}
    </div>
  </div>
  <div className="rounded-lg border bg-blue-50 dark:bg-blue-950/20 p-3">
    <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('accounts.netWorth')}</div>
    <div className="text-xl font-bold text-blue-600 dark:text-blue-400">
      {formatCurrencyWithDto(summary.netWorth, currencies.find(c => c.code === 'CNY') || defaultCurrency)}
    </div>
  </div>
</div>
```

- [ ] **Step 3: Add i18n keys**

In `en.json`:
```json
"accounts.totalAssets": "Total Assets",
"accounts.totalLiabilities": "Total Liabilities",
"accounts.netWorth": "Net Worth"
```

In `zh.json`:
```json
"accounts.totalAssets": "总资产",
"accounts.totalLiabilities": "总负债",
"accounts.netWorth": "净资产"
```

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat(accounts): add asset/liability/net-worth summary cards

Adds three summary cards above the account list showing total assets,
total liabilities, and net worth in real-time."
```

---

### Task 9: Replace inline delete confirm with DeleteAccountDialog (P26/P31/P32)

**Files:**
- Create: `src/components/DeleteAccountDialog.tsx`
- Modify: `src/pages/AccountsPage.tsx`

- [ ] **Step 1: Create DeleteAccountDialog component**

```tsx
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from './ui/dialog';
import { Button } from './ui/button';
import { useMutation } from '@tanstack/react-query';
import { useQueryClient } from '@tanstack/react-query';
import { deleteAccount } from '../lib/tauri/account';
import { toast } from 'sonner';
import { useTranslation } from 'react-i18next';
import type { AccountDto } from '../lib/tauri/account';

interface DeleteAccountDialogProps {
  account: AccountDto | null;
  transactionCount?: number;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function DeleteAccountDialog({ account, transactionCount, open, onOpenChange }: DeleteAccountDialogProps) {
  const { t } = useTranslation();
  const queryClient = useQueryClient();

  const deleteMutation = useMutation({
    mutationFn: deleteAccount,
    onMutate: async (accountId: string) => {
      await queryClient.cancelQueries({ queryKey: ['accounts'] });
      const previousAccounts = queryClient.getQueryData<AccountDto[]>(['accounts']);
      if (previousAccounts) {
        queryClient.setQueryData<AccountDto[]>(
          ['accounts'],
          previousAccounts.filter(a => a.id !== accountId)
        );
      }
      return { previousAccounts };
    },
    onSuccess: () => {
      toast.success(t('accounts.accountDeleted'));
      onOpenChange(false);
    },
    onError: (error, _accountId, context) => {
      if (context?.previousAccounts) {
        queryClient.setQueryData<AccountDto[]>(['accounts'], context.previousAccounts);
      }
      toast.error(t('accounts.deleteFailed'));
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
    },
  });

  if (!account) return null;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('accounts.deleteAccount')}</DialogTitle>
          <DialogDescription>
            {t('accounts.deleteConfirmMessage', { name: account.name, count: transactionCount ?? 0 })}
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)} disabled={deleteMutation.isPending}>
            {t('common.cancel')}
          </Button>
          <Button
            variant="destructive"
            onClick={() => deleteMutation.mutate(account.id)}
            disabled={deleteMutation.isPending}
          >
            {deleteMutation.isPending ? t('accounts.deleting') : t('accounts.deleteConfirmButton')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
```

- [ ] **Step 2: Add i18n keys for delete dialog**

In `en.json`:
```json
"accounts.deleteConfirmMessage": "Are you sure you want to delete \"{{name}}\"? {{count}} transaction(s) will be preserved but the account will be marked as deleted.",
"accounts.deleteConfirmButton": "Delete Account",
"accounts.deleteFailed": "Failed to delete account"
```

In `zh.json`:
```json
"accounts.deleteConfirmMessage": "确定要删除\"{{name}}\"吗？该账户的 {{count}} 笔交易记录将保留，但账户将被标记为已删除。",
"accounts.deleteConfirmButton": "确认删除",
"accounts.deleteFailed": "删除账户失败"
```

- [ ] **Step 3: Replace inline confirm in AccountsPage**

Remove the `deleteConfirmId` state and the inline confirm UI in `AccountGroupTable`. Replace with:

```tsx
const [deletingAccount, setDeletingAccount] = useState<AccountDto | null>(null);
```

In each row's delete button:

```tsx
<Button variant="ghost" size="sm" onClick={() => setDeletingAccount(account)}>
  <Trash2 className="h-4 w-4 text-red-500" />
</Button>
```

At the bottom of `AccountsPage`, add:

```tsx
<DeleteAccountDialog
  account={deletingAccount}
  open={!!deletingAccount}
  onOpenChange={(open) => { if (!open) setDeletingAccount(null); }}
/>
```

- [ ] **Step 4: Remove the old `deleteMutation` from AccountsPage**

Move the mutation logic into the `DeleteAccountDialog` component (already done in Step 1). Remove the inline `deleteMutation` and `deleteConfirmId` state from `AccountsPage`.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(accounts): replace inline delete with confirmation dialog

Shows account name and transaction count impact. Uses destructive
variant for confirm button with loading state. Preserves optimistic
update + rollback strategy."
```

---

### Task 10: Add initial balance change warning to edit form (P8)

**Files:**
- Modify: `src/components/AccountForm.tsx`

- [ ] **Step 1: Add warning below initial_balance in edit mode**

In the edit-mode initial_balance section, add a warning message below the input:

```tsx
{isEditMode && (
  <p className="text-xs text-amber-600 dark:text-amber-400 mt-1 flex items-center gap-1">
    <AlertTriangle className="h-3 w-3" />
    {t('accountForm.balanceChangeWarning')}
  </p>
)}
```

Import `AlertTriangle` from `lucide-react`.

- [ ] **Step 2: Add i18n key**

In `en.json`:
```json
"accountForm.balanceChangeWarning": "Changing the initial balance will affect the current balance display"
```

In `zh.json`:
```json
"accountForm.balanceChangeWarning": "修改初始余额将影响当前余额显示"
```

- [ ] **Step 3: Add info icon for immutable currency field**

In the currency Select (disabled in edit mode), add a tooltip:

```tsx
<div className="flex items-center gap-1">
  <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
    {t('accountForm.currency')}
  </FormLabel>
  {isEditMode && (
    <span className="text-xs text-muted-foreground/50" title={t('accountForm.currencyImmutableHint')}>
      ⓘ
    </span>
  )}
</div>
```

Add i18n keys:
```json
// en.json
"accountForm.currencyImmutableHint": "Currency cannot be changed after creation because it affects transaction records"
// zh.json
"accountForm.currencyImmutableHint": "币种创建后不可更改，因为它会影响交易记录"
```

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat(accounts): add balance change warning and immutable field hints

Adds amber warning below initial balance in edit mode. Adds ⓘ hint
for currency explaining why it's locked."
```

---

### Task 11: Add name uniqueness check on update (P9)

**Files:**
- Modify: `src-tauri/src/application/services/account_service.rs:113-168`

- [ ] **Step 1: Add name uniqueness check in update_account**

In `account_service.rs`, after loading the account, add a duplicate name check:

```rust
pub async fn update_account<E>(
    &self,
    _executor: E,
    id: Uuid,
    dto: PatchAccountDto,
) -> Result<AccountDto, AccountServiceError> {
    let mut account = self
        .account_repo
        .find_by_id(id)
        .await?
        .ok_or(AccountServiceError::AccountNotFound(id))?;

    // Check for duplicate name (only if name changed)
    if dto.name != account.name {
        if let Some(existing) = self.account_repo.find_by_name(&dto.name).await? {
            if existing.id != id {
                return Err(AccountServiceError::DuplicateAccountName(dto.name));
            }
        }
    }

    // ... rest of update logic
}
```

- [ ] **Step 2: Run backend tests**

Run: `cd src-tauri && cargo test account`
Expected: PASS (add a test for duplicate name on update)

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "fix(accounts): check name uniqueness on update

Prevents creating duplicate account names when renaming. Only checks
if the new name differs from the current one."
```

---

This plan covers the P0 and P1 fixes and the Ownership refactor. P2 and P3 items (editable page route, unified create entry, Decimal TEXT migration, PG repo, etc.) are deferred to subsequent plans to keep scope manageable.