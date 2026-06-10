# Plan 07: Holding + Backup + Sync Modules

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement three infrastructure and investment modules — Holding (investment portfolio with securities), Backup (cloud backup with WebDAV/OAuth providers), and Sync (bidirectional data synchronization with conflict resolution).

**Architecture:** Explicit Architecture with DDD, Hexagonal Ports & Adapters, CQRS.

**Depends on:** Plan 1–4 (shared kernel, auth, account, transaction) + Plan 5–6 (budget, goal, debt, tag, template)

**Design Specs:**
- [Functional Modules](../specs/2026-06-09-functional-modules-design.md) — Sections 4, 12, 11

---

# Part A: Holding Module (Investment)

## File Structure

```
yucai/
├── proto/holding/v1/
│   └── holding.proto
│
└── server/internal/holding/
    ├── domain/
    │   ├── entity.go                # Security, Holding, HoldingTransaction
    │   ├── valueobject.go           # SecurityType, TradeType enums
    │   ├── service.go               # PortfolioCalculator (avg cost, P&L)
    │   └── repository.go            # HoldingRepository, SecurityRepository
    │
    ├── application/
    │   ├── service.go               # HoldingApplicationService
    │   └── dto.go
    │
    ├── adapter/driven/
    │   ├── repository/
    │   │   ├── holding_repo.go
    │   │   └── security_repo.go
    │   └── marketdata/
    │       └── yahoo_finance.go     # Yahoo Finance price fetcher
    │
    ├── adapter/driving/
    │   └── grpc/
    │       └── holding_handler.go
    │
    └── ent/schema/
        ├── security.go              # Global reference data (no tenant)
        ├── holding.go               # Per-tenant position
        └── holding_transaction.go   # Append-only trade ledger
```

---

## Task A1: Protobuf Holding Service Definition

- [ ] **Step 1: Create `proto/holding/v1/holding.proto`**

```protobuf
syntax = "proto3";
package yucai.holding.v1;
option go_package = "github.com/yucai/server/internal/proto/holding/v1";

import "common/v1/pagination.proto";
import "google/protobuf/empty.proto";
import "google/protobuf/timestamp.proto";

service HoldingService {
  // Security CRUD
  rpc CreateSecurity(CreateSecurityRequest) returns (SecurityResponse);
  rpc ListSecurities(ListSecuritiesRequest) returns (ListSecuritiesResponse);
  rpc UpdateSecurityPrice(UpdatePriceRequest) returns (google.protobuf.Empty);
  rpc SearchSecurities(SearchSecuritiesRequest) returns (SearchSecuritiesResponse);

  // Holding operations
  rpc BuyHolding(HoldingTradeRequest) returns (HoldingTransactionResponse);
  rpc SellHolding(HoldingTradeRequest) returns (HoldingTransactionResponse);
  rpc RecordDividend(RecordDividendRequest) returns (HoldingTransactionResponse);
  rpc RecordSplit(RecordSplitRequest) returns (HoldingTransactionResponse);

  // Queries
  rpc ListHoldings(ListHoldingsRequest) returns (ListHoldingsResponse);
  rpc ListHoldingTransactions(ListTradesRequest) returns (ListTradesResponse);
}

enum SecurityType {
  SECURITY_TYPE_UNSPECIFIED = 0;
  SECURITY_TYPE_STOCK = 1;
  SECURITY_TYPE_FUND = 2;
  SECURITY_TYPE_ETF = 3;
  SECURITY_TYPE_BOND = 4;
  SECURITY_TYPE_GOLD = 5;
  SECURITY_TYPE_OPTION = 6;
  SECURITY_TYPE_OTHER = 7;
}

enum TradeType {
  TRADE_TYPE_UNSPECIFIED = 0;
  TRADE_TYPE_BUY = 1;
  TRADE_TYPE_SELL = 2;
  TRADE_TYPE_DIVIDEND = 3;
  TRADE_TYPE_SPLIT = 4;
}

message SecurityDTO {
  string id = 1;
  string symbol = 2;
  string name = 3;
  SecurityType security_type = 4;
  string exchange = 5;
  string currency_code = 6;
  int64 current_price_cents = 7;
  google.protobuf.Timestamp created_at = 8;
}

message HoldingDTO {
  string id = 1;
  string account_id = 2;
  string security_id = 3;
  string security_name = 4;
  string security_symbol = 5;
  double quantity = 6;
  int64 avg_cost_cents = 7;
  int64 market_value_cents = 8;
  int64 unrealized_pnl_cents = 9;
  int64 version = 10;
}

message HoldingTransactionDTO {
  string id = 1;
  string account_id = 2;
  string security_id = 3;
  TradeType trade_type = 4;
  double quantity = 5;
  int64 price_cents = 6;
  int64 amount_cents = 7;
  int64 fee_cents = 8;
  string trade_date = 9;
  string notes = 10;
  google.protobuf.Timestamp created_at = 11;
}

message CreateSecurityRequest {
  string symbol = 1;
  string name = 2;
  SecurityType security_type = 3;
  string exchange = 4;
  string currency_code = 5;
}

message ListSecuritiesRequest {
  yucai.common.v1.PageRequest page = 1;
  SecurityType security_type = 2;
}

message UpdatePriceRequest {
  string security_id = 1;
  int64 price_cents = 2;
}

message SearchSecuritiesRequest {
  string query = 1;
  int32 limit = 2;
}

message HoldingTradeRequest {
  string account_id = 1;
  string security_id = 2;
  double quantity = 3;
  int64 price_cents = 4;
  int64 fee_cents = 5;
  string trade_date = 6;
  string notes = 7;
}

message RecordDividendRequest {
  string account_id = 1;
  string security_id = 2;
  double quantity = 3;
  int64 cash_per_share_cents = 4;
  int64 total_amount_cents = 5;
  string trade_date = 6;
  string notes = 7;
}

message RecordSplitRequest {
  string account_id = 1;
  string security_id = 2;
  double ratio = 3;                 // e.g. 2.0 for 2:1 split
  string split_date = 4;
  string notes = 5;
}

message ListHoldingsRequest {
  string account_id = 1;            // optional filter
  yucai.common.v1.PageRequest page = 2;
}

message ListTradesRequest {
  string account_id = 1;
  string security_id = 2;
  yucai.common.v1.PageRequest page = 3;
}

message SecurityResponse { SecurityDTO security = 1; }
message ListSecuritiesResponse { repeated SecurityDTO securities = 1; yucai.common.v1.PageResponse page = 2; }
message SearchSecuritiesResponse { repeated SecurityDTO securities = 1; }
message HoldingTransactionResponse { HoldingTransactionDTO transaction = 1; }
message ListHoldingsResponse { repeated HoldingDTO holdings = 1; yucai.common.v1.PageResponse page = 2; }
message ListTradesResponse { repeated HoldingTransactionDTO trades = 1; yucai.common.v1.PageResponse page = 2; }
```

- [ ] **Step 2: Run `buf generate`**
- [ ] **Step 3: Verify**

---

## Task A2: entGo Schema (Security + Holding + HoldingTransaction)

- [ ] **Step 1: Create `internal/holding/ent/schema/security.go`** — Global (no TenantMixin). Fields: UUID PK, `symbol`, `name`, `security_type` (string enum), `exchange` (optional), `currency_code`, `current_price_cents` (optional int64), timestamps. UNIQUE `(symbol, exchange)`.
- [ ] **Step 2: Create `internal/holding/ent/schema/holding.go`** — TenantMixin. Fields: UUID PK, `account_id` (UUID), `security_id` (UUID), `quantity` (float64), `avg_cost_cents` (int64), `version` (int64), timestamps. UNIQUE `(tenant_id, account_id, security_id)`.
- [ ] **Step 3: Create `internal/holding/ent/schema/holding_transaction.go`** — TenantMixin. Fields: UUID PK, `account_id`, `security_id`, `trade_type` (string enum), `quantity` (float64), `price_cents`, `amount_cents`, `fee_cents`, `trade_date`, `transaction_id` (optional UUID), `notes` (optional), timestamps. Append-only (no update/delete).
- [ ] **Step 4: Generate + verify**

---

## Task A3: Domain Layer

- [ ] **Step 1: Create `internal/holding/domain/valueobject.go`** — `SecurityType`, `TradeType` enums.
- [ ] **Step 2: Create `internal/holding/domain/entity.go`** — Security (global ref), Holding (position), HoldingTransaction (trade record). Holding methods: `ApplyBuy()`, `ApplySell()`, `ApplyDividend()`, `ApplySplit()`, `MarketValue()`, `UnrealizedPnL()`.
- [ ] **Step 3: Create `internal/holding/domain/service.go`** — `PortfolioCalculator` with weighted average cost computation.
- [ ] **Step 4: Create `internal/holding/domain/repository.go`**

```go
type SecurityRepository interface {
    Save(ctx context.Context, security *Security) error
    FindByID(ctx context.Context, id uuid.UUID) (*Security, error)
    FindAll(ctx context.Context, securityType *SecurityType, page PageRequest) (*PaginatedResult[Security], error)
    FindBySymbol(ctx context.Context, symbol, exchange string) (*Security, error)
    Search(ctx context.Context, query string, limit int) ([]Security, error)
    UpdatePrice(ctx context.Context, id uuid.UUID, priceCents int64) error
}

type HoldingRepository interface {
    SaveOrUpdate(ctx context.Context, holding *Holding) error
    FindByAccountAndSecurity(ctx context.Context, tenantID, accountID, securityID uuid.UUID) (*Holding, error)
    FindAll(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, page PageRequest) (*PaginatedResult[Holding], error)
}

type TradeRepository interface {
    Save(ctx context.Context, trade *HoldingTransaction) error
    FindAll(ctx context.Context, tenantID uuid.UUID, accountID, securityID *uuid.UUID, page PageRequest) (*PaginatedResult[HoldingTransaction], error)
}
```

- [ ] **Step 5: Write domain tests** — avg cost calculation, buy/sell/dividend/split operations.

---

## Task A4: Application Layer

- [ ] **Step 1: Create dto.go** — DTOs for all operations + mappers.
- [ ] **Step 2: Create service.go** — `CreateSecurity()`, `BuyHolding()` (creates trade + updates holding position + creates accounting transaction), `SellHolding()` (realized P&L), `RecordDividend()`, `RecordSplit()`, `ListHoldings()` (with market value), `FetchPrice()` (delegates to market data adapter).
- [ ] **Step 3: Write tests**

---

## Task A5: Driven Adapters

- [ ] **Step 1: Create `security_repo.go`** — entGo implementation. Global (no tenant filter).
- [ ] **Step 2: Create `holding_repo.go`** — entGo implementation. `SaveOrUpdate` uses upsert pattern.
- [ ] **Step 3: Create `internal/holding/adapter/driven/marketdata/yahoo_finance.go`** — Implements `MarketDataProvider` port. Fetches prices from Yahoo Finance API. Uses exchange suffix mapping (SHA→.SS, SHE→.SZ, HKG→.HK).
- [ ] **Step 4: Write tests**

---

## Task A6: gRPC + Wire + Tests

- [ ] **Step 1: Create `holding_handler.go`** — gRPC HoldingServiceServer.
- [ ] **Step 2: Wire integration** — update wire files + main.go.
- [ ] **Step 3: Create `tests/holding_integration_test.go`**

```go
func TestSecurityCRUD(t *testing.T)                // Create → List → Search
func TestBuyHolding(t *testing.T)                   // Buy → verify holding position + avg cost
func TestSellHolding(t *testing.T)                   // Buy → Sell → verify realized P&L
func TestDividend(t *testing.T)                      // Buy → Dividend → verify cash entry
func TestSplit(t *testing.T)                         // Buy → Split → verify quantity doubled, avg cost halved
func TestPortfolioValue(t *testing.T)                 // Multiple holdings → ListHoldings with market value
func TestHoldingTenantIsolation(t *testing.T)
```

- [ ] **Step 4: Run tests**
- [ ] **Step 5: Commit** — `feat: implement Holding module`

---

# Part B: Backup Module

## File Structure

```
yucai/
├── proto/backup/v1/
│   └── backup.proto
│
└── server/internal/backup/
    ├── domain/
    │   ├── entity.go                # Backup entity
    │   ├── valueobject.go           # BackupProvider enum
    │   └── repository.go            # BackupRepository, CloudSettingsRepository
    │
    ├── application/
    │   ├── service.go               # BackupApplicationService
    │   └── dto.go
    │
    ├── adapter/driven/
    │   ├── repository/
    │   │   └── backup_repo.go
    │   └── cloud/
    │       ├── provider.go          # CloudProvider port interface
    │       ├── local.go             # Local filesystem
    │       ├── webdav.go            # WebDAV
    │       └── oauth.go             # OAuth2 PKCE helper
    │
    ├── adapter/driving/
    │   └── grpc/
    │       └── backup_handler.go
    │
    └── ent/schema/
        └── backup.go
```

---

## Task B1: Protobuf Backup Service Definition

- [ ] **Step 1: Create `proto/backup/v1/backup.proto`**

```protobuf
syntax = "proto3";
package yucai.backup.v1;
option go_package = "github.com/yucai/server/internal/proto/backup/v1";

import "common/v1/pagination.proto";
import "google/protobuf/empty.proto";
import "google/protobuf/timestamp.proto";

service BackupService {
  rpc CreateBackup(CreateBackupRequest) returns (BackupResponse);
  rpc RestoreBackup(RestoreBackupRequest) returns (google.protobuf.Empty);
  rpc ListBackups(ListBackupsRequest) returns (ListBackupsResponse);
  rpc DeleteBackup(DeleteBackupRequest) returns (google.protobuf.Empty);
  rpc SaveCloudSettings(SaveCloudSettingsRequest) returns (google.protobuf.Empty);
  rpc GetCloudSettings(google.protobuf.Empty) returns (CloudSettingsResponse);
  rpc TestCloudConnection(TestConnectionRequest) returns (TestConnectionResponse);
  rpc UploadToCloud(UploadRequest) returns (BackupResponse);
}

enum BackupProvider {
  BACKUP_PROVIDER_UNSPECIFIED = 0;
  BACKUP_PROVIDER_LOCAL = 1;
  BACKUP_PROVIDER_WEBDAV = 2;
  BACKUP_PROVIDER_DROPBOX = 3;
  BACKUP_PROVIDER_GOOGLE_DRIVE = 4;
  BACKUP_PROVIDER_ONE_DRIVE = 5;
  BACKUP_PROVIDER_S3 = 6;
}

message BackupDTO {
  string id = 1;
  BackupProvider provider = 2;
  string filename = 3;
  int64 size_bytes = 4;
  string checksum = 5;
  bool encrypted = 6;
  bool auto = 7;
  google.protobuf.Timestamp created_at = 8;
}

message CreateBackupRequest {
  bool encrypted = 1;
}

message RestoreBackupRequest {
  string backup_id = 1;
  string password = 2;               // required if encrypted
}

message ListBackupsRequest {
  yucai.common.v1.PageRequest page = 1;
  BackupProvider provider = 2;        // optional filter
}

message ListBackupsResponse {
  repeated BackupDTO backups = 1;
  yucai.common.v1.PageResponse page = 2;
}

message DeleteBackupRequest { string id = 1; }

message CloudSettingsDTO {
  BackupProvider provider = 1;
  string webdav_url = 2;
  string webdav_username = 3;
  string oauth_token = 4;
  bool auto_backup = 5;
  int32 auto_backup_interval_hours = 6;
}

message SaveCloudSettingsRequest { CloudSettingsDTO settings = 1; }
message CloudSettingsResponse { CloudSettingsDTO settings = 1; }
message TestConnectionRequest { BackupProvider provider = 1; }
message TestConnectionResponse { bool success = 1; string message = 2; }
message UploadRequest { string backup_id = 1; BackupProvider provider = 2; }
message BackupResponse { BackupDTO backup = 1; }
```

- [ ] **Step 2: Run `buf generate`**
- [ ] **Step 3: Verify**

---

## Task B2–B6: Full Module Implementation

(Same pattern as previous modules)

- [ ] **Task B2: entGo Schema** — `backup.go` (TenantMixin, provider, filename, size_bytes, checksum, encrypted, auto, timestamps) + `backup_settings.go` (tenant cloud settings, 1:1 per tenant).
- [ ] **Task B3: Domain Layer** — Backup entity, BackupProvider enum, BackupRepository interface. CloudProvider port (interface for driven adapters).
- [ ] **Task B4: Application Layer** — service.go: `CreateBackup()` (serialize all tenant data to JSON, optional AES-256-GCM encryption, compute SHA-256), `RestoreBackup()`, `UploadToCloud()` (delegate to CloudProvider port).
- [ ] **Task B5: Driven Adapters** — backup_repo.go, cloud/local.go (filesystem), cloud/webdav.go (HTTP client), cloud/oauth.go (PKCE helper for Dropbox/GoogleDrive/OneDrive — stub for OAuth flow).
- [ ] **Task B6: gRPC + Wire + Tests**

```go
func TestLocalBackupCreate(t *testing.T)     // Create → List → verify exists
func TestBackupRestore(t *testing.T)          // Create → Restore → verify data integrity
func TestBackupChecksum(t *testing.T)          // Create → verify SHA-256 checksum
func TestBackupDelete(t *testing.T)            // Create → Delete → List empty
func TestCloudSettings(t *testing.T)           // Save → Get → verify roundtrip
func TestWebDAVConnection(t *testing.T)        // Test connection (mock)
```

- [ ] **Commit** — `feat: implement Backup module`

---

# Part C: Sync Module

## File Structure

```
yucai/
├── proto/sync/v1/
│   └── sync.proto
│
└── server/internal/sync/
    ├── domain/
    │   ├── entity.go                # SyncLog, SyncDevice, SyncConflict
    │   ├── valueobject.go           # SyncOperation, ConflictType enums
    │   └── repository.go            # SyncLogRepository, SyncDeviceRepository
    │
    ├── application/
    │   ├── service.go               # SyncService (push/pull orchestration)
    │   ├── conflict.go              # ConflictResolver strategies
    │   └── dto.go
    │
    ├── adapter/driven/
    │   └── repository/
    │       └── sync_repo.go
    │
    ├── adapter/driving/
    │   └── grpc/
    │       └── sync_handler.go      # Bidirectional streaming
    │
    └── ent/schema/
        ├── sync_log.go
        ├── sync_device.go
        └── sync_conflict.go
```

---

## Task C1: Protobuf Sync Service Definition

- [ ] **Step 1: Create `proto/sync/v1/sync.proto`**

```protobuf
syntax = "proto3";
package yucai.sync.v1;
option go_package = "github.com/yucai/server/internal/proto/sync/v1";

import "common/v1/error.proto";
import "google/protobuf/empty.proto";
import "google/protobuf/timestamp.proto";

service SyncService {
  // Unary: device registration + status
  rpc RegisterDevice(RegisterDeviceRequest) returns (RegisterDeviceResponse);
  rpc GetSyncStatus(GetSyncStatusRequest) returns (SyncStatusResponse);

  // Unary: push/pull per entity batch
  rpc PushChanges(stream SyncPayload) returns (PushResponse);
  rpc PullChanges(PullChangesRequest) returns (stream SyncPayload);

  // Unary: conflict resolution
  rpc ResolveConflict(ResolveConflictRequest) returns (google.protobuf.Empty);
  rpc ListConflicts(ListConflictsRequest) returns (ListConflictsResponse);
}

enum SyncOperation {
  SYNC_OPERATION_UNSPECIFIED = 0;
  SYNC_OPERATION_CREATE = 1;
  SYNC_OPERATION_UPDATE = 2;
  SYNC_OPERATION_DELETE = 3;
}

message SyncPayload {
  string entity_type = 1;            // "account" | "transaction" | "budget" | etc.
  SyncOperation operation = 2;
  bytes payload = 3;                 // Serialized entity JSON
  int64 version = 4;
  string device_id = 5;
  string entity_id = 6;
}

message RegisterDeviceRequest {
  string device_name = 1;
}

message RegisterDeviceResponse {
  string device_id = 1;
  int64 last_sync_version = 2;
}

message GetSyncStatusRequest {}

message SyncStatusResponse {
  string device_id = 1;
  int64 last_sync_version = 2;
  google.protobuf.Timestamp last_sync_at = 3;
  int32 pending_conflicts = 4;
}

message PushResponse {
  int64 synced_version = 1;
  repeated ConflictDTO conflicts = 2;
}

message PullChangesRequest {
  int64 since_version = 1;
  repeated string entity_types = 2;  // empty = all
}

message ConflictDTO {
  string id = 1;
  string entity_type = 2;
  string entity_id = 3;
  bytes server_payload = 4;
  bytes client_payload = 5;
  string resolution = 6;             // "pending" | "server" | "client"
}

message ResolveConflictRequest {
  string conflict_id = 1;
  string resolution = 2;             // "server" | "client"
  bytes merged_payload = 3;          // optional manual merge
}

message ListConflictsRequest {}
message ListConflictsResponse { repeated ConflictDTO conflicts = 1; }
```

- [ ] **Step 2: Run `buf generate`**
- [ ] **Step 3: Verify**

---

## Task C2: entGo Schema (SyncLog + SyncDevice + SyncConflict)

- [ ] **Step 1: Create `internal/sync/ent/schema/sync_log.go`** — TenantMixin. Fields: UUID PK, `entity_type`, `entity_id` (UUID), `operation` (string enum), `payload` (bytes), `version` (int64 auto-increment), `device_id` (UUID), timestamps. Append-only. Index: `(tenant_id, version)`, `(tenant_id, entity_type, entity_id)`.
- [ ] **Step 2: Create `internal/sync/ent/schema/sync_device.go`** — TenantMixin. Fields: UUID PK, `device_name`, `last_sync_version` (int64), `last_sync_at` (time), timestamps.
- [ ] **Step 3: Create `internal/sync/ent/schema/sync_conflict.go`** — TenantMixin. Fields: UUID PK, `entity_type`, `entity_id` (UUID), `conflict_type` (string), `server_payload` (bytes), `client_payload` (bytes), `resolution` (string, default "pending"), `resolved_at` (optional), timestamps.
- [ ] **Step 4: Generate + verify**

---

## Task C3: Domain Layer

- [ ] **Step 1: Create `internal/sync/domain/valueobject.go`** — `SyncOperation` (Create, Update, Delete), `ConflictResolution` (ServerWins, ClientWins, Merge).
- [ ] **Step 2: Create `internal/sync/domain/entity.go`** — SyncLog, SyncDevice, SyncConflict entities.
- [ ] **Step 3: Create `internal/sync/domain/repository.go`**

```go
type SyncLogRepository interface {
    Append(ctx context.Context, entry *SyncLog) error
    FindSince(ctx context.Context, tenantID uuid.UUID, sinceVersion int64, entityTypes []string) ([]SyncLog, error)
    LatestVersion(ctx context.Context, tenantID uuid.UUID) (int64, error)
}

type SyncDeviceRepository interface {
    Register(ctx context.Context, tenantID uuid.UUID, deviceName string) (*SyncDevice, error)
    FindByID(ctx context.Context, tenantID, deviceID uuid.UUID) (*SyncDevice, error)
    UpdateSyncVersion(ctx context.Context, tenantID, deviceID uuid.UUID, version int64) error
}

type SyncConflictRepository interface {
    Save(ctx context.Context, conflict *SyncConflict) error
    FindPending(ctx context.Context, tenantID uuid.UUID) ([]SyncConflict, error)
    Resolve(ctx context.Context, tenantID, conflictID uuid.UUID, resolution string, mergedPayload []byte) error
}
```

- [ ] **Step 4: Write domain tests**

---

## Task C4: Application Layer

- [ ] **Step 1: Create dto.go** — DTOs for all sync operations.
- [ ] **Step 2: Create `internal/sync/application/conflict.go`** — `ConflictResolver` with strategies:
  - Update-Update: Server wins (higher version)
  - Delete-Update: Delete wins (tombstone)
  - Create-Create: Server assigns final ID

- [ ] **Step 3: Create service.go** — `PushChanges()` (process incoming changes, detect conflicts, append to sync log), `PullChanges()` (stream changes since version), `RegisterDevice()`, `ResolveConflict()`.

`PushChanges` flow per payload:
1. Parse entity type and ID
2. If entity exists → check version conflict
3. If conflict → create SyncConflict entry, return to client
4. If no conflict → apply change, append SyncLog

- [ ] **Step 4: Write tests** — conflict detection, push/pull, device registration.

---

## Task C5: Driven Adapter + gRPC + Wire

- [ ] **Step 1: Create sync_repo.go** — entGo implementation for all 3 repositories.
- [ ] **Step 2: Create `internal/sync/adapter/driving/grpc/sync_handler.go`** — Implements SyncServiceServer. `PushChanges` receives stream, `PullChanges` returns stream.
- [ ] **Step 3: Wire integration** — update wire files + main.go.
- [ ] **Step 4: Verify** — `go build ./cmd/server`

---

## Task C6: Integration Tests

- [ ] **Step 1: Create `tests/sync_integration_test.go`**

```go
func TestSyncDeviceRegistration(t *testing.T)      // Register → GetStatus
func TestSyncPushPull(t *testing.T)                 // Push changes → Pull → verify data
func TestSyncConflictDetection(t *testing.T)        // Push conflicting update → ListConflicts
func TestSyncConflictResolution(t *testing.T)       // Create conflict → Resolve → Pull
func TestSyncVersionProgression(t *testing.T)       // Push multiple → versions increment
func TestSyncTenantIsolation(t *testing.T)          // Tenant A sync invisible to B
```

- [ ] **Step 2: Run tests**
- [ ] **Step 3: Commit** — `feat: implement Sync module`

---

## Self-Review

| Spec Section | Covered by Task |
|---|---|
| Security entity (global ref) | A3 (domain) |
| Holding position (per account+security) | A3 (domain) |
| Buy/Sell/Dividend/Split operations | A3 (domain methods) |
| Weighted average cost | A3 (service) |
| Yahoo Finance price fetcher | A5 (market data adapter) |
| Backup create/restore | B4 (service) |
| AES-256-GCM encryption | B4 (service) |
| WebDAV cloud provider | B5 (adapter) |
| OAuth2 PKCE | B5 (adapter stub) |
| Sync push/pull protocol | C4 (service) |
| Append-only sync log | C2 (schema), C3 (domain) |
| Conflict detection + resolution | C4 (conflict.go) |
| Device registration | C3 (repository), C4 (service) |
| All gRPC services | A6, B6, C5 |
| Wire DI integration | A6, B6, C5 |
