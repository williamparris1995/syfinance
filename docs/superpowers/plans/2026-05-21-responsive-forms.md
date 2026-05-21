# Responsive Forms Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Dialog-based forms with responsive Sheet (wide) / standalone page (narrow) pattern using shadcn components.

**Architecture:** A `useMediaQuery` hook detects viewport width. Each list page uses the existing `Sheet` component to slide forms in from the right on wide screens (>=1024px), and `useNavigate` to go to a dedicated child route on narrow screens. Three new standalone pages serve as the narrow-screen targets.

**Tech Stack:** React, @tanstack/react-router, @base-ui/react (Sheet), Tailwind CSS, react-hook-form + zod

---

## File Structure

```
src/
  hooks/
    useMediaQuery.ts          — NEW: SSR-safe media query hook
  pages/
    TransactionsPage.tsx       — MODIFY: Sheet + route pattern
    AccountsPage.tsx           — MODIFY: Sheet + route pattern
    DebtsPage.tsx              — MODIFY: Sheet + route pattern
    SettingsPage.tsx           — MODIFY: Sheet + route pattern (currency form only)
    NewTransactionPage.tsx     — NEW: standalone form page for narrow screens
    NewAccountPage.tsx         — NEW: standalone form page for narrow screens
    NewDebtPage.tsx            — NEW: standalone form page for narrow screens
  router.tsx                   — MODIFY: add child routes
```

---

### Task 1: Create `useMediaQuery` hook

**Files:**
- Create: `src/hooks/useMediaQuery.ts`

- [ ] **Step 1: Write the hook**

```typescript
import { useEffect, useState } from 'react';

export function useMediaQuery(query: string): boolean {
  const [matches, setMatches] = useState(() => {
    if (typeof window !== 'undefined') {
      return window.matchMedia(query).matches;
    }
    return false;
  });

  useEffect(() => {
    const mql = window.matchMedia(query);
    const handler = (e: MediaQueryListEvent) => setMatches(e.matches);
    mql.addEventListener('change', handler);
    setMatches(mql.matches);
    return () => mql.removeEventListener('change', handler);
  }, [query]);

  return matches;
}
```

- [ ] **Step 2: Commit**

```bash
git add src/hooks/useMediaQuery.ts
git commit -m "feat: add useMediaQuery hook for responsive breakpoint detection"
```

---

### Task 2: Add child routes and new standalone pages

**Files:**
- Modify: `src/router.tsx`
- Create: `src/pages/NewTransactionPage.tsx`
- Create: `src/pages/NewAccountPage.tsx`
- Create: `src/pages/NewDebtPage.tsx`

- [ ] **Step 1: Create NewTransactionPage**

```typescript
import { useNavigate } from '@tanstack/react-router';
import { ArrowLeft } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { SimpleTransactionForm, TransactionFormData } from '@/components/SimpleTransactionForm';
import { Button } from '@/components/ui/button';
import { listAccounts } from '@/lib/tauri/account';
import { listCategories } from '@/lib/tauri/category';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

export function NewTransactionPage() {
  const navigate = useNavigate();
  const { t } = useTranslation();
  const queryClient = useQueryClient();

  const { data: accounts = [] } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
  });

  const { data: categories = [] } = useQuery({
    queryKey: ['categories'],
    queryFn: listCategories,
  });

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <div className="flex items-center gap-4 mb-6">
        <Button variant="ghost" size="icon" onClick={() => navigate({ to: '/transactions' })}>
          <ArrowLeft className="h-5 w-5" />
        </Button>
        <h1 className="text-2xl font-bold">{t('transactions.recordTransaction')}</h1>
      </div>
      <SimpleTransactionForm
        accounts={accounts}
        categories={categories}
        onSubmit={async (data: TransactionFormData) => {
          navigate({ to: '/transactions' });
          queryClient.invalidateQueries({ queryKey: ['transactions'] });
          queryClient.invalidateQueries({ queryKey: ['accounts'] });
          toast.success(t('transactions.recorded'));
        }}
        onCancel={() => navigate({ to: '/transactions' })}
      />
    </div>
  );
}
```

- [ ] **Step 2: Create NewAccountPage**

```typescript
import { useNavigate } from '@tanstack/react-router';
import { ArrowLeft } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { AccountForm } from '@/components/AccountForm';
import { Button } from '@/components/ui/button';
import { createAccount, type CreateAccountDto } from '@/lib/tauri/account';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { getUserFriendlyError } from '@/lib/error-handler';

export function NewAccountPage() {
  const navigate = useNavigate();
  const { t } = useTranslation();
  const queryClient = useQueryClient();

  const createMutation = useMutation({
    mutationFn: createAccount,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      navigate({ to: '/accounts' });
      toast.success(t('accounts.accountCreated'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <div className="flex items-center gap-4 mb-6">
        <Button variant="ghost" size="icon" onClick={() => navigate({ to: '/accounts' })}>
          <ArrowLeft className="h-5 w-5" />
        </Button>
        <h1 className="text-2xl font-bold">{t('accounts.createAccount')}</h1>
      </div>
      <AccountForm
        onSubmit={(data: CreateAccountDto) => createMutation.mutate(data)}
        onCancel={() => navigate({ to: '/accounts' })}
        isLoading={createMutation.isPending}
      />
    </div>
  );
}
```

- [ ] **Step 3: Create NewDebtPage**

```typescript
import { useNavigate } from '@tanstack/react-router';
import { ArrowLeft } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { DebtForm } from '@/components/DebtForm';
import { Button } from '@/components/ui/button';
import { createDebt, type CreateDebtDto } from '@/lib/tauri/debt';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { getUserFriendlyError } from '@/lib/error-handler';

export function NewDebtPage() {
  const navigate = useNavigate();
  const { t } = useTranslation();
  const queryClient = useQueryClient();

  const createMutation = useMutation({
    mutationFn: createDebt,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['debts'] });
      queryClient.invalidateQueries({ queryKey: ['upcoming-payments'] });
      navigate({ to: '/debts' });
      toast.success(t('debts.debtCreated'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <div className="flex items-center gap-4 mb-6">
        <Button variant="ghost" size="icon" onClick={() => navigate({ to: '/debts' })}>
          <ArrowLeft className="h-5 w-5" />
        </Button>
        <h1 className="text-2xl font-bold">{t('debts.createDebt')}</h1>
      </div>
      <DebtForm
        onSubmit={(data: CreateDebtDto) => createMutation.mutate(data)}
        onCancel={() => navigate({ to: '/debts' })}
        isLoading={createMutation.isPending}
      />
    </div>
  );
}
```

- [ ] **Step 4: Update router.tsx — add child routes**

In `src/router.tsx`, add imports for the new pages and child routes:

Add imports at top:
```typescript
import { NewTransactionPage } from './pages/NewTransactionPage';
import { NewAccountPage } from './pages/NewAccountPage';
import { NewDebtPage } from './pages/NewDebtPage';
```

Add child routes after each existing route definition. For transactions:
```typescript
const newTransactionRoute = createRoute({
  getParentRoute: () => transactionsRoute,
  path: 'new',
  component: NewTransactionPage,
});
```

For accounts:
```typescript
const newAccountRoute = createRoute({
  getParentRoute: () => accountsRoute,
  path: 'new',
  component: NewAccountPage,
});
```

For debts:
```typescript
const newDebtRoute = createRoute({
  getParentRoute: () => debtsRoute,
  path: 'new',
  component: NewDebtPage,
});
```

Update `routeTree` to add children to the parent routes:
```typescript
const routeTree = rootRoute.addChildren([
  homeRoute,
  accountsRoute.addChildren([newAccountRoute]),
  transactionsRoute.addChildren([newTransactionRoute]),
  debtsRoute.addChildren([newDebtRoute]),
  reportsRoute,
  settingsRoute,
  onboardingRoute,
]);
```

- [ ] **Step 5: Commit**

```bash
git add src/hooks/ src/pages/NewTransactionPage.tsx src/pages/NewAccountPage.tsx src/pages/NewDebtPage.tsx src/router.tsx
git commit -m "feat: add responsive form pages and child routes"
```

---

### Task 3: Update TransactionsPage — Sheet + route pattern, merge two buttons

**Files:**
- Modify: `src/pages/TransactionsPage.tsx`

- [ ] **Step 1: Rewrite TransactionsPage to use Sheet/route and single button**

Replace the current `TransactionsPage.tsx`. Key changes:
- Remove `Dialog` imports for the quick/advanced forms, add `Sheet` imports
- Remove the old `TransactionForm` import (keep only `SimpleTransactionForm`)
- Add `useMediaQuery` and `useNavigate` imports
- Replace two buttons ("Record Transaction" + "Advanced") with single "Add Transaction" button
- On click: wide screen opens Sheet, narrow screen navigates to `/transactions/new`
- Remove the advanced `TransactionForm` dialog entirely

```typescript
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { toast } from 'sonner';
import { useTranslation } from 'react-i18next';
import { useNavigate } from '@tanstack/react-router';
import { SimpleTransactionForm, TransactionFormData } from '../components/SimpleTransactionForm';
import { Button } from '../components/ui/button';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from '../components/ui/sheet';
import { Input } from '../components/ui/input';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '../components/ui/table';
import { Plus } from 'lucide-react';
import { listAccounts } from '../lib/tauri/account';
import { listCategories } from '../lib/tauri/category';
import {
  listTransactions,
  getTransactionsByDateRange,
  type TransactionDto,
} from '../lib/tauri/transaction';
import { useMediaQuery } from '../hooks/useMediaQuery';

export function TransactionsPage() {
  const [isSheetOpen, setIsSheetOpen] = useState(false);
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  const navigate = useNavigate();
  const isWide = useMediaQuery('(min-width: 1024px)');

  const { data: accounts = [] } = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
  });

  const { data: categories = [] } = useQuery({
    queryKey: ['categories'],
    queryFn: listCategories,
  });

  const { data: transactions = [], isLoading } = useQuery({
    queryKey: ['transactions', startDate, endDate],
    queryFn: async () => {
      if (startDate && endDate) {
        return getTransactionsByDateRange(startDate, endDate);
      }
      return listTransactions();
    },
  });

  const handleAddClick = () => {
    if (isWide) {
      setIsSheetOpen(true);
    } else {
      navigate({ to: '/transactions/new' });
    }
  };

  const handleFormSubmit = async (data: TransactionFormData) => {
    setIsSheetOpen(false);
    queryClient.invalidateQueries({ queryKey: ['transactions'] });
    queryClient.invalidateQueries({ queryKey: ['accounts'] });
    toast.success(t('transactions.recorded'));
  };

  const getAccountName = (accountId: string) => {
    const account = accounts.find((a) => a.id === accountId);
    return account ? account.name : accountId;
  };

  const getTransactionAmount = (transaction: TransactionDto) => {
    let total = 0;
    transaction.entries.forEach((entry) => {
      if (entry.debit_amount) {
        total += parseFloat(entry.debit_amount);
      }
    });
    return total;
  };

  const getTransactionAccounts = (transaction: TransactionDto) => {
    const accountNames = transaction.entries.map((entry) => getAccountName(entry.account_id));
    return [...new Set(accountNames)].join(', ');
  };

  const handleClearFilters = () => {
    setStartDate('');
    setEndDate('');
  };

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">{t('transactions.title')}</h1>
        <Button onClick={handleAddClick}>
          <Plus className="mr-2 h-4 w-4" />
          {t('transactions.recordTransaction')}
        </Button>
      </div>

      {/* Date filters — unchanged */}
      <div className="flex gap-4 mb-6">
        <div className="flex items-center gap-2">
          <label htmlFor="start-date" className="text-sm font-medium">
            {t('transactions.from')}
          </label>
          <Input
            id="start-date"
            type="date"
            value={startDate}
            onChange={(e) => setStartDate(e.target.value)}
            className="w-40"
          />
        </div>
        <div className="flex items-center gap-2">
          <label htmlFor="end-date" className="text-sm font-medium">
            {t('transactions.to')}
          </label>
          <Input
            id="end-date"
            type="date"
            value={endDate}
            onChange={(e) => setEndDate(e.target.value)}
            className="w-40"
          />
        </div>
        {(startDate || endDate) && (
          <Button variant="outline" onClick={handleClearFilters}>
            {t('transactions.clearFilters')}
          </Button>
        )}
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center py-12">
          <div className="text-neutral-500">{t('transactions.loadingTransactions')}</div>
        </div>
      ) : transactions.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <p className="text-neutral-500 mb-4">
            {startDate || endDate ? t('transactions.noTransactionsInRange') : t('transactions.noTransactions')}
          </p>
          <Button onClick={handleAddClick}>{t('transactions.recordFirst')}</Button>
        </div>
      ) : (
        <div className="border rounded-lg">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t('common.date')}</TableHead>
                <TableHead>{t('common.description')}</TableHead>
                <TableHead className="text-right">{t('common.amount')}</TableHead>
                <TableHead>{t('transactions.accounts')}</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {transactions.map((transaction: TransactionDto) => (
                <TableRow key={transaction.id}>
                  <TableCell className="font-medium">
                    {new Date(transaction.transaction_date).toLocaleDateString('en-US', {
                      year: 'numeric',
                      month: 'short',
                      day: 'numeric',
                    })}
                  </TableCell>
                  <TableCell>{transaction.description}</TableCell>
                  <TableCell className="text-right">
                    {getTransactionAmount(transaction).toLocaleString('en-US', {
                      minimumFractionDigits: 2,
                      maximumFractionDigits: 2,
                    })}
                  </TableCell>
                  <TableCell className="text-neutral-600">
                    {getTransactionAccounts(transaction)}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}

      {/* Sheet for wide screens */}
      <Sheet open={isSheetOpen} onOpenChange={setIsSheetOpen}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>{t('transactions.recordTransaction')}</SheetTitle>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto -mx-4 px-4">
            <SimpleTransactionForm
              accounts={accounts}
              categories={categories}
              onSubmit={handleFormSubmit}
              onCancel={() => setIsSheetOpen(false)}
            />
          </div>
        </SheetContent>
      </Sheet>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add src/pages/TransactionsPage.tsx
git commit -m "feat: replace transaction dialogs with Sheet + route pattern"
```

---

### Task 4: Update AccountsPage — Sheet + route pattern

**Files:**
- Modify: `src/pages/AccountsPage.tsx`

- [ ] **Step 1: Replace Dialog with Sheet/route**

Remove `Dialog` imports, add `Sheet` and `useMediaQuery` + `useNavigate`. Replace the "Create Account" button handler and the Dialog with a Sheet.

The key changes to `AccountsPage.tsx`:

```typescript
// Add imports:
import { useNavigate } from '@tanstack/react-router';
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '../components/ui/sheet';
import { useMediaQuery } from '../hooks/useMediaQuery';

// Inside component, replace:
// const [isCreateDialogOpen, setIsCreateDialogOpen] = useState(false);
// With:
const [isSheetOpen, setIsSheetOpen] = useState(false);
const navigate = useNavigate();
const isWide = useMediaQuery('(min-width: 1024px)');

// Replace button onClick:
// onClick={() => setIsCreateDialogOpen(true)}
// With:
const handleCreateClick = () => {
  if (isWide) setIsSheetOpen(true);
  else navigate({ to: '/accounts/new' });
};

// Replace Dialog with Sheet:
<Sheet open={isSheetOpen} onOpenChange={setIsSheetOpen}>
  <SheetContent side="right" className="w-full sm:max-w-lg">
    <SheetHeader>
      <SheetTitle>{t('accounts.createAccount')}</SheetTitle>
    </SheetHeader>
    <div className="flex-1 overflow-y-auto -mx-4 px-4">
      <AccountForm
        onSubmit={handleCreateAccount}
        onCancel={() => setIsSheetOpen(false)}
        isLoading={createMutation.isPending}
      />
    </div>
  </SheetContent>
</Sheet>
```

- [ ] **Step 2: Commit**

```bash
git add src/pages/AccountsPage.tsx
git commit -m "feat: replace account dialog with Sheet + route pattern"
```

---

### Task 5: Update DebtsPage — Sheet + route pattern

**Files:**
- Modify: `src/pages/DebtsPage.tsx`

- [ ] **Step 1: Replace Dialog with Sheet/route**

Same pattern as AccountsPage. Replace the create debt `Dialog` with `Sheet` + `useMediaQuery` + `useNavigate`.

Key changes:
```typescript
// Add imports:
import { useNavigate } from '@tanstack/react-router';
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '../components/ui/sheet';
import { useMediaQuery } from '../hooks/useMediaQuery';

// Replace dialog state with sheet state:
const [isSheetOpen, setIsSheetOpen] = useState(false);
const navigate = useNavigate();
const isWide = useMediaQuery('(min-width: 1024px)');

// Replace button handler:
const handleCreateClick = () => {
  if (isWide) setIsSheetOpen(true);
  else navigate({ to: '/debts/new' });
};

// Replace Dialog with Sheet (keep other dialogs for debt details and payment):
<Sheet open={isSheetOpen} onOpenChange={setIsSheetOpen}>
  <SheetContent side="right" className="w-full sm:max-w-lg">
    <SheetHeader>
      <SheetTitle>{t('debts.createDebt')}</SheetTitle>
    </SheetHeader>
    <div className="flex-1 overflow-y-auto -mx-4 px-4">
      <DebtForm
        onSubmit={handleCreateDebt}
        onCancel={() => setIsSheetOpen(false)}
        isLoading={createMutation.isPending}
      />
    </div>
  </SheetContent>
</Sheet>
```

- [ ] **Step 2: Commit**

```bash
git add src/pages/DebtsPage.tsx
git commit -m "feat: replace debt dialog with Sheet + route pattern"
```

---

### Task 6: Update SettingsPage — Sheet for currency form

**Files:**
- Modify: `src/pages/SettingsPage.tsx`

- [ ] **Step 1: Replace currency Dialog with Sheet**

Only the currency form dialog gets Sheet treatment. The update rate and link device dialogs are small inline actions that stay as Dialogs.

```typescript
// Add imports:
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '../components/ui/sheet';

// Replace:
// const [isAddDialogOpen, setIsAddDialogOpen] = useState(false);
// With:
const [isCurrencySheetOpen, setIsCurrencySheetOpen] = useState(false);

// Replace button onClick:
// onClick={() => setIsAddDialogOpen(true)}
// With:
// onClick={() => setIsCurrencySheetOpen(true)}

// Replace Dialog with Sheet:
<Sheet open={isCurrencySheetOpen} onOpenChange={setIsCurrencySheetOpen}>
  <SheetContent side="right" className="w-full sm:max-w-lg">
    <SheetHeader>
      <SheetTitle>{t('settings.addCurrency')}</SheetTitle>
    </SheetHeader>
    <div className="flex-1 overflow-y-auto -mx-4 px-4">
      <CurrencyForm
        onSubmit={handleAddCurrency}
        onCancel={() => setIsCurrencySheetOpen(false)}
        isLoading={addMutation.isPending}
      />
    </div>
  </SheetContent>
</Sheet>
```

- [ ] **Step 2: Commit**

```bash
git add src/pages/SettingsPage.tsx
git commit -m "feat: replace currency dialog with Sheet"
```

---

### Task 7: Verify build and test

**Files:**
- None

- [ ] **Step 1: Run type check**

```bash
cd src && npx tsc --noEmit
```
Expected: No type errors.

- [ ] **Step 2: Run existing tests**

```bash
npx vitest run
```
Expected: All existing tests pass.

- [ ] **Step 3: Start dev server and smoke test**

```bash
npm run dev
```
Manual verification:
1. Wide screen: Click "Add Transaction" → Sheet slides from right
2. Narrow screen (resize to <1024px): Click "Add Transaction" → navigates to `/transactions/new` page with back arrow
3. Same for Accounts, Debts, Currency forms

- [ ] **Step 4: Commit any fixes if needed**

```bash
git add . && git commit -m "fix: address type errors or test failures from responsive forms"
```
