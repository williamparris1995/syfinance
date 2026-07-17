# budget M3 · actuals 折算到 budget 币种 · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** budget item actuals(account 币种 entry Σ)折算到 **budget.CurrencyCode**,使 `total_actual` / `usage_pct` 统一 budget 币种(item planned 已 budget 币种)。照 networth `ConvertToBase` + `RateHistoryRepository` 范式。

**Architecture:** budget domain 新 `AccountCurrencySource` port(accountID→currency_code);budget application import `currencydomain`(ConvertToBase + RateHistoryRepository,照 networth 共享基础);`Service` 加 `rateRepo` + `accountCur` field + `NewService` 加 2 参;`computeActualsReadTime`/`computeActualsReadTimeBatch` 改折算(per item:account currency → rate(budget month 末日)→ ConvertToBase);nil port → M2 raw 行为(不折算);wire 注入(budget 不 import account domain,adapter bridge account repo)。**零 proto/schema,UI 不改**(actuals 已 budget 币种)。

**Tech Stack:** Go · ent · DDD 四层 + wire 手改 · TDD

---

## Global Constraints

(每个 task 隐含包含;从 spec §3/§9 + CLAUDE.md 提取)

1. **英文 slog**(无 CJK)。
2. **budget import `currencydomain`**(ConvertToBase 纯函数 + RateHistoryRepository interface type)—— 照 networth(currency 共享基础,非业务 domain)。
3. **budget 不 import account domain** —— `AccountCurrencySource` port(budget domain);wire adapter bridge(holdingRateAdapter 范式)。
4. **rate 时机** = budget **month 末日**(`monthRange(month).to`)—— actuals 是历史,用历史 rate(非 time.Now);`FindRate` nearest(currency rate_history);缺失/err → 降级**原币 + slog**(best-effort)。
5. **nil port**(rateRepo/accountCur)→ **M2 raw 行为**(不折算,account 币种 cents)。
6. **单币种优化**:account 币种 == budget 币种 → 跳过 rate 查询/折算。
7. **`NewService` 加 2 参**(`rateRepo` + `accountCurSource`)→ 签名变 → 全调用方(wire/providers.go `provideBudgetService` + tests/budget_integration_test + budget/application/service_test)改 —— **M1 教训:grep 全 NewService 调用方含 tests/ 集成测**。
8. **wire_gen.go 手改**(Task 2,`provideBudgetService` 签名变时)—— memory `yucai-wire-handmaintained`;不跑 wire CLI。Task 1 `provideBudgetService` 签名不变(repo+txnSvc,body 调 NewService(...,nil,nil))→ wire_gen.go 不改。
9. **`ComputeActuals` persist 不折算**(范围外,保留 M1 单 entryFunc 原币)。
10. **零 proto/client/schema**,commit multi `-m`(Bash here-string 坏),TDD。

---

## File Structure

| 文件 | 责任 | 改动 |
|---|---|---|
| [budget/domain/account_source.go](../../yucai/server/internal/budget/domain/account_source.go) | 新 `AccountCurrencySource` port | 新文件:`CurrencyCodes(ctx, tenantID) (map[uuid.UUID]string, error)` |
| [budget/application/service.go](../../yucai/server/internal/budget/application/service.go) | `Service` | +`rateRepo currencydomain.RateHistoryRepository` + `accountCur domain.AccountCurrencySource` field;`NewService` +2 参;import currencydomain;折算 helper(`accountCurrencies`/`budgetRate`/`convertToBudget`/`accountNet`/`monthEnd`);`computeActualsReadTime`/`computeActualsReadTimeBatch` 改折算 |
| [budget/application/service_test.go](../../yucai/server/internal/budget/application/service_test.go) | app test | M2 7 测 `NewService(repo, nil, entryMonthFunc)` → `(..., nil, nil)`;+多币种折算测(fake rateRepo + fake accountCur,照 networth fakeRateRepo) |
| [budget/adapter/driven/repository/budget_repo.go](../../yucai/server/internal/budget/adapter/driven/repository/budget_repo.go) | (不改) | — |
| [tests/budget_integration_test.go](../../yucai/server/tests/budget_integration_test.go) | integration | `setupBudgetTestService` `NewService(repo, nil, nil)` → `(repo, nil, nil, nil, nil)` |
| [wire/providers.go](../../yucai/server/wire/providers.go) | wire | Task 1:`provideBudgetService` body `NewService(..., nil, nil)`;Task 2:签名 +rateRepo +accountCur + `accountCurrencyAdapter`(FindAllForBackup)+ `provideAccountCurrencySource` |
| [wire/wire_gen.go](../../yucai/server/wire/wire_gen.go) | wire gen(手改) | Task 2:`provideBudgetService` 调用加 rateRepo(复用 `currencyRateHistoryRepo`)+ accountCurSource(新变量) |

---

## Task 1: budget domain port + application 折算(nil port = M2 行为)

domain port + Service 折算逻辑 + service_test(fake port 测折算)。`provideBudgetService` body 调 `NewService(..., nil, nil)`(**签名不变** → wire_gen.go 不改 → build 绿)。nil rateRepo/accountCur → M2 raw 行为(不折算,全测不回归)。

**Files:**
- Create: [budget/domain/account_source.go](../../yucai/server/internal/budget/domain/account_source.go)
- Modify: [budget/application/service.go](../../yucai/server/internal/budget/application/service.go)
- Modify: [budget/application/service_test.go](../../yucai/server/internal/budget/application/service_test.go)
- Modify: [tests/budget_integration_test.go](../../yucai/server/tests/budget_integration_test.go)(`setupBudgetTestService` NewService 5 参)
- Modify: [wire/providers.go](../../yucai/server/wire/providers.go)(`provideBudgetService` body `NewService(..., nil, nil)`)

**Interfaces:**
- Consumes: M2 `entryMonthFunc` + `computeActualsReadTime`/`computeActualsReadTimeBatch` + `monthRange`;`currencydomain.ConvertToBase` + `RateHistoryRepository`(networth 范式);networth `fakeRateRepo`(service_test 范式)
- Produces: `AccountCurrencySource` port + 折算 Service(NewService 5 参)

- [ ] **Step 1: 写 domain port**

Create [budget/domain/account_source.go](../../yucai/server/internal/budget/domain/account_source.go)(照 networth domain `AccountBalanceSource` 范式):

```go
package domain

import (
	"context"

	"github.com/google/uuid"
)

// AccountCurrencySource is a port for looking up account currency codes
// (budget does not import account domain — mirrors networth's AccountBalanceSource
// / goal's AccountMarketValueSource pattern). Used by M3 actuals conversion to
//折算 per-item actuals from the account's currency to the budget's currency.
type AccountCurrencySource interface {
	// CurrencyCodes returns account_id -> currency_code for the tenant's accounts.
	// Budget looks up each item's account currency to drive ConvertToBase.
	// Callers should cache the result per request (one query per ListBudgets).
	CurrencyCodes(ctx context.Context, tenantID uuid.UUID) (map[uuid.UUID]string, error)
}
```

- [ ] **Step 2: 写 application 多币种折算测(失败态)**

追加到 [service_test.go](../../yucai/server/internal/budget/application/service_test.go)。需 import `currencydomain "github.com/yucai/server/internal/currency/domain"` + `"time"`(已有)+ `"sort"`(若断言 map 顺序)。照 networth `fakeRateRepo` 范式:

```go
// fakeAccountCur implements domain.AccountCurrencySource from a static map.
type fakeAccountCur struct {
	codes map[uuid.UUID]string
	err   error
}

func (f *fakeAccountCur) CurrencyCodes(_ context.Context, _ uuid.UUID) (map[uuid.UUID]string, error) {
	return f.codes, f.err
}

// fakeRateRepo implements currencydomain.RateHistoryRepository from a static
// code->rate map (照 networth fakeRateRepo). Missing code -> 1.0.
type fakeRateRepo struct {
	rates map[string]float64
}

func (r *fakeRateRepo) FindRate(_ context.Context, code string, _ time.Time) (float64, error) {
	if v, ok := r.rates[code]; ok {
		return v, nil
	}
	return 1.0, nil
}

func (r *fakeRateRepo) FindRange(_ context.Context, _ string, _, _ time.Time) ([]currencydomain.RateHistory, error) {
	return nil, nil
}

func (r *fakeRateRepo) Save(_ context.Context, _ currencydomain.RateHistory) error { return nil }

// TestComputeActuals_MultiCurrencyConverts verifies M3: a budget in CNY with
// an item on a USD account has its actuals (USD cents) converted to CNY via
// ConvertToBase (usdCents × rateUSD / rateCNY).
func TestComputeActuals_MultiCurrencyConverts(t *testing.T) {
	usdAcc := uuid.New()
	budget := &domain.Budget{
		TenantID: uuid.New(), Month: "2026-07", CurrencyCode: "CNY",
		Items: []domain.BudgetItem{{ID: uuid.New(), AccountID: usdAcc}},
	}
	repo := &fakeBudgetRepo{budget: budget}
	// entryMonthFunc returns 10000 USD cents (debit) on the USD account.
	entryMonthFunc := func(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error) {
		return map[uuid.UUID]EntryTotals{usdAcc: {DebitCents: 10000, CreditCents: 0}}, nil
	}
	accountCur := &fakeAccountCur{codes: map[uuid.UUID]string{usdAcc: "USD"}}
	rateRepo := &fakeRateRepo{rates: map[string]float64{"CNY": 1.0, "USD": 7.0}} // 1 USD = 7 CNY
	svc := NewService(repo, nil, entryMonthFunc, rateRepo, accountCur)

	dto, err := svc.GetBudgetByMonth(context.Background(), budget.TenantID, "2026-07")
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	// 10000 USD × 7 / 1 = 70000 CNY
	if got := dto.Budget.Items[0].ActualAmountCents; got != 70000 {
		t.Errorf("multi-currency actual: got %d, want 70000 (10000 USD × 7)", got)
	}
}

// TestComputeActuals_SameCurrencyNoConvert verifies the optimization: when the
// item's account currency == budget currency, no conversion happens (raw cents).
func TestComputeActuals_SameCurrencyNoConvert(t *testing.T) {
	cnyAcc := uuid.New()
	budget := &domain.Budget{
		TenantID: uuid.New(), Month: "2026-07", CurrencyCode: "CNY",
		Items: []domain.BudgetItem{{ID: uuid.New(), AccountID: cnyAcc}},
	}
	repo := &fakeBudgetRepo{budget: budget}
	entryMonthFunc := func(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error) {
		return map[uuid.UUID]EntryTotals{cnyAcc: {DebitCents: 50000, CreditCents: 0}}, nil
	}
	accountCur := &fakeAccountCur{codes: map[uuid.UUID]string{cnyAcc: "CNY"}}
	rateRepo := &fakeRateRepo{rates: map[string]float64{"CNY": 1.0}}
	svc := NewService(repo, nil, entryMonthFunc, rateRepo, accountCur)

	dto, err := svc.GetBudgetByMonth(context.Background(), budget.TenantID, "2026-07")
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if got := dto.Budget.Items[0].ActualAmountCents; got != 50000 {
		t.Errorf("same-currency actual: got %d, want 50000 (raw, no conversion)", got)
	}
}

// TestComputeActuals_NilPortsRawBehavior verifies nil rateRepo/accountCur
// preserves M2 behavior (no conversion, raw account-currency cents).
func TestComputeActuals_NilPortsRawBehavior(t *testing.T) {
	usdAcc := uuid.New()
	budget := &domain.Budget{
		TenantID: uuid.New(), Month: "2026-07", CurrencyCode: "CNY",
		Items: []domain.BudgetItem{{ID: uuid.New(), AccountID: usdAcc}},
	}
	repo := &fakeBudgetRepo{budget: budget}
	entryMonthFunc := func(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error) {
		return map[uuid.UUID]EntryTotals{usdAcc: {DebitCents: 10000, CreditCents: 0}}, nil
	}
	svc := NewService(repo, nil, entryMonthFunc, nil, nil) // nil ports

	dto, err := svc.GetBudgetByMonth(context.Background(), budget.TenantID, "2026-07")
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if got := dto.Budget.Items[0].ActualAmountCents; got != 10000 {
		t.Errorf("nil-port actual: got %d, want 10000 (M2 raw, no conversion)", got)
	}
}
```

- [ ] **Step 3: 跑测试看失败**

Run: `cd yucai/server && go test ./internal/budget/application/... -run 'TestComputeActuals_(MultiCurrencyConverts|SameCurrencyNoConvert|NilPortsRawBehavior)' -count=1`
Expected: FAIL / 编译错(`NewService` 仍是 3 参 / `rateRepo` `accountCur` field 不存在 / 折算逻辑未实现 → MultiCurrency 返 10000 非 70000)

- [ ] **Step 4: 改 Service — 加 field + NewService 5 参 + 折算 helper + computeActuals 改**

[service.go](../../yucai/server/internal/budget/application/service.go):

import 加 `currencydomain "github.com/yucai/server/internal/currency/domain"`。

Service struct 加 2 field:
```go
type Service struct {
	repo           domain.BudgetRepository
	entryFunc      EntryTotalsFunc
	entryMonthFunc EntryTotalsMonthFunc
	rateRepo       currencydomain.RateHistoryRepository // M3: nil → no conversion
	accountCur     domain.AccountCurrencySource         // M3: nil → no conversion
}
```

NewService 加 2 参:
```go
func NewService(
	repo domain.BudgetRepository,
	entryFunc EntryTotalsFunc,
	entryMonthFunc EntryTotalsMonthFunc,
	rateRepo currencydomain.RateHistoryRepository,
	accountCur domain.AccountCurrencySource,
) *Service {
	return &Service{
		repo:           repo,
		entryFunc:      entryFunc,
		entryMonthFunc: entryMonthFunc,
		rateRepo:       rateRepo,
		accountCur:     accountCur,
	}
}
```

折算 helper(加在 `computeActualsReadTimeBatch` 之后):
```go
// accountCurrencies fetches account_id -> currency_code for the tenant (nil
// accountCur → nil map, conversion skipped). Logged on err, not fatal.
func (s *Service) accountCurrencies(ctx context.Context, tenantID uuid.UUID) map[uuid.UUID]string {
	if s.accountCur == nil {
		return nil
	}
	m, err := s.accountCur.CurrencyCodes(ctx, tenantID)
	if err != nil {
		slog.Warn("budget actuals: account currency lookup failed, skipping conversion",
			"operation", "budget.computeActuals", "error", err.Error())
		return nil
	}
	return m
}

// budgetRate fetches the budget currency -> CNY rate at the given time (nil
// rateRepo → 1.0, no conversion; err/zero → 1.0 fallback).
func (s *Service) budgetRate(ctx context.Context, budgetCur string, at time.Time) float64 {
	if s.rateRepo == nil {
		return 1.0
	}
	r, err := s.rateRepo.FindRate(ctx, budgetCur, at)
	if err != nil || r == 0 {
		return 1.0
	}
	return r
}

// convertToBudget折算 raw (account currency) cents to budget currency cents.
// nil infra / unknown account currency / same currency / missing rate → raw
// (best-effort,照 networth toBase).
func (s *Service) convertToBudget(ctx context.Context, raw int64, accountID uuid.UUID, budgetCur string, curMap map[uuid.UUID]string, rateBase float64, at time.Time) int64 {
	if raw == 0 || s.rateRepo == nil || s.accountCur == nil {
		return raw
	}
	accCode, ok := curMap[accountID]
	if !ok || accCode == "" || accCode == budgetCur {
		return raw // same currency → no conversion
	}
	rateFrom, err := s.rateRepo.FindRate(ctx, accCode, at)
	if err != nil || rateFrom == 0 {
		slog.Warn("budget actuals: rate missing, using raw account-currency cents",
			"operation", "budget.computeActuals",
			"account_currency", accCode, "budget_currency", budgetCur)
		return raw
	}
	return currencydomain.ConvertToBase(raw, rateFrom, rateBase)
}

// accountNet returns debit−credit for an account from the month totals map.
func accountNet(totals map[uuid.UUID]EntryTotals, accountID uuid.UUID) int64 {
	if totals == nil {
		return 0
	}
	if t, ok := totals[accountID]; ok {
		return t.DebitCents - t.CreditCents
	}
	return 0
}
```

`computeActualsReadTime` 改折算(替换 M2 版,line ~215):
```go
func (s *Service) computeActualsReadTime(ctx context.Context, b *domain.Budget) {
	if s.entryMonthFunc == nil {
		return
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
	curMap := s.accountCurrencies(ctx, b.TenantID)
	rateBase := s.budgetRate(ctx, b.CurrencyCode, to)
	for i := range b.Items {
		raw := accountNet(totals, b.Items[i].AccountID)
		b.Items[i].ActualAmountCents = s.convertToBudget(ctx, raw, b.Items[i].AccountID, b.CurrencyCode, curMap, rateBase, to)
	}
}
```

`computeActualsReadTimeBatch` 改折算(替换 M2 版,line ~243)—— curMap 一次/tenant,rateBase per budget currency:
```go
func (s *Service) computeActualsReadTimeBatch(ctx context.Context, tenantID uuid.UUID, budgets []domain.Budget) {
	if s.entryMonthFunc == nil {
		return
	}
	curMap := s.accountCurrencies(ctx, tenantID)
	monthCache := map[string]map[uuid.UUID]EntryTotals{}
	for i := range budgets {
		month := budgets[i].Month
		if _, cached := monthCache[month]; !cached {
			from, to := monthRange(month)
			totals, err := s.entryMonthFunc(ctx, tenantID, from, to)
			if err != nil {
				slog.Error("budget actuals batch: entryMonthFunc failed",
					"operation", "budget.computeActualsReadTimeBatch",
					"month", month, "error", err.Error())
				monthCache[month] = nil
				continue
			}
			monthCache[month] = totals
		}
		to, _ := monthRange(budgets[i].Month)
		rateBase := s.budgetRate(ctx, budgets[i].CurrencyCode, to)
		totals := monthCache[budgets[i].Month]
		for j := range budgets[i].Items {
			raw := accountNet(totals, budgets[i].Items[j].AccountID)
			budgets[i].Items[j].ActualAmountCents = s.convertToBudget(ctx, raw, budgets[i].Items[j].AccountID, budgets[i].CurrencyCode, curMap, rateBase, to)
		}
	}
}
```

- [ ] **Step 5: 跑折算测通过**

Run: `cd yucai/server && go test ./internal/budget/application/... -run 'TestComputeActuals_(MultiCurrencyConverts|SameCurrencyNoConvert|NilPortsRawBehavior)' -count=1`
Expected: PASS(3 测)

- [ ] **Step 6: M2 测改 NewService 5 参 + budget_integration_test + provideBudgetService body nil,nil**

M2 的 7 个 service_test(5 read-time + 2 batch)的 `NewService(repo, nil, entryMonthFunc)` → `NewService(repo, nil, entryMonthFunc, nil, nil)`(grep `NewService(` in service_test.go 全改)。

[tests/budget_integration_test.go](../../yucai/server/tests/budget_integration_test.go) `setupBudgetTestService`:`NewService(repo, nil, nil)` → `NewService(repo, nil, nil, nil, nil)`。

[wire/providers.go](../../yucai/server/wire/providers.go) `provideBudgetService` body:`NewService(repo, entryFunc, entryMonthFunc)` → `NewService(repo, entryFunc, entryMonthFunc, nil, nil)`(**签名不变** repo+txnSvc → wire_gen.go 不改;nil port = M2 行为)。

- [ ] **Step 7: 跑全量 build + test**

Run: `cd yucai/server && go build ./...`
Expected: 成功(NewService 5 参全调用方改:service_test + budget_integration_test + provideBudgetService;wire_gen.go 不改因 provideBudgetService 签名不变)

Run: `cd yucai/server && go test ./... -count=1`
Expected: PASS(M2 budget 测 + M3 折算测 + nil port 不回归;全量 0 FAIL)

- [ ] **Step 8: Commit**

```bash
cd e:/projects/syfinance
git add yucai/server/internal/budget/domain/account_source.go \
  yucai/server/internal/budget/application/service.go \
  yucai/server/internal/budget/application/service_test.go \
  yucai/server/tests/budget_integration_test.go \
  yucai/server/wire/providers.go
git commit -m "feat(budget): M3 actuals convert scaffolding (nil port = M2 behavior)" -m "AccountCurrencySource port (budget domain) + Service rateRepo/accountCur fields + NewService +2 params + convertToBudget helpers (照 networth toBase/ConvertToBase). computeActualsReadTime/Batch convert per-item actuals to budget currency via budget-month-end rate. nil rateRepo/accountCur -> M2 raw behavior (no conversion). provideBudgetService signature UNCHANGED (body NewService(...,nil,nil)) -> wire_gen.go untouched. Task 2 wires real ports. Multi-currency/same-currency/nil-port tests (fake rateRepo/accountCur)."
```

---

## Task 2: wire 注入真实 rateRepo + accountCur + 多币种 integration + wire_gen.go 手改

provideBudgetService 加 rateRepo + accountCur 参数(签名变)→ wire_gen.go 手改。accountCurrencyAdapter(account FindAllForBackup → CurrencyCodes)。多币种 integration e2e。

**Files:**
- Modify: [wire/providers.go](../../yucai/server/wire/providers.go)(`provideBudgetService` +rateRepo +accountCur 参数 + `accountCurrencyAdapter` + `provideAccountCurrencySource`)
- Modify: [wire/wire_gen.go](../../yucai/server/wire/wire_gen.go)(手改:`provideBudgetService` 调用加 rateRepo + accountCurSource)
- Modify: [tests/budget_integration_test.go](../../yucai/server/tests/budget_integration_test.go)(+多币种 integration test)

**Interfaces:**
- Consumes: Task 1 `AccountCurrencySource` port + 折算 Service;`accountrepo.AccountRepository.FindAllForBackup`;`*currencyrepo.RateHistoryRepository`(currencydomain.RateHistoryRepository structural)
- Produces: wire 注入真实 port(M3 折算 active in prod)

- [ ] **Step 1: wire accountCurrencyAdapter + provideAccountCurrencySource**

[providers.go](../../yucai/server/wire/providers.go)(照 `holdingRateAdapter` wire bridge 范式,加在 provideBudgetService 附近):

```go
// accountCurrencyAdapter bridges the account repo to budget's
// AccountCurrencySource port (budget does not import account domain — mirrors
// holdingRateAdapter). CurrencyCodes lists tenant accounts (FindAllForBackup,
// no pagination) and builds account_id -> currency_code.
type accountCurrencyAdapter struct{ inner *accountrepo.AccountRepository }

func (a *accountCurrencyAdapter) CurrencyCodes(ctx context.Context, tenantID uuid.UUID) (map[uuid.UUID]string, error) {
	accounts, err := a.inner.FindAllForBackup(ctx, tenantID)
	if err != nil {
		return nil, fmt.Errorf("account currencies: %w", err)
	}
	out := make(map[uuid.UUID]string, len(accounts))
	for _, acc := range accounts {
		out[acc.ID] = acc.CurrencyCode
	}
	return out, nil
}

func provideAccountCurrencySource(accRepo *accountrepo.AccountRepository) budgetdomain.AccountCurrencySource {
	return &accountCurrencyAdapter{inner: accRepo}
}
```

> import 确认:`accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"` + `budgetdomain "github.com/yucai/server/internal/budget/domain"`(对齐 providers.go 现有 alias)。`accountrepo.AccountRepository.FindAllForBackup(ctx, tenantID) []domain.Account`(含 CurrencyCode,backup 用,M1 确认)。

- [ ] **Step 2: provideBudgetService 加 rateRepo + accountCur 参数**

[providers.go](../../yucai/server/wire/providers.go) `provideBudgetService`(M2 签名 `repo, txnSvc` → M3 `repo, txnSvc, rateRepo, accountCur`):

```go
// provideBudgetService wires budget's ports: M2 entryFunc/entryMonthFunc
// (actuals query) + M3 rateRepo/accountCur (multi-currency conversion). budget
// application does NOT import transaction/account domain (port pattern, mirrors
// networth).
func provideBudgetService(
	repo *budgetrepo.BudgetRepository,
	txnSvc *txnapp.Service,
	rateRepo currencydomain.RateHistoryRepository,
	accountCur budgetdomain.AccountCurrencySource,
) *budgetapp.Service {
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
		rateRepo,     // M3
		accountCur,   // M3
	)
}
```

- [ ] **Step 3: wire_gen.go 手改(memory yucai-wire-handmaintained)**

[wire_gen.go](../../yucai/server/wire/wire_gen.go):定位 `budgetService := provideBudgetService(budgetRepo, txnService)`(M1/M2 现状),改为加 rateRepo + accountCurSource:

```go
	// budget module
	budgetRepo := provideBudgetRepo(budgetClient)
	accountCurSource := provideAccountCurrencySource(accountRepo) // M3: budget AccountCurrencySource
	// (txnService declared above in Transaction module)
	budgetService := provideBudgetService(budgetRepo, txnService, currencyRateHistoryRepo, accountCurSource)
	budgetHandler := provideBudgetHandler(budgetService)
```

> `currencyRateHistoryRepo` 变量复用(currency module 既有,networth 同用);`accountCurSource` 新变量(声明在 budgetService 前);`accountRepo` 变量既有(account module)。implementer 用 `git log`/grep 确认这三个变量在 wire_gen.go 的确切行 + 声明顺序(消费方在依赖方后)。

- [ ] **Step 4: accountCurrencyAdapter 单测 或 defer(二选一,无 t.Skip 占位)**

折算逻辑已由 Task 1 `TestComputeActuals_MultiCurrencyConverts`(fake rateRepo + fake accountCur)覆盖。adapter 本身是 5 行 thin bridge(`FindAllForBackup → map[id]currency_code`)。implementer 二选一,report 说明:

- **(a) adapter 单测**(轻,推荐):若 account ent fixture 可用(独立 account enttest client 或扩展 setupBudgetTestDB),Save 2 个 account(USD + CNY)+ `(&accountCurrencyAdapter{inner: accountRepo}).CurrencyCodes(ctx, tenantID)` → 断言 `map[id]code` 正确(2 entries,code 匹配)。
- **(b) defer**:跨 budget+account ent fixture 太重 → 折算逻辑覆盖靠 Task 1 fake-port 测 + Task 2 Step 6 `go build ./...`(adapter 编译过)。report 注 defer 理由(follow-up e2e 跨 ent)。

**不写 `t.Skip` 占位** —— 选 (a) 写真测,或 (b) 明确 defer。

- [ ] **Step 6: 跑全量 build + test**

Run: `cd yucai/server && go build ./...`
Expected: 成功(wire_gen.go 手改:provideBudgetService 4 参 + currencyRateHistoryRepo + accountCurSource 变量;NewService 5 参)

Run: `cd yucai/server && go test ./... -count=1`
Expected: PASS(Task 1 折算测 + adapter 单测/集成 + M2/M1 不回归)

- [ ] **Step 7: Commit**

```bash
cd e:/projects/syfinance
git add yucai/server/wire/providers.go yucai/server/wire/wire_gen.go yucai/server/tests/budget_integration_test.go
git commit -m "feat(budget): M3 wire real rateRepo + accountCur (multi-currency active)" -m "provideBudgetService +rateRepo +accountCur params (signature change -> wire_gen.go hand-edit: reuse currencyRateHistoryRepo + new accountCurSource var). accountCurrencyAdapter bridges account repo FindAllForBackup -> budget AccountCurrencySource (wire,照 holdingRateAdapter). M3 conversion now active in prod (budget-month-end rate, nil/missing -> M2 raw best-effort)."
```

---

## Spec coverage 矩阵

| spec 决策/章节 | 落地 task | 备注 |
|---|---|---|
| §3 #1 折算方向 actuals→budget | Task 1 Step 4 convertToBudget | |
| §3 #2 import ConvertToBase | Task 1 Step 4 import currencydomain | networth 范式 |
| §3 #3 rate month 末日 | Task 1 Step 4 budgetRate(monthRange to) | |
| §3 #4 降级原币 | Task 1 Step 4 convertToBudget raw + slog | |
| §3 #5 AccountCurrencySource port | Task 1 Step 1 + Task 2 adapter | |
| §3 #6 单币种优化 | Task 1 Step 4 convertToBudget accCode==budgetCur → raw | |
| §3 #7 NewService +2 参 | Task 1 Step 4 + Step 6 调用方 | M1 教训 |
| §3 #8 wire_gen.go 手改 | Task 2 Step 3 | provideBudgetService 签名变 |
| §3 #9 UI/proto 不改 | 全 plan | actuals 已 budget 币种 |
| §6.1 port | Task 1 Step 1 | |
| §6.2 Service 折算 | Task 1 Step 4 | |
| §6.3 adapter | Task 2 Step 1 | accountCurrencyAdapter(FindAllForBackup) |
| §6.4 wire | Task 2 Step 2-3 | provideBudgetService + wire_gen.go |
| §6.5 调用方迁移 | Task 1 Step 6 | M1 教训 grep |
| §9 风险 1 签名变 | Task 1 Step 6 + Task 2 | |
| §9 风险 2 wire 手改 | Task 2 Step 3 | |
| §9 风险 3 rate 时机 | Task 1 budgetRate | |
| §9 风险 4 import currencydomain | Task 1 import | |
| §9 风险 5 persist 不折算 | ComputeActuals 不动 | |
| §9 风险 7 accountCur adapter | Task 2 Step 1 FindAllForBackup | M1 确认 |
