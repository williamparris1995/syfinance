# Sprint 2: P1 Core Feature Improvements — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add recurring transactions, fix reports to support drill-down and date-aware balance sheets, and add balance history sparklines to the accounts page.

**Architecture:** Task 6 (recurring transactions) reuses the subscription auto-record pattern. Task 7 (reports) modifies client-side computation. Task 8 (sparklines) adds a backend query + recharts visualization.

**Tech Stack:** Rust (Tauri 2.x, SQLx), SQLite, React (TypeScript, TanStack Query, recharts)

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `src-tauri/migrations/20260602000002_transaction_templates.sql` | Create | Schema for recurring transaction templates |
| `src-tauri/src/domain/aggregates/transaction_template.rs` | Create | Domain aggregate for recurring templates |
| `src-tauri/src/domain/repositories/mod.rs` | Modify | Add TransactionTemplateRepository trait |
| `src-tauri/src/infrastructure/repositories/transaction_template_repository.rs` | Create | SQLite implementation |
| `src-tauri/src/application/services/transaction_template_service.rs` | Create | Service with CRUD + process_due + background scheduler |
| `src-tauri/src/application/services/mod.rs` | Modify | Register new module |
| `src-tauri/src/presentation/tauri_commands/transaction_template_commands.rs` | Create | Tauri IPC commands |
| `src-tauri/src/presentation/tauri_commands/mod.rs` | Modify | Register new module |
| `src-tauri/src/main.rs` | Modify | Register commands + start background scheduler |
| `src/lib/tauri/transactionTemplate.ts` | Create | Frontend Tauri bridge |
| `src/hooks/useTransactionTemplate.ts` | Create | React Query hooks |
| `src/pages/TransactionTemplatesPage.tsx` | Create | Management page |
| `src/pages/TransactionsPage.tsx` | Modify | Add "Make Recurring" option |
| `src/pages/ReportsPage.tsx` | Modify | Fix balance sheet date-awareness, add drill-down |
| `src/pages/TransactionsPage.tsx` | Modify | Accept filter params for drill-down navigation |
| `src-tauri/src/domain/repositories/mod.rs` | Modify | Add get_balance_history to AccountRepository |
| `src-tauri/src/infrastructure/repositories/account_repository.rs` | Modify | Implement get_balance_history |
| `src-tauri/src/presentation/tauri_commands/account_commands.rs` | Modify | Add get_account_balance_history command |
| `src/lib/tauri/account.ts` | Modify | Add getAccountBalanceHistory |
| `src/hooks/useAccount.ts` or new `useAccountBalanceHistory.ts` | Create | Hook for balance history |
| `src/pages/AccountsPage.tsx` | Modify | Add sparkline column |
| `src/components/AccountDetailPanel.tsx` | Modify | Add sparkline to detail panel |
| `src/i18n/locales/en.json` | Modify | Add new i18n keys |
| `src/i18n/locales/zh.json` | Modify | Add new i18n keys |

---

### Task 6: Add recurring/scheduled transactions

This is the largest task. It reuses the subscription auto-record pattern (process_due → record → advance_to_next → background scheduler).

**Files:**
- Create: `src-tauri/migrations/20260602000002_transaction_templates.sql`
- Create: `src-tauri/src/domain/aggregates/transaction_template.rs`
- Modify: `src-tauri/src/domain/repositories/mod.rs`
- Create: `src-tauri/src/infrastructure/repositories/transaction_template_repository.rs`
- Create: `src-tauri/src/application/services/transaction_template_service.rs`
- Create: `src-tauri/src/presentation/tauri_commands/transaction_template_commands.rs`
- Modify: `src-tauri/src/main.rs`
- Create: `src/lib/tauri/transactionTemplate.ts`
- Create: `src/hooks/useTransactionTemplate.ts`
- Create: `src/pages/TransactionTemplatesPage.tsx`
- Modify: `src/components/layout/Sidebar.tsx` (add nav link)

- [ ] **Step 1: Create migration for transaction_templates table**

Create `src-tauri/migrations/20260602000002_transaction_templates.sql`:

```sql
CREATE TABLE IF NOT EXISTS transaction_templates (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    amount TEXT NOT NULL DEFAULT '0',
    direction TEXT NOT NULL DEFAULT 'expense',
    source_account_id TEXT NOT NULL,
    destination_account_id TEXT,
    cycle TEXT NOT NULL DEFAULT 'monthly',
    cycle_days INTEGER,
    billing_day INTEGER,
    next_date TEXT NOT NULL,
    start_date TEXT NOT NULL,
    end_date TEXT,
    auto_record INTEGER NOT NULL DEFAULT 1,
    paused INTEGER NOT NULL DEFAULT 0,
    last_transaction_id TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    deleted_at TEXT,
    FOREIGN KEY (source_account_id) REFERENCES accounts(id),
    FOREIGN KEY (destination_account_id) REFERENCES accounts(id)
);
```

- [ ] **Step 2: Create TransactionTemplate domain aggregate**

Create `src-tauri/src/domain/aggregates/transaction_template.rs` following the `Subscription` pattern with fields: id, name, description, amount, direction, source_account_id, destination_account_id, cycle, cycle_days, billing_day, next_date, start_date, end_date, auto_record, paused, last_transaction_id. Include methods: `is_due(today)`, `calculate_next_date()`, `advance_to_next()`, `pause()`, `resume()`.

- [ ] **Step 3: Add repository trait**

Modify `src-tauri/src/domain/repositories/mod.rs` to add `TransactionTemplateRepository` trait with: `create`, `find_by_id`, `find_all`, `find_due(today)`, `update`, `soft_delete`, `update_next_date`.

- [ ] **Step 4: Create SQLite repository implementation**

Create `src-tauri/src/infrastructure/repositories/transaction_template_repository.rs` implementing the trait.

- [ ] **Step 5: Create TransactionTemplateService**

Create `src-tauri/src/application/services/transaction_template_service.rs` with methods:
- `create(dto) -> TemplateDto`
- `list() -> Vec<TemplateDto>`
- `get_by_id(id) -> TemplateDto`
- `update(id, dto) -> TemplateDto`
- `delete(id)`
- `pause(id)`, `resume(id)`
- `process_due_templates(today) -> usize` — same pattern as `SubscriptionService::process_due_subscriptions`
- Private `record_template(template)` — creates a double-entry Transaction, returns txn_id

- [ ] **Step 6: Create Tauri commands**

Create `src-tauri/src/presentation/tauri_commands/transaction_template_commands.rs` with commands: `list_transaction_templates`, `get_transaction_template`, `create_transaction_template`, `update_transaction_template`, `delete_transaction_template`, `pause_transaction_template`, `resume_transaction_template`.

- [ ] **Step 7: Register in main.rs**

Add background scheduler (copy the subscription scheduler pattern from main.rs lines 379-395, but for TransactionTemplateService). Register all commands in invoke_handler.

- [ ] **Step 8: Create frontend Tauri bridge**

Create `src/lib/tauri/transactionTemplate.ts` with typed invoke wrappers.

- [ ] **Step 9: Create React Query hooks**

Create `src/hooks/useTransactionTemplate.ts` with `useTransactionTemplates`, `useCreateTransactionTemplate`, `useUpdateTransactionTemplate`, `useDeleteTransactionTemplate`, `usePauseTransactionTemplate`, `useResumeTransactionTemplate`.

- [ ] **Step 10: Create TransactionTemplatesPage**

Create `src/pages/TransactionTemplatesPage.tsx` with:
- Summary cards (active count, monthly total)
- Table: name, amount, cycle, next date, status (active/paused), actions
- Create/Edit via Sheet with form: name, amount, direction (expense/income/transfer), source account, destination account (for transfers), cycle, billing day, next date, auto_record toggle
- Pause/Resume button per row
- Delete confirmation

- [ ] **Step 11: Add to sidebar navigation**

In `src/components/layout/Sidebar.tsx`, add a nav item for Transaction Templates (e.g., between Transactions and Budget).

- [ ] **Step 12: Add i18n keys**

Add `transactionTemplate` section to both `en.json` and `zh.json` with all necessary keys.

- [ ] **Step 13: Verify and commit**

Run: `cd src-tauri && cargo check`
Run: `pnpm type-check`
Commit: `git add -A && git commit -m "feat(transactions): add recurring/scheduled transaction templates"`

---

### Task 7: Reports drill-down + date-aware balance sheet

**Files:**
- Modify: `src/pages/ReportsPage.tsx`
- Modify: `src/pages/TransactionsPage.tsx` (accept URL filter params)

- [ ] **Step 1: Make balance sheet date-aware**

In `src/pages/ReportsPage.tsx`, modify the `balanceSheetData` useMemo (currently lines 83-114). Instead of using raw `accounts` data (which reflects current state), compute balance from transactions up to `dateRange.end`:

For each account, instead of using `account.current_balance`, compute:
- Find all transactions up to `dateRange.end`
- For each transaction entry that references the account, sum debits minus credits
- Add to `account.initial_balance`

This makes the balance sheet show the financial position as of the selected end date.

- [ ] **Step 2: Add click handlers to charts for drill-down**

Add `onClick` to the recharts `Pie` and `Bar` components. When a segment is clicked:
1. Extract the account name or category from the clicked data point
2. Navigate to `/transactions` with query params for the account filter and date range

Use TanStack Router's `useNavigate` to navigate with search params.

- [ ] **Step 3: Accept filter params in TransactionsPage**

Modify `src/pages/TransactionsPage.tsx` to read URL search params on load:
- `accountId` filter — pre-select the account
- `startDate` / `endDate` — set the date range

Use `useSearch` from TanStack Router to read params, and apply them as default filter values.

- [ ] **Step 4: Verify and commit**

Run: `pnpm type-check`
Commit: `git add -A && git commit -m "feat(reports): add date-aware balance sheet and drill-down navigation"`

---

### Task 8: Add balance history sparklines to Accounts

**Files:**
- Modify: `src-tauri/src/domain/repositories/mod.rs` (add method to AccountRepository)
- Modify: `src-tauri/src/infrastructure/repositories/account_repository.rs` (implement)
- Modify: `src-tauri/src/presentation/tauri_commands/account_commands.rs`
- Modify: `src/lib/tauri/account.ts`
- Create: `src/hooks/useAccountBalanceHistory.ts`
- Modify: `src/pages/AccountsPage.tsx`
- Modify: `src/components/AccountDetailPanel.tsx`

- [ ] **Step 1: Add `get_balance_history` to AccountRepository trait**

In `src-tauri/src/domain/repositories/mod.rs`, add to `AccountRepository`:

```rust
async fn get_balance_history(
    &self,
    account_id: Uuid,
    days: i32,
) -> Result<Vec<(String, Decimal)>, sqlx::Error>;
```

This returns a list of `(date_string, running_balance)` tuples for the last N days.

- [ ] **Step 2: Implement for SQLite**

In `src-tauri/src/infrastructure/repositories/account_repository.rs`, add an inherent method that computes daily running balances:

```sql
WITH RECURSIVE dates(date) AS (
    SELECT DATE('now', '-29 days')
    UNION ALL
    SELECT DATE(date, '+1 day') FROM dates WHERE date < DATE('now')
)
SELECT
    d.date,
    a.initial_balance + COALESCE(
        (SELECT SUM(CAST(COALESCE(e.debit_amount, 0) AS REAL) - CAST(COALESCE(e.credit_amount, 0) AS REAL))
         FROM transaction_entries e
         JOIN transactions t ON e.transaction_id = t.id
         WHERE e.account_id = ?
         AND e.deleted_at IS NULL AND t.deleted_at IS NULL
         AND t.transaction_date <= d.date),
        0
    ) as balance
FROM dates d, accounts a
WHERE a.id = ?
ORDER BY d.date
```

Implement the trait method delegating to the inherent method.

- [ ] **Step 3: Add Tauri command**

In `src-tauri/src/presentation/tauri_commands/account_commands.rs`, add:

```rust
#[tauri::command]
pub async fn get_account_balance_history(
    state: State<'_, AccountCommandState>,
    account_id: String,
    days: Option<i32>,
) -> Result<Vec<BalanceHistoryPoint>, String>
```

With a response DTO:
```rust
pub struct BalanceHistoryPoint {
    pub date: String,
    pub balance: String,
}
```

Register in main.rs invoke_handler.

- [ ] **Step 4: Add frontend bridge**

In `src/lib/tauri/account.ts`, add:
```typescript
export interface BalanceHistoryPoint {
  date: string;
  balance: string;
}
export async function getAccountBalanceHistory(accountId: string, days?: number): Promise<BalanceHistoryPoint[]> { ... }
```

- [ ] **Step 5: Create hook**

Create `src/hooks/useAccountBalanceHistory.ts`:
```typescript
export function useAccountBalanceHistory(accountId: string | undefined, days = 30) {
  return useQuery({
    queryKey: ['accountBalanceHistory', accountId, days],
    queryFn: () => getAccountBalanceHistory(accountId!, days),
    enabled: !!accountId,
    staleTime: 5 * 60 * 1000,
  });
}
```

- [ ] **Step 6: Add sparkline to AccountsPage**

In `src/pages/AccountsPage.tsx`:

1. Fetch balance histories for all visible accounts (batch or individually).
2. Add a new column "Trend" between "Current Balance" and "Actions".
3. Render a mini sparkline using recharts `<LineChart>` with no axes, no grid, just a simple line:

```tsx
<ResponsiveContainer width={80} height={30}>
  <LineChart data={historyData}>
    <Line type="monotone" dataKey="balance" stroke="#10B981" dot={false} strokeWidth={1.5} />
  </LineChart>
</ResponsiveContainer>
```

Color-code the line: green for positive trend, red for negative trend.

- [ ] **Step 7: Add sparkline to AccountDetailPanel**

In `src/components/AccountDetailPanel.tsx`, add a larger sparkline (200×60) showing the last 30 days of balance history at the top of the panel.

- [ ] **Step 8: Add i18n keys**

Add keys for "Trend" column header and any labels in both locale files.

- [ ] **Step 9: Verify and commit**

Run: `cd src-tauri && cargo check`
Run: `pnpm type-check`
Commit: `git add -A && git commit -m "feat(accounts): add 30-day balance history sparklines"`
