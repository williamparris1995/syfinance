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

## Task 35 Decomposition (Deferred to Post-Verification)

**Reason for deferral**: Task 35 timed out after 30 minutes. Decomposed into 3 sub-tasks to be executed after Final Verification Wave (F1-F4).

### Task 35.1: Currency Conversion Utilities (15 min)
- Create `src/lib/currency.ts`
- Implement `convertMoney(amount, fromCurrency, toCurrency, rates): number | null`
- Implement `getMissingRates(currencies, targetCurrency, rates): string[]`
- Implement `formatCurrency(amount, currencyCode): string`
- Write vitest unit tests
- Conversion formula: `amount * (targetRate / sourceRate)`

### Task 35.2: Balance Sheet Multi-Currency Support (20 min)
- Add currency selector (Select component) in ReportsPage
- Fetch currency list via `useQuery` + `listCurrencies()`
- Modify `balanceSheetData` calculation to use `convertMoney()`
- Add missing rate warning (Alert component)
- Add "Rates as of [timestamp]" disclaimer

### Task 35.3: Income Statement Multi-Currency Support (15 min)
- Modify `incomeStatementData` calculation with currency conversion
- Add Tooltip showing original currency on hover
- Update CSV export to include currency info
- Playwright screenshot verification

**Total estimated time**: 50 minutes (vs 30+ min timeout for monolithic task)
