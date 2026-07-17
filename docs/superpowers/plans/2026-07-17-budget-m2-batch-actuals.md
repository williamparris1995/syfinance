# budget M2 · ListBudgets batch actuals · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 budget read-time actuals 的 **N×M per-item query** 改成 **month 聚合 batch** —— `ListBudgets` N×M → distinct months(通常 1–12),`GetBudget`/`GetBudgetByMonth` M → 1。

**Architecture:** 自底向上加一条 batch 通道,与现有 per-item 通道并存:transaction repo 新增 `SumEntryTotalsByMonth`(raw SQL `GROUP BY account_id`,tenant + date range 过滤)→ transaction application 薄包装 `SpendingByAccountByMonth` → wire 闭包注入 budget 的 `EntryTotalsMonthFunc`(转换 `AccountTotals`→`EntryTotals`,budget 不 import transaction domain)→ budget `computeActualsReadTime`(单 budget)/`computeActualsReadTimeBatch`(list,按 month 分组 + 内存 cache)改用它。**零 proto / 零 ent schema / 零 client。** `ComputeActuals`(persist RPC)保留单 `entryFunc`(范围外)。

**Tech Stack:** Go · ent(raw SQL via `*sql.DB` + `rebindPlaceholders`)· DDD 四层(domain→application→infrastructure)· wire(`providers.go` 手改;`wire_gen.go` 本次**无需改** —— 见 Global Constraints #5)· TDD

---

## Global Constraints

(每个 task 的需求隐含包含以下全部;从 spec 第 3/9 节 + CLAUDE.md 提取,逐字执行)

1. **英文结构化日志** —— `slog.Error("op", "key", val)`,log 串**无 CJK**。
2. **DDD port 边界** —— budget application **不 import** transaction domain。wire 闭包负责把 `transaction.AccountTotals` 转成 budget-local `EntryTotals`(照 D-budget `entryFunc` 闭包范式)。
3. **interface 加方法(CLAUDE.md 约束 6)** —— `TransactionRepository` 加 `SumEntryTotalsByMonth` 后,**全部 7 个 implementer**(1 real + 6 test fake)必须一次补全,否则 `go build ./...` 破。改完跑**全量** `go test ./...`(非 scoped,否则跨包 fake 漏改致 build fail)。implementer 定位法:grep 独有方法名 `SumEntryTotalsByAccount`(新方法加在同一批 fake 上)。
4. **raw SQL dialect** —— 用 `rebindPlaceholders`(sqlite `?` vs postgres `$N`),对齐 `SumEntryTotalsByAccount`。enttest SQLite 自动覆盖;prod postgres 由相同 `rebindPlaceholders` 路径覆盖。
5. **wire 手改(memory `yucai-wire-handmaintained`)** —— **关键简化**:`provideBudgetService` 签名**不变**(仍 `(repo *budgetrepo.BudgetRepository, txnSvc *txnapp.Service)`),只在 body 内多构造一个 `entryMonthFunc` 闭包传给 `budgetapp.NewService`。因此 [wire_gen.go](../../yucai/server/wire/wire_gen.go) 第 101 行 `budgetService := provideBudgetService(budgetRepo, txnService)` **无需改**。只改 [providers.go](../../yucai/server/wire/providers.go) 的 `provideBudgetService` body。
6. **`ComputeActuals`(persist)保留单 `entryFunc`** —— 范围外。`NewService` 改成双闭包 `(entryFunc, entryMonthFunc)`;`ComputeActuals` 调用方不变(仍用 `entryFunc`)。
7. **TDD + frequent commits** —— 每 task:red test → green → commit。conventional commit message(`feat(scope): ...`)。

---

## File Structure

| 文件 | 责任 | 改动 |
|---|---|---|
| [transaction/domain/repository.go](../../yucai/server/internal/transaction/domain/repository.go) | `TransactionRepository` interface + 新 type | +`AccountTotals` struct;interface +`SumEntryTotalsByMonth` |
| [transaction/adapter/driven/repository/transaction_repo.go](../../yucai/server/internal/transaction/adapter/driven/repository/transaction_repo.go) | ent repo(raw SQL via `rawDB`) | +`SumEntryTotalsByMonth` real impl(`GROUP BY account_id`) |
| [transaction/adapter/driven/repository/sum_entry_totals_repo_test.go](../../yucai/server/internal/transaction/adapter/driven/repository/sum_entry_totals_repo_test.go) | repo 聚合测试(enttest SQLite) | +4 个 `TestSumEntryTotalsByMonth_*` |
| [transaction/application/service.go](../../yucai/server/internal/transaction/application/service.go) | app `Service`(薄包装 repo) | +`SpendingByAccountByMonth` |
| [transaction/application/service_test.go](../../yucai/server/internal/transaction/application/service_test.go) | app test + 3 个 fake | 3 fake(`recordingTxnRepo`/`recentTxnRepo`/`sumByAccountTxnRepo`)+`SumEntryTotalsByMonth` stub;`sumByAccountTxnRepo` 加 `monthTotals`/`gotTenantID` field;+2 个 `TestSpendingByAccountByMonth_*` |
| [debt/adapter/driving/grpc/debt_handler_test.go](../../yucai/server/internal/debt/adapter/driving/grpc/debt_handler_test.go) | debt test fake | `recordingTxnRepo` + `failingTxnRepo` 各 +`SumEntryTotalsByMonth` panic stub(`txnDomain` alias) |
| [holding/adapter/driving/grpc/holding_handler_test.go](../../yucai/server/internal/holding/adapter/driving/grpc/holding_handler_test.go) | holding test fake | `recordingTxnRepo` +`SumEntryTotalsByMonth` panic stub(`txnDomain` alias) |
| [budget/application/service.go](../../yucai/server/internal/budget/application/service.go) | budget `Service` | +`EntryTotals` +`EntryTotalsMonthFunc` type;`Service` +`entryMonthFunc` field;`NewService` 加参;`computeActualsReadTime` 改 batch;+`computeActualsReadTimeBatch`;`ListBudgets` 改用 batch |
| [budget/application/service_test.go](../../yucai/server/internal/budget/application/service_test.go) | budget test | `fakeBudgetRepo.FindAll` 加 `all` field;5 个现有测试 `NewService(repo, entryFunc)` → `NewService(repo, nil, entryMonthFunc)`;+2 个 batch 测试 |
| [wire/providers.go](../../yucai/server/wire/providers.go) | wire provider | `provideBudgetService` body +`entryMonthFunc` 闭包 |

---

## Task 1: transaction repo `SumEntryTotalsByMonth` + `AccountTotals` + 全 implementer stub

**原子任务** —— interface 加方法,7 个 implementer 必须一次补全(Global Constraints #3)。task 结束 `go build ./...` + `go test ./...` 全绿。

**Files:**
- Modify: [transaction/domain/repository.go](../../yucai/server/internal/transaction/domain/repository.go)(+type +interface 方法)
- Modify: [transaction/adapter/driven/repository/transaction_repo.go](../../yucai/server/internal/transaction/adapter/driven/repository/transaction_repo.go)(+real impl,插在 `SumEntryTotalsByAccount` line 914 之后)
- Modify: [transaction/adapter/driven/repository/sum_entry_totals_repo_test.go](../../yucai/server/internal/transaction/adapter/driven/repository/sum_entry_totals_repo_test.go)(+4 测试)
- Modify: [transaction/application/service_test.go](../../yucai/server/internal/transaction/application/service_test.go)(3 fake +stub)
- Modify: [debt/adapter/driving/grpc/debt_handler_test.go](../../yucai/server/internal/debt/adapter/driving/grpc/debt_handler_test.go)(2 fake +stub)
- Modify: [holding/adapter/driving/grpc/holding_handler_test.go](../../yucai/server/internal/holding/adapter/driving/grpc/holding_handler_test.go)(1 fake +stub)

**Interfaces:**
- Consumes: 现有 `rebindPlaceholders`、`transactionEntryTable`、`transactionTable`、`r.rawDB`、`r.rawDialect`(均在 transaction_repo.go)
- Produces: `domain.AccountTotals` struct + `TransactionRepository.SumEntryTotalsByMonth(ctx, tenantID, from, to) (map[uuid.UUID]AccountTotals, error)`(Task 2/3 消费)

- [ ] **Step 1: 写 4 个 repo 测试(失败态)**

追加到 [sum_entry_totals_repo_test.go](../../yucai/server/internal/transaction/adapter/driven/repository/sum_entry_totals_repo_test.go) 末尾。复用现有 `newSumRepoFixture` / `recordTxn` / `expenseEntries` / `incomeEntries`(`incomeEntries` 定义在 [transaction_repo_test.go:177](../../yucai/server/internal/transaction/adapter/driven/repository/transaction_repo_test.go#L177))。

```go
// TestSumEntryTotalsByMonth_GroupsByAccount verifies the repo returns one
// debit/credit total per account for entries in [from, to]. Budget batch
// actuals consume this: one query per month fills every item (replaces N×M
// per-item SumEntryTotalsByAccount calls).
func TestSumEntryTotalsByMonth_GroupsByAccount(t *testing.T) {
	f, txnRepo := newSumRepoFixture(t)

	jan10 := time.Date(2026, 1, 10, 0, 0, 0, 0, time.UTC)
	// Food expense ¥500 (debit on expense, credit on asset).
	recordTxn(t, txnRepo, f.tenantID, jan10, "lunch",
		expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 50000))
	// Salary income ¥10000 (debit on asset, credit on income).
	recordTxn(t, txnRepo, f.tenantID, jan10, "salary",
		incomeEntries(f.assetAcc.ID, f.incomeAcc.ID, 1000000))

	from := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 1, 31, 23, 59, 59, 0, time.UTC)
	totals, err := txnRepo.SumEntryTotalsByMonth(context.Background(), f.tenantID, from, to)
	if err != nil {
		t.Fatalf("SumEntryTotalsByMonth: %v", err)
	}
	// Expense account: debit 50000 (spend), credit 0.
	if got := totals[f.expenseAcc.ID]; got.DebitCents != 50000 || got.CreditCents != 0 {
		t.Errorf("expense account: got debit=%d credit=%d, want 50000/0", got.DebitCents, got.CreditCents)
	}
	// Income account: credit 1000000 (salary), debit 0.
	if got := totals[f.incomeAcc.ID]; got.DebitCents != 0 || got.CreditCents != 1000000 {
		t.Errorf("income account: got debit=%d credit=%d, want 0/1000000", got.DebitCents, got.CreditCents)
	}
	// Asset account legs: debit=salary leg 1000000, credit=lunch leg 50000.
	if got := totals[f.assetAcc.ID]; got.DebitCents != 1000000 || got.CreditCents != 50000 {
		t.Errorf("asset account: got debit=%d credit=%d, want 1000000/50000", got.DebitCents, got.CreditCents)
	}
}

// TestSumEntryTotalsByMonth_TenantScopedAndDateFiltered verifies both the
// tenant_id WHERE and the date window: a February entry and another tenant's
// January entry do not contribute (even when the entry's account_id matches).
func TestSumEntryTotalsByMonth_TenantScopedAndDateFiltered(t *testing.T) {
	f, txnRepo := newSumRepoFixture(t)

	jan10 := time.Date(2026, 1, 10, 0, 0, 0, 0, time.UTC)
	feb10 := time.Date(2026, 2, 10, 0, 0, 0, 0, time.UTC)
	// In-window January spend by the fixture tenant.
	recordTxn(t, txnRepo, f.tenantID, jan10, "lunch",
		expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 50000))
	// Out-of-window February spend by the fixture tenant (date filter excludes).
	recordTxn(t, txnRepo, f.tenantID, feb10, "feb lunch",
		expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 99999))
	// January spend by ANOTHER tenant on the same expense account (tenant filter
	// excludes — the whole txn is dropped despite matching account_id).
	recordTxn(t, txnRepo, uuid.New(), jan10, "other-tenant lunch",
		expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 77777))

	from := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 1, 31, 23, 59, 59, 0, time.UTC)
	totals, err := txnRepo.SumEntryTotalsByMonth(context.Background(), f.tenantID, from, to)
	if err != nil {
		t.Fatalf("SumEntryTotalsByMonth: %v", err)
	}
	if got := totals[f.expenseAcc.ID]; got.DebitCents != 50000 {
		t.Errorf("expense debit: got %d, want 50000 (feb/other-tenant leaked)", got.DebitCents)
	}
}

// TestSumEntryTotalsByMonth_ExcludesSoftDeleted verifies that soft-deleted
// transactions do not contribute (same deleted_at IS NULL guard as
// SumEntryTotalsByAccount).
func TestSumEntryTotalsByMonth_ExcludesSoftDeleted(t *testing.T) {
	f, txnRepo := newSumRepoFixture(t)

	date := time.Date(2026, 1, 5, 0, 0, 0, 0, time.UTC)
	recordTxn(t, txnRepo, f.tenantID, date, "live",
		expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 50000))
	deleted := recordTxn(t, txnRepo, f.tenantID, date, "deleted",
		expenseEntries(f.expenseAcc.ID, f.assetAcc.ID, 30000))
	if err := txnRepo.SoftDelete(context.Background(), f.tenantID, deleted.ID); err != nil {
		t.Fatalf("soft delete: %v", err)
	}

	from := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 1, 31, 23, 59, 59, 0, time.UTC)
	totals, err := txnRepo.SumEntryTotalsByMonth(context.Background(), f.tenantID, from, to)
	if err != nil {
		t.Fatalf("SumEntryTotalsByMonth: %v", err)
	}
	if got := totals[f.expenseAcc.ID]; got.DebitCents != 50000 {
		t.Errorf("expense debit: got %d, want 50000 (soft-deleted leaked)", got.DebitCents)
	}
}

// TestSumEntryTotalsByMonth_EmptyReturnsEmptyMap verifies that a tenant/month
// with no activity returns an empty (non-nil) map, not an error.
func TestSumEntryTotalsByMonth_EmptyReturnsEmptyMap(t *testing.T) {
	_, txnRepo := newSumRepoFixture(t)

	from := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 1, 31, 23, 59, 59, 0, time.UTC)
	totals, err := txnRepo.SumEntryTotalsByMonth(context.Background(), uuid.New(), from, to)
	if err != nil {
		t.Fatalf("SumEntryTotalsByMonth empty: %v", err)
	}
	if totals == nil {
		t.Fatal("empty result: got nil map, want non-nil empty map")
	}
	if len(totals) != 0 {
		t.Errorf("empty tenant: got %d accounts, want 0", len(totals))
	}
}
```

- [ ] **Step 2: 跑测试看失败(编译错)**

Run: `cd yucai/server && go test ./internal/transaction/adapter/driven/repository/... -run TestSumEntryTotalsByMonth -count=1`
Expected: FAIL / 编译错 `txnRepo.SumEntryTotalsByMonth undefined (type *repository.TransactionRepository has no field or method SumEntryTotalsByMonth)`

- [ ] **Step 3: 加 domain `AccountTotals` type + interface 方法**

[transaction/domain/repository.go](../../yucai/server/internal/transaction/domain/repository.go):在 `type TransactionRepository interface {`(line 11)**之前**插入 type;在 `SumEntryTotalsByAccount`(line 33)**之后**、`FindAllForBackup`(line 34)**之前**插入方法。

type(插在 interface 前):
```go
// AccountTotals is one account's debit/credit totals over a period. Returned
// by SumEntryTotalsByMonth (grouped by account_id) so budget batch actuals can
// fill every item from a single query instead of one query per item.
type AccountTotals struct {
	DebitCents  int64
	CreditCents int64
}
```

方法(插在 interface 内,`SumEntryTotalsByAccount` 之后):
```go
	// SumEntryTotalsByMonth returns debit/credit totals grouped by account_id
	// for entries whose transaction_date is in [from, to], tenant-scoped. One
	// map entry per account with activity in the range. Used by budget batch
	// actuals: a single query per month replaces N×M per-item
	// SumEntryTotalsByAccount calls. Transfers are asset→asset flows that never
	// touch Expense accounts, so they are excluded automatically — no
	// TransactionType filter is applied.
	SumEntryTotalsByMonth(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]AccountTotals, error)
```

- [ ] **Step 4: 加 real repo impl(raw SQL)**

[transaction_repo.go](../../yucai/server/internal/transaction/adapter/driven/repository/transaction_repo.go):插在 `SumEntryTotalsByAccount` 结束(line 914)**之后**。对齐 `SumEntryTotalsByAccount` 的 `rawDB`/`rebindPlaceholders`/表常量范式。

```go
// SumEntryTotalsByMonth sums debit_cents and credit_cents of all entries whose
// transaction's date falls in [from, to], tenant-scoped, grouped by account_id.
// One map entry per account with activity in the range. Used by budget batch
// actuals: a single query per month replaces N×M per-item
// SumEntryTotalsByAccount calls. Like SumEntryTotalsByAccount the
// transactions/transaction_entries ent modules declare no edge, so the JOIN
// runs over the shared *sql.DB and placeholders are rebound for PostgreSQL
// (pgx does not rewrite '?').
func (r *TransactionRepository) SumEntryTotalsByMonth(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]domain.AccountTotals, error) {
	if r.rawDB == nil {
		return nil, fmt.Errorf("sum entry totals by month requires the underlying *sql.DB (rawDB is nil)")
	}

	q := `
		SELECT
			e.account_id,
			COALESCE(SUM(e.debit_cents), 0),
			COALESCE(SUM(e.credit_cents), 0)
		FROM ` + transactionEntryTable + ` e
		JOIN ` + transactionTable + ` t ON t.id = e.transaction_id
		WHERE t.tenant_id = ?
		  AND t.deleted_at IS NULL
		  AND t.transaction_date >= ?
		  AND t.transaction_date <= ?
		GROUP BY e.account_id
	`
	q = rebindPlaceholders(q, r.rawDialect)

	rows, err := r.rawDB.QueryContext(ctx, q, tenantID, from, to)
	if err != nil {
		return nil, fmt.Errorf("sum entry totals by month: %w", err)
	}
	defer rows.Close()

	out := make(map[uuid.UUID]domain.AccountTotals)
	for rows.Next() {
		var accID uuid.UUID
		var debit, credit int64
		if err := rows.Scan(&accID, &debit, &credit); err != nil {
			return nil, fmt.Errorf("scan entry totals by month: %w", err)
		}
		out[accID] = domain.AccountTotals{DebitCents: debit, CreditCents: credit}
	}
	return out, rows.Err()
}
```

- [ ] **Step 5: 补 6 个 test fake stub(让全量 build 绿)**

**5a.** [transaction/application/service_test.go](../../yucai/server/internal/transaction/application/service_test.go)(alias `domain`):

`recordingTxnRepo` —— 插在其 `SumEntryTotalsByAccount`(line 108)之后:
```go
func (r *recordingTxnRepo) SumEntryTotalsByMonth(context.Context, uuid.UUID, time.Time, time.Time) (map[uuid.UUID]domain.AccountTotals, error) {
	panic("unexpected SumEntryTotalsByMonth call")
}
```

`recentTxnRepo` —— 插在其 `SumEntryTotalsByAccount`(line 153)之后:
```go
func (r *recentTxnRepo) SumEntryTotalsByMonth(context.Context, uuid.UUID, time.Time, time.Time) (map[uuid.UUID]domain.AccountTotals, error) {
	panic("unexpected SumEntryTotalsByMonth call")
}
```

`sumByAccountTxnRepo` —— **真实返回**(它本就是"可编程返回"的 fake,Task 2 的 application 测试要用)。先给 struct 加 2 个 field(line 166–173 的 struct):
```go
type sumByAccountTxnRepo struct {
	gotAccountID uuid.UUID
	gotFrom      time.Time
	gotTo        time.Time
	debitTotal   int64
	creditTotal  int64
	err          error
	// SumEntryTotalsByMonth canned result (budget batch port).
	monthTotals map[uuid.UUID]domain.AccountTotals
	gotTenantID uuid.UUID
}
```
再插在其 `SumEntryTotalsByAccount`(line 196)之后加方法:
```go
func (r *sumByAccountTxnRepo) SumEntryTotalsByMonth(_ context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]domain.AccountTotals, error) {
	r.gotTenantID = tenantID
	r.gotFrom = from
	r.gotTo = to
	return r.monthTotals, r.err
}
```

**5b.** [debt/adapter/driving/grpc/debt_handler_test.go](../../yucai/server/internal/debt/adapter/driving/grpc/debt_handler_test.go)(alias `txnDomain`):

`recordingTxnRepo` —— 插在其 `SumEntryTotalsByAccount`(line 243)之后:
```go
func (r *recordingTxnRepo) SumEntryTotalsByMonth(context.Context, uuid.UUID, time.Time, time.Time) (map[uuid.UUID]txnDomain.AccountTotals, error) {
	panic("unexpected SumEntryTotalsByMonth call")
}
```

`failingTxnRepo` —— 插在其 `SumEntryTotalsByAccount`(line 518)之后:
```go
func (r *failingTxnRepo) SumEntryTotalsByMonth(context.Context, uuid.UUID, time.Time, time.Time) (map[uuid.UUID]txnDomain.AccountTotals, error) {
	panic("unexpected SumEntryTotalsByMonth call")
}
```

**5c.** [holding/adapter/driving/grpc/holding_handler_test.go](../../yucai/server/internal/holding/adapter/driving/grpc/holding_handler_test.go)(alias `txnDomain`):

`recordingTxnRepo` —— 插在其 `SumEntryTotalsByAccount`(line 136)之后:
```go
func (r *recordingTxnRepo) SumEntryTotalsByMonth(context.Context, uuid.UUID, time.Time, time.Time) (map[uuid.UUID]txnDomain.AccountTotals, error) {
	panic("unexpected SumEntryTotalsByMonth call")
}
```

- [ ] **Step 6: 跑全量 build + test**

Run: `cd yucai/server && go build ./...`
Expected: 成功(无输出)

Run: `cd yucai/server && go test ./internal/transaction/... -count=1`
Expected: PASS(4 个新 `TestSumEntryTotalsByMonth_*` 全过;现有 `TestSumEntryTotalsByAccount_*` 不回归)

Run: `cd yucai/server && go test ./... -count=1`
Expected: PASS(确认 6 个 fake stub 不破 transaction/debt/holding 任何包 —— Global Constraints #3 全量验证)

- [ ] **Step 7: Commit**

```bash
cd yucai/server
git add internal/transaction/domain/repository.go \
  internal/transaction/adapter/driven/repository/transaction_repo.go \
  internal/transaction/adapter/driven/repository/sum_entry_totals_repo_test.go \
  internal/transaction/application/service_test.go \
  internal/debt/adapter/driving/grpc/debt_handler_test.go \
  internal/holding/adapter/driving/grpc/holding_handler_test.go
git commit -m "feat(transaction): SumEntryTotalsByMonth repo batch (budget M2 Task 1)

Add GROUP BY account_id raw SQL aggregate (tenant + date-range scoped) so a
single query per month can fill every budget item's actuals, replacing the
N×M per-item SumEntryTotalsByAccount calls. AccountTotals type added to
transaction domain. All 7 TransactionRepository implementers (1 real + 6 test
fakes across transaction/debt/holding) updated; full suite green."
```

---

## Task 2: transaction application `SpendingByAccountByMonth` wrapper + test

**Files:**
- Modify: [transaction/application/service.go](../../yucai/server/internal/transaction/application/service.go)(+方法,插在 `SpendingByAccount` line 123 之后)
- Modify: [transaction/application/service_test.go](../../yucai/server/internal/transaction/application/service_test.go)(+2 测试)

**Interfaces:**
- Consumes: Task 1 的 `txnRepo.SumEntryTotalsByMonth`;现有 `NewService(txnRepo, accountRepo, balanceUpd)`、`newMockAccountRepo()`、`noopBalanceUpdater{}`
- Produces: `Service.SpendingByAccountByMonth(ctx, tenantID, from, to) (map[uuid.UUID]domain.AccountTotals, error)`(Task 3 wire 闭包消费)

- [ ] **Step 1: 写 2 个 application 测试(失败态)**

追加到 [service_test.go](../../yucai/server/internal/transaction/application/service_test.go) 末尾。`sumByAccountTxnRepo` 已在 Task 1 加好 `monthTotals`/`gotTenantID` field + `SumEntryTotalsByMonth` 真实返回。

```go
// TestSpendingByAccountByMonth_DelegatesToRepo verifies the service method is a
// pure thin wrapper: it forwards tenantID/from/to to the repo and returns the
// repo's canned map unchanged.
func TestSpendingByAccountByMonth_DelegatesToRepo(t *testing.T) {
	acc := uuid.New()
	canned := map[uuid.UUID]domain.AccountTotals{acc: {DebitCents: 50000, CreditCents: 5000}}
	from := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 1, 31, 23, 59, 59, 0, time.UTC)
	tenantID := uuid.New()

	repo := &sumByAccountTxnRepo{monthTotals: canned}
	svc := NewService(repo, newMockAccountRepo(), noopBalanceUpdater{})

	got, err := svc.SpendingByAccountByMonth(context.Background(), tenantID, from, to)
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if repo.gotTenantID != tenantID {
		t.Errorf("tenantID: got %s, want %s", repo.gotTenantID, tenantID)
	}
	if !repo.gotFrom.Equal(from) || !repo.gotTo.Equal(to) {
		t.Errorf("range: got %s..%s, want %s..%s", repo.gotFrom, repo.gotTo, from, to)
	}
	if got[acc].DebitCents != 50000 || got[acc].CreditCents != 5000 {
		t.Errorf("canned map not forwarded: got debit=%d credit=%d, want 50000/5000", got[acc].DebitCents, got[acc].CreditCents)
	}
}

// TestSpendingByAccountByMonth_PropagatesRepoError verifies a repo error is
// wrapped and returned (not swallowed).
func TestSpendingByAccountByMonth_PropagatesRepoError(t *testing.T) {
	repo := &sumByAccountTxnRepo{err: fmt.Errorf("boom")}
	svc := NewService(repo, newMockAccountRepo(), noopBalanceUpdater{})

	_, err := svc.SpendingByAccountByMonth(context.Background(), uuid.New(), time.Time{}, time.Time{})
	if err == nil {
		t.Fatal("expected error, got nil")
	}
}
```

(`fmt` / `time` / `uuid` / `domain` 均已在 service_test.go 顶部 import,无需补。)

- [ ] **Step 2: 跑测试看失败**

Run: `cd yucai/server && go test ./internal/transaction/application/... -run TestSpendingByAccountByMonth -count=1`
Expected: FAIL / 编译错 `svc.SpendingByAccountByMonth undefined`

- [ ] **Step 3: 加 `SpendingByAccountByMonth` 方法**

[service.go](../../yucai/server/internal/transaction/application/service.go):插在 `SpendingByAccount`(line 123)**之后**。对齐 `SpendingByAccount` 薄包装范式。

```go
// SpendingByAccountByMonth returns debit/credit totals grouped by account_id
// for [from, to], tenant-scoped. Budget batch actuals port: one query per
// month replaces N×M per-item SpendingByAccount calls across a budget list.
// Thin wrapper: delegates to the repository and wraps errors.
func (s *Service) SpendingByAccountByMonth(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]domain.AccountTotals, error) {
	totals, err := s.txnRepo.SumEntryTotalsByMonth(ctx, tenantID, from, to)
	if err != nil {
		return nil, fmt.Errorf("spending by account by month: %w", err)
	}
	return totals, nil
}
```

- [ ] **Step 4: 跑测试看通过**

Run: `cd yucai/server && go test ./internal/transaction/application/... -run TestSpendingByAccountByMonth -count=1`
Expected: PASS(2 个新测试过)

Run: `cd yucai/server && go build ./...`
Expected: 成功

- [ ] **Step 5: Commit**

```bash
cd yucai/server
git add internal/transaction/application/service.go internal/transaction/application/service_test.go
git commit -m "feat(transaction/app): SpendingByAccountByMonth wrapper (budget M2 Task 2)

Thin wrapper over SumEntryTotalsByMonth so wire can inject a batch port into
budget without budget importing transaction domain."
```

---

## Task 3: budget application batch actuals + wire closure

**原子任务** —— `NewService` 签名变更(2→3 参)期间 build 会破,完成全部改动(service.go + service_test.go + providers.go)后统一验证。`ComputeActuals`(persist)保留单 `entryFunc` 不变。

**Files:**
- Modify: [budget/application/service.go](../../yucai/server/internal/budget/application/service.go)(type + field + `NewService` + `computeActualsReadTime` 改 batch + `ListBudgets` 改 batch + 新 `computeActualsReadTimeBatch`)
- Modify: [budget/application/service_test.go](../../yucai/server/internal/budget/application/service_test.go)(`fakeBudgetRepo.FindAll` 加 `all` field;5 现有测试改 `entryMonthFunc`;+2 新 batch 测试)
- Modify: [wire/providers.go](../../yucai/server/wire/providers.go)(`provideBudgetService` body)
- **不改**:[wire/wire_gen.go](../../yucai/server/wire/wire_gen.go)(`provideBudgetService` 签名不变,Global Constraints #5)

**Interfaces:**
- Consumes: Task 2 的 `txnSvc.SpendingByAccountByMonth`;Task 1 的 `transaction.AccountTotals`;现有 `monthRange`、`ComputeActuals`(用 `entryFunc`)、`BudgetToDTO`
- Produces: `budgetapp.EntryTotals`、`budgetapp.EntryTotalsMonthFunc`、`NewService(repo, entryFunc, entryMonthFunc)`(wire 消费)

- [ ] **Step 1: 改 budget service.go —— type + field + NewService + batch 方法**

[budget/application/service.go](../../yucai/server/internal/budget/application/service.go):

**1a.** 在 `EntryTotalsFunc`(line 14)**之后**插入两个新 type:
```go
// EntryTotals is one account's debit/credit over a period (budget-local copy
// of transaction.AccountTotals — budget does not import transaction domain).
type EntryTotals struct {
	DebitCents  int64
	CreditCents int64
}

// EntryTotalsMonthFunc returns debit/credit totals grouped by account_id for
// [from, to], tenant-scoped. Batch port for read-time actuals (replaces the
// per-item EntryTotalsFunc for ListBudgets/GetBudget*). nil → actuals stay 0.
type EntryTotalsMonthFunc func(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error)
```

**1b.** 替换 `Service` struct(line 17–20)+ `NewService`(line 23–25):
```go
// Service orchestrates budget operations.
type Service struct {
	repo           domain.BudgetRepository
	entryFunc      EntryTotalsFunc      // single-account (ComputeActuals persist RPC)
	entryMonthFunc EntryTotalsMonthFunc // batch (read-time actuals: ListBudgets/GetBudget*)
}

// NewService creates a new budget application service. entryFunc backs the
// persist-path ComputeActuals (per-item); entryMonthFunc backs read-time
// actuals (one query per month). Either may be nil (graceful: actuals stay 0).
func NewService(repo domain.BudgetRepository, entryFunc EntryTotalsFunc, entryMonthFunc EntryTotalsMonthFunc) *Service {
	return &Service{repo: repo, entryFunc: entryFunc, entryMonthFunc: entryMonthFunc}
}
```

**1c.** 替换 `ListBudgets`(line 74–89)—— 改用 `computeActualsReadTimeBatch`:
```go
// ListBudgets returns a paginated list of budgets.
func (s *Service) ListBudgets(ctx context.Context, req ListBudgetsRequest) (*ListBudgetsResult, error) {
	result, err := s.repo.FindAll(ctx, req.TenantID, req.ActiveOnly, req.Page)
	if err != nil {
		return nil, fmt.Errorf("list budgets: %w", err)
	}
	s.computeActualsReadTimeBatch(ctx, req.TenantID, result.Items)
	dtos := make([]BudgetDTO, len(result.Items))
	for i, b := range result.Items {
		dtos[i] = BudgetToDTO(&b)
	}
	return &ListBudgetsResult{
		Budgets:       dtos,
		NextPageToken: result.NextPageToken,
		TotalCount:    result.TotalCount,
	}, nil
}
```

**1d.** 替换 `computeActualsReadTime`(line 200–217)—— 改 batch(单 budget:1 month query 替代 M per-item;`GetBudget`/`GetBudgetByMonth` 受益):
```go
// computeActualsReadTime fills each item's ActualAmountCents via one batch
// month query (entryMonthFunc), not per-item. nil entryMonthFunc → actuals 0.
// err → all items 0 + slog (best-effort, NOT propagated).
// actual = debit - credit (spending - refunds = net spend).
func (s *Service) computeActualsReadTime(ctx context.Context, b *domain.Budget) {
	if s.entryMonthFunc == nil {
		return // actuals stay 0 (stored value or zero)
	}
	from, to := monthRange(b.Month)
	totals, err := s.entryMonthFunc(ctx, b.TenantID, from, to)
	if err != nil {
		slog.Error("budget actuals: entryMonthFunc failed",
			"operation", "budget.computeActualsReadTime",
			"budget_id", b.ID.String(), "error", err.Error())
		for i := range b.Items {
			b.Items[i].ActualAmountCents = 0
		}
		return
	}
	for i := range b.Items {
		if t, ok := totals[b.Items[i].AccountID]; ok {
			b.Items[i].ActualAmountCents = t.DebitCents - t.CreditCents
		} else {
			b.Items[i].ActualAmountCents = 0
		}
	}
}

// computeActualsReadTimeBatch fills actuals for many budgets with one query
// per distinct month (vs N×M per-item). nil entryMonthFunc → no-op. A failed
// month is cached as nil so it is not retried; its items stay 0. ListBudgets
// passes its tenantID (already tenant-scoped by FindAll).
func (s *Service) computeActualsReadTimeBatch(ctx context.Context, tenantID uuid.UUID, budgets []domain.Budget) {
	if s.entryMonthFunc == nil {
		return
	}
	monthCache := map[string]map[uuid.UUID]EntryTotals{}
	for i := range budgets {
		month := budgets[i].Month
		if _, cached := monthCache[month]; cached {
			continue
		}
		from, to := monthRange(month)
		totals, err := s.entryMonthFunc(ctx, tenantID, from, to)
		if err != nil {
			slog.Error("budget actuals batch: entryMonthFunc failed",
				"operation", "budget.computeActualsReadTimeBatch",
				"month", month, "error", err.Error())
			monthCache[month] = nil // mark attempted (items stay 0, no retry)
			continue
		}
		monthCache[month] = totals
	}
	for i := range budgets {
		totals := monthCache[budgets[i].Month]
		for j := range budgets[i].Items {
			if totals != nil {
				if t, ok := totals[budgets[i].Items[j].AccountID]; ok {
					budgets[i].Items[j].ActualAmountCents = t.DebitCents - t.CreditCents
					continue
				}
			}
			budgets[i].Items[j].ActualAmountCents = 0
		}
	}
}
```

> `ComputeActuals`(line 139–162)**不动** —— 它仍用 `s.entryFunc` per-item(范围外)。`entryFunc` 经 wire 双闭包继续注入(Global Constraints #6)。

- [ ] **Step 2: 改 budget service_test.go —— fakeBudgetRepo.FindAll + 5 现有测试切换 + 2 新 batch 测试**

[budget/application/service_test.go](../../yucai/server/internal/budget/application/service_test.go):

**2a.** 扩展 `fakeBudgetRepo.FindAll`(line 37–42)支持多 budget(`all` field;回退单 `budget` 保持现有 4 个不走 FindAll 的测试不破)。struct(line 14–17)加 `all` field:
```go
// fakeBudgetRepo is an in-memory BudgetRepository for testing.
type fakeBudgetRepo struct {
	budget *domain.Budget
	all    []domain.Budget // FindAll returns this when non-nil (multi-budget batch tests)
	err    error
}
```
FindAll 改:
```go
func (r *fakeBudgetRepo) FindAll(ctx context.Context, tenantID uuid.UUID, activeOnly bool, page domain.PageRequest) (*domain.PaginatedResult[domain.Budget], error) {
	if r.err != nil {
		return nil, r.err
	}
	items := r.all
	if items == nil && r.budget != nil {
		items = []domain.Budget{*r.budget}
	}
	return &domain.PaginatedResult[domain.Budget]{Items: items}, nil
}
```

**2b.** 5 个现有 read-time 测试:`entryFunc` 闭包 → `entryMonthFunc` 闭包(返回 map),`NewService(repo, entryFunc)` → `NewService(repo, nil, entryMonthFunc)`。逐个替换:

`TestGetBudgetComputesActualsReadTime`(line 63–91):
```go
func TestGetBudgetComputesActualsReadTime(t *testing.T) {
	budget := &domain.Budget{
		ID: uuid.New(), Month: "2026-07", CurrencyCode: "CNY",
		Items: []domain.BudgetItem{
			{ID: uuid.New(), AccountID: uuid.New(), PlannedAmountCents: 200000},
		},
		TotalAmountCents: 200000,
	}
	repo := &fakeBudgetRepo{budget: budget}
	// batch port: returns the item account's debit/credit (¥500 spend).
	entryMonthFunc := func(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error) {
		return map[uuid.UUID]EntryTotals{budget.Items[0].AccountID: {DebitCents: 50000, CreditCents: 0}}, nil
	}
	svc := NewService(repo, nil, entryMonthFunc)

	dto, err := svc.GetBudgetByMonth(context.Background(), uuid.New(), "2026-07")
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if dto.Budget.Items[0].ActualAmountCents != 50000 {
		t.Fatalf("item actual: got %d, want 50000", dto.Budget.Items[0].ActualAmountCents)
	}
	if dto.TotalActualCents != 50000 {
		t.Fatalf("total actual: got %d, want 50000", dto.TotalActualCents)
	}
	// usage_pct = 50000/200000*100 = 25
	if dto.UsagePct != 25.0 {
		t.Fatalf("usage_pct: got %f, want 25", dto.UsagePct)
	}
}
```

`TestGetBudgetActualsNilEntryFuncFallback`(line 93–107)—— 改 `NewService(repo, nil, nil)`(双 nil):
```go
func TestGetBudgetActualsNilEntryFuncFallback(t *testing.T) {
	repo := &fakeBudgetRepo{budget: &domain.Budget{
		Month: "2026-07",
		Items: []domain.BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 100000}},
		TotalAmountCents: 100000,
	}}
	svc := NewService(repo, nil, nil) // nil entryMonthFunc
	dto, err := svc.GetBudgetByMonth(context.Background(), uuid.New(), "2026-07")
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if dto.Budget.Items[0].ActualAmountCents != 0 {
		t.Fatalf("nil entryMonthFunc: got %d, want 0", dto.Budget.Items[0].ActualAmountCents)
	}
}
```

`TestGetBudgetActualsEntryFuncErrGraceful`(line 109–126)—— entryMonthFunc 返 err:
```go
func TestGetBudgetActualsEntryFuncErrGraceful(t *testing.T) {
	repo := &fakeBudgetRepo{budget: &domain.Budget{
		Month: "2026-07",
		Items: []domain.BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 100000}},
		TotalAmountCents: 100000,
	}}
	entryMonthFunc := func(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error) {
		return nil, fmt.Errorf("boom")
	}
	svc := NewService(repo, nil, entryMonthFunc)
	dto, err := svc.GetBudgetByMonth(context.Background(), uuid.New(), "2026-07")
	if err != nil {
		t.Fatalf("should not propagate entryMonthFunc err: %v", err)
	}
	if dto.Budget.Items[0].ActualAmountCents != 0 {
		t.Fatalf("err fallback: got %d, want 0", dto.Budget.Items[0].ActualAmountCents)
	}
}
```

`TestGetBudgetByIDComputesActuals`(line 128–150)—— net debit−credit(30000−10000=20000):
```go
func TestGetBudgetByIDComputesActuals(t *testing.T) {
	budget := &domain.Budget{
		ID: uuid.New(), Month: "2026-07",
		Items: []domain.BudgetItem{
			{ID: uuid.New(), AccountID: uuid.New(), PlannedAmountCents: 100000},
		},
		TotalAmountCents: 100000,
	}
	repo := &fakeBudgetRepo{budget: budget}
	entryMonthFunc := func(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error) {
		return map[uuid.UUID]EntryTotals{budget.Items[0].AccountID: {DebitCents: 30000, CreditCents: 10000}}, nil // net 20000
	}
	svc := NewService(repo, nil, entryMonthFunc)
	dto, err := svc.GetBudget(context.Background(), uuid.New(), uuid.New())
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if dto.Budget.Items[0].ActualAmountCents != 20000 {
		t.Fatalf("item actual: got %d, want 20000 (debit-credit)", dto.Budget.Items[0].ActualAmountCents)
	}
	if dto.TotalActualCents != 20000 {
		t.Fatalf("total actual: got %d, want 20000", dto.TotalActualCents)
	}
}
```

`TestListBudgetsComputesActuals`(line 152–175)—— 单 budget list,batch 路径:
```go
func TestListBudgetsComputesActuals(t *testing.T) {
	budget := &domain.Budget{
		ID: uuid.New(), Month: "2026-07",
		Items: []domain.BudgetItem{
			{ID: uuid.New(), AccountID: uuid.New(), PlannedAmountCents: 100000},
		},
		TotalAmountCents: 100000,
	}
	repo := &fakeBudgetRepo{budget: budget}
	entryMonthFunc := func(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error) {
		return map[uuid.UUID]EntryTotals{budget.Items[0].AccountID: {DebitCents: 80000, CreditCents: 0}}, nil
	}
	svc := NewService(repo, nil, entryMonthFunc)
	res, err := svc.ListBudgets(context.Background(), ListBudgetsRequest{TenantID: uuid.New()})
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if len(res.Budgets) != 1 {
		t.Fatalf("expected 1 budget, got %d", len(res.Budgets))
	}
	if res.Budgets[0].Items[0].ActualAmountCents != 80000 {
		t.Fatalf("item actual: got %d, want 80000", res.Budgets[0].Items[0].ActualAmountCents)
	}
}
```

**2c.** 追加 2 个新 batch 测试(验证 N×M → distinct months):

```go
// TestListBudgets_BatchOneQueryPerDistinctMonth verifies
// computeActualsReadTimeBatch issues exactly one entryMonthFunc call per
// distinct Month across all budgets (not one per budget, not one per item).
// Two July budgets share one query; a June budget triggers exactly one more.
func TestListBudgets_BatchOneQueryPerDistinctMonth(t *testing.T) {
	tenantID := uuid.New()
	calls := 0
	callsByMonth := map[string]int{}
	entryMonthFunc := func(ctx context.Context, tid uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error) {
		calls++
		callsByMonth[from.Format("2006-01")]++
		return map[uuid.UUID]EntryTotals{}, nil
	}
	repo := &fakeBudgetRepo{all: []domain.Budget{
		{ID: uuid.New(), TenantID: tenantID, Month: "2026-07", Items: []domain.BudgetItem{{ID: uuid.New(), AccountID: uuid.New()}}},
		{ID: uuid.New(), TenantID: tenantID, Month: "2026-07", Items: []domain.BudgetItem{{ID: uuid.New(), AccountID: uuid.New()}}},
		{ID: uuid.New(), TenantID: tenantID, Month: "2026-06", Items: []domain.BudgetItem{{ID: uuid.New(), AccountID: uuid.New()}}},
	}}
	svc := NewService(repo, nil, entryMonthFunc)

	_, err := svc.ListBudgets(context.Background(), ListBudgetsRequest{TenantID: tenantID})
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	// 2 distinct months (2026-06, 2026-07) → exactly 2 calls, NOT 3 (per budget).
	if calls != 2 {
		t.Errorf("entryMonthFunc calls: got %d, want 2 (one per distinct month)", calls)
	}
	if callsByMonth["2026-07"] != 1 || callsByMonth["2026-06"] != 1 {
		t.Errorf("per-month calls: got %+v, want 2026-07=1, 2026-06=1", callsByMonth)
	}
}

// TestListBudgets_BatchFillsActualsFromMap verifies the batch result fills each
// item's ActualAmountCents from the month query's per-account totals
// (debit−credit), and items with no matching account stay 0.
func TestListBudgets_BatchFillsActualsFromMap(t *testing.T) {
	foodAcc := uuid.New()
	transportAcc := uuid.New()
	noDataAcc := uuid.New()
	tenantID := uuid.New()
	entryMonthFunc := func(ctx context.Context, tid uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error) {
		if from.Format("2006-01") != "2026-07" {
			return map[uuid.UUID]EntryTotals{}, nil
		}
		return map[uuid.UUID]EntryTotals{
			foodAcc:      {DebitCents: 50000, CreditCents: 5000}, // net 45000
			transportAcc: {DebitCents: 20000, CreditCents: 0},    // net 20000
		}, nil
	}
	repo := &fakeBudgetRepo{all: []domain.Budget{
		{TenantID: tenantID, Month: "2026-07", Items: []domain.BudgetItem{
			{ID: uuid.New(), AccountID: foodAcc},
			{ID: uuid.New(), AccountID: transportAcc},
			{ID: uuid.New(), AccountID: noDataAcc}, // no entry → stays 0
		}},
	}}
	svc := NewService(repo, nil, entryMonthFunc)

	res, err := svc.ListBudgets(context.Background(), ListBudgetsRequest{TenantID: tenantID})
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if got := res.Budgets[0].Items[0].ActualAmountCents; got != 45000 {
		t.Errorf("food actual: got %d, want 45000 (debit-credit)", got)
	}
	if got := res.Budgets[0].Items[1].ActualAmountCents; got != 20000 {
		t.Errorf("transport actual: got %d, want 20000", got)
	}
	if got := res.Budgets[0].Items[2].ActualAmountCents; got != 0 {
		t.Errorf("no-data item actual: got %d, want 0", got)
	}
}
```

- [ ] **Step 3: 改 wire providers.go —— provideBudgetService body**

[wire/providers.go](../../yucai/server/wire/providers.go):替换 `provideBudgetService`(line 297–301)body —— 加 `entryMonthFunc` 闭包,转换 `transaction.AccountTotals`→`budgetapp.EntryTotals`。**签名不变**(`(repo, txnSvc)`),所以 [wire_gen.go:101](../../yucai/server/wire/wire_gen.go#L101) 的调用不动。

```go
// provideBudgetService wires budget's entryFunc (per-item, ComputeActuals
// persist) and entryMonthFunc (batch, read-time actuals) to the real
// transaction spending totals. budget application does NOT import transaction
// (function-injection port pattern, mirroring D-currency's networth and
// D-goal's AccountMarketValueSource); wire injects closures that delegate to
// txnSvc.SpendingByAccount / SpendingByAccountByMonth. Before Task 4
// entryFunc was nil, so actuals read 0.
func provideBudgetService(repo *budgetrepo.BudgetRepository, txnSvc *txnapp.Service) *budgetapp.Service {
	return budgetapp.NewService(repo,
		func(ctx context.Context, accountID uuid.UUID, from, to time.Time) (int64, int64, error) {
			return txnSvc.SpendingByAccount(ctx, accountID, from, to)
		},
		func(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]budgetapp.EntryTotals, error) {
			totals, err := txnSvc.SpendingByAccountByMonth(ctx, tenantID, from, to)
			if err != nil {
				return nil, err
			}
			out := make(map[uuid.UUID]budgetapp.EntryTotals, len(totals))
			for acc, t := range totals {
				out[acc] = budgetapp.EntryTotals{DebitCents: t.DebitCents, CreditCents: t.CreditCents}
			}
			return out, nil
		},
	)
}
```

> `budgetapp` / `txnapp` / `uuid` / `budgetrepo` alias 沿用 providers.go 顶部现有 import(它们已被现有 `provideBudgetService` 使用)。

- [ ] **Step 4: 跑全量 build + test**

Run: `cd yucai/server && go build ./...`
Expected: 成功(NewService 3 参 + providers.go + wire_gen.go 全同步;6 个 TransactionRepository fake 已在 Task 1 补全)

Run: `cd yucai/server && go test ./internal/budget/... -count=1`
Expected: PASS(5 改造测试 + 2 新 batch 测试全过)

Run: `cd yucai/server && go test ./... -count=1`
Expected: PASS(transaction + budget + wire 全链路绿;ComputeActuals persist 路径未回归)

- [ ] **Step 5: (可选)e2e 烟测**

若 dev 环境就绪(memory `yucai-dev-env`):启动 server,用 grpcurl 调 `ListBudgets` / `GetBudgetByMonth`,确认 actuals 正常返回(query 数下降需 DB 层观察,功能正确性由单元测试保证)。

- [ ] **Step 6: Commit**

```bash
cd yucai/server
git add internal/budget/application/service.go \
  internal/budget/application/service_test.go \
  wire/providers.go
git commit -m "feat(budget): read-time actuals batch N×M→distinct months (M2 Task 3)

Switch ListBudgets/GetBudget/GetBudgetByMonth read-time actuals from
per-item entryFunc to a batch entryMonthFunc: one query per distinct month
(grouped by account_id) instead of N×M per-item queries. EntryTotals +
EntryTotalsMonthFunc added to budget application (no cross-module import;
wire closure converts transaction.AccountTotals→budget EntryTotals).
provideBudgetService signature unchanged → wire_gen.go untouched.
ComputeActuals persist path keeps single entryFunc (out of scope)."
```

---

## Spec coverage 矩阵

| spec 决策/章节 | 落地 task | 备注 |
|---|---|---|
| §3 #1 month 聚合 batch(A 方案) | Task 1+3 | `GROUP BY account_id` + month 分组 cache |
| §3 #2 all read-time actuals | Task 3 | ListBudgets + GetBudget + GetBudgetByMonth 共享 `computeActualsReadTime`(batch) |
| §3 #3 ComputeActuals(persist)不改 | Task 3 1d 注 | `ComputeActuals` 保留 `entryFunc` per-item |
| §3 #4 txn service 方法 + wire 闭包 port | Task 2 + Task 3 Step 3 | `SpendingByAccountByMonth` + 闭包 |
| §3 #5 `map[uuid.UUID]AccountTotals` | Task 1 Step 3/4 | `AccountTotals{DebitCents,CreditCents}` |
| §3 #6 ListBudgets 按 month 分组 + cache | Task 3 Step 1c/1d | `computeActualsReadTimeBatch` `monthCache` |
| §3 #7 AccountTotals→txn domain,EntryTotals→budget | Task 1 + Task 3 Step 1a | wire 闭包转换 |
| §5 五层改动 | Task 1(domain+repo)+ Task 2(app)+ Task 3(budget app+wire) | |
| §6.1–6.5 全部代码块 | Task 1–3 对应 step | 逐字落地,签名/类型一致 |
| §8 测试:repo 多 account/tenant/date/空/soft-delete | Task 1 Step 1 | 4 测试覆盖全部 |
| §8 测试:app wrapper 委托 | Task 2 Step 1 | Delegates + PropagatesError |
| §8 测试:budget batch(nil/err/distinct months/actuals) | Task 3 Step 2 | 5 改造 + 2 新 |
| §8 约束 6:grep 全 implementer | Task 1 Step 5 | 7 个(1 real + 6 fake)全补 |
| §9 风险 1–6 | 全 task | #1 Task 1 Step 5;#2 Task 3 Step 3(wire_gen.go 不改);#3 Task 1 raw SQL;#4 Task 3 1d 双闭包;#5 Task 3 1d `monthCache[month]=nil`;#6 Task 3 1c/1d 用 `tenantID` 参数 |
