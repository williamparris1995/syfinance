# 御财 Auth OIDC 迁移设计

- **日期**:2026-07-20
- **状态**:设计已确认(brainstorming 完成,待 writing-plans)
- **关联需求**:memory `auth-oidc-migration`(用户 2026-07-19 提出"为什么还是注册登录,不是用 OIDC 了吗,不要自建")
- **关联模块**:`server/internal/auth/`、`client/lib/auth/`、`proto/auth/v1/auth.proto`

## 1. 背景与动机

御财当前 auth 是**完全自建**:email/password + bcrypt(`infrastructure/password/hash.go`)+ JWT access/refresh(`infrastructure/jwt/token.go`)+ redis refresh session(`adapter/driven/session/redis_store.go`)。proto 提供 Register/Login/RefreshToken/GetProfile/UpdateProfile/GetPreferences/UpdatePreferences 七个 RPC。

User ent schema(`internal/auth/ent/schema/user.go`)已**预留** `oauth_provider` / `oauth_id` 字段,但 `password_hash` 仍是 `NotEmpty()` 必填,OAuth 分支从未实现 —— 设计自相矛盾,预留字段形同摆设。

用户动机(brainstorming 确认,四项全选):
1. **UX/降低登录摩擦** —— 不想记密码、不想填注册表单
2. **安全/不存密码** —— 不想自负责密码 hash,信任大厂 IDP
3. **多设备/家庭共享** —— 多设备同步登录态、家庭多人各自账号
4. **纯理念/去自建** —— 不再维护自建 auth 模块全栈,交给标准协议

本 spec 把 auth 身份层从自建密码迁移到 **OIDC**(OpenID Connect),首发接 Google。

## 2. 目标与非目标

### 目标
- 删除自建密码 auth(email/password + bcrypt + Register/Login RPC + `password_hash` 字段)
- 接入 OIDC,首发 provider = Google,架构上支持多 IDP 扩展
- 登录后**复用御财现有 JWT + redis refresh session** 基础设施(只换"身份来源",不换 session 模型)
- Windows desktop client 可发起 OIDC flow 并完成登录

### 非目标(显式 defer,不在本 spec)
- **家庭多用户 tenant**:御财当前 1 user = 1 tenant,`family_role`/`admin`/`member` 仅 schema 预留、无业务逻辑、无邀请机制。"家庭共享"是独立新需求,本 spec 不覆盖
- **账号链接(link)**:登录后绑定/解绑其他 IDP 到同一 user(`user_identity` 表为此预留,但 link RPC/UI 不在首发)
- **prod 数据迁移**:御财无 prod 部署;纯 OIDC 下老 password user 本就无 OIDC `sub` 可绑,迁移无意义
- **`nonce` 防重放**:PKCE + state 已提供足够保护,nonce defer
- **完整 OIDC e2e**:首发靠单测覆盖,e2e(真实/mock IDP 编排)作 follow-up

## 3. 决策摘要

| 维度 | 决策 |
|---|---|
| IDP | 多 provider 架构,首发 Google |
| 密码 | 纯 OIDC,删 `password_hash` / Register / Login,jit provisioning(首次登录自动建 user) |
| 身份模型 | 拆 `UserIdentity` 一对多表(架构正确、为账号链接铺路),首发扁平身份(按 `(provider, subject)` 找/建) |
| 账号链接 | defer(`UserIdentity` 表已预留,首发不实现 link RPC/UI) |
| OIDC flow 架构 | **方案 A**:client loopback PKCE 发起 + server 交换 code + 御财自签 JWT |
| token 模型 | OIDC 仅身份验证;登录成功后发御财 access+refresh(复用 `issueSession`),不直接用 IDP token |
| Scope | 仅 auth 身份层替换,家庭 tenant 独立后续 spec |

## 4. 架构总览(方案 A)

御财既有 Flutter desktop client 又有 Go gRPC server,OIDC flow 责任划分如下:

```
Flutter(data/oidc_authenticator.dart)
  ① crypto 生成 PKCE verifier + S256 challenge + 随机 state
  ② HttpServer.bind('127.0.0.1', 0)  ← 临时 loopback(拿到 code 即关)
  ③ 拼 auth URL(issuer auth_endpoint + client_id + redirect_uri
              = http://localhost:{port}/callback + code_challenge + state
              + scope=openid email profile)
  ④ url_launcher 开系统浏览器 → 用户 Google 登录
  ⑤ Google redirect → loopback 捕 code(并验 state 匹配)→ 关 server
  ⑥ gRPC OIDCExchange(provider, code, code_verifier, redirect_uri)
御财 server(internal/auth)
  ⑦ registry.Get(provider) → Provider(go-oidc + oauth2,无则 InvalidArgument)
  ⑧ oauth2.Config.Exchange(ctx, code, code_verifier, ...) → 拿 id_token
  ⑨ provider.Verifier.VerifyIDToken(id_token) → claims{sub, email, email_verified}
  ⑩ identityRepo.FindByProviderSubject(provider, sub)
     ├─ 命中 → user = userRepo.FindByID(identity.UserID)
     └─ 未命中 → jit(tx:建 Tenant → 建 User → 建 Identity)
  ⑪ issueSession(user) → 御财 access + refresh(复用现有 JWT + redis)
  ⑫ 返回 AuthResponse(access+refresh+user DTO)
Flutter 存 token(token_storage),后续走现有 auth_interceptor(零改动)
```

**为何此方案**:
- 复用御财成熟 JWT/refresh 基础设施,只把身份来源从 password 换成 OIDC id_token
- server 保持纯 gRPC,无需暴露 HTTP callback endpoint
- PKCE 规范要求 verifier 由发起方(client)持有;secret 留 server(不入 client/proto)
- 登录后离线可用(JWT 自包含,不依赖 IDP 可达)
- 多 provider 扩展 = server 加 provider 配置,client 通过 `GetOIDCConfig` 自动发现

**排除的备选方案**:
- **方案 B(server 主导 flow + HTTP callback)**:server 处理整个 OIDC,callback 到 server HTTP endpoint,再推 token 回 client。需给纯 gRPC server 新增 HTTP 层 + 浏览器会话/轮询,实现量大
- **方案 C(client 全权处理)**:Flutter 自己换 token+验证,只发 id_token 给 server。client_secret 泄露风险(桌面 app 易逆向)、id_token 在 client 暴露面大、验证逻辑分散

## 5. 数据模型

### 5.1 `User` 表改造(`internal/auth/ent/schema/user.go`)

| 字段 | 现状 | OIDC 后 |
|---|---|---|
| `password_hash` | `NotEmpty()` Sensitive | **删** |
| `oauth_provider` | `Optional("")` | **删**(移到 `UserIdentity`) |
| `oauth_id` | `Optional("")` | **删**(移到 `UserIdentity`) |
| `email` | `NotEmpty()` + `(tenant_id,email)` unique | `Optional()`。退为 profile metadata(jit 时从首个 identity 的 email 填充),**删** `(tenant_id, email)` unique index |
| `id` / `display_name` / `avatar_url` / `family_role` / `created_at` / `updated_at` | — | 不变 |

tenant 关系、`family_role`(默认 `owner`)不变 —— jit provisioning 沿用现状建独立 1:1 tenant。

### 5.2 新增 `UserIdentity` 表(`internal/auth/ent/schema/user_identity.go`)

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | uuid | PK |
| `user_id` | uuid(edge→User) | 归属 user |
| `provider` | string `NotEmpty` | `"google"` / `"github"` / ... |
| `subject` | string `NotEmpty` | IDP 的 `sub` claim(provider 内唯一) |
| `issuer` | string Optional | IDP issuer URL(OIDC 严格验证用) |
| `email_at_provider` | string Optional | 该 IDP 返回的 email(多 identity 可能不同) |
| `created_at` / `updated_at` | time | — |

**Indexes**:
- `(provider, subject)` **global unique** —— OIDC 身份查找键
- `(user_id, provider)` **unique** —— 一个 user 同 provider 只绑一个 identity(防重复绑,为未来 link 铺路)

需 `ent generate` 新 schema(**非 wire,工具链正常**)。

### 5.3 身份查找逻辑

client 选 provider → server 按 `(provider, subject)` 查 `UserIdentity`:
- **命中**:取 `user_id` → `userRepo.FindByID` → `issueSession`
- **未命中**:jit provisioning(tx 内建 Tenant → 建 User → 建 Identity)→ `issueSession`

## 6. proto + API 改造(`proto/auth/v1/auth.proto`)

**删**:`Register`、`Login` RPC + 对应 `RegisterRequest/Response`、`LoginRequest/Response` message。

**保留不变**:`RefreshToken`、`GetProfile`、`UpdateProfile`、`GetPreferences`、`UpdatePreferences` —— 身份验证后的 API 完全不动,现有 client 调用零改动。

**新增 2 个 RPC**(均 auth-bypass,身份由 code 交换确立):

### 6.1 `GetOIDCConfig`
```proto
message GetOIDCConfigRequest {}
message OIDCProviderConfig {
  string name = 1;                  // "google"
  string display_name = 2;          // "使用 Google 登录"
  string issuer = 3;
  string authorization_endpoint = 4;
  string client_id = 5;
  repeated string scopes = 6;
}
message GetOIDCConfigResponse {
  repeated OIDCProviderConfig providers = 1;
}
```
返回 server 启用的 provider 列表(剥 `client_secret`)。client 用它渲染登录页按钮 + 发起 PKCE flow。**`redirect_uri` 不在此返回** —— loopback 端口由 client 动态绑定,redirect 由 client 决定(`http://localhost:{port}/callback`)。

### 6.2 `OIDCExchange`
```proto
message OIDCExchangeRequest {
  string provider = 1;
  string code = 2;
  string code_verifier = 3;
  string redirect_uri = 4;          // 必须与 auth request 一致(含实际 loopback 端口)
}
message OIDCExchangeResponse {
  // 复用现有 AuthResponse 结构
  string access_token = 1;
  string refresh_token = 2;
  UserDTO user = 3;
}
```
`redirect_uri` 必须与 client 发起 auth request 时的一致(Google token endpoint 校验)。**`state` 不传 server** —— state 验证纯 client 内部(loopback 捕获时对照发起 state)。

proto 改后 **Go + Dart stub 都要 regen**(CLAUDE.md 约束 5;Dart protoc_plugin **25.0.0**)。

## 7. server OIDC 模块设计(Go,`internal/auth/`)

### 7.1 Go 库选型
- `github.com/coreos/go-oidc/v3/oidc` —— Provider discovery(.well-known)、JWKS 自动验签、IDToken verifier
- `golang.org/x/oauth2` —— authorization code 交换
- 新增进 `go.mod`

### 7.2 DDD 四层改动

| 层 | 改动 |
|---|---|
| `domain/` | 新 `identity.go`(`UserIdentity` entity + `NewUserIdentity`);`UserRepository` 加 `FindByProviderSubject(provider, subject)`;新 `IdentityRepository` interface |
| `application/` | **删** `Register`/`Login` + 对应 command/handler;新 `OIDCExchange` command/handler(orchestrate:换 token→验证→查/jit→issueSession);`GetOIDCConfig`(透传 registry) |
| `infrastructure/` | 新 `oidc/`(provider.go / registry.go / verifier.go);新 `IdentityRepository` ent 实现;`user_repo.go` 加 `FindByProviderSubject`(join identity);**删** `password/hash.go`(bcrypt);jwt / session 不变 |
| `adapter/driving/grpc/` | handler 删 Register/Login,加 OIDCExchange/GetOIDCConfig;`issueSession` 复用 |

### 7.3 provider 抽象(infrastructure/oidc/)
```
provider.go   // ProviderConfig{name, display_name, issuer, client_id, client_secret,
              //   redirect_uri, scopes} + Provider(封装 go-oidc Provider + oauth2.Config)
registry.go   // ProviderRegistry: map[name]*Provider,启动从 yaml+env 合并加载
verifier.go   // id_token 验证(Verifier.VerifyIDToken → claims)
```
**加 provider = 加一条 yaml 配置**,server/client 都不改。

### 7.4 jit provisioning 字段策略
- `display_name`:取 id_token `name` claim → 无则 email 前缀 → 再无则 `"User"`
- `email`:**仅 `email_verified=true`** 才填 `user.email`;否则只存 `identity.email_at_provider`
- `tenant`:jit 建新 tenant(1:1,沿用现状命名逻辑)

## 8. client 改造(Flutter,`client/lib/auth/`)

### 8.1 OIDC client 逻辑(新 `data/oidc_authenticator.dart`,~100-150 行)

**关键约束**:御财 Windows desktop 优先,而 `flutter_appauth` **不支持 Windows**(只 iOS/Android/macOS/web)。故用 **loopback redirect + 轻量手写**(RFC 8252 desktop 标准):
1. `crypto` 生成 PKCE verifier + S256 challenge + 随机 state
2. `HttpServer.bind('127.0.0.1', 0)` 临时 loopback
3. 拼 auth URL(从 `GetOIDCConfig` 拿 provider 配置)
4. `url_launcher` 开系统浏览器
5. 捕 code + 验 state → 关 server → 返回 `(code, verifier)`
6. 交 `AuthRepository.oidcLogin` → `OIDCExchange`

依赖:`url_launcher` + `crypto`(已在)+ Dart `HttpServer`(内置)。Windows 无需 manifest 配置(loopback 不注册 scheme)。

### 8.2 DDD 四层改动

| 层 | 改动 |
|---|---|
| `domain/` | `AuthRepository` 接口:删 `register`/`login`,加 `oidcLogin(provider)`、`getOIDCConfig()`;`User` entity 不变 |
| `data/` | 新 `oidc_authenticator.dart`;`auth_remote_ds.dart` 删 register/login、加 OIDCExchange/GetOIDCConfig;`auth_repository_impl.dart` 对应改;`token_storage.dart` **不变** |
| `presentation/` | `auth_bloc`:删 Register/Login events,加 `OIDCLoginRequested(provider)`;登录页表单 → provider 按钮(从 `GetOIDCConfig` 渲染,首发一个 "使用 Google 登录") |
| `core/network/` | `auth_interceptor.dart` / `auth_retry.dart` **完全不变**(还是御财 JWT + 401 refresh) |

`router` 登录守卫不变(仍看 `token_storage` 有无御财 JWT),只是 token 来源从 password 换 OIDC。

### 8.3 redirect_uri 端口
loopback 端口每次随机(`bind(..., 0)`),`redirect_uri = http://localhost:{dynamic_port}/callback`。Google Console 需登记 `http://localhost`(对 loopback 任意端口支持)。

## 9. 配置与安全

### 9.1 Google Cloud Console(实现前手动)
- 创建 OAuth 2.0 Client ID(**Web application** 类型 —— 御财 server 是 confidential client,持 secret 交换 code)
- Authorized redirect URIs:登记 `http://localhost:PORT/callback`。Google 对 loopback redirect 端口宽松 —— client 运行时用动态端口(`bind(0)`),Google 仍接受(见 8.3)
- Scopes:`openid email profile`
- OAuth consent screen:配 app 名/图标(个人理财,可走"测试"模式,无需 full verification)

### 9.2 配置与密钥分离
```
config/oidc_providers.yaml   ← 非敏感(issuer, client_id, scopes, redirect_uri),可入库
OIDC_GOOGLE_CLIENT_SECRET    ← env 注入(跟现有 JWT_SECRET 一致),不进 yaml/不进 proto/不入 client
```
启动时 `ProviderRegistry` 合并 yaml + env。`GetOIDCConfig` 只输出 yaml 部分(剥 secret)。

### 9.3 flow 安全
- **PKCE**:`code_verifier`(client 生成)+ S256 challenge —— 防 code 拦截重放(**必须**)
- **state**:client 生成随机 state,auth URL 带,loopback 回来验证匹配 —— 防 CSRF(**必须**)
- **nonce**:defer

## 10. 数据迁移

御财当前 dev 环境(podman)、无 prod 部署。现有 user 无 OIDC identity,纯 OIDC 下无法登录。

**dev 策略**:
- ent auto-migrate(server 启动):加 `user_identities` 表、删 `users.password_hash`、改 index
- 清空旧 `users` / `tenants`(重新用 OIDC 注册,无数据损失风险 —— 个人 dev 数据)

**prod 迁移**:defer(御财无 prod;纯 OIDC 下老 password user 本就无 `sub` 可绑)

## 11. wire_gen.go 手改

依 memory `yucai-wire-handmaintained`,wire 工具链 tree-wide 坏,`wire_gen.go` 手改(镜像现有 provider 声明顺序,消费方在依赖方之后):
- **删**:password hash provider、register/login handler provider
- **加**:oidc `ProviderRegistry`、`IdentityRepository`、`OIDCExchange` handler provider

不跑 wire CLI。

## 12. 删除清单

**server 删**:
- `Register`/`Login`(proto + grpc handler + command + service method)
- `internal/auth/infrastructure/password/hash.go`(bcrypt)
- `user.password_hash` 字段、`(tenant_id, email)` index

**client 删**:
- `register`/`login`(repository method + remote_ds gRPC call + bloc event)
- 登录页 email/password 表单 widget
- 若有 register/login 相关 widget test,一并清理(不破坏 CLAUDE.md 记的 3 测/2 文件预存 fail 基线)

## 13. 测试策略

**核心原则**:测试**不依赖真实 Google**(不联网 IDP、不脆弱)。用本地 mock IDP。

### 13.1 server 测试(Go,`internal/auth/`)
- **test OIDC IDP mock**:用 `httptest` 起 server 模拟 IDP 的 `.well-known/openid-configuration` + token endpoint + JWKS;用 test RSA key 签发 id_token。coreos/go-oidc 支持自定义 issuer,可注入
- **OIDCExchange handler 单测**:
  - jit provisioning 路径(identity 未命中 → 建 user+tenant+identity → 发 token)
  - 已有 identity 路径(命中 → 取 user → 发 token,不重复建)
  - 错误路径:unknown provider / PKCE verifier 错 / id_token 验签失败 → 对应 gRPC code
- **集成测**(enttest SQLite):`IdentityRepository` CRUD + `(provider, subject)` unique 约束 + `FindByProviderSubject` join
- **GetOIDCConfig**:registry 输出剥 secret

### 13.2 client 测试(Flutter,mocktail)
- `auth_repository_impl.oidcLogin`:mock `AuthRemoteDataSource`(OIDCExchange 返 token)+ mock `OIDCAuthenticator`(返 code)→ 验证 token 存 storage
- `auth_bloc`:`OIDCLoginRequested(provider)` → loading/success/failure 状态流转
- 登录页 widget:从 `GetOIDCConfig` 渲染 provider 按钮(mock remote_ds)
- `oidc_authenticator`(loopback + url_launcher):标 **integration test**(platform channel mock 复杂,起 test HttpServer 模拟 redirect 捕获 code)

### 13.3 e2e
defer(完整 OIDC flow 需真实 IDP 或复杂 mock IDP 编排,首发靠单测覆盖;e2e 作 follow-up,参照现有 e2e 套件模式)。

## 14. Deferred 项(显式,独立后续 spec/任务)

| 项 | 何时做 | 依赖 |
|---|---|---|
| 家庭多用户 tenant(邀请/角色业务逻辑) | 独立 spec | 本 spec(identity 层)先行 |
| 账号链接(link/unlink IDP 到同 user) | 本 spec 后增量 | `UserIdentity` 表已预留 |
| `nonce` 防重放 | 增量 | PKCE+state 已足够 |
| prod 数据迁移 | 御财有 prod 时 | — |
| 完整 OIDC e2e 套件 | follow-up | mock IDP 编排 |
| 第 2+ provider(GitHub 等)实现 | 增量配置 | 架构已支持,加 yaml + Console client |

## 15. 实现顺序提示(供 writing-plans 参考)

建议分阶段(每阶段可独立验证):
1. **数据层**:`UserIdentity` schema + ent generate + repo;`User` schema 删字段/改 index;migration 验证
2. **server OIDC 基础**:go-oidc + oauth2 引入;provider 抽象 + registry + verifier + 配置加载(yaml/env)
3. **server API**:proto 改(删 Register/Login + 加 GetOIDCConfig/OIDCExchange)+ regen;OIDCExchange handler + jit provisioning;GetOIDCConfig handler;wire_gen.go 手改;删 password infra
4. **server 测试**:mock IDP + handler 单测 + 集成测
5. **client OIDC authenticator**:`oidc_authenticator.dart`(loopback + PKCE + url_launcher)+ integration test
6. **client API/domain**:`AuthRepository`/remote_ds 改;auth_bloc 改;登录页改;清理 register/login widget + test
7. **联调**:Google Console 配置;手动 dev 端到端验证
