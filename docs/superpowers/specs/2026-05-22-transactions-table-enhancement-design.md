# Transactions Table Enhancement — Design Spec

**Date:** 2026-05-22
**Status:** Draft
**Approach:** C — Hybrid filtering + optimistic updates

## Motivation

The TransactionsPage currently has only two raw date inputs for filtering and no edit/delete capability. The goal is to align it with the rest of the app (period selector pattern from HomePage/ReportsPage) and add full CRUD operations with filtering.

## Design Approach

**Approach C: Hybrid filtering + optimistic updates**

- Period/date range → server-side filtering via existing `getTransactionsByDateRange`
- Type / account / text search → client-side filtering via `useMemo`
- Inline description edit with optimistic update + debounced save
- Edit button opens Sheet with pre-filled `SimpleTransactionForm`
- Delete with confirmation dialog + optimistic removal + toast with undo
- Backend: add `update_transaction` and `delete_transaction` Tauri commands

Rationale: for a local SQLite app, the transaction count per period is manageable client-side. Leveraging the existing `getTransactionsByDateRange` minimizes backend work. Optimistic updates provide instant-feeling UX.

## Layout

Three rows from top to bottom:

```
┌──────────────────────────────────────────────────────┐
│ Transactions                        [+ Record Tx]    │  ← header
├──────────────────────────────────────────────────────┤
│ [Month] [Quarter] [Year] [Custom]  | 2026-05-01..31  │  ← period selector
├──────────────────────────────────────────────────────┤
│ [All|Exp|Inc|Xfer] | [Account v] | [Search...]   42  │  ← filter bar
├──────────────────────────────────────────────────────┤
│ Date | Type | Description | Amount | Accounts | Act  │  ← table
│ May15| Exp  | Grocery...  | -156.80| Chase    | ✏️🗑️ │
│ May14| Inc  | Salary...   |+5200.00| Chase    | ✏️🗑️ │
└──────────────────────────────────────────────────────┘
```

## Components

### 1. Period Selector

Reuse the pattern from HomePage/ReportsPage:
- Button group: Month / Quarter / Year / Custom
- Uses `DateRangePreset` type (already defined in HomePage)
- When "Custom" selected, two `<Input type="date">` fields appear inline
- Computes `dateRange: { start: string; end: string }` via `useMemo`
- Drives the React Query key: `['transactions', dateRange.start, dateRange.end]`

### 2. Filter Bar

Rendered between period selector and table. Gray background card with:

- **Type toggle**: Button group — All (default) / Expense / Income / Transfer
- **Account dropdown**: `<Select>` listing external accounts, default "All Accounts"
- **Text search**: `<Input>` with search icon, placeholder "Search description..."
- **Result count**: Right-aligned text showing matching row count (e.g., "42 transactions")

Filter state:
```typescript
const [typeFilter, setTypeFilter] = useState<'all' | 'expense' | 'income' | 'transfer'>('all');
const [accountFilter, setAccountFilter] = useState<string>('all');
const [searchQuery, setSearchQuery] = useState('');
```

Client-side filtering in `useMemo`:
```typescript
const filteredTransactions = useMemo(() => {
  let result = transactions;
  if (typeFilter !== 'all') {
    result = result.filter(tx => getTransactionType(tx) === typeFilter);
  }
  if (accountFilter !== 'all') {
    result = result.filter(tx => tx.entries.some(e => e.account_id === accountFilter));
  }
  if (searchQuery) {
    const q = searchQuery.toLowerCase();
    result = result.filter(tx => tx.description?.toLowerCase().includes(q));
  }
  return result;
}, [transactions, typeFilter, accountFilter, searchQuery]);
```

### 3. Transaction Type Derivation

New helper to classify transactions for the Type column and type filter:
```typescript
type TransactionType = 'income' | 'expense' | 'transfer';

function getTransactionType(tx: TransactionDto): TransactionType {
  // Derived from entries' linked account types
  // If all external accounts in entries are Income → 'income'
  // If all external accounts in entries are Expense → 'expense'
  // Mixed or internal-only → 'transfer'
}
```

Type badges use color-coded pills:
- Expense: red background (`bg-red-50 text-red-600`)
- Income: green background (`bg-green-50 text-green-600`)
- Transfer: purple background (`bg-purple-50 text-purple-600`)

### 4. Table Columns

| Column | Width | Notes |
|--------|-------|-------|
| Date | auto | Formatted via `toLocaleDateString` |
| Type | 90px | Color-coded pill badge |
| Description | auto | Click to inline-edit (see below) |
| Amount | 120px | Right-aligned, color-coded (+green/-red) |
| Accounts | auto | Joined account names |
| Actions | 80px | Edit + Delete icon buttons |

### 5. Inline Description Edit

- Click description text → swaps to `<Input>` with current value
- Input auto-focuses
- On blur or Enter: calls `updateTransaction` with new description, optimistic UI update
- On Escape: cancels edit, restores original value
- Visual: input gets `border-2 border-blue-500` to distinguish from surrounding cells

### 6. Edit Sheet

- Click ✏️ icon → opens `<Sheet side="right">`
- Sheet contains `<SimpleTransactionForm>` with new `initialData` prop
- `initialData: TransactionFormData` pre-fills all fields
- On submit: calls `update_transaction` Tauri command → closes sheet → invalidates query cache
- SimpleTransactionForm changes:
  ```typescript
  interface SimpleTransactionFormProps {
    accounts: AccountDto[];
    externalAccounts: AccountDto[];
    onSubmit: (data: TransactionFormData) => Promise<void>;
    onCancel: () => void;
    initialData?: TransactionFormData;  // NEW — pre-fill for edit mode
  }
  ```
  When `initialData` is present: button text changes from "Record" to "Save Changes", sheet title changes to "Edit Transaction".

### 7. Delete Flow

- Click 🗑️ icon → `<AlertDialog>` opens
- Title: "Delete Transaction"
- Description: "Are you sure? This action cannot be undone."
- Cancel / Delete buttons (Delete is destructive red variant)
- On confirm: optimistic remove from list + call `delete_transaction` + toast
- Toast has undo button (3 seconds): restores row + cancels backend call

## Data Flow

```
Period Selector → dateRange → React Query (server fetch)
                                   ↓
                            transactions[]
                                   ↓
            ┌──────────────────────┼──────────────────────┐
            ↓                      ↓                      ↓
       typeFilter            accountFilter          searchQuery
            └──────────────────────┼──────────────────────┘
                                   ↓
                          filteredTransactions (useMemo)
                                   ↓
                              <Table> renders
```

Mutations:
```
Inline Edit → updateTransaction({ id, description }) → queryClient.setQueryData (optimistic)
Edit Sheet  → updateTransaction(fullDto)              → queryClient.invalidateQueries
Delete      → deleteTransaction(id)                   → queryClient.setQueryData (optimistic removal)
```

## Backend Changes

Two new Tauri commands in `transaction_commands.rs`:

### `update_transaction`
```rust
#[tauri::command]
async fn update_transaction(
    state: tauri::State<'_, AppState>,
    transaction: TransactionDto,
) -> Result<TransactionDto, String> {
    // 1. Validate transaction exists
    // 2. Delete existing entries for this transaction
    // 3. Insert new entries
    // 4. Update transaction main record (date, description)
    // 5. Return updated TransactionDto
}
```

### `delete_transaction`
```rust
#[tauri::command]
async fn delete_transaction(
    state: tauri::State<'_, AppState>,
    transaction_id: String,
) -> Result<(), String> {
    // 1. Delete entries (FK constraint)
    // 2. Delete transaction main record
    // All in a single SQL transaction
}
```

Corresponding service methods in `transaction_service.rs` and repository methods in `transaction_repository_postgres.rs`.

## Frontend File Changes

| File | Change |
|------|--------|
| `src/pages/TransactionsPage.tsx` | Major: period selector, filter bar, Type column, Actions column, inline edit state, edit Sheet, delete dialog |
| `src/components/SimpleTransactionForm.tsx` | Add `initialData?` prop, pre-fill form fields, change button text for edit mode |
| `src/lib/tauri/transaction.ts` | Add `updateTransaction()` and `deleteTransaction()` invoke wrappers |
| `src/i18n/locales/en.json` | New keys for type labels, filter placeholders, edit/delete actions, confirm dialog |
| `src/i18n/locales/zh.json` | Chinese translations for same keys |

## Backend File Changes

| File | Change |
|------|--------|
| `src-tauri/src/presentation/tauri_commands/transaction_commands.rs` | Add `update_transaction`, `delete_transaction` commands |
| `src-tauri/src/application/services/transaction_service.rs` | Add `update_transaction`, `delete_transaction` methods |
| `src-tauri/src/infrastructure/repositories/transaction_repository_postgres.rs` | Add `update`, `delete` SQL methods |

## i18n Keys (New)

```json
// en.json
{
  "transactions": {
    "type": "Type",
    "allTypes": "All",
    "expense": "Expense",
    "income": "Income",
    "transfer": "Transfer",
    "allAccounts": "All Accounts",
    "searchDescription": "Search description...",
    "edit": "Edit",
    "delete": "Delete",
    "editTransaction": "Edit Transaction",
    "deleteConfirmTitle": "Delete Transaction",
    "deleteConfirmDesc": "Are you sure? This action cannot be undone.",
    "deleteSuccess": "Transaction deleted",
    "undo": "Undo",
    "saveChanges": "Save Changes",
    "descriptionUpdated": "Description updated"
  }
}
```

## Scope

- Frontend: TransactionsPage, SimpleTransactionForm, Tauri invoke wrappers, i18n
- Backend: Two new Tauri commands (update + delete), service + repository methods
- No database schema changes needed
- No new dependencies needed
