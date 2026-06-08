# YuCai UI Redesign — P1 Account Module Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Rewrite the account module using YuCai patterns — card grid list, dedicated detail page, styled form pages — establishing the reference implementation for all future modules.

**Architecture:** Convert AccountsPage from Table to DataCard grid with PageShell/PageHeader/StatCard/FilterBar patterns. Replace AccountDetailPanel (Sheet) with a full AccountDetailPage route using HeroCard + DetailTwoCol. Restyle NewAccountPage and AccountEditPage with PageShell/FormCard patterns.

**Tech Stack:** React, Tailwind CSS, shadcn/ui, TanStack Router/Query, recharts, react-hook-form

**Spec:** `docs/superpowers/specs/2026-06-08-yucai-ui-redesign-design.md`

---

## File Map

### Modify
| File | Change |
|------|--------|
| `src/pages/AccountsPage.tsx` | Table → DataCard grid, PageShell, StatCard summary, FilterBar |
| `src/pages/AccountDetailPage.tsx` | Placeholder → full detail page with HeroCard + DetailTwoCol |
| `src/pages/NewAccountPage.tsx` | Restyle with PageShell + FormCard |
| `src/pages/AccountEditPage.tsx` | Restyle with PageShell + FormCard |

### Keep unchanged
- `src/components/AccountForm.tsx` — functional form, already works
- `src/components/AccountWizard.tsx` — keep as dialog
- `src/components/DeleteAccountDialog.tsx` — keep as dialog
- `src/components/TopUpDialog.tsx` — keep as dialog
- `src/components/PrepaidDetailPanel.tsx` — keep as dialog (Prepaid special case)
- `src/components/AccountChangesDialog.tsx` — keep as dialog

### Delete (after migration)
- `src/components/AccountDetailPanel.tsx` — replaced by AccountDetailPage

---

## Task 1: Rewrite AccountsPage — Table → DataCard Grid

**Files:** `src/pages/AccountsPage.tsx`

### What changes

1. **Outer wrapper**: Replace `<div className="p-4 sm:p-6">` with `<PageShell>`
2. **Page header**: Replace inline header with `<PageHeader>` (title + actions slot with create button)
3. **Summary cards**: Replace inline colored divs with 3 `<StatCard>` components (total assets, liabilities, net worth)
4. **Filter bar**: Replace inline filter buttons with `<FilterBar>` component for type filtering; keep search and archive toggle as separate controls
5. **Account cards**: Replace `AccountGroupTable` (Table component) with a new `AccountGroupCards` function that renders `<DataCard>` grid items. Each card shows:
   - Icon + account name + status badge
   - Current balance (large, font-display)
   - Balance sparkline (keep existing)
   - Currency code
   - Action buttons row (edit, copy, archive/hide, etc.)
6. **Click to detail**: Clicking a card navigates to `/accounts/$accountId` instead of opening AccountDetailPanel Sheet
7. **Remove AccountDetailPanel import/usage**: The detail is now a route page

### What stays the same
- All data fetching logic (useQuery, useCurrencies, mutations)
- AccountWizard dialog for creating
- DeleteAccountDialog
- TopUpDialog (Prepaid special case)
- PrepaidDetailPanel (Prepaid special case)
- Copy Sheet
- Search, sort, filter logic
- TYPE_ORDER array

### Key pattern
```
<PageShell>
  <PageHeader title={t('accounts.title')} actions={<Button>+ New</Button>} />
  <div className="grid grid-cols-3 gap-3.5 mb-7">
    <StatCard label="Total Assets" value="¥128,300" tag="+2.3%" tagVariant="positive" />
    <StatCard label="Total Liabilities" value="¥12,500" tagVariant="negative" />
    <StatCard label="Net Worth" value="¥115,800" />
  </div>
  <FilterBar options={...} value={typeFilter} onChange={setTypeFilter} />
  {/* Search + archive toggle */}
  {/* Account group cards */}
  <AccountWizard />
  <DeleteAccountDialog />
  ...
</PageShell>
```

### Commit
```bash
git commit -m "feat(accounts): rewrite list page with YuCai card grid, StatCard summary, FilterBar"
```

---

## Task 2: Implement AccountDetailPage — Full Detail Page

**Files:** `src/pages/AccountDetailPage.tsx`

### What to build

Replace the placeholder with a full detail page. Move content from `AccountDetailPanel.tsx` into this route page.

### Page structure
```
<PageShell>
  <HeroCard icon={typeIcon} name={account.name} subtitle={account.institution}>
    {/* Balance display */}
    <div className="font-display text-4xl font-semibold">{balance}</div>
    <div className="text-xs text-muted-foreground">{t('accounts.currentBalance')}</div>
  </HeroCard>

  <div className="grid grid-cols-4 gap-3.5 mb-7">
    <StatCard label={t('accounts.initialBalance')} value={...} />
    <StatCard label={t('common.currency')} value={account.currency_code} />
    <StatCard label={t('accountForm.accountNumber')} value={account.account_number || '—'} />
    <StatCard label={t('accountForm.institution')} value={account.institution || '—'} />
  </div>

  <DetailTwoCol
    main={<TransactionSection />}
    side={<AccountInfoSidebar />}
  />
</PageShell>
```

### Data fetching
- Use `useParams` to get `accountId`
- Use `useQuery` with `getAccount(accountId)` to fetch account data
- Use `useQuery` with `getTransactionsByAccount(accountId)` for transactions
- Use `useAccountBalanceHistory` for the chart

### Key features to port from AccountDetailPanel
- Balance chart (DetailBalanceChart → keep but style with YuCai colors)
- Account type badge
- Account info fields (currency, initial balance, account number, institution)
- Transaction history list

### Additional features
- Edit button → navigate to `/accounts/$accountId/edit`
- Delete button → open DeleteAccountDialog
- Credit card specific: show credit limit, billing day, payment due day

### Commit
```bash
git commit -m "feat(accounts): implement full detail page with HeroCard, StatCards, DetailTwoCol"
```

---

## Task 3: Restyle Account Form Pages

**Files:** `src/pages/NewAccountPage.tsx`, `src/pages/AccountEditPage.tsx`

### Changes (minimal — styling only)

**NewAccountPage.tsx:**
- Replace outer div with `<PageShell narrow>`
- Replace header with `<PageHeader title={t('accounts.createAccount')} subtitle={...} />`
- Remove back button (breadcrumb handles navigation)
- Wrap AccountForm with `<FormCard>`
- Keep all mutation logic unchanged

**AccountEditPage.tsx:**
- Same pattern: `<PageShell narrow>` + `<PageHeader>` + `<FormCard>`
- Keep AccountChangesDialog unchanged
- Keep all mutation and change-tracking logic

### Commit
```bash
git commit -m "feat(accounts): restyle form pages with PageShell, PageHeader, FormCard patterns"
```

---

## Task 4: Clean Up and Verify

1. Remove `AccountDetailPanel.tsx` import from AccountsPage (already done in Task 1)
2. Run type-check
3. Verify navigation flow: list → click card → detail → edit → back to list → new
4. Commit any fixes

```bash
git commit -m "chore: clean up account module after P1 redesign"
```
