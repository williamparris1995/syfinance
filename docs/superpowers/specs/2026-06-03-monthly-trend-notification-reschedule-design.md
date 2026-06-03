# Monthly Trend Endpoint + Notification Reschedule Design

**Date:** 2026-06-03
**Status:** Approved

---

## Task A: Server-Side Monthly Trend Aggregation

### Goal
Replace `listTransactions()` + client-side `useMemo` in HomePage and ReportsPage with a dedicated SQL aggregation endpoint, eliminating the last remaining full-table load on both pages.

### Backend

Add `get_monthly_trend(start_date, end_date)` to `ReportService`. Single SQL query groups by month + account:

```sql
SELECT
    strftime('%Y-%m', t.transaction_date) as month,
    a.name as account_name,
    a.account_type,
    a.color,
    CAST(COALESCE(SUM(
        CASE WHEN a.account_type = 'expense' AND e.debit_amount IS NOT NULL THEN e.debit_amount
             WHEN a.account_type = 'income' AND e.credit_amount IS NOT NULL THEN e.credit_amount
             ELSE 0 END
    ), 0) AS TEXT) as amount
FROM transactions t
JOIN transaction_entries e ON e.transaction_id = t.id AND e.deleted_at IS NULL
JOIN accounts a ON e.account_id = a.id
WHERE t.deleted_at IS NULL
  AND t.transaction_date >= ?1 AND t.transaction_date <= ?2
  AND a.deleted_at IS NULL AND a.ownership = 'external'
  AND a.account_type IN ('income', 'expense')
GROUP BY month, a.id
ORDER BY month, a.name
```

Response type:
```rust
struct MonthlyTrendItem {
    month: String,
    income: String,
    expenses: String,
    expense_categories: serde_json::Value,  // {"Groceries": "500.00", ...}
    income_categories: serde_json::Value,
}
```

New Tauri command: `get_monthly_trend(query: ReportDateQuery)`.

### Frontend

- Add `getMonthlyTrend()` to `src/lib/tauri/report.ts`
- Replace `listTransactions` useQuery + `monthlyTrendData` useMemo in both pages
- Remove `listTransactions` import entirely from both files
- Derive `expenseCategories` from response data keys

---

## Task B: Notification Reschedule on Startup

### Goal
Call `NotificationService.reschedule_all()` at startup so pending reminders from previous sessions get scheduled for OS notification delivery.

### Change
In `main.rs` `.setup()`, after creating `notification_service` but before the `tokio::spawn` block that moves `reminder_scheduler`, add:

```rust
match notification_service.reschedule_all().await {
    Ok(count) => info!(count = count, "Rescheduled pending reminders"),
    Err(e) => error!(error = %e, "Failed to reschedule pending reminders"),
}
```

The `notification_service` must be cloned before being moved into the `ReminderScheduler`, so `reschedule_all()` can be called on the original.

---

## Acceptance Criteria

- [ ] `get_monthly_trend` Tauri command returns monthly aggregated data
- [ ] HomePage no longer imports `listTransactions`
- [ ] ReportsPage no longer imports `listTransactions`
- [ ] `reschedule_all()` called on app startup
- [ ] `pnpm type-check && pnpm lint` pass
- [ ] `cd src-tauri && cargo check` passes
