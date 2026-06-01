# Gap Analysis Design — Finance App vs Industry Leaders

**Date:** 2026-06-01
**Status:** Approved
**Scope:** All 19 feature modules, 4 evaluation dimensions, 3 reference products

## Objective

Systematically compare every feature module of this Tauri finance app against three industry-leading products (随手记, MoneyWiz, YNAB) across four dimensions. Produce a detailed report with browser-based visualizations and a prioritized action plan for improvement.

## Reference Products

| Product | Strengths | Platform |
|---------|-----------|----------|
| **随手记** | Largest Chinese personal finance app; comprehensive bookkeeping, budgets, reports, investment tracking; mature UX | Mobile (iOS/Android), Web |
| **MoneyWiz** | Cross-platform professional finance app; multi-currency, investment portfolio, budgets, elegant UI | iOS, macOS, Android, Windows |
| **YNAB** | Global leader in budget management; "give every dollar a job" philosophy; powerful analytics and reporting | Web, iOS, Android |

## Scoring Methodology

### 5-Point Scale

| Score | Meaning |
|-------|---------|
| 5 | Matches or exceeds reference products |
| 4 | Close to reference products, minor gaps |
| 3 | Functional but noticeably behind |
| 2 | Feature exists but incomplete/poor UX |
| 1 | Missing or non-functional |

### Evaluation Dimensions

1. **Data Analysis / Reports (数据分析/报表)**
   - Visualization richness (charts, graphs, dashboards)
   - Report types available (balance sheet, income statement, trends)
   - Trend analysis (month-over-month, year-over-year)
   - Category breakdown and drill-down capability
   - Custom date range and comparison features

2. **UI / Interaction Experience (UI/交互体验)**
   - Layout design and information hierarchy
   - Interaction smoothness and responsiveness
   - Visual polish (animations, transitions, feedback)
   - Mobile responsiveness and adaptive layout
   - Accessibility and intuitive navigation

3. **Business Logic Correctness (业务逻辑正确性)**
   - Double-entry bookkeeping accuracy (debits = credits)
   - Edge case handling (negative balances, currency conversion, overdrafts)
   - Error recovery and data integrity
   - Soft delete consistency across related entities
   - Balance computation correctness across account types

4. **Operation Efficiency (操作效率)**
   - Quick entry flows (one-tap record, templates, recurring)
   - Batch operations (bulk edit, bulk delete, bulk categorize)
   - Smart features (auto-categorization, duplicate detection, AI suggestions)
   - Search and filter capabilities
   - Keyboard shortcuts and power-user features

## Module Grouping & Analysis Order

### Group 1: Core Accounting (核心记账)
| Module | Key Files | Why First |
|--------|-----------|-----------|
| Accounts | `domain/aggregates/account.rs`, `AccountsPage.tsx` | Foundation of all financial data |
| Transactions | `domain/aggregates/transaction.rs`, `TransactionsPage.tsx`, `TransactionForm.tsx` | Core bookkeeping mechanic |
| Reports | `ReportsPage.tsx` | Measures value delivered by all other modules |

### Group 2: Financial Management (财务管理)
| Module | Key Files | Why Second |
|--------|-----------|------------|
| Budget | `domain/aggregates/budget.rs`, `BudgetPage.tsx` | Planning capability, user retention |
| Debts | `domain/aggregates/debt.rs`, `DebtsPage.tsx`, `DebtForm.tsx` | Debt tracking with amortization |
| Goals | `domain/aggregates/goal.rs`, `GoalsPage.tsx` | Long-term financial planning |
| Subscriptions | `domain/aggregates/subscription.rs`, `SubscriptionsPage.tsx` | Recurring expense management |

### Group 3: Investment & Assets (投资资产)
| Module | Key Files | Why Third |
|--------|-----------|-----------|
| Holdings | `domain/aggregates/holding.rs`, `HoldingsPage.tsx` | Investment portfolio management |
| Prepaid Cards | `TopUpDialog.tsx`, `PrepaidDetailPanel.tsx` | Asset management depth |
| Multi-currency | `domain/value_objects/currency.rs`, `CurrencyForm.tsx` | Multi-currency support |

### Group 4: System Features (系统功能)
| Module | Key Files | Why Last |
|--------|-----------|----------|
| Backup | `BackupPage.tsx`, `infrastructure/backup/` | Data safety |
| Cloud Sync | `cloud_sync_service.rs`, `useCloudSync.ts` | Multi-device support |
| Encryption | `encryption_service.rs`, `useEncryption.ts` | Security |
| Reminders | `domain/aggregates/reminder.rs` | Notification delivery |
| Tags | `domain/aggregates/tag.rs` | Transaction categorization |
| Export | `export_commands.rs` | Data portability |
| Search | `search_commands.rs`, `GlobalSearch.tsx` | Findability |
| Onboarding | `OnboardingPage.tsx` | First-run experience |

## Output Deliverables

### 1. Detailed Report (Markdown)
For each module:
- **Current state assessment** — what exists and how it works
- **Reference product comparison** — what 随手记/MoneyWiz/YNAB offer
- **Dimension scores** — 1-5 rating per dimension with justification
- **Key gaps identified** — ranked by impact
- **Improvement suggestions** — short-term fixes and long-term enhancements

### 2. Browser Visualizations
Served via visual companion at `http://localhost:<port>`:
- **Radar charts** — per-module, 4 axes, overlay current vs reference average
- **Score matrix** — modules × dimensions, color-coded (red ≤2, yellow 3, green ≥4)
- **Gap ranking bar chart** — sorted by gap magnitude (reference avg - current)

### 3. Prioritized Action Plan
Three priority levels:

| Level | Criteria | Examples |
|-------|----------|----------|
| **P0 Critical** | Business logic errors, data loss risk | Transaction imbalance, incorrect report calculations |
| **P1 High** | Core experience significantly behind competitors | Missing trend charts, no quick-entry shortcut |
| **P2 Enhancement** | Nice-to-have improvements | Batch operations, custom dashboards, AI categorization |

Each action item includes:
- Module & dimension affected
- Current state → Target state
- Implementation approach
- Estimated effort: S (<1 day) / M (1-3 days) / L (3-5 days)

## Analysis Process Per Module

For each of the 19 modules:

1. **Code review** — Read domain model, service logic, UI components
2. **Feature inventory** — List all implemented capabilities
3. **Reference comparison** — Compare against 随手记, MoneyWiz, YNAB feature sets
4. **Score each dimension** — Apply 5-point scale with written justification
5. **Identify gaps** — List specific missing or weak areas
6. **Propose improvements** — With priority and effort estimate

## Constraints

- Analysis is based on code review and domain knowledge; no live user testing
- Reference product features are based on publicly available information
- Focus on actionable improvements, not feature parity for its own sake
- YAGNI: only recommend improvements that serve real user needs

## File Locations

- Design spec: `docs/superpowers/specs/2026-06-01-gap-analysis-design.md`
- Full report: `docs/superpowers/specs/2026-06-01-gap-analysis-report.md`
- Visualizations: served via brainstorming companion (browser)
- Action plan: included in report, also extracted to `docs/superpowers/specs/2026-06-01-gap-analysis-action-plan.md`
