# BorrowedOut networth bug fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修 production bug #4 —— networth `SumRemainingByCurrency` 不 filter DebtType → BorrowedOut receivable principal 落 liability。最小 fix liab filter(1 行)。

**Architecture:** `SumRemainingByCurrency` FindAll `typeFilter nil → &BorrowedIn`。liab 只 BorrowedIn(receivable 已在 asset account balance via double-write)。comment 同步 + test ExcludesBorrowedOut。

**Tech Stack:** Go testing · TDD

---

## Global Constraints

- **main-driven**(授权),commit `multi -m`
- **file scope**:`debt/application/service.go`(fix + comment)+ `account/application/service.go`(comment)+ `debt/application/sumbycurrency_test.go`(test)
- **fix 方案 B**:FindAll `typeFilter &BorrowedIn`(显式,非 Unspecified;SQL `WHERE debt_type='borrowed_in'`)
- **reviewer 纠正**:receivable 已在 asset(double-write);**不加 receivable source port**(double-count)
- **comment 同步**(防未来误判)
- 零 proto/schema/wire
- TDD;commit multi -m

## File Structure

| 文件 | 改动 |
|---|---|
| [debt/application/service.go](../../yucai/server/internal/debt/application/service.go) | SumRemainingByCurrency filter `&BorrowedIn` + comment |
| [account/application/service.go](../../yucai/server/internal/account/application/service.go) | comment:310-311 liab 说明 |
| [debt/application/sumbycurrency_test.go](../../yucai/server/internal/debt/application/sumbycurrency_test.go) | +TestSumRemainingByCurrency_ExcludesBorrowedOut |

---

## Task 1: fix SumRemainingByCurrency filter + comment + test

**Files:**
- Modify: [debt/application/service.go:162-183](../../yucai/server/internal/debt/application/service.go)(SumRemainingByCurrency)
- Modify: [debt/application/service.go:153-161](../../yucai/server/internal/debt/application/service.go)(comment)
- Modify: [account/application/service.go:310-311](../../yucai/server/internal/account/application/service.go)(comment)
- Modify: [debt/application/sumbycurrency_test.go](../../yucai/server/internal/debt/application/sumbycurrency_test.go)(+test)

- [ ] **Step 1: fix SumRemainingByCurrency filter BorrowedIn**

[debt/application/service.go:164-166](../../yucai/server/internal/debt/application/service.go):
```go
	page := domain.PageRequest{PageSize: 100}
	in := domain.BorrowedIn // networth liab 只含 borrowed-in;BorrowedOut receivable 已在 asset account balance via double-write
	for {
		result, err := s.repo.FindAll(ctx, tenantID, page, &in)
```
(原 `FindAll(ctx, tenantID, page, nil)` → `&in`)

- [ ] **Step 2: comment 同步(debt service.go:153-161)**

[debt/application/service.go:153-161](../../yucai/server/internal/debt/application/service.go) SumRemainingByCurrency doc:"every debt" → "every borrowed-in debt (BorrowedOut receivables excluded — tracked as asset account balances via double-write)"。

- [ ] **Step 3: comment 同步(account service.go:310-311)**

[account/application/service.go:310-311](../../yucai/server/internal/account/application/service.go) SumBalancesByCurrency doc:"liabilities are tracked separately via the debt module's SumRemainingByCurrency" → "liabilities (borrowed-in only) tracked via SumRemainingByCurrency; receivables (borrowed-out) tracked as asset account balances via debt double-write"。

- [ ] **Step 4: 写 TestSumRemainingByCurrency_ExcludesBorrowedOut(TDD RED)**

[debt/application/sumbycurrency_test.go](../../yucai/server/internal/debt/application/sumbycurrency_test.go)(照现有 test fake repo 范式 —— 确认 fake repo typeFilter support sumbycurrency_test.go:45-56):
```go
// TestSumRemainingByCurrency_ExcludesBorrowedOut verifies that BorrowedOut
// receivables are excluded from networth liabilities (only BorrowedIn counts).
// Bug root cause: original FindAll typeFilter=nil counted both types.
func TestSumRemainingByCurrency_ExcludesBorrowedOut(t *testing.T) {
	// seed 1 BorrowedIn (principal 5000) + 1 BorrowedOut (principal 3000) via fake repo
	// (照现有 sumbycurrency_test fake repo 范式;确认 fake repo 支持 DebtType seed + typeFilter)
	tenantID := uuid.New()
	repo := &fakeDebtRepo{debts: []domain.DebtDetails{
		{ID: uuid.New(), TenantID: tenantID, AccountID: uuid.New(), DebtType: domain.BorrowedIn, TotalPrincipalCents: 5000, ...},
		{ID: uuid.New(), TenantID: tenantID, AccountID: uuid.New(), DebtType: domain.BorrowedOut, TotalPrincipalCents: 3000, ...},
	}}
	svc := NewService(repo)
	svc.SetAccountLookup(...)  // 照现有 test fake accountLookup

	got, err := svc.SumRemainingByCurrency(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("SumRemainingByCurrency: %v", err)
	}
	// only BorrowedIn 5000 (BorrowedOut 3000 excluded)
	total := int64(0)
	for _, amt := range got {
		total += amt
	}
	if total != 5000 {
		t.Errorf("SumRemainingByCurrency total: got %d, want 5000 (BorrowedIn only, BorrowedOut excluded)", total)
	}
}
```
(implementer 调通:fake repo DebtDetails seed 字段 + fake accountLookup + RemainingPrincipal 计算;照现有 sumbycurrency_test 范式)

- [ ] **Step 5: 跑 test,验证 RED(fix 前)→ GREEN(fix 后)**

Run: `cd yucai/server && go test ./internal/debt/application/ -run TestSumRemainingByCurrency_ExcludesBorrowedOut -v -count=1`
Expected: fix 前 RED(total 8000 = 5000+3000,BorrowedOut 未排除);fix 后 GREEN(total 5000)。

- [ ] **Step 6: 全量回归**

Run: `cd yucai/server && go test ./... -count=1 && go build ./...`
Expected: PASS + 绿(零回归)。

- [ ] **Step 7: Commit**

```bash
cd e:/projects/syfinance
git add yucai/server/internal/debt/application/service.go yucai/server/internal/account/application/service.go yucai/server/internal/debt/application/sumbycurrency_test.go
git commit -m "fix(networth): SumRemainingByCurrency filter BorrowedIn (BorrowedOut receivable 不计 liab)" -m "修 production bug #4: SumRemainingByCurrency FindAll typeFilter nil -> &BorrowedIn. liab 只 BorrowedIn(BorrowedOut receivable 排除). BorrowedOut receivable 已在 asset account balance via double-write(SumBalancesByCurrency filter asset 含 receivable). reviewer 'receivable 未 mirror' 误判(实际已 asset; fix liab filter 非 receivable source, 加 source double-count). comment 同步(debt + account service.go). test ExcludesBorrowedOut(sumbycurrency_test 现全 BorrowedIn = bug 根因). 零 proto/schema/wire."
```

---

## 全量验证(plan 收尾)

- [ ] `cd yucai/server && go test ./internal/debt/application/ -run TestSumRemainingByCurrency -v -count=1` — ExcludesBorrowedOut + 现有 test PASS
- [ ] `cd yucai/server && go test ./... -count=1` — 零回归
- [ ] `cd yucai/server && go build ./...` — build 绿
