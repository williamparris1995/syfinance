# budget M3 · actuals 折算到 budget 币种 · 设计 spec

- **日期**: 2026-07-17
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans → subagent session)
- **分支**: 待定(main-driven,从 main 最新 `664a96e`)
- **范围**: budget M3 defer —— budget item actuals(**account 币种** entry Σ)折算到 **budget.CurrencyCode**,使 `total_actual` / `usage_pct` 统一 budget 币种(item `planned` 已 budget 币种)。照 networth `ConvertToBase` + `RateHistoryRepository` 范式。**零 proto / 零 ent schema**(client 不改:actuals 已 budget 币种)。

## 1. 背景

D-budget([2026-07-01-holding-budget-design.md](2026-07-01-holding-budget-design.md))决策 ⑧ "**原币相加(defer 折算)**" + 风险 6 "budget.CurrencyCode vs expense 账户 currency 不一致;MVP 原币相加不折算,UI note"。

**现状**(budget M2 batch actuals + M1 edit + atomicity,merged main):
- `transaction_entry` **无 currency field**(只有 debit/credit cents + account_id)→ entry 币种 = **`account.currency_code`**
- budget item actuals = `SumEntryTotalsByMonth` 返的 `map[accountID]AccountTotals`(**account 币种 cents**,Σ entry debit/credit)
- budget item `PlannedAmountCents` 是 **budget 币种**(用户创建时填,UI 显示 budget 币种符号)
- 若某 item 的 expense account 币种 ≠ budget.CurrencyCode(如 budget CNY 但 Food 账户 USD),actuals 是 USD cents 但与 planned(CNY)比较 / 累加进 `total_actual` → **币种混合,数字语义错**(`usage_pct` 失真)

**关键洞察**(brainstorm 确认):用户有多币种预算场景(budget CNY + 某 expense USD),M3 值得做。修复 = actuals 折算到 budget 币种(照 [networth](../../yucai/server/internal/networth/application/service.go) `toBase` + `currencydomain.ConvertToBase` 范式)。

memory `holding-asset-management-todo` D-budget defer M3:"多币种原币相加"。

## 2. 目标

- budget item actuals(account 币种)折算到 **budget.CurrencyCode** → `total_actual` / `usage_pct` 统一 budget 币种,与 `planned` 一致比较
- 复用 [currencydomain.ConvertToBase](../../yucai/server/internal/currency/domain/convert.go)(纯函数)+ `RateHistoryRepository.FindRate`(D-currency rate_history)
- 多币种 item 折算;单币种 item(budget 币种 == account 币种)跳过折算(优化 + 无 rate 依赖)
- rate 缺失 → 降级原币 + slog(best-effort,照 networth)

## 3. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | 折算方向 | **actuals → budget 币种** | planned 已 budget 币种;actuals 折算后一致;UI 不改(已显示 budget 币种) |
| 2 | 折算函数 | **import `currencydomain.ConvertToBase`**(纯函数) | networth 范式;currency 是共享基础(非业务 domain);不像 transaction 业务 domain 需 port |
| 3 | rate 来源 | **`RateHistoryRepository.FindRate(code, budgetMonthEnd)`** | D-currency rate_history daily;actuals 是历史 → 用 budget month 末日 rate(非当前 time.Now,networth 用 Now 因 networth 是实时快照) |
| 4 | rate 缺失降级 | **原币 + slog(best-effort)** | 照 networth(rateRepo nil → rate 1.0 → 不折算);不 crash;UI 显示原币数字 + 用户感知 |
| 5 | account currency port | **`AccountCurrencySource` port(`CurrencyCodes(tenantID) → map[accountID]code`)** | DDD 边界(budget 不 import account domain);批量一次查(照 networth `SumBalancesByCurrency`),budget 按 item.accountID 查 map |
| 6 | 单币种优化 | **account 币种 == budget 币种 → 跳过 rate 查询/折算** | 多数 item 同币种(单币种用户);省 rate_history 查询;accountCurSource 仍查(轻) |
| 7 | NewService 签名 | **加 2 参 `rateRepo` + `accountCurSource`**(M2 3→M3 5 参) | 照 networth 多 port 注入;wire + test 调用方全改(约束 6 + M1 教训:grep 全 NewService 调用方含 tests/ 集成测) |
| 8 | wire_gen.go | **手改**(provideBudgetService 签名变,加 rateRepo + accountCurSource 参数) | memory `yucai-wire-handmaintained`;M1/M2 签名不变避改,M3 必改(新依赖) |
| 9 | UI / proto | **不改** | actuals 已 budget 币种;client 透传(total_actual/usage_pct 字段 M2 已有) |

## 4. 范围边界

| 在范围(M3) | 不在范围(defer / out) |
|---|---|
| budget domain `AccountCurrencySource` port interface | budget item `currency_code` 字段(数据模型大改,决策 defer) |
| budget application import `currencydomain`(ConvertToBase + RateHistoryRepository type) | UI 多币种显示(item 标 account 币种)—— actuals 折算后无需 |
| budget `Service` 加 `rateRepo` + `accountCurSource` field;`NewService` 加 2 参 | planned 折算(planned 已 budget 币种) |
| `computeActualsReadTime` / `computeActualsReadTimeBatch` 改折算(per item:account currency → rate → ConvertToBase) | ComputeActuals persist 路径(保留单 entryFunc,不折算 —— 范围外,persist 是用户显式触发) |
| account adapter 实现 `AccountCurrencySource`(查 account.currency_code) | rate 历史 time 旅行(用 month 末日,不扫全月) |
| wire `provideBudgetService` 加 2 参 + `wire_gen.go` 手改 + account currency adapter provider | |

## 5. 架构

| 层 | 组件 | 改动 |
|---|---|---|
| **domain**(budget) | 新 `AccountCurrencySource` interface | `CurrencyCodes(ctx, tenantID) (map[uuid.UUID]string, error)`(accountID → currency_code) |
| **application**(budget) | `Service` | +`rateRepo currencydomain.RateHistoryRepository` field + `accountCur AccountCurrencySource` field;`NewService` 加 2 参;import `currencydomain`;`computeActualsReadTime` / `computeActualsReadTimeBatch` 改折算 |
| **adapter/driven**(budget 或 account) | `AccountCurrencySource` 实现 adapter | 查 account.currency_code by tenant(批量 map),注入 budget |
| **wire** | `providers.go` + `wire_gen.go` | `provideBudgetService` 加 rateRepo + accountCurSource 参数(签名变 → **wire_gen.go 手改**);新 account currency adapter provider |

**不改**:domain Budget entity / BudgetRepository / proto / client / ent schema。

## 6. 核心改动

### 6.1 budget domain — AccountCurrencySource port

[budget/domain/](../../yucai/server/internal/budget/domain/) 新 port(照 networth domain `AccountBalanceSource` 范式):

```go
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

### 6.2 budget application — Service 加 2 field + NewService 加参 + 折算

[budget/application/service.go](../../yucai/server/internal/budget/application/service.go):

Service struct 加 2 field:
```go
type Service struct {
	repo           domain.BudgetRepository
	entryFunc      EntryTotalsFunc       // 单 account(ComputeActuals persist,M1 保留)
	entryMonthFunc EntryTotalsMonthFunc  // batch(read-time actuals,M2)
	rateRepo       currencydomain.RateHistoryRepository // M3:折算 rate(nil → 不折算,原币)
	accountCur     domain.AccountCurrencySource          // M3:account 币种(nil → 不折算)
}
```

NewService 加 2 参(M2 3 → M3 5):
```go
// NewService creates a new budget application service. entryFunc backs the
// persist-path ComputeActuals; entryMonthFunc backs read-time actuals (M2 batch);
// rateRepo + accountCur back M3 multi-currency actuals conversion (either may be
// nil → graceful: actuals stay in account currency, no conversion).
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

import 加 `currencydomain "github.com/yucai/server/internal/currency/domain"`(照 networth)。

**`computeActualsReadTime` 改折算**(单 budget,GetBudget/GetBudgetByMonth):
```go
// computeActualsReadTime fills each item's ActualAmountCents via one batch month
// query (entryMonthFunc) then折算 each item's account-currency actuals to the
// budget currency (M3). nil entryMonthFunc → actuals 0. err → all 0 + slog.
// Conversion: nil rateRepo/accountCur → raw account-currency cents (no conversion,
// M2 behavior). rate missing for a code → falls back to raw + slog (best-effort).
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
		for i := range b.Items { b.Items[i].ActualAmountCents = 0 }
		return
	}
	curMap := s.accountCurrencies(ctx, b.TenantID)       // map[accountID]code(nil port → empty)
	rateBase := s.budgetRate(ctx, b.CurrencyCode, to)     // budget 币种 → CNY rate(month end)
	for i := range b.Items {
		raw := accountNet(totals, b.Items[i].AccountID)   // account 币种 cents(debit−credit)
		b.Items[i].ActualAmountCents = s.convertToBudget(ctx, raw, b.Items[i].AccountID, b.CurrencyCode, curMap, rateBase, to)
	}
}
```

**`computeActualsReadTimeBatch` 改折算**(ListBudgets,按 month 分组):
```go
// computeActualsReadTimeBatch fills actuals for many budgets with one query per
// distinct month (M2) + per-item currency conversion to each budget's currency
// (M3). nil entryMonthFunc → no-op. curMap queried once per tenant (all budgets
// share tenant). rateBase per (month, budget currency).
func (s *Service) computeActualsReadTimeBatch(ctx context.Context, tenantID uuid.UUID, budgets []domain.Budget) {
	if s.entryMonthFunc == nil {
		return
	}
	curMap := s.accountCurrencies(ctx, tenantID) // nil port → empty (no conversion)
	monthCache := map[string]map[uuid.UUID]EntryTotals{}
	rateBaseCache := map[string]float64{}        // month -> budget-currency -> ... (single budget currency per month? 见下)
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
		totals := monthCache[budgets[i].Month]
		rateBase := s.budgetRate(ctx, budgets[i].CurrencyCode, monthEnd(budgets[i].Month))
		for j := range budgets[i].Items {
			raw := accountNet(totals, budgets[i].Items[j].AccountID)
			budgets[i].Items[j].ActualAmountCents = s.convertToBudget(ctx, raw, budgets[i].Items[j].AccountID, budgets[i].CurrencyCode, curMap, rateBase, monthEnd(budgets[i].Month))
		}
	}
}
```

**helper 方法**(折算逻辑,照 networth `toBase`):
```go
// accountCurrencies fetches account_id -> currency_code for the tenant (nil
// accountCur port → empty map, conversion skipped). Logged on err, not fatal.
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

// budgetRate fetches the budget currency -> CNY rate at monthEnd (nil rateRepo →
// 1.0, no conversion).
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
// account currency unknown / same as budget / no rate → raw (best-effort).
func (s *Service) convertToBudget(ctx context.Context, raw int64, accountID uuid.UUID, budgetCur string, curMap map[uuid.UUID]string, rateBase float64, at time.Time) int64 {
	if raw == 0 || s.rateRepo == nil || s.accountCur == nil {
		return raw // no conversion infra → M2 raw behavior
	}
	accCode, ok := curMap[accountID]
	if !ok || accCode == "" || accCode == budgetCur {
		return raw // same currency → no conversion
	}
	rateFrom, err := s.rateRepo.FindRate(ctx, accCode, at)
	if err != nil || rateFrom == 0 {
		slog.Warn("budget actuals: rate missing, using raw account-currency cents",
			"operation", "budget.computeActuals", "account_currency", accCode, "budget_currency", budgetCur)
		return raw
	}
	return currencydomain.ConvertToBase(raw, rateFrom, rateBase)
}

// accountNet returns debit−credit for an account from the month totals map
// (nil totals / missing account → 0).
func accountNet(totals map[uuid.UUID]EntryTotals, accountID uuid.UUID) int64 {
	if totals == nil {
		return 0
	}
	t, ok := totals[accountID]
	if !ok {
		return 0
	}
	return t.DebitCents - t.CreditCents
}

// monthEnd returns the last instant of the month (for rate lookup time).
func monthEnd(month string) time.Time {
	_, to := monthRange(month)
	return to
}
```

> ComputeActuals(persist)路径**不折算**(保留 M1 单 entryFunc,actuals persist 是用户显式触发 + 范围外)。

### 6.3 account currency adapter(AccountCurrencySource 实现)

新 adapter(放 budget/adapter/driven/ 或复用 account repo)。实现 `CurrencyCodes(ctx, tenantID) → map[uuid.UUID]string`:

```go
// accountCurrencyAdapter implements budget domain.AccountCurrencySource by
// querying the account repo for tenant accounts' currency codes. Wired in DI
// (budget does not import account domain — the adapter is the bridge, mirrors
// networth's account/holding/debt source adapters).
type accountCurrencyAdapter struct {
	repo accountdomain.AccountRepository // 或 account application port
}

func (a *accountCurrencyAdapter) CurrencyCodes(ctx context.Context, tenantID uuid.UUID) (map[uuid.UUID]string, error) {
	// account repo: list tenant accounts (active), build map[id]currency_code.
	accounts, err := a.repo.FindAll(ctx, tenantID, ...) // 对齐 account repo 现有 list 方法
	if err != nil {
		return nil, fmt.Errorf("account currencies: %w", err)
	}
	out := make(map[uuid.UUID]string, len(accounts))
	for _, acc := range accounts {
		out[acc.ID] = acc.CurrencyCode
	}
	return out, nil
}
```

> plan 确认 account repo 的 tenant account list 方法(M1 account_repo.go 有 `FindByID`/`FindAll`?对齐现有 + 是否需 tenant filter)。

### 6.4 wire — provideBudgetService 加 2 参 + wire_gen.go 手改

[providers.go](../../yucai/server/wire/providers.go) `provideBudgetService` 加 rateRepo + accountCur(M1/M2 签名 `repo, txnSvc` → M3 `repo, txnSvc, rateRepo, accountCur`):

```go
// provideBudgetService wires budget's ports (M2 entryFunc/entryMonthFunc for
// actuals query + M3 rateRepo/accountCur for multi-currency conversion).
// budget application does NOT import transaction/account domain (port pattern).
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

新 provider(账户 currency adapter):
```go
func provideAccountCurrencySource(accRepo *accountrepo.AccountRepository) budgetdomain.AccountCurrencySource {
	return &accountCurrencyAdapter{repo: accRepo}
}
```

[wire_gen.go](../../yucai/server/wire/wire_gen.go) **手改**(memory `yucai-wire-handmaintained`):
- `provideBudgetService` 调用加 `rateRepo`(复用 holding/currency 的 rateRepo 变量)+ `accountCurSource`(新变量,`provideAccountCurrencySource(accountRepo)`)
- 新变量声明 `accountCurSource := provideAccountCurrencySource(accountRepo)`(在 budgetService 之前)
- 镜像现有 provider 声明顺序(消费方在依赖方后)

> rateRepo 复用:networth 用 currency rateRepo(providers.go 现有 provider)。M3 budget 同 rateRepo 实例。plan 确认 rateRepo 变量名 + 来源(holding snapshot 用 rate_history,或 currency 自家 RateHistoryRepository)。

### 6.5 NewService 调用方迁移(M1 教训:grep 全调用方含 tests/ 集成测)

`NewService` 5 参 → 全调用方改:
- [wire/providers.go](../../yucai/server/wire/providers.go) `provideBudgetService`(6.4)
- [tests/budget_integration_test.go](../../yucai/server/tests/budget_integration_test.go) `setupBudgetTestService`:`NewService(repo, nil, nil)` → `NewService(repo, nil, nil, nil, nil)`(nil rateRepo/accountCur → 不折算,单币种测试不变;**多币种折算测试用 fake rateRepo + fake accountCur**)
- [budget/application/service_test.go](../../yucai/server/internal/budget/application/service_test.go) M2 的 5 现有 + 2 batch 测:`NewService(repo, nil, entryMonthFunc)` → `NewService(repo, nil, entryMonthFunc, nil, nil)`(单币种,nil 折算);**新多币种折算测用 fake rateRepo + fake accountCur**

## 7. 数据流

- **单币种 item**(budget 币种 == account 币种):`entryMonthFunc` → `accountNet` → `convertToBudget` 检测 accCode == budgetCur → raw(不折算,省 rate 查询)。M2 行为。
- **多币种 item**(budget CNY,Food USD):`entryMonthFunc` 返 Food USD cents → `accountCur.CurrencyCodes` 查 Food=USD → `rateRepo.FindRate(USD, monthEnd)` rateFrom + `FindRate(CNY=budget, monthEnd)` rateBase → `ConvertToBase(usdCents, rateFrom, rateBase)` → CNY cents。`total_actual` Σ 全 CNY,`usage_pct` 准。
- **rate 缺失**(USD 该月无 rate_history):`FindRate` err/0 → `convertToBudget` slog + raw(USD cents,数字未折算,best-effort)。
- **nil port**(rateRepo/accountCur nil,如 integration test):`convertToBudget` → raw(M2 行为,不折算)。

## 8. 测试

- **domain**:无新 domain 逻辑(AccountCurrencySource 是 interface)。
- **application**(budget):
  - 单币种 item 不折算(M2 行为回归):budget CNY + item CNY account → actuals raw(nil rateRepo/accountCur 也 raw)。
  - 多币种 item 折算:budget CNY + item USD account + fake rateRepo(USD=7,CNY=1)+ fake accountCur({acc:USD})→ actuals = usdCents × 7 / 1(照 networth 测范式)。
  - rate 缺失:fake rateRepo FindRate err → actuals raw + slog(best-effort)。
  - nil port:nil rateRepo/accountCur → raw(M2 行为)。
  - computeActualsReadTimeBatch 多 budget 多 month:折算 + month cache(M2)+ rateBase per budget currency。
- **adapter**(accountCurrencyAdapter):CurrencyCodes(tenantID) → map(对齐 account repo list;enttest)。
- **integration**(budget_integration_test):setupBudgetTestService 加可选 rateRepo/accountCur 注入(多币种折算 e2e)。
- **wire**:`go build ./...`(wire_gen.go 手改后编译)+ NewService 5 参全调用方(grep `budgetapp.NewService\|application.NewService` 确认无遗漏含 tests/)。

## 9. 风险

1. **NewService 签名变(M1 教训)**:加 2 参 → grep 全调用方(wire/providers.go + tests/budget_integration_test + budget/application/service_test)。**含 tests/ 集成测**(M1 Task 2 漏 budget_integration_test:45 教训)。全调用方改后 `go build ./...` + `go test ./...`。
2. **wire_gen.go 手改**(memory `yucai-wire-handmaintained`):provideBudgetService 签名变(repo+txnSvc → +rateRepo+accountCur)→ wire_gen.go `budgetService := provideBudgetService(budgetRepo, txnService, rateRepo, accountCurSource)` 改 + 新 `accountCurSource := provideAccountCurrencySource(accountRepo)` 变量声明(在 budgetService 前)。**不跑 wire CLI**(tree-wide 坏)。
3. **rate 时机**(决策 3):budget month 末日 `monthRange(month).to`。rate_history daily(D-currency SyncRates)→ FindRate(code, monthEnd)。若该日无 rate → FindRange fallback 或降级(plan 确认 FindRate 语义:exact date vs nearest)。
4. **budget import currencydomain**(决策 2):照 networth(currency 共享基础)。ConvertToBase 纯函数 + RateHistoryRepository interface type。**不 import account domain**(用 AccountCurrencySource port)。
5. **ComputeActuals persist 不折算**(决策):范围外。persist 是用户显式触发(M1 entryFunc),actuals persist 原币。若未来需 persist 折算,follow-up。
6. **性能**(batch):accountCur.CurrencyCodes 一次/tenant(所有 budget 共享)+ rateRepo.FindRate per (currency, month)(cache rateBase per month)。省查询。多 budget 同 tenant 共享 curMap + rateBase。
7. **accountCur adapter 依赖 account repo**:plan 确认 account repo tenant list 方法(返回 currency_code)。若无,加 method 或用现有 FindAll。

## 10. 参考

- D-budget spec:[2026-07-01-holding-budget-design.md](2026-07-01-holding-budget-design.md)(决策⑧ 原币相加 defer 折算 + 风险 6)
- budget M2 spec:[2026-07-17-budget-m2-batch-actuals-design.md](2026-07-17-budget-m2-batch-actuals-design.md)(entryMonthFunc batch port + ConvertToBase 基础)
- networth 折算范式:[networth/application/service.go](../../yucai/server/internal/networth/application/service.go)(`toBase` + `rateRepo.FindRate` + `ConvertToBase` + nil rateRepo 降级)
- [currencydomain.ConvertToBase](../../yucai/server/internal/currency/domain/convert.go)(amount × rateFrom / rateBase)
- [RateHistoryRepository.FindRate](../../yucai/server/internal/currency/domain/repository.go#L38)
- memory:`holding-asset-management-todo`(D-budget M3 defer)、`yucai-wire-handmaintained`(wire_gen.go 手改)、CLAUDE.md 约束 6 + M1 教训(签名变更 grep 全调用方含 tests/)
