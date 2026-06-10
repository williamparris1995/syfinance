# Plan 06: Tag + Recurring Transaction Modules

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement two transaction-enhancement modules — Tag (labeling system for transactions) and TransactionTemplate (recurring/scheduled transaction templates with auto-generation). Both depend on Transaction.

**Architecture:** Explicit Architecture with DDD, Hexagonal Ports & Adapters, CQRS.

**Depends on:** Plan 1 (shared kernel) + Plan 2 (auth) + Plan 3 (Account) + Plan 4 (Transaction)

**Design Specs:**
- [Functional Modules](../specs/2026-06-09-functional-modules-design.md) — Sections 6, 8

---

# Part A: Tag Module

## File Structure

```
yucai/
├── proto/tag/v1/
│   └── tag.proto
│
└── server/internal/tag/
    ├── domain/
    │   ├── entity.go                # Tag entity
    │   └── repository.go            # TagRepository interface
    │
    ├── application/
    │   ├── service.go               # TagApplicationService
    │   └── dto.go                   # DTOs + mappers
    │
    ├── adapter/driven/
    │   └── repository/
    │       └── tag_repo.go          # entGo TagRepository
    │
    ├── adapter/driving/
    │   └── grpc/
    │       └── tag_handler.go       # gRPC TagService
    │
    └── ent/schema/
        ├── tag.go                   # Tag schema + TenantMixin
        └── transaction_tag.go       # Junction table

Modified:
├── server/wire/wire.go, wire_gen.go, app.go, providers.go
└── server/cmd/server/main.go
```

---

## Task A1: Protobuf Tag Service Definition

- [ ] **Step 1: Create `proto/tag/v1/tag.proto`**

```protobuf
syntax = "proto3";
package yucai.tag.v1;
option go_package = "github.com/yucai/server/internal/proto/tag/v1";

import "common/v1/pagination.proto";
import "google/protobuf/empty.proto";
import "google/protobuf/timestamp.proto";

service TagService {
  rpc CreateTag(CreateTagRequest) returns (TagResponse);
  rpc UpdateTag(UpdateTagRequest) returns (TagResponse);
  rpc DeleteTag(DeleteTagRequest) returns (google.protobuf.Empty);
  rpc ListTags(ListTagsRequest) returns (ListTagsResponse);
  rpc AddTagToTransaction(TagTransactionRequest) returns (google.protobuf.Empty);
  rpc RemoveTagFromTransaction(TagTransactionRequest) returns (google.protobuf.Empty);
  rpc GetTransactionTags(GetTransactionTagsRequest) returns (ListTagsResponse);
}

message TagDTO {
  string id = 1;
  string name = 2;
  string color = 3;
  int64 version = 4;
  google.protobuf.Timestamp created_at = 5;
  google.protobuf.Timestamp updated_at = 6;
}

message CreateTagRequest {
  string name = 1;
  string color = 2;                 // hex color, e.g. "#FF5733"
}

message UpdateTagRequest {
  string id = 1;
  string name = 2;
  string color = 3;
  int64 version = 4;
}

message DeleteTagRequest { string id = 1; }

message ListTagsRequest {
  yucai.common.v1.PageRequest page = 1;
  string search = 2;                // optional fuzzy search
}

message ListTagsResponse {
  repeated TagDTO tags = 1;
  yucai.common.v1.PageResponse page = 2;
}

message TagTransactionRequest {
  string tag_id = 1;
  string transaction_id = 2;
}

message GetTransactionTagsRequest {
  string transaction_id = 1;
}

message TagResponse { TagDTO tag = 1; }
```

- [ ] **Step 2: Run `buf generate`**
- [ ] **Step 3: Verify generated files**

---

## Task A2: entGo Schema (Tag + TransactionTag)

- [ ] **Step 1: Create `internal/tag/ent/schema/tag.go`**

Fields: UUID PK, TenantMixin, `name` (string, unique per tenant), `color` (string, hex), `version` (int64, default 1), `deleted_at` (optional), timestamps.

Indexes: UNIQUE `(tenant_id, name)`, `tenant_id`.

- [ ] **Step 2: Create `internal/tag/ent/schema/transaction_tag.go`**

Fields: UUID PK, `transaction_id` (UUID), `tag_id` (UUID FK → Tag), timestamps.

Constraint: UNIQUE `(transaction_id, tag_id)`.

- [ ] **Step 3: Generate + verify**

---

## Task A3: Domain Layer

- [ ] **Step 1: Create `internal/tag/domain/entity.go`**

```go
type Tag struct {
    ID        uuid.UUID
    TenantID  uuid.UUID
    Name      string
    Color     string
    Version   int64
    DeletedAt *time.Time
    CreatedAt time.Time
    UpdatedAt time.Time
}
```

Constructor `NewTag(tenantID uuid.UUID, name, color string) (*Tag, error)` validates: non-empty trimmed name, valid hex color format.

Methods: `UpdateName()`, `UpdateColor()`, `SoftDelete()`, `IncrementVersion()`.

- [ ] **Step 2: Create `internal/tag/domain/repository.go`**

```go
type TagRepository interface {
    Save(ctx context.Context, tag *Tag) error
    FindByID(ctx context.Context, tenantID, id uuid.UUID) (*Tag, error)
    FindAll(ctx context.Context, tenantID uuid.UUID, search string, page PageRequest) (*PaginatedResult[Tag], error)
    Update(ctx context.Context, tag *Tag) error
    SoftDelete(ctx context.Context, tenantID, id uuid.UUID) error
    // Tag-transaction junction
    AddTagToTransaction(ctx context.Context, tagID, transactionID uuid.UUID) error
    RemoveTagFromTransaction(ctx context.Context, tagID, transactionID uuid.UUID) error
    FindByTransaction(ctx context.Context, tenantID, transactionID uuid.UUID) ([]Tag, error)
}
```

- [ ] **Step 3: Write domain tests** — creation, validation, soft delete.

---

## Task A4: Application Layer

- [ ] **Step 1: Create dto.go** — `CreateTagRequest`, `UpdateTagRequest`, `TagDTO`, `ListTagsResult`. Mapper: `TagToDTO()`.
- [ ] **Step 2: Create service.go** — Methods: `CreateTag()`, `UpdateTag()`, `DeleteTag()`, `ListTags()`, `AddTagToTransaction()`, `RemoveTagFromTransaction()`, `GetTransactionTags()`.
- [ ] **Step 3: Write tests** — mock repo, test CRUD and tag-transaction association.

---

## Task A5: Driven Adapter (Repository)

- [ ] **Step 1: Create `internal/tag/adapter/driven/repository/tag_repo.go`**

Implement using entGo. `FindAll` supports optional name fuzzy search. Junction operations (`AddTagToTransaction`, `RemoveTagFromTransaction`, `FindByTransaction`) query the `transaction_tags` table.

- [ ] **Step 2: Write tests** — CRUD, uniqueness constraint, junction operations.

---

## Task A6: gRPC + Wire + Tests

- [ ] **Step 1: Create `internal/tag/adapter/driving/grpc/tag_handler.go`**
- [ ] **Step 2: Wire integration** — update wire files + main.go.
- [ ] **Step 3: Verify** — `go build ./cmd/server`
- [ ] **Step 4: Create `tests/tag_integration_test.go`**

```go
func TestTagCRUD(t *testing.T)                  // Create → Get → Update → Delete
func TestTagNameUniqueness(t *testing.T)         // Duplicate name within tenant → error
func TestTagTransactionAssociation(t *testing.T)  // Add tag → GetTransactionTags → Remove → verify gone
func TestTagSoftDelete(t *testing.T)              // Delete → List should not include
func TestTagSearch(t *testing.T)                  // Create tags → search by name
func TestTagTenantIsolation(t *testing.T)         // Cross-tenant invisibility
```

- [ ] **Step 5: Run tests**
- [ ] **Step 6: Commit** — `feat: implement Tag module`

---

# Part B: Recurring Transaction (TransactionTemplate) Module

## File Structure

```
yucai/
├── proto/template/v1/
│   └── template.proto
│
└── server/internal/template/
    ├── domain/
    │   ├── entity.go                # TransactionTemplate entity
    │   ├── valueobject.go           # TemplateDirection, TemplateCycle enums
    │   ├── service.go               # NextDateCalculator domain service
    │   └── repository.go            # TemplateRepository interface
    │
    ├── application/
    │   ├── service.go               # TemplateApplicationService + auto-record logic
    │   └── dto.go
    │
    ├── adapter/driven/
    │   └── repository/
    │       └── template_repo.go
    │
    ├── adapter/driving/
    │   └── grpc/
    │       └── template_handler.go
    │
    └── ent/schema/
        └── transaction_template.go
```

---

## Task B1: Protobuf Template Service Definition

- [ ] **Step 1: Create `proto/template/v1/template.proto`**

```protobuf
syntax = "proto3";
package yucai.template.v1;
option go_package = "github.com/yucai/server/internal/proto/template/v1";

import "common/v1/pagination.proto";
import "google/protobuf/empty.proto";
import "google/protobuf/timestamp.proto";

service TransactionTemplateService {
  rpc CreateTransactionTemplate(CreateTemplateRequest) returns (TemplateResponse);
  rpc UpdateTransactionTemplate(UpdateTemplateRequest) returns (TemplateResponse);
  rpc DeleteTransactionTemplate(DeleteTemplateRequest) returns (google.protobuf.Empty);
  rpc PauseTransactionTemplate(PauseTemplateRequest) returns (TemplateResponse);
  rpc ResumeTransactionTemplate(ResumeTemplateRequest) returns (TemplateResponse);
  rpc GetTransactionTemplate(GetTemplateRequest) returns (TemplateResponse);
  rpc ListTransactionTemplates(ListTemplatesRequest) returns (ListTemplatesResponse);
}

enum TemplateDirection {
  DIRECTION_UNSPECIFIED = 0;
  DIRECTION_EXPENSE = 1;
  DIRECTION_INCOME = 2;
  DIRECTION_TRANSFER = 3;
}

enum TemplateCycle {
  CYCLE_UNSPECIFIED = 0;
  CYCLE_WEEKLY = 1;
  CYCLE_MONTHLY = 2;
  CYCLE_YEARLY = 3;
  CYCLE_CUSTOM = 4;
}

message TemplateDTO {
  string id = 1;
  string name = 2;
  string description = 3;
  int64 amount_cents = 4;
  TemplateDirection direction = 5;
  string source_account_id = 6;
  string destination_account_id = 7;
  TemplateCycle cycle = 8;
  int32 cycle_days = 9;
  int32 billing_day = 10;
  string next_date = 11;
  string start_date = 12;
  string end_date = 13;
  bool auto_record = 14;
  bool paused = 15;
  string last_transaction_id = 16;
  string category = 17;
  int64 version = 18;
  google.protobuf.Timestamp created_at = 19;
  google.protobuf.Timestamp updated_at = 20;
}

message CreateTemplateRequest {
  string name = 1;
  string description = 2;
  int64 amount_cents = 3;
  TemplateDirection direction = 4;
  string source_account_id = 5;
  string destination_account_id = 6;
  TemplateCycle cycle = 7;
  int32 cycle_days = 8;
  int32 billing_day = 9;
  string start_date = 10;
  string end_date = 11;
  bool auto_record = 12;
  string category = 13;
}

message UpdateTemplateRequest {
  string id = 1;
  string name = 2;
  string description = 3;
  int64 amount_cents = 4;
  TemplateCycle cycle = 5;
  int32 cycle_days = 6;
  string end_date = 7;
  bool auto_record = 8;
  int64 version = 9;
}

message DeleteTemplateRequest { string id = 1; }
message PauseTemplateRequest { string id = 1; }
message ResumeTemplateRequest { string id = 1; }
message GetTemplateRequest { string id = 1; }

message ListTemplatesRequest {
  yucai.common.v1.PageRequest page = 1;
  bool paused = 2;                  // filter: true=paused, false=active, absent=all
}

message ListTemplatesResponse {
  repeated TemplateDTO templates = 1;
  yucai.common.v1.PageResponse page = 2;
}

message TemplateResponse { TemplateDTO template = 1; }
```

- [ ] **Step 2: Run `buf generate`**
- [ ] **Step 3: Verify**

---

## Task B2: entGo Schema

- [ ] **Step 1: Create `internal/template/ent/schema/transaction_template.go`**

Fields: UUID PK, TenantMixin, `name`, `description` (optional), `amount_cents` (int64), `direction` (string enum), `source_account_id` (UUID), `destination_account_id` (optional UUID), `cycle` (string enum), `cycle_days` (optional int32), `billing_day` (optional int32), `next_date` (time), `start_date` (time), `end_date` (optional time), `auto_record` (bool, default false), `paused` (bool, default false), `last_transaction_id` (optional UUID), `category` (optional string), `version` (int64, default 1), timestamps.

Indexes: `(tenant_id, paused, next_date)`, `tenant_id`.

- [ ] **Step 2: Generate + verify**

---

## Task B3: Domain Layer

- [ ] **Step 1: Create `internal/template/domain/valueobject.go`**

```go
type TemplateDirection int // Expense, Income, Transfer
type TemplateCycle int    // Weekly, Monthly, Yearly, Custom
```

With `String()` and `Parse*()` methods.

- [ ] **Step 2: Create `internal/template/domain/entity.go`**

TransactionTemplate entity with constructor. Methods: `IsDue()`, `CalculateNextDate()`, `AdvanceToNext()`, `Pause()`, `Resume()`, `IncrementVersion()`.

`CalculateNextDate()` handles month-end clamping (Jan 31 → Feb 28).

- [ ] **Step 3: Create `internal/template/domain/service.go`**

`NextDateCalculator` — encapsulates date arithmetic for each cycle type. Handles edge cases: month-end clamping, leap years.

- [ ] **Step 4: Create `internal/template/domain/repository.go`**

```go
type TemplateRepository interface {
    Save(ctx context.Context, tmpl *TransactionTemplate) error
    FindByID(ctx context.Context, tenantID, id uuid.UUID) (*TransactionTemplate, error)
    FindAll(ctx context.Context, tenantID uuid.UUID, paused *bool, page PageRequest) (*PaginatedResult[TransactionTemplate], error)
    FindDue(ctx context.Context, today time.Time) ([]TransactionTemplate, error)
    Update(ctx context.Context, tmpl *TransactionTemplate) error
    Delete(ctx context.Context, tenantID, id uuid.UUID) error
}
```

- [ ] **Step 5: Write domain tests** — IsDue, CalculateNextDate (month-end clamping), Pause/Resume.

---

## Task B4: Application Layer

- [ ] **Step 1: Create dto.go** — DTOs for all operations + `TemplateToDTO()` mapper.
- [ ] **Step 2: Create service.go** — Methods: `CreateTemplate()`, `UpdateTemplate()`, `DeleteTemplate()`, `PauseTemplate()`, `ResumeTemplate()`, `ListTemplates()`.
- [ ] **Step 3: Create `internal/template/application/scheduler.go`**

`Scheduler` runs as a background goroutine (5-minute interval). Each tick:
1. Query `FindDue(today)` for all due templates across all tenants
2. For each due template with `auto_record=true`: create transaction via TransactionService
3. Call `AdvanceToNext()` on the template
4. Update template in repo

- [ ] **Step 4: Write tests** — mock repo, test scheduler tick logic.

---

## Task B5: Driven Adapter + gRPC + Wire

- [ ] **Step 1: Create `internal/template/adapter/driven/repository/template_repo.go`** — entGo implementation. `FindDue` queries WHERE `paused=false AND next_date <= ? AND deleted_at IS NULL`.
- [ ] **Step 2: Create `internal/template/adapter/driving/grpc/template_handler.go`**
- [ ] **Step 3: Wire integration** — update wire files + main.go. Start scheduler in main.go as background task.
- [ ] **Step 4: Verify** — `go build ./cmd/server`

---

## Task B6: Integration Tests

- [ ] **Step 1: Create `tests/template_integration_test.go`**

```go
func TestTemplateCRUD(t *testing.T)               // Create → Get → Update → Delete
func TestTemplatePauseResume(t *testing.T)         // Pause → List paused=true → Resume
func TestTemplateIsDue(t *testing.T)                // Set next_date to today → IsDue
func TestTemplateAdvanceToNext(t *testing.T)        // Monthly cycle → advance → next_date shifted
func TestTemplateMonthEndClamping(t *testing.T)     // Jan 31 → Feb 28
func TestTemplateAutoRecord(t *testing.T)           // auto_record=true → scheduler creates transaction
func TestTemplateTenantIsolation(t *testing.T)      // Cross-tenant invisibility
```

- [ ] **Step 2: Run tests**
- [ ] **Step 3: Commit** — `feat: implement TransactionTemplate module`

---

## Self-Review

| Spec Section | Covered by Task |
|---|---|
| Tag entity + soft delete | A3 (domain) |
| Tag-transaction junction | A3 (repository), A5 (repo) |
| Tag name uniqueness | A2 (schema UNIQUE) |
| Template entity | B3 (domain) |
| Template cycle calculation | B3 (service) |
| Template auto-record scheduler | B4 (scheduler) |
| Month-end clamping | B3 (service) |
| Pause/Resume | B3 (domain methods) |
| All gRPC services | A6, B5 |
| Wire DI integration | A6, B5 |
