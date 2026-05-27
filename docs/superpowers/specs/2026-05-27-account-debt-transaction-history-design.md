# Account & Debt Transaction History Design

## Context

HoldingsPage and SubscriptionsPage both support expandable rows to show associated transaction records. AccountsPage and DebtsPage lack this capability — users cannot see what transactions are linked to an account or debt from those pages. The backend already provides `getTransactionsByAccount(accountId)` and `DebtDto` includes `account_id` for querying transactions.

## Requirements

1. **AccountDetailPanel**: Sheet showing account summary + associated transaction list
2. **DebtDetailPanel**: Sheet showing debt summary + payment schedule (with per-period interest) + associated transaction list
3. **TransactionList**: Shared component for rendering transactions, reused across AccountDetailPanel, DebtDetailPanel, and PrepaidDetailPanel
4. **Interaction**: Click "View" button on account/debt row to open Sheet

## Shared Component: TransactionList

### File: `src/components/TransactionList.tsx`

A pure presentational component.

**Props**:
```typescript
interface TransactionListProps {
  transactions: TransactionDto[];
  accountId?: string;
  currencyCode?: string;
  isLoading?: boolean;
}
```

**Behavior**:
- Renders each transaction as a row: date | description | amount (colored by debit/credit direction relative to `accountId`)
- If `accountId` is provided, finds the entry matching that account and shows the debit/credit amount with color (debit = red/expense, credit = green/income)
- Sorted by `transaction_date` descending
- Empty state: "暂无交易记录" with an icon
- Loading state: skeleton/spinner

**Reuse**: Replace the manual transaction rendering in PrepaidDetailPanel's "Consumption" tab with this component.

## AccountDetailPanel

### File: `src/components/AccountDetailPanel.tsx`

Right-side Sheet, opened from AccountsPage.

**Data sources**:
- Account info from parent (passed as prop or fetched via `getAccount`)
- Transactions via `useQuery` → `getTransactionsByAccount(accountId)`

**Layout** (top to bottom):

1. **Header**: Account name + type Badge
2. **Summary section** (grid 2-col):
   - Currency code
   - Initial balance / Current balance
   - Account number (if any)
   - Institution (if any)
3. **Separator**
4. **Transaction records**: `<TransactionList>` with full transaction list

**AccountsPage changes**:
- Add "View" button (Eye icon) to every account row (not just prepaid)
- `detailAccountId` state controls Sheet visibility
- Prepaid accounts: show AccountDetailPanel instead of separate PrepaidDetailPanel, or keep PrepaidDetailPanel with its specialized top-up/consumption tabs and add the "View" button for other account types

**Decision**: Keep PrepaidDetailPanel for prepaid accounts (it has specialized top-up/consumption tabs). AccountDetailPanel is for all non-prepaid account types. Both reuse TransactionList internally.

## DebtDetailPanel

### File: `src/components/DebtDetailPanel.tsx`

Right-side Sheet, opened from DebtsPage.

**Data sources**:
- Debt info from parent (passed as prop via `DebtDto`)
- Transactions via `useQuery` → `getTransactionsByAccount(debt.account_id)` — this fetches all transactions involving the debt account, including the initial loan/disbursement transaction and every repayment transaction

**Layout** (top to bottom):

1. **Header**: Debt account name + type Badge
2. **Summary section** (grid 2-col):
   - Counterparty
   - Principal / Remaining principal
   - Interest rate (% / year)
   - Start date / Due date
   - Amortization method
3. **Separator**
4. **Payment schedule table**:
   - Columns: 期数 | 还款日 | 本金 | 利息 | 总额 | 状态
   - Paid rows: muted styling + checkmark, clickable to see transaction
   - Unpaid rows: normal styling
   - Shows per-period interest clearly
5. **Separator**
6. **Transaction records**: `<TransactionList>` with all associated transactions

**DebtsPage changes**:
- Existing "View" button (Eye icon) currently opens DebtForm in read-only mode
- Change to open DebtDetailPanel Sheet instead
- Can keep the "Record Payment" button as-is

## Files

### New files
| File | Responsibility |
|------|---------------|
| `src/components/TransactionList.tsx` | Shared transaction list renderer |
| `src/components/AccountDetailPanel.tsx` | Account detail Sheet with transactions |
| `src/components/DebtDetailPanel.tsx` | Debt detail Sheet with schedule + transactions |

### Modified files
| File | Change |
|------|--------|
| `src/pages/AccountsPage.tsx` | Add View button for all accounts, wire up AccountDetailPanel |
| `src/pages/DebtsPage.tsx` | Change View button to open DebtDetailPanel |
| `src/components/PrepaidDetailPanel.tsx` | Replace manual transaction rendering with TransactionList |

## Reused Patterns

| Pattern | Source | What's Reused |
|---------|--------|---------------|
| Sheet side panel | PrepaidDetailPanel | Panel structure, close behavior |
| Transaction query | PrepaidDetailPanel | `getTransactionsByAccount` API |
| Account type Badge | AccountsPage | Type display styling |
| Payment schedule table | DebtForm | Schedule rendering |

## Out of Scope

- Edit transactions from the detail panel (navigate to TransactionsPage for editing)
- Pagination (load all transactions, most accounts won't have thousands)
- Transaction filtering by date range within the panel
- Statistical charts for account/debt transactions
