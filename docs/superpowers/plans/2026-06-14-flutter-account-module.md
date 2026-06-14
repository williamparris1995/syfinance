# Flutter Client — Account Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Account feature module to the Flutter client — list + create + delete accounts, connecting to the existing Go `AccountService`. Replaces the HomePage placeholder with a real account list.

**Architecture:** Identical 4-layer pattern as the Auth module (domain → data → bloc → presentation). Reuses all foundation: Failure/Either, GrpcClient, AuthInterceptor (auto Bearer), AuthRetryCaller (auto 401 refresh), get_it+injectable, go_router. Money in int64 cents (no float).

**Tech Stack:** Flutter 3.44 / Dart 3.12, flutter_bloc, grpc 5, injectable, dartz.

**Working directory for all `flutter`/`dart` commands:** `yucai/client/`

**Proto contract:** `proto/account/v1/account.proto` — `AccountService{CreateAccount, GetAccount, ListAccounts, UpdateAccount, DeleteAccount}`, enums `AccountType`(6)/`Ownership`(2)/`AccountStatus`(2), `AccountDTO`(17 fields incl. current_balance_cents).

**Scope:** List + Create + Delete only. Get/Update/Archive/history deferred.

---

## File Structure

```
client/lib/account/
├── domain/
│   ├── entities/account_entity.dart
│   ├── value_objects.dart                     # AccountType, Ownership, AccountStatus
│   ├── repositories/account_repository.dart
│   └── usecases/
│       ├── list_accounts_usecase.dart
│       ├── create_account_usecase.dart
│       └── delete_account_usecase.dart
├── data/
│   ├── account_repository_impl.dart
│   ├── account_remote_ds.dart                 # AccountServiceClient + AuthRetryCaller
│   ├── mappers/account_mapper.dart
│   └── account_params.dart                    # CreateAccountParams
└── presentation/
    ├── bloc/
    │   ├── account_bloc.dart
    │   ├── account_event.dart
    │   └── account_state.dart
    └── pages/
        ├── accounts_page.dart
        └── account_form_page.dart
```

Modified: `lib/app/router.dart` (add `/accounts` route), `lib/auth/presentation/pages/home_page.dart` (wire account nav into shell), `lib/core/di/injection.dart` (no manual reg needed — all @injectable).

---

## Task A1: Generate Account Dart proto + gRPC stubs

- [ ] Step 1: Generate stubs (from `yucai/proto`): `protoc --dart_out=grpc:../client/lib/proto -I. account/v1/account.proto` (with `protoc-gen-dart` on PATH from `dart pub global activate protoc_plugin`).
- [ ] Step 2: Verify `client/lib/proto/account/v1/account.pbgrpc.dart` exists (contains `AccountServiceClient`).
- [ ] Step 3: Commit.

## Task A2: Domain — Account entity + enums + repository interface

- [ ] Write `account/domain/value_objects.dart` — `AccountType`, `Ownership`, `AccountStatus` enums with `String()` + `parse()` + proto-mapping helpers.
- [ ] Write `account/domain/entities/account_entity.dart` — `Account` Equatable class (id, name, accountType, currencyCode, initialBalanceCents, currentBalanceCents, ownership, icon, color, status, version, createdAt).
- [ ] Write `account/domain/repositories/account_repository.dart` — abstract: `list`, `create`, `delete` returning `Either<Failure, T>`.
- [ ] Write `account/domain/value_objects_test.dart` — enum round-trips.
- [ ] Run test, commit.

## Task A3: Data — mapper + remote DS + repository impl

- [ ] Write `account/data/mappers/account_mapper.dart` — `AccountMapper.toDomain(AccountDTO)`.
- [ ] Write `account/data/account_params.dart` — `CreateAccountParams`.
- [ ] Write `account/data/account_remote_ds.dart` — `@LazySingleton`, wraps `AccountServiceClient` (channel + AuthInterceptor). `list`/`create`/`delete` methods. Wrap `list`/`create` in `AuthRetryCaller` (protected calls → auto-refresh on expired token).
- [ ] Write `account/data/account_repository_impl.dart` — `@LazySingleton(as: AccountRepository)`, catches GrpcError → Failure, delegates to remote DS.
- [ ] Write `account/data/mappers/account_mapper_test.dart` + `account_repository_impl_test.dart`.
- [ ] Run tests, commit.

## Task A4: Domain — use cases

- [ ] Write `list_accounts_usecase.dart`, `create_account_usecase.dart`, `delete_account_usecase.dart` — thin wrappers, `@injectable`.
- [ ] Write `usecases_test.dart` (mock repo).
- [ ] Run, commit.

## Task A5: Presentation — AccountBloc

- [ ] Write `account_event.dart` — `LoadAccountsRequested`, `CreateAccountRequested(params)`, `DeleteAccountRequested(id)`.
- [ ] Write `account_state.dart` — `AccountInitial/Loading/Loaded(accounts)/Error(msg)/FormSubmitting`.
- [ ] Write `account_bloc.dart` — `@injectable`, handles the 3 events; Create/Delete re-trigger Load on success.
- [ ] Write `account_bloc_test.dart` (bloc_test, mock use cases).
- [ ] Run, commit.

## Task A6: DI + build_runner

- [ ] Run `dart run build_runner build --delete-conflicting-outputs` (resolves AccountRemoteDataSource, AccountRepositoryImpl, use cases, AccountBloc via constructor injection).
- [ ] Verify `flutter analyze lib/` clean.

## Task A7: Presentation — AccountsPage + AccountFormPage

- [ ] Write `account_form_page.dart` — form: name, type dropdown (6 types), currency (default CNY), initial balance, ownership. Validation. On submit → `CreateAccountRequested`.
- [ ] Write `accounts_page.dart` — `BlocBuilder<AccountBloc>`: list of cards (name + type badge + balance). FAB → push form. Long-press / swipe → delete with confirm. Pull-to-refresh → LoadAccountsRequested. Empty state.
- [ ] All UI Chinese.
- [ ] Commit.

## Task A8: Routing + HomePage integration

- [ ] `router.dart`: add `/accounts` route → `AccountsPage`, guarded (auth).
- [ ] `home_page.dart`: replace "功能开发中" placeholder with a link/button to accounts; provide `BlocProvider<AccountBloc>` (or use the authenticated state). Sidebar entry "账户".
- [ ] Commit.

## Task A9: Verification

- [ ] `flutter analyze` — 0 errors.
- [ ] `flutter test` — all pass (existing 41 + new account tests).
- [ ] `flutter build windows --debug` — succeeds.
- [ ] Commit.

## Self-Review

| Spec | Task |
|---|---|
| List accounts | A3 (remote DS list), A5 (Load event), A7 (page) |
| Create account | A3 (create), A5 (Create event), A7 (form) |
| Delete account | A3 (delete), A5 (Delete event), A7 (confirm) |
| Auto token refresh on account calls | A3 (AuthRetryCaller on list/create) |
| Multi-tenancy (token carries tenant) | AuthInterceptor injects Bearer; server scopes by tenant |
| Money int64 cents | A2 (entity cents), A7 (format) |
