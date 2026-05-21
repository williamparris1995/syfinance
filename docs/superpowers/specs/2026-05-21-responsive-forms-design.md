# Responsive Forms Redesign

**Date:** 2026-05-21
**Status:** Approved
**Scope:** All form creation/edit flows across the app

## Problem

- Forms use `Dialog` modals which feel clunky on wide screens
- Transaction entry had separate buttons for quick vs advanced
- Forms should adapt to screen size for better UX

## Solution: Sheet + Route Hybrid

| Screen Size | Behavior |
|---|---|
| Wide (>=1024px) | Slide-out **Sheet** from the right side |
| Narrow (<1024px) | Navigate to a dedicated child route page |

## Implementation Plan

### 1. `useResponsiveSheet` Hook

Custom hook that detects viewport and returns appropriate navigation:

```ts
function useResponsiveSheet() {
  const isWide = useMediaQuery('(min-width: 1024px)');
  const navigate = useNavigate();

  return {
    openForm: (path: string) => {
      if (isWide) setSheetOpen(true);
      else navigate({ to: path });
    },
    // ...
  };
}
```

### 2. New Routes

Add child routes under existing list routes:
- `/transactions/new` — standalone SimpleTransactionForm page
- `/accounts/new` — standalone AccountForm page
- `/debts/new` — standalone DebtForm page

### 3. Page Changes

**TransactionsPage:**
- Replace two buttons (Quick + Advanced) with single "Add Transaction" button
- SimpleTransactionForm already uses Tabs for expense/income/transfer
- Remove the old TransactionForm (advanced double-entry) dialog — simplify UX
- Open in Sheet (wide) or navigate to `/transactions/new` (narrow)

**AccountsPage:**
- Replace Dialog with Sheet/route pattern for AccountForm

**DebtsPage:**
- Replace Dialog with Sheet/route pattern for DebtForm

**SettingsPage:**
- Replace Dialog with Sheet/route pattern for CurrencyForm

### 4. Forms (no structural changes needed)

All forms already use shadcn components and are well-structured:
- SimpleTransactionForm — Tabs + Input + Select
- AccountForm — Form + Input + Select
- DebtForm — Form + Input + Select + Table preview
- CurrencyForm — Form + Input

### 5. Files Touched

| File | Change |
|---|---|
| `src/hooks/useResponsiveSheet.ts` | New hook |
| `src/pages/TransactionsPage.tsx` | Sheet + route navigation, merge two buttons |
| `src/pages/AccountsPage.tsx` | Sheet + route navigation |
| `src/pages/DebtsPage.tsx` | Sheet + route navigation |
| `src/pages/SettingsPage.tsx` | Sheet + route navigation |
| `src/pages/NewTransactionPage.tsx` | New standalone page |
| `src/pages/NewAccountPage.tsx` | New standalone page |
| `src/pages/NewDebtPage.tsx` | New standalone page |
| `src/router.tsx` | Add child routes |
| `src/components/SimpleTransactionForm.tsx` | Minor polish |
