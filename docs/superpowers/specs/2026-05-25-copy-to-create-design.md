# Copy-to-Create Feature Design

**Date:** 2026-05-25
**Approach:** Reuse `initialData` prop with `mode='create'` for copy behavior

## Requirements

- AccountsPage: add "copy" button (Copy icon) that opens the create Sheet pre-filled with the account's data
- TransactionsPage: add "copy" button (Copy icon) that opens the create Sheet pre-filled with the transaction's data
- All fields are editable in copy mode (same as create, unlike edit where ownership/account_type are disabled)
- Copy creates a brand new record (new ID) — no backend changes needed
- Transaction copy preserves the original date

## Design

### Key Insight: `initialData` and `mode` are independent

Currently `AccountForm` and `SimpleTransactionForm` derive mode from `initialData`:
```
isEditMode = !!initialData
```

We decouple these:
- `initialData` = optional data to pre-fill the form
- `mode: 'create' | 'edit'` = determines submit behavior and field restrictions

| Scenario | `initialData` | `mode` | Fields disabled? | Submit calls |
|----------|--------------|--------|-----------------|-------------|
| Create (blank) | undefined | 'create' | None | create API |
| Copy | existing data | 'create' | None | create API |
| Edit | existing data | 'edit' | ownership, account_type | update API |

### AccountForm changes

- Add `mode: 'create' | 'edit'` prop (default: `'create'`)
- Remove `isEditMode = !!initialData`, replace with `isEditMode = mode === 'edit'`
- Pre-fill logic stays the same (driven by `initialData`)
- Submit handler stays the same (driven by `isEditMode`)

### SimpleTransactionForm changes

- Add `mode: 'create' | 'edit'` prop (default: `'create'`)
- `initialData` already exists for edit — same prop works for copy
- When `mode === 'create'`, the create API calls run (unlike edit where they're skipped)
- No fields disabled in create mode

### AccountsPage changes

- Add Copy icon button (from lucide `Copy`) in the actions column
- Click handler: sets `copyingAccount` state with the account data, opens the create Sheet
- Create Sheet receives `initialData={copyingAccount}` and `mode='create'`
- On submit: calls `createAccount` as usual

### TransactionsPage changes

- Add Copy icon button in the actions column
- Click handler: converts transaction to `TransactionFormData` (reuse `getEditInitialData`), opens the create Sheet
- Create Sheet receives `initialData={formData}` and `mode='create'`
- On submit: form calls create API as usual

## Data Flow (Account Copy)

```
User clicks Copy → copyingAccount set → create Sheet opens
  AccountForm(initialData=account, mode='create')
  → form pre-filled, all fields enabled
  → submit → creates CreateAccountDto → createAccount() → new account created
```

## Data Flow (Transaction Copy)

```
User clicks Copy → formData = getEditInitialData(transaction)
  → create Sheet opens with initialData=formData, mode='create'
  → form pre-filled, all fields enabled
  → submit → createSimpleExpense/Income/Transfer() → new transaction created
```

## Files to Change

| File | Change |
|------|--------|
| `src/components/AccountForm.tsx` | Add `mode` prop, decouple from `initialData` |
| `src/components/SimpleTransactionForm.tsx` | Add `mode` prop, pass through to form |
| `src/pages/AccountsPage.tsx` | Add Copy button + copyingAccount state |
| `src/pages/TransactionsPage.tsx` | Add Copy button + copyingTransaction state |
| `src/i18n/locales/en.json` | Add copy-related i18n keys |
| `src/i18n/locales/zh.json` | Add copy-related i18n keys |
