# Accounts Page: Dynamic Balance + Tabs + Sort/Filter — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add dynamic balance computation, ownership tabs, and sort/search/filter to the Accounts page.

**Architecture:** Backend: DB migration renames `balance` → `initial_balance`; new repository method computes `current_balance` from `transaction_entries`; `AccountDto` gains both fields. Frontend: AccountsPage gains tabs, search input, type filter dropdown, and sortable column headers; all filtering/sorting is client-side via `useMemo`.

**Tech Stack:** Rust/Tauri backend (sqlx, SQLite), React 19/TypeScript frontend (@base-ui/react Tabs, existing Select/Input components)

---

### File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `src-tauri/migrations/<ts>_rename_balance.sql` | Create | Rename `balance` → `initial_balance` in accounts table |
| `src-tauri/src/domain/aggregates/account.rs` | Modify | Rename `balance` field to `initial_balance` |
| `src-tauri/src/application/dtos/account_dto.rs` | Modify | Add `initial_balance` + `current_balance` to `AccountDto` |
| `src-tauri/src/application/services/account_service.rs` | Modify | Add `get_accounts_with_current_balance` method |
| `src-tauri/src/infrastructure/repositories/account_repository.rs` | Modify | Update SQL queries, add balance computation query |
| `src-tauri/src/presentation/tauri_commands/account_commands.rs` | Modify | Add `list_accounts_with_balances` command, update existing commands |
| `src/lib/tauri/account.ts` | Modify | Update types, export new API function |
| `src/pages/AccountsPage.tsx` | Modify | Add tabs, search, type filter, column sorting |
| `src/components/AccountForm.tsx` | Modify | Make balance read-only in edit mode |
| `src/i18n/locales/en.json` | Modify | Add new keys |
| `src/i18n/locales/zh.json` | Modify | Add new keys |

---

### Task 1: DB Migration — Rename balance to initial_balance

**Files:**
- Create: `src-tauri/migrations/<timestamp>_rename_balance_to_initial_balance.sql`

- [ ] **Step 1: Create migration file**

Write `src-tauri/migrations/20260526000001_rename_balance_to_initial_balance.sql`:

```sql
ALTER TABLE accounts RENAME COLUMN balance TO initial_balance;
```

- [ ] **Step 2: Commit**

```bash
git add src-tauri/migrations/20260526000001_rename_balance_to_initial_balance.sql
git commit -m "feat: rename balance column to initial_balance in accounts table"
```

---

### Task 2: Backend — Account Aggregate

**Files:**
- Modify: `src-tauri/src/domain/aggregates/account.rs`

- [ ] **Step 1: Rename `balance` field to `initial_balance`**

In `src-tauri/src/domain/aggregates/account.rs`, change the struct field at line 117:

```rust
// Before:
pub balance: Money,
// After:
pub initial_balance: Money,
```

- [ ] **Step 2: Update `new()` method parameter name**

At line 133, rename parameter from `balance: Money` to `initial_balance: Money`, and update the struct construction at ~line 171 to use `initial_balance` instead of `balance`.

- [ ] **Step 3: Update `update_balance()` method**

Rename `update_balance` to `update_initial_balance` (lines 185-199). Update the event `BalanceUpdated` field names accordingly.

- [ ] **Step 4: Update all other methods that reference `balance`**

Search for `self.balance` in the file and replace with `self.initial_balance`. This affects:
- `update_balance` method body
- `validate_balance` free function (update parameter references)
- Test module (update all test references)

- [ ] **Step 5: Verify Rust compilation**

Run: `cargo build 2>&1 | head -30` from `src-tauri/`
Expected: compilation succeeds (may have errors from dependent files not yet updated — that's expected)

- [ ] **Step 6: Commit**

```bash
git add src-tauri/src/domain/aggregates/account.rs
git commit -m "feat: rename Account.balance to initial_balance"
```

---

### Task 3: Backend — Repository

**Files:**
- Modify: `src-tauri/src/infrastructure/repositories/account_repository.rs`

- [ ] **Step 1: Update `row_to_account` function**

At ~line 48-54, rename the `balance` variable to `initial_balance`:

```rust
let initial_balance_str: String = row.try_get("initial_balance").unwrap_or_default();
let initial_balance = Money::new(
    Decimal::from_str(&initial_balance_str).unwrap_or_default(),
    &currency_code,
);
```

Update the Account construction at ~line 155 to use `initial_balance`.

- [ ] **Step 2: Update INSERT query in `create` method**

At line 177, change `balance` to `initial_balance` in the column list:

```sql
INSERT INTO accounts (
    id, name, account_type, ownership, currency_code, initial_balance,
    ...
)
```

- [ ] **Step 3: Update all SELECT queries**

In all SELECT queries (`find_by_id`, `find_all`, `find_by_type`, `find_by_ownership`, `find_all_including_deleted`, `get_changes_since`), change:
```sql
CAST(balance AS TEXT) AS balance
```
To:
```sql
CAST(initial_balance AS TEXT) AS initial_balance
```

- [ ] **Step 4: Update UPDATE query**

In the `update` method at ~line 307, change `balance = ?` to `initial_balance = ?`.

- [ ] **Step 5: Add balance computation query method**

Add a new method to `SqliteAccountRepository` (not part of the trait — public impl method):

```rust
impl SqliteAccountRepository {
    pub async fn compute_balances_for_all_accounts(
        &self,
    ) -> Result<std::collections::HashMap<Uuid, Decimal>, sqlx::Error> {
        #[derive(sqlx::FromRow)]
        struct BalanceRow {
            account_id: String,
            net_change: Option<String>,
        }

        let rows = sqlx::query_as::<_, BalanceRow>(
            r#"
            SELECT
                e.account_id,
                CAST(COALESCE(SUM(COALESCE(e.debit_amount, 0)), 0) -
                     COALESCE(SUM(COALESCE(e.credit_amount, 0)), 0) AS TEXT) AS net_change
            FROM transaction_entries e
            JOIN transactions t ON e.transaction_id = t.id
            WHERE e.deleted_at IS NULL AND t.deleted_at IS NULL
            GROUP BY e.account_id
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        let mut map = std::collections::HashMap::new();
        for row in rows {
            if let Ok(id) = Uuid::from_str(&row.account_id) {
                let change = row
                    .net_change
                    .and_then(|s| Decimal::from_str(&s).ok())
                    .unwrap_or(Decimal::ZERO);
                map.insert(id, change);
            }
        }
        Ok(map)
    }
}
```

- [ ] **Step 6: Verify Rust compilation**

Run: `cargo build 2>&1 | head -40` from `src-tauri/`
Expected: compilation succeeds (may have errors from service/dto not yet updated)

- [ ] **Step 7: Commit**

```bash
git add src-tauri/src/infrastructure/repositories/account_repository.rs
git commit -m "feat: update repository for initial_balance, add balance computation query"
```

---

### Task 4: Backend — DTOs and Service

**Files:**
- Modify: `src-tauri/src/application/dtos/account_dto.rs`
- Modify: `src-tauri/src/application/services/account_service.rs`

- [ ] **Step 1: Update `AccountDto`**

Add `initial_balance` and `current_balance` fields to `AccountDto` (line 40-61):

```rust
pub struct AccountDto {
    pub id: Uuid,
    pub name: String,
    pub account_type: AccountType,
    pub ownership: Ownership,
    pub icon: String,
    pub color: String,
    pub chart_code: Option<String>,
    pub parent_id: Option<Uuid>,
    pub currency_code: String,
    pub initial_balance: Decimal,
    pub current_balance: Decimal,
    pub account_number: Option<String>,
    pub institution: Option<String>,
    pub credit_limit: Option<Decimal>,
    pub billing_day: Option<u8>,
    pub payment_due_day: Option<u8>,
    pub interest_rate: Option<Decimal>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
}
```

- [ ] **Step 2: Update `From<Account> for AccountDto` impl**

At line 81, change `balance: account.balance.amount` to `initial_balance: account.initial_balance.amount`. Set `current_balance` to `account.initial_balance.amount` as default (will be overridden by the service).

- [ ] **Step 3: Update `UpdateAccountDto`**

Rename `balance` field to `initial_balance` in `UpdateAccountDto`:

```rust
pub struct UpdateAccountDto {
    pub name: String,
    pub initial_balance: Decimal,  // was: balance
    // ... rest unchanged
}
```

- [ ] **Step 4: Update `AccountService::update_account`**

At line 71, change `dto.balance` to `dto.initial_balance`:

```rust
let new_balance = Money::new(dto.initial_balance, &account.currency_code);
account.update_initial_balance(new_balance)?;
```

- [ ] **Step 5: Add `list_accounts_with_balances` method to service**

Add to `AccountService`:

```rust
pub async fn list_accounts_with_balances(
    &self,
) -> Result<Vec<AccountDto>, AccountServiceError> {
    let accounts = self.account_repo.find_all().await
        .map_err(AccountServiceError::DatabaseError)?;

    let balance_changes = self.account_repo
        .compute_balances_for_all_accounts()
        .await
        .map_err(AccountServiceError::DatabaseError)?;

    let dtos: Vec<AccountDto> = accounts
        .into_iter()
        .map(|account| {
            let net_change = balance_changes.get(&account.id).copied().unwrap_or(Decimal::ZERO);
            let current = account.initial_balance.amount + net_change;
            AccountDto {
                initial_balance: account.initial_balance.amount,
                current_balance: current,
                ..account.into()
            }
        })
        .collect();

    Ok(dtos)
}
```

Note: This requires the `AccountRepository` trait to also expose `compute_balances_for_all_accounts`. Add it to the trait in `mod.rs`:

```rust
async fn compute_balances_for_all_accounts(
    &self,
) -> Result<std::collections::HashMap<Uuid, Decimal>, sqlx::Error>;
```

- [ ] **Step 6: Verify Rust compilation**

Run: `cargo build 2>&1 | head -40` from `src-tauri/`
Expected: compilation succeeds

- [ ] **Step 7: Commit**

```bash
git add src-tauri/src/application/dtos/account_dto.rs src-tauri/src/application/services/account_service.rs
git commit -m "feat: add initial_balance and current_balance to DTOs and service"
```

---

### Task 5: Backend — Tauri Commands

**Files:**
- Modify: `src-tauri/src/presentation/tauri_commands/account_commands.rs`
- Modify: `src-tauri/src/domain/repositories/mod.rs` (trait definition, if needed)

- [ ] **Step 1: Add `list_accounts_with_balances` command**

Add new internal function and Tauri command:

```rust
async fn list_accounts_with_balances_with_state(
    state: &AppState,
) -> Result<Vec<AccountDto>, String> {
    state
        .service()
        .list_accounts_with_balances()
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn list_accounts_with_balances(
    state: State<'_, AppState>,
) -> Result<Vec<AccountDto>, String> {
    list_accounts_with_balances_with_state(&state).await
}
```

Also register the command in the Tauri builder (check `src-tauri/src/main.rs` or `lib.rs` for the command registration).

- [ ] **Step 2: Update existing commands for renamed fields**

Update `update_account_with_state` to use `initial_balance` instead of `balance` in `UpdateAccountDto`. Update `get_account_balance_with_state` to compute current balance.

- [ ] **Step 3: Verify Rust compilation**

Run: `cargo build 2>&1 | head -40` from `src-tauri/`
Expected: compilation succeeds

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/presentation/tauri_commands/account_commands.rs
git commit -m "feat: add list_accounts_with_balances Tauri command"
```

---

### Task 6: Frontend — Types and API

**Files:**
- Modify: `src/lib/tauri/account.ts`

- [ ] **Step 1: Update TypeScript types**

Update `AccountDto` to include `initial_balance` and `current_balance`:

```ts
export interface AccountDto {
  id: string;
  name: string;
  account_type: AccountType;
  ownership: Ownership;
  icon: string;
  color: string;
  chart_code?: string | null;
  parent_id?: string | null;
  currency_code: string;
  initial_balance: number;
  current_balance: number;
  account_number?: string;
  institution?: string;
  credit_limit?: number;
  billing_day?: number;
  payment_due_day?: number;
  interest_rate?: number;
  created_at: string;
  updated_at: string;
  deleted_at?: string;
}
```

- [ ] **Step 2: Add new API function**

```ts
export const listAccountsWithBalances = () =>
  invokeTauri<AccountDto[]>('list_accounts_with_balances');
```

- [ ] **Step 3: Verify TypeScript compiles**

Run: `npx tsc --noEmit --pretty`
Expected: no output

- [ ] **Step 4: Commit**

```bash
git add src/lib/tauri/account.ts
git commit -m "feat: update AccountDto types, add listAccountsWithBalances API"
```

---

### Task 7: Frontend — i18n Keys

**Files:**
- Modify: `src/i18n/locales/en.json`
- Modify: `src/i18n/locales/zh.json`

- [ ] **Step 1: Add new keys**

Add to `en.json`:
```json
"common": {
    "all": "All",
    "sortAsc": "Sort ascending",
    "sortDesc": "Sort descending"
},
"accounts": {
    "searchPlaceholder": "Search accounts...",
    "filterByType": "Filter by type",
    "initialBalance": "Initial Balance",
    "currentBalance": "Current Balance",
    "allAccounts": "All Accounts"
}
```

Add to `zh.json`:
```json
"common": {
    "all": "全部",
    "sortAsc": "升序排列",
    "sortDesc": "降序排列"
},
"accounts": {
    "searchPlaceholder": "搜索账户...",
    "filterByType": "按类型筛选",
    "initialBalance": "初始余额",
    "currentBalance": "当前余额",
    "allAccounts": "全部账户"
}
```

- [ ] **Step 2: Commit**

```bash
git add src/i18n/locales/en.json src/i18n/locales/zh.json
git commit -m "feat: add accounts page i18n keys"
```

---

### Task 8: Frontend — AccountsPage (Tabs + Sort + Search + Filter)

**Files:**
- Modify: `src/pages/AccountsPage.tsx`

- [ ] **Step 1: Add imports**

Add to existing imports:
```tsx
import { Tabs, TabsList, TabsTrigger } from '../components/ui/tabs';
import { ArrowUpDown, ArrowUp, ArrowDown } from 'lucide-react';
import { MultiSelect } from '../components/ui/multi-select';
import { listAccountsWithBalances } from '../lib/tauri/account';
```

Replace `listAccounts` with `listAccountsWithBalances` in the query: change the queryFn from `listAccounts` to `listAccountsWithBalances`.

- [ ] **Step 2: Add tab state and filter state**

```tsx
const [ownershipTab, setOwnershipTab] = useState<'all' | 'own' | 'external'>('all');
const [searchQuery, setSearchQuery] = useState('');
const [typeFilter, setTypeFilter] = useState<AccountType | 'all'>('all');
const [sortColumn, setSortColumn] = useState<'name' | 'type' | 'balance'>('name');
const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('asc');
```

- [ ] **Step 3: Add filtered and sorted accounts useMemo**

```tsx
const filteredAndSortedAccounts = useMemo(() => {
  let result = accounts;

  // Tab filter (ownership)
  if (ownershipTab !== 'all') {
    result = result.filter((a) => a.ownership === ownershipTab);
  }

  // Search filter (name)
  if (searchQuery.trim()) {
    const q = searchQuery.toLowerCase().trim();
    result = result.filter((a) => a.name.toLowerCase().includes(q));
  }

  // Type filter
  if (typeFilter !== 'all') {
    result = result.filter((a) => a.account_type === typeFilter);
  }

  // Sort
  result = [...result].sort((a, b) => {
    let cmp = 0;
    if (sortColumn === 'name') {
      cmp = a.name.localeCompare(b.name);
    } else if (sortColumn === 'type') {
      cmp = a.account_type.localeCompare(b.account_type);
    } else if (sortColumn === 'balance') {
      cmp = a.current_balance - b.current_balance;
    }
    return sortDirection === 'asc' ? cmp : -cmp;
  });

  return result;
}, [accounts, ownershipTab, searchQuery, typeFilter, sortColumn, sortDirection]);
```

- [ ] **Step 4: Add Tabs bar**

After the title bar, before the table:

```tsx
<Tabs value={ownershipTab} onValueChange={(v) => setOwnershipTab(v as typeof ownershipTab)}>
  <TabsList>
    <TabsTrigger value="all">{t('common.all')}</TabsTrigger>
    <TabsTrigger value="own">{t('accountForm.ownAccount')}</TabsTrigger>
    <TabsTrigger value="external">{t('accountForm.externalAccount')}</TabsTrigger>
  </TabsList>
</Tabs>
```

- [ ] **Step 5: Add search and type filter bar**

```tsx
<div className="flex items-center gap-3 mb-4">
  <div className="relative flex-1 max-w-xs">
    <Search className="absolute left-2 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground" />
    <Input
      value={searchQuery}
      onChange={(e) => setSearchQuery(e.target.value)}
      placeholder={t('accounts.searchPlaceholder')}
      className="pl-7 h-8 text-sm"
    />
  </div>
  <Select value={typeFilter} onValueChange={(v) => setTypeFilter(v as AccountType | 'all')}>
    <SelectTrigger className="w-36 h-8 text-sm">
      <SelectValue placeholder={t('accounts.filterByType')} />
    </SelectTrigger>
    <SelectContent>
      <SelectItem value="all">{t('common.all')}</SelectItem>
      <SelectItem value="Cash">{t('accountForm.cash')}</SelectItem>
      <SelectItem value="Bank">{t('accountForm.bank')}</SelectItem>
      <SelectItem value="CreditCard">{t('accountForm.creditCard')}</SelectItem>
      <SelectItem value="Investment">{t('accountForm.investment')}</SelectItem>
      <SelectItem value="Loan">{t('accountForm.loan')}</SelectItem>
      <SelectItem value="Income">{t('accountForm.income')}</SelectItem>
      <SelectItem value="Expense">{t('accountForm.expense')}</SelectItem>
      <SelectItem value="Other">{t('accountForm.other')}</SelectItem>
    </SelectContent>
  </Select>
</div>
```

- [ ] **Step 6: Update table headers to be sortable**

Replace the table header row. Add `onClick` handlers and sort indicators:

```tsx
<TableHead
  className="cursor-pointer select-none"
  onClick={() => {
    if (sortColumn === 'name') {
      setSortDirection(d => d === 'asc' ? 'desc' : 'asc');
    } else {
      setSortColumn('name');
      setSortDirection('asc');
    }
  }}
>
  <span className="inline-flex items-center gap-1">
    {t('common.name')}
    {sortColumn === 'name' && (
      sortDirection === 'asc' ? <ArrowUp className="h-3 w-3" /> : <ArrowDown className="h-3 w-3" />
    )}
  </span>
</TableHead>
```

Repeat for Type and Balance columns. Currency and Actions columns remain non-sortable.

- [ ] **Step 7: Update table body to use `filteredAndSortedAccounts` and `current_balance`**

Change `accounts.map(...)` to `filteredAndSortedAccounts.map(...)` and change `account.balance` to `account.current_balance` in the balance cell.

- [ ] **Step 8: Verify TypeScript compiles**

Run: `npx tsc --noEmit --pretty`
Expected: no output

- [ ] **Step 9: Commit**

```bash
git add src/pages/AccountsPage.tsx
git commit -m "feat: add tabs, search, type filter, and column sorting to AccountsPage"
```

---

### Task 9: Frontend — AccountForm Balance Display

**Files:**
- Modify: `src/components/AccountForm.tsx`

- [ ] **Step 1: Make balance field read-only in edit mode**

In the balance input section of `AccountForm.tsx`, when `mode === 'edit'`:
- Show `initial_balance` as a read-only field (or hide it)
- Show `current_balance` if available (computed value from the server)

In create mode: keep the existing `initial_balance` input as-is.

- [ ] **Step 2: Verify TypeScript compiles**

Run: `npx tsc --noEmit --pretty`
Expected: no output

- [ ] **Step 3: Commit**

```bash
git add src/components/AccountForm.tsx
git commit -m "feat: make balance read-only in account edit mode"
```

---

### Self-Review Checklist

1. **Spec coverage:**
   - Dynamic balance computation: Tasks 1-6, 9 ✓
   - Ownership tabs: Task 8 ✓
   - Sort/search/filter: Task 8 ✓
   - i18n keys: Task 7 ✓

2. **Placeholder scan:** No TBD, TODO, or incomplete sections.

3. **Type consistency:**
   - `initial_balance: Decimal` in Rust ↔ `initial_balance: number` in TypeScript ✓
   - `current_balance: Decimal` in Rust ↔ `current_balance: number` in TypeScript ✓
   - `AccountType` filter uses `AccountType | 'all'` in both state and Select ✓
   - Sort direction uses `'asc' | 'desc'` consistently ✓
