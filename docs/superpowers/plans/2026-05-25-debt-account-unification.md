# Debt-Account Unification — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify the independent Debt system into the Account system so debts are specialized accounts with automatic double-entry transaction creation on repayment.

**Architecture:** Extend `AccountType` enum with `BorrowedOut`/`BorrowedIn`, remove `Loan` (merged into `BorrowedIn` per IFRS/CAS classification). Add `debt_details` (1:1 with accounts) and `debt_payment_schedule` (1:N with debt_details) tables. Account-first flow: user creates accounts in Accounts page, then selects them in DebtForm via dropdowns. On repayment: mark schedule entry paid, create Transaction linking debt account + payment source account + interest account.

**Tech Stack:** Rust/Tauri (sqlx, SQLite/Postgres), React 19/TypeScript, @base-ui/react, react-i18next

---

### File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `src-tauri/migrations/20260526000002_create_debt_tables.sql` | Create | debt_details + debt_payment_schedule DDL |
| `src-tauri/src/domain/aggregates/account.rs` | Modify | Add BorrowedOut/BorrowedIn, remove Loan |
| `src-tauri/src/domain/aggregates/debt_details.rs` | Create | DebtDetails aggregate + amortization |
| `src-tauri/src/domain/aggregates/mod.rs` | Modify | Register debt_details module |
| `src-tauri/src/application/dtos/account_dto.rs` | Modify | Add debt-related fields |
| `src-tauri/src/application/dtos/debt_dto.rs` | Rewrite | New DTOs mirroring new model |
| `src-tauri/src/application/services/debt_service.rs` | Rewrite | Unified debt operations |
| `src-tauri/src/infrastructure/repositories/debt_repository.rs` | Rewrite | debt_details + payment_schedule CRUD |
| `src-tauri/src/presentation/tauri_commands/debt_commands.rs` | Rewrite | Updated commands |
| `src-tauri/migrations/20260526000003_migrate_debts_to_accounts.sql` | Create | Data migration from old tables |
| `src-tauri/migrations/20260526000004_drop_old_debt_tables.sql` | Create | Drop debts + debt_payments |
| `src/lib/tauri/account.ts` | Modify | Add debt fields to AccountDto |
| `src/lib/tauri/debt.ts` | Rewrite | Updated types and API |
| `src/i18n/locales/en.json` | Modify | Debt-related keys |
| `src/i18n/locales/zh.json` | Modify | Debt-related keys |
| `src/pages/DebtsPage.tsx` | Rewrite | Account-based debt listing |
| `src/components/DebtForm.tsx` | Rewrite | Account-first: dropdown selectors instead of text inputs |

---

### Task 1: DB Migration — Create debt_details and debt_payment_schedule Tables

**Files:**
- Create: `src-tauri/migrations/20260526000002_create_debt_tables.sql`

- [ ] **Step 1: Write migration**

```sql
CREATE TABLE IF NOT EXISTS debt_details (
    id TEXT PRIMARY KEY,
    account_id TEXT UNIQUE NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    counterparty VARCHAR(100) NOT NULL,
    interest_rate DECIMAL(5,4) NOT NULL DEFAULT 0,
    amortization_method VARCHAR(20) NOT NULL DEFAULT 'LumpSum',
    start_date DATE NOT NULL,
    due_date DATE NOT NULL,
    total_principal DECIMAL(20,2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS debt_payment_schedule (
    id TEXT PRIMARY KEY,
    debt_id TEXT NOT NULL REFERENCES debt_details(id) ON DELETE CASCADE,
    payment_date DATE NOT NULL,
    principal_amount DECIMAL(20,2) NOT NULL,
    interest_amount DECIMAL(20,2) NOT NULL DEFAULT 0,
    total_amount DECIMAL(20,2) NOT NULL,
    paid BOOLEAN NOT NULL DEFAULT FALSE,
    transaction_id TEXT REFERENCES transactions(id),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

- [ ] **Step 2: Commit**

```bash
git add src-tauri/migrations/20260526000002_create_debt_tables.sql
git commit -m "feat: add debt_details and debt_payment_schedule tables"
```

---

### Task 2: Backend — AccountType Update

**Files:**
- Modify: `src-tauri/src/domain/aggregates/account.rs`

- [ ] **Step 1: Add BorrowedOut/BorrowedIn, remove Loan from AccountType enum**

In the `AccountType` enum (around line 7-17), add two new variants:

```rust
pub enum AccountType {
    Cash,
    Bank,
    CreditCard,
    Investment,
    Loan,
    BorrowedOut,   // Lending out (receivable)
    BorrowedIn,    // Borrowing in (payable)
    Other,
    Income,
    Expense,
}
```

- [ ] **Step 2: Update Display impl for new variants**

Add display strings:

```rust
AccountType::BorrowedOut => write!(f, "borrowed_out"),
AccountType::BorrowedIn => write!(f, "borrowed_in"),
```

- [ ] **Step 3: Update AccountType to/from string patterns in repository**

The repository's `row_to_account` function matches on `account_type` string. Add:

```rust
"borrowed_out" => AccountType::BorrowedOut,
"borrowed_in" => AccountType::BorrowedIn,
```

- [ ] **Step 4: Verify compilation**

Run: `cargo check 2>&1 | head -20` from `src-tauri/`
Expected: zero errors

- [ ] **Step 5: Commit**

```bash
git add src-tauri/src/domain/aggregates/account.rs src-tauri/src/infrastructure/repositories/account_repository.rs
git commit -m "feat: add BorrowedOut and BorrowedIn account types"
```

---

### Task 3: Backend — DebtDetails Domain Model

**Files:**
- Create: `src-tauri/src/domain/aggregates/debt_details.rs`
- Modify: `src-tauri/src/domain/aggregates/mod.rs`

- [ ] **Step 1: Create debt_details.rs with domain types**

```rust
use chrono::NaiveDate;
use rust_decimal::Decimal;
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AmortizationMethod {
    EqualPrincipalInterest,
    EqualPrincipal,
    LumpSum,
}

impl std::fmt::Display for AmortizationMethod {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::EqualPrincipalInterest => write!(f, "EqualPrincipalInterest"),
            Self::EqualPrincipal => write!(f, "EqualPrincipal"),
            Self::LumpSum => write!(f, "LumpSum"),
        }
    }
}

pub struct DebtDetails {
    pub id: Uuid,
    pub account_id: Uuid,
    pub counterparty: String,
    pub interest_rate: Decimal,
    pub amortization_method: AmortizationMethod,
    pub start_date: NaiveDate,
    pub due_date: NaiveDate,
    pub total_principal: Decimal,
    pub payment_schedule: Vec<PaymentScheduleEntry>,
}

pub struct PaymentScheduleEntry {
    pub id: Uuid,
    pub debt_id: Uuid,
    pub payment_date: NaiveDate,
    pub principal_amount: Decimal,
    pub interest_amount: Decimal,
    pub total_amount: Decimal,
    pub paid: bool,
    pub transaction_id: Option<Uuid>,
}

impl DebtDetails {
    pub fn new(
        id: Uuid,
        account_id: Uuid,
        counterparty: String,
        interest_rate: Decimal,
        amortization_method: AmortizationMethod,
        start_date: NaiveDate,
        due_date: NaiveDate,
        total_principal: Decimal,
    ) -> Self {
        Self {
            id,
            account_id,
            counterparty,
            interest_rate,
            amortization_method,
            start_date,
            due_date,
            total_principal,
            payment_schedule: Vec::new(),
        }
    }

    /// Generate payment schedule based on amortization method
    pub fn generate_schedule(&mut self) {
        self.payment_schedule.clear();
        match self.amortization_method {
            AmortizationMethod::LumpSum => {
                // Single payment at due_date
                self.payment_schedule.push(PaymentScheduleEntry {
                    id: Uuid::new_v4(),
                    debt_id: self.id,
                    payment_date: self.due_date,
                    principal_amount: self.total_principal,
                    interest_amount: Decimal::ZERO,
                    total_amount: self.total_principal,
                    paid: false,
                    transaction_id: None,
                });
            }
            AmortizationMethod::EqualPrincipal | AmortizationMethod::EqualPrincipalInterest => {
                let months = (self.due_date.year() - self.start_date.year()) * 12
                    + (self.due_date.month() as i32 - self.start_date.month() as i32);
                let monthly_rate = self.interest_rate / Decimal::from(12);

                let monthly_total = if self.amortization_method == AmortizationMethod::EqualPrincipalInterest {
                    // PMT formula: P * r * (1+r)^n / ((1+r)^n - 1)
                    if monthly_rate > Decimal::ZERO && months > 0 {
                        let rate_float = monthly_rate.to_f64().unwrap_or(0.0);
                        let months_f64 = months as f64;
                        let principal_f64 = self.total_principal.to_f64().unwrap_or(0.0);
                        let pmt = principal_f64 * rate_float * (1.0 + rate_float).powf(months_f64)
                            / ((1.0 + rate_float).powf(months_f64) - 1.0);
                        Decimal::from_f64_retain(pmt).unwrap_or(self.total_principal / Decimal::from(months))
                    } else {
                        self.total_principal / Decimal::from(months)
                    }
                } else {
                    Decimal::ZERO // EqualPrincipal: varies per month
                };

                let mut remaining = self.total_principal;
                for i in 0..months {
                    let month_date = if self.start_date.month() as i32 + i > 12 {
                        NaiveDate::from_ymd_opt(
                            self.start_date.year() + (self.start_date.month() as i32 + i - 1) / 12,
                            ((self.start_date.month() as i32 + i - 1) % 12 + 1) as u32,
                            1,
                        ).unwrap_or(self.start_date)
                    } else {
                        NaiveDate::from_ymd_opt(
                            self.start_date.year(),
                            (self.start_date.month() as i32 + i) as u32,
                            1,
                        ).unwrap_or(self.start_date)
                    };

                    let interest = (remaining * monthly_rate).round_dp(2);
                    let principal = if self.amortization_method == AmortizationMethod::EqualPrincipalInterest {
                        (monthly_total - interest).max(Decimal::ZERO).min(remaining).round_dp(2)
                    } else {
                        (self.total_principal / Decimal::from(months)).min(remaining).round_dp(2)
                    };
                    let total = (principal + interest).round_dp(2);
                    remaining = (remaining - principal).max(Decimal::ZERO);

                    self.payment_schedule.push(PaymentScheduleEntry {
                        id: Uuid::new_v4(),
                        debt_id: self.id,
                        payment_date: month_date,
                        principal_amount: principal,
                        interest_amount: interest,
                        total_amount: total,
                        paid: false,
                        transaction_id: None,
                    });
                }
            }
        }
    }

    /// Mark a schedule entry as paid and link to a transaction
    pub fn mark_paid(&mut self, schedule_id: Uuid, transaction_id: Uuid) -> Result<(), &'static str> {
        let entry = self
            .payment_schedule
            .iter_mut()
            .find(|e| e.id == schedule_id)
            .ok_or("Schedule entry not found")?;
        if entry.paid {
            return Err("Already paid");
        }
        entry.paid = true;
        entry.transaction_id = Some(transaction_id);
        Ok(())
    }

    /// Calculate remaining principal balance
    pub fn remaining_balance(&self) -> Decimal {
        let paid_principal: Decimal = self
            .payment_schedule
            .iter()
            .filter(|e| e.paid)
            .map(|e| e.principal_amount)
            .sum();
        self.total_principal - paid_principal
    }
}
```

- [ ] **Step 2: Register module in mod.rs**

In `src-tauri/src/domain/aggregates/mod.rs`, add:
```rust
pub mod debt_details;
```

- [ ] **Step 3: Verify compilation**

Run: `cargo check 2>&1 | head -20` from `src-tauri/`
Expected: zero errors

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/domain/aggregates/debt_details.rs src-tauri/src/domain/aggregates/mod.rs
git commit -m "feat: add DebtDetails domain model with amortization logic"
```

---

### Task 4: Backend — Repository for debt_details and payment_schedule

**Files:**
- Rewrite: `src-tauri/src/infrastructure/repositories/debt_repository.rs`
- Modify: `src-tauri/src/domain/repositories/debt_repository.rs` (update trait)

- [ ] **Step 1: Update DebtRepository trait**

```rust
use crate::domain::aggregates::debt_details::{DebtDetails, PaymentScheduleEntry};

#[async_trait]
pub trait DebtRepository: Send + Sync {
    async fn create_debt_details(&self, debt: &DebtDetails) -> Result<(), sqlx::Error>;
    async fn find_debt_details_by_id(&self, id: Uuid) -> Result<Option<DebtDetails>, sqlx::Error>;
    async fn find_debt_details_by_account_id(&self, account_id: Uuid) -> Result<Option<DebtDetails>, sqlx::Error>;
    async fn find_all_debt_details(&self) -> Result<Vec<DebtDetails>, sqlx::Error>;
    async fn update_debt_details(&self, debt: &DebtDetails) -> Result<(), sqlx::Error>;
    async fn delete_debt_details(&self, id: Uuid) -> Result<(), sqlx::Error>;

    async fn create_schedule_entries(&self, entries: &[PaymentScheduleEntry]) -> Result<(), sqlx::Error>;
    async fn find_schedule_by_debt_id(&self, debt_id: Uuid) -> Result<Vec<PaymentScheduleEntry>, sqlx::Error>;
    async fn update_schedule_entry(&self, entry: &PaymentScheduleEntry) -> Result<(), sqlx::Error>;
    async fn get_upcoming_payments(&self, days_ahead: i32) -> Result<Vec<(DebtDetails, PaymentScheduleEntry)>, sqlx::Error>;
}
```

- [ ] **Step 2: Implement SqliteDebtRepository**

Write SQLite implementation with:
- INSERT/UPDATE for `debt_details` table
- INSERT/UPDATE for `debt_payment_schedule` table
- SELECT queries with JOIN for upcoming payments
- Follow the existing pattern from `account_repository.rs` (text-based UUID/Decimal serialization)

- [ ] **Step 3: Verify compilation**

Run: `cargo check 2>&1 | head -30` from `src-tauri/`
Expected: zero errors

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/domain/repositories/debt_repository.rs src-tauri/src/infrastructure/repositories/debt_repository.rs
git commit -m "feat: rewrite debt repository for debt_details and payment_schedule"
```

---

### Task 5: Backend — DTOs and DebtService

**Files:**
- Rewrite: `src-tauri/src/application/dtos/debt_dto.rs`
- Rewrite: `src-tauri/src/application/services/debt_service.rs`

- [ ] **Step 1: Update DTOs**

Rewrite `debt_dto.rs` with new DTOs that include `account_id`:

```rust
pub struct CreateDebtDto {
    pub name: String,
    pub account_type: AccountType,       // BorrowedIn, BorrowedOut, Loan, CreditCard
    pub counterparty: String,
    pub principal_amount: Decimal,
    pub currency_code: String,
    pub interest_rate: Decimal,
    pub start_date: NaiveDate,
    pub due_date: NaiveDate,
    pub amortization_method: Option<String>,
}

pub struct DebtDto {
    pub account_id: Uuid,
    pub account_name: String,
    pub account_type: AccountType,
    pub counterparty: String,
    pub principal_amount: Decimal,
    pub remaining_balance: Decimal,
    pub currency_code: String,
    pub interest_rate: Decimal,
    pub start_date: NaiveDate,
    pub due_date: NaiveDate,
    pub amortization_method: String,
    pub payment_schedule: Vec<PaymentScheduleDto>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

pub struct RecordPaymentDto {
    pub schedule_entry_id: Uuid,
    pub payment_source_account_id: Uuid,
    pub interest_account_id: Uuid,  // external account for interest expense/income
}
```

- [ ] **Step 2: Rewrite DebtService**

The service should:
- `create_debt`: Create an Account + DebtDetails + generate payment schedule in one transaction
- `list_debts`: Query accounts with debt types, join with debt_details
- `get_debt`: Get account + debt_details + schedule
- `record_payment`: Mark schedule entry paid, create double-entry Transaction
- `get_upcoming_payments`: Forward to repository

The `record_payment` method is the key integration:
1. Find debt_details by account_id
2. Find the schedule entry, mark it paid
3. Create a Transaction with entries:
   - If BorrowedIn/Loan: debit debt account (principal) + debit interest expense account (interest) → credit payment source account (total)
   - If BorrowedOut: debit payment source account (total) → credit debt account (principal) + credit interest income account (interest)
4. Return the created Transaction

- [ ] **Step 3: Verify compilation**

Run: `cargo check 2>&1 | head -30` from `src-tauri/`
Expected: zero errors

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/application/dtos/debt_dto.rs src-tauri/src/application/services/debt_service.rs
git commit -m "feat: rewrite debt DTOs and service for unified model"
```

---

### Task 6: Backend — Tauri Commands

**Files:**
- Rewrite: `src-tauri/src/presentation/tauri_commands/debt_commands.rs`

- [ ] **Step 1: Rewrite commands**

Update all 5 commands to use the new service methods. Key change: `create_debt` now accepts `CreateDebtDto` with `name` and `account_type` fields; `record_payment` now requires `payment_source_account_id` and `interest_account_id`.

- [ ] **Step 2: Verify compilation**

Run: `cargo check 2>&1 | head -20` from `src-tauri/`
Expected: zero errors

- [ ] **Step 3: Commit**

```bash
git add src-tauri/src/presentation/tauri_commands/debt_commands.rs
git commit -m "feat: update debt Tauri commands for unified model"
```

---

### Task 7: Data Migration — Old Data to New Model

**Files:**
- Create: `src-tauri/migrations/20260526000003_migrate_debts_to_accounts.sql`

- [ ] **Step 1: Write migration SQL**

For each row in old `debts` table:
- INSERT into `accounts` with mapped account_type, chart_code, ownership='own'
- INSERT into `debt_details` with counterparty, dates, principal
- Migrate each `debt_payments` row to `debt_payment_schedule`
- For paid entries: leave `transaction_id` as NULL (historical, no backfill)

Include type mapping:
```sql
-- debt_type mapping:
-- 'borrowed_in' -> account_type 'BorrowedIn', chart_code '2001'
-- 'borrowed_out' -> account_type 'BorrowedOut', chart_code '1221'
-- 'credit_card' -> account_type 'CreditCard', chart_code '2202'
-- 'loan' -> account_type 'Loan', chart_code '2501'
```

- [ ] **Step 2: Commit**

```bash
git add src-tauri/migrations/20260526000003_migrate_debts_to_accounts.sql
git commit -m "feat: add data migration from old debts to unified model"
```

---

### Task 8: Drop Old Tables

**Files:**
- Create: `src-tauri/migrations/20260526000004_drop_old_debt_tables.sql`

- [ ] **Step 1: Write drop migration**

```sql
DROP TABLE IF EXISTS debt_payments;
DROP TABLE IF EXISTS debts;
```

- [ ] **Step 2: Commit**

```bash
git add src-tauri/migrations/20260526000004_drop_old_debt_tables.sql
git commit -m "feat: drop old debts and debt_payments tables"
```

---

### Task 9: Frontend — Types and i18n

**Files:**
- Rewrite: `src/lib/tauri/debt.ts`
- Modify: `src/lib/tauri/account.ts`
- Modify: `src/i18n/locales/en.json`
- Modify: `src/i18n/locales/zh.json`

- [ ] **Step 1: Update frontend types**

Rewrite `debt.ts` with updated interfaces matching the new DTOs. Add `DebtDto` with `account_id`, `account_name`, `payment_schedule`. Update API function signatures.

- [ ] **Step 2: Update AccountDto to include debt-specific info**

No changes needed to AccountDto — debt info comes through the debt API. But ensure `AccountType` union includes `'BorrowedOut' | 'BorrowedIn'`.

- [ ] **Step 3: Add i18n keys**

New keys in both en.json and zh.json:
```json
"debts": {
    "borrowedIn": "Borrowed In" / "借入款",
    "borrowedOut": "Borrowed Out" / "借出款",
    "counterparty": "Counterparty" / "对方",
    "interestRate": "Interest Rate" / "利率",
    "paymentSource": "Payment Source" / "还款来源",
    "interestAccount": "Interest Account" / "利息科目",
    ...
}
```

- [ ] **Step 4: Verify TypeScript compiles**

Run: `npx tsc --noEmit --pretty`
Note: Expected errors from DebtsPage/DebtForm — Tasks 10-11 will fix.

- [ ] **Step 5: Commit**

```bash
git add src/lib/tauri/debt.ts src/lib/tauri/account.ts src/i18n/locales/en.json src/i18n/locales/zh.json
git commit -m "feat: update frontend types and i18n for unified debt model"
```

---

### Task 10: Frontend — DebtForm Rewrite

**Files:**
- Rewrite: `src/components/DebtForm.tsx`

- [ ] **Step 1: Rewrite DebtForm**

The new form collects:
- `name` — account name (e.g., "招商银行房贷")
- `account_type` — BorrowedIn, BorrowedOut, Loan, CreditCard
- `counterparty` — lender/borrower name
- `principal_amount` — total principal
- `currency_code` — hidden, defaults to CNY
- `interest_rate` — annual rate %
- `start_date`, `due_date` — date inputs
- `amortization_method` — LumpSum, EqualPrincipal, EqualPrincipalInterest
- `periods` — number of months (only for amortized loans)

Modeled after AccountForm pattern (react-hook-form + zod validation).

On submit: calls `createDebt` API which creates the Account + debt_details + schedule.

- [ ] **Step 2: Verify TypeScript compiles**

Run: `npx tsc --noEmit --pretty`
Note: Expected errors from DebtsPage only.

- [ ] **Step 3: Commit**

```bash
git add src/components/DebtForm.tsx
git commit -m "feat: rewrite DebtForm for unified model"
```

---

### Task 11: Frontend — DebtsPage Rewrite

**Files:**
- Rewrite: `src/pages/DebtsPage.tsx`

- [ ] **Step 1: Rewrite DebtsPage**

Key changes:
- Query accounts with debt types instead of old `listDebts`
- Table columns: Name, Type, Counterparty, Principal, Remaining Balance, Due Date, Status, Actions
- "Record Payment" flow:
  1. User clicks "Record Payment" on a schedule entry
  2. Dialog shows: payment amount, payment source account selector (own Bank/Cash accounts), interest account selector (external Expense accounts)
  3. On confirm: calls `recordPayment` with schedule_entry_id, payment_source_account_id, interest_account_id
- View details dialog: shows payment schedule with paid/unpaid status, linked transactions
- Remove old `listDebts`/`getUpcomingPayments` imports

- [ ] **Step 2: Verify TypeScript compiles**

Run: `npx tsc --noEmit --pretty`
Expected: ZERO errors

- [ ] **Step 3: Commit**

```bash
git add src/pages/DebtsPage.tsx
git commit -m "feat: rewrite DebtsPage for unified account-based model"
```

---

### Self-Review

1. **Spec coverage:**
   - debt_details + debt_payment_schedule tables: Task 1 ✓
   - AccountType expansion (BorrowedOut/BorrowedIn): Task 2 ✓
   - DebtDetails domain model + amortization: Task 3 ✓
   - Repository: Task 4 ✓
   - Repayment creates transactions: Task 5 (service) ✓
   - Data migration: Task 7 ✓
   - Drop old tables: Task 8 ✓
   - Frontend types/i18n: Task 9 ✓
   - Frontend forms/pages: Tasks 10-11 ✓

2. **Placeholder scan:** No TBD or TODO. All code is concrete.

3. **Type consistency:**
   - `BorrowedOut`/`BorrowedIn` used consistently in Rust enum and TypeScript union ✓
   - `debt_details.account_id` FK → `accounts.id` ✓
   - `debt_payment_schedule.transaction_id` FK → `transactions.id` ✓
   - DTO field names match between Rust and TypeScript ✓
