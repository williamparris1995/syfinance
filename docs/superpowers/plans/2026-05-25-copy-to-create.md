# Copy-to-Create Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add "copy" buttons to AccountsPage and TransactionsPage that open a create form pre-filled with existing data, creating a new record on submit.

**Architecture:** Decouple `initialData` from `mode` in both form components. `initialData` controls pre-filling; `mode` ('create' | 'edit') controls submit behavior and field restrictions. Copy = `initialData` + `mode='create'`.

**Tech Stack:** React, TypeScript, react-hook-form, TanStack Query, lucide-react icons, shadcn/ui

---

### Task 1: Add `mode` prop to AccountForm

**Files:**
- Modify: `src/components/AccountForm.tsx`

- [ ] **Step 1: Update props interface and component signature**

In `src/components/AccountForm.tsx`, change the props interface (around line 62):

```typescript
interface AccountFormProps {
  onSubmit: (data: CreateAccountDto | { id: string; dto: UpdateAccountDto }) => void;
  onCancel: () => void;
  isLoading?: boolean;
  initialData?: AccountDto;
  mode?: 'create' | 'edit';
}
```

Change the component signature (around line 69):

```typescript
export function AccountForm({ onSubmit, onCancel, isLoading, initialData, mode = 'create' }: AccountFormProps) {
```

- [ ] **Step 2: Replace `isEditMode` derivation**

Change line 73 from:

```typescript
const isEditMode = !!initialData;
```

To:

```typescript
const isEditMode = mode === 'edit';
```

This is the core change. `initialData` now only controls form pre-filling. `mode` controls whether submit produces a `CreateAccountDto` or an `{ id, dto: UpdateAccountDto }`, and whether ownership/account_type are disabled.

- [ ] **Step 3: Verify TypeScript compiles**

Run: `npx tsc --noEmit --pretty 2>&1 | head -10`
Expected: Errors in `AccountsPage.tsx` and `NewAccountPage.tsx` because they don't pass `mode` yet. This is fine — we'll fix it in Task 3 and the default `'create'` handles it.

Actually, since `mode` has a default value of `'create'`, existing callers should compile fine. Verify no errors.

- [ ] **Step 4: Commit**

```bash
git add src/components/AccountForm.tsx
git commit -m "feat: add mode prop to AccountForm, decouple from initialData"
```

---

### Task 2: Add `mode` prop to SimpleTransactionForm

**Files:**
- Modify: `src/components/SimpleTransactionForm.tsx`

- [ ] **Step 1: Update props interface and component signature**

Change the props interface (around line 30):

```typescript
interface SimpleTransactionFormProps {
  accounts: Account[];
  externalAccounts: Account[];
  onSubmit: (data: TransactionFormData) => Promise<void>;
  onCancel: () => void;
  initialData?: TransactionFormData;
  mode?: 'create' | 'edit';
}
```

Change the component destructuring (around line 50):

```typescript
export function SimpleTransactionForm({
  accounts,
  externalAccounts,
  onSubmit,
  onCancel,
  initialData,
  mode = 'create',
}: SimpleTransactionFormProps) {
```

- [ ] **Step 2: Replace `initialData` check in handleSubmit**

In the `handleSubmit` function, change the create API guard (around line 151):

From:
```typescript
if (!initialData) {
```

To:
```typescript
if (mode !== 'edit') {
```

This ensures create API calls run in both `create` and `copy` modes. Only `edit` mode skips them (letting the parent's `onSubmit` handle the update).

- [ ] **Step 3: Replace `initialData` check for form reset**

In the same `handleSubmit` function, the form reset guard (around line 179):

From:
```typescript
if (!initialData) {
```

To:
```typescript
if (mode !== 'edit') {
```

This resets form fields after create/copy, but not after edit.

- [ ] **Step 4: Verify TypeScript compiles**

Run: `npx tsc --noEmit --pretty 2>&1 | head -10`
Expected: No errors (mode has default value).

- [ ] **Step 5: Commit**

```bash
git add src/components/SimpleTransactionForm.tsx
git commit -m "feat: add mode prop to SimpleTransactionForm, decouple from initialData"
```

---

### Task 3: Add copy flow to AccountsPage

**Files:**
- Modify: `src/pages/AccountsPage.tsx`

- [ ] **Step 1: Add Copy icon import**

Update the lucide import (around line 2):

```typescript
import { Copy, Pencil, Trash2 } from 'lucide-react';
```

- [ ] **Step 2: Add copyingAccount state**

After the existing `useState` declarations (around line 41), add:

```typescript
const [copyingAccount, setCopyingAccount] = useState<AccountDto | null>(null);
```

- [ ] **Step 3: Update handleCreateClick to clear copy state**

Change `handleCreateClick` to also clear `copyingAccount`:

```typescript
const handleCreateClick = () => {
  setEditingAccount(null);
  setCopyingAccount(null);
  setIsSheetOpen(true);
};
```

- [ ] **Step 4: Add copy click handler**

After `handleEditClick`, add:

```typescript
const handleCopyClick = (account: AccountDto) => {
  setEditingAccount(null);
  setCopyingAccount(account);
  setIsSheetOpen(true);
};
```

- [ ] **Step 5: Add Copy button to table actions**

In the table actions cell (around line 171), add Copy button before the Pencil button:

```tsx
<TableCell>
  <Button
    variant="ghost"
    size="sm"
    onClick={() => handleCopyClick(account)}
    title={t('accounts.copyToCreate')}
  >
    <Copy className="h-4 w-4 text-gray-500" />
  </Button>
  <Button
    variant="ghost"
    size="sm"
    onClick={() => handleEditClick(account)}
  >
    <Pencil className="h-4 w-4 text-blue-500" />
  </Button>
  <Button
    variant="ghost"
    size="sm"
    onClick={() => setDeleteConfirmId(account.id)}
  >
    <Trash2 className="h-4 w-4" />
  </Button>
</TableCell>
```

- [ ] **Step 6: Update create Sheet to support copy**

Update the create Sheet's `open` prop and content (around line 165):

```tsx
<Sheet open={isSheetOpen && !editingAccount} onOpenChange={(open) => { setIsSheetOpen(open); if (!open) { setEditingAccount(null); setCopyingAccount(null); } }}>
  <SheetContent side="right" className="w-full sm:max-w-lg">
    <SheetHeader>
      <SheetTitle>{copyingAccount ? t('accounts.copyToCreate') : t('accounts.createAccount')}</SheetTitle>
    </SheetHeader>
    <div className="flex-1 overflow-y-auto -mx-4 px-4">
      <AccountForm
        initialData={copyingAccount ?? undefined}
        onSubmit={handleCreateAccount}
        onCancel={() => { setIsSheetOpen(false); setEditingAccount(null); setCopyingAccount(null); }}
        isLoading={createMutation.isPending}
      />
    </div>
  </SheetContent>
</Sheet>
```

The key: `mode` defaults to `'create'`, so even with `initialData`, the form creates a new account.

- [ ] **Step 7: Verify TypeScript compiles**

Run: `npx tsc --noEmit --pretty 2>&1 | head -10`
Expected: No errors.

- [ ] **Step 8: Commit**

```bash
git add src/pages/AccountsPage.tsx
git commit -m "feat: add copy-to-create button to AccountsPage"
```

---

### Task 4: Add copy flow to TransactionsPage

**Files:**
- Modify: `src/pages/TransactionsPage.tsx`

- [ ] **Step 1: Add Copy icon import**

Update the lucide import. Find the line with `Pencil, Trash2` and add `Copy`:

```typescript
import { Copy, Pencil, Trash2, Search } from 'lucide-react';
```

- [ ] **Step 2: Add copyingTransaction state**

After the existing `useState` declarations (around the `editingTransaction` state), add:

```typescript
const [copyingTransaction, setCopyingTransaction] = useState<TransactionDto | null>(null);
```

- [ ] **Step 3: Add copy click handler**

Add after the existing `handleEditClick` logic:

```typescript
const handleCopyClick = (transaction: TransactionDto) => {
  setEditingTransaction(null);
  setCopyingTransaction(transaction);
  setIsSheetOpen(true);
};
```

- [ ] **Step 4: Add Copy button to table actions**

In the actions cell (around line 573), add Copy button before the Pencil button:

```tsx
<TableCell className="text-center">
  <Button
    variant="ghost"
    size="icon"
    className="h-7 w-7"
    onClick={() => handleCopyClick(transaction)}
    title={t('transactions.copyToCreate')}
  >
    <Copy className="h-3.5 w-3.5 text-gray-500" />
  </Button>
  <Button
    variant="ghost"
    size="icon"
    className="h-7 w-7"
    onClick={() => {
      setEditingTransaction(transaction);
      setIsSheetOpen(true);
    }}
  >
    <Pencil className="h-3.5 w-3.5 text-blue-500" />
  </Button>
  <Button
    variant="ghost"
    size="icon"
    className="h-7 w-7"
    onClick={() => setDeletingTransaction(transaction)}
  >
    <Trash2 className="h-3.5 w-3.5 text-red-500" />
  </Button>
</TableCell>
```

- [ ] **Step 5: Update create Sheet to support copy**

Update the create Sheet (around line 602):

```tsx
<Sheet open={isSheetOpen && !editingTransaction} onOpenChange={(open) => { setIsSheetOpen(open); if (!open) { setEditingTransaction(null); setCopyingTransaction(null); } }}>
  <SheetContent side="right" className="w-full sm:max-w-lg">
    <SheetHeader>
      <SheetTitle>{copyingTransaction ? t('transactions.copyToCreate') : t('transactions.recordTransaction')}</SheetTitle>
    </SheetHeader>
    <div className="flex-1 overflow-y-auto -mx-4 px-4">
      <SimpleTransactionForm
        accounts={accounts}
        externalAccounts={externalAccounts}
        initialData={copyingTransaction ? getEditInitialData(copyingTransaction) : undefined}
        onSubmit={async () => {
          setIsSheetOpen(false);
          setCopyingTransaction(null);
          queryClient.invalidateQueries({ queryKey: ['transactions'] });
          queryClient.invalidateQueries({ queryKey: ['accounts'] });
          toast.success(t('transactions.recorded'));
        }}
        onCancel={() => { setIsSheetOpen(false); setCopyingTransaction(null); }}
      />
    </div>
  </SheetContent>
</Sheet>
```

The `mode` defaults to `'create'`, so the form calls create API even with `initialData`.

- [ ] **Step 6: Verify TypeScript compiles**

Run: `npx tsc --noEmit --pretty 2>&1 | head -10`
Expected: No errors.

- [ ] **Step 7: Commit**

```bash
git add src/pages/TransactionsPage.tsx
git commit -m "feat: add copy-to-create button to TransactionsPage"
```

---

### Task 5: Add i18n keys

**Files:**
- Modify: `src/i18n/locales/en.json`
- Modify: `src/i18n/locales/zh.json`

- [ ] **Step 1: Add keys to both locale files**

Add to `accounts` section:
- `accounts.copyToCreate` — en: `"Copy to New Account"`, zh: `"复制为新账户"`

Add to `transactions` section:
- `transactions.copyToCreate` — en: `"Copy to New Transaction"`, zh: `"复制为新交易"`

- [ ] **Step 2: Commit**

```bash
git add src/i18n/locales/en.json src/i18n/locales/zh.json
git commit -m "feat: add i18n keys for copy-to-create"
```

---

### Task 6: Verify

- [ ] **Step 1: TypeScript check**

Run: `npx tsc --noEmit --pretty 2>&1 | head -10`
Expected: No errors.

- [ ] **Step 2: Manual test**

Run: `npm run tauri dev`

Test:
1. **Account copy**: Click Copy icon on an account → Sheet opens pre-filled → change name → submit → new account appears in table
2. **Transaction copy**: Click Copy icon on a transaction → Sheet opens pre-filled → submit → new transaction appears
3. **Normal create still works**: Click "Create Account" → blank form → submit → new account
4. **Edit still works**: Click Pencil → form pre-filled with disabled fields → submit → account updated
