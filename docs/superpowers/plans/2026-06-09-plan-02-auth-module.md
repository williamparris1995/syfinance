# Plan 2: Auth Module

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the Auth module — tenant + user management, JWT authentication, gRPC auth service, and Redis session store. This module provides the multi-tenant isolation foundation for all subsequent modules.

**Architecture:** Explicit Architecture with DDD, Hexagonal Ports & Adapters, CQRS. Domain layer has zero external imports. Adapters implement domain-defined interfaces.

**Depends on:** Plan 1 (shared kernel, Wire DI, entGo TenantMixin, gRPC interceptors)

**Design Specs:**
- [Architecture Redesign](../specs/2026-06-09-architecture-redesign-design.md) — Section 2 (Auth)
- [Functional Modules](../specs/2026-06-09-functional-modules-design.md)

---

## File Structure

```
yucai/
├── proto/auth/v1/
│   └── auth.proto                    # AuthService gRPC definition
│
└── server/internal/auth/
    ├── domain/
    │   ├── entity.go                 # Tenant, User entities
    │   ├── repository.go            # TenantRepository, UserRepository interfaces
    │   └── valueobject.go           # TenantType, FamilyRole enums
    │
    ├── application/
    │   ├── command/
    │   │   ├── register.go          # RegisterCommand + handler
    │   │   ├── login.go             # LoginCommand + handler
    │   │   └── refresh.go           # RefreshTokenCommand + handler
    │   ├── query/
    │   │   └── profile.go           # GetProfileQuery, UpdateProfileCommand handlers
    │   ├── service.go               # AuthService orchestrator
    │   └── dto.go                   # Request/Response DTOs
    │
    ├── adapter/driven/
    │   ├── repository/
    │   │   ├── tenant_repo.go       # entGo TenantRepository
    │   │   └── user_repo.go         # entGo UserRepository
    │   └── session/
    │       └── redis_store.go       # Redis refresh token store
    │
    ├── adapter/driving/
    │   └── grpc/
    │       └── auth_handler.go      # gRPC AuthService implementation
    │
    ├── infrastructure/
    │   ├── jwt/
    │   │   └── token.go             # JWT generation/parsing
    │   └── password/
    │       └── hash.go              # bcrypt hash/verify
    │
    └── ent/schema/
        ├── tenant.go                # Tenant entGo schema
        └── user.go                  # User entGo schema + TenantMixin

Modified:
├── server/cmd/server/main.go        # Start gRPC server
├── server/pkg/middleware/auth.go     # Real JWT validation
├── server/wire/wire.go              # Wire auth module
├── server/wire/app.go               # Add AuthService to App
├── server/wire/app.go               # Add DB pool, Redis client to App
└── server/go.mod                    # New deps: bcrypt, crypto
```

---

## Task 1: Protobuf Auth Service Definition

- [ ] **Step 1: Create proto/auth/v1/auth.proto**

```protobuf
syntax = "proto3";
package yucai.auth.v1;
option go_package = "github.com/yucai/server/internal/proto/auth/v1";

import "google/protobuf/empty.proto";

service AuthService {
  rpc Register(RegisterRequest) returns (RegisterResponse);
  rpc Login(LoginRequest) returns (LoginResponse);
  rpc RefreshToken(RefreshTokenRequest) returns (RefreshTokenResponse);
  rpc GetProfile(GetProfileRequest) returns (GetProfileResponse);
  rpc UpdateProfile(UpdateProfileRequest) returns (UpdateProfileResponse);
}

message RegisterRequest {
  string email = 1;
  string password = 2;
  string display_name = 3;
}

message RegisterResponse {
  string access_token = 1;
  string refresh_token = 2;
  UserDTO user = 3;
}

message LoginRequest {
  string email = 1;
  string password = 2;
}

message LoginResponse {
  string access_token = 1;
  string refresh_token = 2;
  UserDTO user = 3;
}

message RefreshTokenRequest {
  string refresh_token = 1;
}

message RefreshTokenResponse {
  string access_token = 1;
  string refresh_token = 2;
}

message GetProfileRequest {}
message GetProfileResponse { UserDTO user = 1; }

message UpdateProfileRequest {
  string display_name = 2;
  string avatar_url = 3;
}
message UpdateProfileResponse { UserDTO user = 1; }

message UserDTO {
  string id = 1;
  string tenant_id = 2;
  string email = 3;
  string display_name = 4;
  string avatar_url = 5;
  string created_at = 6;
}
```

- [ ] **Step 2: Run `buf generate` to produce Go stubs**
- [ ] **Step 3: Verify generated files exist**

---

## Task 2: entGo Schema (Tenant + User)

- [ ] **Step 1: Create `internal/auth/ent/schema/tenant.go`**

Tenant schema: UUID PK, `type` enum (personal/family), `name` string, timestamps.

- [ ] **Step 2: Create `internal/auth/ent/schema/user.go`**

User schema: UUID PK, embed `TenantMixin`, `email` (unique per tenant), `password_hash`, `display_name`, `avatar_url`, `oauth_provider`, `oauth_id`, `family_role`, timestamps. Add index on `(tenant_id, email)`.

- [ ] **Step 3: Generate entGo code** — `cd server && go generate ./internal/ent/...`
- [ ] **Step 4: Verify compilation** — `go build ./...`

---

## Task 3: Domain Layer

- [ ] **Step 1: Create `internal/auth/domain/valueobject.go`**

Define `TenantType` (Personal/Family) and `FamilyRole` (Owner/Member) as typed enums with `String()` and `ParseXxx()` methods. Use `fmt.Stringer` interface, not external enum libraries.

- [ ] **Step 2: Create `internal/auth/domain/entity.go`**

```go
type Tenant struct {
    ID        uuid.UUID
    Type      TenantType
    Name      string
    CreatedAt time.Time
}

type User struct {
    ID           uuid.UUID
    TenantID     uuid.UUID
    Email        string
    PasswordHash string
    DisplayName  string
    AvatarURL    string
    OAuthProvider string
    OAuthID       string
    FamilyRole   FamilyRole
    CreatedAt    time.Time
}
```

Add validation: `NewTenant()` enforces non-empty name, `NewUser()` enforces valid email format, non-empty display_name.

- [ ] **Step 3: Create `internal/auth/domain/repository.go`**

```go
type TenantRepository interface {
    Save(ctx context.Context, tenant *Tenant) error
    FindByID(ctx context.Context, id uuid.UUID) (*Tenant, error)
}

type UserRepository interface {
    Save(ctx context.Context, user *User) error
    FindByID(ctx context.Context, id uuid.UUID) (*User, error)
    FindByEmail(ctx context.Context, tenantID uuid.UUID, email string) (*User, error)
}
```

- [ ] **Step 4: Verify compilation**

---

## Task 4: JWT + Password Utilities

- [ ] **Step 1: Add dependencies** — `go get golang.org/x/crypto/bcrypt`
- [ ] **Step 2: Create `internal/auth/infrastructure/password/hash.go`**

Functions: `HashPassword(password string) (string, error)` and `CheckPassword(password, hash string) bool`. Use bcrypt with default cost.

- [ ] **Step 3: Create `internal/auth/infrastructure/jwt/token.go`**

```go
type TokenService struct {
    secretKey     string
    accessTokenTTL  15 * time.Minute
    refreshTokenTTL 7 * 24 * time.Hour
}

func NewTokenService(secretKey string) *TokenService
func (s *TokenService) GenerateAccessToken(userID, tenantID uuid.UUID) (string, error)
func (s *TokenService) ParseAccessToken(tokenStr string) (userID, tenantID uuid.UUID, error)
func (s *TokenService) GenerateRefreshToken() (string, error)
```

JWT claims: `{ "sub": userID, "tenant_id": tenantID, "exp": ..., "iat": ... }`. Use HS256 signing.

- [ ] **Step 4: Write tests for both packages**

Test password hash/verify roundtrip. Test JWT generate/parse roundtrip. Test expired token rejection.

---

## Task 5: Application Layer (CQRS Handlers)

- [ ] **Step 1: Create `internal/auth/application/dto.go`**

Define DTOs: `RegisterRequest`, `LoginRequest`, `AuthResponse`, `ProfileResponse`, `UpdateProfileRequest`.

- [ ] **Step 2: Create `internal/auth/application/command/register.go`**

`RegisterHandler` implements `command.Handler[RegisterCommand]`.
Flow: validate input → check email not taken → hash password → create Tenant(type=personal) → create User → generate tokens → return AuthResponse.
Use `port.TxManager` for atomicity.

- [ ] **Step 3: Create `internal/auth/application/command/login.go`**

`LoginHandler` implements `command.Handler[LoginCommand]`.
Flow: find user by email → check password → generate tokens → store refresh token in Redis → return AuthResponse.

- [ ] **Step 4: Create `internal/auth/application/command/refresh.go`**

`RefreshHandler` implements `command.Handler[RefreshCommand]`.
Flow: lookup refresh token in Redis → validate → find user → generate new access token → optionally rotate refresh token → return.

- [ ] **Step 5: Create `internal/auth/application/query/profile.go`**

`GetProfileHandler` implements `query.Handler[GetProfileQuery, ProfileResponse]`.
`UpdateProfileHandler` implements `command.Handler[UpdateProfileCommand]`.

- [ ] **Step 6: Create `internal/auth/application/service.go`**

`AuthService` struct that holds command/query buses and provides convenience methods: `Register(ctx, req)`, `Login(ctx, req)`, etc. Each method creates the appropriate command/query and dispatches via the bus.

- [ ] **Step 7: Write tests** — mock repositories, test register/login/refresh flows.

---

## Task 6: Driven Adapters (Repositories + Session)

- [ ] **Step 1: Create `internal/auth/adapter/driven/repository/tenant_repo.go`**

Implement `domain.TenantRepository` using entGo client. Map between domain entity and entGo model.

- [ ] **Step 2: Create `internal/auth/adapter/driven/repository/user_repo.go`**

Implement `domain.UserRepository` using entGo client. All queries include `Where(tenant_id = ?)`.

- [ ] **Step 3: Create `internal/auth/adapter/driven/session/redis_store.go`**

```go
type RedisSessionStore struct {
    client *redis.Client
}

func (s *RedisSessionStore) Store(ctx context.Context, userID string, refreshToken string, ttl time.Duration) error
func (s *RedisSessionStore) Validate(ctx context.Context, userID string, refreshToken string) (bool, error)
func (s *RedisSessionStore) Delete(ctx context.Context, userID string) error
```

Key format: `refresh_token:{userID}`. TTL = 7 days.

- [ ] **Step 4: Write tests** — use miniredis or mock for Redis tests.

---

## Task 7: gRPC Driving Adapter + Server Startup

- [ ] **Step 1: Create `internal/auth/adapter/driving/grpc/auth_handler.go`**

Implement the generated `AuthServiceServer` interface. Each RPC method:
1. Extract tenant_id from JWT context (except Register/Login which skip auth)
2. Map gRPC request to application DTO
3. Call AuthService method
4. Map response back to protobuf

Map domain errors to gRPC codes: NOT_FOUND → NOT_FOUND, VALIDATION_ERROR → INVALID_ARGUMENT, ALREADY_EXISTS → ALREADY_EXISTS.

- [ ] **Step 2: Update `pkg/middleware/auth.go`**

Replace placeholder with real JWT validation using `jwt.TokenService.ParseAccessToken()`. Extract `user_id` and `tenant_id` from claims and inject into context via `context.WithValue()`.

- [ ] **Step 3: Update `wire/app.go`**

Add fields to App: `DB *pgxpool.Pool`, `Redis *redis.Client`, `AuthService *auth.application.Service`, `GRPCServer *grpc.Server`.

- [ ] **Step 4: Update `wire/wire.go`**

Add Wire providers for: pgxpool, redis client, entGo client, all auth repositories, session store, token service, auth service, gRPC server with interceptors, auth handler registration.

- [ ] **Step 5: Update `cmd/server/main.go`**

Start gRPC server: `grpc.NewServer()` with interceptors → register AuthService → `net.Listen()` on GRPC_PORT → `grpcServer.Serve()` in goroutine → graceful shutdown on signal.

- [ ] **Step 6: Verify** — `go build ./cmd/server` and `go test ./...`

---

## Task 8: Integration Tests

- [ ] **Step 1: Create `tests/auth_integration_test.go`**

Tests run against real PostgreSQL + Redis (started via Docker or testcontainers).

```go
func TestRegisterLoginFlow(t *testing.T) {
    // Register -> Login -> GetProfile -> UpdateProfile
}

func TestDuplicateEmail(t *testing.T) {
    // Register same email twice -> ALREADY_EXISTS
}

func TestRefreshToken(t *testing.T) {
    // Login -> RefreshToken -> GetProfile with new token
}

func TestUnauthenticated(t *testing.T) {
    // GetProfile without token -> UNAUTHENTICATED
}
```

- [ ] **Step 2: Run tests** — `go test ./tests/... -v -run TestAuth`
- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: implement Auth module — JWT, tenant isolation, gRPC AuthService"
```

---

## Self-Review

### 1. Spec Coverage

| Spec Section | Covered by Task |
|---|---|
| Tenant entity + auto-creation | Task 3 (domain), Task 5 (register handler) |
| User entity + password | Task 3 (domain), Task 4 (bcrypt) |
| JWT access/refresh tokens | Task 4 (jwt package) |
| Redis session store | Task 6 (Redis adapter) |
| Register/Login/Refresh RPCs | Task 5 (CQRS), Task 7 (gRPC handler) |
| GetProfile/UpdateProfile | Task 5 (query), Task 7 (gRPC handler) |
| Auth interceptor (JWT validation) | Task 7 (middleware update) |
| gRPC server startup | Task 7 (main.go update) |
| Wire DI integration | Task 7 (wire update) |

### 2. Placeholder Scan

No TBD/TODO. All tasks have complete descriptions.

### 3. Type Consistency

- User ID and Tenant ID: `uuid.UUID` throughout
- JWT claims use string representation of UUIDs
- All errors use `shared/errors` package
- CQRS handlers use shared kernel `command.Bus` and `query.Bus`
