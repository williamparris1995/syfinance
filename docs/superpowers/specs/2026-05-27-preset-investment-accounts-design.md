# Preset Investment Accounts Design

**Date:** 2026-05-27
**Status:** Approved

## Overview

Add 7 preset investment accounts mapped to the existing SecurityType enum (Stock, Fund, Etf, Bond, Gold, Option, Other). Two usage scenarios:

1. **Onboarding auto-creation**: All 7 accounts created automatically after device registration
2. **Template-based creation**: When creating an Investment account, user can pick a template to pre-fill form fields

## Preset Data

| SecurityType | Account Name | chart_code | Icon | Color |
|---|---|---|---|---|
| Stock | 股票账户 | `1101` | TrendingUp | `#EF4444` |
| Fund | 基金账户 | `1101` | BarChart3 | `#3B82F6` |
| Etf | ETF账户 | `1101` | Layers | `#8B5CF6` |
| Bond | 债券账户 | `1501` | Landmark | `#10B981` |
| Gold | 黄金账户 | `1101` | Coins | `#F59E0B` |
| Option | 期权账户 | `1101` | GitBranch | `#F97316` |
| Other | 其他投资 | `1012` | Wallet | `#6B7280` |

All accounts: `account_type: Investment`, `ownership: own`, `currency_code: CNY`, `initial_balance: 0`.

Chart codes:
- `1101` 交易性金融资产 — short-term trading assets (stock, fund, ETF, gold, option)
- `1501` 持有至到期投资 — held-to-maturity investments (bonds)
- `1012` 其他货币资金 — fallback (other)

## Backend

### Template constant

Define in `account_service.rs`:

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

### New service method

`AccountService::create_preset_investment_accounts(executor, currency_code)`:
- Iterate over `INVESTMENT_TEMPLATES`
- For each: create `Account::new()` with `Uuid::new_v4()` + `SyncMetadata::new()` + `AccountType::Investment` + `Ownership::Own`
- Persist via `account_repo.create()`
- Return `Vec<AccountDto>`

### New Tauri command

`setup_preset_investment_accounts(state)`:
- Accept optional `currency_code` param (default `"CNY"`)
- Call `account_service.create_preset_investment_accounts()`
- Register in `main.rs`

### Error handling

- Individual account creation failures do not block remaining accounts
- UUID primary key prevents duplicates on repeated calls
- Frontend call failure does not block navigation; show toast on error

## Frontend

### OnboardingPage

After registration/linking succeeds and before navigating to `/`, call:
```typescript
await setupPresetInvestmentAccounts({ currencyCode: 'CNY' });
```

### AccountForm template selection

When `account_type` is `Investment`:
- Show template picker at top of form: 7 cards with name, icon, color
- Clicking a template fills: `name`, `icon`, `color`, `chart_code`
- All fields remain editable after selection
- No template selected = existing empty form behavior unchanged

### API function

Add to `src/lib/tauri/account.ts`:
```typescript
export const setupPresetInvestmentAccounts = (params?: { currencyCode?: string }) =>
  invokeTauri<void>('setup_preset_investment_accounts', params);
```

Add frontend template constant array matching the backend templates for the template picker UI.

### i18n

Add translation keys in `en.json` and `zh.json` for:
- Template names
- Template picker label

## Files to Modify

**Backend (Rust):**
- `src-tauri/src/application/services/account_service.rs` — template constant + `create_preset_investment_accounts()`
- `src-tauri/src/presentation/tauri_commands/account_commands.rs` — new command
- `src-tauri/src/main.rs` — register command

**Frontend (React/TS):**
- `src/pages/OnboardingPage.tsx` — call preset command after registration
- `src/components/AccountForm.tsx` — template picker for Investment type
- `src/lib/tauri/account.ts` — API function + frontend template constant
- `src/i18n/locales/en.json` — English translations
- `src/i18n/locales/zh.json` — Chinese translations

## Out of Scope

- No new database tables or migrations
- No changes to existing `create_account` flow
- No changes to Holdings system
