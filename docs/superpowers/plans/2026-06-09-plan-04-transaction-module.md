# Plan 4: Transaction Module

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the Transaction module — double-entry bookkeeping with debit/credit entries, balance validation, and convenience RPCs (SimpleIncome/Expense/Transfer). This is the core accounting engine.

**Architecture:** Explicit Architecture with DDD, Hexagonal Ports & Adapters, CQRS.

**Depends on:** Plan 1 (shared kernel) + Plan 2 (auth) + Plan 3 (Account module — account entities, BalanceCalculator, AccountRepository)

**Design Specs:**
- [Architecture Redesign](../specs/2026-06-09-architecture-redesign-design.md) — Section 2 (Transaction)
- [Functional Modules](../specs/2026-06-09-functional-modules-design.md)

---

## File Structure

```
yucai/
├── proto/transaction/v1/
│   └── transaction.proto            # TransactionService gRPC definition
│
└── server/internal/transaction/
    ├── domain/
    │   ├── entity.go                # Transaction, TransactionEntry entities
    │   ├── valueobject.go           # EntryType enum
    │   ├── event.go                 # TransactionRecorded event
    │   ├── service.go               # DoubleEntryValidator domain service
    │   └── repository.go            # TransactionRepository interface
    │
    ├── application/
    │   ├── command/
    │   │   ├── record.go            # RecordTransaction handler
    │   │   ├── update.go            # UpdateTransaction handler
    │   │   ├── delete.go            # DeleteTransaction handler (soft delete)
    │   │   └── simple.go            # SimpleIncome/Expense/Transfer handlers
    │   ├── query/
    │   │   ├── get.go               # GetTransaction handler
    │   │   └── list.go              # ListTransactions handler (filtered + paginated)
    │   ├── service.go               # TransactionApplicationService
    │   └── dto.go                   # DTOs
    │
    ├── adapter/driven/
    │   ├── repository/
    │   │   └── transaction_repo.go  # entGo TransactionRepository
    │   └── balance_updater.go       # Cross-module: update account balances
    │
    ├── adapter/driving/
    │   └── grpc/
    │       └── transaction_handler.go  # gRPC TransactionService implementation
    │
    └── ent/schema/
        ├── transaction.go           # Transaction schema + TenantMixin
        └── transaction_entry.go     # TransactionEntry schema with XOR CHECK

Modified:
├── server/wire/wire.go              # Wire transaction module
├── server/wire/app.go               # Add TransactionService to App
└── server/cmd/server/main.go        # Register TransactionService with gRPC
```

---

## Task 1: Protobuf Transaction Service Definition

- [ ] **Step 1: Create `proto/transaction/v1/transaction.proto`**

```protobuf
syntax = "proto3";
package yucai.transaction.v1;
option go_package = "github.com/yucai/server/internal/proto/transaction/v1";

import "common/v1/money.proto";
import "common/v1/pagination.proto";
import "google/protobuf/empty.proto";
import "google/protobuf/timestamp.proto";

service TransactionService {
  rpc RecordTransaction(RecordTransactionRequest) returns (TransactionResponse);
  rpc GetTransaction(GetTransactionRequest) returns (TransactionResponse);
  rpc ListTransactions(ListTransactionsRequest) returns (ListTransactionsResponse);
  rpc UpdateTransaction(UpdateTransactionRequest) returns (TransactionResponse);
  rpc DeleteTransaction(DeleteTransactionRequest) returns (google.protobuf.Empty);
  rpc SimpleIncome(SimpleIncomeRequest) returns (TransactionResponse);
  rpc SimpleExpense(SimpleExpenseRequest) returns (TransactionResponse);
  rpc SimpleTransfer(SimpleTransferRequest) returns (TransactionResponse);
}

message TransactionDTO {
  string id = 1;
  string transaction_date = 2;   // ISO 8601 date
  string description = 3;
  repeated EntryDTO entries = 4;
  int64 version = 5;
  google.protobuf.Timestamp created_at = 6;
  google.protobuf.Timestamp updated_at = 7;
}

message EntryDTO {
  string id = 1;
  string account_id = 2;
  string chart_of_account_code = 3;
  int64 debit_cents = 4;
  int64 credit_cents = 5;
  string note = 6;
}

message RecordTransactionRequest {
  string transaction_date = 1;
  string description = 2;
  repeated EntryDTO entries = 3;
}

message GetTransactionRequest { string id = 1; }

message ListTransactionsRequest {
  yucai.common.v1.PageRequest page = 1;
  string account_id = 2;         // optional filter
  string date_from = 3;           // optional, ISO 8601
  string date_to = 4;             // optional, ISO 8601
}

message ListTransactionsResponse {
  repeated TransactionDTO transactions = 1;
  yucai.common.v1.PageResponse page = 2;
}

message UpdateTransactionRequest {
  string id = 1;
  string transaction_date = 2;
  string description = 3;
  repeated EntryDTO entries = 4;
  int64 version = 5;
}

message DeleteTransactionRequest { string id = 1; }

// Convenience RPCs — server creates the correct entries
message SimpleIncomeRequest {
  string transaction_date = 1;
  string description = 2;
  string asset_account_id = 3;    // debit (receive money)
  string income_account_id = 4;   // credit (income source)
  int64 amount_cents = 5;
  string note = 6;
}

message SimpleExpenseRequest {
  string transaction_date = 1;
  string description = 2;
  string expense_account_id = 3;  // debit (spend category)
  string asset_account_id = 4;    // credit (pay from)
  int64 amount_cents = 5;
  string note = 6;
}

message SimpleTransferRequest {
  string transaction_date = 1;
  string description = 2;
  string from_account_id = 3;     // credit (source)
  string to_account_id = 4;       // debit (destination)
  int64 amount_cents = 5;
  string note = 6;
}

message TransactionResponse { TransactionDTO transaction = 1; }
```

- [ ] **Step 2: Run `buf generate`**
- [ ] **Step 3: Verify generated files**

---

## Task 2: entGo Schema (Transaction + TransactionEntry)

- [ ] **Step 1: Create `internal/transaction/ent/schema/transaction.go`**

Fields: UUID PK, embed TenantMixin, `transaction_date` (date), `description` (string), `version` (int64, default 1), `deleted_at` (optional), timestamps.

Indexes: `tenant_id`, `(tenant_id, transaction_date)`.

- [ ] **Step 2: Create `internal/transaction/ent/schema/transaction_entry.go`**

Fields: UUID PK, `transaction_id` (FK → Transaction, cascade delete), `account_id` (UUID), `chart_of_account_code` (string), `debit_cents` (int64, default 0), `credit_cents` (int64, default 0), `note` (string, optional).

**CRITICAL:** Add PostgreSQL CHECK constraint:
```go
func (TransactionEntry) Annotations() []entschema.Annotation {
    return []entschema.Annotation{
        entsql.Annotation{
            Check: "chk_debit_credit_xor CHECK ((debit_cents > 0 AND credit_cents = 0) OR (credit_cents > 0 AND debit_cents = 0))",
        },
    }
}
```

Indexes: `transaction_id`, `account_id`.

- [ ] **Step 3: Generate entGo code** — `go generate ./internal/ent/...`
- [ ] **Step 4: Verify compilation**

---

## Task 3: Domain Layer

- [ ] **Step 1: Create `internal/transaction/domain/valueobject.go`**

```go
type EntryType int
const (
    EntryTypeDebit  EntryType = iota + 1
    EntryTypeCredit
)
```

- [ ] **Step 2: Create `internal/transaction/domain/entity.go`**

```go
type Transaction struct {
    ID              uuid.UUID
    TenantID        uuid.UUID
    TransactionDate time.Time
    Description     string
    Entries         []TransactionEntry
    Version         int64
    CreatedAt       time.Time
    UpdatedAt       time.Time
    DeletedAt       *time.Time
}

type TransactionEntry struct {
    ID                 uuid.UUID
    TransactionID      uuid.UUID
    AccountID          uuid.UUID
    ChartOfAccountCode string
    DebitCents         int64
    CreditCents        int64
    Note               string
}
```

Constructor `NewTransaction(tenantID uuid.UUID, date time.Time, description string, entries []TransactionEntry) (*Transaction, error)` validates:
- At least 2 entries
- Each entry has debit XOR credit (not both, not neither)
- Calls DoubleEntryValidator

- [ ] **Step 3: Create `internal/transaction/domain/service.go`**

```go
type DoubleEntryValidator struct{}

func (v *DoubleEntryValidator) Validate(entries []TransactionEntry) error {
    var totalDebits, totalCredits int64
    for _, e := range entries {
        if e.DebitCents > 0 && e.CreditCents > 0 {
            return errors.New("entry cannot have both debit and credit")
        }
        if e.DebitCents == 0 && e.CreditCents == 0 {
            return errors.New("entry must have either debit or credit")
        }
        totalDebits += e.DebitCents
        totalCredits += e.CreditCents
    }
    if totalDebits != totalCredits {
        return fmt.Errorf("double-entry violation: debits=%d != credits=%d", totalDebits, totalCredits)
    }
    return nil
}
```

- [ ] **Step 4: Create `internal/transaction/domain/event.go`**

```go
type TransactionRecorded struct {
    baseEvent
    TransactionID uuid.UUID
    EntryCount    int
}
```

- [ ] **Step 5: Create `internal/transaction/domain/repository.go`**

```go
type TransactionRepository interface {
    Save(ctx context.Context, tx *Transaction) error
    FindByID(ctx context.Context, tenantID, id uuid.UUID) (*Transaction, error)
    FindAll(ctx context.Context, tenantID uuid.UUID, filter TransactionFilter, page types.PageRequest) (*types.PaginatedResult[Transaction], error)
    Update(ctx context.Context, tx *Transaction) error
    SoftDelete(ctx context.Context, tenantID, id uuid.UUID) error
}

type TransactionFilter struct {
    AccountID *uuid.UUID
    DateFrom  *time.Time
    DateTo    *time.Time
}
```

- [ ] **Step 6: Write domain tests** — test DoubleEntryValidator with valid/invalid entries, test Transaction constructor validation.

---

## Task 4: Application Layer (Core CQRS Handlers)

- [ ] **Step 1: Create `internal/transaction/application/dto.go`**

DTOs: `RecordTransactionRequest`, `UpdateTransactionRequest`, `TransactionDTO`, `EntryDTO`, `ListTransactionsRequest`, `TransactionFilter`.

Mapper: `TransactionToDTO(tx *domain.Transaction) TransactionDTO`.

- [ ] **Step 2: Create `internal/transaction/application/command/record.go`**

`RecordTransactionHandler`:
1. Parse entries from DTO → domain TransactionEntry slice
2. Call `domain.NewTransaction()` (validates double-entry)
3. `repo.Save()` (persists transaction + entries)
4. Call `BalanceUpdater.UpdateBalances()` for each affected account
5. Emit `TransactionRecorded` event
6. Return DTO

- [ ] **Step 3: Create `internal/transaction/application/command/update.go`**

`UpdateTransactionHandler`:
1. Find existing transaction (verify version for optimistic lock)
2. Validate new entries (double-entry)
3. Reverse old balance effects
4. Apply new balance effects
5. `repo.Update()`
6. Return DTO

- [ ] **Step 4: Create `internal/transaction/application/command/delete.go`**

`DeleteTransactionHandler`:
1. Find transaction with entries
2. Reverse all balance effects (negate each entry's contribution)
3. `repo.SoftDelete()`
4. Return nil

- [ ] **Step 5: Create query handlers** (`get.go`, `list.go`)

`GetTransactionHandler`: repo.FindByID → return DTO (with entries).

`ListTransactionsHandler`: repo.FindAll with optional account/date filters + cursor-based pagination. Cursor = `(transaction_date, id)`.

---

## Task 5: Application Layer (Simple* Convenience Handlers)

- [ ] **Step 1: Create `internal/transaction/application/command/simple.go`**

Three handlers that build entries internally:

**SimpleIncomeHandler**: Given asset_account_id, income_account_id, amount:
- Entry 1: debit asset_account, amount cents
- Entry 2: credit income_account, amount cents
- Call RecordTransaction internally

**SimpleExpenseHandler**: Given expense_account_id, asset_account_id, amount:
- Entry 1: debit expense_account, amount cents
- Entry 2: credit asset_account, amount cents
- Call RecordTransaction internally

**SimpleTransferHandler**: Given from_account_id, to_account_id, amount:
- Entry 1: debit to_account, amount cents
- Entry 2: credit from_account, amount cents
- Call RecordTransaction internally

- [ ] **Step 2: Write tests** — test each Simple* handler produces correct debit/credit entries.

---

## Task 6: Driven Adapters (Repository + Balance Updater)

- [ ] **Step 1: Create `internal/transaction/adapter/driven/repository/transaction_repo.go`**

Implement `domain.TransactionRepository` using entGo. Key behaviors:
- `Save`: create Transaction, then batch create TransactionEntries in a transaction
- `FindByID`: eager-load entries, filter by tenant_id, exclude soft-deleted
- `FindAll`: build dynamic query with optional account_id join + date range, cursor-based pagination using `(transaction_date, id)`, limit `page_size + 1`
- `Update`: delete old entries, insert new entries, update transaction fields, WHERE version = ?
- `SoftDelete`: set deleted_at, cascade soft-delete entries

- [ ] **Step 2: Create `internal/transaction/adapter/driven/balance_updater.go`**

Cross-module balance updater. Depends on `account.domain.AccountRepository`:
```go
type BalanceUpdater struct {
    accountRepo accountdomain.AccountRepository
}

func (u *BalanceUpdater) UpdateBalances(ctx context.Context, entries []domain.TransactionEntry) error
```

For each unique account_id in entries:
1. Sum all debit_cents and credit_cents from ALL transaction entries for this account
2. Call `domain.BalanceCalculator.CalculateBalance()` with account type + totals
3. Update account's `current_balance_cents`

**Alternative (simpler for V1):** Increment/decrement balance directly instead of full recalculation. This avoids the cross-module query but can drift over time. Add a periodic reconciliation job later.

Recommendation: Use **direct increment/decrement** for V1:
```go
func (u *BalanceUpdater) ApplyEntry(ctx context.Context, accountID uuid.UUID, debitCents, creditCents int64) error {
    // For asset/expense accounts: balance += debitCents - creditCents
    // For liability/equity/income accounts: balance += creditCents - debitCents
    // Need account type from accountRepo to determine direction
}
```

- [ ] **Step 3: Write tests** — test repo CRUD, test balance updater with mock account repo.

---

## Task 7: gRPC Driving Adapter + Wire Integration

- [ ] **Step 1: Create `internal/transaction/adapter/driving/grpc/transaction_handler.go`**

Implement generated `TransactionServiceServer`. Map all 8 RPCs to application service methods.

Error mapping same as Account module.

- [ ] **Step 2: Update `wire/app.go`** — Add `TransactionService` to App.
- [ ] **Step 3: Update `wire/wire.go`** — Add transaction module providers.
- [ ] **Step 4: Update `cmd/server/main.go`** — Register TransactionService.
- [ ] **Step 5: Generate Wire** — `wire ./wire/...`
- [ ] **Step 6: Verify** — `go build ./cmd/server && go test ./...`

---

## Task 8: Integration Tests

- [ ] **Step 1: Create `tests/transaction_integration_test.go`**

```go
func TestRecordTransaction(t *testing.T) {
    // Create 2 accounts, record transaction with 2 entries, verify balance update
}

func TestDoubleEntryValidation(t *testing.T) {
    // Record with unbalanced entries → BALANCE_VIOLATION error
}

func TestSimpleIncome(t *testing.T) {
    // SimpleIncome → verify debit asset + credit income
}

func TestSimpleExpense(t *testing.T) {
    // SimpleExpense → verify debit expense + credit asset
}

func TestSimpleTransfer(t *testing.T) {
    // SimpleTransfer → verify debit target + credit source
}

func TestDeleteReversesBalance(t *testing.T) {
    // Record → verify balance → Delete → verify balance reversed
}

func TestDateRangeFilter(t *testing.T) {
    // Create transactions on different dates, filter by range
}

func TestTenantIsolation(t *testing.T) {
    // Record for tenant A, try to access from tenant B → NOT_FOUND
}
```

- [ ] **Step 2: Run tests**
- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: implement Transaction module — double-entry bookkeeping, Simple* RPCs, balance tracking"
```

---

## Self-Review

| Spec Section | Covered by Task |
|---|---|
| Transaction entity (aggregate root) | Task 3 (domain) |
| TransactionEntry with debit/credit XOR | Task 2 (schema CHECK), Task 3 (domain) |
| DoubleEntryValidator | Task 3 (domain service) |
| sum(debits) == sum(credits) | Task 3 (validator), Task 4 (handler calls validator) |
| RecordTransaction RPC | Task 4 (command handler) |
| UpdateTransaction RPC | Task 4 (command handler) |
| DeleteTransaction RPC (soft) | Task 4 (command handler) |
| Get/List RPCs (filtered, paginated) | Task 4 (query handlers) |
| SimpleIncome/Expense/Transfer | Task 5 (convenience handlers) |
| Balance update after transaction | Task 6 (balance updater) |
| Balance reversal on delete | Task 4 (delete handler), Task 6 (balance updater) |
| gRPC TransactionService (8 RPCs) | Task 7 (handler) |
| Wire DI integration | Task 7 |
| Tenant isolation | Task 6 (repo WHERE tenant_id) |

### Cross-Module Dependencies

Transaction module imports:
- `internal/account/domain` — AccountRepository interface, BalanceCalculator (for balance updater)
- `internal/shared/...` — Money, Pagination, DomainEvent, errors, CQRS bus, ports

Transaction does NOT import:
- Account's adapter layer (only domain interfaces)
- Auth module directly (tenant_id comes from context via middleware)
