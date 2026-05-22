# Form UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign four form components for personal finance UX — amount-first transaction entry, minimal account creation, lump-sum/installment debt toggle, and currency form polish.

**Architecture:** Bottom-up — SimpleTransactionForm first (largest scope), then AccountForm, DebtForm, CurrencyForm. Each task is self-contained. All forms share the Stripe-inspired design tokens from the prior redesign (gradient buttons, rounded-2xl cards, uppercase labels).

**Tech Stack:** React 19, Tailwind CSS 3.4, react-hook-form + zod, Base UI Tabs, shadcn/ui Form components

---

### Task 1: SimpleTransactionForm — Extract Amount Above Tabs

**Files:**
- Modify: `src/components/SimpleTransactionForm.tsx`

**Goal:** Move the amount input out of TabsContent so it appears once above the tab selector, with large ¥ format and type-tinted background.

**Step 1: Read the full file**

Read `src/components/SimpleTransactionForm.tsx` completely. Understand the current structure: Tabs contain three TabsContent blocks (expense/income/transfer), each with a duplicated amount input.

**Step 2: Remove amount field from all three TabsContent blocks**

Find and remove each `<div className="space-y-2">` block containing the amount `<Input>` from inside all three `<TabsContent>` sections.

**Step 3: Add unified amount field above TabsList**

Insert the amount field between `<form>` and `<Tabs>`:

```tsx
{/* Amount — always visible, type-tinted background */}
<div className={cn(
  "rounded-xl border p-4 text-center",
  type === 'expense' && "bg-gradient-to-br from-red-50/50 to-card border-red-200/50 dark:from-red-950/20 dark:to-card dark:border-red-800/30",
  type === 'income' && "bg-gradient-to-br from-emerald-50/50 to-card border-emerald-200/50 dark:from-emerald-950/20 dark:to-card dark:border-emerald-800/30",
  type === 'transfer' && "bg-gradient-to-br from-blue-50/50 to-card border-blue-200/50 dark:from-blue-950/20 dark:to-card dark:border-blue-800/30",
)}>
  <div className="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2">
    {type === 'expense' ? t('transaction.amount') : type === 'income' ? t('transaction.amount') : t('transaction.amount')}
  </div>
  <div className="flex items-center justify-center gap-1">
    <span className="text-3xl font-bold text-foreground/80">¥</span>
    <input
      type="number"
      step="0.01"
      min="0.01"
      required
      value={amount}
      onChange={(e) => setAmount(e.target.value)}
      placeholder="0.00"
      className="w-40 bg-transparent text-center text-3xl font-bold outline-none [appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none"
    />
  </div>
</div>
```

**Step 4: Verify**

Run: `npx tsc --noEmit` (zero errors)
Run: `npx vitest run` (72 passed, 1 skipped)

**Step 5: Commit**

```bash
git add src/components/SimpleTransactionForm.tsx
git commit -m "feat(ui): extract amount field above tabs in SimpleTransactionForm

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 2: SimpleTransactionForm — Pill Type Toggle + Grid Layout

**Files:**
- Modify: `src/components/SimpleTransactionForm.tsx`

**Goal:** Replace full-width line Tabs with compact pill toggle. Arrange account/category/date in 2-column grids.

**Step 1: Replace TabsList with pill toggle**

Replace the `<TabsList variant="line" className="w-full">` block with a compact pill toggle:

```tsx
{/* Type selector — compact pill toggle */}
<div className="flex justify-center">
  <div className="inline-flex gap-1 rounded-full bg-muted p-1">
    {(['expense', 'income', 'transfer'] as const).map((t) => (
      <button
        key={t}
        type="button"
        onClick={() => setType(t)}
        className={cn(
          "rounded-full px-4 py-1.5 text-xs font-medium transition-all",
          type === t
            ? "bg-background text-foreground shadow-sm"
            : "text-muted-foreground hover:text-foreground"
        )}
      >
        {t === 'expense' ? t('transaction.expense') : t === 'income' ? t('transaction.income') : t('transaction.transfer')}
      </button>
    ))}
  </div>
</div>
```

Remove the entire `<Tabs>` wrapper, `<TabsList>`, `<TabsTrigger>` and `<TabsContent>` blocks. Replace with simple conditional rendering based on `type` state.

**Step 2: Render fields conditionally by type**

For expense/income (same structure):
```tsx
{type !== 'transfer' ? (
  <div className="grid grid-cols-2 gap-3">
    <div className="space-y-1.5">
      <Label className="text-xs uppercase tracking-wider text-muted-foreground">{t('transaction.account')}</Label>
      <Select value={accountId} onValueChange={setAccountId}>
        <SelectTrigger className="h-9"><SelectValue placeholder={t('transaction.selectAccount')} /></SelectTrigger>
        <SelectContent>{/* account options */}</SelectContent>
      </Select>
    </div>
    <div className="space-y-1.5">
      <Label className="text-xs uppercase tracking-wider text-muted-foreground">{t('transaction.category')}</Label>
      <Select value={categoryId} onValueChange={setCategoryId}>
        <SelectTrigger className="h-9"><SelectValue placeholder={t('transaction.selectCategory')} /></SelectTrigger>
        <SelectContent>{/* category options */}</SelectContent>
      </Select>
    </div>
  </div>
) : (
  <div className="grid grid-cols-2 gap-3">
    <div className="space-y-1.5">
      <Label className="text-xs uppercase tracking-wider text-muted-foreground">{t('transaction.fromAccount')}</Label>
      <Select value={fromAccountId} onValueChange={setFromAccountId}>
        <SelectTrigger className="h-9"><SelectValue placeholder={t('transaction.selectAccount')} /></SelectTrigger>
        <SelectContent>{/* account options */}</SelectContent>
      </Select>
    </div>
    <div className="space-y-1.5">
      <Label className="text-xs uppercase tracking-wider text-muted-foreground">{t('transaction.toAccount')}</Label>
      <Select value={toAccountId} onValueChange={setToAccountId}>
        <SelectTrigger className="h-9"><SelectValue placeholder={t('transaction.selectAccount')} /></SelectTrigger>
        <SelectContent>{/* account options filtered */}</SelectContent>
      </Select>
    </div>
  </div>
)}
```

**Step 3: Date + Note in 2-column grid**

```tsx
<div className="grid grid-cols-[120px_1fr] gap-3">
  <div className="space-y-1.5">
    <Label className="text-xs uppercase tracking-wider text-muted-foreground">{t('transaction.date')}</Label>
    <Input type="date" value={date} onChange={(e) => setDate(e.target.value)} className="h-9" required />
  </div>
  <div className="space-y-1.5">
    <Label className="text-xs uppercase tracking-wider text-muted-foreground">
      {t('transaction.description')}
      <span className="text-muted-foreground/50 font-normal"> — optional</span>
    </Label>
    <Input value={description} onChange={(e) => setDescription(e.target.value)} placeholder={t('transaction.descriptionPlaceholder')} className="h-9" />
  </div>
</div>
```

**Step 4: Context-aware CTA button**

```tsx
<Button type="submit" variant="default-gradient" className="w-full" disabled={isSubmitting}>
  {type === 'expense'
    ? `${t('transaction.recordExpense')} — ¥${amount || '0'}`
    : type === 'income'
    ? `${t('transaction.recordIncome')} — ¥${amount || '0'}`
    : `${t('transaction.recordTransfer')} — ¥${amount || '0'}`}
</Button>
```

**Step 5: Clean up imports**

Remove unused imports: `Tabs`, `TabsContent`, `TabsList`, `TabsTrigger` from `@/components/ui/tabs`.

**Step 6: Verify**

Run: `npx tsc --noEmit` (zero errors)
Run: `npx vitest run` (72 passed, 1 skipped)

**Step 7: Commit**

```bash
git add src/components/SimpleTransactionForm.tsx
git commit -m "feat(ui): redesign SimpleTransactionForm with pill toggle, grid layout, context-aware CTA

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 3: AccountForm — Core Fields + Expandable Advanced

**Files:**
- Modify: `src/components/AccountForm.tsx`

**Goal:** Show 3 core fields always (Name, Type, Balance). Move 5 advanced fields behind expandable section. Add ¥ prefix to balance input.

**Step 1: Read the file**

Read `src/components/AccountForm.tsx` to understand current field order and structure.

**Step 2: Reorder fields — 3-core grid first**

Restructure the form JSX so core fields appear first in a compact layout:

```tsx
{/* Core fields */}
<div className="space-y-4">
  <FormField name="name" render={({ field }) => (
    <FormItem>
      <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
        {t('accountForm.name')} <span className="text-red-500">*</span>
      </FormLabel>
      <FormControl><Input placeholder={t('accountForm.namePlaceholder')} className="h-9" {...field} /></FormControl>
      <FormMessage />
    </FormItem>
  )} />

  <div className="grid grid-cols-2 gap-3">
    <FormField name="account_type" render={({ field }) => (
      <FormItem>
        <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
          {t('accountForm.accountType')} <span className="text-red-500">*</span>
        </FormLabel>
        <Select value={field.value} onValueChange={field.onChange}>
          <FormControl><SelectTrigger className="h-9"><SelectValue /></SelectTrigger></FormControl>
          <SelectContent>
            {(['Cash', 'Bank', 'CreditCard', 'Investment', 'Loan', 'Other'] as const).map((type) => (
              <SelectItem key={type} value={type}>{t(`accountForm.types.${type}`)}</SelectItem>
            ))}
          </SelectContent>
        </Select>
        <FormMessage />
      </FormItem>
    )} />

    <FormField name="initial_balance" render={({ field }) => (
      <FormItem>
        <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
          {t('accountForm.initialBalance')}
        </FormLabel>
        <FormControl>
          <div className="flex items-center rounded-lg border overflow-hidden h-9">
            <span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-r">¥</span>
            <input className="flex-1 border-0 bg-transparent px-2.5 text-sm outline-none" placeholder="0.00" {...field} />
          </div>
        </FormControl>
        <FormMessage />
      </FormItem>
    )} />
  </div>
</div>
```

**Step 3: Add expandable advanced section**

Wrap remaining fields (currency_code, account_number, institution, credit_limit, billing_day, payment_due_day, interest_rate) in a collapsible section:

```tsx
{/* Advanced fields — expandable */}
<details className="border-t pt-4">
  <summary className="text-xs font-medium text-primary cursor-pointer hover:text-primary/80">
    {t('accountForm.advancedOptions')}
  </summary>
  <div className="space-y-4 mt-4">
    {/* currency_code field */}
    <FormField name="currency_code" render={({ field }) => (
      <FormItem>
        <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
          {t('accountForm.currency')}
          <span className="text-muted-foreground/50 font-normal"> — optional</span>
        </FormLabel>
        <Select value={field.value} onValueChange={field.onChange}>
          <FormControl><SelectTrigger className="h-9"><SelectValue /></SelectTrigger></FormControl>
          <SelectContent>
            <SelectItem value="CNY">CNY (¥)</SelectItem>
            <SelectItem value="USD">USD ($)</SelectItem>
            <SelectItem value="EUR">EUR (€)</SelectItem>
          </SelectContent>
        </Select>
        <FormMessage />
      </FormItem>
    )} />

    <div className="grid grid-cols-2 gap-3">
      <FormField name="account_number" render={({ field }) => (
        <FormItem>
          <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
            {t('accountForm.accountNumber')}
            <span className="text-muted-foreground/50 font-normal"> — optional</span>
          </FormLabel>
          <FormControl><Input placeholder={t('accountForm.accountNumberPlaceholder')} className="h-9" {...field} /></FormControl>
          <FormMessage />
        </FormItem>
      )} />
      <FormField name="institution" render={({ field }) => (
        <FormItem>
          <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
            {t('accountForm.institution')}
            <span className="text-muted-foreground/50 font-normal"> — optional</span>
          </FormLabel>
          <FormControl><Input placeholder={t('accountForm.institutionPlaceholder')} className="h-9" {...field} /></FormControl>
          <FormMessage />
        </FormItem>
      )} />
    </div>

    {/* Conditional credit card fields */}
    {accountType === 'CreditCard' && (
      <div className="rounded-lg border border-blue-200/50 bg-gradient-to-br from-blue-50/50 to-card p-4 dark:from-blue-950/20 dark:to-card dark:border-blue-800/30">
        <div className="text-xs font-medium text-blue-600 dark:text-blue-400 uppercase tracking-wider mb-3">
          {t('accountForm.creditCardDetails')}
        </div>
        <div className="grid grid-cols-3 gap-3">
          <FormField name="credit_limit" render={({ field }) => (
            <FormItem>
              <FormLabel className="text-xs text-muted-foreground">{t('accountForm.creditLimit')}</FormLabel>
              <FormControl><Input type="number" placeholder="50000" className="h-9" {...field} /></FormControl>
              <FormMessage />
            </FormItem>
          )} />
          <FormField name="billing_day" render={({ field }) => (
            <FormItem>
              <FormLabel className="text-xs text-muted-foreground">{t('accountForm.billingDay')}</FormLabel>
              <FormControl><Input type="number" min={1} max={31} placeholder="5" className="h-9" {...field} /></FormControl>
              <FormMessage />
            </FormItem>
          )} />
          <FormField name="payment_due_day" render={({ field }) => (
            <FormItem>
              <FormLabel className="text-xs text-muted-foreground">{t('accountForm.paymentDueDay')}</FormLabel>
              <FormControl><Input type="number" min={1} max={31} placeholder="25" className="h-9" {...field} /></FormControl>
              <FormMessage />
            </FormItem>
          )} />
        </div>
      </div>
    )}

    {/* Conditional loan field */}
    {accountType === 'Loan' && (
      <FormField name="interest_rate" render={({ field }) => (
        <FormItem>
          <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">{t('accountForm.interestRate')}</FormLabel>
          <FormControl>
            <div className="flex items-center rounded-lg border overflow-hidden h-9">
              <input className="flex-1 border-0 bg-transparent px-2.5 text-sm outline-none" placeholder="5.5" {...field} />
              <span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-l">%</span>
            </div>
          </FormControl>
          <FormMessage />
        </FormItem>
      )} />
    )}
  </div>
</details>
```

**Step 4: Update button row**

Change the submit button to `variant="default-gradient"` and ensure it uses the gradient from the earlier redesign:

```tsx
<Button type="submit" variant="default-gradient" disabled={isSubmitting}>
  {isSubmitting ? t('common.creating') : t('accountForm.createAccount')}
</Button>
```

**Step 5: Verify**

Run: `npx tsc --noEmit` (zero errors)
Run: `npx vitest run` (72 passed, 1 skipped)

**Step 6: Commit**

```bash
git add src/components/AccountForm.tsx
git commit -m "feat(ui): redesign AccountForm with core fields + expandable advanced section

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 4: DebtForm — Lump Sum vs Installment Toggle

**Files:**
- Modify: `src/components/DebtForm.tsx`

**Goal:** Add repayment mode toggle (Lump Sum | Installment). Lump Sum shows due date + simple total. Installment shows periods + start date + amortization method + collapsible schedule.

**Step 1: Read the file**

Read `src/components/DebtForm.tsx` to understand current field structure and the payment schedule calculation logic.

**Step 2: Add repayment_mode state and toggle UI**

Add a `repaymentMode` state:
```tsx
const [repaymentMode, setRepaymentMode] = useState<'lump_sum' | 'installment'>('lump_sum');
```

Add the toggle at the top of the form:
```tsx
{/* Repayment mode toggle */}
<div className="flex justify-center">
  <div className="inline-flex gap-1 rounded-full bg-muted p-1">
    <button
      type="button"
      onClick={() => setRepaymentMode('lump_sum')}
      className={cn(
        "rounded-full px-4 py-1.5 text-xs font-medium transition-all",
        repaymentMode === 'lump_sum'
          ? "bg-background text-foreground shadow-sm"
          : "text-muted-foreground hover:text-foreground"
      )}
    >
      {t('debtForm.lumpSum')}
    </button>
    <button
      type="button"
      onClick={() => setRepaymentMode('installment')}
      className={cn(
        "rounded-full px-4 py-1.5 text-xs font-medium transition-all",
        repaymentMode === 'installment'
          ? "bg-background text-foreground shadow-sm"
          : "text-muted-foreground hover:text-foreground"
      )}
    >
      {t('debtForm.installment')}
    </button>
  </div>
</div>
```

**Step 3: Restructure fields with 2-column grid for common fields**

```tsx
<div className="grid grid-cols-2 gap-3">
  <FormField name="debt_type" render={({ field }) => (
    <FormItem>
      <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
        {t('debtForm.type')} <span className="text-red-500">*</span>
      </FormLabel>
      <Select value={field.value} onValueChange={field.onChange}>
        <FormControl><SelectTrigger className="h-9"><SelectValue /></SelectTrigger></FormControl>
        <SelectContent>
          <SelectItem value="BorrowedIn">{t('debtForm.borrowedIn')}</SelectItem>
          <SelectItem value="BorrowedOut">{t('debtForm.borrowedOut')}</SelectItem>
        </SelectContent>
      </Select>
      <FormMessage />
    </FormItem>
  )} />
  <FormField name="counterparty" render={({ field }) => (
    <FormItem>
      <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
        {t('debtForm.counterparty')} <span className="text-red-500">*</span>
      </FormLabel>
      <FormControl><Input placeholder={t('debtForm.counterpartyPlaceholder')} className="h-9" {...field} /></FormControl>
      <FormMessage />
    </FormItem>
  )} />
</div>
```

**Step 4: Principal + Rate in 3-column with mode-dependent third field**

```tsx
<div className="grid grid-cols-3 gap-3">
  <FormField name="principal_amount" render={({ field }) => (
    <FormItem>
      <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
        {t('debtForm.principal')} <span className="text-red-500">*</span>
      </FormLabel>
      <FormControl>
        <div className="flex items-center rounded-lg border overflow-hidden h-9">
          <span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-r">¥</span>
          <input className="flex-1 border-0 bg-transparent px-2.5 text-sm outline-none" placeholder="100,000" {...field} />
        </div>
      </FormControl>
      <FormMessage />
    </FormItem>
  )} />
  <FormField name="interest_rate" render={({ field }) => (
    <FormItem>
      <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
        {t('debtForm.interestRate')}
      </FormLabel>
      <FormControl>
        <div className="flex items-center rounded-lg border overflow-hidden h-9">
          <input className="flex-1 border-0 bg-transparent px-2.5 text-sm outline-none" placeholder="5.5" {...field} />
          <span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-l">%</span>
        </div>
      </FormControl>
      <FormMessage />
    </FormItem>
  )} />

  {repaymentMode === 'lump_sum' ? (
    <FormField name="due_date" render={({ field }) => (
      <FormItem>
        <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
          {t('debtForm.dueDate')} <span className="text-red-500">*</span>
        </FormLabel>
        <FormControl><Input type="date" className="h-9" {...field} /></FormControl>
        <FormMessage />
      </FormItem>
    )} />
  ) : (
    <FormField name="periods" render={({ field }) => (
      <FormItem>
        <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
          {t('debtForm.periods')} <span className="text-red-500">*</span>
        </FormLabel>
        <Select value={field.value?.toString()} onValueChange={(v) => field.onChange(parseInt(v))}>
          <FormControl><SelectTrigger className="h-9"><SelectValue /></SelectTrigger></FormControl>
          <SelectContent>
            {[3, 6, 12, 24, 36, 60].map((n) => (
              <SelectItem key={n} value={n.toString()}>{n} {t('debtForm.months')}</SelectItem>
            ))}
          </SelectContent>
        </Select>
        <FormMessage />
      </FormItem>
    )} />
  )}
</div>
```

**Step 5: Installment-only fields (start date + amortization method)**

Conditionally render only when `repaymentMode === 'installment'`:

```tsx
{repaymentMode === 'installment' && (
  <div className="grid grid-cols-2 gap-3">
    <FormField name="start_date" render={({ field }) => (
      <FormItem>
        <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
          {t('debtForm.startDate')}
        </FormLabel>
        <FormControl><Input type="date" className="h-9" {...field} /></FormControl>
        <FormMessage />
      </FormItem>
    )} />
    <FormField name="amortization_method" render={({ field }) => (
      <FormItem>
        <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
          {t('debtForm.amortizationMethod')}
        </FormLabel>
        <Select value={field.value} onValueChange={field.onChange}>
          <FormControl><SelectTrigger className="h-9"><SelectValue /></SelectTrigger></FormControl>
          <SelectContent>
            <SelectItem value="EqualPrincipalInterest">{t('debtForm.equalPI')}</SelectItem>
            <SelectItem value="EqualPrincipal">{t('debtForm.equalPrincipal')}</SelectItem>
          </SelectContent>
        </Select>
        <FormMessage />
      </FormItem>
    )} />
  </div>
)}
```

**Step 6: Replace large payment schedule table with compact summary**

Lump Sum summary:
```tsx
{repaymentMode === 'lump_sum' && principal && interestRate && (
  <div className="rounded-xl border border-blue-200/50 bg-gradient-to-br from-blue-50/50 to-card p-4 flex items-center justify-between dark:from-blue-950/20 dark:to-card dark:border-blue-800/30">
    <div>
      <div className="text-xs text-muted-foreground">{t('debtForm.repaymentOnDueDate')}</div>
      <div className="text-xl font-bold">¥{totalRepayment.toLocaleString()}</div>
    </div>
    <div className="text-right text-xs space-y-1">
      <div className="text-muted-foreground">{t('debtForm.principal')}: ¥{principal.toLocaleString()}</div>
      <div className="text-muted-foreground">{t('debtForm.interest')} ({interestRate}%): +¥{totalInterest.toLocaleString()}</div>
    </div>
  </div>
)}
```

Installment summary:
```tsx
{repaymentMode === 'installment' && schedule.length > 0 && (
  <div className="rounded-xl border border-emerald-200/50 bg-gradient-to-br from-emerald-50/50 to-card p-4 dark:from-emerald-950/20 dark:to-card dark:border-emerald-800/30">
    <div className="flex items-center justify-between mb-2">
      <span className="text-xs font-medium text-emerald-700 dark:text-emerald-400">{t('debtForm.monthlyPayment')}</span>
      <span className="text-xl font-bold text-emerald-700 dark:text-emerald-400">¥{monthlyPayment.toLocaleString()}</span>
    </div>
    <div className="flex justify-between text-xs text-muted-foreground">
      <span>{schedule.length} {t('debtForm.payments')}</span>
      <span>{t('debtForm.totalInterest')}: ¥{totalInterest.toLocaleString()}</span>
    </div>
    <details className="mt-3">
      <summary className="text-xs text-primary cursor-pointer">{t('debtForm.viewSchedule')}</summary>
      <div className="max-h-40 overflow-y-auto mt-2">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>#</TableHead>
              <TableHead>{t('debtForm.date')}</TableHead>
              <TableHead className="text-right">{t('debtForm.payment')}</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {schedule.map((payment, i) => (
              <TableRow key={i}>
                <TableCell className="text-xs">{i + 1}</TableCell>
                <TableCell className="text-xs">{payment.date}</TableCell>
                <TableCell className="text-xs text-right font-medium">¥{payment.total.toLocaleString()}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>
    </details>
  </div>
)}
```

**Step 7: Update button to gradient**

```tsx
<Button type="submit" variant="default-gradient" disabled={isSubmitting}>
  {isSubmitting ? t('common.creating') : t('debtForm.createDebt')}
</Button>
```

**Step 8: Verify**

Run: `npx tsc --noEmit` (zero errors)
Run: `npx vitest run` (72 passed, 1 skipped)

**Step 9: Commit**

```bash
git add src/components/DebtForm.tsx
git commit -m "feat(ui): redesign DebtForm with lump sum vs installment toggle, compact summary

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 5: CurrencyForm — Minor Polish

**Files:**
- Modify: `src/components/CurrencyForm.tsx`

**Goal:** CSS uppercase on code input (eliminates flicker), `type="number"` on exchange rate, placeholder with context.

**Step 1: Read the file**

Read `src/components/CurrencyForm.tsx`.

**Step 2: Add CSS uppercase to code field**

Find the code input's `<Input>` component and add `className="uppercase"`:

```tsx
<FormControl>
  <Input
    maxLength={3}
    placeholder="CNY"
    className="uppercase"
    {...field}
    onChange={(e) => field.onChange(e.target.value.toUpperCase())}
  />
</FormControl>
```

**Step 3: Change exchange_rate input to type="number"**

Find the exchange_rate `<Input>` and change to:

```tsx
<FormControl>
  <Input
    type="number"
    step="0.0001"
    min="0"
    placeholder={t('currencyForm.exchangeRatePlaceholder')}
    {...field}
  />
</FormControl>
```

**Step 4: Update button to gradient**

```tsx
<Button type="submit" variant="default-gradient" disabled={isSubmitting}>
  {isSubmitting ? t('common.saving') : t('currencyForm.addCurrency')}
</Button>
```

**Step 5: Verify**

Run: `npx tsc --noEmit` (zero errors)
Run: `npx vitest run` (72 passed, 1 skipped)

**Step 6: Commit**

```bash
git add src/components/CurrencyForm.tsx
git commit -m "feat(ui): polish CurrencyForm — CSS uppercase, number input, gradient button

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 6: Add Missing i18n Keys

**Files:**
- Modify: `src/i18n/locales/en.json`
- Modify: `src/i18n/locales/zh.json`

**Goal:** Add translation keys needed by the redesigned forms (repayment mode, advanced options toggle, etc.).

**Step 1: Find i18n files**

Run: `find src -name "*.json" -path "*/locales/*"`

**Step 2: Add English keys**

In `en.json`, add under appropriate sections:

```json
"debtForm": {
  "lumpSum": "Lump Sum",
  "installment": "Installment",
  "repaymentOnDueDate": "Repayment on due date",
  "monthlyPayment": "Monthly Payment",
  "payments": "payments",
  "viewSchedule": "View payment schedule",
  "periods": "Periods",
  "months": "months"
},
"accountForm": {
  "advancedOptions": "+ Advanced: currency, account number, credit limit...",
  "creditCardDetails": "Credit Card Details",
  "namePlaceholder": "e.g. Main Checking",
  "accountNumberPlaceholder": "Last 4 digits",
  "institutionPlaceholder": "Bank name"
},
"currencyForm": {
  "exchangeRatePlaceholder": "Rate vs CNY"
},
"transaction": {
  "recordExpense": "Record Expense",
  "recordIncome": "Record Income",
  "recordTransfer": "Record Transfer",
  "descriptionPlaceholder": "Add a note..."
}
```

**Step 3: Add Chinese keys**

In `zh.json`, add corresponding translations:

```json
"debtForm": {
  "lumpSum": "一次性还本付息",
  "installment": "分期偿还",
  "repaymentOnDueDate": "到期还款金额",
  "monthlyPayment": "月还款额",
  "payments": "期",
  "viewSchedule": "查看还款计划",
  "periods": "期数",
  "months": "个月"
},
"accountForm": {
  "advancedOptions": "+ 高级选项：币种、账号、信用卡额度...",
  "creditCardDetails": "信用卡详情",
  "namePlaceholder": "例如：工资卡",
  "accountNumberPlaceholder": "后4位",
  "institutionPlaceholder": "银行名称"
},
"currencyForm": {
  "exchangeRatePlaceholder": "对人民币汇率"
},
"transaction": {
  "recordExpense": "记录支出",
  "recordIncome": "记录收入",
  "recordTransfer": "记录转账",
  "descriptionPlaceholder": "添加备注..."
}
```

**Step 4: Verify**

Run: `npx tsc --noEmit` (zero errors, JSON files not type-checked)

**Step 5: Commit**

```bash
git add src/i18n/locales/en.json src/i18n/locales/zh.json
git commit -m "feat(i18n): add translation keys for redesigned forms

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 7: Final Integration Verification

**Files:** None (verification only)

**Step 1: Run full test suite**

```bash
npx vitest run
```
Expected: 72 passed, 1 skipped

**Step 2: Run TypeScript check**

```bash
npx tsc --noEmit
```
Expected: zero errors

**Step 3: Run production build**

```bash
npx vite build
```
Expected: builds successfully

**Step 4: Commit**

```bash
git commit -m "chore: final integration verification — all tests pass

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```
