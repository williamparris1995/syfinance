# Preset Investment Accounts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 7 preset investment accounts that auto-create on onboarding and serve as templates for manual account creation.

**Architecture:** Hardcoded template constants in both backend (Rust) and frontend (TypeScript). Backend service method iterates templates to create accounts. Frontend template picker fills form fields. No new database tables.

**Tech Stack:** Rust (Tauri commands, domain services), React + react-hook-form (template picker), i18next (translations)

---

## File Structure

| File | Action | Purpose |
|------|--------|---------|
| `src-tauri/src/application/services/account_service.rs` | Modify | Add template constant + `create_preset_investment_accounts()` |
| `src-tauri/src/presentation/tauri_commands/account_commands.rs` | Modify | Add `setup_preset_investment_accounts` command |
| `src-tauri/src/main.rs` | Modify | Register new command |
| `src/lib/tauri/account.ts` | Modify | Add API function + frontend template constant |
| `src/pages/OnboardingPage.tsx` | Modify | Call preset command after registration |
| `src/components/AccountForm.tsx` | Modify | Add template picker for Investment type |
| `src/i18n/locales/en.json` | Modify | Add template translation keys |
| `src/i18n/locales/zh.json` | Modify | Add template translation keys |

---

### Task 1: Backend — Template constant and service method

**Files:**
- Modify: `src-tauri/src/application/services/account_service.rs`

- [ ] **Step 1: Write the failing test**

Add this test at the bottom of the `tests` module in `account_service.rs` (after the existing `test_get_account_balance` test, before the closing `}`):

```rust
    #[tokio::test]
    async fn test_create_preset_investment_accounts() {
        let account_repo = Arc::new(MockAccountRepository::new());
        let currency_repo = Arc::new(MockCurrencyRepository::new());

        let service = AccountService::new(account_repo.clone(), currency_repo);

        let result = service
            .create_preset_investment_accounts((), "CNY")
            .await;

        assert!(result.is_ok());
        let accounts = result.unwrap();
        assert_eq!(accounts.len(), 7);

        let names: Vec<&str> = accounts.iter().map(|a| a.name.as_str()).collect();
        assert!(names.contains(&"股票账户"));
        assert!(names.contains(&"基金账户"));
        assert!(names.contains(&"ETF账户"));
        assert!(names.contains(&"债券账户"));
        assert!(names.contains(&"黄金账户"));
        assert!(names.contains(&"期权账户"));
        assert!(names.contains(&"其他投资"));

        for account in &accounts {
            assert_eq!(account.account_type, AccountType::Investment);
            assert_eq!(account.ownership, Ownership::Own);
            assert_eq!(account.currency_code, "CNY");
        }
    }
```

The `AccountDto` uses typed fields: `account_type: AccountType` and `ownership: Ownership`, so we compare directly against the enum variants.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd src-tauri && cargo test test_create_preset_investment_accounts -- --nocapture`
Expected: COMPILE ERROR — method `create_preset_investment_accounts` does not exist

- [ ] **Step 3: Write implementation**

Add these imports at the top of `account_service.rs` (if not already present):

```rust
use crate::domain::aggregates::AccountType;
```

Add the template struct and constant right after the `AccountService` struct definition (after line 13, before the `impl` block):

```rust
struct InvestmentTemplate {
    name: &'static str,
    chart_code: &'static str,
    icon: &'static str,
    color: &'static str,
}

const INVESTMENT_TEMPLATES: [InvestmentTemplate; 7] = [
    InvestmentTemplate { name: "股票账户", chart_code: "1101", icon: "TrendingUp", color: "#EF4444" },
    InvestmentTemplate { name: "基金账户", chart_code: "1101", icon: "BarChart3", color: "#3B82F6" },
    InvestmentTemplate { name: "ETF账户", chart_code: "1101", icon: "Layers", color: "#8B5CF6" },
    InvestmentTemplate { name: "债券账户", chart_code: "1501", icon: "Landmark", color: "#10B981" },
    InvestmentTemplate { name: "黄金账户", chart_code: "1101", icon: "Coins", color: "#F59E0B" },
    InvestmentTemplate { name: "期权账户", chart_code: "1101", icon: "GitBranch", color: "#F97316" },
    InvestmentTemplate { name: "其他投资", chart_code: "1012", icon: "Wallet", color: "#6B7280" },
];
```

Add the method inside the `impl<R: AccountRepository, U: CurrencyRepository> AccountService<R, U>` block, after the existing `get_account_balance` method (after line 191):

```rust
    pub async fn create_preset_investment_accounts<E>(
        &self,
        _executor: E,
        currency_code: &str,
    ) -> Result<Vec<AccountDto>, AccountServiceError> {
        let currency = self
            .currency_repo
            .find_by_code(currency_code)
            .await?
            .ok_or_else(|| AccountServiceError::CurrencyNotFound(currency_code.to_string()))?;

        let mut results = Vec::new();

        for template in &INVESTMENT_TEMPLATES {
            let balance = Money::new(Decimal::ZERO, currency_code)
                .map_err(|e| AccountServiceError::InvalidMoney(e.to_string()))?;

            match Account::new(
                Uuid::new_v4(),
                template.name,
                AccountType::Investment,
                Ownership::Own,
                &currency,
                balance,
                template.icon,
                template.color,
                Some(template.chart_code.to_string()),
                None,
                SyncMetadata::new(Uuid::new_v4()),
            ) {
                Ok(account) => {
                    if self.account_repo.create(&account).await.is_ok() {
                        results.push(AccountDto::from(account));
                    }
                }
                Err(_) => continue,
            }
        }

        Ok(results)
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd src-tauri && cargo test test_create_preset_investment_accounts -- --nocapture`
Expected: PASS

- [ ] **Step 5: Run all existing tests to check for regressions**

Run: `cd src-tauri && cargo test -- --nocapture`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add src-tauri/src/application/services/account_service.rs
git commit -m "feat: add preset investment account templates and service method"
```

---

### Task 2: Backend — Tauri command and registration

**Files:**
- Modify: `src-tauri/src/presentation/tauri_commands/account_commands.rs`
- Modify: `src-tauri/src/main.rs`

- [ ] **Step 1: Add the Tauri command**

In `src-tauri/src/presentation/tauri_commands/account_commands.rs`, add this helper function and command after the existing `list_accounts_with_balances` function (after line 184):

```rust
pub async fn setup_preset_investment_accounts_with_state(
    state: &AppState,
    currency_code: Option<String>,
) -> Result<Vec<AccountDto>, String> {
    let code = currency_code.as_deref().unwrap_or("CNY");
    state
        .service()
        .create_preset_investment_accounts(state.pool(), code)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn setup_preset_investment_accounts(
    state: State<'_, AppState>,
    currency_code: Option<String>,
) -> Result<Vec<AccountDto>, String> {
    setup_preset_investment_accounts_with_state(state.inner(), currency_code).await
}
```

- [ ] **Step 2: Register the command in main.rs**

In `src-tauri/src/main.rs`, update the import line for `account_commands` to include the new command. The current import is:

```rust
    account_commands::{
        create_account, delete_account, get_account, get_account_balance, list_accounts,
        list_accounts_by_ownership, list_accounts_with_balances, update_account, AppState,
    },
```

Change it to:

```rust
    account_commands::{
        create_account, delete_account, get_account, get_account_balance, list_accounts,
        list_accounts_by_ownership, list_accounts_with_balances, setup_preset_investment_accounts,
        update_account, AppState,
    },
```

Then in the `invoke_handler` macro (around line 158), add `setup_preset_investment_accounts` to the list. Add it after `get_account_balance` (line 166):

```rust
            get_account_balance,
            setup_preset_investment_accounts,
```

- [ ] **Step 3: Build to verify compilation**

Run: `cd src-tauri && cargo build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/presentation/tauri_commands/account_commands.rs src-tauri/src/main.rs
git commit -m "feat: add setup_preset_investment_accounts Tauri command"
```

---

### Task 3: Frontend — API function and template constant

**Files:**
- Modify: `src/lib/tauri/account.ts`

- [ ] **Step 1: Add the template interface, constant, and API function**

At the bottom of `src/lib/tauri/account.ts`, add:

```typescript
export interface InvestmentTemplate {
  name: string;
  chart_code: string;
  icon: string;
  color: string;
}

export const INVESTMENT_TEMPLATES: InvestmentTemplate[] = [
  { name: '股票账户', chart_code: '1101', icon: 'TrendingUp', color: '#EF4444' },
  { name: '基金账户', chart_code: '1101', icon: 'BarChart3', color: '#3B82F6' },
  { name: 'ETF账户', chart_code: '1101', icon: 'Layers', color: '#8B5CF6' },
  { name: '债券账户', chart_code: '1501', icon: 'Landmark', color: '#10B981' },
  { name: '黄金账户', chart_code: '1101', icon: 'Coins', color: '#F59E0B' },
  { name: '期权账户', chart_code: '1101', icon: 'GitBranch', color: '#F97316' },
  { name: '其他投资', chart_code: '1012', icon: 'Wallet', color: '#6B7280' },
];

export const setupPresetInvestmentAccounts = (currencyCode?: string) =>
  invokeTauri<AccountDto[]>('setup_preset_investment_accounts', {
    currencyCode: currencyCode ?? 'CNY',
  });
```

- [ ] **Step 2: Verify TypeScript compilation**

Run: `cd c:/Users/BuHiYo-001/Desktop/projects/fiance && npx tsc --noEmit`
Expected: No errors related to the new code

- [ ] **Step 3: Commit**

```bash
git add src/lib/tauri/account.ts
git commit -m "feat: add frontend investment templates and setup API function"
```

---

### Task 4: Frontend — Onboarding integration

**Files:**
- Modify: `src/pages/OnboardingPage.tsx`

- [ ] **Step 1: Add preset account creation to onboarding flow**

Add the import at the top of `OnboardingPage.tsx` (after the existing imports):

```typescript
import { setupPresetInvestmentAccounts } from '../lib/tauri/account';
```

Modify the `handleComplete` function (line 51-53). Current:

```typescript
  const handleComplete = () => {
    navigate({ to: '/' });
  };
```

Change to:

```typescript
  const handleComplete = async () => {
    try {
      await setupPresetInvestmentAccounts('CNY');
    } catch {
      // Preset creation failure should not block navigation
    }
    navigate({ to: '/' });
  };
```

Also modify the `linkMutation` `onSuccess` callback (line 27-29). Current:

```typescript
    onSuccess: () => {
      navigate({ to: '/' });
    },
```

Change to:

```typescript
    onSuccess: async () => {
      try {
        await setupPresetInvestmentAccounts('CNY');
      } catch {
        // Preset creation failure should not block navigation
      }
      navigate({ to: '/' });
    },
```

- [ ] **Step 2: Verify TypeScript compilation**

Run: `cd c:/Users/BuHiYo-001/Desktop/projects/fiance && npx tsc --noEmit`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add src/pages/OnboardingPage.tsx
git commit -m "feat: call setup_preset_investment_accounts during onboarding"
```

---

### Task 5: Frontend — AccountForm template picker

**Files:**
- Modify: `src/components/AccountForm.tsx`

- [ ] **Step 1: Add imports and template picker component**

Add these imports at the top of `AccountForm.tsx` (after existing imports):

```typescript
import { TrendingUp, BarChart3, Layers, Landmark, Coins, GitBranch, Wallet } from 'lucide-react';
import { INVESTMENT_TEMPLATES } from '@/lib/tauri/account';
```

Note: Check that these Lucide icons are available. If `Coins` is not available, use `CircleDollarSign` instead.

Add a `useState` for tracking the selected template. Inside the `AccountForm` function, after line 74 (`const isEditMode = mode === 'edit';`), add:

```typescript
  const [selectedTemplate, setSelectedTemplate] = useState<number | null>(null);
```

Add the `useState` import if not already present:

```typescript
import { useState } from 'react';
```

Now add the template picker UI. After the ownership toggle `</FormField>` (after the closing `/>` of the ownership FormField, around line 226), and before the Name FormField (line 229), insert:

```typescript
          {/* Investment Template Picker */}
          {!isEditMode && accountType === 'Investment' && (
            <FormItem>
              <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                {t('accountForm.selectTemplate')}
                <span className="text-muted-foreground/50 font-normal"> — optional</span>
              </FormLabel>
              <div className="grid grid-cols-4 gap-2">
                {INVESTMENT_TEMPLATES.map((template, index) => {
                  const IconComponent = [TrendingUp, BarChart3, Layers, Landmark, Coins, GitBranch, Wallet][index];
                  return (
                    <button
                      key={template.name}
                      type="button"
                      onClick={() => {
                        setSelectedTemplate(index);
                        form.setValue('name', template.name);
                        form.setValue('icon', template.icon);
                        form.setValue('color', template.color);
                        form.setValue('chart_code', template.chart_code);
                      }}
                      className={cn(
                        "flex flex-col items-center gap-1 rounded-lg border p-2 text-xs transition-all",
                        selectedTemplate === index
                          ? "border-primary bg-primary/10 ring-1 ring-primary"
                          : "border-input hover:border-primary/50 hover:bg-muted"
                      )}
                    >
                      <IconComponent
                        className="h-4 w-4"
                        style={{ color: template.color }}
                      />
                      <span className="truncate w-full text-center">{template.name}</span>
                    </button>
                  );
                })}
              </div>
            </FormItem>
          )}
```

Note: This uses a `<FormItem>` without a `<FormField>` wrapper, which is valid in shadcn/ui for non-form-field display groups. If the codebase requires `<FormField>`, wrap it but use a hidden field.

- [ ] **Step 2: Verify TypeScript compilation**

Run: `cd c:/Users/BuHiYo-001/Desktop/projects/fiance && npx tsc --noEmit`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add src/components/AccountForm.tsx
git commit -m "feat: add investment template picker to AccountForm"
```

---

### Task 6: Frontend — i18n translations

**Files:**
- Modify: `src/i18n/locales/en.json`
- Modify: `src/i18n/locales/zh.json`

- [ ] **Step 1: Add translation keys to zh.json**

Find the `"accountForm"` section in `src/i18n/locales/zh.json` and add this key inside it (alongside the existing keys like `"accountName"`, etc.):

```json
"selectTemplate": "选择投资模板",
```

- [ ] **Step 2: Add translation keys to en.json**

Find the `"accountForm"` section in `src/i18n/locales/en.json` and add this key inside it:

```json
"selectTemplate": "Select Investment Template",
```

- [ ] **Step 3: Verify JSON is valid**

Run: `node -e "JSON.parse(require('fs').readFileSync('src/i18n/locales/zh.json','utf8')); console.log('zh.json OK')" && node -e "JSON.parse(require('fs').readFileSync('src/i18n/locales/en.json','utf8')); console.log('en.json OK')"`
Expected: Both print "OK"

- [ ] **Step 4: Commit**

```bash
git add src/i18n/locales/en.json src/i18n/locales/zh.json
git commit -m "feat: add i18n keys for investment template picker"
```

---

### Task 7: Build verification

**Files:** None — verification only

- [ ] **Step 1: Run Rust tests**

Run: `cd src-tauri && cargo test -- --nocapture`
Expected: All tests pass

- [ ] **Step 2: Run frontend type check**

Run: `cd c:/Users/BuHiYo-001/Desktop/projects/fiance && npx tsc --noEmit`
Expected: No errors

- [ ] **Step 3: Run frontend tests**

Run: `cd c:/Users/BuHiYo-001/Desktop/projects/fiance && npx vitest run`
Expected: All tests pass

- [ ] **Step 4: Build the full application**

Run: `cd c:/Users/BuHiYo-001/Desktop/projects/fiance && npm run build`
Expected: Build succeeds
