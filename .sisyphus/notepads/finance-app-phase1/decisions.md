# Architectural Decisions - Finance App Phase 1

## Technology Stack
- Frontend: Tauri 2.x + React 18 + TypeScript + TanStack Query/Router + shadcn/ui + Tailwind CSS
- Backend: Rust + Axum + sqlx + PostgreSQL
- Local Storage: SQLite (offline-first)
- Architecture: DDD (Domain → Application → Infrastructure → Presentation)
- Testing: cargo test + vitest (simplified testing strategy)

## Key Design Decisions
- Multi-currency support with manual exchange rate input
- Chinese Accounting Standards (中国会计准则) for chart of accounts
- Double-entry bookkeeping with domain-level validation
- Last Write Wins conflict resolution for sync
- Soft deletes with tombstone strategy
- rust_decimal for all monetary calculations (no f64)
