---
feature: 2026-08-20-auth-offline-fork
status: drafted
---

# Design — 启动鉴权分流 + 游客模式

> 消费 [spec.md](spec.md)(confirmed)。现状事实:`auth_state.dart` 5 态(Initial/Loading/Authenticated/Unauthenticated/Error);`_onAppStarted` fold `_` 一刀切;守卫 `isLoggedIn = auth is Authenticated`,`!isLoggedIn && goingProtected → /login`;登出/TokenRefreshFailed → Unauthenticated。

## Context

R6 offline-first 的鉴权地基:断网不踢人、无账号可用(单机可分发的第一面)、绑/不绑自由切换的状态机。游客数据可用性归 feature C。

## Goals / NonGoals

- **Goals**:AuthBloc 三分支分流 + Guest 态 + 守卫重定义 + 登录双向入口 + 登出转 Guest + connectivity 网关。
- **NonGoals**:双源 seam/游客数据(C)/绑定上传(G)/登出镜像数据(H)/离线数据降级 UI(C/F)。

## Decisions(ADRs)

### ADR-1 状态机:新增 `Guest` 与 `OfflineAuthenticated` 两个显式状态
- **Decision**:`AuthState` 增加 `Guest`(无凭据/登出/跳过)与 `OfflineAuthenticated`(有 token 但 GetProfile 网络失败,无 User 对象)。
- **Rationale**:离线时拿不到 Profile——可空 User(`Authenticated(this.user?)`)会迫使所有消费方 `auth.user!`,类型弱化;显式状态让 router/UI 按态分流,无假对象。
- **Alternatives**:①`Authenticated` 带 nullable user——全消费方判空,reject;②复用 `Unauthenticated`+标志位——语义混乱(未登录≠游客≠离线会话)。

### ADR-2 AppStarted 分流:token 预检先行,三分支决策
- **Decision**:AppStarted 先查本地凭据(`HasStoredCredentialsUseCase`,包装 TokenStorage):无凭据 → 直接 `Guest`(不发 GetProfile,省一次注定失败的 RPC);有凭据 → GetProfile:成功 → `Authenticated`;NetworkFailure → `OfflineAuthenticated`;AuthFailure → `Unauthenticated`(现状)。
- **Rationale**:token 预检同时解决「无 token 白跑 RPC」与「NetworkFailure 时区分游客/离线会话」两个问题;失败类型已可区分(`_mapGrpcError` 有 NetworkFailure)。
- **Alternatives**:①全靠 GetProfile 失败类型——无 token 离线时 NetworkFailure 会误判为"离线会话",reject;②token 检查放 repo 层——跨层泄漏, bloc 拿不到决策信息。

### ADR-3 守卫反转:从「未登录拦业务」到「未登录拦绑定专属」
- **Decision**:redirect 重写——`hasSession = Authenticated || OfflineAuthenticated`;规则仅两条:`!hasSession && goingBindOnly → /login`、`hasSession && goingToAuth → /home`;Guest 可达全部业务路由(含 /settings)也可达 /login(登录入口)。绑定专属路由清单从「云备份设置」起步(现无独立路由则清单暂空、机制就位,云端入口路由化时入列)。
- **Rationale**:spec FR-2 的行为反转最小实现;清单机制让后续绑定专属页(云备份/同步状态)零成本入列。
- **Alternatives**:每路由 meta 标注——go_router 无原生 meta,过度设计。

### ADR-4 登出/刷新失败 → Guest;登录页双向入口
- **Decision**:LogoutRequested 与 TokenRefreshFailed 均 → `Guest`(不再 Unauthenticated——forced logout 与主动登出同语义,FR-4)。LoginPage 增加「先不登录,离线使用」(→ `SkipLoginRequested` → Guest);Settings 页在 Guest 态显示「登录」入口(→ /login)。
- **Rationale**:「绑/不绑自由选择」闭环;NFR-1 的零回归以业务数据路径为准,踢登录页行为的变化是 FR-4 的有意变更(用户留在 app 内)。
- **Alternatives**:TokenRefreshFailed 保留踢登录(与 FR-4 矛盾)——reject。

### ADR-5 ConnectivityGateway:core 共享网关服务
- **Decision**:新增 `core/connectivity/connectivity_gateway.dart`——`Stream<bool> get online`(distinct)+ `bool get current`,包装 connectivity_plus;injection.dart 手动注册 singleton(对齐 core infra 惯例);B 只交付状态流,UI 离线徽标 defer(C/F 的 UX)。
- **Rationale**:死依赖转用 + seam/UI 统一消费点;单实例共享事件流。
- **Alternatives**:各处直接用 connectivity_plus——散落依赖,难测(reject)。

## HLD

```
改动面(全部 client,零 server):
auth/presentation/bloc/auth_state.dart     +Guest +OfflineAuthenticated
auth/presentation/bloc/auth_event.dart     +SkipLoginRequested
auth/presentation/bloc/auth_bloc.dart      AppStarted 预检+三分支;Skip→Guest;Logout/RefreshFail→Guest
auth/domain/usecases/has_stored_credentials_usecase.dart  新增(包 TokenStorage.readTokens != null)
app/router.dart                            redirect 重写(ADR-3)
auth/presentation/pages/login_page.dart    +「先不登录,离线使用」
settings 页(presentation)                  Guest 态「登录」入口
core/connectivity/connectivity_gateway.dart 新增 + injection.dart 注册
```

依赖方向不变:bloc → usecase → (data) TokenStorage;router 消费 AuthBloc 状态;gateway 被消费(本 feature 内仅测试消费)。

## LLD

### 状态转移表

| 事件 | 前置 | 新态 |
|---|---|---|
| AppStarted | 无本地凭据 | Guest(不发 RPC) |
| AppStarted | 有凭据 + GetProfile 成功 | Authenticated(user) |
| AppStarted | 有凭据 + NetworkFailure | OfflineAuthenticated |
| AppStarted | 有凭据 + AuthFailure | Unauthenticated(→/login) |
| SkipLoginRequested | 任意(登录页) | Guest |
| OIDCLoginRequested | 成功 / 失败 | Authenticated / AuthError(现状) |
| LogoutRequested | 任意 | Guest |
| TokenRefreshFailed | 任意 | Guest |

### redirect 伪码

```
if (loading) return null;
hasSession = state is Authenticated || state is OfflineAuthenticated
goingBindOnly = 前缀匹配 bindOnlyPrefixes(初始:[] 机制就位,云备份路由化时入列)
if (!hasSession && goingBindOnly) return '/login';
if (hasSession && goingToAuth) return '/home';
return null;   // Guest 可达业务路由与 /login
```

### ConnectivityGateway 契约

```dart
class ConnectivityGateway {
  Stream<bool> get online;    // distinct,初值后随事件;none→false 其余→true
  bool get current;
}
```
构造注入 `Connectivity()`(可测:传 fake Stream);`onStatusChanged` 映射 none/offline→false, wifi/ethernet/…→true。

### 测试计划

- `auth_bloc_test`:表驱动覆盖转移表 8 行(注入 fake usecases/TokenStorage seam)。
- `router_guard_test`:Guest→业务路由放行 / Guest→/login 放行 / hasSession→/login 重定向 / bindOnly 机制(注入伪路由)。
- `connectivity_gateway_test`:fake 状态流 → distinct 布尔流 + current。
- 回归:现有 auth/login 相关测试改期望登出→Guest 等,全套基线内。

## Risks

- **R1 Guest 业务页数据错误/空态窗口期**(spec accepted 张力)——B→C 同 sprint 相邻交付。
- **R2 OfflineAuthenticated 下云端操作 RPC 报网络错误**——走现状错误文案体系,可接受(改善归 C/F)。
- **R3 TokenRefreshFailed→Guest 改变在线失效路径**——有意变更(ADR-4),auth 相关既有测试需同步期望。

## Migration

纯 client 行为变更,无数据/schema 迁移;既有 auth 测试期望更新即「迁移」。

## Open Questions

1. Settings 页「登录」入口的具体摆放(Guest 态可见性)——execute 时按现有 settings 结构最小侵入放置。
2. 离线徽标 UI(defer C/F,见 ADR-5)。
