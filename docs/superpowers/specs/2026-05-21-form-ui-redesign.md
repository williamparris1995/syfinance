# Personal Finance Form UI Redesign

**Date:** 2026-05-21
**Status:** Approved
**Scope:** SimpleTransactionForm, AccountForm, DebtForm, CurrencyForm UI optimization

## Design Philosophy

Personal finance, not enterprise accounting. Every design decision prioritizes speed and simplicity:
- Record a transaction in under 5 seconds
- Hide double-entry mechanics from the user
- Smart defaults over mandatory choices
- Progressive disclosure over long forms

**Design references:**
- Data model: double-entry bookkeeping standards (GAAP/IFRS), django-ledger, smrt-ledger
- UX patterns: Mercury (progressive disclosure, AI categorization), Revolut (adaptive flows), Stripe (visual silence), Monarch Money (emoji category chips), YNAB (single-screen entry)

## Form Designs

### 1. SimpleTransactionForm — "Amount First"

**Problem:** Current 3-tab layout duplicates the amount field. Type switching changes the entire tab content, creating visual flicker. Users must scroll to find date/note below tabs.

**Solution:** Amount field extracted above tabs — always visible, large format with ¥ symbol. Type selector becomes a compact pill toggle. Category selection uses emoji chips instead of dropdown. Date and account are secondary fields (2-column grid). Smart defaults for date (today), account (last used).

**Layout (top to bottom):**
1. Type toggle pill (Expense | Income | Transfer) — compact, `rounded-full` container
2. Amount hero — large input (28px font) with ¥ prefix, tinted background per type
3. Category chips (Expense/Income) / Account selects (Transfer) — emoji + name, tap to select
4. Account + Date — 2-column grid, muted labels
5. Note — optional, inline with "Add note" placeholder
6. CTA button — context-aware: "Record Expense — ¥156.30"

**Transfer type exception:** Category chips replaced by From Account / To Account selects.

### 2. AccountForm — "Just the Essentials"

**Problem:** 7 fields stacked vertically, plus conditional fields for Credit Card and Loan types. Long scroll in a Sheet.

**Solution:** 3 core fields always visible (Name, Type, Balance). Advanced fields (currency, account number, institution, credit limit, billing day, payment due day, interest rate) collapsed behind "+ Advanced" expander. Conditional fields animate in when Type changes.

**Core fields:** Name (text), Type (select: Cash/Bank/CreditCard/Investment/Loan/Other), Balance (number with ¥ prefix)

**Advanced (expandable):** Currency (select), Account Number (text, optional), Institution (text, optional), Credit Card: Credit Limit + Billing Day + Payment Due Day (3-column), Loan: Interest Rate

### 3. DebtForm — "Lump Sum or Installment"

**Problem:** 7 fields + large payment schedule table creates excessive scroll. Amortization method exposed without context. No clear distinction between one-time repayment and installment loans.

**Solution:** Repayment mode toggle (Lump Sum | Installment) determines which fields appear. Live summary replaces bulky table.

**Common fields (both modes):** Type (Borrowed/Lent), Counterparty, Principal (¥ prefixed), Interest Rate (% suffixed)

**Lump Sum fields:** Due Date (single date) → Summary: "Repayment on due date: ¥XXX (Principal ¥XXX + Interest ¥XXX)"

**Installment fields:** Number of Periods (select: 3/6/12/24/36), Start Date, Amortization Method (select: Equal P+I / Equal Principal) → Summary: "Monthly: ¥XXX × N payments (Total interest: ¥XXX)"

Payment schedule table collapsed inside `<details>` — expand on demand.

### 4. CurrencyForm — Minor Polish

**Problem:** Code field auto-uppercases via onChange — visual flicker. Exchange rate uses text input.

**Solution:** CSS `uppercase` on code input + `type="number"` with `step="0.0001"` for exchange rate. Add placeholder text indicating base currency context.

## Implementation Details

### Shared Patterns

**All forms:**
- Sheet wrapper: `side="right"` `className="w-full sm:max-w-lg"`
- Scroll wrapper: `flex-1 overflow-y-auto -mx-4 px-4`
- Form spacing: `space-y-5` (consistent across all forms)
- Button row: gradient CTA (using existing `variant="default-gradient"`) + outline Cancel
- Field labels: `text-xs uppercase tracking-wider text-muted-foreground`
- Required indicator: red asterisk on label
- Optional indicator: "— optional" in muted text

**Grid usage:**
- 2 related fields → `grid grid-cols-2 gap-3` (e.g., Account + Date)
- 3 related fields → `grid grid-cols-3 gap-3` (e.g., Credit Card details)
- Form sections separated by `border-t pt-4` or section label

**Number inputs with units:**
```tsx
<div className="flex items-center border rounded-lg overflow-hidden">
  <span className="px-2.5 py-2 text-muted-foreground bg-muted/50 border-r text-sm">¥</span>
  <input className="flex-1 border-0 ..." />
</div>
```

### Visual States

| Element | Rest | Focus | Error |
|---------|------|-------|-------|
| Type pill toggle | `bg-muted text-muted-foreground` | — | — |
| Type pill (active) | `bg-background text-type-color shadow-sm` | — | — |
| Category chip | `bg-muted text-muted-foreground` | — | — |
| Category chip (selected) | `bg-type-tint border-type-border text-type-color` | — | — |
| Amount input | Large, transparent bg | Subtle ring | Red border |

### Responsive

- Desktop (≥1024px): Sheet `side="right"`, 2/3-column grids
- Mobile (<1024px): Full page route, grids collapse to single column, category chips wrap

## Not in Scope

- Adding new category icons/emojis to the data model (use existing category names)
- Payment schedule calculation logic changes (existing math is correct)
- Form validation rule changes (existing zod schemas preserved)
- Sheet routing logic changes (existing useMediaQuery pattern preserved)
- Account linking / Plaid integration
- AI auto-categorization
