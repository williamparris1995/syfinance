# Unified Account Model — Design Spec

**Date:** 2026-05-22
**Status:** Draft
**Approach:** A — Full unification (accounts absorb categories)

## Motivation

The current data model separates `accounts` (where money lives) from `categories` (how transactions are classified). This creates a FK constraint problem: transaction entries that represent category-side debits/credits use `Uuid::nil()` as `account_id`, which violates `FOREIGN KEY (account_id) REFERENCES accounts(id)`.

The fix is not to make `account_id` nullable, but to unify accounts and categories into a single entity — matching how GnuCash and enterprise ERP systems model counterparties as real accounts.

## Core Concept

**Every transaction entry references a real account.** No more `Uuid::nil()` sentinels.

Accounts have an `ownership` dimension:
- **own** — the user's own asset/liability accounts (bank, cash, credit card, loan). Included in net worth and statistics.
- **external** — counterparty/category accounts (merchants, employers, banks for loans). Excluded from net worth and statistics.

External accounts absorb the role of categories — they carry `icon`, `color`, and `chart_code` for classification.

## Schema Changes

### accounts table

Add columns:
```sql
ownership VARCHAR(10) NOT NULL DEFAULT 'own'  -- 'own' | 'external'
icon VARCHAR(10) NOT NULL DEFAULT '📁'
color VARCHAR(7) NOT NULL DEFAULT '#6B7280'
chart_code VARCHAR(10)  -- NULL for own accounts, required for external
parent_id TEXT REFERENCES accounts(id) ON DELETE SET NULL
```

Note: `chart_code` was removed from accounts in migration 20260507000011. It is re-added here to carry the accounting code for external accounts (own accounts leave it NULL since their chart_code is implied by account_type).

Add CHECK constraint:
```sql
CHECK (ownership IN ('own', 'external'))
```

### AccountType enum

Extend with two new variants:
```sql
CHECK (account_type IN ('cash', 'bank', 'credit_card', 'investment', 'loan', 'other', 'income', 'expense'))
```

### categories table — DROPPED

All existing category rows are migrated to accounts with `ownership = 'external'`.

### transaction_entries table

Remove `category_id` column. The external account itself carries category semantics (icon, color, chart_code).

Migration: drop the `category_id` column and its FK during table recreation.

## Domain Model Changes

### Account aggregate (modified)

```rust
pub enum Ownership { Own, External }

pub enum AccountType {
    Cash, Bank, CreditCard, Investment, Loan, Other,  // existing
    Income, Expense,  // new — for external accounts
}

pub struct Account {
    pub id: Uuid,
    pub name: String,
    pub ownership: Ownership,    // new
    pub account_type: AccountType,
    pub icon: String,            // new (from Category)
    pub color: String,           // new (from Category)
    pub chart_code: String,      // new — chart_of_accounts code
    pub parent_id: Option<Uuid>, // new (from Category)
    pub currency_code: String,
    pub balance: Money,
    // ... existing optional fields (account_number, institution, etc.)
}
```

### Category aggregate — REMOVED

Delete: `Category`, `CategoryType`, `CategoryEvent`, `CategoryError`, `CategoryRepository`, `CategoryService`, `CategoryCommands`, `CategoryDto`, `CreateCategoryDto`, `UpdateCategoryDto`.

### TransactionEntry (modified)

Remove `category_id: Option<String>` field. Every entry's classification is derived from the referenced account's `chart_code` and `account_type`.

### SimpleExpenseDto (modified)

```rust
pub struct SimpleExpenseDto {
    pub date: NaiveDate,
    pub amount: Decimal,
    pub account_id: Uuid,         // renamed: debit_account_id (external account)
    pub credit_account_id: Uuid,  // new: own account
    pub description: String,
}
```

### SimpleIncomeDto (modified)

```rust
pub struct SimpleIncomeDto {
    pub date: NaiveDate,
    pub amount: Decimal,
    pub debit_account_id: Uuid,   // own account — receives the money
    pub credit_account_id: Uuid,  // external account — income source (salary, etc.)
    pub description: String,
}
```

### Transfer DTO (unchanged)

Transfer already uses two real account IDs (`from_account_id`, `to_account_id`). Both must be `ownership = Own`.

## Backend Service Changes

### transaction_service.rs — create_expense

Before (broken):
```
fetch account by id → fetch category by category_id →
create entries with Uuid::nil() for category side → FK violation
```

After:
```
fetch debit_account (external) by id → validate type = Expense →
fetch credit_account (own) by id → validate ownership = Own →
create entries with real account IDs → update own account balance
```

Both `create_expense` and `create_income` use two real accounts. Transfers already use real accounts — unchanged.

### transaction_commands.rs

`create_simple_expense` signature changes:
```rust
pub async fn create_simple_expense(
    state: State<'_, TransactionCommandState>,
    account_id: String,          // debit: external account
    credit_account_id: String,   // credit: own account (NEW)
    amount: String,
    date: String,
    description: String,
) -> Result<String, String>
```

`create_simple_income` signature changes:
```rust
pub async fn create_simple_income(
    state: State<'_, TransactionCommandState>,
    debit_account_id: String,    // own account — receives money (was account_id)
    credit_account_id: String,   // external account — income source (was category_id)
    amount: String,
    date: String,
    description: String,
) -> Result<String, String>
```

### New: account filtering by ownership

Add `list_accounts_by_ownership(ownership: Ownership)` to account service and commands.

## Frontend Changes

### SimpleTransactionForm

- Props change: `categories: Category[]` → `externalAccounts: Account[]` (filtered to ownership=external, matching type)
- Two account selectors instead of "account + category":
  - Expense mode: [Own Account (credit)] → [External Account (debit)]
  - Income mode: [External Account (credit)] → [Own Account (debit)]
  - Transfer mode: [From Account (own)] → [To Account (own)]
- Remove `categoryId` from form state and submit data

### AccountForm

Add fields:
- `ownership` — toggle (Own / External) at top of form
- `icon` — emoji picker or select
- `color` — hex color picker (preset swatches)
- `chart_code` — shown when external account type selected

Account type options adjust based on ownership:
- Own: Cash, Bank, CreditCard, Investment, Loan, Other
- External: Income, Expense

### API layer

`transactions.ts`: `SimpleExpenseRequest` gains `creditAccountId`, loses `categoryId`.

`category.ts`: deleted entirely.

### Reports / HomePage

Replace category lookup with account lookup. Filter statistics:
```
entry.account_id → accounts.find() → ownership === 'own' → include
```

## Migration Strategy

### Phase 1: Schema migration (one migration file)

1. PRAGMA foreign_keys = OFF
2. Add new columns to accounts (ownership, icon, color, parent_id, chart_code)
3. Migrate category rows → accounts with ownership='external'
4. Drop categories table
5. Recreate transaction_entries without category_id column
6. PRAGMA foreign_keys = ON

### Phase 2: Backend changes

Domain model, services, commands updated to remove category dependencies.

### Phase 3: Frontend changes

Forms, API layer, reports updated.

### Phase 4: Cleanup

Remove unused category DTOs, repository trait impls, test fixtures.

## Statistics Behavior

| What | Filter | Result |
|---|---|---|
| Net worth | SUM(own accounts balance) | Your actual assets - liabilities |
| Monthly expense | SUM(credit entries WHERE account.ownership = own AND account.type IN (cash,bank,credit_card)) | Money flowing out |
| Monthly income | SUM(debit entries WHERE account.ownership = own AND account.type IN (cash,bank,credit_card)) | Money flowing in |
| Category breakdown | SUM by external account name/icon | Spending by merchant category |

## Risks & Mitigations

- **Risk:** Migration breaks existing transaction data. **Mitigation:** Backup tables before migration; validate row counts post-migration.
- **Risk:** External accounts appearing in account list confuses users. **Mitigation:** Default filter to ownership=own in account list views; external accounts shown in a separate tab or filtered view.
- **Risk:** Transfer still uses two own accounts — need to ensure from/to are both own. **Mitigation:** Transfer form validates ownership=own for both selectors.
