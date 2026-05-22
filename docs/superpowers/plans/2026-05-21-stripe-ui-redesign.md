# Stripe-Style UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Polish all pages and components with Stripe-inspired design — soft gradients, generous rounding, colored card tints, line-variant tabs, chip filters, and gradient buttons.

**Architecture:** Bottom-up: design tokens and base components first, then pages. Each task touches 1-2 files. No structural refactoring — visual CSS-only changes backed by existing test suite.

**Tech Stack:** React 19, Tailwind CSS 3.4, Base UI, shadcn/ui tokens, class-variance-authority

---

### Task 1: Card Component Polish

**Files:**
- Modify: `src/components/ui/card.tsx`

- [ ] **Step 1: Update Card styling**

Change the Card root from `ring-1 ring-foreground/10` to soft shadow + border, and increase rounding:

```tsx
// Line 15 — replace the className:
"group/card flex flex-col gap-4 overflow-hidden rounded-2xl bg-card py-4 text-sm text-card-foreground border border-border/50 shadow-sm has-data-[slot=card-footer]:pb-0 has-[>img:first-child]:pt-0 data-[size=sm]:gap-3 data-[size=sm]:py-3 data-[size=sm]:has-data-[slot=card-footer]:pb-0 *:[img:first-child]:rounded-t-xl *:[img:last-child]:rounded-b-xl",
```

Key changes:
- `rounded-xl` → `rounded-2xl`
- `ring-1 ring-foreground/10` → `border border-border/50 shadow-sm`

- [ ] **Step 2: Verify type check and tests**

Run: `npx tsc --noEmit`
Expected: zero errors

Run: `npx vitest run`
Expected: 72 passed (1 skipped, 1 playwright pre-existing failure)

- [ ] **Step 3: Commit**

```bash
git add src/components/ui/card.tsx
git commit -m "feat(ui): polish Card component — rounded-2xl, soft shadow, border

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 2: Button Component Polish — Gradient Primary

**Files:**
- Modify: `src/components/ui/button.tsx`

- [ ] **Step 1: Add gradient primary variant**

Add a new `primary-gradient` variant to `buttonVariants` that uses Stripe-style gradient:

```tsx
// Add after the "default" variant line:
default: "bg-primary text-primary-foreground [a]:hover:bg-primary/80",
"default-gradient": "bg-gradient-to-br from-[#635bff] to-[#4f46e5] text-white shadow-[0_2px_8px_rgba(99,91,255,0.25)] hover:shadow-[0_4px_12px_rgba(99,91,255,0.35)] hover:brightness-105",
```

And add it to the variant type — change the `variant` property's default value from `"default"` to keep `"default"`, but the user will opt into `"default-gradient"` on primary CTAs. No breaking change to existing buttons.

- [ ] **Step 2: Verify type check and tests**

Run: `npx tsc --noEmit`  
Expected: zero errors

Run: `npx vitest run`
Expected: 72 passed (1 skipped)

- [ ] **Step 3: Commit**

```bash
git add src/components/ui/button.tsx
git commit -m "feat(ui): add gradient primary button variant

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 3: Table Component Polish

**Files:**
- Modify: `src/components/ui/table.tsx`

- [ ] **Step 1: Polish TableHead and TableRow**

Update `TableHead` to have uppercase styling with letter-spacing:

```tsx
// TableHead — replace className:
"h-10 px-2 text-left align-middle font-medium text-xs uppercase tracking-wider text-muted-foreground whitespace-nowrap [&:has([role=checkbox])]:pr-0"
```

Update `TableRow` hover to be subtler:

```tsx
// TableRow — replace className:
"border-b transition-colors hover:bg-muted/30 has-aria-expanded:bg-muted/30 data-[state=selected]:bg-muted"
```

Update `Table` wrapper to have rounded border:

```tsx
// Table component wrapper div — add rounded-lg border:
"relative w-full overflow-x-auto rounded-lg border"
```

- [ ] **Step 2: Verify type check and tests**

Run: `npx tsc --noEmit` / `npx vitest run`

- [ ] **Step 3: Commit**

```bash
git add src/components/ui/table.tsx
git commit -m "feat(ui): polish Table — uppercase headers, subtler hover, rounded border

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 4: Badge Polish

**Files:**
- Modify: `src/components/ui/badge.tsx`

- [ ] **Step 1: Add soft variants**

Add two new variants — `success` (green tint) and `warning` (amber tint), keeping existing variants:

```tsx
// In badgeVariants cva, add to variants.variant:
success: "bg-emerald-50 text-emerald-700 border-emerald-200 dark:bg-emerald-950 dark:text-emerald-300 dark:border-emerald-800",
warning: "bg-amber-50 text-amber-700 border-amber-200 dark:bg-amber-950 dark:text-amber-300 dark:border-amber-800",
```

- [ ] **Step 2: Verify type check and tests**

Run: `npx tsc --noEmit` / `npx vitest run`

- [ ] **Step 3: Commit**

```bash
git add src/components/ui/badge.tsx
git commit -m "feat(ui): add success and warning badge variants

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 5: Tabs — Line Variant on ReportsPage

**Files:**
- Modify: `src/pages/ReportsPage.tsx`

- [ ] **Step 1: Switch ReportsPage TabsList to line variant**

Change line 299 from:
```tsx
<TabsList className="grid w-full max-w-md grid-cols-2">
```
to:
```tsx
<TabsList variant="line" className="w-full">
```

Remove the `grid` and `max-w-md` classes — line variant uses natural width with gap.

- [ ] **Step 2: Verify type check and tests**

Run: `npx tsc --noEmit` / `npx vitest run`

- [ ] **Step 3: Commit**

```bash
git add src/pages/ReportsPage.tsx
git commit -m "feat(ui): switch ReportsPage tabs to line variant

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 6: HomePage Stat Cards Redesign

**Files:**
- Modify: `src/pages/HomePage.tsx`

- [ ] **Step 1: Redesign stat cards with icons, trend indicators, and tinted backgrounds**

Replace the 4-card grid section (currently lines ~82-130, the `{!isLoading && accounts.length > 0 && (` block start) with enriched stat cards.

Read the current stat cards section, then replace with:

```tsx
{!isLoading && accounts.length > 0 && (
  <>
    <div className="flex items-center gap-2 mb-1">
      <span className="text-xs font-medium text-muted-foreground uppercase tracking-wider">
        {t('dashboard.overview')}
      </span>
    </div>
    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
      {/* Total Balance */}
      <Card className="bg-gradient-to-br from-card to-card/80 border-border/40 shadow-sm">
        <CardContent className="pt-4">
          <div className="flex items-center gap-3 mb-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-primary/10">
              <Wallet className="h-4 w-4 text-primary" />
            </div>
            <span className="text-xs font-medium text-muted-foreground">
              {t('dashboard.totalBalance')}
            </span>
          </div>
          <div className="text-2xl font-bold tracking-tight">
            {formatCurrency(totalBalance)}
          </div>
        </CardContent>
      </Card>

      {/* Monthly Income */}
      <Card className="bg-gradient-to-br from-emerald-50/50 to-card border-emerald-200/50 shadow-sm dark:from-emerald-950/20 dark:to-card dark:border-emerald-800/30">
        <CardContent className="pt-4">
          <div className="flex items-center gap-3 mb-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-emerald-100 dark:bg-emerald-900/30">
              <ArrowUpRight className="h-4 w-4 text-emerald-600 dark:text-emerald-400" />
            </div>
            <span className="text-xs font-medium text-muted-foreground">
              {t('dashboard.monthlyIncome')}
            </span>
          </div>
          <div className="text-2xl font-bold tracking-tight text-emerald-600 dark:text-emerald-400">
            +{formatCurrency(monthlyIncome)}
          </div>
        </CardContent>
      </Card>

      {/* Monthly Expenses */}
      <Card className="bg-gradient-to-br from-red-50/50 to-card border-red-200/50 shadow-sm dark:from-red-950/20 dark:to-card dark:border-red-800/30">
        <CardContent className="pt-4">
          <div className="flex items-center gap-3 mb-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-red-100 dark:bg-red-900/30">
              <ArrowDownRight className="h-4 w-4 text-red-600 dark:text-red-400" />
            </div>
            <span className="text-xs font-medium text-muted-foreground">
              {t('dashboard.monthlyExpenses')}
            </span>
          </div>
          <div className="text-2xl font-bold tracking-tight text-red-600 dark:text-red-400">
            -{formatCurrency(monthlyExpenses)}
          </div>
        </CardContent>
      </Card>

      {/* Monthly Savings */}
      <Card className="bg-gradient-to-br from-blue-50/50 to-card border-blue-200/50 shadow-sm dark:from-blue-950/20 dark:to-card dark:border-blue-800/30">
        <CardContent className="pt-4">
          <div className="flex items-center gap-3 mb-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-blue-100 dark:bg-blue-900/30">
              <TrendingUp className="h-4 w-4 text-blue-600 dark:text-blue-400" />
            </div>
            <span className="text-xs font-medium text-muted-foreground">
              {t('dashboard.monthlySavings')}
            </span>
          </div>
          <div className={`text-2xl font-bold tracking-tight ${monthlySavings >= 0 ? 'text-emerald-600 dark:text-emerald-400' : 'text-red-600 dark:text-red-400'}`}>
            {monthlySavings >= 0 ? '+' : ''}{formatCurrency(monthlySavings)}
          </div>
        </CardContent>
      </Card>
    </div>
  </>
)}
```

- [ ] **Step 2: Remove duplicate old grid**

After adding the new stat cards, remove the old duplicate card grid that follows (the original `grid grid-cols-2 md:grid-cols-2 lg:grid-cols-4 gap-4` block).

- [ ] **Step 3: Add import for CardContent if not already imported**

Check that `CardContent` is imported from `@/components/ui/card`. Add it to the import on line 6 if missing.

- [ ] **Step 4: Verify type check and tests**

Run: `npx tsc --noEmit` / `npx vitest run`

- [ ] **Step 5: Commit**

```bash
git add src/pages/HomePage.tsx
git commit -m "feat(ui): redesign HomePage stat cards with icons, tints, trends

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 7: TransactionsPage — Chip Filters + Gradient Button

**Files:**
- Modify: `src/pages/TransactionsPage.tsx`

- [ ] **Step 1: Add helper for date range presets and chip-style filter bar**

Read the current TransactionsPage (find the date filter section with two `<Input>` elements and button group), then:

1. Replace the date preset buttons with chip/pill style:
   - Active chip: `rounded-full bg-primary/10 text-primary text-xs font-medium px-3 py-1.5`
   - Inactive chip: `rounded-full bg-muted text-muted-foreground text-xs px-3 py-1.5`

2. Change the "Record Transaction" button variant from `default` to `default-gradient`:
```tsx
<Button variant="default-gradient" onClick={...}>
  <Plus className="h-4 w-4 mr-1.5" />
  {t('transactions.recordTransaction')}
</Button>
```

- [ ] **Step 2: Verify type check and tests**

Run: `npx tsc --noEmit` / `npx vitest run`

- [ ] **Step 3: Commit**

```bash
git add src/pages/TransactionsPage.tsx
git commit -m "feat(ui): TransactionsPage — chip date filters + gradient CTA button

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 8: AccountsPage, DebtsPage, ReportsPage Button Polish

**Files:**
- Modify: `src/pages/AccountsPage.tsx`
- Modify: `src/pages/DebtsPage.tsx`
- Modify: `src/pages/ReportsPage.tsx`

- [ ] **Step 1: Switch primary CTA buttons to gradient variant**

In each page, find the main "Create"/"Add"/"Record" button and change `variant="default"` to `variant="default-gradient"`.

AccountsPage:
```tsx
// Find the "Create Account" button and change:
<Button variant="default-gradient" onClick={...}>
```

DebtsPage:
```tsx
// Find the "Add Debt" button and change:
<Button variant="default-gradient" onClick={...}>
```

ReportsPage:
```tsx
// Find the CSV export buttons and use outline (keep as-is), 
// no primary CTA on reports, skip if no default button found
```

- [ ] **Step 2: Verify type check and tests**

Run: `npx tsc --noEmit` / `npx vitest run`

- [ ] **Step 3: Commit**

```bash
git add src/pages/AccountsPage.tsx src/pages/DebtsPage.tsx
git commit -m "feat(ui): switch page CTA buttons to gradient variant

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 9: Sidebar Gradient Background

**Files:**
- Modify: `src/components/layout/Sidebar.tsx`

- [ ] **Step 1: Add subtle gradient to sidebar**

Find the Sidebar component's root element (likely a `<aside>` with `bg-card`). Change to:

```tsx
// Replace bg-card with gradient:
"bg-gradient-to-b from-card via-card to-muted/30"
```

- [ ] **Step 2: Verify type check and tests**

Run: `npx tsc --noEmit` / `npx vitest run`

- [ ] **Step 3: Commit**

```bash
git add src/components/layout/Sidebar.tsx
git commit -m "feat(ui): add subtle gradient to sidebar background

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 10: QuickActions and EmptyState Polish

**Files:**
- Modify: `src/components/QuickActions.tsx`
- Modify: `src/components/EmptyState.tsx`

- [ ] **Step 1: Polish QuickActions**

Read current QuickActions. Update button styling:
- Use softer border colors
- Add subtle hover shadow

- [ ] **Step 2: Polish EmptyState**

Read current EmptyState. Update:
- Icon container: `rounded-2xl` (was `rounded-full`)
- Subtle background tint on the icon circle

- [ ] **Step 3: Verify type check and tests**

Run: `npx tsc --noEmit` / `npx vitest run`

- [ ] **Step 4: Commit**

```bash
git add src/components/QuickActions.tsx src/components/EmptyState.tsx
git commit -m "feat(ui): polish QuickActions and EmptyState components

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 11: SettingsPage Card Polish

**Files:**
- Modify: `src/pages/SettingsPage.tsx`

- [ ] **Step 1: Polish card sections**

Read current SettingsPage. For each `Card` section, add a subtle header accent:
- Add `border-border/40 shadow-sm` to each Card (already inherited from Task 1)
- Ensure section titles are consistent and well-spaced

No structural changes — the Card polish from Task 1 already handles the visual upgrade.

- [ ] **Step 2: Verify type check and tests**

Run: `npx tsc --noEmit` / `npx vitest run`

- [ ] **Step 3: Commit**

```bash
git add src/pages/SettingsPage.tsx
git commit -m "feat(ui): minor SettingsPage card spacing polish

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 12: Final Integration — Full Test Suite + Visual Check

**Files:** None (verification only)

- [ ] **Step 1: Run full test suite**

```bash
npx vitest run
```
Expected: 72 tests passed, 1 skipped (playwright pre-existing)

- [ ] **Step 2: Run TypeScript check**

```bash
npx tsc --noEmit
```
Expected: zero errors

- [ ] **Step 3: Build check**

```bash
npx vite build
```
Expected: builds successfully, no CSS warnings

- [ ] **Step 4: Manual verification checklist**

Start the dev server and check each page:
- [ ] HomePage — stat cards with icons, tints, trends
- [ ] TransactionsPage — chip filters, line tabs, gradient CTA
- [ ] AccountsPage — polished table, gradient CTA
- [ ] DebtsPage — polished cards and badges
- [ ] ReportsPage — line tabs variant, polished cards
- [ ] SettingsPage — consistent card styling
- [ ] OnboardingPage — polished cards

- [ ] **Step 5: Commit**

```bash
git commit -m "chore: final integration verification — all tests pass

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```
