> **ℹ️ 历史快照 — 注**: 云备份与多设备同步已于 2026-07-25 取消(御财 server+Postgres 已集中持久化数据)。本文为时点快照,相关内容仅作历史记录。

# Gap Analysis Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a comprehensive gap analysis report comparing all 19 modules against 随手记, MoneyWiz, and YNAB across 4 dimensions, with browser visualizations and a prioritized action plan.

**Architecture:** Research is complete (module feature inventories collected). Remaining work is synthesis: scoring, visualization, report writing, and action plan creation. Each task produces a self-contained deliverable.

**Tech Stack:** Markdown reports, HTML/CSS visualizations (served via brainstorming companion), structured scoring data.

---

## Task 1: Score All Modules and Build Score Matrix

**Files:**
- Create: `docs/superpowers/specs/2026-06-01-gap-analysis-scores.md` (score justification per module)
- Create: `docs/superpowers/specs/2026-06-01-gap-analysis-report.md` (full report, appended to incrementally)

This task produces the scoring for all 19 modules. Each module gets scored 1-5 on 4 dimensions, with written justification referencing specific code findings and reference product capabilities.

- [ ] **Step 1: Score Group 1 — Core Accounting (Accounts, Transactions, Reports)**

For each module, assign scores with justification:

```
MODULE: Accounts
- Data Analysis: [score] — [justification]
- UI/UX: [score] — [justification]
- Business Logic: [score] — [justification]
- Operation Efficiency: [score] — [justification]
- Reference comparison: what 随手记/MoneyWiz/YNAB offer that we lack

MODULE: Transactions
[same format]

MODULE: Reports
[same format]
```

Scoring rubric (from spec):
- 5 = Matches or exceeds reference products
- 4 = Close to reference products, minor gaps
- 3 = Functional but noticeably behind
- 2 = Feature exists but incomplete/poor UX
- 1 = Missing or non-functional

Reference product benchmarks for each dimension:
- **随手记**: Rich chart library (20+ chart types), trend analysis, category drill-down, smart categorization, OCR receipt scanning, batch operations, template transactions, budget vs actual tracking, investment portfolio with real-time quotes
- **MoneyWiz**: Elegant multi-platform UI, advanced transaction filters, scheduled transactions, multi-currency with auto-conversion, investment tracking with dividends/splits, advanced reports with custom date ranges, tag-based reporting, forecast/projection tools
- **YNAB**: "Give every dollar a job" budgeting philosophy, age of money metric, real-time sync, goal-based budgeting, detailed spending reports, trend analysis, mobile-first responsive design, educational content integration

**Key findings from code review (use these for scoring):**

Accounts:
- Data Analysis: No charts, no trend analysis, no account balance history → LOW score
- UI/UX: Solid layout with icons/colors/sorting, but no drag-drop reorder, no responsive mobile layout → MEDIUM
- Business Logic: Strong domain model with proper invariants, but `low_balance_threshold` not round-tripping through update, `get_account_balance` returns only initial_balance → GOOD but not perfect
- Operation Efficiency: Copy-to-create works, but no templates, no batch ops, no import, search is basic → LOW-MEDIUM

Transactions:
- Data Analysis: No analytics on transactions page itself (reports are separate), no spending trends inline → LOW
- UI/UX: Clean form with pill toggles, inline editing, optimistic updates, but advanced form hidden, no receipt attachments → MEDIUM
- Business Logic: Strong double-entry enforcement, proper balance validation, but `get_transactions_by_account` loads all then filters, category stub non-functional → GOOD
- Operation Efficiency: Quick entry via simple form, but no templates, no recurring, no bulk ops, no auto-categorize → LOW

Reports:
- Data Analysis: Balance sheet + income statement with 4 chart types, but no cash flow, no net worth trend, no drill-down, no year-over-year → LOW-MEDIUM
- UI/UX: Clean tabs and gradient cards, but hardcoded ¥ symbol, no PDF/print, no interactive charts → MEDIUM
- Business Logic: Client-side computation from full datasets (no server aggregation), balance sheet not date-aware → MEDIUM
- Operation Efficiency: Date presets work, CSV export works, but no custom report builder, no scheduled reports → LOW-MEDIUM

- [ ] **Step 2: Score Group 2 — Financial Management (Budget, Debts, Goals, Subscriptions)**

Budget:
- Data Analysis: Only progress bars, no charts, no trend analysis, no budget vs actual over time → LOW
- UI/UX: Clean month navigation and cards, but no service layer, actual amounts never populated → LOW (incomplete)
- Business Logic: Domain model is solid but no auto-tracking of actuals, no integration with transactions → MEDIUM
- Operation Efficiency: Must manually create each month, no templates, no copy from previous → LOW

Debts:
- Data Analysis: No summary stats, no debt trend charts, no interest cost projection → LOW
- UI/UX: Rich form with amortization preview, overdue alerts, payment recording — one of the best modules → MEDIUM-HIGH
- Business Logic: Comprehensive service layer, proper double-entry for payments, partial payment support, but dead domain model coexists → GOOD
- Operation Efficiency: Copy debt, payment recording, upcoming payments panel — decent → MEDIUM

Goals:
- Data Analysis: Summary cards with percentages, but no projection, no trend, no forecasting → LOW-MEDIUM
- UI/UX: Clean cards with progress bars, but no edit UI after creation → MEDIUM
- Business Logic: Domain is sound but no auto-sync from account balances, manual progress only → MEDIUM
- Operation Efficiency: Create + add progress + complete flow, but no edit, no templates → LOW-MEDIUM

Subscriptions:
- Data Analysis: Monthly normalization in summary cards, but no cost trend, no annual projection → LOW-MEDIUM
- UI/UX: Clean filters, expandable rows, pause/resume — well designed → MEDIUM-HIGH
- Business Logic: Auto-record scheduler runs in background, proper double-entry, but transaction matching is fragile (name prefix) → MEDIUM
- Operation Efficiency: Auto-record is great, pause/resume is smooth, but no grouping, no trial tracking → MEDIUM

- [ ] **Step 3: Score Group 3 — Investment & Assets (Holdings, Prepaid, Multi-currency)**

Holdings:
- Data Analysis: Portfolio summary with P&L, but no allocation chart, no historical performance, no benchmarking → LOW-MEDIUM
- UI/UX: Sortable table, expandable trade history, inline editing, but date range filters are non-functional, hardcoded ¥ → MEDIUM
- Business Logic: Weighted average cost, proper double-entry buy/sell, but no dividend/split handling, no lot tracking, recalculate skips dividend/split → MEDIUM
- Operation Efficiency: New trade + sell flows are smooth, security search with auto-create, but no price alerts, no batch trades → MEDIUM

Prepaid:
- Data Analysis: Balance + top-up/consumption stats, but no spending trend chart, no balance history → LOW
- UI/UX: Clean top-up dialog with preview, detail panel with tabs, but no edit/delete for records → MEDIUM
- Business Logic: Full lifecycle with balance checks and low-balance alerts, but alerts not persisted, expiry not tracked → MEDIUM
- Operation Efficiency: Top-up flow is quick, but no preset amounts, no source balance display → LOW-MEDIUM

Multi-currency:
- Data Analysis: Exchange rates stored but no rate history, no rate trend, no conversion analytics → LOW
- UI/UX: Basic form for adding currencies, but no management UI (edit/delete/activate), no rate display → LOW
- Business Logic: Proper conversion math, but hardcoded base currency, no historical rates, precision loss via f64 → MEDIUM
- Operation Efficiency: Add + update rate works, but no batch update, no auto-fetch rates, no rate widget → LOW

- [ ] **Step 4: Score Group 4 — System Features (Backup, Cloud Sync, Encryption, Reminders, Tags, Export, Search, Onboarding)**

Backup:
- Data Analysis: Diff comparison per table with statistics, backup metadata → MEDIUM
- UI/UX: Clean table with restore dialog and diff view, cloud config with presets → MEDIUM-HIGH
- Business Logic: Full backup/restore with 3 conflict strategies, encryption, safety backup, but WebDAV only → GOOD
- Operation Efficiency: One-click backup, one-click restore, but no scheduled backup, no incremental → MEDIUM

Cloud Sync:
- Data Analysis: Sync status only (last sync, status, error) → LOW
- UI/UX: Clean settings section in SettingsPage with status indicators → MEDIUM
- Business Logic: Full sync cycle implemented, but no background timer, no conflict resolution UI → MEDIUM
- Operation Efficiency: Manual sync only, no auto-sync daemon running → LOW

Encryption:
- Data Analysis: N/A (not a data module) → N/A
- UI/UX: Setup/unlock/lock/disable flow complete with keychain support → HIGH
- Business Logic: AES-256-GCM + PBKDF2 + keychain, but unlock doesn't verify password, no field-level encryption applied → MEDIUM-HIGH
- Operation Efficiency: Keychain auto-unlock is seamless → HIGH

Reminders:
- Data Analysis: N/A → N/A
- UI/UX: No frontend UI at all → 1
- Business Logic: Domain model + scheduler logic complete, but no periodic invocation, no notification dispatch → LOW
- Operation Efficiency: No way to create or manage reminders → 1

Tags:
- Data Analysis: No tag statistics or usage counts → LOW
- UI/UX: CRUD wired to frontend, but no update tag, no management page → LOW-MEDIUM
- Business Logic: Very thin domain (id/name/color only), no validation, no soft delete, no sync metadata → LOW
- Operation Efficiency: Create + delete + link to transactions, but no bulk ops, no autocomplete → LOW

Export:
- Data Analysis: Returns JSON dump of 6 tables, no filtering → LOW
- UI/UX: No download UI, no file save dialog → 1
- Business Logic: Dynamic row-to-JSON conversion, but missing tables vs backup schema → LOW
- Operation Efficiency: No file output, no format selection, no scheduled export → 1

Search:
- Data Analysis: N/A → N/A
- UI/UX: Cmd+K shortcut, keyboard navigation, type icons, loading/empty states → MEDIUM-HIGH
- Business Logic: SQL LIKE on 3 entity types, capped at 5 per type, but transactions don't navigate to specific record → MEDIUM
- Operation Efficiency: Quick shortcut, debounced input, but no FTS, no search history, no amount/date filters → MEDIUM

Onboarding:
- Data Analysis: N/A → N/A
- UI/UX: Clean 3-screen flow with copy-to-clipboard, warning box → MEDIUM
- Business Logic: Register/link device + preset accounts, but no progress indicator, refresh resets flow → MEDIUM
- Operation Efficiency: Fast setup, but no currency selection, no encryption prompt, no tutorial → LOW-MEDIUM

- [ ] **Step 5: Compile scores into structured data and write to report**

Write `docs/superpowers/specs/2026-06-01-gap-analysis-scores.md` with the complete scoring table and justifications.

- [ ] **Step 6: Commit scores**

```bash
git add docs/superpowers/specs/2026-06-01-gap-analysis-scores.md
git commit -m "docs: add gap analysis scoring matrix for all 19 modules"
```

---

## Task 2: Create Browser Visualization — Score Matrix & Radar Charts

**Files:**
- Create: HTML file in brainstorming companion `screen_dir` (dynamic, served via browser)

This task produces three browser visualizations:
1. Module × Dimension score matrix (color-coded table)
2. Per-module radar charts (current vs reference average)
3. Gap ranking bar chart (sorted by improvement needed)

- [ ] **Step 1: Write score matrix HTML**

Create `score-matrix.html` in the brainstorming content directory. This is a full HTML page with embedded SVG radar charts and a styled table.

The matrix shows:
- Rows: 19 modules (grouped by category)
- Columns: 4 dimensions + average score + reference average
- Cells: color-coded (red ≤2, yellow 3, green ≥4)
- Reference averages based on what 随手记/MoneyWiz/YNAB typically score (estimated at 4-5 for most dimensions)

Use the scoring from Task 1.

- [ ] **Step 2: Write radar chart HTML**

Create `radar-charts.html` with SVG radar charts for each of the 4 module groups (8-16 axes per chart, each module as a separate line). Show current scores and reference averages as two overlapping polygons.

- [ ] **Step 3: Write gap ranking HTML**

Create `gap-ranking.html` with horizontal bar chart showing modules sorted by total gap (sum of differences across all dimensions). Red bars for largest gaps.

- [ ] **Step 4: Tell user to view visualizations**

Remind user of the URL. Summarize what they'll see.

---

## Task 3: Write Detailed Gap Analysis Report

**Files:**
- Create: `docs/superpowers/specs/2026-06-01-gap-analysis-report.md`

- [ ] **Step 1: Write Group 1 analysis (Accounts, Transactions, Reports)**

For each module, write:
- Current state assessment (what exists)
- Reference product comparison (what competitors offer)
- Dimension scores with justification
- Key gaps identified (ranked by impact)
- Improvement suggestions (short-term fixes vs long-term enhancements)

- [ ] **Step 2: Write Group 2 analysis (Budget, Debts, Goals, Subscriptions)**

Same format as Step 1.

- [ ] **Step 3: Write Group 3 analysis (Holdings, Prepaid, Multi-currency)**

Same format as Step 1.

- [ ] **Step 4: Write Group 4 analysis (Backup, Cloud Sync, Encryption, Reminders, Tags, Export, Search, Onboarding)**

Same format as Step 1.

- [ ] **Step 5: Write cross-cutting analysis**

Document patterns observed across all modules:
- Architecture inconsistencies (some modules have service layer, some don't)
- Missing integrations between modules (budget ≠ transaction actuals, goals ≠ account balances)
- i18n gaps (hardcoded ¥, Chinese toast messages)
- Currency handling (hardcoded CNY/¥ in many places)
- Dead code (legacy debt.rs, stub category system)
- Testing gaps

- [ ] **Step 6: Commit report**

```bash
git add docs/superpowers/specs/2026-06-01-gap-analysis-report.md
git commit -m "docs: add comprehensive gap analysis report for all 19 modules"
```

---

## Task 4: Write Prioritized Action Plan

**Files:**
- Create: `docs/superpowers/specs/2026-06-01-gap-analysis-action-plan.md`

- [ ] **Step 1: Compile all gaps into a unified list**

Extract every gap identified across all module analyses. Deduplicate and categorize.

- [ ] **Step 2: Assign priority levels**

For each gap:
- **P0 Critical**: Business logic errors, data loss risks (e.g., low_balance_threshold not saved, unlock without password verification, transaction matching heuristic)
- **P1 High**: Core experience significantly behind competitors (e.g., no budget auto-tracking, no recurring transactions, no drill-down reports, hardcoded currency)
- **P2 Enhancement**: Nice-to-have improvements (e.g., batch operations, AI categorization, custom dashboards, PDF export)

- [ ] **Step 3: Add effort estimates**

For each action item, estimate:
- S = <1 day
- M = 1-3 days
- L = 3-5 days

- [ ] **Step 4: Write the action plan document**

Format each item as:
```markdown
### [P0/P1/P2] [Short Title]
- **Module**: [affected module]
- **Dimension**: [affected dimension(s)]
- **Current state**: [what's wrong now]
- **Target state**: [what it should be]
- **Implementation approach**: [technical direction]
- **Effort**: [S/M/L]
```

Group by priority, then sort by impact × effort ratio.

- [ ] **Step 5: Commit action plan**

```bash
git add docs/superpowers/specs/2026-06-01-gap-analysis-action-plan.md
git commit -m "docs: add prioritized action plan from gap analysis"
```

---

## Task 5: Final Visualization — Action Plan Summary

**Files:**
- Create: HTML file in brainstorming companion `screen_dir`

- [ ] **Step 1: Write action plan summary HTML**

Create `action-plan.html` showing:
- Priority distribution (P0/P1/P2 counts)
- Effort distribution (S/M/L counts)
- Top 10 highest-impact improvements as a ranked list with progress-bar-style effort indicators
- Module heatmap showing which modules need the most work

- [ ] **Step 2: Push to browser and tell user**

Remind user of URL. Summarize the action plan highlights.

---

## Estimated Total Effort

| Task | Description | Time |
|------|-------------|------|
| 1 | Score all modules | ~30 min |
| 2 | Browser visualizations | ~20 min |
| 3 | Detailed report | ~40 min |
| 4 | Action plan | ~20 min |
| 5 | Final visualization | ~10 min |
| **Total** | | **~2 hours** |
