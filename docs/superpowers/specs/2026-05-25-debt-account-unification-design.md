# Debt-Account Unification Design

## Summary

Unify the independent Debt system into the Account system, making debts a specialized type of account. This enables debt repayment to automatically create double-entry transactions, keeping balances consistent.

## Motivation

- Debt and Account are currently two independent systems with no data relationship
- Recording a debt payment does not create accounting transactions — it only marks a schedule entry as paid
- Users must manually record both a debt payment AND an account transaction, leading to inconsistency
- The Account system already supports liability types; extending it avoids duplication

## Design

### Section 1: Data Model

**AccountType variants (updated):**

```rust
pub enum AccountType {
    Cash,
    Bank,
    CreditCard,
    Investment,
    BorrowedOut,   // Lending out (receivable / 借出)
    BorrowedIn,    // Borrowing in (payable / 借入)
    Other,
    Income,
    Expense,
}
```

Note: `Loan` was merged into `BorrowedIn`. Accounting standards (IFRS/CAS) classify borrowings by term (short/long), not by lender type (bank vs individual). The distinction is captured by `chart_code` (2001 for short-term, 2501 for long-term) and `due_date`, not by account type.

**Chart of accounts mapping for debt types:**

| AccountType | chart_code | Name | Balance Direction |
|---|---|---|---|
| BorrowedOut | 1221 | 其他应收款 | Debit |
| BorrowedIn | 2001/2501 | 短期/长期借款 | Credit |
| CreditCard | 2202 | 应付信用卡款 | Credit |
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

### Section 2: Creation and Repayment Flow

**Debt creation flow (account-first):**
1. User creates an Account of type `BorrowedIn`, `BorrowedOut`, or `CreditCard` in the Accounts page
2. In the Debts page, user clicks "Create Debt" and selects:
   - **Account** — an existing account of debt type (BorrowedIn, BorrowedOut, CreditCard) via dropdown
   - **Counterparty** — another existing account via dropdown (its name is stored as counterparty text)
   - Loan terms (principal, interest rate, dates, amortization method)
3. System creates `debt_details` + `debt_payment_schedule` linked to the selected account

**Repayment creates transactions:**

When a user records a payment against a debt schedule entry:

**Liability repayment (BorrowedIn/CreditCard):**

```
借: 借款账户(debt account)  ¥principal  (liability decreases)
借: 利息支出(interest account) ¥interest  (expense)
    贷: 还款来源账户(payment source)  ¥total  (asset decreases)
```

**Receivable recovery (BorrowedOut):**

```
借: 收款账户(receiving account)  ¥total  (asset increases)
    贷: 借出账户(debt account)  ¥principal  (receivable decreases)
    贷: 利息收入(income account)  ¥interest (if any)  (income)
```

**Processing flow:**
1. User clicks "Record Payment" on a schedule entry, selects payment source account
2. System creates a `Transaction` with balanced debit/credit entries
3. System marks the schedule entry as `paid` and sets `transaction_id`
4. Account `current_balance` for the debt account reflects: `initial_balance - SUM(paid_principal)`

### Section 3: Migration

**Phase 1: Schema migration**
- Create `debt_details` and `debt_payment_schedule` tables
- Extend `AccountType` enum with `BorrowedOut`, `BorrowedIn`, remove `Loan`
- Update `accounts` CHECK constraint

**Phase 2: Data migration**
- For each row in `debts` table:
  - Create an `Account` with mapped `account_type` (`loan` → `borrowed_in`)
  - Insert into `debt_details` with counterparty, interest_rate, dates
  - Migrate each payment schedule entry to `debt_payment_schedule`
  - For already-paid entries: no transaction backfill (historical)

**Phase 3: Drop old tables**
- Verify migration data integrity
- Drop `debts` and `debt_payments` tables

### Out of Scope

- Investment/fund/stock tracking (separate feature using `Investment` AccountType)
- Integration with existing `Reminder` system
- Historical payment-to-transaction backfill for already-paid entries
