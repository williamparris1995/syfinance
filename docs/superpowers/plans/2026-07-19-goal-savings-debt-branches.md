# savings+debt goal 分支 e2e Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补 Savings + DebtPayoff goal scheduler e2e（现只 Investment）。

**Architecture:** 扩展 `setupGoalHoldingHarness`（+debt client/schema + debtSvc + `SetAccountBalanceSource` + `SetDebtProgressSource`）。`TestGoalScheduler_SavingsBackedCurrentAmount`（account balance 800000）+ `TestGoalScheduler_DebtPayoffBackedCurrentAmount`（debt paid 200000）。

**Tech Stack:** Go testing + enttest SQLite · TDD

---

## Global Constraints

- **main-driven**（授权），commit `multi -m`
- **file scope**:仅 `goal_holding_scheduler_integration_test.go`（harness 扩展 + 2 test + 现有 holding test 改解构）
- **FK 顺序**:debt schema 先 Create（`goal_debt_links` 引用 debt）；seed debt 先于 goal link
- **target > paid**（避 auto-complete）
- **GetDebtsPaid 不需 SetAccountLookup**（debt NewService(repo) 即满足）
- 零 proto/schema/production 改（纯 test）
- TDD;commit multi -m

## File Structure

| 文件 | 改动 |
|---|---|
| [goal_holding_scheduler_integration_test.go](../../yucai/server/tests/goal_holding_scheduler_integration_test.go) | harness 扩展（+debt）+ TestGoalScheduler_SavingsBackedCurrentAmount + TestGoalScheduler_DebtPayoffBackedCurrentAmount + 现有 holding test 改解构 |

---

## Task 1: harness 扩展 + TestGoalScheduler_SavingsBackedCurrentAmount

**Files:**
- Modify: [goal_holding_scheduler_integration_test.go](../../yucai/server/tests/goal_holding_scheduler_integration_test.go)

- [ ] **Step 1: harness 扩展（+debt client/schema + debtSvc + 2 setter + 返 debtSvc）**

`setupGoalHoldingHarness` 加（import `debtent`/`debtrepo`/`debtapp`）：
- debt client：`debtClient := debtent.NewClient(debtent.Driver(drv))` + `debtClient.Schema.Create(ctx)`（**在 goal Schema.Create 前**，FK 顺序）+ `t.Cleanup(debtClient.Close)`
- debtSvc：`debtRepo := debtrepo.NewDebtRepository(debtClient)` + `debtSvc := debtapp.NewService(debtRepo)`
- setter：`goalSvc.SetAccountBalanceSource(acctSvc)`（acctSvc 已在 harness）+ `goalSvc.SetDebtProgressSource(debtSvc)`
- 返值加 `debtSvc *debtapp.Service`（签名 + return）

- [ ] **Step 2: 现有 holding test 改解构**

`TestGoalScheduler_HoldingBackedCurrentAmount` 的 `setupGoalHoldingHarness(t)` 解构加 `, _`（接住 debtSvc）。

- [ ] **Step 3: 写 TestGoalScheduler_SavingsBackedCurrentAmount**

追加：
```go
// TestGoalScheduler_SavingsBackedCurrentAmount verifies Savings goal progress
// = Σ linked account CurrentBalanceCents (via balSrc.GetAccountsBalance).
// Fixture: savings account(InitialBalance 800000) + savings goal(target 1000000)
// → current = 800000.
func TestGoalScheduler_SavingsBackedCurrentAmount(t *testing.T) {
	goalSvc, goalRepo, _, acctSvc, tenantID := setupGoalHoldingHarness(t)
	ctx := context.Background()

	// seed savings account (InitialBalance 800000 = 8000 元).
	acc, err := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID: tenantID, Name: "储蓄账户",
		AccountType: accountdomain.AccountTypeAsset, Category: accountdomain.AccountCategorySavings,
		CurrencyCode: "CNY", InitialBalanceCents: 800000,
	})
	if err != nil {
		t.Fatalf("CreateAccount savings: %v", err)
	}

	// seed Savings goal (linked to savings account, target 1000000).
	goal, err := goaldomain.NewGoal(tenantID, "储蓄目标", goaldomain.GoalTypeSavings,
		1000000, "CNY", nil, []uuid.UUID{acc.ID}, nil, "")
	if err != nil {
		t.Fatalf("NewGoal savings: %v", err)
	}
	if err := goalRepo.Save(ctx, goal); err != nil {
		t.Fatalf("goalRepo.Save: %v", err)
	}

	// SyncAllGoals: computeGoalProgress(Savings) → balSrc.GetAccountsBalance([acc.ID]) = 800000.
	count, err := goalSvc.SyncAllGoals(ctx, tenantID)
	if err != nil {
		t.Fatalf("SyncAllGoals: %v", err)
	}
	if count < 1 {
		t.Errorf("SyncAllGoals count=%d, want >= 1", count)
	}

	// Verify goal.CurrentAmountCents = 800000.
	got, err := goalRepo.FindAll(ctx, tenantID, nil, nil, goaldomain.PageRequest{PageSize: 10})
	if err != nil || len(got.Goals) == 0 {
		t.Fatalf("goalRepo.FindAll: err=%v len=%d", err, len(got.Goals))
	}
	if got.Goals[0].CurrentAmountCents != 800000 {
		t.Errorf("savings goal CurrentAmountCents: got %d, want 800000 (account balance)", got.Goals[0].CurrentAmountCents)
	}
}
```

- [ ] **Step 4: 跑 test + 全量回归**

Run: `cd yucai/server && go test ./tests/ -run "TestGoalScheduler_HoldingBacked|TestGoalScheduler_SavingsBacked" -v -count=1`
Expected: holding + savings PASS（holding 不破；savings current=800000）。

Run: `cd yucai/server && go test ./... -count=1 && go build ./...`
Expected: PASS + 绿。

- [ ] **Step 5: Commit**

```bash
cd e:/projects/syfinance
git add yucai/server/tests/goal_holding_scheduler_integration_test.go
git commit -m "test(goal): harness 扩展 debt + Savings goal e2e (account balance 800000)" -m "setupGoalHoldingHarness 扩展(+debt client/schema + debtSvc + SetAccountBalanceSource(acctSvc) + SetDebtProgressSource(debtSvc) + 返 debtSvc; 现有 holding test 改解构). TestGoalScheduler_SavingsBackedCurrentAmount: savings account(InitialBalance 800000)+ savings goal(target 1000000) -> SyncAllGoals -> balSrc.GetAccountsBalance=800000 -> current=800000. goal scheduler Savings 分支 e2e."
```

---

## Task 2: TestGoalScheduler_DebtPayoffBackedCurrentAmount

**Files:**
- Modify: `goal_holding_scheduler_integration_test.go`

- [ ] **Step 1: 写 TestGoalScheduler_DebtPayoffBackedCurrentAmount**

追加：
```go
// TestGoalScheduler_DebtPayoffBackedCurrentAmount verifies DebtPayoff goal progress
// = Σ (TotalPrincipal − RemainingPrincipal) of linked debts (via debtSrc.GetDebtsPaid).
// Fixture: debt(total 600000, EqualPrincipal 3月, 月 200000) + mark Schedule[0] paid
// → paid=200000, remaining=400000 + debt payoff goal(target 600000) → current=200000.
func TestGoalScheduler_DebtPayoffBackedCurrentAmount(t *testing.T) {
	goalSvc, goalRepo, _, _, debtSvc, tenantID := setupGoalHoldingHarness(t)  // 6 值(debtSvc 在 acctSvc 后)
	ctx := context.Background()

	// seed debt: total 600000, EqualPrincipal, 3-month term → 月 principal 200000.
	// CreateDebt via debtSvc (照 debt_integration_test 范式).
	debt, err := debtSvc.CreateDebt(ctx, debtapp.CreateDebtRequest{
		TenantID: tenantID, AccountID: uuid.New(), // debt account(any; GetDebtsPaid 不需)
		Name: "测试负债", AnnualRate: 0.05,
		Amortization: debtdomain.AmortizationEqualPrincipal,
		StartDate: time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		DueDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC), // 3 月 term
		TotalPrincipalCents: 600000,
		DebtType: debtdomain.BorrowedIn,
	})
	if err != nil {
		t.Fatalf("CreateDebt: %v", err)
	}
	debtID := debt.ID

	// mark Schedule[0] paid (paid=200000, remaining=400000).
	// 直调 domain: debtRepo.FindByID + MarkPaid(Schedule[0].ID) + Update.
	// (照 debt_integration_test 范式;implementer 调通 CreateDebt/MarkPaid/Update API)
	// [implementer:确认 CreateDebt 返 *DebtDetails(含 Schedule)或 FindByID;
	//  MarkPaid(Schedule[0].ID, uuid.New()) + debtRepo.Update 或 debtSvc.Update]

	// seed DebtPayoff goal (linked to debt, target 600000).
	goal, err := goaldomain.NewGoal(tenantID, "还款目标", goaldomain.GoalTypeDebtPayoff,
		600000, "CNY", nil, nil, []uuid.UUID{debtID}, "")
	if err != nil {
		t.Fatalf("NewGoal debtpayoff: %v", err)
	}
	if err := goalRepo.Save(ctx, goal); err != nil {
		t.Fatalf("goalRepo.Save: %v", err)
	}

	// SyncAllGoals: computeGoalProgress(DebtPayoff) → debtSrc.GetDebtsPaid([debtID]) = 600000-400000 = 200000.
	count, err := goalSvc.SyncAllGoals(ctx, tenantID)
	if err != nil {
		t.Fatalf("SyncAllGoals: %v", err)
	}
	if count < 1 {
		t.Errorf("SyncAllGoals count=%d, want >= 1", count)
	}

	// Verify goal.CurrentAmountCents = 200000 (600000 - 400000 remaining).
	got, err := goalRepo.FindAll(ctx, tenantID, nil, nil, goaldomain.PageRequest{PageSize: 10})
	if err != nil || len(got.Goals) == 0 {
		t.Fatalf("goalRepo.FindAll: err=%v len=%d", err, len(got.Goals))
	}
	if got.Goals[0].CurrentAmountCents != 200000 {
		t.Errorf("debtpayoff goal CurrentAmountCents: got %d, want 200000 (600000 total - 400000 remaining)", got.Goals[0].CurrentAmountCents)
	}
}
```
（implementer 调通：debtSvc.CreateDebt 签名 + Schedule mark paid 直调 domain；import `debtapp`/`debtdomain`）

- [ ] **Step 2: 跑 test + 全量回归**

Run: `cd yucai/server && go test ./tests/ -run TestGoalScheduler_DebtPayoffBackedCurrentAmount -v -count=1`
Expected: PASS（debt paid 200000）。调通：CreateDebt 签名 + MarkPaid + Update（照 debt_integration_test）。

Run: `cd yucai/server && go test ./... -count=1 && go build ./...`
Expected: PASS + 绿。

- [ ] **Step 3: Commit**

```bash
cd e:/projects/syfinance
git add yucai/server/tests/goal_holding_scheduler_integration_test.go
git commit -m "test(goal): DebtPayoff goal e2e (debt paid 200000 EqualPrincipal)" -m "TestGoalScheduler_DebtPayoffBackedCurrentAmount: debt(total 600000 EqualPrincipal 3月)+ mark Schedule[0] paid(paid 200000 remaining 400000)+ debt payoff goal(target 600000)-> SyncAllGoals -> debtSrc.GetDebtsPaid=200000 -> current=200000. goal scheduler DebtPayoff 分支 e2e."
```

---

## 全量验证(plan 收尾)

- [ ] `cd yucai/server && go test ./tests/ -run "TestGoalScheduler" -v -count=1` — holding + savings + debtpayoff 全 PASS
- [ ] `cd yucai/server && go test ./... -count=1` — 零回归
- [ ] `cd yucai/server && go build ./...` — build 绿
