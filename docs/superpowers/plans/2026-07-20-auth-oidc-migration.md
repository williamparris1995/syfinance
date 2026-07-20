# 御财 Auth OIDC 迁移 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把御财 auth 身份层从自建 email/password 迁移到 OIDC(首发 Google,架构支持多 provider),client loopback PKCE 发起 + server 交换 code + 复用现有御财 JWT/refresh 基础设施。

**Architecture:** client(Flutter desktop)用 `oidc_authenticator`(loopback HTTP + PKCE + url_launcher)拿 authorization code → gRPC `OIDCExchange` → server(go-oidc + oauth2)用 code 换 id_token、验证、按 `(provider, subject)` 查 `UserIdentity`(未命中则 jit provisioning 建 user+tenant+identity)→ `issueSession` 发御财 access+refresh。删除 Register/Login/password_hash/bcrypt,身份移到 `UserIdentity` 一对多表。

**Tech Stack:** Go(coreos/go-oidc v3 + golang.org/x/oauth2 + ent)、Flutter(Dart `HttpServer` + `crypto` + `url_launcher`)、proto3、redis(session)、Postgres。

**Spec:** [docs/superpowers/specs/2026-07-20-auth-oidc-migration-design.md](../specs/2026-07-20-auth-oidc-migration-design.md)

## Global Constraints

(逐字来自 spec + CLAUDE.md,每个 task 隐含遵守)

- **wire 工具链坏**:`wire_gen.go` **手改**(镜像 `wire/providers.go` 声明顺序,消费方在依赖方之后),**不跑** wire CLI(见 memory `yucai-wire-handmaintained`)
- **proto regen**:改 proto 后 Go + Dart stub 都要 regen;Dart **protoc_plugin 25.0.0**(21.x 生成 protobuf 4.x 旧 API → analyze 暴增)。Go:`cd yucai/server && buf generate --template buf.gen.go.yaml`;Dart:`cd yucai && make gen-dart`
- **ent generate**(工具链正常,非 wire):`cd yucai/server && go generate ./internal/auth/ent/...`(每个模块 `ent/generate.go` 含 `//go:generate go run -mod=mod entgo.io/ent/cmd/ent generate ./schema`)
- **English 结构化日志**:slog `slog.Error("op", "key", val)`,**无 CJK 在 log 串**
- **中文 UI 直写**(client):非 i18next `t()`
- **interface 加方法**:grep 全 implementer(**含 test fake**);implementer 跑**全量 suite** 非 scoped(`go test ./...` / `flutter test`),否则跨包 fake 漏改致 build fail
- **DDD 边界**:domain → application → infrastructure/adapter;跨模块走 port(不跨层 import)。OIDC 模块自洽不跨模块
- **测试基线**:client 预存 fail 3 测/2 文件(account_detail_page_test / receivable_detail_page_test,test drift,与本迁移无关)—— 不破坏
- **ent auth client 独立**:`provideAuthEntClient` 是单独的 `*authent.Client`;`UserIdentity` 与 `User` 共享此 client
- **不自动 commit**:每 task 末尾 commit 步骤需人工/主控确认;不跑 `git push`

---

## File Structure

### Server 新增/修改(`yucai/server/`)

| 文件 | 操作 | 职责 |
|---|---|---|
| `internal/auth/ent/schema/user_identity.go` | 新建 | UserIdentity ent schema |
| `internal/auth/ent/schema/user.go` | 改 | 删 password_hash/oauth_provider/oauth_id,email Optional,改 index |
| `internal/auth/ent/` (generated) | regen | ent generate |
| `internal/auth/domain/entity.go` | 改 | User entity 删 PasswordHash/OAuth*,NewUser 去 passwordHash 参数;新增 UserIdentity entity + NewUserIdentity |
| `internal/auth/domain/repository.go` | 改 | UserRepository 加 FindByProviderSubject;删 FindByEmail/FindByEmailGlobal;新 IdentityRepository interface |
| `internal/auth/adapter/driven/repository/user_repo.go` | 改 | Save/Update 去 password/oauth;删 FindByEmail/Global;加 FindByProviderSubject;toDomainUser 去 password/oauth |
| `internal/auth/adapter/driven/repository/identity_repo.go` | 新建 | IdentityRepository ent 实现 |
| `internal/auth/infrastructure/oidc/provider.go` | 新建 | ProviderConfig + Provider(go-oidc + oauth2) |
| `internal/auth/infrastructure/oidc/registry.go` | 新建 | ProviderRegistry(从 yaml+env 加载,discovery) |
| `internal/auth/infrastructure/oidc/verifier.go` | 新建 | id_token 验证 + claims 提取 |
| `internal/auth/application/command/oidc_exchange.go` | 新建 | OIDCExchangeHandler(换 token→验证→查/jit→返 user) |
| `internal/auth/application/command/register.go` | 删 | — |
| `internal/auth/application/command/login.go` | 删 | — |
| `internal/auth/application/command/refresh.go` | 改 | PresetSeeder port 移到这里(从 register.go 迁移) |
| `internal/auth/application/service.go` | 改 | 删 Register/Login;加 OIDCExchange/GetOIDCConfig;NewService 签名改 |
| `internal/auth/application/mapper.go` | 改 | UserToDTOWithCurrency 去 password 依赖(若用) |
| `internal/auth/adapter/driving/grpc/auth_handler.go` | 改 | 删 Register/Login handler;加 OIDCExchange/GetOIDCConfig handler |
| `internal/auth/infrastructure/password/hash.go` | 删 | bcrypt 移除 |
| `config/oidc_providers.yaml` | 新建 | Google provider 非敏感配置 |
| `pkg/config/config.go` | 改 | 加 OIDCProvidersPath + per-provider secret env 读取 |
| `wire/providers.go` | 改 | 删 provideRegisterHandler/LoginHandler;加 provideIdentityRepo/OIDCRegistry/OIDCExchangeHandler;改 provideAuthService |
| `wire/wire_gen.go` | 手改 | 镜像 providers.go |

### Client 新增/修改(`yucai/client/`)

| 文件 | 操作 | 职责 |
|---|---|---|
| `lib/proto/auth/v1/auth.pb.dart` 等 | regen | make gen-dart |
| `lib/auth/data/oidc_authenticator.dart` | 新建 | loopback + PKCE + url_launcher,产 authorization code |
| `lib/auth/data/auth_remote_ds.dart` | 改 | 删 register/login;加 oidcExchange/getOIDCConfig |
| `lib/auth/data/auth_repository_impl.dart` | 改 | 删 register/login;加 oidcLogin/getOIDCConfig |
| `lib/auth/domain/repositories/auth_repository.dart` | 改 | 删 register/login;加 oidcLogin/getOIDCConfig |
| `lib/auth/domain/entities/oidc_provider.dart` | 新建 | OIDCProviderConfig 值对象 |
| `lib/auth/domain/usecases/login_usecase.dart` | 删 | — |
| `lib/auth/domain/usecases/register_usecase.dart` | 删 | — |
| `lib/auth/domain/usecases/oidc_login_usecase.dart` | 新建 | OIDCLoginUseCase |
| `lib/auth/presentation/bloc/auth_bloc.dart` | 改 | 删 Login/Register;加 OIDCLoginRequested |
| `lib/auth/presentation/bloc/auth_event.dart` | 改 | 删 Login/Register events;加 OIDCLoginRequested |
| `lib/auth/presentation/pages/login_page.dart` | 改 | 表单 → provider 按钮 |
| `lib/auth/presentation/pages/register_page.dart` | 删 | — |
| `lib/router.dart`(或 app_router) | 改 | 删 /register 路由 |
| `pubspec.yaml` | 改 | 加 url_launcher |

---

## Task 1: UserIdentity ent schema + generate

**Files:**
- Create: `yucai/server/internal/auth/ent/schema/user_identity.go`

**Interfaces:**
- Produces: ent `UserIdentity` 实体(供 Task 3 domain entity + repo 用)

- [ ] **Step 1: 写 schema**

```go
// yucai/server/internal/auth/ent/schema/user_identity.go
package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/edge"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"
	"github.com/yucai/server/internal/ent/schema/mixin"
)

// UserIdentity binds an external OIDC identity (provider+subject) to a User.
// One User may have multiple identities (one per provider) — enables future
// account-link. Login lookup is by (provider, subject) global unique.
type UserIdentity struct {
	ent.Schema
}

func (UserIdentity) Annotations() []entschema.Annotation {
	return []entschema.Annotation{entsql.WithComments(true)}
}

func (UserIdentity) Mixin() []ent.Mixin {
	return []ent.Mixin{mixin.TenantMixin{}}
}

func (UserIdentity) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).Default(uuid.New).Comment("Primary key"),
		field.UUID("user_id", uuid.UUID{}).Comment("Owning user"),
		field.String("provider").NotEmpty().Comment("OIDC provider name (google, github, ...)"),
		field.String("subject").NotEmpty().Comment("IDP sub claim, unique per provider"),
		field.String("issuer").Optional().Default("").Comment("IDP issuer URL"),
		field.String("email_at_provider").Optional().Default("").Comment("Email returned by this IDP"),
		field.Time("created_at").Default(time.Now).Immutable(),
		field.Time("updated_at").Default(time.Now).UpdateDefault(time.Now),
	}
}

func (UserIdentity) Edges() []ent.Edge {
	return []ent.Edge{
		edge.From("user", User.Type).
			Ref("identities").
			Field("user_id").
			Unique().
			Required(),
	}
}

func (UserIdentity) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("provider", "subject").Unique().Comment("OIDC identity lookup key"),
		index.Fields("user_id", "provider").Unique().Comment("one identity per provider per user"),
	}
}
```

> 注:`User` 需加反向 edge `Ref("identities")` —— 在 Task 2 改 user.go 时加 `edge.To("identities", UserIdentity.Type)`。Task 1 先建 schema 文件,Task 2 一起 generate(否则 edge 引用未定义)。

- [ ] **Step 2: 暂不 generate**(等 Task 2 user.go 改完一起 generate,避免 edge 未定义编译错)

- [ ] **Step 3: Commit**

```bash
git add yucai/server/internal/auth/ent/schema/user_identity.go
git commit -m "feat(auth): add UserIdentity ent schema for OIDC identities"
```

---

## Task 2: User ent schema + domain entity 改造

**Files:**
- Modify: `yucai/server/internal/auth/ent/schema/user.go`(加 identities edge + 删 password/oauth + email Optional + 改 index)
- Modify: `yucai/server/internal/auth/domain/entity.go`(User struct 删字段 + NewUser 去 passwordHash)

**Interfaces:**
- Consumes: Task 1 `UserIdentity` schema
- Produces: `User` ent(无 password/oauth,有 identities edge);`domain.User`(无 PasswordHash/OAuth*);`domain.NewUser(tenantID, email, displayName)` 新签名(供 Task 6 jit provisioning 用)

- [ ] **Step 1: 改 user.go schema**

把 [user.go](../../../yucai/server/internal/auth/ent/schema/user.go) 改为(删 `password_hash`/`oauth_provider`/`oauth_id` 字段;`email` 改 Optional + 删 `NotEmpty()`;删 `(tenant_id,email)` index;加 `identities` edge):

```go
// Fields() 改为:
func (User) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).Default(uuid.New).Comment("Primary key"),
		field.String("email").Optional().Default("").Comment("Profile email (from first OIDC identity, verified only)"),
		field.String("display_name").NotEmpty().Comment("User-visible display name"),
		field.String("avatar_url").Optional().Default("").Comment("URL to user avatar image"),
		field.Enum("family_role").Values("owner", "admin", "member").Default("owner").Comment("Role within family tenant"),
		field.Time("created_at").Default(time.Now).Immutable(),
		field.Time("updated_at").Default(time.Now).UpdateDefault(time.Now),
	}
}

// Edges() 改为:
func (User) Edges() []ent.Edge {
	return []ent.Edge{
		edge.To("identities", UserIdentity.Type).StorageKey(edge.Column("user_id")),
	}
}

// Indexes() 改为(删 tenant_id+email unique):
func (User) Indexes() []ent.Index {
	return nil
}
```

> 删除 import 中不再使用的项(`index` 若不再用)。`entschema`/`entsql`/`mixin`/`uuid`/`time` 保留。

- [ ] **Step 2: 改 domain/entity.go**

```go
// User struct 删除 PasswordHash / OAuthProvider / OAuthID 字段:
type User struct {
	ID          uuid.UUID
	TenantID    uuid.UUID
	Email       string
	DisplayName string
	AvatarURL   string
	FamilyRole  FamilyRole
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// NewUser 新签名(去 passwordHash,去 email 必填校验——OIDC email 可能空):
func NewUser(tenantID uuid.UUID, email, displayName string) (*User, error) {
	email = strings.TrimSpace(strings.ToLower(email))
	// email optional: 仅非空时校验格式
	if email != "" {
		if _, err := mail.ParseAddress(email); err != nil {
			return nil, fmt.Errorf("invalid email format: %w", err)
		}
	}
	displayName = strings.TrimSpace(displayName)
	if displayName == "" {
		return nil, fmt.Errorf("display_name must not be empty")
	}
	return &User{
		ID:          uuid.New(),
		TenantID:    tenantID,
		Email:       email,
		DisplayName: displayName,
		FamilyRole:  FamilyRoleOwner,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}, nil
}

// 新增 UserIdentity domain entity:
type UserIdentity struct {
	ID              uuid.UUID
	TenantID        uuid.UUID
	UserID          uuid.UUID
	Provider        string
	Subject         string
	Issuer          string
	EmailAtProvider string
	CreatedAt       time.Time
	UpdatedAt       time.Time
}

func NewUserIdentity(tenantID, userID uuid.UUID, provider, subject, issuer, emailAtProvider string) (*UserIdentity, error) {
	provider = strings.TrimSpace(provider)
	subject = strings.TrimSpace(subject)
	if provider == "" || subject == "" {
		return nil, fmt.Errorf("provider and subject must not be empty")
	}
	return &UserIdentity{
		ID:              uuid.New(),
		TenantID:        tenantID,
		UserID:          userID,
		Provider:        provider,
		Subject:         subject,
		Issuer:          strings.TrimSpace(issuer),
		EmailAtProvider: strings.TrimSpace(emailAtProvider),
		CreatedAt:       time.Now(),
		UpdatedAt:       time.Now(),
	}, nil
}
```

- [ ] **Step 3: ent generate**

```bash
cd yucai/server && go generate ./internal/auth/ent/...
```
Expected: 生成 `internal/auth/ent/useridentity/`、`internal/auth/ent/identity.go` 等;`user.go` generated 更新(去 password/oauth 字段)。无报错。

- [ ] **Step 4: 验证 build(预期失败 —— user_repo.go 仍引用 PasswordHash/OAuth*)**

```bash
cd yucai/server && go build ./...
```
Expected: FAIL(`user_repo.go` 引用 `u.PasswordHash`/`SetPasswordHash`/`SetOauthProvider` 等已删字段)—— Task 3/5 修复。记录失败点。

- [ ] **Step 5: Commit**(schema + domain entity 改造,接受 build 暂坏;后续 task 修)

```bash
git add yucai/server/internal/auth/ent/ yucai/server/internal/auth/domain/entity.go yucai/server/internal/auth/ent/schema/user.go
git commit -m "refactor(auth): drop password/oauth fields from User, add UserIdentity entity"
```

---

## Task 3: domain repository + ent repos 改造

**Files:**
- Modify: `yucai/server/internal/auth/domain/repository.go`
- Modify: `yucai/server/internal/auth/adapter/driven/repository/user_repo.go`
- Create: `yucai/server/internal/auth/adapter/driven/repository/identity_repo.go`

**Interfaces:**
- Produces: `domain.IdentityRepository`(Save / FindByProviderSubject);`domain.UserRepository.FindByProviderSubject(provider, subject)`;ent impl

- [ ] **Step 1: 改 domain/repository.go**

```go
// UserRepository 改为(删 FindByEmail/FindByEmailGlobal,加 FindByProviderSubject):
type UserRepository interface {
	Save(ctx context.Context, user *User) error
	FindByID(ctx context.Context, id uuid.UUID) (*User, error)
	FindByProviderSubject(ctx context.Context, provider, subject string) (*User, error)
	Update(ctx context.Context, user *User) error
}

// 新增 IdentityRepository:
type IdentityRepository interface {
	Save(ctx context.Context, identity *UserIdentity) error
	FindByProviderSubject(ctx context.Context, provider, subject string) (*UserIdentity, error)
}
```

- [ ] **Step 2: 改 user_repo.go ent 实现**

参照 [user_repo.go](../../../yucai/server/internal/auth/adapter/driven/repository/user_repo.go) 范式。`Save` 删 `SetPasswordHash`/`SetOauthProvider`/`SetOauthID`;`Update` 不变(已只改 display/avatar);删 `FindByEmail`/`FindByEmailGlobal`;加 `FindByProviderSubject`(join identities);`toDomainUser` 删 PasswordHash/OAuth 映射:

```go
// Save 改为(去 password/oauth set):
func (r *UserRepository) Save(ctx context.Context, u *domain.User) error {
	_, err := r.client.User.Create().
		SetID(u.ID).
		SetTenantID(u.TenantID).
		SetEmail(u.Email).
		SetDisplayName(u.DisplayName).
		SetAvatarURL(u.AvatarURL).
		SetFamilyRole(user.FamilyRole(u.FamilyRole.String())).
		SetCreatedAt(u.CreatedAt).
		SetUpdatedAt(u.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("save user: %w", err)
	}
	return nil
}

// FindByProviderSubject(替代 FindByEmailGlobal):
func (r *UserRepository) FindByProviderSubject(ctx context.Context, provider, subject string) (*domain.User, error) {
	u, err := r.client.User.Query().
		Where(user.HasIdentitiesWith(
			useridentity.Provider(provider),
			useridentity.Subject(subject),
		)).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find user by provider subject: %w", err)
	}
	return toDomainUser(u), nil
}

// toDomainUser 改为(去 password/oauth):
func toDomainUser(u *ent.User) *domain.User {
	return &domain.User{
		ID:          u.ID,
		TenantID:    u.TenantID,
		Email:       u.Email,
		DisplayName: u.DisplayName,
		AvatarURL:   u.AvatarURL,
		FamilyRole:  domain.ParseFamilyRole(string(u.FamilyRole)),
		CreatedAt:   u.CreatedAt,
		UpdatedAt:   u.UpdatedAt,
	}
}
```

> import 加 `"github.com/yucai/server/internal/auth/ent/useridentity"`;删不再用的(若 `user` 仍用于 FamilyRole 保留)。

- [ ] **Step 3: 写 identity_repo.go**

```go
// yucai/server/internal/auth/adapter/driven/repository/identity_repo.go
package repository

import (
	"context"
	"fmt"

	"github.com/yucai/server/internal/auth/domain"
	"github.com/yucai/server/internal/auth/ent"
	"github.com/yucai/server/internal/auth/ent/useridentity"
)

type IdentityRepository struct {
	client *ent.Client
}

func NewIdentityRepository(client *ent.Client) *IdentityRepository {
	return &IdentityRepository{client: client}
}

func (r *IdentityRepository) Save(ctx context.Context, id *domain.UserIdentity) error {
	_, err := r.client.UserIdentity.Create().
		SetID(id.ID).
		SetTenantID(id.TenantID).
		SetUserID(id.UserID).
		SetProvider(id.Provider).
		SetSubject(id.Subject).
		SetIssuer(id.Issuer).
		SetEmailAtProvider(id.EmailAtProvider).
		SetCreatedAt(id.CreatedAt).
		SetUpdatedAt(id.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("save identity: %w", err)
	}
	return nil
}

func (r *IdentityRepository) FindByProviderSubject(ctx context.Context, provider, subject string) (*domain.UserIdentity, error) {
	i, err := r.client.UserIdentity.Query().
		Where(
			useridentity.Provider(provider),
			useridentity.Subject(subject),
		).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find identity: %w", err)
	}
	return toDomainIdentity(i), nil
}

func toDomainIdentity(i *ent.UserIdentity) *domain.UserIdentity {
	return &domain.UserIdentity{
		ID:              i.ID,
		TenantID:        i.TenantID,
		UserID:          i.UserID,
		Provider:        i.Provider,
		Subject:         i.Subject,
		Issuer:          i.Issuer,
		EmailAtProvider: i.EmailAtProvider,
		CreatedAt:       i.CreatedAt,
		UpdatedAt:       i.UpdatedAt,
	}
}

var _ domain.IdentityRepository = (*IdentityRepository)(nil)
```

- [ ] **Step 4: 写 identity_repo 集成测**

参照现有 auth repo 测试范式(enttest SQLite)。Test 文件:`yucai/server/internal/auth/adapter/driven/repository/identity_repo_test.go`:

```go
package repository_test

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/auth/adapter/driven/repository"
	"github.com/yucai/server/internal/auth/domain"
	"github.com/yucai/server/internal/auth/ent/enttest"
	_ "modernc.org/sqlite"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestIdentityRepository_SaveAndFind(t *testing.T) {
	client := enttest.Open(t, "sqlite3", "file:ent?mode=memory&cache=shared&_fk=1")
	defer client.Close()

	tenantID := uuid.New()
	userID := uuid.New()
	// 先建 user(identity FK 要求)——照 user_repo Save 范式建 domain.User
	// (此处假设有 helper 建 user;实际照 user_repo_test 范式)

	repo := repository.NewIdentityRepository(client)
	id, err := domain.NewUserIdentity(tenantID, userID, "google", "sub-123", "https://accounts.google.com", "u@example.com")
	require.NoError(t, err)

	require.NoError(t, repo.Save(context.Background(), id))

	got, err := repo.FindByProviderSubject(context.Background(), "google", "sub-123")
	require.NoError(t, err)
	assert.Equal(t, userID, got.UserID)
	assert.Equal(t, "google", got.Provider)
}
```

> 实现者:参照同目录现有 `user_repo_test.go`(若有)或 budget/debt repo_test 的 enttest 设置 + user 前置创建范式,补全 user 前置。

- [ ] **Step 5: 跑测试**

```bash
cd yucai/server && go test ./internal/auth/adapter/driven/repository/... -count=1 -run TestIdentityRepository
```
Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add yucai/server/internal/auth/domain/repository.go yucai/server/internal/auth/adapter/driven/repository/
git commit -m "feat(auth): IdentityRepository + UserRepository.FindByProviderSubject"
```

---

## Task 4: OIDC infrastructure(provider/registry/verifier)

**Files:**
- Create: `yucai/server/internal/auth/infrastructure/oidc/provider.go`
- Create: `yucai/server/internal/auth/infrastructure/oidc/registry.go`
- Create: `yucai/server/internal/auth/infrastructure/oidc/verifier.go`
- Modify: `yucai/server/go.mod`(加 go-oidc + oauth2)
- Create: `yucai/server/config/oidc_providers.yaml`

**Interfaces:**
- Produces: `oidc.ProviderConfig`、`oidc.Provider`(封装 go-oidc Provider + oauth2.Config + Endpoint)、`oidc.ProviderRegistry`(Get(name) / ListConfigs())、`oidc.VerifyResult{Provider, Subject, Email, EmailVerified, Issuer}`

- [ ] **Step 1: 加 Go 依赖**

```bash
cd yucai/server && go get github.com/coreos/go-oidc/v3/oidc golang.org/x/oauth2
```
Expected: go.mod 加两行 require + go.sum 更新。

- [ ] **Step 2: 写 provider.go**

```go
// yucai/server/internal/auth/infrastructure/oidc/provider.go
package oidc

import (
	"context"
	"fmt"

	"github.com/coreos/go-oidc/v3/oidc"
	"golang.org/x/oauth2"
)

// ProviderConfig is the non-sensitive provider description (safe to return via
// GetOIDCConfig). Secret is loaded separately from env and never serialized.
// AuthorizationEndpoint is filled by OIDC discovery at Load time (not from yaml).
type ProviderConfig struct {
	Name                   string   // "google"
	DisplayName            string   // "使用 Google 登录"
	Issuer                 string   // "https://accounts.google.com"
	AuthorizationEndpoint  string   // filled by discovery (provider.Endpoint().AuthURL)
	ClientID               string
	ClientSecret           string // env-injected, not in yaml
	Scopes                 []string
	RedirectURI            string // base, e.g. "http://localhost:PORT/callback" (client binds actual port)
}

// Provider wraps go-oidc discovery + oauth2 config for one IDP.
type Provider struct {
	Config       ProviderConfig
	oauth2Config *oauth2.Config
	verifier     *oidc.IDTokenVerifier
}

// NewProvider runs OIDC discovery against cfg.Issuer and builds the oauth2
// config + id_token verifier.
func NewProvider(ctx context.Context, cfg ProviderConfig) (*Provider, error) {
	p, err := oidc.NewProvider(ctx, cfg.Issuer)
	if err != nil {
		return nil, fmt.Errorf("oidc discovery for %s: %w", cfg.Issuer, err)
	}
	return &Provider{
		Config: cfg,
		oauth2Config: &oauth2.Config{
			ClientID:     cfg.ClientID,
			ClientSecret: cfg.ClientSecret,
			Endpoint:     p.Endpoint(),
			RedirectURL:  cfg.RedirectURI,
			Scopes:       cfg.Scopes,
		},
		verifier: p.Verifier(&oidc.Config{ClientID: cfg.ClientID}),
	}, nil
}

// Exchange swaps an authorization code (+ PKCE verifier) for tokens.
func (p *Provider) Exchange(ctx context.Context, code, codeVerifier, redirectURI string) (*oauth2.Token, error) {
	// redirectURI must match the auth request; oauth2 uses Config.RedirectURL by
	// default, but loopback port is dynamic so override per-call.
	opts := []oauth2.AuthCodeOption{oauth2.SetAuthURLParam("code_verifier", codeVerifier)}
	if redirectURI != "" {
		opts = append(opts, oauth2.SetAuthURLParam("redirect_uri", redirectURI))
	}
	tok, err := p.oauth2Config.Exchange(ctx, code, opts...)
	if err != nil {
		return nil, fmt.Errorf("exchange code: %w", err)
	}
	return tok, nil
}

// AuthorizationEndpoint is exposed for GetOIDCConfig (client builds the auth URL).
func (p *Provider) AuthorizationEndpoint() string {
	return p.oauth2Config.Endpoint.AuthURL
}
```

- [ ] **Step 3: 写 verifier.go**

```go
// yucai/server/internal/auth/infrastructure/oidc/verifier.go
package oidc

import (
	"context"
	"fmt"

	"github.com/coreos/go-oidc/v3/oidc"
)

type VerifyResult struct {
	Provider      string
	Subject       string
	Email         string
	EmailVerified bool
	Issuer        string
}

type idClaims struct {
	Email         string `json:"email"`
	EmailVerified bool   `json:"email_verified"`
}

// VerifyIDToken validates the id_token (extracted from the oauth2 token exchange
// response) and returns identity claims. Signature/iss/aud/exp are checked by
// the go-oidc verifier built in NewProvider.
func (p *Provider) VerifyIDToken(ctx context.Context, rawIDToken string) (*VerifyResult, error) {
	idToken, err := p.verifier.Verify(ctx, rawIDToken)
	if err != nil {
		return nil, fmt.Errorf("verify id_token: %w", err)
	}
	var c idClaims
	if err := idToken.Claims(&c); err != nil {
		return nil, fmt.Errorf("parse id_token claims: %w", err)
	}
	return &VerifyResult{
		Provider:      p.Config.Name,
		Subject:       idToken.Subject,
		Email:         c.Email,
		EmailVerified: c.EmailVerified,
		Issuer:        idToken.Issuer,
	}, nil
}
```

> `Exchange`(Step 2)返回的 `*oauth2.Token` 含 id_token;调用方取 `rawIDToken, _ := tok.Extra("id_token").(string)` 后传入 `VerifyIDToken`。

- [ ] **Step 4: 写 registry.go**

```go
// yucai/server/internal/auth/infrastructure/oidc/registry.go
package oidc

import (
	"context"
	"fmt"
	"os"
	"strings"

	"gopkg.in/yaml.v3"
)

// yamlProvider is the on-disk shape of oidc_providers.yaml (no secret).
type yamlProvider struct {
	Name        string   `yaml:"name"`
	DisplayName string   `yaml:"display_name"`
	Issuer      string   `yaml:"issuer"`
	ClientID    string   `yaml:"client_id"`
	Scopes      []string `yaml:"scopes"`
	RedirectURI string   `yaml:"redirect_uri"`
}

type yamlConfig struct {
	Providers []yamlProvider `yaml:"providers"`
}

// ProviderRegistry holds discovered providers keyed by name.
type ProviderRegistry struct {
	providers map[string]*Provider
	configs   []ProviderConfig
}

// Load reads yaml + injects per-provider secret from env
// (OIDC_<NAME_UPPER>_CLIENT_SECRET), then runs discovery for each.
func Load(ctx context.Context, yamlPath string) (*ProviderRegistry, error) {
	data, err := os.ReadFile(yamlPath)
	if err != nil {
		return nil, fmt.Errorf("read oidc providers yaml: %w", err)
	}
	var yc yamlConfig
	if err := yaml.Unmarshal(data, &yc); err != nil {
		return nil, fmt.Errorf("parse oidc providers yaml: %w", err)
	}

	reg := &ProviderRegistry{providers: map[string]*Provider{}}
	for _, yp := range yc.Providers {
		secret := os.Getenv("OIDC_" + strings.ToUpper(yp.Name) + "_CLIENT_SECRET")
		cfg := ProviderConfig{
			Name: yp.Name, DisplayName: yp.DisplayName, Issuer: yp.Issuer,
			ClientID: yp.ClientID, ClientSecret: secret,
			Scopes: yp.Scopes, RedirectURI: yp.RedirectURI,
		}
		p, err := NewProvider(ctx, cfg)
		if err != nil {
			return nil, fmt.Errorf("init provider %s: %w", yp.Name, err)
		}
		cfg.AuthorizationEndpoint = p.AuthorizationEndpoint()
		reg.providers[yp.Name] = p
		reg.configs = append(reg.configs, cfg)
	}
	return reg, nil
}

func (r *ProviderRegistry) Get(name string) (*Provider, bool) {
	p, ok := r.providers[name]
	return p, ok
}

// ListConfigs returns non-sensitive configs for GetOIDCConfig (strips secret).
func (r *ProviderRegistry) ListConfigs() []ProviderConfig {
	out := make([]ProviderConfig, 0, len(r.configs))
	for _, c := range r.configs {
		c.ClientSecret = ""
		out = append(out, c)
	}
	return out
}
```

- [ ] **Step 5: 写 config/oidc_providers.yaml**

```yaml
# yucai/server/config/oidc_providers.yaml
# Non-sensitive OIDC provider configs. Client secret loaded from env
# OIDC_GOOGLE_CLIENT_SECRET (never commit here).
providers:
  - name: google
    display_name: "使用 Google 登录"
    issuer: "https://accounts.google.com"
    client_id: "REPLACE_WITH_GOOGLE_CLIENT_ID"
    scopes: ["openid", "email", "profile"]
    redirect_uri: "http://localhost:8080/callback"
```

- [ ] **Step 6: 写 verifier 单测(test RSA 签 id_token + httptest IDP discovery)**

测试用 `httptest` server 模拟 `.well-known/openid-configuration` + JWKS,用 test RSA key 签 id_token,验证 `VerifyIDToken`。参照 [coreos/go-oidc v3 文档示例](https://github.com/coreos/go-oidc)的 IDP test helper。

Test 文件:`yucai/server/internal/auth/infrastructure/oidc/verifier_test.go`。核心:用 `httptest.NewServer` 返回 jwks_uri + discovery doc,`rsa.GenerateKey` 签 id_token jwt,断言 `VerifyResult.Subject/Email`。

- [ ] **Step 7: 跑测试 + build**

```bash
cd yucai/server && go test ./internal/auth/infrastructure/oidc/... -count=1
cd yucai/server && go build ./internal/auth/infrastructure/oidc/...
```
Expected: 测试 PASS;build 通过。

- [ ] **Step 8: Commit**

```bash
git add yucai/server/internal/auth/infrastructure/oidc/ yucai/server/config/oidc_providers.yaml yucai/server/go.mod yucai/server/go.sum
git commit -m "feat(auth): OIDC provider registry + id_token verifier (go-oidc)"
```

---

## Task 5: proto 改 + Go stub regen

**Files:**
- Modify: `yucai/proto/auth/v1/auth.proto`
- regen: `yucai/server/internal/proto/auth/v1/`(Go stub)

**Interfaces:**
- Produces: proto `GetOIDCConfig` / `OIDCExchange` RPC + messages;删 `Register`/`Login`

- [ ] **Step 1: 改 auth.proto**

把 [auth.proto](../../../yucai/proto/auth/v1/auth.proto) service 改为:

```proto
service AuthService {
  rpc GetOIDCConfig(GetOIDCConfigRequest) returns (GetOIDCConfigResponse);
  rpc OIDCExchange(OIDCExchangeRequest) returns (OIDCExchangeResponse);
  rpc RefreshToken(RefreshTokenRequest) returns (RefreshTokenResponse);
  rpc GetProfile(GetProfileRequest) returns (GetProfileResponse);
  rpc UpdateProfile(UpdateProfileRequest) returns (UpdateProfileResponse);
  rpc GetPreferences(GetPreferencesRequest) returns (GetPreferencesResponse);
  rpc UpdatePreferences(UpdatePreferencesRequest) returns (UpdatePreferencesResponse);
}
```

删 `RegisterRequest`/`RegisterResponse`/`LoginRequest`/`LoginResponse` messages。新增(放 service 后):

```proto
message GetOIDCConfigRequest {}

message OIDCProviderConfig {
  string name = 1;
  string display_name = 2;
  string issuer = 3;
  string authorization_endpoint = 4;
  string client_id = 5;
  repeated string scopes = 6;
}

message GetOIDCConfigResponse {
  repeated OIDCProviderConfig providers = 1;
}

message OIDCExchangeRequest {
  string provider = 1;
  string code = 2;
  string code_verifier = 3;
  string redirect_uri = 4;
}

message OIDCExchangeResponse {
  string access_token = 1;
  string refresh_token = 2;
  UserDTO user = 3;
}
```

- [ ] **Step 2: regen Go stub**

```bash
cd yucai/server && buf generate --template buf.gen.go.yaml
```
Expected: `internal/proto/auth/v1/auth.pb.go` + `auth_grpc.pb.go` 更新(新 RPC + 删 Register/Login)。无报错。

- [ ] **Step 3: 验证 build(预期失败 —— auth_handler.go/service.go 仍实现 Register/Login interface)**

```bash
cd yucai/server && go build ./...
```
Expected: FAIL —— `AuthServiceServer` interface 删了 Register/Login,但 `AuthHandler` 还实现它们(且未实现 GetOIDCConfig/OIDCExchange)。Task 6 修复。

- [ ] **Step 4: Commit**

```bash
git add yucai/proto/auth/v1/auth.proto yucai/server/internal/proto/auth/v1/
git commit -m "feat(auth): proto — drop Register/Login, add GetOIDCConfig/OIDCExchange"
```

---

## Task 6: OIDCExchange command/handler + service + grpc handler

**Files:**
- Create: `yucai/server/internal/auth/application/command/oidc_exchange.go`
- Modify: `yucai/server/internal/auth/application/command/refresh.go`(迁入 PresetSeeder port)
- Modify: `yucai/server/internal/auth/application/service.go`
- Modify: `yucai/server/internal/auth/adapter/driving/grpc/auth_handler.go`
- Delete: `yucai/server/internal/auth/application/command/register.go`、`login.go`

**Interfaces:**
- Consumes: Task 3 repos、Task 4 oidc registry/verifier、Task 2 domain.NewUser/NewUserIdentity/NewTenant
- Produces: `authcmd.OIDCExchangeHandler.Exchange(ctx, provider, code, verifier, redirectURI) (*domain.User, error)`;`authapp.Service.OIDCExchange` / `GetOIDCConfig`

- [ ] **Step 1: 迁 PresetSeeder port 到 refresh.go**(register.go 要删)

把 [register.go:14-25](../../../yucai/server/internal/auth/application/command/register.go) 的 `PresetSeeder` interface + `noopPresetSeeder` 移到 `refresh.go`(或新建 `ports.go`)。

```go
// 加到 refresh.go(或新 ports.go):
type PresetSeeder interface {
	SeedTenantPresets(ctx context.Context, tenantID uuid.UUID) error
}
type noopPresetSeeder struct{}
func (noopPresetSeeder) SeedTenantPresets(_ context.Context, _ uuid.UUID) error { return nil }
```
需 import `github.com/google/uuid`。

- [ ] **Step 2: 删 register.go + login.go**

```bash
git rm yucai/server/internal/auth/application/command/register.go
git rm yucai/server/internal/auth/application/command/login.go
```
同时删 `register.go` 里的 `RegisterCommand`、`login.go` 里的 `LoginCommand` type 定义(若在独立 `commands.go` 则改之;若在各自文件则随文件删)。检查 `command/` 下是否有 `commands.go` 定义 Register/LoginCommand。

- [ ] **Step 3: 写 oidc_exchange.go**

```go
// yucai/server/internal/auth/application/command/oidc_exchange.go
package command

import (
	"context"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/auth/domain"
	"github.com/yucai/server/internal/auth/infrastructure/oidc"
)

// OIDCExchangeHandler swaps an auth code for an id_token, verifies it, and
// resolves/creates the user via identity lookup (jit provisioning).
type OIDCExchangeHandler struct {
	registry    *oidc.ProviderRegistry
	userRepo    domain.UserRepository
	identityRepo domain.IdentityRepository
	tenantRepo  domain.TenantRepository
	seeder      PresetSeeder
}

func NewOIDCExchangeHandler(
	registry *oidc.ProviderRegistry,
	userRepo domain.UserRepository,
	identityRepo domain.IdentityRepository,
	tenantRepo domain.TenantRepository,
	seeder PresetSeeder,
) *OIDCExchangeHandler {
	if seeder == nil {
		seeder = noopPresetSeeder{}
	}
	return &OIDCExchangeHandler{registry: registry, userRepo: userRepo, identityRepo: identityRepo, tenantRepo: tenantRepo, seeder: seeder}
}

// Exchange returns the user for a verified OIDC identity, creating
// user+tenant+identity on first login (jit provisioning).
func (h *OIDCExchangeHandler) Exchange(ctx context.Context, providerName, code, codeVerifier, redirectURI string) (*domain.User, error) {
	provider, ok := h.registry.Get(providerName)
	if !ok {
		return nil, fmt.Errorf("unknown provider: %s", providerName)
	}

	tok, err := provider.Exchange(ctx, code, codeVerifier, redirectURI)
	if err != nil {
		return nil, fmt.Errorf("oidc exchange: %w", err)
	}
	rawIDToken, _ := tok.Extra("id_token").(string)
	if rawIDToken == "" {
		return nil, fmt.Errorf("oidc exchange: no id_token in response")
	}
	verified, err := provider.VerifyIDToken(ctx, rawIDToken)
	if err != nil {
		return nil, fmt.Errorf("oidc verify: %w", err)
	}

	// Existing identity?
	if existing, _ := h.identityRepo.FindByProviderSubject(ctx, verified.Provider, verified.Subject); existing != nil {
		return h.userRepo.FindByID(ctx, existing.UserID)
	}

	// jit provisioning
	displayName := deriveDisplayName(verified)
	tenant, err := domain.NewTenant(displayName+"'s Finances", domain.TenantTypePersonal)
	if err != nil {
		return nil, fmt.Errorf("create tenant: %w", err)
	}
	if err := h.tenantRepo.Save(ctx, tenant); err != nil {
		return nil, fmt.Errorf("save tenant: %w", err)
	}
	if err := h.seeder.SeedTenantPresets(ctx, tenant.ID); err != nil {
		return nil, fmt.Errorf("seed tenant presets: %w", err)
	}

	email := ""
	if verified.EmailVerified {
		email = strings.TrimSpace(strings.ToLower(verified.Email))
	}
	user, err := domain.NewUser(tenant.ID, email, displayName)
	if err != nil {
		return nil, fmt.Errorf("create user: %w", err)
	}
	if err := h.userRepo.Save(ctx, user); err != nil {
		return nil, fmt.Errorf("save user: %w", err)
	}

	identity, err := domain.NewUserIdentity(tenant.ID, user.ID, verified.Provider, verified.Subject, verified.Issuer, verified.Email)
	if err != nil {
		return nil, fmt.Errorf("create identity: %w", err)
	}
	if err := h.identityRepo.Save(ctx, identity); err != nil {
		return nil, fmt.Errorf("save identity: %w", err)
	}
	return user, nil
}

// deriveDisplayName picks a display name from id_token claims (name > email > "User").
func deriveDisplayName(v *oidc.VerifyResult) string {
	// email prefix fallback; full name claim not always present in our VerifyResult
	// — extend VerifyResult with Name if needed. For now email-localpart or "User".
	if at := strings.IndexByte(v.Email, '@'); at > 0 {
		return v.Email[:at]
	}
	return "User"
}

// Handle satisfies command.Handler[OIDCExchangeCommand] (unused — Service drives).
func (h *OIDCExchangeHandler) Handle(ctx context.Context, cmd OIDCExchangeCommand) error {
	return nil
}

type OIDCExchangeCommand struct {
	Provider     string
	Code         string
	CodeVerifier string
	RedirectURI  string
}
```

> 注:若要 `id_token` 含 `name` claim 用于 displayName,扩展 `oidc.idClaims` 加 `Name string` + `VerifyResult.Name`,`deriveDisplayName` 优先用 Name。

- [ ] **Step 4: 改 application/service.go**

参照 [service.go](../../../yucai/server/internal/auth/application/service.go)。`Service` struct 删 `registerHandler`/`loginHandler` 字段,加 `oidcHandler *command.OIDCExchangeHandler` + `oidcRegistry *oidc.ProviderRegistry`。`NewService` 签名改:

```go
func NewService(
	tenantRepo domain.TenantRepository,
	userRepo domain.UserRepository,
	tokenService *authjwt.TokenService,
	sessionStore command.SessionStore,
	oidcHandler *command.OIDCExchangeHandler,
	oidcRegistry *oidc.ProviderRegistry,
	refreshHandler *command.RefreshHandler,
	profileHandler *query.GetProfileHandler,
	checker domain.CurrencyCodeChecker,
) *Service
```

删 `Register` / `Login` 方法。加:

```go
// OIDCExchange handles the OIDC authorization-code exchange + jit provisioning,
// then issues a御财 session (reuses issueSession).
func (s *Service) OIDCExchange(ctx context.Context, provider, code, codeVerifier, redirectURI string) (*AuthResponse, error) {
	user, err := s.oidcHandler.Exchange(ctx, provider, code, codeVerifier, redirectURI)
	if err != nil {
		return nil, err
	}
	accessToken, refreshToken, err := s.issueSession(ctx, user)
	if err != nil {
		return nil, err
	}
	return &AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		User:         UserToDTOWithCurrency(user, s.preferredCurrencyFor(ctx, user.TenantID)),
	}, nil
}

// GetOIDCConfig returns enabled providers (secret stripped by registry).
func (s *Service) GetOIDCConfig() []oidc.ProviderConfig {
	return s.oidcRegistry.ListConfigs()
}
```

import 加 `"github.com/yucai/server/internal/auth/infrastructure/oidc"`。`issueSession` / `preferredCurrencyFor` / `RefreshToken` / `Logout` / `GetProfile` / `UpdateProfile` / `GetPreferences` / `UpdatePreferences` 不变。

- [ ] **Step 5: 改 grpc/auth_handler.go**

参照 [auth_handler.go](../../../yucai/server/internal/auth/adapter/driving/grpc/auth_handler.go)。删 `Register` / `Login` handler 方法。加:

```go
func (h *AuthHandler) GetOIDCConfig(ctx context.Context, req *pb.GetOIDCConfigRequest) (*pb.GetOIDCConfigResponse, error) {
	configs := h.service.GetOIDCConfig()
	out := make([]*pb.OIDCProviderConfig, 0, len(configs))
	for _, c := range configs {
		out = append(out, &pb.OIDCProviderConfig{
			Name:                  c.Name,
			DisplayName:           c.DisplayName,
			Issuer:                c.Issuer,
			AuthorizationEndpoint: c.AuthorizationEndpoint, // Task 4 registry discovery 填充
			ClientId:              c.ClientID,
			Scopes:                c.Scopes,
		})
	}
	return &pb.GetOIDCConfigResponse{Providers: out}, nil
}

func (h *AuthHandler) OIDCExchange(ctx context.Context, req *pb.OIDCExchangeRequest) (*pb.OIDCExchangeResponse, error) {
	if req.Provider == "" || req.Code == "" || req.CodeVerifier == "" {
		return nil, status.Error(codes.InvalidArgument, "provider, code, and code_verifier are required")
	}
	resp, err := h.service.OIDCExchange(ctx, req.Provider, req.Code, req.CodeVerifier, req.RedirectUri)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.OIDCExchangeResponse{
		AccessToken:  resp.AccessToken,
		RefreshToken: resp.RefreshToken,
		User:         dtoToProto(resp.User),
	}, nil
}
```

> `c.AuthorizationEndpoint` 由 Task 4 `registry.Load` discovery 填充,handler 无需触达 `*oidc.Provider`。

- [ ] **Step 6: build 验证**

```bash
cd yucai/server && go build ./...
```
Expected: 仍可能 FAIL(wire 未改 —— Task 7)。但 `internal/auth/...` 包内应编译通过。先 `go build ./internal/auth/...` 验证 auth 包:

```bash
cd yucai/server && go build ./internal/auth/...
```
Expected: PASS。

- [ ] **Step 7: Commit**

```bash
git add yucai/server/internal/auth/application/ yucai/server/internal/auth/adapter/driving/grpc/auth_handler.go
git commit -m "feat(auth): OIDCExchange + GetOIDCConfig application/grpc handlers, drop Register/Login"
```

---

## Task 7: wire providers + wire_gen.go 手改 + 删 password infra

**Files:**
- Modify: `yucai/server/wire/providers.go`
- Modify: `yucai/server/wire/wire_gen.go`(手改)
- Delete: `yucai/server/internal/auth/infrastructure/password/hash.go`
- Modify: `yucai/server/pkg/config/config.go`(加 OIDCProvidersPath)

**Interfaces:**
- Consumes: Task 3-6 全部新组件
- Produces: 可启动的 server(wire 完整)

- [ ] **Step 1: 删 password/hash.go**

```bash
git rm yucai/server/internal/auth/infrastructure/password/hash.go
```
grep 全仓 `infrastructure/password` 引用(register.go/login.go 已在 Task 6 删,应无残留):

```bash
cd yucai/server && grep -rn "infrastructure/password" --include="*.go" .
```
Expected: 无输出(或仅本 grep)。

- [ ] **Step 2: 改 pkg/config/config.go 加 OIDCProvidersPath**

参照现有 Config(envconfig)。加字段:

```go
type Config struct {
	// ... 现有字段 ...
	OIDCProvidersPath string `env:"OIDC_PROVIDERS_PATH,default=config/oidc_providers.yaml"`
}
```

- [ ] **Step 3: 改 wire/providers.go**

参照 [providers.go](../../../yucai/server/wire/providers.go)。删 `provideRegisterHandler`、`provideLoginHandler`。改/加:

```go
// 删:provideRegisterHandler, provideLoginHandler

// 加:
func provideIdentityRepo(client *authent.Client) *authrepo.IdentityRepository {
	return authrepo.NewIdentityRepository(client)
}

func provideOIDCRegistry(cfg *config.Config) (*oidc.ProviderRegistry, error) {
	return oidc.Load(context.Background(), cfg.OIDCProvidersPath)
}

func provideOIDCExchangeHandler(
	registry *oidc.ProviderRegistry,
	ur *authrepo.UserRepository,
	ir *authrepo.IdentityRepository,
	tr *authrepo.TenantRepository,
	seeder authcmd.PresetSeeder,
) *authcmd.OIDCExchangeHandler {
	return authcmd.NewOIDCExchangeHandler(registry, ur, ir, tr, seeder)
}

// 改 provideAuthService(删 rh, lh 参数;加 registry, ir, oidcH):
func provideAuthService(
	tr *authrepo.TenantRepository,
	ur *authrepo.UserRepository,
	ts *authjwt.TokenService,
	ss *session.RedisSessionStore,
	registry *oidc.ProviderRegistry,
	ir *authrepo.IdentityRepository,
	oidcH *authcmd.OIDCExchangeHandler,
	fh *authcmd.RefreshHandler,
	ph *authquery.GetProfileHandler,
	checker authdomain.CurrencyCodeChecker,
) *authapp.Service {
	return authapp.NewService(tr, ur, ts, ss, oidcH, registry, fh, ph, checker)
}
```

import 加 `"github.com/yucai/server/internal/auth/infrastructure/oidc"`。`accountPresetSeeder` / `providePresetSeeder` 保留(给 OIDCExchangeHandler 用)。`provideAuthHandler` 不变。

- [ ] **Step 4: 手改 wire/wire_gen.go**

依 memory `yucai-wire-handmaintained`,**镜像 providers.go 声明顺序,消费方在依赖方之后**。改动:
- 删 `registerHandler` / `loginHandler` 的 provider 链(`NewRegisterHandler`/`NewLoginHandler` 调用 + 变量)
- 加 `identityRepo := provideIdentityRepo(authEntClient)`、`oidcRegistry, err := provideOIDCRegistry(cfg)`、`oidcExchangeHandler := provideOIDCExchangeHandler(...)`
- 改 `authService := provideAuthService(...)` 调用实参(去 rh/lh,加 registry/ir/oidcH)
- 错误处理:`provideOIDCRegistry` 返回 error,需在 InitializeApp 内 `if err != nil { return nil, err }`

> 实现者:打开 `wire_gen.go`,定位 `authService :=` 与 `registerHandler :=`/`loginHandler :=` 段,按上述镜像改。这是手改,不跑 wire CLI。

- [ ] **Step 5: build 全量**

```bash
cd yucai/server && go build ./...
```
Expected: PASS。

- [ ] **Step 6: 全量测试(确认未破坏跨包)**

```bash
cd yucai/server && go test ./... -count=1
```
Expected: 全 PASS(或仅已知与 auth 无关的预存问题)。删 Register/Login 后,若有 auth 相关旧 test(register_test/login_test)需删/改 —— grep 确认:

```bash
cd yucai/server && grep -rln "Register\|Login\|password" internal/auth/ --include="*_test.go"
```
删/改命中的过期测试。

- [ ] **Step 7: Commit**

```bash
git add yucai/server/wire/ yucai/server/pkg/config/ yucai/server/internal/auth/
git commit -m "feat(auth): wire OIDC providers, drop password/register/login infra"
```

---

## Task 8: server OIDCExchange handler 单测

**Files:**
- Create: `yucai/server/internal/auth/application/command/oidc_exchange_test.go`(或 grpc handler test)

**Interfaces:**
- Consumes: Task 4 mock IDP helper + Task 6 handler

- [ ] **Step 1: 写 jit provisioning 测试**

复用 Task 4 的 mock IDP httptest helper(提取到 `oidc/oidctest/` 共享,或在 test 内联)。测试场景:
- **未命中 identity** → Exchange 建 user+tenant+identity,返回 user
- **命中 identity**(预插) → Exchange 返回现有 user,不重复建
- **unknown provider** → error
- **id_token 验签失败**(篡改签名) → error

Test 用 enttest SQLite client + 真 repo + mock IDP provider(构造 `oidc.Provider` 指向 test server)。

```go
// 伪代码骨架(实现者补全 mock IDP setup,照 Task 4 verifier_test 范式)
func TestOIDCExchange_JitProvisioning(t *testing.T) {
	// 1. setup enttest client + repos
	// 2. setup mock IDP httptest server(discovery + token endpoint 返签名 id_token)
	// 3. 构造 registry with 一个指向 mock IDP 的 Provider
	// 4. handler.Exchange(ctx, "google", "code", "verifier", "http://localhost:0/callback")
	// 5. assert: user 已建, identityRepo.FindByProviderSubject 命中, user.Email == verified email
}

func TestOIDCExchange_ExistingIdentity(t *testing.T) {
	// 预插 user+identity,Exchange 返回同一 user,无新建(user count 不变)
}

func TestOIDCExchange_UnknownProvider(t *testing.T) {
	// Exchange("nobody", ...) → error 含 "unknown provider"
}
```

- [ ] **Step 2: 跑测试**

```bash
cd yucai/server && go test ./internal/auth/application/command/... -count=1 -run OIDCExchange
```
Expected: PASS。

- [ ] **Step 3: 全量 server 测试**

```bash
cd yucai/server && go test ./... -count=1
```
Expected: PASS。

- [ ] **Step 4: Commit**

```bash
git add yucai/server/internal/auth/application/command/oidc_exchange_test.go yucai/server/internal/auth/infrastructure/oidc/oidctest/
git commit -m "test(auth): OIDCExchange jit provisioning + error paths with mock IDP"
```

---

## Task 9: client proto regen + AuthRepository/remote_ds/usecase 改

**Files:**
- regen: `yucai/client/lib/proto/auth/v1/`
- Modify: `yucai/client/lib/auth/domain/repositories/auth_repository.dart`
- Modify: `yucai/client/lib/auth/domain/entities/oidc_provider.dart`(新建)
- Modify: `yucai/client/lib/auth/data/auth_remote_ds.dart`
- Modify: `yucai/client/lib/auth/data/auth_repository_impl.dart`
- Delete: `yucai/client/lib/auth/domain/usecases/login_usecase.dart`、`register_usecase.dart`
- Create: `yucai/client/lib/auth/domain/usecases/oidc_login_usecase.dart`

**Interfaces:**
- Produces: `AuthRepository.oidcExchange({provider, code, verifier, redirectUri})` / `getOIDCConfig()`;`AuthRemoteDataSource.oidcExchange(...)` / `getOIDCConfig()`。**注**:repository 只做低层 code 交换,**不**持有 `OIDCAuthenticator` —— 取 code 的 flow 编排归 usecase(Task 11),保证 repository 独立可测、Task 9 绿 build。

- [ ] **Step 1: regen Dart stub**

```bash
cd yucai && make gen-dart
```
Expected: `lib/proto/auth/v1/auth.pb.dart` 等更新(新 messages,删 Register/Login)。**确认 protoc_plugin 25.0.0**(CLAUDE.md 约束)。

- [ ] **Step 2: 新建 oidc_provider.dart entity**

```dart
// yucai/client/lib/auth/domain/entities/oidc_provider.dart
import 'package:equatable/equatable.dart';

class OidcProviderConfig extends Equatable {
  const OidcProviderConfig({
    required this.name,
    required this.displayName,
    required this.issuer,
    required this.authorizationEndpoint,
    required this.clientId,
    required this.scopes,
  });
  final String name;
  final String displayName;
  final String issuer;
  final String authorizationEndpoint;
  final String clientId;
  final List<String> scopes;

  @override
  List<Object?> get props => [name, displayName, issuer, authorizationEndpoint, clientId, scopes];
}
```

- [ ] **Step 3: 改 auth_repository.dart(domain interface)**

```dart
abstract class AuthRepository {
  Future<Either<Failure, User>> oidcExchange({
    required String provider,
    required String code,
    required String codeVerifier,
    required String redirectUri,
  });
  Future<Either<Failure, List<OidcProviderConfig>>> getOIDCConfig();
  Future<Either<Failure, AuthTokens>> refreshToken();
  Future<Either<Failure, User>> getProfile();
  Future<void> logout();
}
```
删 `register` / `login`。

- [ ] **Step 4: 改 auth_remote_ds.dart**

参照 [auth_remote_ds.dart](../../../yucai/client/lib/auth/data/auth_remote_ds.dart)。删 `register` / `login`。加:

```dart
Future<({User user, AuthTokens tokens})> oidcExchange({
  required String provider,
  required String code,
  required String codeVerifier,
  required String redirectUri,
}) async {
  final res = await _client.oIDCExchange(pb.OIDCExchangeRequest()
    ..provider = provider
    ..code = code
    ..codeVerifier = codeVerifier
    ..redirectUri = redirectUri);
  return (
    user: _mapper.toDomain(res.user),
    tokens: AuthTokens(accessToken: res.accessToken, refreshToken: res.refreshToken),
  );
}

Future<List<OidcProviderConfig>> getOIDCConfig() async {
  final res = await _client.getOIDCConfig(pb.GetOIDCConfigRequest());
  return res.providers
      .map((p) => OidcProviderConfig(
            name: p.name,
            displayName: p.displayName,
            issuer: p.issuer,
            authorizationEndpoint: p.authorizationEndpoint,
            clientId: p.clientId,
            scopes: p.scopes,
          ))
      .toList();
}
```

- [ ] **Step 5: 改 auth_repository_impl.dart**

参照 [auth_repository_impl.dart](../../../yucai/client/lib/auth/data/auth_repository_impl.dart)。删 `register`/`login`,构造不变(只 `_remote` + `_storage`,**不**注入 authenticator)。加 `oidcExchange`(纯 RPC,不取 code):

```dart
@override
Future<Either<Failure, User>> oidcExchange({
  required String provider,
  required String code,
  required String codeVerifier,
  required String redirectUri,
}) async {
  try {
    final result = await _remote.oidcExchange(
      provider: provider, code: code, codeVerifier: codeVerifier, redirectUri: redirectUri,
    );
    await _storage.saveTokens(result.tokens);
    return Right(result.user);
  } on GrpcError catch (e) {
    return Left(_mapGrpcError(e));
  } catch (e) {
    return Left(UnexpectedFailure(e.toString()));
  }
}

@override
Future<Either<Failure, List<OidcProviderConfig>>> getOIDCConfig() async {
  try {
    return Right(await _remote.getOIDCConfig());
  } on GrpcError catch (e) {
    return Left(_mapGrpcError(e));
  } catch (e) {
    return Left(UnexpectedFailure(e.toString()));
  }
}
```

> repository 不依赖 `OIDCAuthenticator` —— code 获取的 flow 编排在 Task 11 的 `OidcLoginUseCase`。本 task 可独立编译 + 测试。

- [ ] **Step 6: 删 login/register usecase**

```bash
git rm yucai/client/lib/auth/domain/usecases/login_usecase.dart
git rm yucai/client/lib/auth/domain/usecases/register_usecase.dart
```

> `OidcLoginUseCase` 在 **Task 11** 建(它组装 `OIDCAuthenticator` Task 10 + `repo.oidcExchange`),不在此 task —— 避免 Task 9 依赖 Task 10。

- [ ] **Step 7: build_runner regen(injectable,因构造函数改)**

```bash
cd yucai/client && dart run build_runner build --delete-conflicting-outputs
```
Expected: `config.injection.dart` 更新(AuthRepositoryImpl 新依赖)。

- [ ] **Step 8: 暂不跑 analyze/bloc(等 Task 10/11)—— 本 task 提交 stub**

- [ ] **Step 9: Commit**

```bash
git add yucai/client/lib/proto/ yucai/client/lib/auth/ yucai/client/lib/core/ yucai/client/lib/config.injection.dart
git commit -m "feat(auth-client): OIDC repository/remote_ds/usecase, drop login/register"
```

---

## Task 10: client oidc_authenticator(loopback PKCE)

**Files:**
- Create: `yucai/client/lib/auth/data/oidc_authenticator.dart`
- Modify: `yucai/client/pubspec.yaml`(加 url_launcher)

**Interfaces:**
- Consumes: `OidcProviderConfig`(Task 9)
- Produces: `OIDCAuthenticator.authenticate(config) → ({code, verifier, redirectUri})`

- [ ] **Step 1: 加 url_launcher 依赖**

```bash
cd yucai/client && flutter pub add url_launcher
```
Expected: pubspec.yaml + pubspec.lock 更新。

- [ ] **Step 2: 写 oidc_authenticator.dart**

```dart
// yucai/client/lib/auth/data/oidc_authenticator.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:injectable/injectable.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yucai_client/auth/domain/entities/oidc_provider.dart';

class OidcAuthResult {
  const OidcAuthResult({required this.code, required this.verifier, required this.redirectUri});
  final String code;
  final String verifier;
  final String redirectUri;
}

/// Loopback-based OIDC authorization-code + PKCE flow for desktop (Windows).
/// 1. generate PKCE verifier + S256 challenge + random state
/// 2. bind a temporary localhost HTTP server (random port)
/// 3. open system browser to the provider's authorization endpoint
/// 4. capture the code on the loopback callback, verify state, close server
@LazySingleton()
class OIDCAuthenticator {
  /// Returns the authorization code + the verifier (needed by OIDCExchange)
  /// Throws on user-cancel/timeout/mismatched state.
  Future<OidcAuthResult> authenticate(OidcProviderConfig config, {Duration timeout = const Duration(minutes: 3)}) async {
    final verifier = _generateCodeVerifier();
    final challenge = _s256Challenge(verifier);
    final state = _generateRandomString(16);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    final redirectUri = 'http://localhost:$port/callback';

    final authUrl = Uri.parse(config.authorizationEndpoint).replace(queryParameters: {
      'response_type': 'code',
      'client_id': config.clientId,
      'redirect_uri': redirectUri,
      'scope': config.scopes.join(' '),
      'state': state,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    });

    if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
      await server.close(force: true);
      throw Exception('failed to launch browser');
    }

    final completer = Completer<OidcAuthResult>();
    Timer? watchdog;
    watchdog = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(Exception('oidc flow timed out'));
        server.close(force: true);
      }
    });

    server.listen((HttpRequest req) async {
      final uri = req.uri;
      await _respondAndClose(req);
      if (uri.path != '/callback') return;
      final qp = uri.queryParameters;
      if (qp['state'] != state) {
        if (!completer.isCompleted) completer.completeError(Exception('state mismatch'));
        return;
      }
      final code = qp['code'];
      if (code == null) {
        if (!completer.isCompleted) completer.completeError(Exception('no code in callback: ${qp['error'] ?? ""}'));
        return;
      }
      if (!completer.isCompleted) {
        completer.complete(OidcAuthResult(code: code, verifier: verifier, redirectUri: redirectUri));
        watchdog?.cancel();
        await server.close(force: true);
      }
    });

    return completer.future;
  }

  Future<void> _respondAndClose(HttpRequest req) async {
    req.response
      ..statusCode = 200
      ..headers.contentType = ContentType.html
      ..write('<html><body><h3>登录成功，请返回御财应用。</h3></body></html>');
    await req.response.close();
  }

  String _generateCodeVerifier() => _generateRandomString(64);
  String _generateRandomString(int n) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final r = Random.secure();
    return List.generate(n, (_) => chars[r.nextInt(chars.length)]).join();
  }
  String _s256Challenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
}
```

- [ ] **Step 3: integration test(loopback + 模拟 redirect)**

Test 文件:`yucai/client/test/auth/data/oidc_authenticator_test.dart`。模拟:bind 一个 test HttpServer 作"浏览器",authenticate 启动后,用 `HttpClient` 向 loopback /callback 发 redirect(code+state),断言拿到 code。`launchUrl` mock(mocktail platform channel)或 skip on CI(`@OnPlatform`).

> 实现者:url_launcher 在 test 需 mock platform channel。可注入一个 `Future<bool> Function(Uri)` launcher 函数,生产用 launchUrl,test 用 fake。重构 `authenticate` 接收可选 launcher 参数。

- [ ] **Step 4: build_runner regen + analyze**

```bash
cd yucai/client && dart run build_runner build --delete-conflicting-outputs
cd yucai/client && flutter analyze
```
Expected: analyze 不新增 error(基线:22 error 全 *.pbserver.dart)。

- [ ] **Step 5: Commit**

```bash
git add yucai/client/lib/auth/data/oidc_authenticator.dart yucai/client/pubspec.yaml yucai/client/pubspec.lock yucai/client/test/auth/
git commit -m "feat(auth-client): OIDC loopback PKCE authenticator (Windows desktop)"
```

---

## Task 11: client bloc + 登录页 + router

**Files:**
- Modify: `yucai/client/lib/auth/presentation/bloc/auth_bloc.dart`
- Modify: `yucai/client/lib/auth/presentation/bloc/auth_event.dart`
- Modify: `yucai/client/lib/auth/presentation/pages/login_page.dart`
- Delete: `yucai/client/lib/auth/presentation/pages/register_page.dart`
- Modify: router(`/register` 路由删除)

**Interfaces:**
- Produces: `OIDCLoginRequested(provider)` event;登录页 provider 按钮;可登录的完整 flow

- [ ] **Step 1: 改 auth_event.dart**

删 `LoginRequested` / `RegisterRequested`。加:

```dart
class OIDCLoginRequested extends AuthEvent {
  const OIDCLoginRequested(this.provider);
  final String provider;
  @override
  List<Object?> get props => [provider];
}
```

- [ ] **Step 2: 建 OidcLoginUseCase(组装 authenticator + repo.oidcExchange)**

```dart
// yucai/client/lib/auth/domain/usecases/oidc_login_usecase.dart
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:yucai_client/auth/data/oidc_authenticator.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/domain/repositories/auth_repository.dart';
import 'package:yucai_client/core/error/failures.dart';

@injectable
class OidcLoginUseCase {
  OidcLoginUseCase(this._repo, this._authenticator);
  final AuthRepository _repo;
  final OIDCAuthenticator _authenticator;

  Future<Either<Failure, User>> call(String provider) async {
    final configResult = await _repo.getOIDCConfig();
    if (configResult.isLeft()) return Left((configResult as Left).value);
    final configs = (configResult as Right).value as List;
    final config = configs.firstWhere((p) => p.name == provider);
    try {
      final auth = await _authenticator.authenticate(config);
      return _repo.oidcExchange(
        provider: provider,
        code: auth.code,
        codeVerifier: auth.verifier,
        redirectUri: auth.redirectUri,
      );
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
```

> `OIDCAuthenticator`(Task 10)注入此 usecase;repository 不知 authenticator 存在(DDD 编排归 usecase)。

- [ ] **Step 3: 改 auth_bloc.dart**

参照 [auth_bloc.dart](../../../yucai/client/lib/auth/presentation/bloc/auth_bloc.dart)。构造删 `LoginUseCase`/`RegisterUseCase`,加 `OidcLoginUseCase`。删 `_onLogin`/`_onRegister`,加:

```dart
on<OIDCLoginRequested>(_onOIDCLogin);

final OidcLoginUseCase _oidcLogin;

Future<void> _onOIDCLogin(OIDCLoginRequested event, Emitter<AuthState> emit) async {
  emit(AuthLoading());
  final result = await _oidcLogin.call(event.provider);
  result.fold(
    (failure) => emit(AuthError(failure.displayMessage)),
    (user) => emit(Authenticated(user)),
  );
}
```

- [ ] **Step 4: 改 login_page.dart(表单 → provider 按钮)**

参照 [login_page.dart](../../../yucai/client/lib/auth/presentation/pages/login_page.dart)。删表单 widget,改为从 BlocProvider/Repository 拿 provider 列表渲染按钮。简化版(首发单 provider 硬编码 "google",或从 getOIDCConfig 拉):

```dart
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('御财', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text('登录以继续', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 32),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    return FilledButton.icon(
                      onPressed: state is AuthLoading
                          ? null
                          : () => context.read<AuthBloc>().add(const OIDCLoginRequested('google')),
                      icon: const Icon(LucideIcons.logIn),
                      label: const Text('使用 Google 登录'),
                    );
                  },
                ),
                BlocListener<AuthBloc, AuthState>(
                  listener: (context, state) {
                    if (state is AuthError) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
                    }
                  },
                  child: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

> 多 provider 扩展:用 `FutureBuilder` 包 `getOIDCConfig()`,按返回列表渲染多个按钮。首发单 Google 硬编码即可(YAGNI)。

- [ ] **Step 5: 删 register_page.dart + 路由**

```bash
git rm yucai/client/lib/auth/presentation/pages/register_page.dart
```
改 router(定位 `GoRoute(path: '/register', ...)` 与 `/login` 的 `TextButton → context.go('/register')`),删 /register route,删 login_page 内"注册"入口(已在上一步删)。

- [ ] **Step 6: build_runner regen(bloc 构造改)+ analyze + test**

```bash
cd yucai/client && dart run build_runner build --delete-conflicting-outputs
cd yucai/client && flutter analyze
```
Expected: 无新增 error。

- [ ] **Step 7: 清理 register/login 残留 widget test**

```bash
cd yucai/client && grep -rln "LoginRequested\|RegisterRequested\|register\|login" test/ --include="*.dart"
```
删/改命中(尤其 login_page_test / register_page_test 若存在)。确保不破坏 3 测/2 文件预存 fail 基线(account_detail_page / receivable_detail_page)。

- [ ] **Step 8: Commit**

```bash
git add yucai/client/lib/auth/ yucai/client/lib/ yucai/client/test/
git commit -m "feat(auth-client): OIDC login page + bloc, drop email/password form + register"
```

---

## Task 12: client widget/bloc 测试

**Files:**
- Create/Modify: `yucai/client/test/auth/...`

- [ ] **Step 1: auth_repository_impl.oidcLogin mock test**

mocktail mock `AuthRemoteDataSource` + `OIDCAuthenticator`,验证 oidcLogin 存 token:

```dart
// test/auth/data/auth_repository_impl_test.dart(骨架)
class MockRemote extends Mock implements AuthRemoteDataSource {}
class MockAuthenticator extends Mock implements OIDCAuthenticator {}
class FakeStorage extends Fake implements TokenStorage {}

void main() {
  test('oidcLogin stores tokens on success', () async {
    final remote = MockRemote();
    final authenticator = MockAuthenticator();
    final storage = FakeStorage();
    final repo = AuthRepositoryImpl(remote, storage, authenticator);
    // when(remote.getOIDCConfig()).thenAnswer(... google config)
    // when(authenticator.authenticate(...)).thenAnswer(... OidcAuthResult)
    // when(remote.oidcExchange(...)).thenAnswer(... tokens + user)
    // final result = await repo.oidcLogin('google');
    // expect(result.isRight(), true);
  });
}
```

- [ ] **Step 2: auth_bloc OidcLogin test**

mock `OidcLoginUseCase`,验证 OIDCLoginRequested → AuthLoading → Authenticated/ AuthError。

- [ ] **Step 3: 跑 client 测试**

```bash
cd yucai/client && flutter test
```
Expected: 新测 PASS;预存 3 fail 不变(基线)。

- [ ] **Step 4: Commit**

```bash
git add yucai/client/test/auth/
git commit -m "test(auth-client): oidcLogin repository + bloc mocktail tests"
```

---

## Task 13: 联调 — Google Console + 数据迁移 + 手动验证

**Files:**
- 无代码改动(配置 + 验证)

- [ ] **Step 1: Google Cloud Console 配置**(手动)
- 创建 OAuth 2.0 Client ID(Web application)
- Authorized redirect URIs:`http://localhost:8080/callback`(loopback;Google 端口宽松)
- Scopes:openid email profile
- OAuth consent screen:app 名"御财"(Testing 模式)

- [ ] **Step 2: 配置 server**

填 `config/oidc_providers.yaml` 的 `client_id`(真值)+ 设 env `OIDC_GOOGLE_CLIENT_SECRET`:

```bash
export OIDC_GOOGLE_CLIENT_SECRET='<real_secret>'
```

- [ ] **Step 3: 数据迁移(dev 清表)**

连 podman `yucai-pg`,清旧 user/tenant(纯 OIDC 下无 identity 的老 user 无法登录):

```bash
podman exec -it yucai-pg psql -U yucai -d yucai -c "DELETE FROM users; DELETE FROM tenants;"
```
> 确认表名(generated,可能 `users`/`tenants`)。server 启动 auto-migrate 会建 `user_identities` 表 + 删 `password_hash` 列。

- [ ] **Step 4: 启动 server + client 联调**

```bash
# server(memory yucai-dev-env:绝对路径 cd + background)
export DATABASE_URL='postgresql://yucai:yucai@localhost:5432/yucai?sslmode=disable'
export JWT_SECRET='...'
export GRPC_PORT=9090
export OIDC_GOOGLE_CLIENT_SECRET='...'
cd e:/projects/syfinance/yucai/server && ./bin/server.exe   # 或 go run ./cmd/server

# client
cd e:/projects/syfinance/yucai/client && flutter run -d windows
```

- [ ] **Step 5: 手动验证清单**
- [ ] 登录页显示"使用 Google 登录"按钮,无 email/password 表单
- [ ] 点击 → 系统浏览器打开 Google 登录页
- [ ] 登录 → 浏览器显示"登录成功" → 自动关闭/可手动关
- [ ] 御财 app 进入已登录态(home/dashboard)
- [ ] DB:`user_identities` 表有一条 google identity;`users` 表对应 user(无 password_hash 列)
- [ ] 重启 app → token_storage 持有 JWT → 自动已登录(GetProfile 成功)
- [ ] token 过期 → auth_retry 401 自动 refresh 成功

- [ ] **Step 6: 全量回归测试**

```bash
cd yucai/server && go test ./... -count=1
cd yucai/client && flutter test
cd yucai/client && flutter analyze
```
Expected: server 全 PASS;client 测试仅预存 3 fail;analyze 22 error 全 *.pbserver.dart(基线)。

- [ ] **Step 7: Commit(如有配置/小修)+ 收尾记录**

```bash
# 若 config 或小修
git add -A
git commit -m "chore(auth): dev integration tuning for OIDC google"
```
更新 memory `auth-oidc-migration`(标记实现完成)。

---

## Notes for Implementer

- **wire_gen.go 手改是高风险点**:改完务必 `go build ./...` + `go test ./...` 全过。镜像 providers.go 顺序,消费方在依赖方后。
- **interface 改了(UserRepository/SessionStore 等)→ grep 全 implementer 含 test fake,跑全量 suite**(CLAUDE.md 约束 6)。
- **删 Register/Login 后**,所有引用处(handler/service/wire/bloc/usecase/page/test)都要清 —— 用 grep 扫:`grep -rn "Register\|Login\|password_hash\|PasswordHash\|FindByEmail" --include="*.go" --include="*.dart" yucai/`。
- **proto regen 双端**:Go(`buf generate`) + Dart(`make gen-dart`,protoc_plugin 25.0.0)都要跑。
- **ent generate 仅 auth 模块**:`go generate ./internal/auth/ent/...`(非全仓)。
- **log 全英文,slog**。中文只在 client UI。
- **不 push**,每 task commit 留 review gate。
