# Holding 子项目 D-currency · 多币种折算 + net-worth 聚合 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** realized 多币种折算(C defer 接)+ 新 networth 模块(跨模块聚合 GetNetWorth)+ 用户可配本位币(统一 net-worth/组合曲线/realized)。零新表。

**Architecture:** server 加 `convertToBase` helper(CNY-base 交叉)+ holding `aggregateRealized` 加 base + `GetPortfolioPerformance`/`GetHoldingPerformance` 加 `baseCurrency` 参数 + 新 `networth` 模块(3 跨模块结构 port:account/holding/debt `SumByCurrency`);Flutter home 调 GetNetWorth 修 bug + `CurrencySettings`(flutter_secure_storage)。

**Tech Stack:** Go(ent + grpc + slog)+ proto3 + Flutter(flutter_bloc + injectable + flutter_secure_storage + grpc stub)

**Spec:** [docs/superpowers/specs/2026-07-01-holding-currency-design.md](../specs/2026-07-01-holding-currency-design.md)

## Global Constraints

- **分支**:`holding-asset-management`(A/B/C/D-goal 已完成,D-currency 续做)
- **零新表**:复用 `rate_history`(C 建,CNY-base,`FindRate` 向前填充)。networth 实时聚合无持久化
- **client storage = `flutter_secure_storage: ^9.2.4`**(御财现有,pubspec.yaml:38;`CurrencySettings` 用它存 baseCurrency)
- **account/debt 现有**:`ListAccounts`/`ListDebts`(分页)、`FindByAccountType`(account)。**无 Σ by currency** —— D-currency 加 `SumByCurrency`
- **holding 现有**:`GetAccountMarketValue(tenantID, accountID)`(D-goal,per account 原币 Σ)。D-currency 加 `SumMarketValueByCurrency(tenantID)`(tenant 级 per currency)
- **rate_history**(C 建,CNY-base,`RateHistoryRepository.FindRate(ctx, code, date) → float64`,缺失返 1.0)
- **convertToBase**:`amount × rate[from] / rate[base]`(from==base→amount;rate 缺失 1.0;`math.Round`)
- **networth 新模块**(`internal/networth/`):3 跨模块 port(结构实现,networth 不 import account/holding/debt,同 D-goal `AccountMarketValueSource` 模式)
- **统一可配**:`GetNetWorth` + `GetPortfolioPerformance` + `GetHoldingPerformance` 都接 `baseCurrency` 参数
- **wire 工具链坏**:`wire_gen.go` 手改镜像 B/C/D-goal,不跑 wire CLI(见 [[yucai-wire-handmaintained]])
- **Dart stub**:`cd yucai/proto && bash gen-dart.sh`(make 不在 PATH;protoc_plugin 25.0.0)。Go stub:`buf generate --template buf.gen.go.yaml`
- **English 结构化日志**(CLAUDE.md AI 约束#2)
- **复用第一**:convertToBase 复用(C 组合曲线 + realized + networth);networth port 复用 D-goal 结构 port 模式
- **每 task 末尾 commit**:中文 conventional
- **flutter analyze 基线 = 22 error**(全 `*.pbserver.dart`,客户端未用)

## File Structure

### server 新建
- `yucai/server/internal/networth/domain/repository.go` — 3 port(AccountBalanceSource/HoldingMarketValueSource/DebtSource)
- `yucai/server/internal/networth/application/service.go` — GetNetWorth
- `yucai/server/internal/networth/adapter/driving/grpc/networth_handler.go` — GetNetWorth handler
- `yucai/server/internal/currency/domain/convert.go` — convertToBase helper

### server 修改
- `yucai/server/internal/holding/application/service.go` — aggregateRealized/ForSecurity 加 base + SumMarketValueByCurrency + GetPortfolioPerformance/GetHoldingPerformance 加 baseCurrency
- `yucai/server/internal/account/application/service.go` — SumBalancesByCurrency
- `yucai/server/internal/debt/application/service.go` — SumRemainingByCurrency
- `yucai/proto/networth/v1/service.proto`(新)— GetNetWorth RPC
- `yucai/proto/holding/v1/holding.proto` — GetPortfolioPerformance/GetHoldingPerformance Request 加 base_currency
- `yucai/server/wire/providers.go` + `wire_gen.go`(手改)+ `app.go` + `cmd/server/main.go`

### Flutter 修改
- `yucai/client/lib/currency/data/currency_settings.dart`(新)— flutter_secure_storage baseCurrency
- `yucai/client/lib/holding/data/networth_ds.dart`(新)— GetNetWorth
- `yucai/client/lib/auth/presentation/pages/home_page.dart` — 调 GetNetWorth 修 bug
- settings 页 picker + performance/detail 传 baseCurrency

---

## Task 0: 前置(确认 + 清工作区)

**Files:** 无改动(验证 task)

- [ ] **Step 1: 确认 flutter_secure_storage + rate_history + account/debt List**

```bash
grep -n "flutter_secure_storage" /e/projects/syfinance/yucai/client/pubspec.yaml
grep -n "func.*FindRate" /e/projects/syfinance/yucai/server/internal/currency/adapter/driven/repository/rate_history_repo.go
grep -n "func (s \*Service) ListAccounts\|func (s \*Service) FindByAccountType\|func (s \*Service) ListDebts" /e/projects/syfinance/yucai/server/internal/account/application/service.go /e/projects/syfinance/yucai/server/internal/debt/application/service.go
```
Expected:`flutter_secure_storage: ^9.2.4`;`FindRate` 存在;`ListAccounts`/`FindByAccountType`/`ListDebts` 存在(无 Σ by currency —— Task 5 加)。

- [ ] **Step 2: 确认工作区干净 + server/flutter build 绿(D-currency 起点)**

```bash
git -C /e/projects/syfinance status --short
cd /e/projects/syfinance/yucai/server && go build ./...
```
Expected:干净 + build 绿。记 HEAD(=1460b21 spec commit 的后)为 D-currency 起点。

(本 task 无 commit —— 纯验证)

---

## Task 1: convertToBase helper(currency/domain 纯函数)

**Files:**
- Create: `yucai/server/internal/currency/domain/convert.go`
- Test: `yucai/server/internal/currency/domain/convert_test.go`

**Interfaces:**
- Produces:`ConvertToBase(amount int64, rateFrom, rateBase float64) int64`(纯函数,caller 取 rate)—— Task 2/3/4 用

**背景**:rate_history CNY-base(1 外币 = X CNY)。任意 base 经 CNY 交叉:`amount × rate[from] / rate[base]`。

- [ ] **Step 1: 写失败测试(convert_test.go)**

```go
package domain

import "testing"

func TestConvertToBaseCrossRate(t *testing.T) {
	// 1000 USD → CNY base: rate[USD]=7.0, rate[CNY]=1.0 → 1000×7/1 = 7000
	got := ConvertToBase(1000, 7.0, 1.0)
	if got != 7000 {
		t.Fatalf("USD→CNY: got %d, want 7000", got)
	}
	// 7000 CNY → USD base: rate[CNY]=1.0, rate[USD]=7.0 → 7000×1/7 = 1000
	got = ConvertToBase(7000, 1.0, 7.0)
	if got != 1000 {
		t.Fatalf("CNY→USD: got %d, want 1000", got)
	}
}

func TestConvertToBaseSameCurrency(t *testing.T) {
	// from==base (rate 相等) → amount 不变
	got := ConvertToBase(500, 7.0, 7.0)
	if got != 500 {
		t.Fatalf("same currency: got %d, want 500", got)
	}
}

func TestConvertToBaseMissingRateFallback(t *testing.T) {
	// rate 缺失(caller 传 1.0)→ 原币(amount × 1 / 1)
	got := ConvertToBase(300, 1.0, 1.0)
	if got != 300 {
		t.Fatalf("missing rate: got %d, want 300", got)
	}
}

func TestConvertToBaseRounding(t *testing.T) {
	// 34.80 × 7 / 1 = 243.6 → round 244(浮点防护)
	got := ConvertToBase(3480, 7.0, 1.0) // 3480 cents × 7 = 24360
	if got != 24360 {
		t.Fatalf("rounding: got %d, want 24360", got)
	}
}
```

- [ ] **Step 2: 跑测试验证 FAIL**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/currency/domain/ -run ConvertToBase -v -count=1
```
Expected:FAIL / 编译错误(`ConvertToBase` 未定义)。

- [ ] **Step 3: 实现 convert.go**

```go
package domain

import "math"

// ConvertToBase 折算 amount 从 fromCode 到 baseCode,经 CNY-base rate 交叉。
// rateFrom/rateBase 由 caller 经 RateHistoryRepository.FindRate 取(1 外币 = X CNY)。
// 公式:amount × rateFrom / rateBase。from==base(rate 相等)→ amount 不变。
// rate 缺失(caller 传 1.0)→ 原币。math.Round 防浮点截断。
func ConvertToBase(amount int64, rateFrom, rateBase float64) int64 {
	if rateBase == 0 {
		return amount // 防除零(不应发生,CNY base=1.0)
	}
	return int64(math.Round(float64(amount) * rateFrom / rateBase))
}
```

- [ ] **Step 4: 跑测试验证 PASS + build**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/currency/domain/ -run ConvertToBase -v -count=1
cd /e/projects/syfinance/yucai/server && go build ./...
```
Expected:4 测 PASS + build 绿。

- [ ] **Step 5: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/internal/currency/domain/convert.go yucai/server/internal/currency/domain/convert_test.go
git commit -m "feat(holding-d-currency-server): convertToBase helper(CNY-base 交叉汇率折算)

ConvertToBase(amount, rateFrom, rateBase) = amount × rateFrom / rateBase。
经 CNY 交叉(任意 base)。同币不变+缺失 1.0 fallback+math.Round 防浮点。
纯函数(caller 取 rate)。4 单测(交叉/同币/缺失/rounding)。"
```

---

## Task 2: realized 折算(holding aggregateRealized + base 参数,C defer 接)

**Files:**
- Modify: `yucai/server/internal/holding/application/service.go`(aggregateRealized/aggregateRealizedForSecurity 加 baseCurrency)
- Test: `yucai/server/internal/holding/application/service_test.go`

**Interfaces:**
- Consumes:`currency/domain.ConvertToBase`(Task 1)+ `rateRepo.FindRate`(C 注入)+ `securityRepo.FindByID`(trade → security.CurrencyCode)
- Produces:`aggregateRealized(ctx, tenantID, baseCurrency)` / `aggregateRealizedForSecurity(ctx, tenantID, accountID, securityID, baseCurrency)` 折算到 base —— Task 3(GetPortfolioPerformance/GetHoldingPerformance)用

**背景**:C defer 点([service.go:728-751](../../yucai/server/internal/holding/application/service.go#L728) 原币相加)。D-currency 加 base 折算:每 trade → security.CurrencyCode → FindRate(code, tradeDate)+ FindRate(base) → ConvertToBase → Σ base。照 `samplePortfolioCNY:696-699` 模式。

- [ ] **Step 1: Read aggregateRealized/ForSecurity 现状**

```bash
grep -n "func.*aggregateRealized\|sum += tr.RealizedPnLCents\|sum += tr.AmountCents" /e/projects/syfinance/yucai/server/internal/holding/application/service.go
```
记下:`aggregateRealized`(组合级,~line 727-751)+ `aggregateRealizedForSecurity`(单 holding,~753-776)签名 + 原币相加点。

- [ ] **Step 2: 写失败测试(service_test.go 追加)**

```go
func TestAggregateRealizedConvertsToBase(t *testing.T) {
	// seed: g1 sell trade realized=2000 USD-cents(sec currencyCode=USD),g2 dividend=500 CNY
	// baseCurrency=CNY, rate[USD]=7.0(tradeDate), rate[CNY]=1.0
	// expected: 2000×7/1 + 500×1/1 = 14000 + 500 = 14500 CNY
	// fakeRateRepo 返 USD=7.0(findRate(code,tradeDate))
	// fakeSecurityRepo 返 sec.CurrencyCode="USD"
	// 调 aggregateRealized(ctx, tenantID, "CNY") → 14500
	t.Skip("Step 4 实现:照 C fakeSecurityRepo/fakeRateRepo/fakeTradeRepo 模式 seed 多币种 trade,断言 base 折算 Σ")
}

func TestAggregateRealizedDefaultBaseCNY(t *testing.T) {
	// baseCurrency="" 或 "CNY" → CNY base(rate[CNY]=1.0)
}
```

- [ ] **Step 3: 跑测试验证 FAIL**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/application/ -run AggregateRealized -v -count=1
```
Expected:FAIL(签名变更:`aggregateRealized` 加 baseCurrency 参数,现有调用方需改 —— Task 3 GetPortfolioPerformance 传 base)。

- [ ] **Step 4: 改 aggregateRealized/ForService 加 baseCurrency + 折算**

`aggregateRealized` 签名加 `baseCurrency string`。每 trade 折算:
```go
func (s *Service) aggregateRealized(ctx context.Context, tenantID uuid.UUID, baseCurrency string) (int64, error) {
	base := baseCurrency
	if base == "" { base = "CNY" }
	rateBase, _ := s.rateRepo.FindRate(ctx, base, time.Now()) // base→CNY rate(CNY=1.0)
	sum := int64(0)
	// 遍历 trades(现有分页逻辑)
	for _, tr := range trades {
		sec, _ := s.securityRepo.FindByID(ctx, tr.SecurityID)
		code := "CNY"
		if sec != nil { code = sec.CurrencyCode }
		rateFrom, _ := s.rateRepo.FindRate(ctx, code, tr.TradeDate)
		amount := tr.RealizedPnLCents
		if tr.TradeType == domain.TradeTypeDividend {
			amount = tr.AmountCents
		}
		sum += currencydomain.ConvertToBase(amount, rateFrom, rateBase)
	}
	return sum, nil
}
```
> `aggregateRealizedForSecurity` 同(加 baseCurrency)。`currencydomain` alias for `currency/domain`。`rateRepo.FindRate` 缺失返 1.0(C 建)。**移除 C defer 注释**。

- [ ] **Step 5: 补全测试(去 t.Skip,seed 多币种 trade + fakeRateRepo + fakeSecurityRepo,断言折算 Σ)**

照 C fakeSecurityRepo/fakeRateRepo/fakeTradeRepo 模式(Task 6 C 的 fake)。`TestAggregateRealizedConvertsToBase`:USD sell realized 2000 + CNY dividend 500,base CNY,rate[USD]=7.0 → 14500。

- [ ] **Step 6: 修复签名变更调用方**

`aggregateRealized`/`ForSecurity` 加了 baseCurrency 参数,现有调用方(`GetPortfolioPerformance`/`GetHoldingPerformance`,C 建)需补参数(暂传 "CNY",Task 3 改 baseCurrency)。grep 调用方:
```bash
grep -n "aggregateRealized" /e/projects/syfinance/yucai/server/internal/holding/application/service.go
```

- [ ] **Step 7: 跑测试 + build**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/application/ -run AggregateRealized -v -count=1
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/application/ -count=1
cd /e/projects/syfinance/yucai/server && go build ./...
```
Expected:测 PASS + holding application 回归 + build 绿。

- [ ] **Step 8: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/internal/holding/application/
git commit -m "feat(holding-d-currency-server): realized 多币种折算(C defer 接)

aggregateRealized/ForSecurity 加 baseCurrency 参数。每 trade → security.CurrencyCode
→ FindRate(code, tradeDate)+ FindRate(base)→ ConvertToBase → Σ base。
照 samplePortfolioCNY 模式。移除 C defer 注释。单测(多币种折算+默认 CNY)。"
```

---

## Task 3: GetPortfolioPerformance/GetHoldingPerformance 加 baseCurrency(统一可配)

**Files:**
- Modify: `yucai/server/internal/holding/application/service.go`(GetPortfolioPerformance/GetHoldingPerformance/samplePortfolioCNY/currentUnrealizedCNY/currentCostBasisCNY)
- Modify: `yucai/server/internal/holding/application/dto.go`(PortfolioPerformance/HoldingPerformance 请求加 BaseCurrency)
- Test: `yucai/server/internal/holding/application/service_test.go`

**Interfaces:**
- Consumes:`ConvertToBase`(Task 1)+ `aggregateRealized`(Task 2 base)+ `rateRepo.FindRate`
- Produces:`GetPortfolioPerformance(ctx, tenantID, accountID*, range, withBenchmark, baseCurrency)` / `GetHoldingPerformance(ctx, holdingID, range, baseCurrency)` —— Task 7(handler/proto base)用

**背景**:C 硬编码 CNY([service.go:665](../../yucai/server/internal/holding/application/service.go#L665))。D-currency 加 baseCurrency 参数:`samplePortfolioCNY → samplePortfolioInBase`、`currentUnrealizedCNY → InBase`、`currentCostBasisCNY → InBase`、Currency=base。

- [ ] **Step 1: dto.go 加 BaseCurrency**

`PortfolioPerformance`/`HoldingPerformance` 相关请求(若有独立请求 struct)或方法参数加 `BaseCurrency string`。Read dto.go 确认现有请求 struct(Task 6 C 可能 GetPortfolioPerformance 直接参数,非 DTO)。

- [ ] **Step 2: 改 GetPortfolioPerformance 加 baseCurrency 参数**

签名([service.go:640](../../yucai/server/internal/holding/application/service.go#L640))加 `baseCurrency string`:
```go
func (s *Service) GetPortfolioPerformance(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, rangeName string, withBenchmark bool, baseCurrency string) (*PortfolioPerformance, error) {
	base := baseCurrency
	if base == "" { base = "CNY" }
	// samplePortfolioCNY → 传 base(内部 ConvertToBase)
	// aggregateRealized(ctx, tenantID, base)(Task 2)
	// currentUnrealizedCNY/costBasisCNY → 传 base
	// out.Currency = base(非硬编码 CNY)
}
```

- [ ] **Step 3: 改 samplePortfolioCNY → samplePortfolioInBase**

`samplePortfolioCNY`([service.go:674](../../yucai/server/internal/holding/application/service.go#L674))加 `baseCurrency` 参数,折算用 `ConvertToBase(mv, rateFrom, rateBase)`(rateBase = FindRate(base)):
```go
func (s *Service) samplePortfolioInBase(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, from, to time.Time, granularity string, baseCurrency string) (map[time.Time]int64, error) {
	base := baseCurrency; if base == "" { base = "CNY" }
	rateBase, _ := s.rateRepo.FindRate(ctx, base, time.Now())
	// ... 现有 bucket 逻辑
	// 每桶:rateFrom = FindRate(sn.CurrencyCode, sn.SnapshotDate);ConvertToBase(mv, rateFrom, rateBase)
}
```
> `currentUnrealizedCNY`/`currentCostBasisCNY` 同改(→ InBase,加 baseCurrency,ConvertToBase)。函数改名(CNY → InBase)或保留名+加参数(参数化)—— 推荐改名清晰。

- [ ] **Step 4: 改 GetHoldingPerformance 加 baseCurrency + aggregateRealizedForSecurity 传 base**

- [ ] **Step 5: 修复调用方(签名变更)**

GetPortfolioPerformance/GetHoldingPerformance 加了 baseCurrency 参数,现有调用方(handler Task 7 传 proto base;Task 7 修)。本 task 先确认 application 内部测试 + handler 暂传 "CNY"(Task 7 改 proto base)。

- [ ] **Step 6: 写测试(多币种组合 base 切换)**

`TestGetPortfolioPerformanceBaseCurrency`:seed CNY+USD holdings,base=CNY → Σ CNY;base=USD → Σ USD(交叉)。验证 Currency=base。

- [ ] **Step 7: 跑测试 + build**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/application/ -v -count=1
cd /e/projects/syfinance/yucai/server && go build ./...
```
Expected:测 PASS(含 Task 2 realized base)+ build 绿。

- [ ] **Step 8: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/internal/holding/application/
git commit -m "feat(holding-d-currency-server): GetPortfolioPerformance/GetHoldingPerformance 加 baseCurrency

统一可配 base。samplePortfolioCNY→InBase/currentUnrealized/costBasis 全 ConvertToBase
到 base。Currency=base(非硬编码 CNY)。aggregateRealized 传 base(Task 2)。
多币种组合 base 切换测(CNY/USD 交叉)。"
```

---

## Task 4: networth 模块(domain 3 port + application GetNetWorth)

**Files:**
- Create: `yucai/server/internal/networth/domain/repository.go`(3 port + result)
- Create: `yucai/server/internal/networth/application/service.go`(GetNetWorth)
- Test: `yucai/server/internal/networth/application/service_test.go`

**Interfaces:**
- Consumes:`currency/domain.ConvertToBase`(Task 1)+ `rateRepo.FindRate`
- Produces:`GetNetWorth(ctx, tenantID, baseCurrency) → GetNetWorthResult`;3 port 供 Task 5 结构实现

**背景**:新 networth 模块,跨模块聚合。3 port 结构实现(account/holding/debt,Task 5 加 SumByCurrency)。networth 不 import account/holding/debt(同 D-goal `AccountMarketValueSource` 模式)。

- [ ] **Step 1: domain/repository.go(3 port + result)**

```go
package domain

import (
	"context"
	"github.com/google/uuid"
)

// AccountBalanceSource reports per-currency Σ balances (asset accounts only).
// Implemented by account/application.Service (structural — networth doesn't import account).
type AccountBalanceSource interface {
	SumBalancesByCurrency(ctx context.Context, tenantID uuid.UUID) (map[string]int64, error)
}

// HoldingMarketValueSource reports per-currency Σ market value (qty × current price).
// Implemented by holding/application.Service.
type HoldingMarketValueSource interface {
	SumMarketValueByCurrency(ctx context.Context, tenantID uuid.UUID) (map[string]int64, error)
}

// DebtSource reports per-currency Σ remaining principal.
// Implemented by debt/application.Service.
type DebtSource interface {
	SumRemainingByCurrency(ctx context.Context, tenantID uuid.UUID) (map[string]int64, error)
}

// GetNetWorthResult is the aggregated net-worth in baseCurrency.
type GetNetWorthResult struct {
	TotalAssetsCents     int64
	TotalLiabilitiesCents int64
	NetWorthCents        int64
	Currency             string
}
```

- [ ] **Step 2: application/service.go(GetNetWorth)**

```go
package application

import (
	"context"
	"log/slog"

	"github.com/google/uuid"
	currencydomain "github.com/yucai/server/internal/currency/domain"
	"github.com/yucai/server/internal/networth/domain"
)

type Service struct {
	accounts domain.AccountBalanceSource
	holdings domain.HoldingMarketValueSource
	debts    domain.DebtSource
	rateRepo func(ctx context.Context, code string, date interface{ Get() string }) (float64, error) // 简化:实际 RateHistoryRepository.FindRate(ctx, code, time.Time)
	log      *slog.Logger
}

func NewService(a domain.AccountBalanceSource, h domain.HoldingMarketValueSource, d domain.DebtSource, log *slog.Logger) *Service {
	if log == nil { log = slog.Default() }
	return &Service{accounts: a, holdings: h, debts: d, log: log}
}

// GetNetWorth aggregates account balances + holding mv − debt remaining,
// converting each currency to baseCurrency via CNY-base rate_history cross-rate.
func (s *Service) GetNetWorth(ctx context.Context, tenantID uuid.UUID, baseCurrency string) (*domain.GetNetWorthResult, error) {
	base := baseCurrency
	if base == "" { base = "CNY" }
	// rateRepo injected as RateHistoryRepository (Task 8 wire); FindRate(code, today)
	// rateBase = FindRate(base, today); rateBase==1.0 if missing
	var assets, liab int64
	// Σ account balances → base
	if m, err := s.accounts.SumBalancesByCurrency(ctx, tenantID); err == nil {
		for code, amt := range m { assets += s.toBase(ctx, amt, code, base) }
	} else { s.log.Warn("networth: account sum failed", "error", err) }
	// Σ holding mv → base
	if m, err := s.holdings.SumMarketValueByCurrency(ctx, tenantID); err == nil {
		for code, amt := range m { assets += s.toBase(ctx, amt, code, base) }
	} else { s.log.Warn("networth: holding sum failed", "error", err) }
	// Σ debt remaining → base
	if m, err := s.debts.SumRemainingByCurrency(ctx, tenantID); err == nil {
		for code, amt := range m { liab += s.toBase(ctx, amt, code, base) }
	} else { s.log.Warn("networth: debt sum failed", "error", err) }
	return &domain.GetNetWorthResult{
		TotalAssetsCents: assets, TotalLiabilitiesCents: liab,
		NetWorthCents: assets - liab, Currency: base,
	}, nil
}
```
> `toBase` helper:取 rateFrom=FindRate(code)、rateBase=FindRate(base),`currencydomain.ConvertToBase(amt, rateFrom, rateBase)`。注入 `RateHistoryRepository`(Task 8 wire,字段 `rateRepo domain.RateHistoryRepository`,签名 `FindRate(ctx, code, time.Time) → float64`)。best-effort(port fail 跳过+日志)。

- [ ] **Step 3: 写测试(service_test.go)**

```go
// fakeAccountSource/fakeHoldingSource/fakeDebtSource(map[code]int64)
// fakeRateRepo(code→rate,CNY=1.0,USD=7.0)
// TestGetNetWorthMultiCurrencyBaseCNY: account CNY 10000 + holding USD 1000mv + debt CNY 5000
//   base CNY → assets=10000 + 1000×7=7000 = 17000; liab=5000; net=12000
// TestGetNetWorthBaseUSD: base USD → assets=10000/7 + 1000 = ~2429; liab=5000/7=~714; net=~1714
// TestGetNetWorthBestEffortSkipFailedPort: account error → skip, holding+debt still Σ
```

- [ ] **Step 4: build + commit**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/networth/... -v -count=1 && go build ./...
cd /e/projects/syfinance && git add yucai/server/internal/networth/ && git commit -m "feat(holding-d-currency-server): networth 模块(GetNetWorth 跨模块聚合+3 port)"
```

---

## Task 5: account/holding/debt 加 SumByCurrency(结构满足 networth port)

**Files:**
- Modify: `account/application/service.go`(SumBalancesByCurrency)
- Modify: `holding/application/service.go`(SumMarketValueByCurrency)
- Modify: `debt/application/service.go`(SumRemainingByCurrency)
- Test: 各 application test

**Interfaces:**
- Produces:3 方法结构满足 networth 3 port(Task 4)

- [ ] **Step 1: account SumBalancesByCurrency(遍历 ListAccounts/FindByAccountType → map[code]Σ balance)**

```go
func (s *Service) SumBalancesByCurrency(ctx context.Context, tenantID uuid.UUID) (map[string]int64, error) {
	byCur := map[string]int64{}
	// asset accounts only(现金/投资/固定);分页遍历 ListAccounts(asset type)
	// byCur[a.CurrencyCode] += a.CurrentBalanceCents
	return byCur, nil
}
```
> Read ListAccounts/FindByAccountType 分页模式,遍历 asset accounts Σ by CurrencyCode。负债账户(category=liability)排除(或在 networth 作 liab?首批 asset only,debt 单独)。

- [ ] **Step 2: holding SumMarketValueByCurrency(遍历 ListHoldings → Σ mv by security.CurrencyCode)**

```go
func (s *Service) SumMarketValueByCurrency(ctx context.Context, tenantID uuid.UUID) (map[string]int64, error) {
	byCur := map[string]int64{}
	// 分页遍历 ListHoldings(tenantID);每 holding h.MarketValue(sec.CurrentPriceCents)
	// byCur[sec.CurrencyCode] += mv
	return byCur, nil
}
```
> 复用 `Holding.MarketValue`(C/D-goal)。分页(PageSize 100 循环)。

- [ ] **Step 3: debt SumRemainingByCurrency(遍历 ListDebts → Σ remaining by debt.CurrencyCode)**

```go
func (s *Service) SumRemainingByCurrency(ctx context.Context, tenantID uuid.UUID) (map[string]int64, error) {
	byCur := map[string]int64{}
	// 分页遍历 ListDebts(tenantID);byCur[d.CurrencyCode] += d.RemainingPrincipalCents
	return byCur, nil
}
```
> Read debt domain(DTO 有 RemainingPrincipalCents / CurrencyCode)。

- [ ] **Step 4: 各单测 + build + commit**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/account/... ./internal/holding/... ./internal/debt/... -count=1 && go build ./...
cd /e/projects/syfinance && git commit -am "feat(holding-d-currency-server): account/holding/debt SumByCurrency(结构满足 networth port)"
```

---

## Task 6: networth proto + handler

**Files:**
- Create: `yucai/proto/networth/v1/service.proto`
- Create: `yucai/server/internal/networth/adapter/driving/grpc/networth_handler.go`
- Regenerate Go/Dart stub

- [ ] **Step 1: proto/networth/v1/service.proto**

```proto
syntax = "proto3";
package yucai.networth.v1;
option go_package = "github.com/yucai/server/internal/proto/networth/v1";

service NetWorthService {
  rpc GetNetWorth(GetNetWorthRequest) returns (GetNetWorthResponse);
}

message GetNetWorthRequest {
  string base_currency = 1;  // 空/CNY=CNY;用户可配 base
}

message GetNetWorthResponse {
  int64 total_assets_cents = 1;
  int64 total_liabilities_cents = 2;
  int64 net_worth_cents = 3;
  string currency = 4;
}
```

- [ ] **Step 2: 重生成 stub**

```bash
cd /e/projects/syfinance/yucai/proto && buf generate --template buf.gen.go.yaml
dart pub global activate protoc_plugin 25.0.0 && bash gen-dart.sh
```

- [ ] **Step 3: networth_handler.go**

```go
// GetNetWorth: getTenantID + req.BaseCurrency → service.GetNetWorth → 映射 response
func (h *NetWorthHandler) GetNetWorth(ctx context.Context, req *pb.GetNetWorthRequest) (*pb.GetNetWorthResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil { return nil, status.Error(codes.Unauthenticated, err.Error()) }
	res, err := h.service.GetNetWorth(ctx, tenantID, req.GetBaseCurrency())
	if err != nil { return nil, mapError(err) }
	return &pb.GetNetWorthResponse{
		TotalAssetsCents: res.TotalAssetsCents,
		TotalLiabilitiesCents: res.TotalLiabilitiesCents,
		NetWorthCents: res.NetWorthCents,
		Currency: res.Currency,
	}, nil
}
```

- [ ] **Step 4: handler 测 + build + commit**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/networth/... -count=1 && go build ./...
cd /e/projects/syfinance && git add yucai/proto/networth/ yucai/server/internal/proto/networth/ yucai/server/internal/networth/ yucai/client/lib/proto/networth/ && git commit -m "feat(holding-d-currency-proto): networth GetNetWorth RPC + handler + stub"
```

---

## Task 7: holding proto base_currency + handler 改

**Files:**
- Modify: `yucai/proto/holding/v1/holding.proto`(GetPortfolioPerformance/GetHoldingPerformance Request 加 base_currency)
- Modify: `yucai/server/internal/holding/adapter/driving/grpc/holding_handler.go`(传 base)
- Regenerate stub

- [ ] **Step 1: proto 加 base_currency 字段(2 Request)**

```proto
message GetPortfolioPerformanceRequest { ...; string base_currency = 4; }
message GetHoldingPerformanceRequest { ...; string base_currency = 3; }
```

- [ ] **Step 2: 重生成 stub(buf generate + gen-dart)**

- [ ] **Step 3: handler 读 req.BaseCurrency → service.GetPortfolioPerformance/GetHoldingPerformance(base)**

```go
perf, err := h.service.GetPortfolioPerformance(ctx, tenantID, accountID, rangeName, withBenchmark, req.GetBaseCurrency())
// GetHoldingPerformance 同(req.GetBaseCurrency())
```

- [ ] **Step 4: handler 测(base 切换)+ build + commit**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/adapter/driving/grpc/ -count=1 && go build ./...
cd /e/projects/syfinance && git commit -am "feat(holding-d-currency-proto): GetPortfolioPerformance/GetHoldingPerformance 加 base_currency + handler"
```

---

## Task 8: wire + main(networth 接线 + 3 port 注入)

**Files:**
- Modify: `wire/providers.go`(provideNetWorthService + provideNetWorthHandler)
- Modify: `wire/wire_gen.go`(**手改**)
- Modify: `wire/app.go` + `cmd/server/main.go`(注册 networth gRPC)

- [ ] **Step 1: providers.go**

```go
func provideNetWorthService(acc *accountapp.Service, h *holdingapp.Service, d *debtapp.Service, rateRepo goaldomain.RateHistoryRepository, log *slog.Logger) *networthapp.Service {
	// acc/h/d 结构满足 networth 3 port(Task 5);rateRepo = currency rate_history(wire 适配 holding RateHistoryRepository 或直接)
	return networthapp.NewService(acc, h, d, log) // + rateRepo 注入(签名按 Task 4)
}
func provideNetWorthHandler(svc *networthapp.Service) *networthgrpc.NetWorthHandler {
	return networthgrpc.NewNetWorthHandler(svc)
}
```
> Read wire_gen.go + providers.go 现有(accountSvc/holdingSvc/debtSvc/rateHistoryRepo 已在)。镜像 D-goal/C scheduler 行。

- [ ] **Step 2: wire_gen.go 手改(networthService/networthHandler + NewApp)+ app.go + main.go**

```go
// wire_gen.go:
networthService := provideNetWorthService(accountService, holdingService, debtService, currencyRateHistoryRepo, nil)
networthHandler := provideNetWorthHandler(networthService)
// NewApp 加 networthHandler;app.go App.NetWorthHandler 字段
// main.go: pb.RegisterNetWorthServiceServer(grpcServer, app.NetWorthHandler)
```

- [ ] **Step 3: build + 全量 test**

```bash
cd /e/projects/syfinance/yucai/server && go build ./... && go test ./... -count=1
```

- [ ] **Step 4: commit**

```bash
cd /e/projects/syfinance && git commit -am "feat(holding-d-currency-server): wire+main networth 接线(3 port 注入 account/holding/debt)"
```

---

## Task 9: server 端到端验证(我自做,无 commit)

**Files:** 无改动

- [ ] **Step 1: 重建 server + 起 background**(memory yucai-dev-env env)

- [ ] **Step 2: grpcurl GetNetWorth(default CNY + base=USD)**

登录(test@yucai.local/test1234)拿 token,grpcurl:
```
grpcurl -H "authorization: Bearer <token>" -d '{"base_currency":""}' localhost:9090 yucai.networth.v1.NetWorthService/GetNetWorth
grpcurl -H "authorization: Bearer <token>" -d '{"base_currency":"USD"}' localhost:9091 yucai.networth.v1.NetWorthService/GetNetWorth
```
Expected:default CNY 返 total_assets/liabilities/net_worth(CNY);USD 返折算后(数值不同,currency=USD)。

- [ ] **Step 3: 验证 GetPortfolioPerformance base**

grpcurl GetPortfolioPerformance(base_currency=USD)→ Currency=USD,曲线/realized 折算。

- [ ] **Step 4: TaskStop server,记 ledger**(无 commit)

---

## Task 10: Flutter CurrencySettings(flutter_secure_storage baseCurrency)

**Files:**
- Create: `yucai/client/lib/currency/data/currency_settings.dart`
- Test: `yucai/client/test/currency/data/currency_settings_test.dart`

**Interfaces:**
- Produces:`CurrencySettings.getBaseCurrency() → Future<String>`(默认 "CNY")+ `setBaseCurrency(code)`

- [ ] **Step 1: currency_settings.dart(flutter_secure_storage ^9.2.4)**

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CurrencySettings {
  CurrencySettings(this._storage);
  final FlutterSecureStorage _storage;
  static const _key = 'base_currency';

  Future<String> getBaseCurrency() async {
    final v = await _storage.read(key: _key);
    return v?.isNotEmpty == true ? v! : 'CNY';
  }
  Future<void> setBaseCurrency(String code) async {
    await _storage.write(key: _key, value: code);
  }
}
```
> DI 注册(@LazySingleton,注入 FlutterSecureStorage)。御财现有 flutter_secure_storage(pubspec.yaml:38)。

- [ ] **Step 2: 测(mock FlutterSecureStorage)+ build_runner + commit**

---

## Task 11: Flutter home(GetNetWorth 修 bug)

**Files:**
- Modify: `yucai/client/lib/auth/presentation/pages/home_page.dart`(替换原币直加 fold)
- Create: `yucai/client/lib/holding/data/networth_ds.dart`(GetNetWorth ds)
- Test: `home_page_test.dart`

- [ ] **Step 1: networth_ds.dart**(调 NetWorthServiceClient.getNetWorth,GrpcClient+AuthRetryCaller 模式对齐 HoldingRemoteDataSource)

- [ ] **Step 2: home_page.dart _NetWorthCard 调 GetNetWorth(baseCurrency)** 替换 [home_page.dart:84-90](../../yucai/client/lib/auth/presentation/pages/home_page.dart#L84) 原币直加 fold。显示 total_assets/liabilities/net_worth + base 符号(非硬编码 ¥)。

- [ ] **Step 3: widget test(真数据+base 切换+错误态)+ commit**

---

## Task 12: Flutter performance/detail + settings picker

**Files:**
- Modify: performance_page.dart / holding_detail_page.dart(传 baseCurrency)
- Create/Modify: settings 页 baseCurrency picker

- [ ] **Step 1: performance/detail 传 baseCurrency**(从 CurrencySettings 读 → GetPortfolioPerformance/GetHoldingPerformance)
- [ ] **Step 2: settings 页 picker**(CNY/USD/EUR/...,从 currency 模块;切换 → setBaseCurrency + 刷新 home/performance)
- [ ] **Step 3: widget test + commit**

---

## Task 13: 全链路 + final whole-branch review

- [ ] **Step 1: server go test ./... + flutter test + analyze 全绿**
- [ ] **Step 2: flutter run**(home 显示 net-worth base + performance base + settings 切换刷新)
- [ ] **Step 3: final review**(opus,MERGE_BASE = e801097 D-goal 终点,D-currency commits 从 1460b21 spec 起)

---

## Self-Review(plan 自查)

**1. Spec coverage**(对照 spec 各节):
- §1 realized defer → Task 2 ✅;net-worth bug → Task 11 ✅;统一可配 → Task 3/7 ✅
- §3 架构(networth+convertToBase+统一)→ Task 1/3/4/8 ✅
- §4.1 convertToBase → Task 1 ✅;§4.2 networth 模块 → Task 4 ✅;§4.3 realized → Task 2 ✅;§4.4 GetPerf base → Task 3 ✅;§4.5 proto → Task 6/7 ✅;§4.6 wire → Task 8 ✅
- §5 零新表 → 全 plan 无 ent schema ✅
- §6 Flutter home/settings/performance → Task 10/11/12 ✅
- §7 降级 → Task 4 best-effort + Task 1 1.0 fallback ✅
- §8 测试 → 每 task TDD ✅
- §9 前置 → Task 0 ✅

**2. Placeholder scan**:Task 9 grpcurl token(标"<token>"占位,运行时填);Task 4 rateRepo 注入签名(标注 Task 8 wire 确认)—— 必要的运行时/接口发现,非内容缺失。

**3. Type consistency**:
- `ConvertToBase(amount, rateFrom, rateBase)` Task 1 → Task 2/3/4 调用一致 ✅
- `aggregateRealized(ctx, tenantID, baseCurrency)` Task 2 → Task 3 调用一致 ✅
- `GetNetWorth(ctx, tenantID, baseCurrency) → GetNetWorthResult` Task 4 → Task 6 handler 一致 ✅
- `SumByCurrency(tenantID) → map[string]int64` Task 4 port → Task 5 结构实现一致 ✅
- proto `base_currency` Task 6/7 → Dart stub Task 10-12 一致 ✅

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-07-01-holding-currency.md`。执行方式:subagent-driven(推荐,对齐 C/D-goal)。
