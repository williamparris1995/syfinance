> **ℹ️ 历史快照 — 注**: 云备份与多设备同步已于 2026-07-25 取消(御财 server+Postgres 已集中持久化数据)。本文为时点快照,相关内容仅作历史记录。

# YuCai Functional Modules Design Spec

> Date: 2026-06-09
> Status: Draft
> Prerequisite: [Architecture Redesign Spec](./2026-06-09-architecture-redesign-design.md)

This document covers all post-MVP functional modules that will be migrated from the current Tauri/Rust implementation to Go/Flutter. Each module follows the same Explicit Architecture pattern defined in the architecture spec.

---

## 1. Budget Module

### 1.1 Domain Model

**Aggregate Root: Budget**

| Field | Go Type | Notes |
|-------|---------|-------|
| id | uuid.UUID | |
| tenant_id | uuid.UUID | FK → tenants |
| name | string | e.g. "5月预算" |
| month | string | Format "YYYY-MM" |
| total_amount_cents | int64 | Sum of all items' planned_amount_cents |
| currency_code | string | ISO 4217 |
| is_active | bool | Default true |
| items | []BudgetItem | Child value objects |
| version | int64 | Optimistic lock |
| created_at | time.Time | |
| updated_at | time.Time | |

**Value Object: BudgetItem**

| Field | Go Type | Notes |
|-------|---------|-------|
| id | uuid.UUID | |
| budget_id | uuid.UUID | FK → budgets |
| category_account_id | uuid.UUID | Links to category or account |
| planned_amount_cents | int64 | Budgeted amount |
| actual_amount_cents | int64 | Default 0 |
| notes | *string | Optional |

**Domain Methods:**
- `AddItem(item)` — appends, adds planned to total
- `RemoveItem(id)` — removes, subtracts planned from total
- `UpdateItemAmount(id, newAmount)` — adjusts total by delta
- `TotalActual() int64` — sums items' actual amounts
- `TotalRemaining() int64` — total - actual
- `OverallUsagePct() float64` — (actual / total) * 100
- `IsOverBudget() bool` — actual > total
- `Deactivate()` / `Activate()` — toggle is_active
- `CloneToMonth(targetMonth string) *Budget` — deep copy to new month

**Domain Events:**
- `BudgetCreated`
- `BudgetItemAdded`
- `BudgetDeactivated`

### 1.2 gRPC Service

```protobuf
service BudgetService {
  // Commands
  rpc CreateBudget(CreateBudgetRequest) returns (BudgetResponse);
  rpc DeleteBudget(DeleteBudgetRequest) returns (google.protobuf.Empty);
  rpc AddBudgetItem(AddBudgetItemRequest) returns (BudgetResponse);
  rpc RemoveBudgetItem(RemoveBudgetItemRequest) returns (BudgetResponse);
  rpc ComputeBudgetActuals(ComputeActualsRequest) returns (BudgetResponse);
  rpc CloneBudgetToMonth(CloneBudgetRequest) returns (BudgetResponse);

  // Queries
  rpc GetBudget(GetBudgetRequest) returns (BudgetDetailResponse);
  rpc GetBudgetByMonth(GetBudgetByMonthRequest) returns (BudgetDetailResponse);
  rpc ListBudgets(ListBudgetsRequest) returns (ListBudgetsResponse);
}
```

### 1.3 entGo Schema — Key Tables

| Table | Key Columns | Constraints |
|-------|-------------|-------------|
| budgets | id, tenant_id, name, month, total_amount_cents, currency_code, is_active, version, timestamps | UNIQUE(tenant_id, month) |
| budget_items | id, budget_id FK, category_account_id, planned_amount_cents, actual_amount_cents, notes | FK → budgets ON DELETE CASCADE |

### 1.4 Flutter Module Structure

```
budget/
├── domain/
│   ├── budget_entity.dart
│   ├── budget_item.dart
│   ├── budget_repository.dart
│   └── create_budget_usecase.dart
├── data/
│   ├── budget_repository_impl.dart
│   ├── budget_remote_ds.dart
│   ├── budget_local_ds.dart
│   └── budget_mapper.dart
├── bloc/
│   ├── budget_bloc.dart
│   ├── budget_event.dart
│   └── budget_state.dart
└── presentation/
    ├── budget_page.dart
    ├── budget_detail_page.dart
    └── widgets/
        ├── budget_progress_card.dart
        └── budget_item_form.dart
```

### 1.5 Migration Notes

- Tauri Budget uses `String` IDs → Go uses `uuid.UUID`
- Tauri Budget has no `SyncMetadata` → Go uses `version` + `tenant_id`
- `compute_budget_actuals` in Tauri is a command that recalculates → Go will compute actuals from transaction entries on query (no separate command needed)

---

## 2. Goal Module

### 2.1 Domain Model

**Aggregate Root: Goal**

| Field | Go Type | Notes |
|-------|---------|-------|
| id | uuid.UUID | |
| tenant_id | uuid.UUID | FK → tenants |
| name | string | |
| goal_type | GoalType | Enum: savings / debt_payoff / investment |
| target_amount_cents | int64 | |
| current_amount_cents | int64 | Default 0 |
| currency_code | string | |
| deadline | *time.Time | Optional |
| linked_account_id | *uuid.UUID | Optional account link |
| notes | *string | |
| is_completed | bool | Default false |
| completed_at | *time.Time | |
| version | int64 | |
| created_at | time.Time | |
| updated_at | time.Time | |

**Enum: GoalType**

| Value | Protobuf |
|-------|----------|
| savings | GOAL_TYPE_SAVINGS |
| debt_payoff | GOAL_TYPE_DEBT_PAYOFF |
| investment | GOAL_TYPE_INVESTMENT |

**Domain Methods:**
- `ProgressPct() float64` — (current / target) * 100
- `RemainingAmount() int64` — target - current
- `IsOverdue() bool` — deadline past AND not completed
- `AddProgress(amount int64) error` — adds to current; auto-completes when current >= target
- `MarkCompleted()` — sets is_completed=true, completed_at=now
- `SetDeadline(d time.Time)` — sets deadline
- `LinkAccount(accountID uuid.UUID)` — links account

**Domain Events:**
- `GoalCreated`
- `GoalProgressUpdated`
- `GoalCompleted`

### 2.2 gRPC Service

```protobuf
service GoalService {
  // Commands
  rpc CreateGoal(CreateGoalRequest) returns (GoalResponse);
  rpc UpdateGoal(UpdateGoalRequest) returns (GoalResponse);
  rpc UpdateGoalProgress(UpdateProgressRequest) returns (GoalResponse);
  rpc CompleteGoal(CompleteGoalRequest) returns (GoalResponse);
  rpc DeleteGoal(DeleteGoalRequest) returns (google.protobuf.Empty);
  rpc SyncGoalProgress(SyncGoalProgressRequest) returns (GoalResponse);

  // Queries
  rpc GetGoal(GetGoalRequest) returns (GoalDetailResponse);
  rpc ListGoals(ListGoalsRequest) returns (ListGoalsResponse);
}
```

### 2.3 entGo Schema

| Table | Key Columns | Constraints |
|-------|-------------|-------------|
| goals | id, tenant_id, name, goal_type, target_amount_cents, current_amount_cents, currency_code, deadline, linked_account_id, notes, is_completed, completed_at, version, timestamps | INDEX(tenant_id, is_completed) |

### 2.4 Flutter Pages

- `GoalsPage` — goal list with progress bars
- `GoalDetailPage` — progress chart + linked account info
- `GoalFormPage` — create/edit goal form

### 2.5 Migration Notes

- `sync_goal_progress` command recalculates current_amount from linked account → Go will compute on query
- Auto-complete logic (current >= target) preserved in domain service

---

## 3. Debt Module

### 3.1 Domain Model

**Aggregate Root: DebtDetails** (1:1 extension of Account for liability accounts)

| Field | Go Type | Notes |
|-------|---------|-------|
| id | uuid.UUID | |
| tenant_id | uuid.UUID | |
| account_id | uuid.UUID | FK → accounts (UNIQUE, 1:1) |
| counterparty | string | Lender name |
| interest_rate | float64 | Annual rate (0.05 = 5%) |
| amortization_method | AmortizationMethod | Enum |
| start_date | time.Time | |
| due_date | time.Time | |
| total_principal_cents | int64 | |
| payment_schedule | []PaymentScheduleEntry | Generated |
| version | int64 | |
| timestamps | — | |

**Enum: AmortizationMethod**

| Value | Description | Protobuf |
|-------|-------------|----------|
| equal_principal_interest | 等额本息 | AMORTIZATION_EQUAL_PRINCIPAL_INTEREST |
| equal_principal | 等额本金 | AMORTIZATION_EQUAL_PRINCIPAL |
| lump_sum | 到期一次还本付息 | AMORTIZATION_LUMP_SUM |

**Value Object: PaymentScheduleEntry**

| Field | Go Type | Notes |
|-------|---------|-------|
| id | uuid.UUID | |
| debt_id | uuid.UUID | FK → debt_details |
| payment_date | time.Time | |
| principal_amount_cents | int64 | |
| interest_amount_cents | int64 | |
| total_amount_cents | int64 | principal + interest |
| paid | bool | |
| paid_amount_cents | int64 | For partial payments |
| transaction_id | *uuid.UUID | Linked transaction |

**Domain Methods:**
- `GenerateSchedule()` — clears existing, dispatches to amortization method
- **LumpSum**: single entry at due_date; interest = principal * rate * (months/12)
- **EqualPrincipalInterest**: monthly rate = rate/12; payment = P * r * (1+r)^n / ((1+r)^n - 1)
- **EqualPrincipal**: fixed monthly principal = total/months; interest = remaining * monthly_rate
- `MarkPaid(scheduleID, transactionID) error` — returns error if already paid
- `RemainingPrincipal() int64` — sums paid principal from schedule
- `TermInMonths() int` — calculated from start_date to due_date

**Domain Events:**
- `DebtCreated`
- `PaymentRecorded`
- `DebtPaidOff`

### 3.2 gRPC Service

```protobuf
service DebtService {
  // Commands
  rpc CreateDebt(CreateDebtRequest) returns (DebtResponse);
  rpc UpdateDebt(UpdateDebtRequest) returns (DebtResponse);
  rpc DeleteDebt(DeleteDebtRequest) returns (google.protobuf.Empty);
  rpc RecordPayment(RecordPaymentRequest) returns (RecordPaymentResponse);

  // Queries
  rpc GetDebt(GetDebtRequest) returns (DebtDetailResponse);
  rpc ListDebts(ListDebtsRequest) returns (ListDebtsResponse);
  rpc GetUpcomingPayments(GetUpcomingPaymentsRequest) returns (ListDebtsResponse);
}
```

### 3.3 entGo Schema

| Table | Key Columns | Constraints |
|-------|-------------|-------------|
| debt_details | id, tenant_id, account_id UNIQUE, counterparty, interest_rate, amortization_method, start_date, due_date, total_principal_cents, version, timestamps | FK account_id → accounts |
| payment_schedule | id, debt_id FK, payment_date, principal_amount_cents, interest_amount_cents, total_amount_cents, paid, paid_amount_cents, transaction_id, timestamps | FK → debt_details ON DELETE CASCADE |

### 3.4 Migration Notes

- Amortization calculation formulas are complex — write comprehensive unit tests ported from Rust
- `RecordPayment` is a composite operation: creates transaction entries + marks schedule entry paid
- Yahoo Finance integration for security prices is in holding module, not debt

---

## 4. Holding Module (Investment)

### 4.1 Domain Model

**Entity: Security** (reference data, not aggregate root per tenant)

| Field | Go Type | Notes |
|-------|---------|-------|
| id | uuid.UUID | |
| symbol | string | e.g. "600519" |
| name | string | e.g. "贵州茅台" |
| security_type | SecurityType | Enum |
| exchange | *string | e.g. "SHA", "SHE", "HKG" |
| currency_code | string | |
| current_price_cents | *int64 | Nullable, updated from market |

**Enum: SecurityType**

| Value | Protobuf |
|-------|----------|
| stock | SECURITY_TYPE_STOCK |
| fund | SECURITY_TYPE_FUND |
| etf | SECURITY_TYPE_ETF |
| bond | SECURITY_TYPE_BOND |
| gold | SECURITY_TYPE_GOLD |
| option | SECURITY_TYPE_OPTION |
| other | SECURITY_TYPE_OTHER |

**Entity: Holding** (current position per account+security)

| Field | Go Type | Notes |
|-------|---------|-------|
| id | uuid.UUID | |
| tenant_id | uuid.UUID | |
| account_id | uuid.UUID | FK → accounts |
| security_id | uuid.UUID | FK → securities |
| quantity | float64 | Decimal precision needed |
| avg_cost_cents | int64 | Weighted average cost basis |
| version | int64 | |
| timestamps | — | |

**Constraint**: UNIQUE(tenant_id, account_id, security_id)

**Entity: HoldingTransaction** (append-only trade ledger)

| Field | Go Type | Notes |
|-------|---------|-------|
| id | uuid.UUID | |
| tenant_id | uuid.UUID | |
| account_id | uuid.UUID | |
| security_id | uuid.UUID | |
| trade_type | TradeType | BUY / SELL / DIVIDEND / SPLIT |
| quantity | float64 | |
| price_cents | int64 | |
| amount_cents | int64 | quantity * price |
| fee_cents | int64 | |
| trade_date | time.Time | |
| transaction_id | *uuid.UUID | Optional link to accounting transaction |
| notes | *string | |
| timestamps | — | |

**Domain Methods on Holding:**
- `ApplyBuy(trade)` — new avg = (old_avg * old_qty + amount + fee) / new_qty
- `ApplySell(trade)` — realized P&L = (price - avg_cost) * quantity - fee
- `MarketValue(currentPrice) int64` — quantity * price
- `UnrealizedPnL(currentPrice) int64` — (price - avg_cost) * quantity
- `ApplyDividend(cashPerShare, totalAmount)` — no quantity/avg change
- `ApplySplit(ratio)` — quantity *= ratio, avg_cost /= ratio

**Domain Events:**
- `HoldingPurchased`
- `HoldingSold`
- `DividendRecorded`
- `SplitApplied`

### 4.2 gRPC Service

```protobuf
service HoldingService {
  // Security CRUD
  rpc CreateSecurity(CreateSecurityRequest) returns (SecurityResponse);
  rpc ListSecurities(ListSecuritiesRequest) returns (ListSecuritiesResponse);
  rpc UpdateSecurityPrice(UpdatePriceRequest) returns (google.protobuf.Empty);
  rpc SearchSecurities(SearchSecuritiesRequest) returns (SearchSecuritiesResponse);
  rpc FetchSecurityPrice(FetchPriceRequest) returns (FetchPriceResponse);

  // Holding operations
  rpc BuyHolding(HoldingTradeRequest) returns (HoldingTransactionResponse);
  rpc SellHolding(HoldingTradeRequest) returns (HoldingTransactionResponse);
  rpc RecordDividend(RecordDividendRequest) returns (HoldingTransactionResponse);
  rpc RecordSplit(RecordSplitRequest) returns (HoldingTransactionResponse);
  rpc DeleteHoldingTrade(DeleteTradeRequest) returns (google.protobuf.Empty);
  rpc UpdateHoldingTrade(UpdateTradeRequest) returns (google.protobuf.Empty);

  // Queries
  rpc ListHoldings(ListHoldingsRequest) returns (ListHoldingsResponse);
  rpc ListHoldingTransactions(ListTradesRequest) returns (ListTradesResponse);
}
```

### 4.3 entGo Schema

| Table | Key Columns | Constraints |
|-------|-------------|-------------|
| securities | id, symbol, name, security_type, exchange, currency_code, current_price_cents | UNIQUE(symbol, exchange) |
| holdings | id, tenant_id, account_id, security_id, quantity, avg_cost_cents, version, timestamps | UNIQUE(account_id, security_id) |
| holding_transactions | id, tenant_id, account_id, security_id, trade_type, quantity, price_cents, amount_cents, fee_cents, trade_date, transaction_id, notes, timestamps | Append-only |

### 4.4 Migration Notes

- **Quantity uses float64** — Holding quantity and price require decimal precision. Go uses `float64` with careful rounding, or `shopspring/decimal` for domain calculations.
- **Yahoo Finance API** — currently embedded in Tauri command layer. Go server will implement as a driven adapter behind a `MarketDataProvider` port.
- **Exchange suffix mapping**: SHA/SHH → `.SS`, SHE/SHZ → `.SZ`, HKG → `.HK`
- `DeleteHoldingTrade` must reverse the holding position recalculation

---

## 5. Category Module

### 5.1 Domain Model

**Aggregate Root: Category**

| Field | Go Type | Notes |
|-------|---------|-------|
| id | uuid.UUID | |
| tenant_id | uuid.UUID | FK → tenants |
| name | string | Trimmed, non-empty |
| category_type | CategoryType | Enum: income / expense |
| icon | string | Emoji or icon name |
| color | string | Hex color |
| parent_id | *uuid.UUID | Hierarchical |
| is_system | bool | System categories cannot be deleted |
| sort_order | int32 | |
| version | int64 | |
| deleted_at | *time.Time | Soft delete |
| timestamps | — | |

**Enum: CategoryType**

| Value | Protobuf |
|-------|----------|
| income | CATEGORY_TYPE_INCOME |
| expense | CATEGORY_TYPE_EXPENSE |

**Domain Methods:**
- `New(...)` — trims name, returns error if empty
- `UpdateName(name) error` — checks not deleted, trims, rejects empty
- `UpdateIcon/Color(...)` — must not be deleted
- `SoftDelete() error` — marks deleted_at; returns error if is_system=true
- `IsDeleted() bool`

### 5.2 gRPC Service

```protobuf
service CategoryService {
  rpc CreateCategory(CreateCategoryRequest) returns (CategoryResponse);
  rpc UpdateCategory(UpdateCategoryRequest) returns (CategoryResponse);
  rpc DeleteCategory(DeleteCategoryRequest) returns (google.protobuf.Empty);
  rpc ListCategories(ListCategoriesRequest) returns (ListCategoriesResponse);
}
```

### 5.3 entGo Schema

| Table | Key Columns | Constraints |
|-------|-------------|-------------|
| categories | id, tenant_id, name, category_type, icon, color, parent_id, is_system, sort_order, version, deleted_at, timestamps | INDEX(tenant_id, category_type), FK parent_id → categories |

### 5.4 Migration Notes

- System categories (seeded) cannot be deleted — enforced in domain service
- Hierarchical via parent_id self-reference
- Tauri uses separate `chart_of_accounts` table — Go merges chart_code as optional field on Category

---

## 6. Tag Module

### 6.1 Domain Model

**Entity: Tag** (simple label, no SyncMetadata needed)

| Field | Go Type | Notes |
|-------|---------|-------|
| id | uuid.UUID | |
| tenant_id | uuid.UUID | |
| name | string | Unique per tenant |
| color | string | Hex color |
| version | int64 | |
| deleted_at | *time.Time | Soft delete |
| timestamps | — | |

**Junction: TransactionTag**

| Field | Go Type |
|-------|---------|
| transaction_id | uuid.UUID |
| tag_id | uuid.UUID |

Constraint: UNIQUE(transaction_id, tag_id)

### 6.2 gRPC Service

```protobuf
service TagService {
  rpc CreateTag(CreateTagRequest) returns (TagResponse);
  rpc UpdateTag(UpdateTagRequest) returns (TagResponse);
  rpc DeleteTag(DeleteTagRequest) returns (google.protobuf.Empty);
  rpc ListTags(ListTagsRequest) returns (ListTagsResponse);
  rpc AddTagToTransaction(TagTransactionRequest) returns (google.protobuf.Empty);
  rpc RemoveTagFromTransaction(TagTransactionRequest) returns (google.protobuf.Empty);
  rpc GetTransactionTags(GetTransactionTagsRequest) returns (ListTagsResponse);
}
```

### 6.3 entGo Schema

| Table | Key Columns | Constraints |
|-------|-------------|-------------|
| tags | id, tenant_id, name, color, version, deleted_at, timestamps | UNIQUE(tenant_id, name) |
| transaction_tags | transaction_id, tag_id | UNIQUE(transaction_id, tag_id), FK → transactions, FK → tags |

---

## 7. Reminder Module

### 7.1 Domain Model

**Aggregate Root: Reminder**

| Field | Go Type | Notes |
|-------|---------|-------|
| id | uuid.UUID | |
| tenant_id | uuid.UUID | |
| reminder_type | ReminderType | Enum |
| related_entity_id | *uuid.UUID | e.g. debt account ID |
| title | string | Trimmed, non-empty |
| description | string | |
| remind_at | time.Time | |
| repeat_pattern | *RepeatPattern | Optional |
| notified | bool | Default false |
| priority | Priority | Enum |
| last_notified_at | *time.Time | |
| notification_count | int32 | Default 0 |
| version | int64 | |
| deleted_at | *time.Time | |
| timestamps | — | |

**Enum: ReminderType**

| Value | Protobuf |
|-------|----------|
| debt_payment | REMINDER_TYPE_DEBT_PAYMENT |
| bill_due | REMINDER_TYPE_BILL_DUE |
| custom | REMINDER_TYPE_CUSTOM |
| prepaid_low_balance | REMINDER_TYPE_PREPAID_LOW_BALANCE |

**Enum: RepeatPattern**

| Value | Protobuf |
|-------|----------|
| daily | REPEAT_DAILY |
| weekly | REPEAT_WEEKLY |
| monthly | REPEAT_MONTHLY |
| yearly | REPEAT_YEARLY |

**Enum: Priority**

| Value | Protobuf |
|-------|----------|
| low | PRIORITY_LOW |
| normal | PRIORITY_NORMAL |
| high | PRIORITY_HIGH |
| urgent | PRIORITY_URGENT |

**Domain Methods:**
- `ShouldTriggerNow() bool` — false if notified; true if remind_at <= now
- `MarkNotified()` — sets notified=true, increments count, sets last_notified_at
- `ShouldNotify() bool` — 24-hour throttle
- `CalculateNextOccurrence() *time.Time` — adds period; handles month-end clamping
- `Complete()` — marks as notified + soft delete

### 7.2 gRPC Service

```protobuf
service ReminderService {
  rpc CreateReminder(CreateReminderRequest) returns (ReminderResponse);
  rpc UpdateReminder(UpdateReminderRequest) returns (ReminderResponse);
  rpc DeleteReminder(DeleteReminderRequest) returns (google.protobuf.Empty);
  rpc CompleteReminder(CompleteReminderRequest) returns (google.protobuf.Empty);
  rpc GetReminder(GetReminderRequest) returns (ReminderResponse);
  rpc ListReminders(ListRemindersRequest) returns (ListRemindersResponse);
}
```

### 7.3 entGo Schema

| Table | Key Columns | Constraints |
|-------|-------------|-------------|
| reminders | id, tenant_id, reminder_type, related_entity_id, title, description, remind_at, repeat_pattern, notified, priority, last_notified_at, notification_count, version, deleted_at, timestamps | INDEX(tenant_id, remind_at), INDEX(tenant_id, notified) |

### 7.4 Migration Notes

- OS task scheduling (os_task_id) is Tauri-specific → Go server uses background scheduler (cron-style)
- Month-end clamping in CalculateNextOccurrence: Jan 31 → Feb 28
- 24-hour notification throttle preserved in domain service

---

## 8. TransactionTemplate Module (Recurring Transactions)

### 8.1 Domain Model

**Aggregate Root: TransactionTemplate**

| Field | Go Type | Notes |
|-------|---------|-------|
| id | uuid.UUID | |
| tenant_id | uuid.UUID | |
| name | string | e.g. "Netflix 月费" |
| description | *string | |
| amount_cents | int64 | |
| direction | TemplateDirection | Enum |
| source_account_id | uuid.UUID | |
| destination_account_id | *uuid.UUID | For transfers |
| cycle | TemplateCycle | Enum |
| cycle_days | *int32 | For custom cycle |
| billing_day | *int32 | |
| next_date | time.Time | Next occurrence |
| start_date | time.Time | |
| end_date | *time.Time | Optional expiry |
| auto_record | bool | |
| paused | bool | |
| last_transaction_id | *uuid.UUID | |
| category | *string | |
| version | int64 | |
| timestamps | — | |

**Enum: TemplateDirection**

| Value | Protobuf |
|-------|----------|
| expense | DIRECTION_EXPENSE |
| income | DIRECTION_INCOME |
| transfer | DIRECTION_TRANSFER |

**Enum: TemplateCycle**

| Value | Protobuf | Notes |
|-------|----------|-------|
| weekly | CYCLE_WEEKLY | +7 days |
| monthly | CYCLE_MONTHLY | +1 month |
| yearly | CYCLE_YEARLY | +12 months |
| custom | CYCLE_CUSTOM | +N days (cycle_days) |

**Domain Methods:**
- `IsDue(today time.Time) bool` — !paused AND next_date <= today AND (no end_date OR today <= end_date)
- `CalculateNextDate() time.Time` — based on cycle
- `AdvanceToNext()` — sets next_date = CalculateNextDate()
- `Pause()` / `Resume()` — toggle paused

**Domain Events:**
- `TemplateCreated`
- `TemplatePaused`
- `TemplateResumed`
- `AutoTransactionRecorded`

### 8.2 gRPC Service

```protobuf
service TransactionTemplateService {
  rpc CreateTransactionTemplate(CreateTemplateRequest) returns (TemplateResponse);
  rpc UpdateTransactionTemplate(UpdateTemplateRequest) returns (TemplateResponse);
  rpc DeleteTransactionTemplate(DeleteTemplateRequest) returns (google.protobuf.Empty);
  rpc PauseTransactionTemplate(PauseTemplateRequest) returns (TemplateResponse);
  rpc ResumeTransactionTemplate(ResumeTemplateRequest) returns (TemplateResponse);
  rpc GetTransactionTemplate(GetTemplateRequest) returns (TemplateResponse);
  rpc ListTransactionTemplates(ListTemplatesRequest) returns (ListTemplatesResponse);
  rpc ListTemplateTransactions(ListTemplateTransactionsRequest) returns (ListTransactionsResponse);
}
```

### 8.3 entGo Schema

| Table | Key Columns | Constraints |
|-------|-------------|-------------|
| transaction_templates | id, tenant_id, name, description, amount_cents, direction, source_account_id, destination_account_id, cycle, cycle_days, billing_day, next_date, start_date, end_date, auto_record, paused, last_transaction_id, category, version, timestamps | INDEX(tenant_id, paused, next_date) |

### 8.4 Migration Notes

- Auto-record logic: background scheduler checks `is_due` templates and creates transactions
- `list_template_transactions` queries transactions linked via `last_transaction_id` chain
- Custom cycle with `cycle_days` is unique to this module

---

## 9. Family Module (Multi-User Sharing)

### 9.1 Domain Model

**Entity: Family**

| Field | Go Type | Notes |
|-------|---------|-------|
| id | uuid.UUID | Also serves as tenant_id for family members |
| name | string | e.g. "Lee Family" |
| created_by | uuid.UUID | FK → users |
| created_at | time.Time | |

**Entity: FamilyMembership**

| Field | Go Type | Notes |
|-------|---------|-------|
| id | uuid.UUID | |
| family_id | uuid.UUID | FK → families |
| user_id | uuid.UUID | FK → users |
| role | FamilyRole | Enum |
| status | MembershipStatus | Enum |
| invited_at | time.Time | |
| joined_at | *time.Time | |
| timestamps | — | |

**Enum: FamilyRole**

| Value | Description |
|-------|-------------|
| owner | Creator, full control |
| admin | Can manage members |
| member | View + edit shared data |

**Enum: MembershipStatus**

| Value | Description |
|-------|-------------|
| pending | Invited, not yet accepted |
| active | Accepted |
| removed | Removed by admin |

**Domain Rules:**
- User creates family → auto-creates Tenant(type=family) → user.tenant_id updated
- Owner can invite (creates pending membership + notification)
- Accept invite → user.tenant_id = family.id, membership status → active
- Remove member → membership status → removed, user.tenant_id reverted to personal tenant
- Shared data: accounts, transactions, budgets scoped by tenant_id
- Only owner can delete family

### 9.2 gRPC Service

```protobuf
service FamilyService {
  rpc CreateFamily(CreateFamilyRequest) returns (FamilyResponse);
  rpc InviteMember(InviteMemberRequest) returns (google.protobuf.Empty);
  rpc AcceptInvite(AcceptInviteRequest) returns (FamilyResponse);
  rpc RemoveMember(RemoveMemberRequest) returns (google.protobuf.Empty);
  rpc LeaveFamily(LeaveFamilyRequest) returns (google.protobuf.Empty);
  rpc DeleteFamily(DeleteFamilyRequest) returns (google.protobuf.Empty);
  rpc GetFamily(GetFamilyRequest) returns (FamilyDetailResponse);
  rpc ListFamilyMembers(ListMembersRequest) returns (ListMembersResponse);
  rpc UpdateMemberRole(UpdateRoleRequest) returns (google.protobuf.Empty);
}
```

### 9.3 entGo Schema

| Table | Key Columns | Constraints |
|-------|-------------|-------------|
| families | id, name, created_by, timestamps | |
| family_memberships | id, family_id, user_id, role, status, invited_at, joined_at, timestamps | UNIQUE(family_id, user_id) |

### 9.4 Migration Notes

- This is entirely new functionality — no Tauri equivalent
- Requires notification system (invite acceptance)
- Data migration: when user joins family, their personal data stays under personal tenant_id; shared data lives under family tenant_id

---

## 10. Report Module

### 10.1 Domain Model

No persistent entities — all computed queries against existing data.

**Supported Reports (from current Tauri):**
- Year-over-year comparison (income/expense by month)
- Account balance history (time series)
- Budget vs actual by category
- Investment portfolio summary (market value, P&L)
- Debt repayment progress
- Goal progress summary

### 10.2 gRPC Service

```protobuf
service ReportService {
  rpc GetYearOverYearComparison(YoYRequest) returns (YoYResponse);
  rpc GetAccountBalanceHistory(BalanceHistoryRequest) returns (BalanceHistoryResponse);
  rpc GetBudgetReport(BudgetReportRequest) returns (BudgetReportResponse);
  rpc GetPortfolioSummary(PortfolioSummaryRequest) returns (PortfolioSummaryResponse);
  rpc GetDebtProgressReport(DebtProgressRequest) returns (DebtProgressResponse);
  rpc GetDashboardSummary(DashboardSummaryRequest) returns (DashboardSummaryResponse);
}
```

### 10.3 Implementation Strategy

- Go query handlers use raw SQL views for complex aggregations (entGo for simple queries)
- Flutter caches report results locally with TTL (e.g., 5-minute stale time)
- Dashboard summary aggregates data from multiple modules in a single gRPC call

---

## 11. Sync Module

### 11.1 Architecture

```
Flutter Client (Drift) ←→ gRPC Bidirectional Stream ←→ Go Server (PostgreSQL)
         ↑                                                          |
         |                                                          ↓
   OfflineQueue                                              SyncLog (append-only)
```

### 11.2 Core Components

**Server-side:**

| Component | Responsibility |
|-----------|----------------|
| SyncService | Orchestrates push/pull per entity type |
| SyncLog | Append-only table tracking all changes per tenant |
| ConflictResolver | Strategy-based (server-wins, client-wins, merge) |

**Client-side:**

| Component | Responsibility |
|-----------|----------------|
| SyncEngine | Manages sync lifecycle, retry, backoff |
| OfflineQueue | Drift table storing pending operations |
| ConflictResolver | Local conflict resolution UI |

### 11.3 entGo Schema

| Table | Key Columns | Purpose |
|-------|-------------|---------|
| sync_log | id, tenant_id, entity_type, entity_id, operation, payload, version, device_id, timestamp | Append-only change log |
| sync_devices | id, tenant_id, device_name, last_sync_version, last_sync_at | Track connected devices |
| sync_conflicts | id, tenant_id, entity_type, entity_id, conflict_type, server_payload, client_payload, resolution, resolved_at | Conflict tracking |

### 11.4 Sync Protocol

Each entity type (account, transaction, etc.) has a bidirectional stream RPC:

```
Client → Server:  SyncPayload { operation: "create/update/delete", payload, version, device_id }
Server → Client:  SyncPayload { operation: "ack", version: N }
Server → Client:  SyncPayload { operation: "push", payload, version }  // New data from other devices
Client → Server:  SyncPayload { operation: "ack", version: N }
Server → Client:  SyncPayload { operation: "conflict", server_payload, client_payload }  // Conflict detected
Client → Server:  SyncPayload { operation: "resolve", chosen: "server"|"client", payload }
```

### 11.5 Conflict Resolution Strategy

| Scenario | Default Strategy |
|----------|-----------------|
| Update-Update | Server wins (higher version) |
| Delete-Update | Delete wins (tombstone) |
| Update-Delete | Delete wins |
| Create-Create (same entity) | Merge (server assigns final ID) |

Users can override per-conflict via Flutter UI.

---

## 12. Backup Module

### 12.1 Domain Model

**Entity: Backup**

| Field | Go Type | Notes |
|-------|---------|-------|
| id | uuid.UUID | |
| tenant_id | uuid.UUID | |
| provider | BackupProvider | Enum |
| filename | string | |
| size_bytes | int64 | |
| checksum | string | SHA-256 |
| encrypted | bool | |
| auto | bool | Scheduled vs manual |
| timestamps | — | |

**Enum: BackupProvider**

| Value | Protobuf |
|-------|----------|
| local | BACKUP_PROVIDER_LOCAL |
| webdav | BACKUP_PROVIDER_WEBDAV |
| dropbox | BACKUP_PROVIDER_DROPBOX |
| google_drive | BACKUP_PROVIDER_GOOGLE_DRIVE |
| onedrive | BACKUP_PROVIDER_ONE_DRIVE |
| s3 | BACKUP_PROVIDER_S3 |

### 12.2 gRPC Service

```protobuf
service BackupService {
  rpc CreateBackup(CreateBackupRequest) returns (BackupResponse);
  rpc RestoreBackup(RestoreBackupRequest) returns (google.protobuf.Empty);
  rpc ListBackups(ListBackupsRequest) returns (ListBackupsResponse);
  rpc DeleteBackup(DeleteBackupRequest) returns (google.protobuf.Empty);
  rpc GetCloudPresets(google.protobuf.Empty) returns (CloudPresetsResponse);
  rpc SaveCloudSettings(SaveCloudSettingsRequest) returns (google.protobuf.Empty);
  rpc GetCloudSettings(google.protobuf.Empty) returns (CloudSettingsResponse);
  rpc TestCloudConnection(TestConnectionRequest) returns (TestConnectionResponse);
  rpc AuthorizeCloudProvider(AuthorizeRequest) returns (AuthorizeResponse);
  rpc UploadToCloud(UploadRequest) returns (BackupResponse);
  rpc ListCloudBackups(ListCloudBackupsRequest) returns (ListBackupsResponse);
}
```

### 12.3 Implementation Notes

- OAuth2 PKCE flow for Dropbox/GoogleDrive/OneDrive (port from Rust)
- WebDAV support with basic auth
- S3-compatible (MinIO) for self-hosted backup
- Backup format: JSON + optional AES-256-GCM encryption
- Auto-backup scheduler (configurable interval)

---

## 13. Search Module

### 13.1 Strategy

| Platform | Technology |
|----------|-----------|
| Go Server | PostgreSQL `pg_trgm` GIN indexes + `tsvector` for Chinese tokenization |
| Flutter Client | Drift full-text search via FTS5 (local) |

### 13.2 gRPC Service

```protobuf
service SearchService {
  rpc GlobalSearch(GlobalSearchRequest) returns (GlobalSearchResponse);
  rpc RebuildSearchIndex(google.protobuf.Empty) returns (google.protobuf.Empty);
}
```

### 13.3 PostgreSQL Setup

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS zhparser;  -- Chinese tokenization

-- GIN indexes for fuzzy search
CREATE INDEX idx_accounts_name_trgm ON accounts USING gin (name gin_trgm_ops);
CREATE INDEX idx_transactions_desc_trgm ON transactions USING gin (description gin_trgm_ops);
```

### 13.4 Flutter Local Search

Drift FTS5 tables mirror server search on local SQLite, rebuilt on each sync.

---

## 14. Encryption Module

### 14.1 Scope

Encrypt sensitive fields (backup files, optional account details) using AES-256-GCM.

### 14.2 Implementation

- Server-side encryption for backup payloads
- Client-side: `flutter_secure_storage` for token storage
- Key derivation: PBKDF2 with user password → encryption key
- No server-side key storage (user holds the key)

### 14.3 gRPC Service

```protobuf
service EncryptionService {
  rpc SetupEncryption(SetupEncryptionRequest) returns (google.protobuf.Empty);
  rpc UnlockEncryption(UnlockEncryptionRequest) returns (google.protobuf.Empty);
  rpc LockEncryption(google.protobuf.Empty) returns (google.protobuf.Empty);
  rpc DisableEncryption(DisableEncryptionRequest) returns (google.protobuf.Empty);
  rpc GetEncryptionStatus(google.protobuf.Empty) returns (EncryptionStatusResponse);
}
```

---

## 15. Currency Module

### 15.1 Domain Model

**Entity: Currency** (global, tenant-independent)

| Field | Go Type | Notes |
|-------|---------|-------|
| id | uuid.UUID | |
| code | string | ISO 4217, UNIQUE |
| name | string | |
| symbol | string | |
| exchange_rate | float64 | To base currency |
| is_active | bool | |

### 15.2 gRPC Service

```protobuf
service CurrencyService {
  rpc ListCurrencies(ListCurrenciesRequest) returns (ListCurrenciesResponse);
  rpc AddCurrency(AddCurrencyRequest) returns (CurrencyResponse);
  rpc UpdateExchangeRate(UpdateRateRequest) returns (CurrencyResponse);
  rpc FetchExchangeRate(FetchRateRequest) returns (FetchRateResponse);
}
```

### 15.3 entGo Schema

| Table | Key Columns | Constraints |
|-------|-------------|-------------|
| currencies | id, code, name, symbol, exchange_rate, is_active | UNIQUE(code) |

### 15.4 Migration Notes

- Exchange rate fetching from external API (port as driven adapter)
- Currencies are global (no tenant_id) but each tenant selects which currencies to use

---

## Module Priority & Dependencies

```
P0 (MVP):        Account + Transaction + Auth          [Architecture spec]
P1 (Core+):      Category + Currency + Tag              [Lightweight, Transaction deps]
P2 (Financial):  Budget + Goal + Debt                   [Account+Transaction deps]
P3 (Investment): Holding + Security                     [Account deps, Yahoo Finance API]
P4 (Ops):        TransactionTemplate + Reminder + Search [Account+Transaction deps]
P5 (Social):     Family + Report                        [All above as data sources]
P6 (Infra):      Sync + Backup + Encryption             [Cross-cutting infrastructure]
```

Each priority level depends only on modules from lower levels. Implementation proceeds level by level.

---

## Industry Terminology Reference

| Term | Usage in This Design |
|------|---------------------|
| tenant_id | Data isolation boundary (NOT user_id) |
| aggregate root | DDD entry entity (Budget, Goal, DebtDetails, etc.) |
| value object | Immutable, no identity (BudgetItem, PaymentScheduleEntry) |
| port | Hexagonal interface (driving/driven) |
| adapter | Hexagonal implementation |
| command | CQRS write |
| query | CQRS read |
| bounded context | Module boundary (budget, goal, debt, holding, etc.) |
| soft delete | Tombstone pattern via deleted_at |
| optimistic lock | Version field for concurrent update detection |
| append-only ledger | HoldingTransaction, SyncLog — never updated/deleted |
