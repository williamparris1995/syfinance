# Account Edit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add account editing to the AccountsPage — click Pencil icon, edit in Sheet, save via extended UpdateAccountDto.

**Architecture:** Extend the existing UpdateAccountDto from `{ name, balance }` to all editable fields. Add setter methods to the Account domain entity. Expand repository UPDATE SQL to persist all fields. Reuse AccountForm with `initialData` prop in a second Sheet for edit mode, following the TransactionsPage pattern.

**Tech Stack:** Rust (Tauri v2), TypeScript, React, React Hook Form + Zod, TanStack Query, shadcn/ui

---

### Task 1: Extend Rust UpdateAccountDto

**Files:**
- Modify: `src-tauri/src/application/dtos/account_dto.rs:24-27`

- [ ] **Step 1: Update UpdateAccountDto struct**

Replace the current struct (lines 24-27):

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
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

- [ ] **Step 2: Run Rust check**

Run: `cd src-tauri && cargo check 2>&1 | head -30`
Expected: Compilation errors in `account_service.rs` because existing test code constructs `UpdateAccountDto` with old fields (`name: Some(...)`, `balance: None`). We will fix this in Task 3.

- [ ] **Step 3: Commit**

```bash
git add src-tauri/src/application/dtos/account_dto.rs
git commit -m "feat: extend UpdateAccountDto with all editable fields"
```

---

### Task 2: Add Account entity setters with tests

**Files:**
- Modify: `src-tauri/src/domain/aggregates/account.rs:184-243` (after existing methods)
- Test: inline `#[cfg(test)]` module in same file

- [ ] **Step 1: Write failing tests for setters**

Add inside `mod tests > mod account > mod business_rules` (after the `soft_delete_marks_sync_metadata_deleted` test, around line 447):

```rust
#[test]
fn update_icon_changes_icon_and_touches_metadata() {
    let mut account = Account::new(
        Uuid::new_v4(),
        "Wallet",
        AccountType::Bank,
        Ownership::Own,
        &currency("CNY"),
        money(100, "CNY"),
        "💰",
        "#10B981",
        None,
        None,
        metadata(),
    ).unwrap();

    let before = account.sync_metadata.updated_at;
    account.update_icon("💳").unwrap();

    assert_eq!(account.icon, "💳");
    assert!(account.sync_metadata.updated_at >= before);
    assert!(account.sync_metadata.synced_at.is_none());
}

#[test]
fn update_color_changes_color() {
    let mut account = Account::new(
        Uuid::new_v4(),
        "Wallet",
        AccountType::Bank,
        Ownership::Own,
        &currency("CNY"),
        money(100, "CNY"),
        "💰",
        "#10B981",
        None,
        None,
        metadata(),
    ).unwrap();

    account.update_color("#EF4444").unwrap();
    assert_eq!(account.color, "#EF4444");
}

#[test]
fn update_currency_code_rejects_mismatch() {
    let mut account = Account::new(
        Uuid::new_v4(),
        "Wallet",
        AccountType::Bank,
        Ownership::Own,
        &currency("CNY"),
        money(100, "CNY"),
        "💰",
        "#10B981",
        None,
        None,
        metadata(),
    ).unwrap();

    let result = account.update_currency_code("USD".to_string());
    assert!(result.is_err());
}

#[test]
fn update_billing_day_rejects_out_of_range() {
    let mut account = Account::new(
        Uuid::new_v4(),
        "Wallet",
        AccountType::Bank,
        Ownership::Own,
        &currency("CNY"),
        money(100, "CNY"),
        "💰",
        "#10B981",
        None,
        None,
        metadata(),
    ).unwrap();

    assert!(account.update_billing_day(Some(32)).is_err());
    assert!(account.update_billing_day(Some(0)).is_err());
    assert!(account.update_billing_day(Some(15)).is_ok());
    assert_eq!(account.billing_day, Some(15));
}

#[test]
fn update_payment_due_day_rejects_out_of_range() {
    let mut account = Account::new(
        Uuid::new_v4(),
        "Wallet",
        AccountType::Bank,
        Ownership::Own,
        &currency("CNY"),
        money(100, "CNY"),
        "💰",
        "#10B981",
        None,
        None,
        metadata(),
    ).unwrap();

    assert!(account.update_payment_due_day(Some(32)).is_err());
    assert!(account.update_payment_due_day(Some(1)).is_ok());
}

#[test]
fn update_interest_rate_rejects_negative() {
    let mut account = Account::new(
        Uuid::new_v4(),
        "Wallet",
        AccountType::Bank,
        Ownership::Own,
        &currency("CNY"),
        money(100, "CNY"),
        "💰",
        "#10B981",
        None,
        None,
        metadata(),
    ).unwrap();

    assert!(account.update_interest_rate(Some(Decimal::new(-1, 2))).is_err());
    assert!(account.update_interest_rate(Some(Decimal::new(5, 1))).is_ok());
    assert_eq!(account.interest_rate, Some(Decimal::new(5, 1)));
}

#[test]
fn update_credit_limit_stores_money_value() {
    let mut account = Account::new(
        Uuid::new_v4(),
        "Visa",
        AccountType::CreditCard,
        Ownership::Own,
        &currency("CNY"),
        money(-100, "CNY"),
        "💳",
        "#10B981",
        None,
        None,
        metadata(),
    ).unwrap();

    account.update_credit_limit(Some(Decimal::new(50000, 2))).unwrap();
    assert_eq!(account.credit_limit.as_ref().unwrap().amount, Decimal::new(50000, 2));
    assert_eq!(account.credit_limit.as_ref().unwrap().currency_code, "CNY");
}

#[test]
fn setters_reject_on_deleted_account() {
    let mut account = Account::new(
        Uuid::new_v4(),
        "Wallet",
        AccountType::Bank,
        Ownership::Own,
        &currency("CNY"),
        money(100, "CNY"),
        "💰",
        "#10B981",
        None,
        None,
        metadata(),
    ).unwrap();

    account.soft_delete().unwrap();

    assert!(account.update_icon("x").is_err());
    assert!(account.update_color("x").is_err());
    assert!(account.update_billing_day(Some(1)).is_err());
    assert!(account.update_payment_due_day(Some(1)).is_err());
    assert!(account.update_interest_rate(Some(Decimal::ONE)).is_err());
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd src-tauri && cargo test --lib account::tests::account::business_rules -- 2>&1 | tail -20`
Expected: FAIL — methods `update_icon`, `update_color`, etc. do not exist yet.

- [ ] **Step 3: Implement setter methods**

Add after the `change_name` method (after line 212) and before `soft_delete`:

```rust
pub fn update_icon(&mut self, icon: impl Into<String>) -> Result<(), AccountError> {
    self.ensure_not_deleted()?;
    self.icon = icon.into().trim().to_string();
    self.touch();
    Ok(())
}

pub fn update_color(&mut self, color: impl Into<String>) -> Result<(), AccountError> {
    self.ensure_not_deleted()?;
    self.color = color.into().trim().to_string();
    self.touch();
    Ok(())
}

pub fn update_currency_code(&mut self, currency_code: String) -> Result<(), AccountError> {
    self.ensure_not_deleted()?;
    if currency_code != self.currency_code {
        return Err(AccountError::CurrencyMismatch {
            expected: self.currency_code.clone(),
            actual: currency_code,
        });
    }
    Ok(())
}

pub fn update_account_number(&mut self, account_number: Option<String>) -> Result<(), AccountError> {
    self.ensure_not_deleted()?;
    self.account_number = account_number;
    self.touch();
    Ok(())
}

pub fn update_institution(&mut self, institution: Option<String>) -> Result<(), AccountError> {
    self.ensure_not_deleted()?;
    self.institution = institution;
    self.touch();
    Ok(())
}

pub fn update_credit_limit(&mut self, credit_limit: Option<Decimal>) -> Result<(), AccountError> {
    self.ensure_not_deleted()?;
    self.credit_limit = credit_limit.map(|amount| Money::new(amount, &self.currency_code)).transpose()
        .map_err(|e| AccountError::CurrencyMismatch {
            expected: self.currency_code.clone(),
            actual: e.to_string(),
        })?;
    self.touch();
    Ok(())
}

pub fn update_billing_day(&mut self, billing_day: Option<i32>) -> Result<(), AccountError> {
    self.ensure_not_deleted()?;
    if let Some(day) = billing_day {
        if !(1..=31).contains(&day) {
            return Err(AccountError::InvalidBillingDay);
        }
        self.billing_day = Some(day as u8);
    } else {
        self.billing_day = None;
    }
    self.touch();
    Ok(())
}

pub fn update_payment_due_day(&mut self, payment_due_day: Option<i32>) -> Result<(), AccountError> {
    self.ensure_not_deleted()?;
    if let Some(day) = payment_due_day {
        if !(1..=31).contains(&day) {
            return Err(AccountError::InvalidPaymentDueDay);
        }
        self.payment_due_day = Some(day as u8);
    } else {
        self.payment_due_day = None;
    }
    self.touch();
    Ok(())
}

pub fn update_interest_rate(&mut self, interest_rate: Option<Decimal>) -> Result<(), AccountError> {
    self.ensure_not_deleted()?;
    if let Some(rate) = interest_rate {
        if rate < Decimal::ZERO {
            return Err(AccountError::InvalidInterestRate);
        }
        self.interest_rate = Some(rate);
    } else {
        self.interest_rate = None;
    }
    self.touch();
    Ok(())
}

pub fn update_chart_code(&mut self, chart_code: Option<String>) -> Result<(), AccountError> {
    self.ensure_not_deleted()?;
    self.chart_code = chart_code;
    self.touch();
    Ok(())
}

pub fn update_parent_id(&mut self, parent_id: Option<Uuid>) -> Result<(), AccountError> {
    self.ensure_not_deleted()?;
    self.parent_id = parent_id;
    self.touch();
    Ok(())
}
```

Note: `update_currency_code` validates that the new code matches the existing currency of the balance. Changing currency requires a separate flow (not in scope).

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd src-tauri && cargo test --lib account::tests::account::business_rules -- 2>&1 | tail -20`
Expected: All new tests PASS.

- [ ] **Step 5: Commit**

```bash
git add src-tauri/src/domain/aggregates/account.rs
git commit -m "feat: add setter methods to Account entity for all editable fields"
```

---

### Task 3: Update AccountService::update_account and fix existing tests

**Files:**
- Modify: `src-tauri/src/application/services/account_service.rs:54-79`
- Test: fix existing test in same file (lines 350-380)

- [ ] **Step 1: Write failing test for extended update**

Add after the `test_update_account_name` test (line 380):

```rust
#[tokio::test]
async fn test_update_account_all_fields() {
    let account_repo = Arc::new(MockAccountRepository::new());
    let currency_repo = Arc::new(MockCurrencyRepository::new());
    let service = AccountService::new(account_repo.clone(), currency_repo);

    let create_dto = CreateAccountDto {
        name: "Visa Card".to_string(),
        account_type: AccountType::CreditCard,
        ownership: Ownership::Own,
        currency_code: "CNY".to_string(),
        initial_balance: Decimal::new(-100, 2),
        icon: "💳".to_string(),
        color: "#10B981".to_string(),
        chart_code: None,
        parent_id: None,
    };

    let created = service.create_account((), create_dto).await.unwrap();

    let update_dto = UpdateAccountDto {
        name: "Visa Platinum".to_string(),
        balance: Decimal::new(-500, 2),
        icon: Some("💰".to_string()),
        color: Some("#EF4444".to_string()),
        currency_code: None,
        account_number: Some("****1234".to_string()),
        institution: Some("ICBC".to_string()),
        credit_limit: Some(Decimal::new(50000, 2)),
        billing_day: Some(5),
        payment_due_day: Some(25),
        interest_rate: None,
        chart_code: None,
        parent_id: None,
    };

    let result = service.update_account((), created.id, update_dto).await;

    assert!(result.is_ok());
    let updated = result.unwrap();
    assert_eq!(updated.name, "Visa Platinum");
    assert_eq!(updated.balance, Decimal::new(-500, 2));
    assert_eq!(updated.icon, "💰");
    assert_eq!(updated.color, "#EF4444");
    assert_eq!(updated.account_number, Some("****1234".to_string()));
    assert_eq!(updated.institution, Some("ICBC".to_string()));
    assert_eq!(updated.credit_limit, Some(Decimal::new(50000, 2)));
    assert_eq!(updated.billing_day, Some(5));
    assert_eq!(updated.payment_due_day, Some(25));
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd src-tauri && cargo test --lib account_service::tests::test_update_account_all_fields -- 2>&1 | tail -20`
Expected: FAIL — the service method doesn't apply the new fields yet.

- [ ] **Step 3: Implement service method and fix existing test**

Replace `update_account` method (lines 54-79):

```rust
pub async fn update_account<E>(
    &self,
    _executor: E,
    id: Uuid,
    dto: UpdateAccountDto,
) -> Result<AccountDto, AccountServiceError> {
    let mut account = self
        .account_repo
        .find_by_id(id)
        .await?
        .ok_or(AccountServiceError::AccountNotFound(id))?;

    account.change_name(dto.name)?;

    let balance = Money::new(dto.balance, &account.currency_code)
        .map_err(|e| AccountServiceError::InvalidMoney(e.to_string()))?;
    account.update_balance(balance)?;

    if let Some(icon) = dto.icon {
        account.update_icon(icon)?;
    }
    if let Some(color) = dto.color {
        account.update_color(color)?;
    }
    if let Some(currency_code) = dto.currency_code {
        account.update_currency_code(currency_code)?;
    }
    if let Some(account_number) = dto.account_number {
        account.update_account_number(Some(account_number))?;
    }
    if let Some(institution) = dto.institution {
        account.update_institution(Some(institution))?;
    }
    if let Some(credit_limit) = dto.credit_limit {
        account.update_credit_limit(Some(credit_limit))?;
    }
    if let Some(billing_day) = dto.billing_day {
        account.update_billing_day(Some(billing_day))?;
    }
    if let Some(payment_due_day) = dto.payment_due_day {
        account.update_payment_due_day(Some(payment_due_day))?;
    }
    if let Some(interest_rate) = dto.interest_rate {
        account.update_interest_rate(Some(interest_rate))?;
    }
    if let Some(chart_code) = dto.chart_code {
        account.update_chart_code(Some(chart_code))?;
    }
    if let Some(parent_id) = dto.parent_id {
        account.update_parent_id(Some(parent_id))?;
    }

    self.account_repo.update(&account).await?;

    Ok(AccountDto::from(account))
}
```

Also fix the existing test `test_update_account_name` (lines 370-374) — the old `UpdateAccountDto` used `Option` fields:

```rust
let update_dto = UpdateAccountDto {
    name: "New Name".to_string(),
    balance: Decimal::new(10000, 2),
    icon: None,
    color: None,
    currency_code: None,
    account_number: None,
    institution: None,
    credit_limit: None,
    billing_day: None,
    payment_due_day: None,
    interest_rate: None,
    chart_code: None,
    parent_id: None,
};
```

- [ ] **Step 4: Run all service tests**

Run: `cd src-tauri && cargo test --lib account_service::tests -- 2>&1 | tail -20`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add src-tauri/src/application/services/account_service.rs
git commit -m "feat: update AccountService to apply all editable fields on update"
```

---

### Task 4: Expand repository UPDATE SQL

**Files:**
- Modify: `src-tauri/src/infrastructure/repositories/account_repository.rs:303-328`
- Modify: `src-tauri/src/infrastructure/repositories/account_repository_postgres.rs:225-254`

- [ ] **Step 1: Update SQLite repository**

Replace the `update` method (lines 303-328):

```rust
async fn update(&self, account: &Account) -> sqlx::Result<bool> {
    let result = sqlx::query(
        r#"
        UPDATE accounts
        SET
            name = ?,
            balance = ?,
            icon = ?,
            color = ?,
            chart_code = ?,
            parent_id = ?,
            account_number = ?,
            institution = ?,
            credit_limit = ?,
            billing_day = ?,
            payment_due_day = ?,
            interest_rate = ?,
            updated_at = ?,
            deleted_at = ?,
            device_id = ?,
            synced_at = ?
        WHERE id = ?
        "#,
    )
    .bind(&account.name)
    .bind(account.balance.amount.to_string())
    .bind(&account.icon)
    .bind(&account.color)
    .bind(&account.chart_code)
    .bind(account.parent_id.map(|id| id.to_string()))
    .bind(&account.account_number)
    .bind(&account.institution)
    .bind(account.credit_limit.as_ref().map(|m| m.amount.to_string()))
    .bind(account.billing_day.map(|d| d as i32))
    .bind(account.payment_due_day.map(|d| d as i32))
    .bind(account.interest_rate.map(|r| r.to_string()))
    .bind(account.sync_metadata.updated_at.to_rfc3339())
    .bind(account.sync_metadata.deleted_at.map(|dt| dt.to_rfc3339()))
    .bind(account.sync_metadata.device_id.to_string())
    .bind(account.sync_metadata.synced_at.map(|dt| dt.to_rfc3339()))
    .bind(account.id.to_string())
    .execute(&self.pool)
    .await?;

    Ok(result.rows_affected() > 0)
}
```

- [ ] **Step 2: Update Postgres repository**

Read the current Postgres `update` method to see bind order, then replace with expanded version matching the same pattern as SQLite but using `$N` placeholders:

```rust
async fn update(&self, account: &Account) -> sqlx::Result<bool> {
    let result = sqlx::query(
        r#"
        UPDATE accounts
        SET
            name = $1,
            balance = $2,
            icon = $3,
            color = $4,
            chart_code = $5,
            parent_id = $6,
            account_number = $7,
            institution = $8,
            credit_limit = $9,
            billing_day = $10,
            payment_due_day = $11,
            interest_rate = $12,
            updated_at = $13,
            deleted_at = $14,
            device_id = $15,
            synced_at = $16
        WHERE id = $17
        RETURNING id
        "#,
    )
    .bind(&account.name)
    .bind(account.balance.amount.to_string())
    .bind(&account.icon)
    .bind(&account.color)
    .bind(&account.chart_code)
    .bind(account.parent_id.map(|id| id.to_string()))
    .bind(&account.account_number)
    .bind(&account.institution)
    .bind(account.credit_limit.as_ref().map(|m| m.amount.to_string()))
    .bind(account.billing_day.map(|d| d as i32))
    .bind(account.payment_due_day.map(|d| d as i32))
    .bind(account.interest_rate.map(|r| r.to_string()))
    .bind(account.sync_metadata.updated_at.to_rfc3339())
    .bind(account.sync_metadata.deleted_at.map(|dt| dt.to_rfc3339()))
    .bind(account.sync_metadata.device_id.to_string())
    .bind(account.sync_metadata.synced_at.map(|dt| dt.to_rfc3339()))
    .bind(account.id.to_string())
    .execute(&self.pool)
    .await?;

    Ok(result.rows_affected() > 0)
}
```

- [ ] **Step 3: Run cargo check**

Run: `cd src-tauri && cargo check 2>&1 | head -20`
Expected: No errors.

- [ ] **Step 4: Run all Rust tests**

Run: `cd src-tauri && cargo test --lib 2>&1 | tail -20`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add src-tauri/src/infrastructure/repositories/account_repository.rs src-tauri/src/infrastructure/repositories/account_repository_postgres.rs
git commit -m "feat: expand repository UPDATE SQL to persist all account fields"
```

---

### Task 5: Extend TypeScript UpdateAccountDto

**Files:**
- Modify: `src/lib/tauri/account.ts:25-28`

- [ ] **Step 1: Update the type**

Replace lines 25-28:

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

- [ ] **Step 2: Run TypeScript check**

Run: `npx tsc --noEmit --pretty 2>&1 | head -20`
Expected: No errors (no consumers of the new fields yet).

- [ ] **Step 3: Commit**

```bash
git add src/lib/tauri/account.ts
git commit -m "feat: extend TypeScript UpdateAccountDto with all editable fields"
```

---

### Task 6: Update AccountForm to support edit mode

**Files:**
- Modify: `src/components/AccountForm.tsx`

- [ ] **Step 1: Update imports**

Change line 23 to include `AccountDto` and `UpdateAccountDto`:

```typescript
import type { AccountType, CreateAccountDto, UpdateAccountDto, Ownership, AccountDto } from '@/lib/tauri/account';
```

- [ ] **Step 2: Update props interface**

Replace the `AccountFormProps` interface (lines 62-66):

```typescript
interface AccountFormProps {
  onSubmit: (data: CreateAccountDto | { id: string; dto: UpdateAccountDto }) => void;
  onCancel: () => void;
  isLoading?: boolean;
  initialData?: AccountDto;
}
```

- [ ] **Step 3: Update component signature and form defaults**

Replace the component function (line 68):

```typescript
export function AccountForm({ onSubmit, onCancel, isLoading, initialData }: AccountFormProps) {
  const { t } = useTranslation();
  const accountFormSchema = createAccountFormSchema(t);
  type AccountFormValues = z.infer<typeof accountFormSchema>;
  const isEditMode = !!initialData;

  const form = useForm<AccountFormValues>({
    resolver: zodResolver(accountFormSchema),
    defaultValues: initialData
      ? {
          name: initialData.name,
          account_type: initialData.account_type,
          ownership: initialData.ownership,
          currency_code: initialData.currency_code,
          initial_balance: String(initialData.balance),
          account_number: initialData.account_number ?? '',
          institution: initialData.institution ?? '',
          credit_limit: initialData.credit_limit != null ? String(initialData.credit_limit) : '',
          billing_day: initialData.billing_day != null ? String(initialData.billing_day) : '',
          payment_due_day: initialData.payment_due_day != null ? String(initialData.payment_due_day) : '',
          interest_rate: initialData.interest_rate != null ? String(initialData.interest_rate) : '',
          icon: initialData.icon || '📁',
          color: initialData.color || '#6B7280',
          chart_code: initialData.chart_code ?? '',
          parent_id: initialData.parent_id ?? undefined,
        }
      : {
          name: '',
          account_type: 'Bank',
          ownership: 'own',
          currency_code: 'CNY',
          initial_balance: '0.00',
          account_number: '',
          institution: '',
          credit_limit: '',
          billing_day: '',
          payment_due_day: '',
          interest_rate: '',
          icon: '📁',
          color: '#6B7280',
          chart_code: '',
          parent_id: undefined as string | undefined,
        },
  });
```

- [ ] **Step 4: Update submit handler**

Replace `handleSubmit` (lines 97-119):

```typescript
const handleSubmit = (values: AccountFormValues) => {
  if (isEditMode && initialData) {
    const dto: UpdateAccountDto = {
      name: values.name,
      balance: parseFloat(values.initial_balance),
    };

    if (values.icon) dto.icon = values.icon || '📁';
    if (values.color) dto.color = values.color || '#6B7280';
    if (values.account_number) dto.account_number = values.account_number;
    if (values.institution) dto.institution = values.institution;
    if (values.credit_limit) dto.credit_limit = parseFloat(values.credit_limit);
    if (values.billing_day) dto.billing_day = parseInt(values.billing_day);
    if (values.payment_due_day) dto.payment_due_day = parseInt(values.payment_due_day);
    if (values.interest_rate) dto.interest_rate = parseFloat(values.interest_rate);
    if (values.chart_code) dto.chart_code = values.chart_code;

    onSubmit({ id: initialData.id, dto });
    return;
  }

  const dto: CreateAccountDto = {
    name: values.name,
    account_type: values.account_type as AccountType,
    ownership: values.ownership as Ownership,
    currency_code: values.currency_code,
    initial_balance: parseFloat(values.initial_balance),
    icon: values.icon || '📁',
    color: values.color || '#6B7280',
  };

  if (values.chart_code) dto.chart_code = values.chart_code;
  if (values.parent_id) dto.parent_id = values.parent_id;
  if (values.account_number) dto.account_number = values.account_number;
  if (values.institution) dto.institution = values.institution;
  if (values.credit_limit) dto.credit_limit = parseFloat(values.credit_limit);
  if (values.billing_day) dto.billing_day = parseInt(values.billing_day);
  if (values.payment_due_day) dto.payment_due_day = parseInt(values.payment_due_day);
  if (values.interest_rate) dto.interest_rate = parseFloat(values.interest_rate);

  onSubmit(dto);
};
```

- [ ] **Step 5: Disable ownership and account_type in edit mode**

Find the ownership toggle section (around lines 153-176). Add `disabled={isEditMode}` to both `<button>` elements:

```tsx
<button
  type="button"
  onClick={() => !isEditMode && field.onChange('own')}
  disabled={isEditMode}
  className={cn(
    "flex-1 rounded-lg border px-3 py-2 text-sm font-medium transition-all",
    field.value === 'own'
      ? "bg-emerald-50 border-emerald-300 text-emerald-700 dark:bg-emerald-950 dark:border-emerald-700 dark:text-emerald-400"
      : "bg-background border-input text-muted-foreground hover:text-foreground",
    isEditMode && "opacity-50 cursor-not-allowed"
  )}
>
  🏠 自己账户
</button>
<button
  type="button"
  onClick={() => !isEditMode && field.onChange('external')}
  disabled={isEditMode}
  className={cn(
    "flex-1 rounded-lg border px-3 py-2 text-sm font-medium transition-all",
    field.value === 'external'
      ? "bg-amber-50 border-amber-300 text-amber-700 dark:bg-amber-950 dark:border-amber-700 dark:text-amber-400"
      : "bg-background border-input text-muted-foreground hover:text-foreground",
    isEditMode && "opacity-50 cursor-not-allowed"
  )}
>
  🌐 外部账户
</button>
```

Find the account_type Select (around line 210). Add `disabled={isEditMode}`:

```tsx
<Select value={field.value} onValueChange={field.onChange} disabled={isEditMode}>
```

- [ ] **Step 6: Update submit button text**

Find the submit button (around line 452-454). Replace:

```tsx
<Button type="submit" variant="default-gradient" disabled={isLoading}>
  {isLoading
    ? t('common.saving')
    : isEditMode
      ? t('common.save')
      : t('accountForm.createAccount')}
</Button>
```

Note: If `common.saving` and `common.save` i18n keys don't exist, check `src/i18n/locales/en.json` and `src/i18n/locales/zh.json` for existing keys. Use the closest match or add them.

- [ ] **Step 7: Run TypeScript check**

Run: `npx tsc --noEmit --pretty 2>&1 | head -30`
Expected: No errors.

- [ ] **Step 8: Commit**

```bash
git add src/components/AccountForm.tsx
git commit -m "feat: add edit mode support to AccountForm with initialData prop"
```

---

### Task 7: Add edit flow to AccountsPage

**Files:**
- Modify: `src/pages/AccountsPage.tsx`

- [ ] **Step 1: Update imports**

Add `Pencil` to lucide imports (line 2):

```typescript
import { Pencil, Trash2 } from 'lucide-react';
```

Add `updateAccount` and `UpdateAccountDto` to account imports (lines 31-36):

```typescript
import {
  createAccount,
  deleteAccount,
  listAccounts,
  updateAccount,
  type AccountDto,
  type CreateAccountDto,
  type UpdateAccountDto,
} from '../lib/tauri/account';
```

- [ ] **Step 2: Add edit state**

After the existing `useState` declarations (around line 40), add:

```typescript
const [editingAccount, setEditingAccount] = useState<AccountDto | null>(null);
```

- [ ] **Step 3: Add update mutation**

After the `createMutation` (around line 59), add:

```typescript
const updateMutation = useMutation({
  mutationFn: ({ id, dto }: { id: string; dto: UpdateAccountDto }) => updateAccount(id, dto),
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['accounts'] });
    setIsSheetOpen(false);
    setEditingAccount(null);
    toast.success(t('accounts.accountUpdated'));
  },
  onError: (error) => {
    toast.error(getUserFriendlyError(error));
  },
});
```

Note: If `accounts.accountUpdated` i18n key doesn't exist, check locales files and use the closest match.

- [ ] **Step 4: Add edit handlers**

After `handleCreateAccount` (around line 95), add:

```typescript
const handleEditClick = (account: AccountDto) => {
  setEditingAccount(account);
  setIsSheetOpen(true);
};

const handleEditSubmit = (data: CreateAccountDto | { id: string; dto: UpdateAccountDto }) => {
  if ('id' in data) {
    updateMutation.mutate({ id: data.id, dto: data.dto });
  }
};
```

Update `handleCreateClick` to clear editing state:

```typescript
const handleCreateClick = () => {
  setEditingAccount(null);
  setIsSheetOpen(true);
};
```

- [ ] **Step 5: Add edit button to table actions**

In the table actions cell (around lines 142-148), add the Pencil button before the Delete button:

```tsx
<TableCell>
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

- [ ] **Step 6: Add edit Sheet**

After the existing create Sheet (around line 170), add the edit Sheet:

```tsx
{/* Edit Sheet */}
<Sheet open={isSheetOpen && !!editingAccount} onOpenChange={(open) => { setIsSheetOpen(open); if (!open) setEditingAccount(null); }}>
  <SheetContent side="right" className="w-full sm:max-w-lg">
    <SheetHeader>
      <SheetTitle>{t('accounts.editAccount')}</SheetTitle>
    </SheetHeader>
    <div className="flex-1 overflow-y-auto -mx-4 px-4">
      {editingAccount && (
        <AccountForm
          initialData={editingAccount}
          onSubmit={handleEditSubmit}
          onCancel={() => { setIsSheetOpen(false); setEditingAccount(null); }}
          isLoading={updateMutation.isPending}
        />
      )}
    </div>
  </SheetContent>
</Sheet>
```

Also update the existing create Sheet `open` prop (line 157) to:

```tsx
<Sheet open={isSheetOpen && !editingAccount} onOpenChange={(open) => { setIsSheetOpen(open); if (!open) setEditingAccount(null); }}>
```

- [ ] **Step 7: Run TypeScript check**

Run: `npx tsc --noEmit --pretty 2>&1 | head -30`
Expected: No errors.

- [ ] **Step 8: Commit**

```bash
git add src/pages/AccountsPage.tsx
git commit -m "feat: add account edit flow to AccountsPage with Sheet and Pencil button"
```

---

### Task 8: Add missing i18n keys

**Files:**
- Modify: `src/i18n/locales/en.json`
- Modify: `src/i18n/locales/zh.json`

- [ ] **Step 1: Check which keys are needed and add them**

Read both locale files and check for:
- `accounts.editAccount` — edit Sheet title
- `accounts.accountUpdated` — success toast
- `common.save` — edit submit button
- `common.saving` — edit submit button loading state

Add any missing keys in both files.

- [ ] **Step 2: Commit**

```bash
git add src/i18n/locales/en.json src/i18n/locales/zh.json
git commit -m "feat: add i18n keys for account editing"
```

---

### Task 9: Verify end-to-end

- [ ] **Step 1: Run all Rust tests**

Run: `cd src-tauri && cargo test --lib 2>&1 | tail -10`
Expected: All PASS.

- [ ] **Step 2: Run TypeScript check**

Run: `npx tsc --noEmit --pretty 2>&1 | head -10`
Expected: No errors.

- [ ] **Step 3: Start the app and manually test**

Run: `npm run tauri dev`

Test the following:
1. Create an account
2. Click the Pencil icon on the new account
3. Verify the Sheet opens with all fields pre-filled
4. Verify ownership and account_type are disabled
5. Edit name, icon, color
6. Submit — verify toast success and table refreshes
7. Verify the updated values appear in the table
