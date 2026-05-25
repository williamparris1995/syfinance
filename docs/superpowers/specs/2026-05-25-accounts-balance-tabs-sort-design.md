# Accounts Page: Dynamic Balance + Tabs + Sort/Search/Filter

## Summary

Three enhancements to the Accounts page:
1. Compute current balance dynamically from transactions instead of storing a static value
2. Add ownership tabs (All / Own / External) to filter the account list
3. Add column sorting, name search, and type filter to the accounts table

## Motivation

- **Dynamic balance:** The current stored `balance` field is disconnected from actual transaction activity. Recording transactions does not update account balances, making the displayed balance misleading.
- **Tabs:** Users need to quickly switch between viewing all accounts, their own accounts, and external accounts.
- **Sort/Search/Filter:** As the number of accounts grows, finding and organizing accounts becomes difficult without sorting and filtering.

---

## Design

### Section 1: Dynamic Balance Computation

**Database migration:**
- Rename `balance` column to `initial_balance` in the `accounts` table
- New schema: `initial_balance DECIMAL(20,2) NOT NULL DEFAULT 0.00`

**Backend:**
- New Tauri command: `get_account_current_balance(id: Uuid) -> AccountBalanceDto`
- Query: sum all transaction entries for the account
  ```sql
  SELECT
    COALESCE(SUM(COALESCE(debit_amount, 0)) - SUM(COALESCE(credit_amount, 0)), 0) AS net_change
  FROM transaction_entries
  WHERE account_id = ? AND deleted_at IS NULL
  ```
- Current balance = `initial_balance + net_change`
- `AccountDto` changes:
  - Rename `balance` → `initial_balance` (stored value)
  - Add `current_balance: number` (computed from transactions + initial)
- `UpdateAccountDto`: keep `balance` field but it maps to `initial_balance` (or rename to `initial_balance`)

**Frontend:**
- `AccountDto` type: add `current_balance` field, rename `balance` to `initial_balance`
- Table displays `current_balance` (the computed value)
- Edit form: balance field becomes read-only display of `current_balance`, initial_balance is hidden (set at creation only)
- Create form: `initial_balance` label remains as-is

**Edge cases:**
- New account with no transactions: `current_balance = initial_balance`
- Account with transactions: `current_balance = initial_balance + sum(debit - credit)`
- Debit entries increase balance, credit entries decrease balance (for own accounts)

### Section 2: Ownership Tabs

**Component:** Use existing `Tabs` component from `src/components/ui/tabs.tsx`

**Layout:**
```
[ All ] [ {t('accountForm.ownAccount')} ] [ {t('accountForm.externalAccount')} ]
```

**Behavior:**
- Default tab: `all`
- Filtering is client-side on the already-loaded `accounts` array
- Tab state: `useState<'all' | 'own' | 'external'>` 
- Filtered data: `accounts.filter(a => tab === 'all' || a.ownership === tab)`
- Tabs preserve sort/search/filter state when switching

**i18n keys (existing, from `accountForm` section):**
- `all`: Use existing `transactions.allTypes` or add `common.all` = "All" / "全部"
- `accountForm.ownAccount`: "Own Account" / "自己账户" (exists)
- `accountForm.externalAccount`: "External Account" / "外部账户" (exists)

**New i18n keys needed:**
- `common.all`: "All" / "全部"

### Section 3: Sort + Search + Type Filter

**Filter bar layout (below tabs):**
```
[ 🔍 Search... ] [ Type ▾ ]
```

**Search:**
- Client-side filter on `account.name` (case-insensitive)
- State: `useState<string>('')`
- Input component with search icon, same style as TransactionsPage search

**Type filter:**
- Dropdown with options: All, Cash, Bank, CreditCard, Investment, Loan, Other, Income, Expense
- Client-side filter on `account.account_type`
- State: `useState<AccountType | 'all'>('all')`
- Uses existing `Select` component

**Column sorting:**
- Clickable column headers for: Name, Type, Balance
- State: `useState<{ column: string; direction: 'asc' | 'desc' }>({ column: 'name', direction: 'asc' })`
- Sort indicator: ▲ (asc) / ▼ (desc) icon next to column header
- Non-sortable columns: Currency, Actions

**Combined filter pipeline:**
```
accounts
  → filter by tab (ownership)
  → filter by search (name match)
  → filter by type (account_type)
  → sort by column/direction
  → render table
```

All filtering and sorting is client-side using `useMemo`.

**i18n keys (existing):**
- `common.search`: "Search" / "搜索" (exists)
- `common.type`: "Type" / "类型" (exists)
- `common.name`: "Name" / "名称" (exists)
- `common.balance`: "Balance" / "余额" (exists)

**New i18n keys:**
- `common.all`: "All" / "全部"
- `accounts.searchPlaceholder`: "Search accounts..." / "搜索账户..."
- `accounts.filterByType`: "Filter by type" / "按类型筛选"

---

### Files Changed

| File | Action | Description |
|------|--------|-------------|
| `src-tauri/migrations/<timestamp>_add_initial_balance.sql` | Create | Rename balance → initial_balance |
| `src-tauri/src/domain/aggregates/account.rs` | Modify | Rename field, add `current_balance` logic |
| `src-tauri/src/application/dtos/account_dto.rs` | Modify | Add `initial_balance` + `current_balance` fields |
| `src-tauri/src/application/services/account_service.rs` | Modify | Add `get_current_balance` method |
| `src-tauri/src/infrastructure/repositories/account_repository.rs` | Modify | Update queries for renamed column, add balance computation query |
| `src-tauri/src/presentation/tauri_commands/account_commands.rs` | Modify | Add `get_account_current_balance` command |
| `src/lib/tauri/account.ts` | Modify | Update types and add new API function |
| `src/pages/AccountsPage.tsx` | Modify | Add tabs, search, type filter, column sorting |
| `src/components/AccountForm.tsx` | Modify | Balance field read-only in edit mode |
| `src/i18n/locales/en.json` | Modify | Add new keys |
| `src/i18n/locales/zh.json` | Modify | Add new keys |

### i18n Keys Summary

| Key | EN | ZH | Section |
|-----|----|----|---------|
| `accounts.searchPlaceholder` | Search accounts... | 搜索账户... | common |
| `accounts.filterByType` | Filter by type | 按类型筛选 | common |
| `accounts.initialBalance` | Initial Balance | 初始余额 | common |
| `accounts.currentBalance` | Current Balance | 当前余额 | common |

### Out of Scope

- Backend pagination — client-side only for now
- Multi-column sort
- Persisting sort/filter preferences
- Balance history/trend visualization
