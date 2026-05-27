# Subscription / Recurring Transactions Design

## Context

Users have periodic financial commitments: monthly subscriptions (Netflix, gym), rent, annual insurance, and periodic income (salary, rental income). These need tracking, automatic recording, and notification. The system already supports one-shot transactions, debt payment schedules, and prepaid top-ups — but no recurring/subscription concept.

## Requirements

1. **Fixed + variable amounts**: Default amount per cycle, user can edit individual generated transactions
2. **Expense + Income**: Both subscription expenses and recurring income
3. **Auto-record + notification**: On billing date, automatically create a double-entry transaction and send notification
4. **Dynamic generation**: No pre-generated schedule table — store rule, generate on-demand
5. **CRUD + lifecycle**: Create, edit, delete, pause, resume subscriptions
6. **UI**: List with cycle filter, sort, expandable transaction history per subscription

## Data Model

### New table: `subscriptions`

| Column | Type | Description |
|--------|------|-------------|
| id | TEXT (UUID PK) | Primary key |
| name | TEXT NOT NULL | Display name (e.g. "Netflix", "房租") |
| amount | DECIMAL NOT NULL | Default amount per cycle |
| direction | TEXT NOT NULL CHECK IN ('expense','income') | Flow direction |
| cycle | TEXT NOT NULL CHECK IN ('weekly','monthly','yearly','custom') | Recurrence type |
| cycle_days | INTEGER | For custom: every N days. NULL for others |
| billing_day | INTEGER | For monthly: day of month (1-31). For yearly: month-day. NULL for weekly |
| next_billing_date | DATE NOT NULL | Next billing date (drives auto-recording) |
| start_date | DATE NOT NULL | Subscription start |
| end_date | DATE | Optional end date. NULL = ongoing |
| auto_record | BOOLEAN NOT NULL DEFAULT 1 | Whether to auto-create transactions |
| paused | BOOLEAN NOT NULL DEFAULT 0 | Paused subscriptions skip auto-recording |
| source_account_id | TEXT (UUID) NOT NULL FK | Account that pays/receives |
| category | TEXT | Optional user category |
| description | TEXT | Notes |
| last_transaction_id | TEXT (UUID) | Last generated transaction |
| + sync columns | | deleted_at, updated_at, device_id, synced_at |

### Relationships

- `subscriptions.source_account_id` → `accounts.id` (which account pays/receives)
- Generated transactions are standard `transactions` + `transaction_entries` — no special link table. Each generated transaction has `description` containing the subscription name for lookup.

### Double-entry entries for auto-recorded transactions

**Expense subscription** (e.g. Netflix ¥68/month, paid from bank account):
- Debit: subscription expense chart code (e.g. `5401`) = amount
- Credit: source_account's bank chart code (e.g. `1002`) = amount

**Income subscription** (e.g. salary ¥15000/month, received in bank):
- Debit: source_account's bank chart code (e.g. `1002`) = amount
- Credit: income chart code (e.g. `4201`) = amount

## Backend Architecture

### Files to create

```
src-tauri/src/domain/aggregates/subscription.rs
src-tauri/src/domain/repositories/mod.rs          (add SubscriptionRepository trait)
src-tauri/src/infrastructure/repositories/subscription_repository.rs
src-tauri/src/application/dtos/subscription_dto.rs
src-tauri/src/application/services/subscription_service.rs
src-tauri/src/presentation/tauri_commands/subscription_commands.rs
```

### Files to modify

```
src-tauri/src/domain/mod.rs              (add subscription module)
src-tauri/src/domain/repositories/mod.rs (add SubscriptionRepository trait)
src-tauri/src/infrastructure/repositories/mod.rs (add subscription_repository module)
src-tauri/src/application/dtos/mod.rs    (re-export subscription DTOs)
src-tauri/src/application/mod.rs         (add subscription_service module)
src-tauri/src/presentation/tauri_commands/mod.rs (add subscription_commands module)
src-tauri/src/main.rs                    (register commands + scheduler)
migrations/                              (new migration for subscriptions table)
```

### Domain: `Subscription` aggregate

```rust
enum SubscriptionCycle { Weekly, Monthly, Yearly, Custom { days: u32 } }

struct Subscription {
    id: Uuid, name: String, amount: Decimal,
    direction: Direction, // Expense | Income
    cycle: SubscriptionCycle,
    billing_day: Option<u8>,
    next_billing_date: NaiveDate,
    start_date: NaiveDate, end_date: Option<NaiveDate>,
    auto_record: bool, paused: bool,
    source_account_id: Uuid,
    category: Option<String>, description: Option<String>,
    last_transaction_id: Option<Uuid>,
}

impl Subscription {
    fn calculate_next_billing_date(&self) -> Option<NaiveDate>;
    fn is_due(&self, today: NaiveDate) -> bool;
    fn pause(&mut self);
    fn resume(&mut self);
}
```

`calculate_next_billing_date` reuses the same logic as `RepeatPattern::calculate_next_occurrence` from the reminder module.

### Service: `SubscriptionService`

Key methods:

- `create(dto: CreateSubscriptionDto) -> Uuid` — validate account, create subscription
- `update(id, dto: UpdateSubscriptionDto)` — edit name/amount/cycle/etc
- `delete(id)` — soft-delete
- `pause(id)` / `resume(id)` — toggle paused flag
- `list(filters: SubscriptionFilters) -> Vec<SubscriptionDto>` — with cycle/direction/paused filters
- `get_by_id(id) -> SubscriptionDto`
- `list_transactions(subscription_id) -> Vec<TransactionDto>` — find transactions by description matching subscription name
- `process_due_subscriptions(today: NaiveDate)` — called by scheduler, iterates due subscriptions, creates transactions, updates next_billing_date

### Scheduler integration

In `main.rs` setup block, alongside the existing reminder scheduler, add:

```rust
tokio::spawn(async move {
    let mut interval = tokio::time::interval(Duration::from_secs(300));
    loop {
        interval.tick().await;
        if let Err(e) = subscription_service.process_due_subscriptions(today).await {
            error!("Failed to process subscriptions: {}", e);
        }
    }
});
```

### Tauri Commands

```
create_subscription
update_subscription
delete_subscription
pause_subscription
resume_subscription
list_subscriptions          (accepts optional direction/cycle/paused filters)
get_subscription
list_subscription_transactions (transactions for a subscription)
```

## Frontend Architecture

### Files to create

```
src/lib/tauri/subscription.ts            (API client)
src/components/SubscriptionForm.tsx       (create/edit form)
src/pages/SubscriptionsPage.tsx           (list page)
```

### Files to modify

```
src/App.tsx                               (add route)
src/components/layout/Sidebar.tsx         (add nav item)
src/i18n/locales/zh.json                  (i18n keys)
src/i18n/locales/en.json                  (i18n keys)
```

### SubscriptionsPage

Layout pattern follows HoldingsPage:

- **Summary cards**: 本月订阅支出 / 本月订阅收入 / 活跃订阅数 / 下次扣款倒计时
- **Filter bar**: 周期筛选 (全部/每周/每月/每年/自定义) + 方向toggle (支出/收入) + 搜索框
- **Sort**: 按下次扣款日 / 金额 / 名称
- **List**: 表格行展示订阅名称、金额、周期、下次扣款日、状态(活跃/暂停)
- **Expand**: 点击行展开显示关联交易记录列表（复用 HoldingsPage 的 ChevronRight/Down 展开模式）
- **Actions**: 编辑、暂停/恢复、删除
- **Create**: 右上角按钮打开 Sheet 侧边栏表单

### SubscriptionForm

Sheet container, follows DebtForm pattern:

- 名称 (text input)
- 金额 (number with ¥ prefix)
- 方向 (支出/收入 pill toggle)
- 周期 (Select: 每周/每月/每年/自定义)
- 自定义天数 (number, conditional on cycle=custom)
- 扣款日 (number, conditional on monthly/yearly)
- 付款/收款账户 (Select, filtered by account type)
- 自动记账 (Switch toggle)
- 开始日期 / 结束日期 (date inputs)
- 描述 (optional textarea)

## Transaction Lookup Strategy

Subscriptions don't have a direct FK to generated transactions. Instead:

- Each auto-generated transaction has `description: "{subscription_name} - {billing_date}"`
- `list_subscription_transactions` queries transactions where `description LIKE '{subscription_name}%'` ordered by date DESC
- `last_transaction_id` is stored on the subscription for quick access to the most recent one

This avoids a join table and keeps the transaction system unchanged.

## Reused Patterns

| Pattern | Source Module | What's Reused |
|---------|---------------|---------------|
| Sheet + react-hook-form + zod | DebtForm, TopUpDialog | Form UI pattern |
| Double-entry transaction creation | DebtService, HoldingService | TransactionEntry building |
| RepeatPattern + calculate_next | Reminder | Billing date calculation |
| Scheduler loop (5-min interval) | ReminderScheduler | Background task pattern |
| TauriNotificationSender | Reminder | Push notifications |
| Soft-delete | All modules | deleted_at pattern |
| Expand row for detail | HoldingsPage | Trade history expand |
| Filter + sort bar | HoldingsPage | Filter UI pattern |

## Out of Scope

- Variable amount per billing (user can edit generated transactions manually)
- Multi-currency subscriptions (follow source account currency)
- Subscription sharing/splitting
- Billing history export
