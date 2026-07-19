# holding CreatedAt bug fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修 production `Holding.CreatedAt` bug —— `BuyHolding` 创建 holding 时 `CreatedAt=zero` → `portfolioCAGR` 对所有用户 silently nil。方案 B:adapter `SaveOrUpdate` Create 分支 `IsZero` fallback。

**Architecture:** `holding_repo.go` `SaveOrUpdate` Create 分支 —— `h.CreatedAt.IsZero()` 时不 `SetCreatedAt` → ent schema `Default(time.Now)` 生效。unit test 锁 adapter(`CreatedAt!=zero`)+ S4 注释更新(M1 misleading)。

**Tech Stack:** Go testing + enttest SQLite · TDD

---

## Global Constraints

- **main-driven**(授权,直接 main commit),commit `multi -m`
- **file scope**:`holding_repo.go`(改 SaveOrUpdate Create)+ `holding_repo_test.go`(新 unit test)+ `holding_performance_integration_test.go`(S4 注释)
- ent schema `Default(time.Now).Immutable()`([holding.go:44-46](../../yucai/server/internal/holding/ent/schema/holding.go))保留 —— 只修"被 SetCreatedAt(zero) 错误覆盖"
- **TDD**:unit test RED(Create with zero → 持久化 zero,fail)→ GREEN(fix IsZero fallback → ent default 生效)
- **零回归**:全量 server 测 pass + holding e2e 套件 S1-S4 pass(S4 预创 `SetCreatedAt` 非零 → `IsZero=false` → 照 set,不变)
- English slog(无 CJK 在 log 串)—— 本 task 不涉 slog

## File Structure

| 文件 | 改动 |
|---|---|
| [holding_repo.go](../../yucai/server/internal/holding/adapter/driven/repository/holding_repo.go) | `SaveOrUpdate` Create 分支(~L30-36):`IsZero` fallback |
| [holding_repo_test.go](../../yucai/server/internal/holding/adapter/driven/repository/holding_repo_test.go) | 新 `TestSaveOrUpdate_CreateFillsDefaultCreatedAt` |
| [holding_performance_integration_test.go](../../yucai/server/tests/holding_performance_integration_test.go) | S4 预创 holding 注释更新(M1 misleading) |

---

## Task 1: fix SaveOrUpdate Create IsZero fallback + unit test + S4 注释

**Files:**
- Modify: [holding_repo.go](../../yucai/server/internal/holding/adapter/driven/repository/holding_repo.go) `SaveOrUpdate` Create 分支(~L30-36)
- Modify: [holding_repo_test.go](../../yucai/server/internal/holding/adapter/driven/repository/holding_repo_test.go)(新 test;`package repository`,用现有 `setupHoldingTestDB` helper [testdb_test.go:19-40](../../yucai/server/internal/holding/adapter/driven/repository/testdb_test.go))
- Modify: [holding_performance_integration_test.go](../../yucai/server/tests/holding_performance_integration_test.go) S4 预创注释

**Interfaces:**
- Produces:`SaveOrUpdate(ctx, h)` Create 分支:`h.CreatedAt.IsZero()` → 不 `SetCreatedAt` → ent `Default(time.Now)` 生效;非 zero → 照 `SetCreatedAt(h.CreatedAt)`(向后兼容 test seed / S4 预创)

- [ ] **Step 1: 写 failing unit test(RED)**

在 `holding_repo_test.go` 加:
```go
func TestSaveOrUpdate_CreateFillsDefaultCreatedAt(t *testing.T) {
	client := setupHoldingTestDB(t) // 现有 helper(testdb_test.go:19-40)
	repo := NewHoldingRepository(client)
	ctx := context.Background()

	// seed holding with CreatedAt zero(模拟 BuyHolding omit)。
	h := &domain.Holding{
		ID:         uuid.New(),
		TenantID:   uuid.New(),
		AccountID:  uuid.New(),
		SecurityID: uuid.New(),
		// CreatedAt zero(模拟 BuyHolding service.go:96-100 omit)
	}
	if err := repo.SaveOrUpdate(ctx, h); err != nil {
		t.Fatalf("SaveOrUpdate: %v", err)
	}

	// 查回 CreatedAt 非 zero(ent Default time.Now 经 IsZero fallback 生效)。
	got, err := repo.FindByAccountAndSecurity(ctx, h.TenantID, h.AccountID, h.SecurityID)
	if err != nil || got == nil {
		t.Fatalf("FindByAccountAndSecurity: %v got=%v", err, got)
	}
	if got.CreatedAt.IsZero() {
		t.Error("CreatedAt zero after SaveOrUpdate(Create with zero); want ent Default(time.Now) via IsZero fallback")
	}
}
```

- [ ] **Step 2: 跑 test 验证 RED**

Run: `cd yucai/server && go test ./internal/holding/adapter/driven/repository/ -run TestSaveOrUpdate_CreateFillsDefaultCreatedAt -v -count=1`
Expected: **FAIL** —— `CreatedAt zero after SaveOrUpdate(Create with zero)`(当前 `SetCreatedAt(h.CreatedAt=zero)` 覆盖 ent default)。

- [ ] **Step 3: fix —— SaveOrUpdate Create 分支 IsZero fallback**

[holding_repo.go:30-40](../../yucai/server/internal/holding/adapter/driven/repository/holding_repo.go) Create 分支,改链式 + 条件 SetCreatedAt:
```go
// Create new
create := r.client.Holding.Create().
    SetID(h.ID).SetTenantID(h.TenantID).
    SetAccountID(h.AccountID).SetSecurityID(h.SecurityID).
    SetQuantity(h.Quantity).SetAvgCostCents(h.AvgCostCents).
    SetVersion(h.Version).SetUpdatedAt(h.UpdatedAt)
// CreatedAt: 显式值透传;zero 时不 SetCreatedAt -> ent Default(time.Now) 生效
// (修 BuyHolding omit CreatedAt 致 portfolioCAGR nil bug;e2e 套件 Task 5 发现)。
if !h.CreatedAt.IsZero() {
    create = create.SetCreatedAt(h.CreatedAt)
}
if _, err := create.Save(ctx); err != nil {
    return fmt.Errorf("create holding: %w", err)
}
return nil
```
(原 `SetCreatedAt(h.CreatedAt)` 从无条件链中移除,改为 `if !IsZero` 条件;Update 分支 L42-51 不动。)

- [ ] **Step 4: 跑 test 验证 GREEN**

Run: `cd yucai/server && go test ./internal/holding/adapter/driven/repository/ -run TestSaveOrUpdate_CreateFillsDefaultCreatedAt -v -count=1`
Expected: **PASS** —— CreatedAt 非 zero(ent Default 生效)。

- [ ] **Step 5: 全量回归**

Run: `cd yucai/server && go test ./... -count=1`
Expected: PASS(零回归 —— holding e2e 套件 S1-S4 仍 pass:S4 预创 `SetCreatedAt` 非零 → `IsZero=false` → 照 set;现有 repo test 不破)。

Run: `cd yucai/server && go build ./...`
Expected: 绿(无 error)。

- [ ] **Step 6: S4 注释更新(M1 misleading)**

[holding_performance_integration_test.go](../../yucai/server/tests/holding_performance_integration_test.go) TestS4 预创 holding 注释块(原"mirrors the production state where holdings have been alive since their first trade date"),改为:
```
// Pre-create holdings with explicit CreatedAt to simulate a "bought in the
// past" scenario (ent time.Now at persistence != SetNow eval date 2021-01-01).
// Production BuyHolding now sets CreatedAt=ent time.Now (fixed via
// holding_repo SaveOrUpdate Create IsZero fallback — see spec
// 2026-07-19-holding-createdat-bug-design.md). This pre-create isolates the
// CAGR math test from that production path (CreatedAt=now would make
// earliest > eval -> CAGR degrade). Not a bug workaround.
```

- [ ] **Step 7: Commit**

```bash
cd e:/projects/syfinance
git add yucai/server/internal/holding/adapter/driven/repository/holding_repo.go \
        yucai/server/internal/holding/adapter/driven/repository/holding_repo_test.go \
        yucai/server/tests/holding_performance_integration_test.go
git commit -m "fix(holding): SaveOrUpdate Create IsZero fallback (CreatedAt bug -> portfolioCAGR nil)" -m "holding_repo SaveOrUpdate Create 分支 h.CreatedAt.IsZero() 时不 SetCreatedAt -> ent Default(time.Now) 生效. 修 BuyHolding omit CreatedAt(zero)覆盖 ent default 致 production portfolioCAGR 对所有用户 silently nil(earliestHoldingCreated zero -> service.go:1554 guard skip). Update 分支不动(已不 SetCreatedAt). unit test TestSaveOrUpdate_CreateFillsDefaultCreatedAt 锁 adapter RED->GREEN. S4 预创注释更新(M1 misleading). 零回归(S4 预创 SetCreatedAt 非零 IsZero=false 不变). e2e 套件 Task 5 发现, reviewer 诊断."
```

---

## 全量验证(plan 收尾)

- [ ] `cd yucai/server && go test ./internal/holding/adapter/driven/repository/ -run TestSaveOrUpdate_CreateFillsDefaultCreatedAt -v -count=1` — PASS
- [ ] `cd yucai/server && go test ./tests/ -run "TestS[1-4]" -v -count=1` — S1-S4 全 PASS(零回归)
- [ ] `cd yucai/server && go test ./... -count=1` — 零回归
- [ ] `cd yucai/server && go build ./...` — build 绿
