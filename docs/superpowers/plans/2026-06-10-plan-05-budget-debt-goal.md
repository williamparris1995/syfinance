# Plan 05: Budget + Debt + Goal Modules

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement three financial planning modules — Budget (monthly budgeting with actual tracking), Debt (loan/debt tracking with amortization), and Goal (savings targets with progress). These are independent modules that all depend on Account and Transaction.

**Architecture:** Explicit Architecture with DDD, Hexagonal Ports & Adapters, CQRS.

**Depends on:** Plan 1 (shared kernel) + Plan 2 (auth) + Plan 3 (Account) + Plan 4 (Transaction)

**Design Specs:**
- [Functional Modules](../specs/2026-06-09-functional-modules-design.md) — Sections 1–3

---

# Part A: Budget Module

## File Structure

```
yucai/
├── proto/budget/v1/
│   └── budget.proto
│
└── server/internal/budget/
    ├── domain/
    │   ├── entity.go                # Budget, BudgetItem
    │   ├── valueobject.go           # (none needed — items embedded)
    │   ├── service.go               # BudgetDomainService (actuals computation)
    │   └── repository.go            # BudgetRepository interface
    │
    ├── application/
    │   ├── service.go               # BudgetApplicationService
    │   └── dto.go                   # DTOs + mappers
    │
    ├── adapter/driven/
    │   └── repository/
    │       └── budget_repo.go       # entGo BudgetRepository
    │
    ├── adapter/driving/
    │   └── grpc/
    │       └── budget_handler.go    # gRPC BudgetService
    │
    └── ent/schema/
        ├── budget.go                # Budget schema + TenantMixin
        └── budget_item.go           # BudgetItem schema

Modified:
├── server/wire/wire.go, wire_gen.go, app.go, providers.go
└── server/cmd/server/main.go
```

---

## Task A1: Protobuf Budget Service Definition

- [ ] **Step 1: Create `proto/budget/v1/budget.proto`**

```protobuf
syntax = "proto3";
package yucai.budget.v1;
option go_package = "github.com/yucai/server/internal/proto/budget/v1";

import "common/v1/pagination.proto";
import "google/protobuf/empty.proto";
import "google/protobuf/timestamp.proto";

service BudgetService {
  rpc CreateBudget(CreateBudgetRequest) returns (BudgetResponse);
  rpc GetBudget(GetBudgetRequest) returns (BudgetDetailResponse);
  rpc GetBudgetByMonth(GetBudgetByMonthRequest) returns (BudgetDetailResponse);
  rpc ListBudgets(ListBudgetsRequest) returns (ListBudgetsResponse);
  rpc DeleteBudget(DeleteBudgetRequest) returns (google.protobuf.Empty);
  rpc AddBudgetItem(AddBudgetItemRequest) returns (BudgetResponse);
  rpc RemoveBudgetItem(RemoveBudgetItemRequest) returns (BudgetResponse);
  rpc ComputeBudgetActuals(ComputeActualsRequest) returns (BudgetResponse);
  rpc CloneBudgetToMonth(CloneBudgetRequest) returns (BudgetResponse);
}

message BudgetDTO {
  string id = 1;
  string name = 2;
  string month = 3;
  int64 total_amount_cents = 4;
  string currency_code = 5;
  bool is_active = 6;
  int64 version = 7;
  google.protobuf.Timestamp created_at = 8;
  google.protobuf.Timestamp updated_at = 9;
}

message BudgetItemDTO {
  string id = 1;
  string budget_id = 2;
  string account_id = 3;
  int64 planned_amount_cents = 4;
  int64 actual_amount_cents = 5;
  string notes = 6;
}

message BudgetDetailDTO {
  BudgetDTO budget = 1;
  repeated BudgetItemDTO items = 2;
  int64 total_actual_cents = 3;
  int64 total_remaining_cents = 4;
  double usage_pct = 5;
}

message CreateBudgetRequest {
  string name = 1;
  string month = 2;                // "YYYY-MM"
  string currency_code = 3;
  repeated BudgetItemInput items = 4;
}

message BudgetItemInput {
  string account_id = 1;
  int64 planned_amount_cents = 2;
  string notes = 3;
}

message GetBudgetRequest { string id = 1; }
message GetBudgetByMonthRequest { string month = 1; }

message ListBudgetsRequest {
  yucai.common.v1.PageRequest page = 1;
  bool active_only = 2;
}

message ListBudgetsResponse {
  repeated BudgetDTO budgets = 1;
  yucai.common.v1.PageResponse page = 2;
}

message DeleteBudgetRequest { string id = 1; }

message AddBudgetItemRequest {
  string budget_id = 1;
  string account_id = 2;
  int64 planned_amount_cents = 3;
  string notes = 4;
}

message RemoveBudgetItemRequest {
  string budget_id = 1;
  string item_id = 2;
}

message ComputeActualsRequest { string budget_id = 1; }

message CloneBudgetRequest {
  string source_budget_id = 1;
  string target_month = 2;
  string name = 3;
}

message BudgetResponse { BudgetDTO budget = 1; }
message BudgetDetailResponse { BudgetDetailDTO budget = 1; }
```

- [ ] **Step 2: Run `buf generate`**
- [ ] **Step 3: Verify generated files**

---

## Task A2: entGo Schema (Budget + BudgetItem)

- [ ] **Step 1: Create `internal/budget/ent/schema/budget.go`**

Fields: UUID PK, TenantMixin, `name` (required), `month` (string "YYYY-MM"), `total_amount_cents` (int64), `currency_code` (default "CNY"), `is_active` (bool, default true), `version` (int64, default 1), `deleted_at` (optional), timestamps.

Indexes: `tenant_id`, UNIQUE `(tenant_id, month)`.

- [ ] **Step 2: Create `internal/budget/ent/schema/budget_item.go`**

Fields: UUID PK, `budget_id` (FK → Budget, cascade delete), `account_id` (UUID), `planned_amount_cents` (int64), `actual_amount_cents` (int64, default 0), `notes` (optional string).

Indexes: `budget_id`, `account_id`.

- [ ] **Step 3: Generate entGo code** — `go generate ./internal/budget/ent/...`
- [ ] **Step 4: Verify compilation**

---

## Task A3: Domain Layer

- [ ] **Step 1: Create `internal/budget/domain/entity.go`**

```go
type Budget struct {
    ID                uuid.UUID
    TenantID          uuid.UUID
    Name              string
    Month             string       // "YYYY-MM"
    TotalAmountCents  int64
    CurrencyCode      string
    IsActive          bool
    Items             []BudgetItem
    Version           int64
    CreatedAt         time.Time
    UpdatedAt         time.Time
    DeletedAt         *time.Time
}

type BudgetItem struct {
    ID                  uuid.UUID
    BudgetID            uuid.UUID
    AccountID           uuid.UUID
    PlannedAmountCents  int64
    ActualAmountCents   int64
    Notes               string
}
```

Constructor `NewBudget(tenantID uuid.UUID, name, month, currencyCode string, items []BudgetItem) (*Budget, error)` validates: non-empty name, valid month format, at least 1 item.

Methods: `AddItem()`, `RemoveItem()`, `UpdateItemAmount()`, `TotalActual()`, `TotalRemaining()`, `UsagePct()`, `IsOverBudget()`, `Deactivate()`, `Activate()`, `CloneToMonth()`, `IncrementVersion()`.

- [ ] **Step 2: Create `internal/budget/domain/service.go`**

`BudgetActualsService` with method:
```go
func (s *BudgetActualsService) ComputeActuals(ctx context.Context, budget *Budget, txnRepo transactionrepo.TransactionRepository) error
```

For each BudgetItem: query transaction entries in the budget's month where `account_id = item.AccountID`, sum debit/credit based on account type, update `item.ActualAmountCents`.

- [ ] **Step 3: Create `internal/budget/domain/repository.go`**

```go
type BudgetRepository interface {
    Save(ctx context.Context, budget *Budget) error
    FindByID(ctx context.Context, tenantID, id uuid.UUID) (*Budget, error)
    FindByMonth(ctx context.Context, tenantID uuid.UUID, month string) (*Budget, error)
    FindAll(ctx context.Context, tenantID uuid.UUID, activeOnly bool, page PageRequest) (*PaginatedResult[Budget], error)
    Update(ctx context.Context, budget *Budget) error
    Delete(ctx context.Context, tenantID, id uuid.UUID) error
}
```

Reuse `PageRequest` and `PaginatedResult` from shared kernel or account domain.

- [ ] **Step 4: Write domain tests** — test budget creation, add/remove items, usage calculation, clone to month.

---

## Task A4: Application Layer

- [ ] **Step 1: Create `internal/budget/application/dto.go`**

DTOs: `CreateBudgetRequest`, `AddBudgetItemRequest`, `RemoveBudgetItemRequest`, `ComputeActualsRequest`, `CloneBudgetRequest`, `ListBudgetsRequest`, `BudgetDTO`, `BudgetItemDTO`, `BudgetDetailDTO`, `ListBudgetsResult`.

Mapper: `BudgetToDTO()`, `BudgetToDetailDTO()`.

- [ ] **Step 2: Create `internal/budget/application/service.go`**

`Service` with methods: `CreateBudget()`, `GetBudget()`, `GetBudgetByMonth()`, `ListBudgets()`, `DeleteBudget()`, `AddBudgetItem()`, `RemoveBudgetItem()`, `ComputeActuals()`, `CloneBudgetToMonth()`.

Each method: validate → domain operation → repo call → return DTO.

- [ ] **Step 3: Write tests** — mock repo, test create/list/clone flows.

---

## Task A5: Driven Adapter (Repository)

- [ ] **Step 1: Create `internal/budget/adapter/driven/repository/budget_repo.go`**

Implement `domain.BudgetRepository` using entGo. Key behaviors:
- `Save`: create Budget + batch create BudgetItems
- `FindByID`: eager-load items, exclude deleted
- `FindByMonth`: WHERE tenant_id AND month
- `FindAll`: pagination, optional active_only filter
- `Update`: optimistic lock via version
- `Delete`: soft delete (set deleted_at)

- [ ] **Step 2: Write tests** — CRUD, pagination, soft delete.

---

## Task A6: gRPC Driving Adapter

- [ ] **Step 1: Create `internal/budget/adapter/driving/grpc/budget_handler.go`**

Implement generated `BudgetServiceServer`. Each RPC: extract tenant_id → map proto to DTO → call service → map to proto.

- [ ] **Step 2: Wire integration** — update wire.go, app.go, providers.go, main.go.
- [ ] **Step 3: Verify** — `go build ./cmd/server`

---

## Task A7: Budget Integration Tests

- [ ] **Step 1: Create `tests/budget_integration_test.go`**

```go
func TestBudgetCRUD(t *testing.T)              // Create → GetByMonth → AddItem → RemoveItem → Delete
func TestBudgetComputeActuals(t *testing.T)     // Create budget → record transactions → compute actuals
func TestBudgetCloneToMonth(t *testing.T)       // Create → Clone → verify independent copy
func TestBudgetOverBudget(t *testing.T)         // Actuals exceed planned → IsOverBudget
func TestBudgetTenantIsolation(t *testing.T)    // Tenant A budget invisible to B
```

- [ ] **Step 2: Run tests**
- [ ] **Step 3: Commit** — `feat: implement Budget module`

---

# Part B: Debt Module

## File Structure

```
yucai/
├── proto/debt/v1/
│   └── debt.proto
│
└── server/internal/debt/
    ├── domain/
    │   ├── entity.go                # DebtDetails, PaymentScheduleEntry
    │   ├── valueobject.go           # AmortizationMethod enum
    │   ├── service.go               # AmortizationCalculator
    │   └── repository.go            # DebtRepository interface
    ├── application/
    │   ├── service.go
    │   └── dto.go
    ├── adapter/driven/
    │   └── repository/
    │       └── debt_repo.go
    ├── adapter/driving/
    │   └── grpc/
    │       └── debt_handler.go
    └── ent/schema/
        ├── debt_details.go
        └── payment_schedule.go
```

---

## Task B1: Protobuf Debt Service Definition

- [ ] **Step 1: Create `proto/debt/v1/debt.proto`**

```protobuf
syntax = "proto3";
package yucai.debt.v1;
option go_package = "github.com/yucai/server/internal/proto/debt/v1";

import "common/v1/pagination.proto";
import "google/protobuf/empty.proto";
import "google/protobuf/timestamp.proto";

service DebtService {
  rpc CreateDebt(CreateDebtRequest) returns (DebtResponse);
  rpc UpdateDebt(UpdateDebtRequest) returns (DebtResponse);
  rpc DeleteDebt(DeleteDebtRequest) returns (google.protobuf.Empty);
  rpc RecordPayment(RecordPaymentRequest) returns (RecordPaymentResponse);
  rpc GetDebt(GetDebtRequest) returns (DebtDetailResponse);
  rpc ListDebts(ListDebtsRequest) returns (ListDebtsResponse);
  rpc GetUpcomingPayments(GetUpcomingPaymentsRequest) returns (ListDebtsResponse);
}

enum AmortizationMethod {
  AMORTIZATION_UNSPECIFIED = 0;
  AMORTIZATION_EQUAL_PRINCIPAL_INTEREST = 1;
  AMORTIZATION_EQUAL_PRINCIPAL = 2;
  AMORTIZATION_LUMP_SUM = 3;
}

message DebtDTO {
  string id = 1;
  string account_id = 2;
  string counterparty = 3;
  double interest_rate = 4;
  AmortizationMethod amortization_method = 5;
  string start_date = 6;
  string due_date = 7;
  int64 total_principal_cents = 8;
  int64 remaining_principal_cents = 9;
  int64 version = 10;
  google.protobuf.Timestamp created_at = 11;
  google.protobuf.Timestamp updated_at = 12;
}

message PaymentEntryDTO {
  string id = 1;
  string payment_date = 2;
  int64 principal_cents = 3;
  int64 interest_cents = 4;
  int64 total_cents = 5;
  bool paid = 6;
  int64 paid_cents = 7;
  string transaction_id = 8;
}

message DebtDetailDTO {
  DebtDTO debt = 1;
  repeated PaymentEntryDTO schedule = 2;
}

message CreateDebtRequest {
  string account_id = 1;
  string counterparty = 2;
  double interest_rate = 3;
  AmortizationMethod amortization_method = 4;
  string start_date = 5;
  string due_date = 6;
  int64 total_principal_cents = 7;
}

message UpdateDebtRequest {
  string id = 1;
  string counterparty = 2;
  double interest_rate = 3;
  int64 version = 4;
}

message DeleteDebtRequest { string id = 1; }

message RecordPaymentRequest {
  string debt_id = 1;
  string schedule_entry_id = 2;
  string from_account_id = 3;
}

message RecordPaymentResponse {
  string transaction_id = 1;
  PaymentEntryDTO entry = 2;
}

message GetDebtRequest { string id = 1; }

message ListDebtsRequest {
  yucai.common.v1.PageRequest page = 1;
}

message ListDebtsResponse {
  repeated DebtDTO debts = 1;
  yucai.common.v1.PageResponse page = 2;
}

message GetUpcomingPaymentsRequest {
  int32 days_ahead = 1;
}

message DebtResponse { DebtDTO debt = 1; }
message DebtDetailResponse { DebtDetailDTO debt = 1; }
```

- [ ] **Step 2: Run `buf generate`**
- [ ] **Step 3: Verify generated files**

---

## Task B2: entGo Schema (DebtDetails + PaymentSchedule)

- [ ] **Step 1: Create `internal/debt/ent/schema/debt_details.go`**

Fields: UUID PK, TenantMixin, `account_id` (UUID, unique), `counterparty` (string), `interest_rate` (float64), `amortization_method` (string enum), `start_date`, `due_date`, `total_principal_cents` (int64), `version` (int64, default 1), timestamps.

Indexes: `tenant_id`, UNIQUE `(tenant_id, account_id)`.

- [ ] **Step 2: Create `internal/debt/ent/schema/payment_schedule.go`**

Fields: UUID PK, `debt_id` (FK → DebtDetails, cascade delete), `payment_date`, `principal_cents`, `interest_cents`, `total_cents`, `paid` (bool, default false), `paid_cents` (int64, default 0), `transaction_id` (optional UUID), timestamps.

- [ ] **Step 3: Generate + verify**

---

## Task B3: Domain Layer

- [ ] **Step 1: Create `internal/debt/domain/valueobject.go`**

```go
type AmortizationMethod int
const (
    AmortizationEqualPrincipalInterest AmortizationMethod = iota + 1
    AmortizationEqualPrincipal
    AmortizationLumpSum
)
```

- [ ] **Step 2: Create `internal/debt/domain/entity.go`**

DebtDetails entity + PaymentScheduleEntry. Constructor validates: positive principal, valid date range, non-empty counterparty.

Methods: `GenerateSchedule()` (delegates to AmortizationCalculator), `MarkPaid()`, `RemainingPrincipal()`, `TermInMonths()`.

- [ ] **Step 3: Create `internal/debt/domain/service.go`**

`AmortizationCalculator` with three strategies:
- **LumpSum**: single entry at due_date; interest = principal * rate * (months/12)
- **EqualPrincipalInterest**: payment = P * r * (1+r)^n / ((1+r)^n - 1)
- **EqualPrincipal**: fixed monthly principal = total/months; interest = remaining * monthly_rate

Write comprehensive unit tests for each formula.

- [ ] **Step 4: Create `internal/debt/domain/repository.go`**

```go
type DebtRepository interface {
    Save(ctx context.Context, debt *DebtDetails) error
    FindByID(ctx context.Context, tenantID, id uuid.UUID) (*DebtDetails, error)
    FindAll(ctx context.Context, tenantID uuid.UUID, page PageRequest) (*PaginatedResult[DebtDetails], error)
    Update(ctx context.Context, debt *DebtDetails) error
    Delete(ctx context.Context, tenantID, id uuid.UUID) error
    FindUpcomingPayments(ctx context.Context, tenantID uuid.UUID, daysAhead int) ([]PaymentScheduleEntry, error)
}
```

- [ ] **Step 5: Write domain tests** — amortization formulas, schedule generation, mark paid.

---

## Task B4: Application Layer

- [ ] **Step 1: Create dto.go** — DebtDTOs, Create/Update/Delete/RecordPayment DTOs.
- [ ] **Step 2: Create service.go** — `CreateDebt()` (create + generate schedule), `RecordPayment()` (mark paid + create transaction entries), `GetUpcomingPayments()`.
- [ ] **Step 3: Write tests**

---

## Task B5: Driven Adapter + gRPC + Wire

- [ ] **Step 1: Create debt_repo.go** — entGo implementation.
- [ ] **Step 2: Create debt_handler.go** — gRPC DebtServiceServer.
- [ ] **Step 3: Wire integration** — update wire files + main.go.
- [ ] **Step 4: Verify** — `go build ./cmd/server`

---

## Task B6: Debt Integration Tests

- [ ] **Step 1: Create `tests/debt_integration_test.go`**

```go
func TestDebtCRUD(t *testing.T)                      // Create → Get → Update → Delete
func TestEqualPrincipalInterestSchedule(t *testing.T) // Verify amortization formula
func TestEqualPrincipalSchedule(t *testing.T)          // Verify amortization formula
func TestLumpSumSchedule(t *testing.T)                 // Verify amortization formula
func TestRecordPayment(t *testing.T)                   // Mark paid → verify transaction created + balance updated
func TestDebtTenantIsolation(t *testing.T)             // Tenant A debt invisible to B
```

- [ ] **Step 2: Run tests**
- [ ] **Step 3: Commit** — `feat: implement Debt module`

---

# Part C: Goal Module

## File Structure

```
yucai/
├── proto/goal/v1/
│   └── goal.proto
│
└── server/internal/goal/
    ├── domain/
    │   ├── entity.go                # Goal entity
    │   ├── valueobject.go           # GoalType enum
    │   └── repository.go            # GoalRepository interface
    ├── application/
    │   ├── service.go
    │   └── dto.go
    ├── adapter/driven/
    │   └── repository/
    │       └── goal_repo.go
    ├── adapter/driving/
    │   └── grpc/
    │       └── goal_handler.go
    └── ent/schema/
        └── goal.go
```

---

## Task C1: Protobuf Goal Service Definition

- [ ] **Step 1: Create `proto/goal/v1/goal.proto`**

```protobuf
syntax = "proto3";
package yucai.goal.v1;
option go_package = "github.com/yucai/server/internal/proto/goal/v1";

import "common/v1/pagination.proto";
import "google/protobuf/empty.proto";
import "google/protobuf/timestamp.proto";

service GoalService {
  rpc CreateGoal(CreateGoalRequest) returns (GoalResponse);
  rpc UpdateGoal(UpdateGoalRequest) returns (GoalResponse);
  rpc UpdateGoalProgress(UpdateProgressRequest) returns (GoalResponse);
  rpc CompleteGoal(CompleteGoalRequest) returns (google.protobuf.Empty);
  rpc DeleteGoal(DeleteGoalRequest) returns (google.protobuf.Empty);
  rpc SyncGoalProgress(SyncGoalProgressRequest) returns (GoalResponse);
  rpc GetGoal(GetGoalRequest) returns (GoalDetailResponse);
  rpc ListGoals(ListGoalsRequest) returns (ListGoalsResponse);
}

enum GoalType {
  GOAL_TYPE_UNSPECIFIED = 0;
  GOAL_TYPE_SAVINGS = 1;
  GOAL_TYPE_DEBT_PAYOFF = 2;
  GOAL_TYPE_INVESTMENT = 3;
}

message GoalDTO {
  string id = 1;
  string name = 2;
  GoalType goal_type = 3;
  int64 target_amount_cents = 4;
  int64 current_amount_cents = 5;
  string currency_code = 6;
  google.protobuf.Timestamp deadline = 7;
  string linked_account_id = 8;
  string notes = 9;
  bool is_completed = 10;
  google.protobuf.Timestamp completed_at = 11;
  double progress_pct = 12;
  int64 remaining_cents = 13;
  int64 version = 14;
  google.protobuf.Timestamp created_at = 15;
  google.protobuf.Timestamp updated_at = 16;
}

message CreateGoalRequest {
  string name = 1;
  GoalType goal_type = 2;
  int64 target_amount_cents = 3;
  string currency_code = 4;
  string deadline = 5;               // ISO 8601 date, optional
  string linked_account_id = 6;      // optional
  string notes = 7;
}

message UpdateGoalRequest {
  string id = 1;
  string name = 2;
  int64 target_amount_cents = 3;
  string deadline = 4;
  string notes = 5;
  int64 version = 6;
}

message UpdateProgressRequest {
  string id = 1;
  int64 amount_cents = 2;            // Amount to add
}

message CompleteGoalRequest { string id = 1; }
message DeleteGoalRequest { string id = 1; }
message SyncGoalProgressRequest { string id = 1; }
message GetGoalRequest { string id = 1; }

message ListGoalsRequest {
  yucai.common.v1.PageRequest page = 1;
  bool completed = 2;                // filter: true=completed, false=active, absent=all
}

message ListGoalsResponse {
  repeated GoalDTO goals = 1;
  yucai.common.v1.PageResponse page = 2;
}

message GoalResponse { GoalDTO goal = 1; }
message GoalDetailResponse { GoalDTO goal = 1; }
```

- [ ] **Step 2: Run `buf generate`**
- [ ] **Step 3: Verify**

---

## Task C2: entGo Schema

- [ ] **Step 1: Create `internal/goal/ent/schema/goal.go`**

Fields: UUID PK, TenantMixin, `name`, `goal_type` (string enum), `target_amount_cents` (int64), `current_amount_cents` (int64, default 0), `currency_code`, `deadline` (optional time), `linked_account_id` (optional UUID), `notes` (optional), `is_completed` (bool, default false), `completed_at` (optional), `version` (int64, default 1), timestamps.

Indexes: `(tenant_id, is_completed)`, `tenant_id`.

- [ ] **Step 2: Generate + verify**

---

## Task C3: Domain Layer

- [ ] **Step 1: Create `internal/goal/domain/valueobject.go`** — `GoalType` enum (Savings, DebtPayoff, Investment).
- [ ] **Step 2: Create `internal/goal/domain/entity.go`** — Goal entity with constructor validation. Methods: `AddProgress()`, `MarkCompleted()`, `ProgressPct()`, `RemainingAmount()`, `IsOverdue()`, `LinkAccount()`.
- [ ] **Step 3: Create `internal/goal/domain/repository.go`**

```go
type GoalRepository interface {
    Save(ctx context.Context, goal *Goal) error
    FindByID(ctx context.Context, tenantID, id uuid.UUID) (*Goal, error)
    FindAll(ctx context.Context, tenantID uuid.UUID, completed *bool, page PageRequest) (*PaginatedResult[Goal], error)
    Update(ctx context.Context, goal *Goal) error
    Delete(ctx context.Context, tenantID, id uuid.UUID) error
}
```

- [ ] **Step 4: Write domain tests** — progress tracking, auto-complete, overdue detection.

---

## Task C4–C7: Application, Adapter, gRPC, Wire, Tests

(Same pattern as Budget — follow Tasks A4–A7 structure)

- [ ] **Task C4: Application Layer** — dto.go + service.go with CreateGoal, UpdateGoal, UpdateProgress, CompleteGoal, SyncGoalProgress (reads linked account balance), ListGoals.
- [ ] **Task C5: Driven Adapter** — goal_repo.go with entGo implementation.
- [ ] **Task C6: gRPC + Wire** — goal_handler.go + wire integration.
- [ ] **Task C7: Integration Tests**

```go
func TestGoalCRUD(t *testing.T)              // Create → Get → Update → Delete
func TestGoalProgress(t *testing.T)          // AddProgress → verify auto-complete when target reached
func TestGoalSyncFromAccount(t *testing.T)   // Link account → SyncGoalProgress → current = account balance
func TestGoalOverdue(t *testing.T)           // Set past deadline → IsOverdue
func TestGoalTenantIsolation(t *testing.T)   // Cross-tenant invisibility
```

- [ ] **Commit** — `feat: implement Goal module`

---

## Self-Review

| Spec Section | Covered by Task |
|---|---|
| Budget aggregate + items | A3 (domain) |
| Budget actuals computation | A3 (service) |
| Budget clone to month | A3 (domain method), A4 (service) |
| Debt amortization formulas | B3 (service) |
| Payment schedule generation | B3 (domain) |
| Record payment + transaction | B4 (service) |
| Goal progress tracking | C3 (domain) |
| Goal auto-complete | C3 (domain method) |
| Goal account sync | C4 (service) |
| All gRPC services | A6, B5, C6 |
| Wire DI integration | A6, B5, C6 |
