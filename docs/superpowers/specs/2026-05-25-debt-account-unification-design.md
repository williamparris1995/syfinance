# Debt-Account Unification Design

## Summary

Unify the independent Debt system into the Account system, making debts a specialized type of account. This enables debt repayment to automatically create double-entry transactions, keeping balances consistent.

## Motivation

- Debt and Account are currently two independent systems with no data relationship
- Recording a debt payment does not create accounting transactions — it only marks a schedule entry as paid
- Users must manually record both a debt payment AND an account transaction, leading to inconsistency
- The Account system already supports liability types (CreditCard, Loan); extending it avoids duplication

## Design

### Section 1: Data Model

**New AccountType variants:**

```rust
pub enum AccountType {
    // Existing
    Cash, Bank, CreditCard, Investment, Loan, Other, Income, Expense,
    // New
    BorrowedOut,   // Lending out (receivable)
    BorrowedIn,    // Borrowing in (payable)
}
```

**Chart of accounts mapping for debt types:**

| AccountType | chart_code | Name | Balance Direction |
|---|---|---|---|
| BorrowedOut | 1221 | 其他应收款 | Debit |
| BorrowedIn | 2001/2501 | 短期/长期借款 | Credit |
| CreditCard | 2202 | 应付信用卡款 | Credit |
| Loan | 2501 | 长期借款 | Credit |
| Investment | 1101 | 交易性金融资产 | Debit |

**New table: `debt_details` (1:1 with accounts)**

```sql
CREATE TABLE debt_details (
    id TEXT PRIMARY KEY,
    account_id TEXT UNIQUE NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    counterparty VARCHAR(100) NOT NULL,
    interest_rate DECIMAL(5,4),
    amortization_method VARCHAR(20) NOT NULL DEFAULT 'LumpSum',
    start_date DATE NOT NULL,
    due_date DATE NOT NULL,
    total_principal DECIMAL(20,2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

Amortization methods: `EqualPrincipalInterest`, `EqualPrincipal`, `LumpSum`

**New table: `debt_payment_schedule` (1:N with debt_details)**

```sql
CREATE TABLE debt_payment_schedule (
    id TEXT PRIMARY KEY,
    debt_id TEXT NOT NULL REFERENCES debt_details(id) ON DELETE CASCADE,
    payment_date DATE NOT NULL,
    principal_amount DECIMAL(20,2) NOT NULL,
    interest_amount DECIMAL(20,2) NOT NULL,
    total_amount DECIMAL(20,2) NOT NULL,
    paid BOOLEAN NOT NULL DEFAULT FALSE,
    transaction_id TEXT REFERENCES transactions(id),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

**ER Diagram:**

```
accounts (1) ─── (0..1) debt_details ─── (1..N) debt_payment_schedule
                                                │
                                           transaction_id ──→ transactions
```

### Section 2: Repayment Creates Transactions

When a user records a payment against a debt schedule entry:

**Expense repayment (e.g., mortgage):**

```
借: 长期借款(debt account)  ¥principal  (liability decreases)
借: 利息支出(expense ext account) ¥interest  (expense)
    贷: 银行存款(payment source account)  ¥total  (asset decreases)
```

**Lending recovery (e.g., friend repays):**

```
借: 银行存款(receiving account)  ¥principal  (asset increases)
    贷: 其他应收款(debt account)  ¥principal  (receivable decreases)
    贷: 利息收入(income ext account)  ¥interest (if any)  (income)
```

**New borrowing (creating a debt):**

```
借: 银行存款(receiving account)  ¥principal  (asset increases)
    贷: 长期借款(debt account)  ¥principal  (liability increases)
```

**New lending (lending to someone):**

```
借: 其他应收款(debt account)  ¥principal  (receivable increases)
    贷: 银行存款(source account)  ¥principal  (asset decreases)
```

**Processing flow:**
1. User clicks "Record Payment" on a schedule entry
2. System creates a `Transaction` with balanced debit/credit entries
3. System marks the schedule entry as `paid` and sets `transaction_id`
4. Account `current_balance` for the debt account reflects: `initial_balance - SUM(paid_principal)`
5. Credit card payment day mapping: `billing_day` → statement generation, `payment_due_day` → payment deadline

### Section 3: Migration

**Phase 1: Schema migration**
- Create `debt_details` and `debt_payment_schedule` tables
- Extend `AccountType` enum with `BorrowedOut`, `BorrowedIn`

**Phase 2: Data migration**
- For each row in `debts` table:
  - Create an `Account` with mapped `account_type`, `ownership = 'own'`, `chart_code` from the type mapping
  - Set `initial_balance = principal` for borrowing, `initial_balance = 0` for lending
  - Insert into `debt_details` with counterparty, interest_rate, dates
  - Migrate each payment schedule entry to `debt_payment_schedule`
  - For already-paid entries: create a corresponding `Transaction` (or mark as historical)

**Phase 3: Drop old tables**
- Verify migration data integrity
- Drop `debts` and `debt_payments` tables

**Phase 4: Frontend migration**
- Update `DebtsPage` to use Account-based queries
- Update `DebtForm` to create debt-type Accounts + debt_details
- Update repayment flow to create transactions
- Remove old debt API calls

### Files Changed

| File | Action | Description |
|------|--------|-------------|
| Migrations (new) | Create | Schema: debt_details, debt_payment_schedule, AccountType expansion, data migration |
| Migrations (new) | Create | Drop old debts/debt_payments tables |
| `src-tauri/src/domain/aggregates/account.rs` | Modify | Add `BorrowedOut`, `BorrowedIn` to `AccountType` |
| `src-tauri/src/domain/aggregates/debt_details.rs` | Create | DebtDetails aggregate with amortization logic |
| `src-tauri/src/application/dtos/account_dto.rs` | Modify | Add debt-specific fields to DTO |
| `src-tauri/src/application/dtos/debt_dto.rs` | Rewrite | New DTOs for debt_details facade |
| `src-tauri/src/application/services/account_service.rs` | Modify | Add debt-related methods |
| `src-tauri/src/application/services/debt_service.rs` | Rewrite | Thin facade over account_service for debt operations |
| `src-tauri/src/infrastructure/repositories/account_repository.rs` | Modify | Add account type filter for debt types |
| `src-tauri/src/infrastructure/repositories/debt_repository.rs` | Rewrite | debt_details + payment_schedule CRUD |
| `src-tauri/src/presentation/tauri_commands/debt_commands.rs` | Rewrite | Updated commands using unified model |
| `src/lib/tauri/account.ts` | Modify | Add debt-related fields to AccountDto |
| `src/lib/tauri/debt.ts` | Rewrite | Updated types and API functions |
| `src/pages/DebtsPage.tsx` | Rewrite | Use Account queries, show debt accounts |
| `src/components/DebtForm.tsx` | Rewrite | Create Account + debt_details |
| `src/i18n/locales/en.json` | Modify | New debt-related keys |
| `src/i18n/locales/zh.json` | Modify | New debt-related keys |

### Out of Scope

- Investment/fund/stock tracking (separate feature using `Investment` AccountType + investment_details table)
- Integration with existing `Reminder` system (debt reminders should be re-evaluated after migration)
- Historical payment-to-transaction backfill for already-paid entries (marked as historical, no transaction created)
