# Stripe-Style UI Redesign

**Date:** 2026-05-21
**Status:** Approved
**Scope:** All pages and UI components — visual polish, not structural refactor

## Design Direction

Stripe-inspired: clean, friendly, soft gradients, generous rounding, colorful but disciplined. Focus on trust and approachability for a personal finance app.

**Reference products:** Stripe Dashboard, Vercel Analytics, Linear (information density)

## Color System

| Token | Current | New |
|-------|---------|-----|
| Primary | `hsl(var(--primary))` | Same, but used with gradient: `linear-gradient(135deg, #635bff, #4f46e5)` |
| Card bg | `bg-card` (solid) | Optional tinted gradients per category (income=green tint, expense=red tint) |
| Card border | `ring-1 ring-foreground/10` | `border border-<color>/20` with `shadow-sm` |
| Sidebar | `bg-card` solid | Subtle gradient sidebar |

## Component Changes

### 1. Tabs — Global `line` Variant

**All** `TabsList` instances switch to `variant="line"`:
- `SimpleTransactionForm.tsx`: Already `line` (from prior spec)
- `ReportsPage.tsx`: Change from `variant="default"` to `variant="line"`

Remove `grid grid-cols-*` classes from `TabsList` — `line` variant uses `gap-*` for spacing.

### 2. Stat Cards (HomePage)

Before:
```
Card > CardHeader(title) + CardContent(value)
```

After:
```
Card with:
  - Gradient-tinted background per type (neutral/income/expense/savings)
  - Small rounded icon container
  - Trend indicator (% change, green up / red down)
  - Soft shadow
```

### 3. Buttons

Primary CTA buttons: gradient background + subtle box-shadow:
```
bg-gradient-to-br from-[#635bff] to-[#4f46e5] shadow-[0_2px_8px_rgba(99,91,255,0.2)]
```

### 4. Tables

- Header row: `bg-muted/50`, uppercase text, `tracking-wider`, smaller font
- Cell padding: increase from `px-3` to `px-4`
- Row hover: `bg-muted/30` (subtler)

### 5. Date Filter Presets

Change from `Button` group (`default`/`outline` variants) to pill/chip style:
```
rounded-full, active: bg-primary/10 text-primary, inactive: bg-muted text-muted-foreground
```

### 6. Cards (Global)

- Increase border-radius from `rounded-xl` to `rounded-2xl`
- Add `shadow-sm` (replaces `ring-1`)
- Category cards (income/expense) get tinted borders and backgrounds

### 7. Sidebar

- Subtle gradient background instead of solid `bg-card`

## Pages Affected

| Page | Changes |
|------|---------|
| **HomePage** | Stat cards redesign, QuickActions polish, greeting header |
| **TransactionsPage** | Tabs→line, date chips, table polish, button gradients |
| **ReportsPage** | Tabs→line, date chips, card polish, table polish |
| **AccountsPage** | Table polish, button gradients, card polish |
| **DebtsPage** | Table polish, badge polish, alert card polish |
| **SettingsPage** | Card sections polish, form field polish |
| **OnboardingPage** | Card polish, button gradients |

## Implementation Order

1. **Design tokens** — Update CSS variables, add gradient utilities
2. **Core components** — Card, Button, Tabs, Table, Badge polish
3. **HomePage** — Stat cards and dashboard
4. **List pages** — Transactions, Accounts, Debts
5. **ReportsPage** — Tabs + charts
6. **SettingsPage** — Form polish
7. **OnboardingPage** — Card polish

## Not in Scope

- Structural/layout refactoring
- New components or features
- Mobile responsive redesign (existing responsive patterns preserved)
- Dark mode redesign (dark mode keeps existing tokens, gets same polish)
