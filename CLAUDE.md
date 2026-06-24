# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal finance desktop app (double-entry bookkeeping, Chinese accounting standards) built with **Tauri 2.x** (Rust backend + React frontend). Offline-first with local SQLite storage. Package manager: **pnpm**.

## Commands

### Frontend
- `pnpm dev` — Vite dev server (port 5173)
- `pnpm build` — Production build to `dist/`
- `pnpm type-check` — TypeScript check (`tsc --noEmit`)
- `pnpm lint` / `pnpm lint:fix` — ESLint on `src/`
- `npx vitest run` — Run frontend tests (single test: `npx vitest run path/to/test`)
- `pnpm vitest` — Watch mode

### Backend (Rust)
- `make check` — Format + clippy + custom quality checks (run before committing)
- `make test` — `cargo test` (single test: `cd src-tauri && cargo test test_name`)
- `make build` — `cargo build`
- `make fix` — Auto-fix with `cargo fmt` + `cargo clippy --fix`
- `make ci` — Full CI: check + test + build

### Full Validation
- `pnpm validate` — Runs **everything**: type-check + lint + cargo fmt + cargo clippy + python quality validators. Use this as the single pre-push check.

### Full app
- `pnpm tauri dev` — Run Tauri in development mode (launches both Vite and Rust)
- `pnpm tauri build` — Production build (MSI installer in `src-tauri/target/release/bundle/`)

## Architecture

### Rust Backend (src-tauri/) — Domain-Driven Design

```
src/
  domain/          # Aggregates, Value Objects, Repository traits
    aggregates/    # Account, Transaction, Debt, Budget, Goal, Tag, Holding, TransactionTemplate, Reminder
    repositories/  # Trait definitions (AccountRepository, TransactionRepository, etc.)
    value_objects/ # Money, Currency, TransactionEntry, VersionVector, BudgetItem, etc.
  application/     # Business logic services + DTOs
  infrastructure/  # SQLite repos, encryption, notifications, reminders, sync, backup
  presentation/
    api/           # Axum REST routes (sync endpoints, port 3000)
    tauri_commands/# Tauri IPC handlers (primary frontend↔backend channel)
```

Frontend communicates with Rust primarily through **Tauri IPC** (`invoke()` calls). Axum REST API on port 3000 handles device registration and sync operations.

### React Frontend (src/)

- **Routing**: TanStack Router (file-based) with auth guard — unregistered devices redirect to `/onboarding`
- **Data fetching**: TanStack React Query (5min stale time, 30min GC)
- **Forms**: react-hook-form + Zod validation
- **UI**: shadcn/ui (base-nova) + Radix primitives + Tailwind CSS
- **i18n**: i18next (English + Chinese), ESLint enforces `i18next/no-literal-string` — all user-visible text must use `t()`. Exempt paths: `src/components/ui/**` (shadcn) and test files.
- **State**: No global client store. Server state via React Query, auth via Tauri Store plugin

### Key Patterns

- **Path alias**: `@/*` maps to `./src/*` in both TS and Vite
- **Tauri IPC wrapper**: `src/lib/tauri.ts` provides `invokeTauri()` with type-safe command wrappers in `src/lib/tauri/` (20 domain modules; only `account` and `prepaid` re-exported from index — others imported directly)
- **Database**: SQLite via SQLx with migrations in `src-tauri/migrations/` (dated SQL files, e.g. `20260407_initial_schema.sql`). Foreign keys enabled on production pool, disabled during migrations. Monetary amounts stored as INTEGER cents.
- **Soft delete**: `deleted_at` timestamp (tombstone pattern)
- **Background schedulers**: Sync, reminders, prepaid alerts — all run as Tokio tasks every 5 min
- **Encryption**: AES-GCM + PBKDF2 + OS keychain for sensitive data
- **Full-text search**: SQLite FTS5 indexes for accounts, transactions, debts, goals, tags — rebuilt on startup
- **Cloud backup**: WebDAV, Dropbox, Google Drive, OneDrive providers (in `infrastructure/backup/`)

## Rust Coding Standards (Mandatory)

See `docs/CODING_STANDARDS.md` for full details. Violations fail CI.

1. **Use ORM** — no hardcoded SQL field names in queries (note: project uses SQLx directly, not SeaORM; `docs/CODING_STANDARDS.md` references SeaORM but the codebase uses `sqlx::query_as!`)
2. **Use `tracing`** — `println!` is banned (enforced by clippy.toml)
3. **Use `serde`** for enums — no hardcoded string matching
4. **Log errors with context** — always include operation name and error details
5. **Max 5 function arguments** (enforced by clippy.toml)

Validate: `make check` or `python3 scripts/validate_code_quality.py`

## Testing

- **Frontend**: Vitest + jsdom + Testing Library. Setup (`vitest.setup.ts`) mocks `react-i18next` with real `en.json` translations and mocks `window.matchMedia`. Tests in `src/__tests__/`, `src/components/__tests__/`, `src/hooks/__tests__/`, `src/pages/__tests__/`.
- **Backend**: Rust integration tests in `src-tauri/tests/` (14 test files). Uses proptest for property-based testing.

## i18n

- Locales: `src/i18n/locales/en.json` and `zh.json`
- ESLint rule `i18next/no-literal-string` means **no raw English/Chinese strings in JSX** — always use `t('key')`
- When adding UI text, add keys to both locale files

## Database

- Location: `%APPDATA%/finance-app/finance.db` (Windows)
- Logs: `%APPDATA%/finance-app/logs/` (daily rolling files via `tracing_appender`)
- Migrations run automatically on first launch
- Add new migrations as dated SQL files in `src-tauri/migrations/` (format: `YYYYMMDD_description.sql`)

## Incomplete Features (as of Phase 1)

- PostgreSQL sync (repos exist but not wired up)
- Notification delivery (scheduling works, delivery incomplete)
- See `LIMITATIONS.md` for full list

## AI Generation Constraints

Three rules enforced by validation tooling (`make check-quality`) and ESLint.

### 1. Modular Design, Reuse First (SHOULD)

Before creating new modules, check existing ones for reuse:
- Frontend: `src/lib/tauri/`, `src/components/ui/`, `src/hooks/`
- Backend: `src-tauri/src/application/services/`, `src-tauri/src/domain/`
- Follow DDD layer boundaries (domain -> application -> infrastructure -> presentation)

### 2. English Structured Logs (SHOULD)

All log output must use English structured format. CJK characters in log statements are flagged by `log_validator.py`.

Rust:
```rust
info!(account_id = %id, "Creating account");
error!(operation = "delete_transaction", error = %e, "Failed to delete");
```

TypeScript:
```typescript
console.error("[AccountService] Failed to create account", error);
```

### 3. i18n for UI, const for Non-UI (FORBIDDEN to hardcode in UI)

- **User-visible JSX text**: Must use `t('key')` -- no hardcoded strings (enforced by ESLint `i18next/no-literal-string` + `const_validator.py`)
- **Non-display constants**: `const STATUS = "active"` is acceptable for error codes, config values, API paths
- **Avoid circular references**: const strings must not create reference loops with i18n keys

Validation: `pnpm lint` (ESLint) + `make check-quality` (Python validators)
## System Architecture
- This project leverages the Open Design system connected via the `open-design` MCP server.
- Locally managed assets are stored in `./design-output/`.

## Reusable Workflow Skills
When triggered by specific instructions, execute these precise steps:

### Skill: /generate-ui [brief]
1. Read the user's layout requirement from the [brief].
2. Invoke the `open-design` MCP tool to create a new design context.
3. Generate the UI components inside the design canvas using Tailwind CSS / React standards.
4. Output the compiled artifacts into the local workspace.

### Skill: /export-ppt [topic]
1. Fetch design themes from `DESIGN.md`.
2. Call the Open Design daemon to compile slide layouts.
3. Save the resulting file as a `.pptx` in the project root.
