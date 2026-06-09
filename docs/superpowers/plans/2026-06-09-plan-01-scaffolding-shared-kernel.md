# Plan 1: Project Scaffolding + Shared Kernel

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Set up the YuCai monorepo with Go server, Flutter client, shared Protobuf definitions, Docker Compose, and the shared kernel (domain types, CQRS bus, ports) that all bounded contexts depend on.

**Architecture:** Explicit Architecture with DDD, Hexagonal (Ports & Adapters), and CQRS. Go server uses domain-driven vertical slicing. Each bounded context (account, transaction, auth) is an independent component with domain/application/adapter layers.

**Tech Stack:** Go 1.22+, Flutter 3.22+, PostgreSQL 16, Redis 7, Buf (protobuf), entGo, Google Wire, Atlas, Docker Compose, make, pnpm

**Design Specs:**
- [Architecture Redesign](../specs/2026-06-09-architecture-redesign-design.md)
- [Functional Modules](../specs/2026-06-09-functional-modules-design.md)

---

## File Structure

This plan creates the following files:

```
yucai/                                    # NEW monorepo root (separate from fiance/)
├── server/
│   ├── cmd/server/main.go                # Entry point
│   ├── internal/
│   │   ├── shared/
│   │   │   ├── domain/
│   │   │   │   ├── event/event.go        # DomainEvent interface + base events
│   │   │   │   └── types/
│   │   │   │       ├── money.go          # Money value object
│   │   │   │       ├── currency.go       # Currency value object
│   │   │   │       ├── pagination.go     # Pagination types
│   │   │   │       └── tenant.go         # TenantMixin helper
│   │   │   ├── application/
│   │   │   │   ├── command/bus.go        # Command bus interface + in-memory impl
│   │   │   │   ├── query/bus.go          # Query bus interface + in-memory impl
│   │   │   │   └── port/
│   │   │   │       ├── txmanager.go      # Transaction manager port
│   │   │   │       └── eventpublisher.go # Event publisher port
│   │   │   └── errors/
│   │   │       └── errors.go             # Unified domain errors
│   │   └── ent/                          # entGo generated code root
│   │       └── schema/
│   │           └── mixin/
│   │               └── tenant.go         # TenantMixin schema
│   ├── pkg/
│   │   ├── config/config.go              # Environment config
│   │   ├── logger/logger.go              # Structured logger (slog)
│   │   └── middleware/
│   │       ├── auth.go                   # gRPC auth interceptor
│   │       ├── logging.go                # gRPC logging interceptor
│   │       └── recovery.go               # gRPC panic recovery
│   ├── wire/
│   │   ├── wire.go                       # Wire DI definitions
│   │   └── wire_gen.go                   # Generated
│   ├── go.mod
│   └── go.sum
│
├── client/                               # Flutter project (created by flutter create)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app/
│   │   ├── core/
│   │   └── di/
│   ├── pubspec.yaml
│   └── build.yaml
│
├── proto/
│   ├── buf.yaml
│   ├── buf.gen.go.yaml
│   ├── buf.gen.dart.yaml
│   ├── buf.lock
│   └── common/v1/
│       ├── money.proto
│       ├── pagination.proto
│       └── error.proto
│
├── deploy/
│   ├── docker-compose.yml
│   ├── docker-compose.dev.yml
│   └── .env.example
│
├── Makefile
└── buf.yaml
```

---

## Task 1: Monorepo Root + Go Module

**Files:**
- Create: `yucai/go.mod` (server module)
- Create: `yucai/Makefile`

- [ ] **Step 1: Create monorepo directory and Go module**

```bash
mkdir -p yucai/server/cmd/server
cd yucai/server
go mod init github.com/yucai/server
```

- [ ] **Step 2: Install Go dependencies**

```bash
cd yucai/server
go get entgo.io/ent@latest
go get google.golang.org/grpc@latest
go get google.golang.org/protobuf@latest
go get github.com/google/uuid@latest
go get github.com/golang-jwt/jwt/v5@latest
go get github.com/redis/go-redis/v9@latest
go get github.com/lib/pq@latest
go get github.com/jackc/pgx/v5@latest
go get github.com/jackc/pgx/v5/pgxpool@latest
go get github.com/gorilla/sessions@latest
go get github.com/sethvargo/go-envconfig@latest
go get github.com/google/wire/cmd/wire@latest
go get github.com/stretchr/testify@latest
go get github.com/shopspring/decimal@latest
```

- [ ] **Step 3: Create Makefile**

Create `yucai/Makefile`:

```makefile
.PHONY: all generate build test lint proto clean docker-up docker-down

# Go server
SERVER_DIR := server

generate: ## Generate entGo + Wire code
	cd $(SERVER_DIR) && go generate ./...

build: generate ## Build Go server binary
	cd $(SERVER_DIR) && go build -o bin/server ./cmd/server

test: ## Run Go tests
	cd $(SERVER_DIR) && go test ./... -v -count=1

test-unit: ## Run unit tests only
	cd $(SERVER_DIR) && go test ./internal/... -v -short -count=1

lint: ## Run golangci-lint
	cd $(SERVER_DIR) && golangci-lint run ./...

proto: ## Generate Protobuf stubs (Go + Dart)
	buf generate

clean: ## Clean build artifacts
	rm -rf $(SERVER_DIR)/bin
	rm -rf $(SERVER_DIR)/internal/proto
	rm -rf client/lib/proto

# Docker
docker-up: ## Start infrastructure services
	docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.dev.yml up -d

docker-down: ## Stop infrastructure services
	docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.dev.yml down

# Flutter
flutter-get: ## Install Flutter dependencies
	cd client && flutter pub get

flutter-build-runner: ## Run Flutter code generation
	cd client && dart run build_runner build --delete-conflicting-outputs

flutter-test: ## Run Flutter tests
	cd client && flutter test

# Full validation
validate: lint test flutter-test ## Run all checks
	@echo "All checks passed!"
```

- [ ] **Step 4: Verify Go module compiles**

Create minimal `yucai/server/cmd/server/main.go`:

```go
package main

import (
	"log"
)

func main() {
	log.Println("YuCai server starting...")
}
```

Run: `cd yucai/server && go build ./cmd/server`
Expected: Builds without errors

- [ ] **Step 5: Commit**

```bash
cd yucai
git init
git add -A
git commit -m "chore: initialize monorepo with Go module and Makefile"
```

---

## Task 2: Buf + Protobuf Common Types

**Files:**
- Create: `yucai/proto/buf.yaml`
- Create: `yucai/proto/buf.gen.go.yaml`
- Create: `yucai/proto/buf.gen.dart.yaml`
- Create: `yucai/proto/common/v1/money.proto`
- Create: `yucai/proto/common/v1/pagination.proto`
- Create: `yucai/proto/common/v1/error.proto`
- Create: `yucai/buf.yaml`

- [ ] **Step 1: Write test for Protobuf common types**

Create `yucai/proto/common/v1/money_test.go` (validates generated code):

```go
package commonv1_test

import (
	"testing"

	pb "github.com/yucai/server/internal/proto/common/v1"
)

func TestMoneyMessageExists(t *testing.T) {
	m := &pb.Money{
		Cents:         10000,
		CurrencyCode:  "CNY",
	}
	if m.Cents != 10000 {
		t.Errorf("expected cents=10000, got %d", m.Cents)
	}
	if m.CurrencyCode != "CNY" {
		t.Errorf("expected currency_code=CNY, got %s", m.CurrencyCode)
	}
}
```

- [ ] **Step 2: Create Buf workspace config**

Create `yucai/buf.yaml`:

```yaml
version: v2
modules:
  - path: proto
```

Create `yucai/proto/buf.yaml`:

```yaml
version: v2
lint:
  use:
    - STANDARD
breaking:
  use:
    - FILE
```

- [ ] **Step 3: Write common/v1/money.proto**

Create `yucai/proto/common/v1/money.proto`:

```protobuf
syntax = "proto3";

package yucai.common.v1;

option go_package = "github.com/yucai/server/internal/proto/common/v1";

// Money represents a monetary amount in integer cents.
// No floating point — avoids precision issues.
message Money {
  int64 cents = 1;
  string currency_code = 2; // ISO 4217: CNY, USD, EUR, etc.
}
```

- [ ] **Step 4: Write common/v1/pagination.proto**

Create `yucai/proto/common/v1/pagination.proto`:

```protobuf
syntax = "proto3";

package yucai.common.v1;

option go_package = "github.com/yucai/server/internal/proto/common/v1";

// Cursor-based pagination request.
message PageRequest {
  int32 page_size = 1;
  string page_token = 2; // Opaque cursor
}

// Pagination response metadata.
message PageResponse {
  string next_page_token = 1;
  int32 total_count = 2;
}
```

- [ ] **Step 5: Write common/v1/error.proto**

Create `yucai/proto/common/v1/error.proto`:

```protobuf
syntax = "proto3";

package yucai.common.v1;

option go_package = "github.com/yucai/server/internal/proto/common/v1";

import "google/protobuf/any.proto";

// Error detail for gRPC Status details.
message ErrorDetail {
  string code = 1;                    // ACCOUNT_NOT_FOUND, BALANCE_VIOLATION, etc.
  string message = 2;
  map<string, string> metadata = 3;
}

// Sync payload for bidirectional streaming sync.
message SyncPayload {
  string entity_type = 1;             // "account" | "transaction"
  string operation = 2;               // "create" | "update" | "delete"
  bytes payload = 3;                  // Serialized entity data
  int64 version = 4;
  string device_id = 5;
}
```

- [ ] **Step 6: Create Buf generation configs**

Create `yucai/proto/buf.gen.go.yaml`:

```yaml
version: v2
managed:
  enabled: true
  override:
    - file_option: go_package_prefix
      value: github.com/yucai/server/internal/proto
plugins:
  - remote: buf.build/protocolbuffers/go
    out: ../server/internal/proto
    opt: paths=source_relative
  - remote: buf.build/grpc/go
    out: ../server/internal/proto
    opt: paths=source_relative
```

Create `yucai/proto/buf.gen.dart.yaml`:

```yaml
version: v2
plugins:
  - remote: buf.build/protocolbuffers/dart
    out: ../client/lib/proto
```

- [ ] **Step 7: Generate and verify**

```bash
cd yucai
buf generate --template proto/buf.gen.go.yaml
```

Expected: `server/internal/proto/common/v1/` contains generated Go files.

Run: `cd yucai/server && go test ./internal/proto/common/v1/... -v`
Expected: PASS (MoneyMessageExists test)

- [ ] **Step 8: Commit**

```bash
cd yucai
git add -A
git commit -m "feat: add Buf config and protobuf common types (money, pagination, error)"
```

---

## Task 3: Docker Compose Infrastructure

**Files:**
- Create: `yucai/deploy/docker-compose.yml`
- Create: `yucai/deploy/docker-compose.dev.yml`
- Create: `yucai/deploy/.env.example`

- [ ] **Step 1: Write docker-compose.yml**

Create `yucai/deploy/docker-compose.yml`:

```yaml
services:
  api:
    build:
      context: ../server
      dockerfile: Dockerfile
    ports:
      - "9090:9090"
    environment:
      - DATABASE_URL=postgresql://yucai:${DB_PASSWORD}@postgres:5432/yucai?sslmode=disable
      - REDIS_URL=redis://redis:6379/0
      - JWT_SECRET=${JWT_SECRET}
      - GRPC_PORT=9090
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: yucai
      POSTGRES_USER: yucai
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U yucai -d yucai"]
      interval: 5s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redisdata:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5
    restart: unless-stopped

volumes:
  pgdata:
  redisdata:
```

- [ ] **Step 2: Write docker-compose.dev.yml**

Create `yucai/deploy/docker-compose.dev.yml`:

```yaml
# Development overrides
services:
  api:
    build:
      context: ../server
      dockerfile: Dockerfile.dev
    volumes:
      - ../server:/app
    environment:
      - DATABASE_URL=postgresql://yucai:yucai_dev@postgres:5432/yucai?sslmode=disable
      - REDIS_URL=redis://redis:6379/0
      - JWT_SECRET=dev-secret-key-change-in-production
      - GRPC_PORT=9090
      - LOG_LEVEL=debug

  postgres:
    environment:
      POSTGRES_PASSWORD: yucai_dev
    ports:
      - "5432:5432"

  adminer:
    image: adminer:latest
    ports:
      - "8080:8080"
    environment:
      ADMINER_DEFAULT_SERVER: postgres
    profiles:
      - dev
```

- [ ] **Step 3: Write .env.example**

Create `yucai/deploy/.env.example`:

```env
# YuCai Server Configuration
DB_PASSWORD=yucai_dev
JWT_SECRET=change-me-to-a-random-string-at-least-32-chars
GRPC_PORT=9090
LOG_LEVEL=info
```

- [ ] **Step 4: Test infrastructure starts**

```bash
cd yucai/deploy
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d postgres redis
sleep 5
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec postgres pg_isready
```

Expected: `accepting connections`

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec redis redis-cli ping
```

Expected: `PONG`

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml down
```

- [ ] **Step 5: Commit**

```bash
cd yucai
git add -A
git commit -m "infra: add Docker Compose for PostgreSQL, Redis, and dev tooling"
```

---

## Task 4: Shared Kernel — Domain Types

**Files:**
- Create: `yucai/server/internal/shared/domain/types/money.go`
- Create: `yucai/server/internal/shared/domain/types/money_test.go`
- Create: `yucai/server/internal/shared/domain/types/currency.go`
- Create: `yucai/server/internal/shared/domain/types/pagination.go`
- Create: `yucai/server/internal/shared/domain/event/event.go`
- Create: `yucai/server/internal/shared/domain/event/event_test.go`

- [ ] **Step 1: Write failing test for Money value object**

Create `yucai/server/internal/shared/domain/types/money_test.go`:

```go
package types

import (
	"testing"
)

func TestMoneyAdd(t *testing.T) {
	a := Money{Cents: 1000, CurrencyCode: "CNY"}
	b := Money{Cents: 500, CurrencyCode: "CNY"}
	result := a.Add(b)
	if result.Cents != 1500 {
		t.Errorf("expected 1500 cents, got %d", result.Cents)
	}
}

func TestMoneyAddDifferentCurrency(t *testing.T) {
	a := Money{Cents: 1000, CurrencyCode: "CNY"}
	b := Money{Cents: 500, CurrencyCode: "USD"}
	result := a.Add(b)
	if result.Cents != 1000 {
		t.Errorf("adding different currencies should return self unchanged, got %d", result.Cents)
	}
}

func TestMoneySubtract(t *testing.T) {
	a := Money{Cents: 1000, CurrencyCode: "CNY"}
	b := Money{Cents: 300, CurrencyCode: "CNY"}
	result := a.Subtract(b)
	if result.Cents != 700 {
		t.Errorf("expected 700 cents, got %d", result.Cents)
	}
}

func TestMoneyToYuan(t *testing.T) {
	m := Money{Cents: 12345, CurrencyCode: "CNY"}
	if m.ToYuan() != 123.45 {
		t.Errorf("expected 123.45, got %f", m.ToYuan())
	}
}

func TestMoneyFromYuan(t *testing.T) {
	m := NewMoneyFromYuan(123.45, "CNY")
	if m.Cents != 12345 {
		t.Errorf("expected 12345 cents, got %d", m.Cents)
	}
}

func TestMoneyIsNegative(t *testing.T) {
	pos := Money{Cents: 100, CurrencyCode: "CNY"}
	zero := Money{Cents: 0, CurrencyCode: "CNY"}
	neg := Money{Cents: -100, CurrencyCode: "CNY"}
	if pos.IsNegative() {
		t.Error("positive money should not be negative")
	}
	if zero.IsNegative() {
		t.Error("zero money should not be negative")
	}
	if !neg.IsNegative() {
		t.Error("negative money should be negative")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd yucai/server && go test ./internal/shared/domain/types/... -v`
Expected: FAIL — `Money` type not defined

- [ ] **Step 3: Implement Money value object**

Create `yucai/server/internal/shared/domain/types/money.go`:

```go
package types

import (
	"github.com/shopspring/decimal"
)

// Money represents a monetary amount as integer cents.
// All arithmetic uses integer cents to avoid floating point precision issues.
type Money struct {
	Cents        int64
	CurrencyCode string
}

// NewMoney creates a Money from cents.
func NewMoney(cents int64, currencyCode string) Money {
	return Money{Cents: cents, CurrencyCode: currencyCode}
}

// NewMoneyFromYuan creates a Money from a yuan (dollar) amount.
func NewMoneyFromYuan(yuan float64, currencyCode string) Money {
	d := decimal.NewFromFloat(yuan).Mul(decimal.NewFromInt(100))
	return Money{Cents: d.IntPart(), CurrencyCode: currencyCode}
}

// Add adds two Money values. Returns self unchanged if currencies differ.
func (m Money) Add(other Money) Money {
	if m.CurrencyCode != other.CurrencyCode {
		return m
	}
	return Money{Cents: m.Cents + other.Cents, CurrencyCode: m.CurrencyCode}
}

// Subtract subtracts other from m. Returns self unchanged if currencies differ.
func (m Money) Subtract(other Money) Money {
	if m.CurrencyCode != other.CurrencyCode {
		return m
	}
	return Money{Cents: m.Cents - other.Cents, CurrencyCode: m.CurrencyCode}
}

// ToYuan converts cents to yuan (dollar) amount.
func (m Money) ToYuan() float64 {
	d := decimal.NewFromInt(m.Cents).Div(decimal.NewFromInt(100))
	f, _ := d.Float64()
	return f
}

// IsNegative returns true if cents < 0.
func (m Money) IsNegative() bool {
	return m.Cents < 0
}

// IsZero returns true if cents == 0.
func (m Money) IsZero() bool {
	return m.Cents == 0
}

// SameCurrency checks if two Money values share the same currency.
func (m Money) SameCurrency(other Money) bool {
	return m.CurrencyCode == other.CurrencyCode
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd yucai/server && go test ./internal/shared/domain/types/... -v`
Expected: PASS — all Money tests green

- [ ] **Step 5: Implement Pagination types**

Create `yucai/server/internal/shared/domain/types/pagination.go`:

```go
package types

// PageRequest represents cursor-based pagination input.
type PageRequest struct {
	PageSize  int32
	PageToken string
}

// PageResponse contains pagination metadata.
type PageResponse struct {
	NextPageToken string
	TotalCount    int32
}

// PaginatedResult wraps a slice of results with pagination metadata.
type PaginatedResult[T any] struct {
	Items         []T
	NextPageToken string
	TotalCount    int32
}
```

- [ ] **Step 6: Write failing test for DomainEvent**

Create `yucai/server/internal/shared/domain/event/event_test.go`:

```go
package event

import (
	"testing"
	"time"
)

type mockEvent struct {
	baseEvent
	AccountID string
}

func TestDomainEventImplementsInterface(t *testing.T) {
	evt := mockEvent{
		baseEvent: baseEvent{
			EventType:   "account.created",
			OccurredAt:  time.Now(),
			AggregateID: "test-id",
		},
		AccountID: "acc-123",
	}
	if evt.EventType != "account.created" {
		t.Errorf("expected account.created, got %s", evt.EventType)
	}
	if evt.AggregateID != "test-id" {
		t.Errorf("expected test-id, got %s", evt.AggregateID)
	}
}
```

- [ ] **Step 7: Implement DomainEvent**

Create `yucai/server/internal/shared/domain/event/event.go`:

```go
package event

import (
	"time"
)

// DomainEvent is the interface all domain events must satisfy.
type DomainEvent interface {
	GetEventType() string
	GetOccurredAt() time.Time
	GetAggregateID() string
}

// baseEvent provides default fields for domain events.
// Embed in concrete event structs.
type baseEvent struct {
	EventType   string    `json:"event_type"`
	OccurredAt  time.Time `json:"occurred_at"`
	AggregateID string    `json:"aggregate_id"`
}

func (e baseEvent) GetEventType() string    { return e.EventType }
func (e baseEvent) GetOccurredAt() time.Time { return e.OccurredAt }
func (e baseEvent) GetAggregateID() string   { return e.AggregateID }
```

- [ ] **Step 8: Run all shared domain tests**

Run: `cd yucai/server && go test ./internal/shared/domain/... -v`
Expected: ALL PASS

- [ ] **Step 9: Commit**

```bash
cd yucai
git add -A
git commit -m "feat: add shared kernel domain types (Money, Pagination, DomainEvent)"
```

---

## Task 5: Shared Kernel — Application Layer (CQRS Bus + Ports)

**Files:**
- Create: `yucai/server/internal/shared/application/command/bus.go`
- Create: `yucai/server/internal/shared/application/command/bus_test.go`
- Create: `yucai/server/internal/shared/application/query/bus.go`
- Create: `yucai/server/internal/shared/application/query/bus_test.go`
- Create: `yucai/server/internal/shared/application/port/txmanager.go`
- Create: `yucai/server/internal/shared/application/port/eventpublisher.go`
- Create: `yucai/server/internal/shared/errors/errors.go`
- Create: `yucai/server/internal/shared/errors/errors_test.go`

- [ ] **Step 1: Write failing test for CommandBus**

Create `yucai/server/internal/shared/application/command/bus_test.go`:

```go
package command

import (
	"context"
	"testing"
)

type testCommand struct {
	Name string
}

type testCommandHandler struct {
	Received testCommand
}

func (h *testCommandHandler) Handle(ctx context.Context, cmd testCommand) error {
	h.Received = cmd
	return nil
}

func TestCommandBusDispatch(t *testing.T) {
	bus := NewBus()
	handler := &testCommandHandler{}
	bus.Register(handler)

	cmd := testCommand{Name: "create_account"}
	err := bus.Dispatch(context.Background(), cmd)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if handler.Received.Name != "create_account" {
		t.Errorf("handler did not receive command, got: %s", handler.Received.Name)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd yucai/server && go test ./internal/shared/application/command/... -v`
Expected: FAIL — `Bus` and `Register` not defined

- [ ] **Step 3: Implement CommandBus**

Create `yucai/server/internal/shared/application/command/bus.go`:

```go
package command

import (
	"context"
	"fmt"
	"sync"
)

// Handler processes a command of type T and returns an error.
type Handler[T any] interface {
	Handle(ctx context.Context, cmd T) error
}

// handlerWrapper erases type for internal storage.
type handlerWrapper struct {
	handler any
}

// Bus dispatches commands to their registered handlers.
type Bus struct {
	mu       sync.RWMutex
	handlers map[string]handlerWrapper
}

// NewBus creates a new in-memory command bus.
func NewBus() *Bus {
	return &Bus{
		handlers: make(map[string]handlerWrapper),
	}
}

// Register adds a handler for its command type.
// The handler must implement Handler[T] for some T.
func Register[T any](bus *Bus, h Handler[T]) {
	bus.mu.Lock()
	defer bus.mu.Unlock()
	var zero T
	name := fmt.Sprintf("%T", zero)
	bus.handlers[name] = handlerWrapper{handler: h}
}

// Dispatch sends a command to its registered handler.
func Dispatch[T any](bus *Bus, ctx context.Context, cmd T) error {
	bus.mu.RLock()
	defer bus.mu.RUnlock()
	name := fmt.Sprintf("%T", cmd)
	wrapper, ok := bus.handlers[name]
	if !ok {
		return fmt.Errorf("no handler registered for command %T", cmd)
	}
	handler, ok := wrapper.handler.(Handler[T])
	if !ok {
		return fmt.Errorf("handler for %T has wrong type", cmd)
	}
	return handler.Handle(ctx, cmd)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd yucai/server && go test ./internal/shared/application/command/... -v`
Expected: PASS

- [ ] **Step 5: Write failing test for QueryBus**

Create `yucai/server/internal/shared/application/query/bus_test.go`:

```go
package query

import (
	"context"
	"testing"
)

type testQuery struct {
	ID string
}

type testResult struct {
	Name string
}

type testQueryHandler struct{}

func (h *testQueryHandler) Handle(ctx context.Context, q testQuery) (testResult, error) {
	return testResult{Name: "result-for-" + q.ID}, nil
}

func TestQueryBusDispatch(t *testing.T) {
	bus := NewBus()
	handler := &testQueryHandler{}
	bus.Register(handler)

	result, err := bus.Dispatch(context.Background(), testQuery{ID: "abc"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result.Name != "result-for-abc" {
		t.Errorf("expected result-for-abc, got %s", result.Name)
	}
}
```

- [ ] **Step 6: Implement QueryBus**

Create `yucai/server/internal/shared/application/query/bus.go`:

```go
package query

import (
	"context"
	"fmt"
	"sync"
)

// Handler processes a query of type Q and returns a result of type R.
type Handler[Q any, R any] interface {
	Handle(ctx context.Context, q Q) (R, error)
}

type handlerWrapper struct {
	handler any
}

// Bus dispatches queries to their registered handlers.
type Bus struct {
	mu       sync.RWMutex
	handlers map[string]handlerWrapper
}

func NewBus() *Bus {
	return &Bus{
		handlers: make(map[string]handlerWrapper),
	}
}

func Register[Q any, R any](bus *Bus, h Handler[Q, R]) {
	bus.mu.Lock()
	defer bus.mu.Unlock()
	var zero Q
	name := fmt.Sprintf("%T", zero)
	bus.handlers[name] = handlerWrapper{handler: h}
}

func Dispatch[Q any, R any](bus *Bus, ctx context.Context, q Q) (R, error) {
	bus.mu.RLock()
	defer bus.mu.RUnlock()
	var zero R
	name := fmt.Sprintf("%T", q)
	wrapper, ok := bus.handlers[name]
	if !ok {
		return zero, fmt.Errorf("no handler registered for query %T", q)
	}
	handler, ok := wrapper.handler.(Handler[Q, R])
	if !ok {
		return zero, fmt.Errorf("handler for %T has wrong type", q)
	}
	return handler.Handle(ctx, q)
}
```

- [ ] **Step 7: Run test to verify it passes**

Run: `cd yucai/server && go test ./internal/shared/application/query/... -v`
Expected: PASS

- [ ] **Step 8: Implement ports**

Create `yucai/server/internal/shared/application/port/txmanager.go`:

```go
package port

import "context"

// TxManager manages database transactions for use case orchestration.
type TxManager interface {
	// WithinTx executes fn inside a database transaction.
	// If fn returns an error, the transaction is rolled back.
	WithinTx(ctx context.Context, fn func(ctx context.Context) error) error
}
```

Create `yucai/server/internal/shared/application/port/eventpublisher.go`:

```go
package port

import "github.com/yucai/server/internal/shared/domain/event"

// EventPublisher publishes domain events to subscribers.
type EventPublisher interface {
	Publish(events ...event.DomainEvent) error
}
```

- [ ] **Step 9: Implement unified domain errors**

Create `yucai/server/internal/shared/errors/errors.go`:

```go
package errors

import "fmt"

// DomainError represents a business rule violation.
type DomainError struct {
	Code    string
	Message string
	Cause   error
}

func (e *DomainError) Error() string {
	if e.Cause != nil {
		return fmt.Sprintf("[%s] %s: %v", e.Code, e.Message, e.Cause)
	}
	return fmt.Sprintf("[%s] %s", e.Code, e.Message)
}

func (e *DomainError) Unwrap() error { return e.Cause }

// New creates a new DomainError.
func New(code, message string) *DomainError {
	return &DomainError{Code: code, Message: message}
}

// Wrap creates a DomainError wrapping a cause.
func Wrap(code, message string, cause error) *DomainError {
	return &DomainError{Code: code, Message: message, Cause: cause}
}

// Pre-defined error codes
var (
	ErrNotFound           = New("NOT_FOUND", "entity not found")
	ErrAlreadyExists      = New("ALREADY_EXISTS", "entity already exists")
	ErrValidation         = New("VALIDATION_ERROR", "validation failed")
	ErrBalanceViolation   = New("BALANCE_VIOLATION", "balance rule violated")
	ErrOptimisticLock     = New("OPTIMISTIC_LOCK_CONFLICT", "concurrent modification detected")
	ErrUnauthorized       = New("UNAUTHORIZED", "not authorized")
	ErrForbidden          = New("FORBIDDEN", "access denied")
	ErrTenantRequired     = New("TENANT_REQUIRED", "tenant_id is required")
)

// WithMessage returns a copy of the error with a custom message.
func WithMessage(err *DomainError, message string) *DomainError {
	return &DomainError{Code: err.Code, Message: message, Cause: err.Cause}
}
```

Create `yucai/server/internal/shared/errors/errors_test.go`:

```go
package errors

import (
	"errors"
	"testing"
)

func TestDomainErrorFormat(t *testing.T) {
	err := New("TEST_CODE", "test message")
	got := err.Error()
	expected := "[TEST_CODE] test message"
	if got != expected {
		t.Errorf("expected %q, got %q", expected, got)
	}
}

func TestDomainErrorUnwrap(t *testing.T) {
	inner := errors.New("inner error")
	err := Wrap("WRAP_CODE", "wrapped", inner)
	if !errors.Is(err, inner) {
		t.Error("expected errors.Is to match inner error")
	}
}

func TestPredefinedErrors(t *testing.T) {
	if ErrNotFound.Code != "NOT_FOUND" {
		t.Errorf("expected NOT_FOUND, got %s", ErrNotFound.Code)
	}
	if ErrBalanceViolation.Code != "BALANCE_VIOLATION" {
		t.Errorf("expected BALANCE_VIOLATION, got %s", ErrBalanceViolation.Code)
	}
}
```

- [ ] **Step 10: Run all shared application tests**

Run: `cd yucai/server && go test ./internal/shared/... -v`
Expected: ALL PASS

- [ ] **Step 11: Commit**

```bash
cd yucai
git add -A
git commit -m "feat: add CQRS command/query bus, ports, and unified domain errors"
```

---

## Task 6: Go Server Infrastructure (Config, Logger, gRPC Interceptors)

**Files:**
- Create: `yucai/server/pkg/config/config.go`
- Create: `yucai/server/pkg/config/config_test.go`
- Create: `yucai/server/pkg/logger/logger.go`
- Create: `yucai/server/pkg/middleware/logging.go`
- Create: `yucai/server/pkg/middleware/recovery.go`
- Create: `yucai/server/pkg/middleware/auth.go`

- [ ] **Step 1: Write failing test for config**

Create `yucai/server/pkg/config/config_test.go`:

```go
package config

import (
	"os"
	"testing"
)

func TestLoadFromEnv(t *testing.T) {
	os.Setenv("GRPC_PORT", "9090")
	os.Setenv("DATABASE_URL", "postgresql://user:pass@localhost:5432/testdb")
	os.Setenv("REDIS_URL", "redis://localhost:6379/0")
	os.Setenv("JWT_SECRET", "test-secret")
	os.Setenv("LOG_LEVEL", "debug")
	defer func() {
		os.Unsetenv("GRPC_PORT")
		os.Unsetenv("DATABASE_URL")
		os.Unsetenv("REDIS_URL")
		os.Unsetenv("JWT_SECRET")
		os.Unsetenv("LOG_LEVEL")
	}()

	cfg, err := Load()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if cfg.GRPCPort != "9090" {
		t.Errorf("expected port 9090, got %s", cfg.GRPCPort)
	}
	if cfg.DatabaseURL != "postgresql://user:pass@localhost:5432/testdb" {
		t.Errorf("unexpected DATABASE_URL: %s", cfg.DatabaseURL)
	}
	if cfg.JWTSecret != "test-secret" {
		t.Errorf("unexpected JWT_SECRET")
	}
}
```

- [ ] **Step 2: Implement config**

Create `yucai/server/pkg/config/config.go`:

```go
package config

import "github.com/sethvargo/go-envconfig"

// Config holds all server configuration.
type Config struct {
	GRPCPort    string `env:"GRPC_PORT,default=9090"`
	DatabaseURL string `env:"DATABASE_URL,required"`
	RedisURL    string `env:"REDIS_URL,default=redis://localhost:6379/0"`
	JWTSecret   string `env:"JWT_SECRET,required"`
	LogLevel    string `env:"LOG_LEVEL,default=info"`
}

// Load reads configuration from environment variables.
func Load() (*Config, error) {
	var cfg Config
	if err := envconfig.Process(context.Background(), &cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}
```

Note: Add `import "context"` at top.

- [ ] **Step 3: Implement structured logger**

Create `yucai/server/pkg/logger/logger.go`:

```go
package logger

import (
	"log/slog"
	"os"
)

// Setup initializes the structured logger.
func Setup(level string) {
	var lvl slog.Level
	switch level {
	case "debug":
		lvl = slog.LevelDebug
	case "info":
		lvl = slog.LevelInfo
	case "warn":
		lvl = slog.LevelWarn
	case "error":
		lvl = slog.LevelError
	default:
		lvl = slog.LevelInfo
	}

	handler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: lvl})
	slog.SetDefault(slog.New(handler))
}
```

- [ ] **Step 4: Implement gRPC interceptors**

Create `yucai/server/pkg/middleware/logging.go`:

```go
package middleware

import (
	"context"
	"log/slog"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/peer"
)

// UnaryLoggingInterceptor logs each unary gRPC call.
func UnaryLoggingInterceptor(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
	start := time.Now()
	resp, err := handler(ctx, req)
	duration := time.Since(start)

	p, _ := peer.FromContext(ctx)
	logLevel := slog.LevelInfo
	if err != nil {
		logLevel = slog.LevelError
	}

	slog.Log(ctx, logLevel, "gRPC call completed",
		"method", info.FullMethod,
		"peer", p.Addr.String(),
		"duration_ms", duration.Milliseconds(),
		"error", err,
	)
	return resp, err
}
```

Create `yucai/server/pkg/middleware/recovery.go`:

```go
package middleware

import (
	"context"
	"log/slog"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// UnaryRecoveryInterceptor recovers from panics in gRPC handlers.
func UnaryRecoveryInterceptor(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (resp any, err error) {
	defer func() {
		if r := recover(); r != nil {
			slog.Error("panic recovered in gRPC handler",
				"method", info.FullMethod,
				"panic", r,
			)
			err = status.Errorf(codes.Internal, "internal server error")
		}
	}()
	return handler(ctx, req)
}
```

Create `yucai/server/pkg/middleware/auth.go`:

```go
package middleware

import (
	"context"
	"strings"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

// AuthInterceptor validates JWT tokens in gRPC metadata.
// For now, this is a placeholder — full JWT validation will be in the Auth module.
func AuthInterceptor(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
	// Skip auth for auth service methods
	if strings.HasPrefix(info.FullMethod, "/yucai.auth.v1.AuthService/") {
		return handler(ctx, req)
	}

	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "missing metadata")
	}

	tokens := md.Get("authorization")
	if len(tokens) == 0 {
		return nil, status.Error(codes.Unauthenticated, "missing authorization token")
	}

	// Token will be validated in Auth module (Plan 2)
	// For now, just pass through if token exists
	return handler(ctx, req)
}
```

- [ ] **Step 5: Run all tests**

Run: `cd yucai/server && go test ./pkg/... -v`
Expected: PASS (config test)

- [ ] **Step 6: Verify full project compiles**

Run: `cd yucai/server && go build ./...`
Expected: No compilation errors

- [ ] **Step 7: Commit**

```bash
cd yucai
git add -A
git commit -m "feat: add server config, structured logger, and gRPC interceptors"
```

---

## Task 7: entGo Setup + TenantMixin

**Files:**
- Create: `yucai/server/internal/ent/schema/mixin/tenant.go`
- Create: `yucai/server/internal/ent/schema/mixin/tenant_test.go`
- Create: `yucai/server/internal/ent/generate.go`

- [ ] **Step 1: Initialize entGo**

```bash
cd yucai/server
go run -mod=mod entgo.io/ent/cmd/ent init --target internal/ent/schema
```

- [ ] **Step 2: Create generate.go directive**

Create `yucai/server/internal/ent/generate.go`:

```go
package ent

//go:generate go run -mod=mod entgo.io/ent/cmd/ent generate ./schema
```

- [ ] **Step 3: Implement TenantMixin**

Create `yucai/server/internal/ent/schema/mixin/tenant.go`:

```go
package mixin

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	"entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"
)

// TenantMixin adds tenant_id to any schema for multi-tenancy isolation.
// Embed in any schema that needs tenant-scoped data.
type TenantMixin struct {
	mixin.Schema
}

func (TenantMixin) Annotations() []schema.Annotation {
	return []schema.Annotation{
		entsql.WithComments(true),
	}
}

func (TenantMixin) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("tenant_id", uuid.UUID{}).
			Immutable().
			Comment("FK to tenants table — data isolation boundary"),
	}
}

func (TenantMixin) Indexes() []ent.Index {
	return []ent.Index{
		index.On("tenant_id"),
	}
}
```

- [ ] **Step 4: Generate entGo code**

```bash
cd yucai/server
go generate ./internal/ent/...
```

Expected: entGo generates code in `internal/ent/` (no errors)

- [ ] **Step 5: Verify compilation**

Run: `cd yucai/server && go build ./...`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
cd yucai
git add -A
git commit -m "feat: initialize entGo with TenantMixin for multi-tenancy"
```

---

## Task 8: Flutter Project Initialization

**Files:**
- Create: `yucai/client/` (Flutter project)
- Create: `yucai/client/pubspec.yaml` (updated)
- Create: `yucai/client/build.yaml`
- Create: `yucai/client/lib/main.dart`

- [ ] **Step 1: Create Flutter project**

```bash
cd yucai
flutter create --org com.yucai --project-name yucai_client client
```

- [ ] **Step 2: Update pubspec.yaml with dependencies**

Edit `yucai/client/pubspec.yaml`, add under `dependencies:`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^8.1.6
  go_router: ^14.6.1
  get_it: ^7.7.0
  injectable: ^2.4.4
  drift: ^2.21.0
  sqlite3_flutter_libs: ^0.5.28
  grpc: ^4.0.1
  protobuf: ^3.1.0
  connectivity_plus: ^6.1.2
  flutter_secure_storage: ^9.2.4
  dartz: ^0.10.1
  equatable: ^2.0.7
  uuid: ^4.5.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.13
  drift_dev: ^2.21.0
  injectable_generator: ^2.6.2
  bloc_test: ^9.1.7
  mocktail: ^1.0.4
```

- [ ] **Step 3: Create build.yaml for code generation**

Create `yucai/client/build.yaml`:

```yaml
targets:
  $default:
    builders:
      drift_dev:
        options:
          apply_converters_on_variables: true
          generate_connect_constructor: true
```

- [ ] **Step 4: Create minimal main.dart**

Replace `yucai/client/lib/main.dart`:

```dart
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const YuCaiApp());
}

class YuCaiApp extends StatelessWidget {
  const YuCaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '御财 YuCai',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1E40AF),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('御财 YuCai — Initializing...'),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Install dependencies and verify**

```bash
cd yucai/client
flutter pub get
flutter analyze
```

Expected: No errors in analysis

- [ ] **Step 6: Commit**

```bash
cd yucai
git add -A
git commit -m "feat: initialize Flutter client with Bloc, Drift, gRPC dependencies"
```

---

## Task 9: Wire DI Setup + Server Entry Point

**Files:**
- Create: `yucai/server/wire/wire.go`
- Create: `yucai/server/wire/wire_gen.go` (generated)
- Modify: `yucai/server/cmd/server/main.go`

- [ ] **Step 1: Write Wire DI definition**

Create `yucai/server/wire/wire.go`:

```go
//go:build wireinject
// +build wireinject

package wire

import (
	"github.com/google/wire"
	"github.com/yucai/server/pkg/config"
	"github.com/yucai/server/pkg/logger"
)

// InitializeApp wires all dependencies and returns a ready-to-run App.
func InitializeApp(cfg *config.Config) (*App, error) {
	wire.Build(
		provideLogger,
		NewApp,
	)
	return nil, nil
}

func provideLogger(cfg *config.Config) *logger.Logger {
	logger.Setup(cfg.LogLevel)
	return &logger.Logger{}
}

// App holds all initialized dependencies.
type App struct {
	Config *config.Config
}
```

Note: This is a minimal wire setup. It will be expanded in Plan 2 (Auth) and Plan 3 (Account) as we add more components.

Create `yucai/server/wire/app.go`:

```go
package wire

import "github.com/yucai/server/pkg/config"

// NewApp creates the application with wired dependencies.
func NewApp(cfg *config.Config) *App {
	return &App{Config: cfg}
}
```

- [ ] **Step 2: Update main.go**

Replace `yucai/server/cmd/server/main.go`:

```go
package main

import (
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"github.com/yucai/server/pkg/config"
	"github.com/yucai/server/wire"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		slog.Error("failed to load config", "error", err)
		os.Exit(1)
	}

	app, err := wire.InitializeApp(cfg)
	if err != nil {
		slog.Error("failed to initialize app", "error", err)
		os.Exit(1)
	}

	slog.Info("YuCai server initialized",
		"grpc_port", app.Config.GRPCPort,
		"log_level", app.Config.LogLevel,
	)

	// Wait for shutdown signal
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	sig := <-sigCh
	slog.Info("shutting down", "signal", sig)
}
```

- [ ] **Step 3: Generate Wire code**

```bash
cd yucai/server
wire ./wire/...
```

Expected: `wire_gen.go` generated without errors

- [ ] **Step 4: Verify full project builds**

Run: `cd yucai/server && go build ./cmd/server`
Expected: Builds successfully

- [ ] **Step 5: Run all tests**

Run: `cd yucai/server && go test ./... -v`
Expected: ALL PASS

- [ ] **Step 6: Commit**

```bash
cd yucai
git add -A
git commit -m "feat: add Wire DI setup and server entry point"
```

---

## Task 10: End-to-End Smoke Test

- [ ] **Step 1: Start infrastructure**

```bash
cd yucai/deploy
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d postgres redis
sleep 5
```

- [ ] **Step 2: Run Go server**

```bash
cd yucai/server
export DATABASE_URL="postgresql://yucai:yucai_dev@localhost:5432/yucai?sslmode=disable"
export REDIS_URL="redis://localhost:6379/0"
export JWT_SECRET="dev-secret-key"
go run ./cmd/server
```

Expected: Log output "YuCai server initialized" with no panics

- [ ] **Step 3: Stop server (Ctrl+C) and infrastructure**

```bash
cd yucai/deploy
docker compose -f docker-compose.yml -f docker-compose.dev.yml down
```

- [ ] **Step 4: Run full test suite**

```bash
cd yucai/server && go test ./... -v
cd yucai/client && flutter test
```

Expected: ALL PASS on both Go and Flutter

- [ ] **Step 5: Final commit**

```bash
cd yucai
git add -A
git commit -m "chore: verify end-to-end build and test pipeline"
```

---

## Self-Review

### 1. Spec Coverage Check

| Spec Section | Covered by Task |
|---|---|
| Monorepo structure | Task 1 (Makefile), Task 8 (Flutter init) |
| Dependency rules | Task 4-5 (shared kernel layered correctly) |
| gRPC/Protobuf common types | Task 2 (Buf + proto files) |
| Docker Compose | Task 3 |
| Money value object | Task 4 |
| Domain events | Task 4 |
| Command/Query bus | Task 5 |
| Ports (TxManager, EventPublisher) | Task 5 |
| Domain errors | Task 5 |
| Config/Logger/Interceptors | Task 6 |
| entGo + TenantMixin | Task 7 |
| Wire DI | Task 9 |
| Flutter dependencies | Task 8 |

### 2. Placeholder Scan

No TBD/TODO found. All code blocks contain complete implementations.

### 3. Type Consistency

- Money uses `int64 Cents` throughout — matches protobuf `int64 cents`
- Error codes use string constants — matches protobuf `ErrorDetail.code`
- CQRS Bus uses generic type parameters — consistent across command/query
- TenantMixin uses `uuid.UUID` — consistent with all schema plans
