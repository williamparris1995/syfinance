# Plan 3: Account Module

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the Account module — chart of accounts, account CRUD, balance tracking, tenant-scoped queries with cursor-based pagination. Account is the core aggregate root referenced by the Transaction module.

**Architecture:** Explicit Architecture with DDD, Hexagonal Ports & Adapters, CQRS.

**Depends on:** Plan 1 (shared kernel) + Plan 2 (auth, tenant isolation, JWT context)

**Design Specs:**
- [Architecture Redesign](../specs/2026-06-09-architecture-redesign-design.md) — Section 2 (Account)
- [Functional Modules](../specs/2026-06-09-functional-modules-design.md)

---

## File Structure

```
yucai/
├── proto/account/v1/
│   └── account.proto                # AccountService gRPC definition
│
└── server/internal/account/
    ├── domain/
    │   ├── entity.go                # Account, ChartOfAccount entities
    │   ├── valueobject.go           # AccountType, Ownership, AccountStatus, BalanceDirection
    │   ├── event.go                 # AccountCreated, BalanceUpdated events
    │   ├── service.go               # BalanceCalculator domain service
    │   └── repository.go            # AccountRepository, ChartRepository interfaces
    │
    ├── application/
    │   ├── command/
    │   │   ├── create.go            # CreateAccount handler
    │   │   ├── update.go            # UpdateAccount handler
    │   │   └── delete.go            # DeleteAccount handler (soft delete)
    │   ├── query/
    │   │   ├── get.go               # GetAccount handler
    │   │   └── list.go              # ListAccounts handler (paginated)
    │   ├── service.go               # AccountApplicationService
    │   └── dto.go                   # DTOs
    │
    ├── adapter/driven/
    │   ├── repository/
    │   │   ├── account_repo.go      # entGo AccountRepository
    │   │   └── chart_repo.go        # entGo ChartRepository
    │   └── eventpub/
    │       └── publisher.go         # Implement port.EventPublisher (async or sync)
    │
    ├── adapter/driving/
    │   └── grpc/
    │       └── account_handler.go   # gRPC AccountService implementation
    │
    └── ent/schema/
        ├── account.go               # Account schema + TenantMixin
        └── chart_of_accounts.go     # ChartOfAccount schema + TenantMixin

Modified:
├── server/wire/wire.go              # Wire account module
├── server/wire/app.go               # Add AccountService to App
└── server/cmd/server/main.go        # Register AccountService with gRPC
```

---

## Task 1: Protobuf Account Service Definition

- [ ] **Step 1: Create `proto/account/v1/account.proto`**

```protobuf
syntax = "proto3";
package yucai.account.v1;
option go_package = "github.com/yucai/server/internal/proto/account/v1";

import "common/v1/money.proto";
import "common/v1/pagination.proto";
import "google/protobuf/empty.proto";
import "google/protobuf/timestamp.proto";

service AccountService {
  rpc CreateAccount(CreateAccountRequest) returns (AccountResponse);
  rpc GetAccount(GetAccountRequest) returns (AccountResponse);
  rpc ListAccounts(ListAccountsRequest) returns (ListAccountsResponse);
  rpc UpdateAccount(UpdateAccountRequest) returns (AccountResponse);
  rpc DeleteAccount(DeleteAccountRequest) returns (google.protobuf.Empty);
}

enum AccountType {
  ACCOUNT_TYPE_UNSPECIFIED = 0;
  ACCOUNT_TYPE_ASSET = 1;
  ACCOUNT_TYPE_LIABILITY = 2;
  ACCOUNT_TYPE_EQUITY = 3;
  ACCOUNT_TYPE_INCOME = 4;
  ACCOUNT_TYPE_EXPENSE = 5;
}

enum Ownership {
  OWNERSHIP_UNSPECIFIED = 0;
  OWNERSHIP_PERSONAL = 1;
  OWNERSHIP_JOINT = 2;
}

enum AccountStatus {
  ACCOUNT_STATUS_UNSPECIFIED = 0;
  ACCOUNT_STATUS_ACTIVE = 1;
  ACCOUNT_STATUS_ARCHIVED = 2;
}

message AccountDTO {
  string id = 1;
  string name = 2;
  AccountType account_type = 3;
  string currency_code = 4;
  yucai.common.v1.Money initial_balance = 5;
  yucai.common.v1.Money current_balance = 6;
  Ownership ownership = 7;
  string icon = 8;
  string color = 9;
  string chart_code = 10;
  string parent_id = 11;
  string institution = 12;
  yucai.common.v1.Money credit_limit = 13;
  AccountStatus status = 14;
  int64 version = 15;
  google.protobuf.Timestamp created_at = 16;
  google.protobuf.Timestamp updated_at = 17;
}

message CreateAccountRequest {
  string name = 1;
  AccountType account_type = 2;
  string currency_code = 3;
  int64 initial_balance_cents = 4;
  Ownership ownership = 5;
  string icon = 6;
  string color = 7;
  string chart_code = 8;
  string parent_id = 9;
  string institution = 10;
  int64 credit_limit_cents = 11;
}

message GetAccountRequest { string id = 1; }

message ListAccountsRequest {
  yucai.common.v1.PageRequest page = 1;
  AccountType account_type = 2;  // optional filter
  AccountStatus status = 3;       // optional filter
}

message ListAccountsResponse {
  repeated AccountDTO accounts = 1;
  yucai.common.v1.PageResponse page = 2;
}

message UpdateAccountRequest {
  string id = 1;
  string name = 2;
  string icon = 3;
  string color = 4;
  string chart_code = 5;
  string institution = 6;
  int64 credit_limit_cents = 7;
  int64 version = 8;  // optimistic lock
}

message DeleteAccountRequest {
  string id = 1;
}

message AccountResponse { AccountDTO account = 1; }
```

- [ ] **Step 2: Run `buf generate`**
- [ ] **Step 3: Verify generated files**

---

## Task 2: entGo Schema (Account + ChartOfAccounts)

- [ ] **Step 1: Create `internal/account/ent/schema/account.go`**

Fields: UUID PK, embed TenantMixin, `name` (required), `account_type` (enum), `currency_code` (default "CNY"), `initial_balance_cents` (int64, default 0), `current_balance_cents` (int64, default 0), `ownership` (enum), `icon`, `color`, `chart_code`, `parent_id` (optional UUID), `institution`, `credit_limit_cents` (int64, default 0), `status` (enum, default active), `version` (int64, default 1), `deleted_at` (optional), timestamps.

Indexes: `tenant_id`, `(tenant_id, account_type)`, `(tenant_id, status)`.

- [ ] **Step 2: Create `internal/account/ent/schema/chart_of_accounts.go`**

Fields: UUID PK, embed TenantMixin, `code` (unique per tenant), `name`, `level` (int), `account_type` (enum), `parent_code` (optional), `balance_direction` (enum: debit/credit), timestamps.

Indexes: `(tenant_id, code)` unique, `tenant_id`.

- [ ] **Step 3: Generate entGo code** — `go generate ./internal/ent/...`
- [ ] **Step 4: Verify compilation**

---

## Task 3: Domain Layer

- [ ] **Step 1: Create `internal/account/domain/valueobject.go`**

```go
type AccountType int
const (
    AccountTypeAsset      AccountType = iota + 1
    AccountTypeLiability
    AccountTypeEquity
    AccountTypeIncome
    AccountTypeExpense
)

type Ownership int      // Personal, Joint
type AccountStatus int  // Active, Archived
type BalanceDirection int // Debit, Credit
```

Each enum has `String()`, `FromString()`, and `Proto()` methods.

- [ ] **Step 2: Create `internal/account/domain/entity.go`**

Account entity with constructor `NewAccount(tenantID uuid.UUID, name string, accountType AccountType, ...)` that validates all fields. Methods: `UpdateName()`, `Archive()`, `SoftDelete()`, `IncrementVersion()`.

ChartOfAccount entity with constructor. Immutable after creation.

- [ ] **Step 3: Create `internal/account/domain/event.go`**

```go
type AccountCreated struct {
    baseEvent
    AccountID   uuid.UUID
    AccountType AccountType
}

type BalanceUpdated struct {
    baseEvent
    AccountID      uuid.UUID
    PreviousCents  int64
    NewCents       int64
}
```

- [ ] **Step 4: Create `internal/account/domain/service.go`**

`BalanceCalculator` with method:
```go
func CalculateBalance(accountType AccountType, initialCents int64, debitTotal int64, creditTotal int64) int64
```

Rules:
- Asset/Expense: `initial + debits - credits`
- Liability/Equity/Income: `initial + credits - debits`

- [ ] **Step 5: Create `internal/account/domain/repository.go`**

```go
type AccountRepository interface {
    Save(ctx context.Context, account *Account) error
    FindByID(ctx context.Context, tenantID, id uuid.UUID) (*Account, error)
    FindAll(ctx context.Context, tenantID uuid.UUID, filter AccountFilter, page types.PageRequest) (*types.PaginatedResult[Account], error)
    Update(ctx context.Context, account *Account) error  // optimistic lock via version
    SoftDelete(ctx context.Context, tenantID, id uuid.UUID) error
}

type AccountFilter struct {
    AccountType *AccountType
    Status      *AccountStatus
}

type ChartRepository interface {
    Save(ctx context.Context, chart *ChartOfAccount) error
    FindByCode(ctx context.Context, tenantID uuid.UUID, code string) (*ChartOfAccount, error)
    FindAll(ctx context.Context, tenantID uuid.UUID) ([]ChartOfAccount, error)
}
```

---

## Task 4: Application Layer (CQRS Handlers)

- [ ] **Step 1: Create `internal/account/application/dto.go`**

DTOs: `CreateAccountRequest`, `UpdateAccountRequest`, `AccountDTO`, `ListAccountsRequest`, `ListAccountsResult`.

Mapper function: `AccountToDTO(account *domain.Account) AccountDTO`.

- [ ] **Step 2: Create command handlers** (`create.go`, `update.go`, `delete.go`)

`CreateAccountHandler`: validate → construct domain entity → repo.Save → emit AccountCreated event → return DTO.

`UpdateAccountHandler`: repo.FindByID → validate version → update fields → repo.Update (optimistic lock) → return DTO. If version mismatch, return `ErrOptimisticLock`.

`DeleteAccountHandler`: repo.SoftDelete (only if balance is zero).

- [ ] **Step 3: Create query handlers** (`get.go`, `list.go`)

`GetAccountHandler`: repo.FindByID → return DTO.

`ListAccountsHandler`: repo.FindAll with filters + pagination → return PaginatedResult[AccountDTO].

- [ ] **Step 4: Create `internal/account/application/service.go`**

`AccountApplicationService` holds command/query buses. Provides convenience methods matching gRPC RPCs.

- [ ] **Step 5: Write tests** — test create/update/delete flows, pagination, optimistic lock rejection.

---

## Task 5: Driven Adapters (Repositories)

- [ ] **Step 1: Create `internal/account/adapter/driven/repository/account_repo.go`**

Implement `domain.AccountRepository` using entGo. Key behaviors:
- `Save`: entGo `client.Account.Create().Set*().Save(ctx)`
- `FindByID`: filter by `tenant_id AND id`, exclude `deleted_at IS NOT NULL`
- `FindAll`: build dynamic query with optional type/status filters, cursor-based pagination using `created_at` + `id` as cursor, limit `page_size + 1` to detect next page
- `Update`: `WHERE id = ? AND version = ? AND tenant_id = ?`, increment version
- `SoftDelete`: `UPDATE SET deleted_at = now(), status = archived WHERE id = ? AND tenant_id = ?`

- [ ] **Step 2: Create `internal/account/adapter/driven/repository/chart_repo.go`**

Similar pattern for ChartOfAccount. Simpler — no pagination, no soft delete.

- [ ] **Step 3: Create `internal/account/adapter/driven/eventpub/publisher.go`**

Simple synchronous implementation of `port.EventPublisher` that logs events. Async/event-driven can be added later.

- [ ] **Step 4: Write tests** — test CRUD, tenant isolation, soft delete filtering, pagination.

---

## Task 6: gRPC Driving Adapter

- [ ] **Step 1: Create `internal/account/adapter/driving/grpc/account_handler.go`**

Implement generated `AccountServiceServer`. Each method:
1. Extract `tenant_id` from JWT context (via middleware helper function `GetTenantID(ctx)`)
2. Map proto request to application DTO
3. Call AccountApplicationService method
4. Map domain DTO to proto response

Error mapping: `ErrNotFound` → `codes.NotFound`, `ErrValidation` → `codes.InvalidArgument`, `ErrOptimisticLock` → `codes.Aborted`, `ErrUnauthorized` → `codes.Unauthenticated`.

- [ ] **Step 2: Add helper `pkg/middleware/context.go`**

```go
func GetTenantID(ctx context.Context) (uuid.UUID, error)
func GetUserID(ctx context.Context) (uuid.UUID, error)
```

Extract values set by auth interceptor.

---

## Task 7: Wire Integration + Server Registration

- [ ] **Step 1: Update `wire/app.go`** — Add `AccountService *account.application.Service` to App.
- [ ] **Step 2: Update `wire/wire.go`** — Add account module providers: account repo, chart repo, event publisher, CQRS handlers, application service.
- [ ] **Step 3: Update `cmd/server/main.go`** — Register `AccountService` with gRPC server.
- [ ] **Step 4: Generate Wire** — `wire ./wire/...`
- [ ] **Step 5: Verify** — `go build ./cmd/server && go test ./...`

---

## Task 8: Integration Tests

- [ ] **Step 1: Create `tests/account_integration_test.go`**

```go
func TestAccountCRUD(t *testing.T) {
    // Create → Get → Update → List → Delete → Verify gone
}

func TestTenantIsolation(t *testing.T) {
    // Create account for tenant A, try to access from tenant B → NOT_FOUND
}

func TestPagination(t *testing.T) {
    // Create 25 accounts, page through with page_size=10
}

func TestSoftDelete(t *testing.T) {
    // Create → Delete → List should not include deleted
}

func TestOptimisticLock(t *testing.T) {
    // Concurrent update → one gets ABORTED
}
```

- [ ] **Step 2: Run tests**
- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: implement Account module — chart of accounts, CRUD, balance tracking, gRPC AccountService"
```

---

## Self-Review

| Spec Section | Covered by Task |
|---|---|
| Account entity with 18 fields | Task 2 (schema), Task 3 (domain) |
| ChartOfAccounts per tenant | Task 2 (schema), Task 3 (domain) |
| Chinese chart of accounts | Task 3 (seed data, deferred to runtime) |
| AccountType enum (5 types) | Task 3 (valueobject) |
| BalanceCalculator | Task 3 (domain service) |
| Cursor-based pagination | Task 4 (query handler), Task 5 (repo) |
| Optimistic locking (version) | Task 4 (update handler), Task 5 (repo) |
| Soft delete | Task 4 (delete handler), Task 5 (repo) |
| Domain events | Task 3 (events), Task 5 (publisher) |
| gRPC AccountService (5 RPCs) | Task 6 (handler) |
| Wire DI integration | Task 7 |
| Tenant isolation | Task 5 (repo WHERE), Task 6 (context) |
