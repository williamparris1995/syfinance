# Flutter Client — Foundation + Auth Module Design Spec

> Date: 2026-06-13
> Status: Approved
> Scope: Flutter client foundation (DI, router, theme, gRPC client, error handling) + Auth feature end-to-end
> Prerequisite: [Architecture Redesign Spec](./2026-06-09-architecture-redesign-design.md) (section 7), running Go gRPC server (Plan 01–08)

## 1. Overview

Build the first deliverable of the YuCai (御财) Flutter client: the core application foundation plus the Auth feature module, connecting to the already-implemented Go gRPC backend.

This spec deliberately scopes a **minimal closed loop** — a user can register, log in, have their token persist across restarts, and land on an authenticated placeholder shell. It establishes the architecture pattern that all subsequent feature modules (Account, Transaction, etc.) will follow.

**Strategy: Online-first.** The first version uses gRPC remote calls only. No Drift local database, no offline queue, no sync engine. This validates the end-to-end gRPC connection, Bloc architecture, and page flow before adding offline complexity (deferred to a later spec).

## 2. Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Offline strategy | Online-first (no Drift) | Validate gRPC + architecture first; offline deferred |
| Feature scope | Foundation + Auth only | Minimal closed loop, establishes pattern |
| State management | flutter_bloc | Matches spec section 7.3 (CQRS mapping) |
| Routing | go_router with redirect guard | Idiomatic, deep-link safe, declarative auth guard |
| DI | get_it + injectable (codegen) | Matches spec; compile-time, less boilerplate |
| Error handling | dartz `Either<Failure, T>` | Functional, explicit failure channel |
| Token storage | flutter_secure_storage | OS keychain/keystore, standard |
| Platform target | Windows desktop primary (dev), responsive shell scaffolded | Dev env is Windows; shell ready for mobile later |
| UI language | Chinese-first (hardcoded) | 御财 app; i18n framework deferred |
| Theme | Material 3, blue seed `0xFF1E40AF` | Keeps existing scaffold seed |
| Proto stubs | buf generate (dart plugin) → `client/lib/proto` | Config already exists (`buf.gen.dart.yaml`) |

## 3. Architecture Layers

4-layer architecture per spec section 7.1. Dependency direction is one-way downward.

| Layer | Responsibility | Depends on |
|-------|----------------|------------|
| `domain/` | Pure Dart — entities, value objects, repository interfaces, use cases | Nothing external |
| `data/` | Repository impl (gRPC remote DS), token storage, mappers | domain/ + grpc/proto |
| `presentation/bloc/` | Event → State mapping, calls use cases | domain/ |
| `presentation/pages/` | Widgets, BlocBuilder/Listener subscriptions | bloc/ |

`core/` holds cross-cutting concerns (config, theme, network, error, DI) that are not feature-specific.

## 4. File Structure

```
client/lib/
├── main.dart                          # ensureInitialized → DI → runApp
├── app/
│   ├── app.dart                       # MaterialApp.router(root)
│   └── router.dart                    # GoRouter + auth redirect guard
├── core/
│   ├── config/
│   │   └── app_config.dart            # host/port/useTls via --dart-define
│   ├── theme/
│   │   └── app_theme.dart             # Material 3, blue seed, CN fonts
│   ├── network/
│   │   ├── grpc_client.dart           # ClientChannel singleton
│   │   └── auth_interceptor.dart      # Bearer inject + refresh-on-401
│   ├── error/
│   │   └── failures.dart              # Failure sealed class
│   └── di/
│       ├── injection.dart             # get_it + injectable bootstrap
│       └── injection.config.dart      # generated
└── auth/
    ├── domain/
    │   ├── entities/
    │   │   ├── user_entity.dart
    │   │   └── auth_tokens.dart       # access + refresh VO
    │   ├── repositories/
    │   │   └── auth_repository.dart   # abstract
    │   └── usecases/
    │       ├── register_usecase.dart
    │       ├── login_usecase.dart
    │       ├── refresh_token_usecase.dart
    │       ├── get_profile_usecase.dart
    │       └── logout_usecase.dart
    ├── data/
    │   ├── auth_repository_impl.dart  # remote-only
    │   ├── auth_remote_ds.dart        # AuthServiceClient wrapper
    │   ├── token_storage.dart         # flutter_secure_storage
    │   └── mappers/
    │       └── user_mapper.dart       # proto UserDTO ↔ domain User
    ├── presentation/
    │   ├── bloc/
    │   │   ├── auth_bloc.dart
    │   │   ├── auth_event.dart
    │   │   └── auth_state.dart
    │   └── pages/
    │       ├── login_page.dart
    │       ├── register_page.dart
    │       └── home_page.dart         # responsive shell placeholder
    └── auth.dart                      # barrel export
```

## 5. gRPC Client + Auth Interceptor

### 5.1 GrpcClient

`grpc_client.dart` creates a `ClientChannel` to the server using `AppConfig` (host/port/useTls). Registered as a singleton in DI. The `AuthInterceptor` is attached at the channel level so **all** generated service clients share it automatically.

### 5.2 AuthInterceptor

A `ClientInterceptor` subclass providing transparent auth:

**Outbound (metadata injection):**
- For every call, read access token from `TokenStorage`
- Inject `authorization: Bearer <token>` metadata
- **Skip** injection for `AuthService.Register`, `AuthService.Login`, and `AuthService.RefreshToken` (these carry credentials in the request body, not the header; Register/Login have no token yet, RefreshToken carries `refresh_token` in its request)

**Inbound (401 handling):**
- On `Unauthenticated` (gRPC code 16) response:
  1. If the failing call was itself `RefreshToken` → do NOT attempt another refresh; throw `AuthFailure` immediately (prevents refresh loop)
  2. Acquire a refresh mutex (Completer-guarded) — if another call is mid-refresh, await the same future (prevents refresh storm)
  3. Call `RefreshToken` with stored refresh token
  4. Store new access + refresh tokens in `TokenStorage`
  5. **Retry the original call once** with the new token
  6. If refresh fails → throw `AuthFailure`, which surfaces as a `TokenRefreshFailed` event to `AuthBloc` → logout + redirect to login
- **Loop guard:** each non-refresh call retries at most once. A metadata flag tracks "already retried" to prevent infinite retry loops.

### 5.3 Dependency boundary

The interceptor depends on `TokenStorage` (abstract interface, backed by flutter_secure_storage in data layer). It does **not** depend on Blocs — it signals failure by throwing `AuthFailure`. The presentation layer handles refresh-failure by dispatching `LogoutRequested`.

## 6. Dependency Injection

**get_it + injectable:**
- `@injectable` / `@LazySingleton` annotations on repos, data sources, use cases
- `injection.dart` calls generated `configureDependencies()`
- Registrations:
  - `GrpcClient`, `TokenStorage`, `AuthRemoteDataSource` → singletons
  - `AuthRepositoryImpl` bound to abstract `AuthRepository` (via `@Injectable(as: AuthRepository)`)
  - Use cases → factories (stateless, cheap)
  - `AuthBloc` → registered manually (not injectable — needs `close()` lifecycle)

## 7. Auth Feature

### 7.1 Domain

**Entity: User** — `id`, `tenantId`, `email`, `displayName`, `avatarUrl`, `createdAt` (DateTime)

**Value Object: AuthTokens** — `accessToken`, `refreshToken` (both non-empty strings). Immutable.

**Repository interface: AuthRepository**
```dart
abstract class AuthRepository {
  Future<Either<Failure, User>> register(String email, String password, String displayName);
  Future<Either<Failure, User>> login(String email, String password);
  Future<Either<Failure, AuthTokens>> refreshToken();
  Future<Either<Failure, User>> getProfile();
  Future<void> logout();
}
```

**Use cases** — 5 classes, each wrapping one repo call: `RegisterUseCase`, `LoginUseCase`, `RefreshTokenUseCase`, `GetProfileUseCase`, `LogoutUseCase`. Thin wrappers that delegate to the repo.

### 7.2 Data

- **AuthRemoteDataSource** — wraps generated `AuthServiceClient`. Methods map 1:1 to RPCs. Throws gRPC exceptions on failure (caught + mapped by repository).
- **TokenStorage** — `flutter_secure_storage` with keys `_a` (access) + `_r` (refresh). Methods: `readTokens()`, `saveTokens(tokens)`, `clearTokens()`.
- **UserMapper** — `protoToDomain(UserDTO) → User`, `createdAt` parsed from ISO string.
- **AuthRepositoryImpl** — calls remote DS, catches gRPC `GrpcError`, maps code → `Failure` subclass, stores/clears tokens on auth events.

### 7.3 Presentation (Bloc)

**AuthBloc** events:
- `AppStarted` — read tokens from storage; if present, call `GetProfileUseCase` to validate → `Authenticated(user)` or clear + `Unauthenticated`
- `LoginRequested(email, password)`
- `RegisterRequested(email, password, displayName)`
- `LogoutRequested`
- `TokenRefreshFailed` — dispatched when interceptor signals refresh failure

**AuthBloc** states:
- `AuthInitial`
- `AuthLoading`
- `Authenticated(User)`
- `Unauthenticated`
- `AuthError(String message)`

### 7.4 Pages

- **LoginPage** — email/password fields, login button, "注册" link → push `/register`. Shows `AuthError` as a SnackBar (Chinese message). Form validation (non-empty, email format).
- **RegisterPage** — email/password/displayName fields, register button, "已有账号？登录" link → pop to login.
- **HomePage** — responsive shell placeholder. `LayoutBuilder`: >900px → sidebar (logo, user name, 退出登录 button) + content ("功能开发中" placeholder); else → bottom nav scaffold with same content. Shows logged-in user's displayName.

All user-visible text is Chinese.

## 8. Routing + Auth Guard

**go_router config (`router.dart`):**
- Routes: `/login`, `/register`, `/home`
- `redirect` callback receives current `AuthBloc.state`:
  - Going to `/home` but NOT `Authenticated` → redirect `/login`
  - Going to `/login` or `/register` but `Authenticated` → redirect `/home`
  - Otherwise: allow
- `main.dart` subscribes to auth state stream and calls `router.refresh()` on change so the redirect re-evaluates.

## 9. Theme + App Shell

- **AppTheme**: Material 3, `ColorScheme.fromSeed(seedColor: Color(0xFF1E40AF))`, Chinese font fallback (system default for v1), `visualDensity: visualDensityStandard`.
- **HomePage shell**: responsive scaffold (section 7.4). Desktop sidebar / mobile bottom nav — content is a placeholder for now.

## 10. Configuration

**AppConfig** — `serverHost` (default `localhost`), `serverPort` (default `9090`), `useTls` (default `false`). Injected via `--dart-define` for dev/prod switching:
```
flutter run --dart-define=SERVER_HOST=localhost --dart-define=SERVER_PORT=9090
```

## 11. Error Handling

**failures.dart** — sealed class hierarchy:
- `ServerFailure(message)` — gRPC error from server
- `NetworkFailure(message)` — unreachable / timeout
- `AuthFailure(message)` — token invalid / refresh failed
- `ValidationFailure(message)` — bad input
- `UnexpectedFailure(message)` — catch-all

All repository methods return `Future<Either<Failure, T>>`. UI maps `AuthError` state → Chinese SnackBar message.

## 12. Testing

| Level | Scope | Tool |
|-------|-------|------|
| Unit | Use cases (mock repo via mocktail) | flutter_test + mocktail |
| Bloc | AuthBloc event → state | bloc_test + mocktail |
| Mapper | UserMapper proto ↔ domain round-trip | flutter_test |

Integration tests requiring a running server are explicitly deferred (future work). No data-source tests that hit real gRPC.

## 13. Out of Scope (Deferred)

These are explicitly excluded from this deliverable to keep it a minimal closed loop:

- **Drift local DB / offline-first / sync engine** — confirmed online-first for v1
- **All non-Auth features** (Account, Transaction, etc.) — follow in subsequent specs
- **i18n framework** (intl) — hardcoded Chinese for v1
- **Real responsive content** — only the shell scaffold exists; no feature content
- **CI / platform build pipelines** — manual `flutter run` for dev
- **Avatar upload, OAuth login** — email/password only
- **Server-side integration tests** — require running Postgres + Redis

## 14. Success Criteria

The deliverable is complete when:
1. `flutter run -d windows` launches the app against a local gRPC server
2. A new user can register → auto-login → land on HomePage showing their displayName
3. Existing user can login → HomePage
4. Token persists across app restart (AppStarted restores session via getProfile)
5. 401 on a protected call triggers transparent refresh + retry
6. Refresh failure → logout → redirect to login
7. Logout clears tokens → redirect to login
8. All unit + bloc tests pass (`flutter test`)
