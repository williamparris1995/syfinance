# Tabs Line Variant — SimpleTransactionForm

**Date:** 2026-05-21
**Status:** Approved
**Scope:** `SimpleTransactionForm.tsx` Tabs styling only

## Problem

The `SimpleTransactionForm` expense/income/transfer tab bar uses `variant="default"` with `grid w-full grid-cols-3`, which:

- Renders as three equally-spaced gray pill buttons, not recognizable as tabs
- The active tab's `bg-background` highlight has insufficient contrast against the `bg-muted` container
- `TabsList` defaults to `w-fit`, causing it to hug the left edge instead of spanning full width above the form

## Solution

Switch `TabsList` to `variant="line"` with `w-full`, matching the shadcn/ui line variant specification.

### Changes

**File:** `src/components/SimpleTransactionForm.tsx`

| Line | Current | Change |
|------|---------|--------|
| 180 | `<TabsList className="grid w-full grid-cols-3">` | `<TabsList variant="line" className="w-full">` |
| 186 | `className="space-y-4 mt-4"` | `className="space-y-4"` |
| 238 | `className="space-y-4 mt-4"` | `className="space-y-4"` |
| 290 | `className="space-y-4 mt-4"` | `className="space-y-4"` |

### Effect

| Aspect | Before | After |
|--------|--------|-------|
| Variant | `default` (gray pill container) | `line` (transparent + bottom border) |
| Active indicator | White background on gray | 2px black underline |
| Width | `w-fit` (hugs left) | `w-full` (spans form width) |
| Content spacing | Manual `mt-4` | Tabs wrapper `gap-2` |

### What stays the same

- Tabs orientation: `horizontal` (tabs on top, content below)
- Three tabs: expense, income, transfer
- All form fields and validation logic
- Sheet + route navigation in `TransactionsPage` / `NewTransactionPage`

### Not in scope

- Extracting shared form fields from `TabsContent`
- Edit pages (not yet implemented)
- Any other form component (`AccountForm`, `DebtForm`, `CurrencyForm`)
