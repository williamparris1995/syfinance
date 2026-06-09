# YuCai Architecture Redesign Design Spec

> Date: 2026-06-09
> Status: Approved
> Scope: MVP (Accounts + Double-Entry Transactions)

## 1. Overview

Migrate the YuCai (御财) personal finance application from a Tauri/Rust/SQLite single-user desktop app to a multi-tenant SaaS with C/S (Client/Server) separation:

- **Server**: Go + PostgreSQL + entGo + gRPC
- **Client**: Flutter + Bloc + Drift (SQLite) — Desktop + Mobile
- **Protocol**: gRPC + Protobuf (Buf managed)
- **Deployment**: Docker Compose

Architecture follows **Explicit Architecture** (Herberto Graca) with strict DDD, Hexagonal (Ports & Adapters), and CQRS patterns. All terminology uses industry-standard conventions (e.g., `tenant_id` for multi-tenancy isolation).

## 2. Core Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| User model | Multi-tenant SaaS + User/Family Organization | Supports both personal and shared family finance |
| Tenant model | `tenant_id` on all data tables | Industry-standard multi-tenancy isolation term |
| Deployment | Docker Compose | Simple self-hosted, easy CI/CD |
| Communication | gRPC + Protobuf | Type-safe, high-performance, code generation |
| Offline strategy | Full offline-first with Drift (SQLite) | Maintains current Tauri offline experience |
| Flutter local DB | Drift (SQLite ORM) | Type-safe, complex relational queries for double-entry |
| Auth | JWT + OAuth2 (Google/Apple) hybrid | Best UX, flexible |
| MVP scope | Accounts + Double-Entry Transactions | Core foundation, other modules incremental |
| Go project structure | Domain-driven vertical slicing (by component) | Aligns with Explicit Architecture "Package by Component" |
| DI (Go) | Google Wire | Compile-time injection, no reflection |
| DI (Flutter) | get_it + injectable | Standard Flutter DI stack |
| ORM | entGo (Meta) | Schema-first code generation, type-safe |
| Event bus | Go channel (in-process) | Sufficient for MVP; NATS later if needed |
| Protobuf management | Buf | Better than raw protoc, lint + breaking change detection |
| DB migration | Atlas (entGo companion) | Auto-migration from entGo schemas |
| State management | Bloc (CQRS mapping) | Event → State aligns with Command → Result |

## 3. Monorepo Structure

```
yucai/
├── server/                         # Go server
│   ├── cmd/server/main.go          # Entry point: Wire DI, start gRPC
│   ├── internal/
│   │   ├── shared/                 # Shared Kernel
│   │   │   ├── domain/
│   │   │   │   ├── event/          # DomainEvent interface + base events
│   │   │   │   └── types/          # Money, Currency, PageToken value objects
│   │   │   ├── application/
│   │   │   │   ├── command/        # Command interface + Bus
│   │   │   │   ├── query/          # Query interface + Bus
│   │   │   │   └── port/           # Generic ports (EventPublisher, TxManager)
│   │   │   └── errors/             # Unified error codes
│   │   ├── account/                # Account bounded context
│   │   │   ├── domain/
│   │   │   │   ├── entity.go       # Account aggregate root
│   │   │   │   ├── valueobject.go  # AccountType, Ownership, AccountStatus
│   │   │   │   ├── event.go        # AccountCreated, BalanceUpdated
│   │   │   │   ├── service.go      # Domain service (BalanceCalculator)
│   │   │   │   └── repository.go   # AccountRepository port (interface)
│   │   │   ├── application/
│   │   │   │   ├── command/        # CreateAccountCmd, UpdateAccountCmd
│   │   │   │   ├── query/          # GetAccountQuery, ListAccountsQuery
│   │   │   │   ├── handler/        # CommandHandler, QueryHandler
│   │   │   │   ├── service.go      # AccountAppService (use case orchestration)
│   │   │   │   └── dto.go          # AccountDTO, AccountWithBalanceDTO
│   │   │   ├── adapter/
│   │   │   │   ├── driven/         # Outbound adapters
│   │   │   │   │   ├── repository/ # entGo AccountRepository implementation
│   │   │   │   │   └── eventpub/   # Event publisher implementation
│   │   │   │   └── driving/        # Inbound adapters
│   │   │   │       └── grpc/       # gRPC AccountService handler
│   │   │   └── ent/schema/
│   │   │       ├── account.go
│   │   │       └── chart_of_accounts.go
│   │   ├── transaction/            # Transaction bounded context (isomorphic)
│   │   │   ├── domain/
│   │   │   │   ├── entity.go       # Transaction + TransactionEntry
│   │   │   │   ├── valueobject.go  # TransactionOperation, DebitCredit
│   │   │   │   ├── event.go        # TransactionRecorded, EntryAdded
│   │   │   │   ├── service.go      # DoubleEntryValidator
│   │   │   │   └── repository.go   # TransactionRepository port
│   │   │   ├── application/
│   │   │   │   ├── command/
│   │   │   │   ├── query/
│   │   │   │   ├── handler/
│   │   │   │   ├── service.go
│   │   │   │   └── dto.go
│   │   │   ├── adapter/
│   │   │   │   ├── driven/repository/
│   │   │   │   └── driving/grpc/
│   │   │   └── ent/schema/
│   │   │       ├── transaction.go
│   │   │       └── transaction_entry.go
│   │   ├── auth/                   # Auth bounded context
│   │   │   ├── domain/             # User, Tenant, Family entities
│   │   │   ├── application/        # RegisterCmd, LoginQuery, OAuth2Callback
│   │   │   ├── adapter/
│   │   │   │   ├── driven/         # entGo User/Tenant Repo + Redis Session
│   │   │   │   └── driving/        # gRPC AuthService
│   │   │   └── ent/schema/
│   │   └── sync/                   # Sync bounded context (post-MVP)
│   ├── pkg/                        # Public utilities (no internal dependency)
│   │   ├── logger/                 # Structured logging (slog)
│   │   ├── config/                 # Config loading (envconfig)
│   │   └── middleware/             # gRPC interceptors (auth, logging, recovery)
│   └── wire/                       # Google Wire DI
│       ├── wire.go
│       └── wire_gen.go
│
├── client/                         # Flutter client
│   ├── lib/
│   │   ├── main.dart               # Entry → DI init → runApp
│   │   ├── app/
│   │   │   ├── app.dart            # MaterialApp.router
│   │   │   └── router.dart         # go_router definitions
│   │   ├── core/
│   │   │   ├── theme/              # YuCai Design System
│   │   │   ├── network/
│   │   │   │   ├── grpc_client.dart
│   │   │   │   └── connectivity.dart
│   │   │   └── sync/
│   │   │       ├── sync_engine.dart
│   │   │       ├── offline_queue.dart
│   │   │       └── conflict_resolver.dart
│   │   ├── account/                # Account feature module
│   │   │   ├── domain/
│   │   │   │   ├── account_entity.dart
│   │   │   │   ├── account_value_objects.dart
│   │   │   │   ├── account_repository.dart  # Abstract interface
│   │   │   │   └── create_account_usecase.dart
│   │   │   ├── data/
│   │   │   │   ├── account_repository_impl.dart  # Remote+Local strategy
│   │   │   │   ├── account_remote_ds.dart        # gRPC data source
│   │   │   │   ├── account_local_ds.dart         # Drift data source
│   │   │   │   └── account_mapper.dart           # DTO ↔ Entity
│   │   │   ├── bloc/
│   │   │   │   ├── account_bloc.dart
│   │   │   │   ├── account_event.dart
│   │   │   │   └── account_state.dart
│   │   │   └── presentation/
│   │   │       ├── accounts_page.dart
│   │   │       ├── account_detail_page.dart
│   │   │       ├── account_form_page.dart
│   │   │       └── widgets/
│   │   ├── transaction/            # Transaction feature module (isomorphic)
│   │   ├── auth/                   # Auth feature module
│   │   └── di/
│   │       ├── injection.config.dart
│   │       └── injection.dart
│   ├── test/
│   ├── proto/                      # Symlink → ../proto/
│   ├── pubspec.yaml
│   └── build.yaml
│
├── proto/                          # Shared Protobuf definitions
│   ├── buf.yaml
│   ├── common/v1/
│   │   ├── money.proto
│   │   ├── pagination.proto
│   │   ├── error.proto
│   │   └── sync.proto
│   ├── account/v1/
│   │   └── account.proto
│   ├── transaction/v1/
│   │   └── transaction.proto
│   └── auth/v1/
│       └── auth.proto
│
├── deploy/
│   ├── docker-compose.yml
│   ├── docker-compose.dev.yml
│   ├── .env.example
│   └── postgres/init.sql
│
├── docs/
├── Makefile
└── buf.yaml
```

## 4. Dependency Rules (Strict)

```
Driving Adapter (gRPC) → Application (Command/Query Handler) → Domain (Entity/VO/Service)
                                                                      ↑
Driven Adapter (entGo) → implements Domain port interfaces
```

- **Domain layer**: No external imports (stdlib + shared kernel only)
- **Application layer**: Imports domain + shared only
- **Driven adapters**: Implement domain-defined interfaces
- **Driving adapters**: Call application handlers/services
- **Cross-component**: Auth/Account/Transaction communicate via domain events only, never direct imports

## 5. gRPC/Protobuf Contract

### 5.1 Service Map (MVP)

| Service | RPCs | Pattern |
|---------|------|---------|
| AccountService | Create, Update, Delete, Archive, Get, List, GetBalanceHistory, SyncAccounts (stream) | 8 unary + 1 bidi stream |
| TransactionService | Record, Update, Delete, BatchDelete, Get, List, ListByAccount, ListByDateRange, SimpleIncome, SimpleExpense, SimpleTransfer, SyncTransactions (stream) | 11 unary + 1 bidi stream |
| AuthService | Register, Login, RefreshToken, OAuth2Callback, GetProfile, UpdateProfile | 6 unary |

### 5.2 Common Types

```protobuf
// common/v1/money.proto
message Money {
  int64 cents = 1;              // Integer cents, no floating point
  string currency_code = 2;     // ISO 4217
}

// common/v1/pagination.proto
message PageRequest {
  int32 page_size = 1;
  string page_token = 2;        // Cursor-based pagination
}

// common/v1/error.proto
message ErrorDetail {
  string code = 1;              // ACCOUNT_NOT_FOUND, BALANCE_VIOLATION, etc.
  string message = 2;
  map<string, string> metadata = 3;
}

// common/v1/sync.proto
message SyncPayload {
  string entity_type = 1;       // "account" | "transaction"
  string operation = 2;         // "create" | "update" | "delete"
  bytes payload = 3;            // Serialized entity
  int64 version = 4;
  string device_id = 5;
}
```

### 5.3 Money Precision

All monetary amounts use `int64 cents` throughout the stack (Protobuf → Go → PostgreSQL → Flutter/Drift). No float/double anywhere.

### 5.4 Sync Protocol (Bidirectional Stream)

```
Client connects SyncAccounts bidi stream:
  → Client sends: SyncPayload { operation: "create", payload: <data>, version: 42, device_id }
  ← Server acks:  SyncPayload { operation: "ack", version: 43 }
  ← Server push:  SyncPayload { operation: "update", payload: <from other device> }
  → Client acks:  SyncPayload { operation: "ack", version: 44 }
```

## 6. Data Model (PostgreSQL)

### 6.1 MVP Tables

| Table | Key Columns | Notes |
|-------|-------------|-------|
| `tenants` | id (UUID), type (personal/family), name, created_at | Data isolation boundary |
| `users` | id, tenant_id FK, email UK, password_hash, display_name, avatar_url, oauth_provider, oauth_id, family_role, created_at | Authentication identity |
| `currencies` | id, code UK, name, symbol, exchange_rate, is_active | Global (no tenant_id) |
| `chart_of_accounts` | id, tenant_id FK, code UK, name, level, account_type, parent_code, balance_direction | Per-tenant chart |
| `accounts` | id, tenant_id FK, name, account_type, currency_code FK, initial_balance_cents, ownership, icon, color, chart_code, parent_id FK, institution, credit_limit_cents, status, version, deleted_at, timestamps | Aggregate root |
| `transactions` | id, tenant_id FK, transaction_date, description, version, deleted_at, timestamps | Aggregate root |
| `transaction_entries` | id, transaction_id FK, account_id FK, chart_of_account_code, debit_cents, credit_cents, note | Double-entry entries |

### 6.2 Multi-Tenancy via TenantMixin

```go
// All domain schemas use TenantMixin for automatic tenant_id injection
type TenantMixin struct {
    mixin.Schema
}

func (TenantMixin) Fields() []ent.Field {
    return []ent.Field{
        field.UUID("tenant_id", uuid.UUID{}).Immutable(),
    }
}

func (TenantMixin) Indexes() []ent.Index {
    return []ent.Index{index.On("tenant_id")}
}
```

### 6.3 Double-Entry Balance Constraint

```sql
-- Entry-level: debit OR credit, not both
ALTER TABLE transaction_entries ADD CONSTRAINT chk_debit_credit_xor
  CHECK ((debit_cents > 0 AND credit_cents = 0) OR
         (credit_cents > 0 AND debit_cents = 0));

-- Transaction-level: sum(debits) = sum(credits) — enforced in Go domain service
```

### 6.4 Optimistic Locking

Every mutable entity has `version BIGINT DEFAULT 1`. Updates use `WHERE version = ?` and `SET version = version + 1`. Zero rows affected = conflict.

### 6.5 SQLite → PostgreSQL Migration Mapping

| Concept | Tauri (SQLite) | Go (PostgreSQL) |
|---------|----------------|-----------------|
| Primary key | UUID (TEXT) | UUID (native pgtype) |
| Monetary amounts | INTEGER (cents) | BIGINT (cents) |
| Enums | TEXT + app validation | entGo Enum + CHECK constraint |
| Timestamps | TEXT (ISO 8601) | TIMESTAMPTZ |
| Soft delete | deleted_at TEXT | deleted_at TIMESTAMPTZ + entGo annotation |
| Double-entry balance | SQLite TRIGGER | PostgreSQL CHECK + domain service validation |
| Full-text search | FTS5 virtual table | pg_trgm GIN index |
| Sync metadata | sync_metadata JSON | version BIGINT + device_id VARCHAR |
| Multi-tenancy | Single user (no isolation) | tenant_id FK + RLS policy |
| ORM | sqlx (raw SQL) | entGo (schema-first code generation) |
| Migrations | 51 dated SQL files | Atlas auto-migration |

### 6.6 Flutter Drift Local Tables

Mirror server schema 1:1 with additional sync columns:

| Column | Type | Purpose |
|--------|------|---------|
| `sync_status` | TEXT | `synced` / `pending` / `conflict` |
| `last_synced_at` | DATETIME | Last successful sync time |
| `local_modified_at` | DATETIME | Detect offline changes |

## 7. Flutter Client Architecture

### 7.1 Layers

| Layer | Responsibility | Dependency Direction |
|-------|----------------|---------------------|
| `domain/` | Pure Dart — Entity + VO + Repository interface + UseCase | No external packages |
| `data/` | Repository implementation (gRPC remote + Drift local) | Depends on domain/ |
| `bloc/` | Event → State mapping, calls UseCase | Depends on domain/ |
| `presentation/` | Pages + Widgets, BlocBuilder subscription | Depends on bloc/ |

### 7.2 Offline-First Repository Strategy

```dart
Future<Either<Failure, Account>> create(AccountParams params) async {
  // 1. Always write to local Drift first (offline-safe)
  final local = await _local.create(params);

  // 2. Check connectivity
  if (await _connectivity.isOnline) {
    // Online: send gRPC request, sync server ID/version back
    final remote = await _remote.create(params);
    await _local.syncFromRemote(remote);
    return Right(remote);
  } else {
    // Offline: enqueue for later sync
    await _queue.enqueue('create_account', params.toJson());
    return local;
  }
}
```

### 7.3 Bloc ↔ CQRS Mapping

| CQRS Concept | Bloc Equivalent |
|--------------|-----------------|
| Command | BlocEvent (write: CreateAccountEvent) |
| Query | BlocEvent (read: LoadAccountsEvent) |
| Command Handler | `on<CreateAccountEvent>` → UseCase → Repo write |
| Query Handler | `on<LoadAccountsEvent>` → UseCase → Repo read |
| Read Model | BlocState (AccountsLoadedState with display data) |

### 7.4 Desktop + Mobile Responsive Layout

```dart
LayoutBuilder(builder: (context, constraints) {
  if (constraints.maxWidth > 900) return _DesktopLayout(...);  // Sidebar + content
  if (constraints.maxWidth > 600) return _TabletLayout(...);   // Drawer + content
  return _MobileLayout(...);                                     // Bottom nav + full screen
});
```

### 7.5 Key Flutter Dependencies

```yaml
dependencies:
  flutter_bloc: ^8.x
  go_router: ^14.x
  get_it: ^7.x
  injectable: ^2.x
  drift: ^2.x
  grpc: ^4.x
  protobuf: ^3.x
  connectivity_plus: ^6.x
  flutter_secure_storage: ^9.x
  dartz: ^0.10.x       # Either<Failure, T>

dev_dependencies:
  build_runner: ^2.x
  drift_dev: ^2.x
  injectable_generator: ^2.x
  bloc_test: ^9.x
  mocktail: ^1.x
```

## 8. Auth & Multi-Tenancy

### 8.1 Tenant Model

```
Personal: User registers → auto-create Tenant(type=personal) → user.tenant_id = tenant.id
Family:   User creates family → Tenant(type=family) → invite others → shared tenant_id
```

- `tenant_id` = data isolation boundary (industry standard term)
- `user_id` = authentication identity + audit trail
- All data queries include `WHERE tenant_id = ?`

### 8.2 Token Lifecycle

| Token | Type | TTL | Storage |
|-------|------|-----|---------|
| access_token | JWT | 15 min | Flutter memory (Bloc state) |
| refresh_token | Random string | 7 days | Redis (server) + flutter_secure_storage (client) |

JWT payload: `{ user_id, tenant_id, role, exp }`

### 8.3 Auto-Refresh Flow

Flutter gRPC interceptor catches `UNAUTHENTICATED` (401) → calls `RefreshToken` → retries original request. Transparent to UI layer.

## 9. Docker Compose Deployment

```yaml
services:
  api:
    build: ../server
    ports: ["9090:9090"]
    environment:
      - DATABASE_URL=postgresql://yucai:${DB_PASS}@postgres:5432/yucai
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET=${JWT_SECRET}
    depends_on: [postgres, redis]

  postgres:
    image: postgres:16-alpine
    volumes: [pgdata:/var/lib/postgresql/data]

  redis:
    image: redis:7-alpine
    volumes: [redisdata:/data]

  adminer:
    image: adminer
    ports: ["8080:8080"]
    profiles: ["dev"]
```

## 10. Testing Strategy

### 10.1 Go Server

| Level | Scope | Tool |
|-------|-------|------|
| Unit | Domain Entity/VO/Service | `go test` |
| Integration | Command/Query Handlers | `go test` with SQLite in-memory |
| Component | gRPC → Handler → Repo | Testcontainers (PostgreSQL) |
| E2E | Full stack via gRPC client | Docker Compose + `go test` |

### 10.2 Flutter Client

| Level | Scope | Tool |
|-------|-------|------|
| Unit | Entity/VO/UseCase | `flutter test` |
| Widget | Individual widgets | `flutter test` |
| Bloc | Bloc Event → State | `bloc_test` package |
| Integration | Repo → Drift in-memory | `flutter test` |
| E2E | Full app with real server | `integration_test` |

## 11. Development Lifecycle

```
1. Modify proto/           → buf generate (Go stub + Dart stub)
2. Modify ent/schema/      → go generate (entGo code + Atlas migration)
3. Implement Domain        → go test (unit)
4. Implement Application   → go test (integration)
5. Implement Adapters      → Testcontainers verify
6. Flutter development     → flutter run + flutter test
7. Full integration        → docker compose up → flutter run
```

## 12. Post-MVP Modules (Incremental)

Each module follows the same bounded-context structure as Account/Transaction:

| Module | Domain Aggregates | Priority |
|--------|-------------------|----------|
| Budget | Budget, BudgetItem | P2 |
| Goal | Goal | P2 |
| Debt | DebtDetails, PaymentScheduleEntry | P2 |
| Holding | Holding, HoldingTransaction, Security | P3 |
| Tag | Tag | P3 |
| Reminder | Reminder | P3 |
| TransactionTemplate | TransactionTemplate | P3 |
| Family | Family, Membership, SharedBudget | P4 |
| Report | Computed queries | P4 |
| Sync | SyncEngine, ConflictResolution | P4 |
| Backup | BackupService, CloudProvider | P5 |

## 13. Terminology Standards

All design uses industry-standard terminology:

| Term | Usage |
|------|-------|
| `tenant_id` | Multi-tenancy data isolation boundary (NOT `user_id`) |
| `aggregate root` | DDD entry point entity (Account, Transaction) |
| `port` | Hexagonal architecture interface (driving/driven) |
| `adapter` | Hexagonal architecture implementation |
| `command` | CQRS write operation |
| `query` | CQRS read operation |
| `value object` | Immutable, no identity (Money, Currency) |
| `bounded context` | DDD subdomain boundary (Account, Transaction, Auth) |
| `shared kernel` | Cross-context shared types |
