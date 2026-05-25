# Account Filter: Split Own/External + Multi-Select

## Summary

Split the single account filter dropdown in TransactionsPage into two independent multi-select dropdowns — one for own accounts, one for external accounts — each supporting checkbox-based multi-selection.

## Motivation

- Currently only external accounts appear in the filter; user-created own accounts are invisible
- Single-select limits filtering to one account at a time
- Users need to filter by multiple accounts across both ownership types simultaneously

## Design

### New Component: `MultiSelect`

**File:** `src/components/ui/multi-select.tsx`

Built on `@base-ui/react` Popover + Checkbox primitives.

Props:
- `options: { id: string; label: string }[]` — selectable items
- `value: string[]` — currently selected IDs
- `onChange: (value: string[]) => void` — selection change handler
- `placeholder: string` — text when nothing selected
- `selectAllLabel: string` — label for the "select all" item

Behavior:
- Click trigger → open Popover with checkbox list
- "Select All" item at top toggles all options
- Individual items toggle independently
- Badge on trigger shows selected count (hidden when 0)
- Click outside closes Popover, preserving selection
- Responsive: Popover width matches trigger; on narrow screens trigger text truncates

### Filter State Changes (TransactionsPage)

Replace:
```
accountFilter: string ('all' | accountId)
```
With:
```
ownAccountFilter: string[]     // selected own account IDs; empty = all
externalAccountFilter: string[] // selected external account IDs; empty = all
```

### Filter Logic

```
if (ownAccountFilter.length > 0 || externalAccountFilter.length > 0) {
  result = result.filter(tx =>
    tx.entries.some(e =>
      (ownAccountFilter.length === 0 || ownAccountFilter.includes(e.account_id)) ||
      (externalAccountFilter.length === 0 || externalAccountFilter.includes(e.account_id))
    )
  );
}
```

An empty array for a group means "all accounts in that group" (no filter applied for that group).

### Filter Bar Layout

```
[All|Expense|Income|Transfer] | 自己: [MultiSelect] 外部: [MultiSelect] | [Search...] | N results
```

Responsive behavior:
- `flex-wrap` on the filter bar container
- Each MultiSelect trigger has `min-w-[120px] max-w-[180px]`
- On narrow screens (< 640px), multi-selects wrap to a new row
- Labels ("自己:", "外部:") hide on very narrow screens, relying on the placeholder text

### Files Changed

1. `src/components/ui/multi-select.tsx` — new component
2. `src/pages/TransactionsPage.tsx` — state, logic, and layout changes
3. `src/i18n/locales/en.json` — new keys
4. `src/i18n/locales/zh.json` — new keys

### i18n Keys

| Key | EN | ZH |
|---|---|---|
| `common.confirm` | Confirm | 确认 |
| `common.clear` | Clear | 清除 |
| `common.selectAll` | Select All | 全选 |
| `transactions.ownAccounts` | (exists) | (exists) |
| `transactions.externalAccounts` | (exists) | (exists) |

### Out of Scope

- Persisting filter state across page navigations
- URL-based filter state
- Debt/Liability form edit support (separate feature)
