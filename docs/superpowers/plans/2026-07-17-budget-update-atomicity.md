# budget repo.Update 原子性 + conflict mapping · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `BudgetRepository.Update` 包 **ent 事务**(delete items + insert items + budget UPDATE 原子,失败回滚)+ **optimistic lock 冲突 → `codes.Aborted`**(现落 NotFound/Internal,因 ent NotFound msg 含 "not found" 被 mapError 先匹配)。

**Architecture:** `repo.Update` 内部开 `r.client.Tx(ctx)`,把 delete old items + insert new items + budget UPDATE(WHERE Version(v-1))放同一 tx,任一失败 `Rollback`。budget UPDATE 失败时 `budgetent.IsNotFound(err)` 检测(WHERE 0 行 = 并发改,因 caller 先 FindByID 确认存在)→ 返 `"optimistic lock: ..."` 纯措辞(**不 `%w` ent err**,避免 msg 含 "not found")→ budget mapError 已有的 `"optimistic lock"` 分支 → `codes.Aborted`。**签名不变 → 4 caller(AddBudgetItem/RemoveBudgetItem/UpdateBudget/ComputeActuals)自动受益**。

**Tech Stack:** Go · ent(`*budgetent.Tx` + `budgetent.IsNotFound`)· TDD

---

## Global Constraints

(每个 task 隐含包含;从 spec §3/§9 + CLAUDE.md 提取)

1. **英文 slog**(无 CJK)—— 本 task 不涉 slog 但约束在。
2. **`repo.Update` 签名不变**(`Update(ctx, *domain.Budget) error`)→ 4 caller 零改 + 约束 6 无 implementer 影响(`BudgetRepository` interface 不变)。
3. **optimistic lock err msg 绝不含 "not found"** —— budget mapError switch 顺序 `not found → invalid/must → optimistic lock → default`,"not found" 在前;含 "not found" 会被先匹配 `codes.NotFound` 而非 `codes.Aborted`。用**纯措辞 `"optimistic lock: budget X concurrently modified, refresh and retry"`,不 `%w` ent NotFound err**(其 Error() = `"ent: budget not found"`)。
4. **mapError 不改**([budget_handler.go:283-295](../../yucai/server/internal/budget/adapter/driving/grpc/budget_handler.go#L283) 已有 `"optimistic lock"` → `codes.Aborted` 分支)。repo 措辞修后自动路由。
5. **`_ = tx.Rollback()`** 忽略 Rollback 返值(失败通常 tx 已自动回滚/连接问题,照 ent 惯例,不 propagate)。
6. **零 proto / client / wire / ent schema** —— 仅 `repo.Update` 实现 + 测试。
7. **commit message 用 multi `-m` flag**(Bash here-string 坏,budget M2 Task 2 教训)。
8. **TDD + frequent commits**。

---

## File Structure

| 文件 | 责任 | 改动 |
|---|---|---|
| [budget/adapter/driven/repository/budget_repo.go](../../yucai/server/internal/budget/adapter/driven/repository/budget_repo.go) | ent repo | `Update`(line 165-199)包 ent tx + `budgetent.IsNotFound` → "optimistic lock" 措辞 |
| [tests/budget_integration_test.go](../../yucai/server/tests/budget_integration_test.go) | integration test | +`TestBudgetRepoUpdate_TxAtomicOnOptimisticLock`(回滚断言)+ `TestBudgetRepoUpdate_OptimisticLockErrMapping`(措辞断言) |

---

## Task 1: repo.Update ent tx + optimistic lock → Aborted

单 task(内聚:1 repo 方法 + 2 测试)。无 interface/proto/wire 改动。

**Files:**
- Modify: [budget/adapter/driven/repository/budget_repo.go](../../yucai/server/internal/budget/adapter/driven/repository/budget_repo.go)(`Update` line 165-199 整段替换)
- Modify: [tests/budget_integration_test.go](../../yucai/server/tests/budget_integration_test.go)(+2 测试,需补 import `"strings"`)

**Interfaces:**
- Consumes: 现有 `r.client *budgetent.Client` + `budgetitem`/`budget` ent predicate;ent gen 的 `*budgetent.Tx`([tx.go](../../yucai/server/internal/budget/ent/tx.go):`Budget`/`BudgetItem` sub-clients + `Commit()`/`Rollback()`)+ `budgetent.IsNotFound`([ent.go:209](../../yucai/server/internal/budget/ent/ent.go#L209));`setupBudgetTestDB` + `budgetrepo.NewBudgetRepository` + `budgetdomain.NewBudget`(budget_integration_test 现有)
- Produces: `repo.Update` 原子 + optimistic lock → Aborted-mappable(4 caller 受益)

- [ ] **Step 1: 写 2 测试(失败态)**

追加到 [budget_integration_test.go](../../yucai/server/tests/budget_integration_test.go)。补 import `"strings"`(若未有)。

```go
// TestBudgetRepoUpdate_TxAtomicOnOptimisticLock verifies that when the budget
// UPDATE fails the optimistic lock (WHERE version mismatch), the preceding
// items delete+insert are rolled back — the whole Update is atomic. Under the
// pre-fix non-transactional repo, items would be left in the new state while
// the budget row stayed old.
func TestBudgetRepoUpdate_TxAtomicOnOptimisticLock(t *testing.T) {
	client := setupBudgetTestDB(t)
	repo := budgetrepo.NewBudgetRepository(client)
	ctx := context.Background()
	tenantID := uuid.New()

	origAcc := uuid.New()
	b, err := budgetdomain.NewBudget(tenantID, "B", "2026-05", "CNY",
		[]budgetdomain.BudgetItem{{AccountID: origAcc, PlannedAmountCents: 10000}})
	if err != nil {
		t.Fatalf("NewBudget: %v", err)
	}
	if err := repo.Save(ctx, b); err != nil {
		t.Fatalf("Save: %v", err)
	}

	// Force optimistic-lock failure: bump version past what the DB has so the
	// WHERE Version(stale.Version-1) predicate matches 0 rows.
	stale := *b
	stale.Update("B2", "USD", []budgetdomain.BudgetItem{
		{AccountID: uuid.New(), PlannedAmountCents: 20000},
	})
	stale.Version = b.Version + 2 // WHERE Version(b.Version+1) != DB b.Version -> NotFound
	if err := repo.Update(ctx, &stale); err == nil {
		t.Fatal("expected optimistic lock error, got nil")
	}

	// TX atomicity: the items delete+insert must have rolled back — FindByID
	// should still see the ORIGINAL single item, not the replacement.
	got, err := repo.FindByID(ctx, tenantID, b.ID)
	if err != nil {
		t.Fatalf("FindByID after failed update: %v", err)
	}
	if len(got.Items) != 1 {
		t.Fatalf("tx did not roll back items: got %d items, want 1 (original)", len(got.Items))
	}
	if got.Items[0].AccountID != origAcc {
		t.Errorf("item account after rollback: got %s, want %s (original)", got.Items[0].AccountID, origAcc)
	}
	if got.TotalAmountCents != 10000 {
		t.Errorf("total after rollback: got %d, want 10000 (original)", got.TotalAmountCents)
	}
	if got.Name != "B" || got.CurrencyCode != "CNY" {
		t.Errorf("budget fields changed despite rollback: name=%q currency=%q", got.Name, got.CurrencyCode)
	}
}

// TestBudgetRepoUpdate_OptimisticLockErrMapping verifies the optimistic-lock
// error is phrased so budget mapError routes it to codes.Aborted (not
// codes.NotFound): the message MUST contain "optimistic lock" and MUST NOT
// contain "not found" (mapError checks "not found" before "optimistic lock").
func TestBudgetRepoUpdate_OptimisticLockErrMapping(t *testing.T) {
	client := setupBudgetTestDB(t)
	repo := budgetrepo.NewBudgetRepository(client)
	ctx := context.Background()
	tenantID := uuid.New()

	b, err := budgetdomain.NewBudget(tenantID, "B", "2026-05", "CNY",
		[]budgetdomain.BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 10000}})
	if err != nil {
		t.Fatalf("NewBudget: %v", err)
	}
	if err := repo.Save(ctx, b); err != nil {
		t.Fatalf("Save: %v", err)
	}

	stale := *b
	stale.Update("B2", "CNY", []budgetdomain.BudgetItem{{AccountID: uuid.New(), PlannedAmountCents: 20000}})
	stale.Version = b.Version + 2
	err = repo.Update(ctx, &stale)
	if err == nil {
		t.Fatal("expected optimistic lock error, got nil")
	}
	if !strings.Contains(err.Error(), "optimistic lock") {
		t.Errorf("err missing 'optimistic lock' phrase (mapError needs it for Aborted): %q", err.Error())
	}
	if strings.Contains(err.Error(), "not found") {
		t.Errorf("err leaks 'not found' (mapError would route to codes.NotFound, not Aborted): %q", err.Error())
	}
}
```

- [ ] **Step 2: 跑测试看失败**

Run: `cd yucai/server && go test ./tests/... -run 'TestBudgetRepoUpdate_TxAtomicOnOptimisticLock|TestBudgetRepoUpdate_OptimisticLockErrMapping' -count=1 -v`
Expected: FAIL
- `TxAtomicOnOptimisticLock`:items 是 new set(非 original)—— 非事务致 delete+insert 未回滚。
- `OptimisticLockErrMapping`:err 含 "not found"(ent NotFound "ent: budget not found" 经 `fmt.Errorf("update budget: %w", err)` 渗入)+ 不含 "optimistic lock"。

(若 `strings` 未 import → 编译错,先补 import。)

- [ ] **Step 3: 改 repo.Update — ent tx + optimistic lock 检测**

[budget_repo.go:165-199](../../yucai/server/internal/budget/adapter/driven/repository/budget_repo.go#L165) 整段替换。M1 Task 1 已补 `SetCurrencyCode` + delete err;本 follow-up 加 tx 包裹 + `IsNotFound` → "optimistic lock":

```go
// Update persists changes to a budget atomically (ent tx: delete old items +
// insert new items + update budget) with optimistic locking. A version
// conflict (concurrent edit since the caller's FindByID) returns an
// "optimistic lock: ..." error with NO "not found" substring, so budget
// mapError routes it to codes.Aborted (not codes.NotFound — the switch checks
// "not found" before "optimistic lock"). All callers (AddBudgetItem /
// RemoveBudgetItem / UpdateBudget / ComputeActuals) share this path, so all
// inherit atomicity + correct conflict mapping.
func (r *BudgetRepository) Update(ctx context.Context, b *domain.Budget) error {
	tx, err := r.client.Tx(ctx)
	if err != nil {
		return fmt.Errorf("begin budget tx: %w", err)
	}

	// Delete old items (tx-scoped).
	if _, err := tx.BudgetItem.Delete().
		Where(budgetitem.BudgetID(b.ID)).
		Exec(ctx); err != nil {
		_ = tx.Rollback()
		return fmt.Errorf("delete old budget items: %w", err)
	}

	// Insert new items (tx-scoped, full replace — item IDs change, budget ID stable).
	for _, item := range b.Items {
		if _, err := tx.BudgetItem.Create().
			SetID(item.ID).
			SetBudgetID(item.BudgetID).
			SetAccountID(item.AccountID).
			SetPlannedAmountCents(item.PlannedAmountCents).
			SetActualAmountCents(item.ActualAmountCents).
			SetNotes(item.Notes).
			Save(ctx); err != nil {
			_ = tx.Rollback()
			return fmt.Errorf("insert budget item: %w", err)
		}
	}

	// Update budget (tx-scoped, optimistic lock WHERE version = v-1).
	if _, err := tx.Budget.UpdateOneID(b.ID).
		Where(budget.Version(b.Version - 1)).
		SetName(b.Name).
		SetCurrencyCode(b.CurrencyCode).
		SetTotalAmountCents(b.TotalAmountCents).
		SetIsActive(b.IsActive).
		SetVersion(b.Version).
		SetUpdatedAt(b.UpdatedAt).
		Save(ctx); err != nil {
		_ = tx.Rollback()
		if budgetent.IsNotFound(err) {
			// WHERE matched 0 rows — budget was modified concurrently since
			// FindByID (caller confirmed existence). Pure phrasing, no "not
			// found", so mapError -> codes.Aborted (refresh-and-retry signal).
			return fmt.Errorf("optimistic lock: budget %s was modified concurrently, refresh and retry", b.ID)
		}
		return fmt.Errorf("update budget: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit budget tx: %w", err)
	}
	return nil
}
```

> import 已含 `budgetent "github.com/yucai/server/internal/budget/ent"`(budget_repo.go line 10)+ `budget`/`budgetitem` predicate。`budgetent.IsNotFound` + `r.client.Tx` + `tx.Budget`/`tx.BudgetItem`/`tx.Commit()`/`tx.Rollback()` 均来自 budget ent gen。

- [ ] **Step 4: 跑测试看通过**

Run: `cd yucai/server && go test ./tests/... -run 'TestBudgetRepoUpdate_TxAtomicOnOptimisticLock|TestBudgetRepoUpdate_OptimisticLockErrMapping' -count=1 -v`
Expected: PASS(both)—— tx 回滚 items 到 original;err 含 "optimistic lock" 不含 "not found"。

- [ ] **Step 5: 回归 —— 现有 budget 测试不破坏**

Run: `cd yucai/server && go test ./internal/budget/... ./tests/... -run TestBudget -count=1`
Expected: PASS —— 新 2 测 + M1 `TestBudgetRepoUpdate`/`TestBudgetRepoUpdate_OptimisticLock` + `TestBudgetUpdate` + `TestBudgetCRUD`(AddBudgetItem/RemoveBudgetItem 路径,也调 repo.Update,现走 tx)全过。tx 包裹不影响正常路径(单连接 tx,commit 成功)。

Run: `cd yucai/server && go build ./...`
Expected: 成功(interface 不变 → 无 implementer 影响;NewService 不变 → wire 不动)

Run: `cd yucai/server && go test ./... -count=1`
Expected: PASS(全量,确认 tx 改动不破坏其他包)

- [ ] **Step 6: Commit**

```bash
cd e:/projects/syfinance
git add yucai/server/internal/budget/adapter/driven/repository/budget_repo.go \
  yucai/server/tests/budget_integration_test.go
git commit -m "fix(budget): repo.Update atomic tx + optimistic lock -> Aborted" -m "Wrap delete items + insert items + budget UPDATE in an ent tx (rollback on err) so a failed optimistic-lock budget UPDATE no longer leaves items mutated. On ent IsNotFound (WHERE version mismatch = concurrent edit since FindByID), return 'optimistic lock: budget X concurrently modified, refresh and retry' (pure phrasing, no 'not found' so mapError routes to codes.Aborted, not NotFound). 4 callers (Add/Remove/Update/ComputeActuals) inherit, signature unchanged. Zero proto/client/wire/schema."
```

---

## Spec coverage 矩阵

| spec 决策/章节 | 落地 | 备注 |
|---|---|---|
| §3 #1 tx 范围=repo.Update | Task 1 Step 3 | 签名不变,4 caller 受益 |
| §3 #2 IsNotFound 检测 | Task 1 Step 3 | `budgetent.IsNotFound(err)` |
| §3 #3 纯措辞不 %w | Task 1 Step 3 + 测 Step 1 `OptimisticLockErrMapping` | 不含 "not found" |
| §3 #4 其他 err %w | Task 1 Step 3 | `"update budget: %w"` |
| §3 #5 mapError 不改 | Task 1(不动 handler) | 已有分支 |
| §3 #6 tenant-scoped defer | 全 plan 不涉 | out of scope |
| §5 repo + 测试 2 层 | Task 1 | |
| §6.1 repo.Update tx 代码 | Task 1 Step 3 | 逐字(已确认 ent API) |
| §6.2 mapError 不改 | Task 1 | |
| §8 测试 tx 原子性 + Aborted mapping | Task 1 Step 1 | 2 测(回滚断言 + 措辞断言) |
| §9 风险 1 ent API | 已确认 | `*budgetent.Tx` Budget/BudgetItem + IsNotFound |
| §9 风险 2 msg 不含 not found | Task 1 Step 1 测 + Step 3 代码 | 评审重点 |
| §9 风险 5 caller 不改 | Task 1 Step 5 回归 | 4 caller 测 |
