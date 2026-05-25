# Account Edit Feature Design

**Date:** 2026-05-25
**Approach:** Extend UpdateAccountDto + reuse AccountForm in Sheet

## Requirements

- AccountsPage table adds an edit action (Pencil icon) in the Actions column
- Clicking edit opens a Sheet sidebar with the existing AccountForm pre-filled with current data
- Editable fields: name, balance, icon, color, currency_code, account_number, institution, credit_limit, billing_day, payment_due_day, interest_rate, chart_code
- Immutable fields: ownership, account_type (disabled in edit mode)
- Balance is directly editable (for credit cards, balance = outstanding amount, can be negative; credit_limit is a separate field)

## Backend Changes (Rust)

### UpdateAccountDto

`src-tauri/src/application/dtos/account_dto.rs` — extend from `{ name, balance }` to:

```rust
pub struct UpdateAccountDto {
    pub name: String,
    pub balance: Decimal,
    pub icon: Option<String>,
    pub color: Option<String>,
    pub currency_code: Option<String>,
    pub account_number: Option<String>,
    pub institution: Option<String>,
    pub credit_limit: Option<Decimal>,
    pub billing_day: Option<i32>,
    pub payment_due_day: Option<i32>,
    pub interest_rate: Option<Decimal>,
    pub chart_code: Option<String>,
    pub parent_id: Option<Uuid>,
}
```

`name` and `balance` are required — the edit form always submits them.

### Account entity setters

`src-tauri/src/domain/aggregates/account.rs` — add methods:

- `update_icon(icon: String)`
- `update_color(color: String)`
- `update_currency_code(currency_code: String)` — validates currency matches existing balance currency, returns error if mismatch
- `update_account_number(account_number: Option<String>)`
- `update_institution(institution: Option<String>)`
- `update_credit_limit(credit_limit: Option<Decimal>)`
- `update_billing_day(billing_day: Option<i32>)` — validates 1-31
- `update_payment_due_day(payment_due_day: Option<i32>)` — validates 1-31
- `update_interest_rate(interest_rate: Option<Decimal>)` — validates non-negative
- `update_chart_code(chart_code: Option<String>)`
- `update_parent_id(parent_id: Option<Uuid>)`

Each setter calls `self.touch()` to update `updated_at` and clear `synced_at`.

### AccountService::update_account

`src-tauri/src/application/services/account_service.rs` — modify to:

1. Load account by ID
2. Apply `dto.name` via `change_name()`
3. Apply `dto.balance` via `update_balance()` (with currency validation)
4. For each remaining `Some` field in dto, call the corresponding setter
5. Save via repository

### Tauri command

No signature change needed — `update_account(state, id, dto)` already accepts the right shape.

## Frontend Changes

### TypeScript UpdateAccountDto

`src/lib/tauri/account.ts` — sync type:

```typescript
export interface UpdateAccountDto {
  name: string;
  balance: number;
  icon?: string;
  color?: string;
  currency_code?: string;
  account_number?: string;
  institution?: string;
  credit_limit?: number;
  billing_day?: number;
  payment_due_day?: number;
  interest_rate?: number;
  chart_code?: string;
  parent_id?: string;
}
```

### AccountForm component

`src/components/AccountForm.tsx` — add props:

```typescript
interface AccountFormProps {
  onSubmit: (data: CreateAccountDto | { id: string; dto: UpdateAccountDto }) => void;
  onCancel: () => void;
  isLoading?: boolean;
  initialData?: AccountDto;
}
```

- When `initialData` is provided, pre-fill all form fields from it
- When editing, `ownership` and `account_type` fields are disabled
- Submit handler: if `initialData` exists, build `UpdateAccountDto` (name/balance required, other fields optional if unchanged); otherwise build `CreateAccountDto`

### AccountsPage

`src/pages/AccountsPage.tsx` — follow TransactionsPage edit pattern:

- Add `editingAccount: AccountDto | null` state
- Actions column: add Pencil icon button before the Delete button
- Click Pencil → set `editingAccount`, open Sheet
- Single Sheet instance: shows create form when `!editingAccount`, edit form when `!!editingAccount`
- Edit submit → call `updateAccount(id, dto)` → invalidate `['accounts']` query → close Sheet
- Error handling: toast notification on failure

## Data Flow

```
User clicks Pencil → editingAccount set → Sheet opens with AccountForm(initialData=account)
User edits fields → submits → AccountForm builds UpdateAccountDto
→ updateAccount(id, dto) → Tauri invoke → Rust update_account command
→ AccountService loads entity → applies setters → repository saves
→ queryClient invalidates → table refreshes → Sheet closes
```
