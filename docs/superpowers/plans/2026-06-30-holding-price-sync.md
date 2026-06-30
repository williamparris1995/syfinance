# Holding 子项目 B · 价格自动 sync 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 holding security 的 `current_price_cents` 能自动(每日 scheduler)+手动(Flutter 刷新按钮)更新,provider 可插拔(首批新浪 A 股真实源 + stub 兜底),并清掉 A 遗留的 ListHoldingTransactions ⏳ 降级。

**Architecture:** server 端新建 `holding/adapter/driven/priceprovider/`(Provider+Sina+Stub+Router 三件套,对齐 currency/exchangerate)+ `holding/scheduler/`(PriceScheduler,复用 currency scheduler 模式)+ `application.Service.SyncPrices`;proto 加 1 个 `SyncPrices` RPC;Flutter 加 syncPrices 全链路(remote_ds→repo→bloc→持仓页刷新 UX);schema 零改动。

**Tech Stack:** Go(net/http + golang.org/x/text GBK 解码 + ent + grpc)+ proto3 + Flutter(flutter_bloc + injectable + grpc stub)

## Global Constraints

- **分支**:`holding-asset-management`(不要在 main 上直接做)
- **wire 工具链 tree-wide 坏**:`wire_gen.go` 是手维护文件,改 provider 签名时**直接手改 `wire_gen.go` 镜像同模式行,不要跑 `go generate`/`wire` CLI**(见 [[yucai-wire-handmaintained]])。验证用 `cd yucai/server && go build ./...` 绿
- **Dart stub 重生成**:`cd yucai && make gen-dart`(需 protoc_plugin **25.0.0**;`dart pub global activate protoc_plugin 25.0.0`)。Go stub:`cd yucai && make proto`(= `buf generate`)
- **价格字段索引**:新浪 A 股 `hq.sinajs.cn` 返回字段顺序 = 今开(0)/昨收(1)/**当前价(2)**/最高(3)/最低(4)。**取索引 2**(spec §12 写"索引 3"有误,以本 plan 为准)
- **GBK 解码**:新浪响应是 GBK,必须用 `golang.org/x/text/encoding/simplifiedchinese.GBK.NewDecoder()` 解码(go.mod 已有 `golang.org/x/text v0.38.0`,可能为 indirect,import 后 `go mod tidy`)
- **English 结构化日志**:Rust/Go 日志全英文(CLAUDE.md AI 约束#2);CJK 只在用户可见 JSX/Dart UI(且走 i18n,但御财 Flutter 暂无强制 i18n,bloc 注释用中文 OK)
- **复用第一**:provider 三件套严格对齐 `currency/adapter/driven/exchangerate/`(FrankfurterProvider/MockProvider/Provider);scheduler 严格对齐 `currency/scheduler/`(Scheduler/NewScheduler/Start/SyncNow/doSync)
- **失败策略**:provider best-effort,单条失败不中断;`ErrNoSource`(非覆盖类型)跳过不动旧价;真错误(HTTP/解析)计日志。对齐 currency "errors logged but never exit loop"
- **每 task 末尾 commit**:conventional commit 中文 header(对齐 git log 风格),如 `feat(holding-b-server): ...`
- **schema 零改动**:Security 表不加字段;last-updated 由 Flutter client 本地记录(拍板点①)
- **stub 兜底**:非 A 股类型首批返回 `ErrNoSource`(不动旧价,不伪造行情)(拍板点②)
- **路由键 = exchange**(拍板点③):SSE→`sh`、SZSE→`sz`;首批覆盖 600519(茅台 SSE)/510300(300ETF SSE)/511010(国债ETF SSE)
- **spec refine**:spec §5.4 的 `SyncPricesResponse.failed_count` 在本 plan 去掉(对齐 currency `RateSyncer.SyncRates(ctx)(int,error)` 简洁契约;failed 仅 server 日志)。response = `{synced_count, synced_at}`
- **服务依赖方向**:application 层依赖 driven port 接口(`priceprovider.Router`),对齐 currency(application 依赖 `exchangerate.Provider`)。holding scheduler 包独立,`PriceSyncer` 接口返回 `(int, error)`,Service 直接实现

## File Structure

### server 新建
- `yucai/server/internal/holding/adapter/driven/priceprovider/provider.go` — Provider 接口 + PriceView + ErrNoSource
- `yucai/server/internal/holding/adapter/driven/priceprovider/sina.go` — SinaProvider(新浪 A 股,GBK)
- `yucai/server/internal/holding/adapter/driven/priceprovider/stub.go` — StubProvider(ErrNoSource 兜底)
- `yucai/server/internal/holding/adapter/driven/priceprovider/router.go` — CompositeRouter(按顺序路由)
- `yucai/server/internal/holding/adapter/driven/priceprovider/provider_test.go` — Stub + Router 单测
- `yucai/server/internal/holding/adapter/driven/priceprovider/sina_test.go` — SinaProvider httptest 单测
- `yucai/server/internal/holding/scheduler/scheduler.go` — PriceScheduler(复用 currency 模式)
- `yucai/server/internal/holding/scheduler/scheduler_test.go` — scheduler 单测

### server 修改
- `yucai/proto/holding/v1/holding.proto` — 加 SyncPrices RPC + 2 message(Task 1 后 make proto 重生成 .pb.go)
- `yucai/server/internal/holding/application/service.go` — 加 priceRouter 字段 + SetPriceRouter + SyncPrices
- `yucai/server/internal/holding/application/service_test.go` — SyncPrices 单测(新建或追加)
- `yucai/server/internal/holding/adapter/driving/grpc/holding_handler.go` — 加 SyncPrices handler
- `yucai/server/internal/holding/adapter/driving/grpc/holding_handler_test.go` — handler SyncPrices 单测
- `yucai/server/wire/providers.go` — providePriceRouter + 改 provideHoldingService 加 priceRouter 参数 + providePriceScheduler
- `yucai/server/wire/wire_gen.go` — **手改**(priceRouter/priceScheduler 变量 + holdingService 实参 + NewApp 调用)
- `yucai/server/wire/app.go` — App struct + NewApp 加 HoldingScheduler
- `yucai/server/cmd/server/main.go` — go priceScheduler.Start(schedCtx) + 注册 HoldingService 不变(RPC 已在)

### Flutter 修改(stub 由 Task 1 make gen-dart 生成)
- `yucai/client/lib/holding/data/holding_remote_ds.dart` — syncPrices()
- `yucai/client/lib/holding/domain/repositories/holding_repository.dart` — syncPrices 抽象
- `yucai/client/lib/holding/data/holding_repository_impl.dart` — syncPrices 实现
- `yucai/client/lib/holding/presentation/bloc/holding_event.dart` — RefreshPricesRequested
- `yucai/client/lib/holding/presentation/bloc/holding_state.dart` — HoldingLoaded 加 lastPriceSyncedAt(去 const)
- `yucai/client/lib/holding/presentation/bloc/holding_bloc.dart` — _onRefreshPrices + _lastPriceSyncedAt 字段
- `yucai/client/lib/holding/presentation/pages/holdings_page.dart` — 刷新按钮 + last-updated UX(对齐 OD 原型)
- `yucai/client/lib/holding/presentation/bloc/holding_bloc_test.dart` — _onRefreshPrices 单测

---

## Task 0: 前置清理(工作区卫生)

**Files:**
- Modify: `yucai/server/cmd/server/main.go`(已 staged 改动,提交)
- Delete: `design-output/holding/mock-data.task1.js.bak`、`design-output/holding/styles.task1.css.bak`、`nul`、`goal-link-desktop-final`、`goal-link-desktop.png`、`goal-link-mobile-final.png`、`goal-link-tablet-final.png`、`holding-detail-desktop-goalcard-fixed`

**背景**:工作区有 A 阶段遗留脏文件,先清掉再开 B,避免 B 的 commit 混入垃圾。`main.go` 是 A 收尾 seed 集中化(demo→test account),逻辑自洽。

- [ ] **Step 1: 提交 main.go(A 收尾)**

```bash
cd /e/projects/syfinance
git add yucai/server/cmd/server/main.go
git commit -m "fix(holding-server): seed 集中到 test account(test@yucai.local/test1234)

A 收尾:holding seed 不再遍历所有 tenant,只给 test 账号 seed holdings,
集中测试数据。其他 tenant 预期事先清空。"
```

- [ ] **Step 2: 删除垃圾文件**

```bash
cd /e/projects/syfinance
git rm -f design-output/holding/mock-data.task1.js.bak design-output/holding/styles.task1.css.bak nul 2>/dev/null
rm -f goal-link-desktop-final goal-link-desktop.png goal-link-mobile-final.png goal-link-tablet-final.png holding-detail-desktop-goalcard-fixed
```

注:`nul` 是 Windows `>nul` 误产物;`goal-link-*` / `holding-detail-desktop-goalcard-fixed` 是 A-od 临时导出。若 `git rm` 报 "did not match"(untracked),改用 `rm -f`。用 `git status` 确认这些文件消失。

- [ ] **Step 3: 验证工作区干净(除 spec/plan 文档)**

```bash
git -C /e/projects/syfinance status
```
Expected: 上述垃圾文件消失,只剩 docs/ 下本 plan 新文件(若已 add)。

- [ ] **Step 4: Commit 清理**

```bash
cd /e/projects/syfinance
git add -A
git commit -m "chore: 清理 A 阶段遗留垃圾文件(.bak/nul/goal-link 导出)"
```

---

## Task 1: proto 加 SyncPrices RPC + 重生成 stub

**Files:**
- Modify: `yucai/proto/holding/v1/holding.proto:21`(service 块末尾加 RPC)+ 文件末尾加 message
- Regenerate: `yucai/server/internal/proto/holding/v1/holding.pb.go`、`holding_grpc.pb.go`、`yucai/client/lib/proto/holding/v1/holding.pb.dart`、`holding.pbgrpc.dart`

**Interfaces:**
- Produces: proto `SyncPrices(SyncPricesRequest) returns (SyncPricesResponse)`;Go `HoldingServiceServer.SyncPrices(ctx, *SyncPricesRequest)(*SyncPricesResponse, error)`;Dart `HoldingServiceClient.syncPrices(req)`。后续 Task 6(handler)、Task 9(Flutter ds)依赖

**背景**:provider 在 server 端,client 手动刷新需要一个 RPC 触发 server 批量 sync。这是非 TDD 的 setup task(proto 是契约,不是行为单测)。

- [ ] **Step 1: 改 holding.proto(service 块加 RPC)**

在 `yucai/proto/holding/v1/holding.proto` 的 service 块(`ListHoldingTransactions` 那行之后,`}` 之前)加:

```proto
  rpc SyncPrices(SyncPricesRequest) returns (SyncPricesResponse);
```

即 service 块变成:
```proto
service HoldingService {
  rpc CreateSecurity(CreateSecurityRequest) returns (SecurityResponse);
  rpc ListSecurities(ListSecuritiesRequest) returns (ListSecuritiesResponse);
  rpc UpdateSecurityPrice(UpdatePriceRequest) returns (google.protobuf.Empty);
  rpc SearchSecurities(SearchSecuritiesRequest) returns (SearchSecuritiesResponse);
  rpc BuyHolding(HoldingTradeRequest) returns (HoldingTransactionResponse);
  rpc SellHolding(HoldingTradeRequest) returns (HoldingTransactionResponse);
  rpc RecordDividend(RecordDividendRequest) returns (HoldingTransactionResponse);
  rpc RecordSplit(RecordSplitRequest) returns (HoldingTransactionResponse);
  rpc ListHoldings(ListHoldingsRequest) returns (ListHoldingsResponse);
  rpc ListHoldingTransactions(ListTradesRequest) returns (ListTradesResponse);
  rpc SyncPrices(SyncPricesRequest) returns (SyncPricesResponse);
}
```

- [ ] **Step 2: 文件末尾加 message(在 `ListTradesResponse` 那行之后)**

```proto
message SyncPricesRequest {}

message SyncPricesResponse {
  int32 synced_count = 1;
  google.protobuf.Timestamp synced_at = 2;
}
```

- [ ] **Step 3: 重生成 Go stub**

```bash
cd /e/projects/syfinance/yucai && make proto
```
Expected: `buf generate` 成功;`yucai/server/internal/proto/holding/v1/holding.pb.go` 出现 `SyncPricesRequest`/`SyncPricesResponse` 类型;`holding_grpc.pb.go` 的 `HoldingServiceServer` 接口加 `SyncPrices(context.Context, *SyncPricesRequest) (*SyncPricesResponse, error)`。

- [ ] **Step 4: 重生成 Dart stub(需 protoc_plugin 25.0.0)**

```bash
dart pub global activate protoc_plugin 25.0.0
cd /e/projects/syfinance/yucai && make gen-dart
```
Expected: `yucai/client/lib/proto/holding/v1/holding.pb.dart` 出现 `SyncPricesRequest`/`SyncPricesResponse`;`holding.pbgrpc.dart` 的 `HoldingServiceClient` 加 `syncPrices` 方法。

- [ ] **Step 5: 验证 Go server 仍编译(handler 还没实现 SyncPrices,会因 interface 未满足报错 —— 预期内,Task 6 修复)**

```bash
cd /e/projects/syfinance/yucai/server && go build ./...
```
Expected: **FAIL** —— `HoldingHandler` 未实现 `SyncPrices`(因为 HoldingServiceServer 接口刚加了新方法)。错误类似 `cannot use holdingHandler (type *HoldingHandler) as type HoldingServiceServer: missing method SyncPrices`。**这是预期的**(TDD red:proto 契约已定,实现待 Task 2-7)。记下错误,Task 6 会让它转绿。

- [ ] **Step 6: Commit proto + 重生成产物**

```bash
cd /e/projects/syfinance
git add yucai/proto/holding/v1/holding.proto yucai/server/internal/proto/holding/v1/ yucai/client/lib/proto/holding/v1/
git commit -m "feat(holding-b-proto): 加 SyncPrices RPC + 重生成 Go/Dart stub

server 批量价格同步触发端点。request 空(刷全部 security),
response synced_count + synced_at。schema 零改动。"
```

---

## Task 2: priceprovider 接口 + StubProvider + CompositeRouter + 单测

**Files:**
- Create: `yucai/server/internal/holding/adapter/driven/priceprovider/provider.go`
- Create: `yucai/server/internal/holding/adapter/driven/priceprovider/stub.go`
- Create: `yucai/server/internal/holding/adapter/driven/priceprovider/router.go`
- Test: `yucai/server/internal/holding/adapter/driven/priceprovider/provider_test.go`

**Interfaces:**
- Produces:
  - `priceprovider.PriceView{Symbol, Exchange string; Type domain.SecurityType}`
  - `priceprovider.Provider` 接口 `FetchPrice(ctx, PriceView) (priceCents int64, source string, err error)`
  - `priceprovider.ErrNoSource` sentinel(`errors.New("price: no source for security")`)
  - `priceprovider.StubProvider`(NewStubProvider(),所有返回 ErrNoSource)
  - `priceprovider.Router` 接口(同 FetchPrice 签名)
  - `priceprovider.CompositeRouter`(NewCompositeRouter(ps ...Provider),顺序路由:ErrNoSource 跳下一个,真错误透传,全无源返回 ErrNoSource)
- Task 3 的 SinaProvider、Task 4 的 service 依赖

**背景**:对齐 `currency/exchangerate/provider.go`(Provider 接口)+ mock_provider.go(兜底)。首批 stub = 显式"无源",不动旧价。

- [ ] **Step 1: 写 provider.go(接口 + PriceView + ErrNoSource)**

`yucai/server/internal/holding/adapter/driven/priceprovider/provider.go`:
```go
// Package priceprovider is the port for security price data sources
// (aligned with currency/adapter/driven/exchangerate). Providers live on
// the server so scheduling, symbol mapping and any future API keys stay
// centralized; the client triggers sync via the SyncPrices RPC.
package priceprovider

import (
	"context"
	"errors"

	"github.com/yucai/server/internal/holding/domain"
)

// ErrNoSource signals that a provider does not cover the given security.
// Routers use it to fall through to the next provider; the service treats
// it as "skip, keep old price" (not a failure).
var ErrNoSource = errors.New("price: no source for security")

// PriceView is the minimal, safe view of a security that a provider needs
// to fetch a price. It does not leak the full Security aggregate.
type PriceView struct {
	Symbol   string
	Exchange string
	Type     domain.SecurityType
}

// Provider is the port interface for price data sources.
type Provider interface {
	// FetchPrice returns the latest price in cents plus a source label.
	// ErrNoSource means this provider does not cover the security.
	FetchPrice(ctx context.Context, v PriceView) (priceCents int64, source string, err error)
}

// Router routes a security to the first covering provider. Implemented by
// CompositeRouter; defined separately so the application service depends on
// the abstraction, not the concrete composite.
type Router interface {
	FetchPrice(ctx context.Context, v PriceView) (priceCents int64, source string, err error)
}
```

- [ ] **Step 2: 写 stub.go**

`yucai/server/internal/holding/adapter/driven/priceprovider/stub.go`:
```go
package priceprovider

import "context"

// StubProvider is the terminal fallback: it covers nothing and returns
// ErrNoSource for every security. Non A-share types (US stock, OTC fund,
// SGE gold, option) land here in the first batch, meaning "no auto source"
// — their price stays at the manually-entered value (we never fabricate).
// Replace by appending a real provider before it in the router.
type StubProvider struct{}

// NewStubProvider builds a StubProvider.
func NewStubProvider() *StubProvider { return &StubProvider{} }

// FetchPrice always returns ErrNoSource.
func (p *StubProvider) FetchPrice(_ context.Context, _ PriceView) (int64, string, error) {
	return 0, "", ErrNoSource
}
```

- [ ] **Step 3: 写 router.go**

`yucai/server/internal/holding/adapter/driven/priceprovider/router.go`:
```go
package priceprovider

import (
	"context"
	"errors"
)

// CompositeRouter routes FetchPrice to the first provider that covers the
// security. ErrNoSource from a provider means "try the next"; any other
// error is a real failure and is propagated immediately (the service logs
// it and counts it as failed, but does not abort the batch). If every
// provider returns ErrNoSource, the router returns ErrNoSource.
type CompositeRouter struct {
	providers []Provider
}

// NewCompositeRouter builds a CompositeRouter from an ordered provider list.
// Order matters: put specific providers (e.g. SinaProvider) before the
// StubProvider fallback.
func NewCompositeRouter(providers ...Provider) *CompositeRouter {
	return &CompositeRouter{providers: providers}
}

func (r *CompositeRouter) FetchPrice(ctx context.Context, v PriceView) (int64, string, error) {
	for _, p := range r.providers {
		price, source, err := p.FetchPrice(ctx, v)
		if err == nil {
			return price, source, nil
		}
		if !errors.Is(err, ErrNoSource) {
			return 0, "", err
		}
	}
	return 0, "", ErrNoSource
}
```

- [ ] **Step 4: 写失败测试 provider_test.go**

`yucai/server/internal/holding/adapter/driven/priceprovider/provider_test.go`:
```go
package priceprovider

import (
	"context"
	"errors"
	"testing"

	"github.com/yucai/server/internal/holding/domain"
)

// stubProbe is a test provider that returns a configured result, letting us
// drive the router through all three branches (ok / real-error / no-source).
type stubProbe struct {
	price  int64
	source string
	err    error
}

func (p *stubProbe) FetchPrice(_ context.Context, _ PriceView) (int64, string, error) {
	return p.price, p.source, p.err
}

func TestStubProviderAlwaysNoSource(t *testing.T) {
	p := NewStubProvider()
	_, _, err := p.FetchPrice(context.Background(), PriceView{Symbol: "600519", Exchange: "SSE"})
	if !errors.Is(err, ErrNoSource) {
		t.Fatalf("StubProvider must return ErrNoSource; got %v", err)
	}
}

func TestRouterReturnsFirstCovering(t *testing.T) {
	// First provider no-source, second covers → second wins.
	r := NewCompositeRouter(
		NewStubProvider(),
		&stubProbe{price: 168000, source: "test"},
	)
	price, src, err := r.FetchPrice(context.Background(), PriceView{Symbol: "600519", Exchange: "SSE"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if price != 168000 || src != "test" {
		t.Fatalf("got price=%d src=%q, want 168000/test", price, src)
	}
}

func TestRouterFallsThroughNoSource(t *testing.T) {
	// All no-source → router returns ErrNoSource.
	r := NewCompositeRouter(NewStubProvider(), NewStubProvider())
	_, _, err := r.FetchPrice(context.Background(), PriceView{Symbol: "AAPL", Exchange: "NASDAQ"})
	if !errors.Is(err, ErrNoSource) {
		t.Fatalf("all-no-source router must return ErrNoSource; got %v", err)
	}
}

func TestRouterPropagatesRealError(t *testing.T) {
	// A real (non ErrNoSource) error is propagated, not swallowed.
	wantErr := errors.New("upstream timeout")
	r := NewCompositeRouter(&stubProbe{err: wantErr})
	_, _, err := r.FetchPrice(context.Background(), PriceView{Type: domain.SecurityTypeStock})
	if !errors.Is(err, wantErr) {
		t.Fatalf("router must propagate real error; got %v want %v", err, wantErr)
	}
}

func TestRouterRealErrorStopsSearch(t *testing.T) {
	// If an earlier provider returns a real error, later providers are not tried.
	called := false
	later := &recordingProbe{onCall: func() { called = true }, err: nil, price: 1}
	r := NewCompositeRouter(&stubProbe{err: errors.New("boom")}, later)
	_, _, _ = r.FetchPrice(context.Background(), PriceView{})
	if called {
		t.Fatal("router must not try later provider after a real error")
	}
}

// recordingProbe records whether FetchPrice was called.
type recordingProbe struct {
	onCall func()
	price  int64
	err    error
}

func (p *recordingProbe) FetchPrice(_ context.Context, _ PriceView) (int64, string, error) {
	if p.onCall != nil {
		p.onCall()
	}
	return p.price, "rec", p.err
}
```

- [ ] **Step 5: 跑测试验证 fail→pass**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/adapter/driven/priceprovider/ -v -count=1
```
Expected: PASS(5 个测试全过)。如果先只写测试再写实现会 FAIL(类型未定义);此处实现已先写,直接 PASS。

- [ ] **Step 6: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/internal/holding/adapter/driven/priceprovider/
git commit -m "feat(holding-b-server): priceprovider 接口+StubProvider+CompositeRouter

对齐 currency/exchangerate 模式。Router 顺序路由:ErrNoSource 跳下一个,
真错误透传。Stub = 显式无源兜底(首批非 A 股不动旧价)。5 单测。"
```

---

## Task 3: SinaProvider(新浪 A 股,GBK)+ 单测

**Files:**
- Create: `yucai/server/internal/holding/adapter/driven/priceprovider/sina.go`
- Test: `yucai/server/internal/holding/adapter/driven/priceprovider/sina_test.go`

**Interfaces:**
- Consumes: `priceprovider.Provider`、`PriceView`、`ErrNoSource`(Task 2)
- Produces: `priceprovider.SinaProvider`(`NewSinaProvider() *SinaProvider`),覆盖 `Exchange ∈ {SSE, SZSE}`,fetch `http://hq.sinajs.cn/list={sh|sz}{symbol}`,GBK 解码,索引 2 转 cents

**背景**:对齐 `currency/exchangerate/frankfurter.go`(HTTP provider 模板)。新浪接口需 Referer header + GBK 解码。

- [ ] **Step 1: 写失败测试 sina_test.go**

`yucai/server/internal/holding/adapter/driven/priceprovider/sina_test.go`:
```go
package priceprovider

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/yucai/server/internal/holding/domain"
)

// gbkCurrentQuote builds a fake sinajs response (GBK-encoded) with the given
// current price at field index 2. Fields: name,open(0),prevClose(1),current(2).
func gbkCurrentQuote(name string, current float64) []byte {
	// ASCII-safe construction: name is the only non-ASCII part. For tests we
	// use an ASCII name so the payload is valid UTF-8 *and* identical when
	// GBK-decoded (ASCII maps 1:1 in GBK). This keeps the test deterministic
	// without a GBK encoder dependency.
	body := "var hq_str_sh600519=\"" + name + "\",35.00,34.50," + formatFloat(current) + ",36.00,34.00,34.80,34.90,12345,600000,34.80,123,34.90,456,2024-01-02,15:00:00,00;"
	return []byte(body)
}

func formatFloat(f float64) string {
	// strconv.FormatFloat with minimal precision; kept inline-free to avoid
	// an extra import shuffle in the plan reader's head.
	if f == float64(int64(f)) {
		return strconvItoa(int64(f)) + ".00"
	}
	return strconvF(f)
}

// strconvItoa / strconvF are thin wrappers added below to keep imports tidy.
func strconvItoa(n int64) string {
	// use strconv.FormatInt via a helper to centralize import
	return strconvFormatInt(n)
}
func strconvF(f float64) string { return strconvFormatFloat(f) }

func TestSinaNotCoveredExchange(t *testing.T) {
	p := NewSinaProvider()
	for _, ex := range []string{"NASDAQ", "OTC", "SGE", ""} {
		_, _, err := p.FetchPrice(context.Background(), PriceView{Symbol: "X", Exchange: ex})
		if !errors.Is(err, ErrNoSource) {
			t.Fatalf("exchange %q must be ErrNoSource; got %v", ex, err)
		}
	}
}

func TestSinaCoversSSEAndSZSE(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if got := r.Header.Get("Referer"); got != "https://finance.sina.com.cn" {
			t.Errorf("missing/wrong Referer: %q", got)
		}
		_, _ = w.Write(gbkCurrentQuote("TEST", 34.80))
	}))
	defer srv.Close()

	p := newSinaProviderWithURL(srv.URL)
	for _, ex := range []string{"SSE", "SZSE"} {
		price, src, err := p.FetchPrice(context.Background(), PriceView{Symbol: "600519", Exchange: ex})
		if err != nil {
			t.Fatalf("exchange %s: unexpected error: %v", ex, err)
		}
		if price != 3480 {
			t.Fatalf("exchange %s: got price %d cents, want 3480 (34.80*100)", ex, price)
		}
		if src != "sina" {
			t.Fatalf("source = %q, want sina", src)
		}
	}
}

func TestSinaHttpErrorPropagated(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer srv.Close()
	p := newSinaProviderWithURL(srv.URL)
	_, _, err := p.FetchPrice(context.Background(), PriceView{Symbol: "600519", Exchange: "SSE"})
	if err == nil || errors.Is(err, ErrNoSource) {
		t.Fatalf("HTTP 500 must be a real error, not nil/ErrNoSource; got %v", err)
	}
}

func TestSinaEmptyQuoteIsError(t *testing.T) {
	// Symbol that does not exist → sinajs returns an empty quote string.
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("var hq_str_sh000000=\"\";"))
	}))
	defer srv.Close()
	p := newSinaProviderWithURL(srv.URL)
	_, _, err := p.FetchPrice(context.Background(), PriceView{Symbol: "000000", Exchange: "SSE"})
	if err == nil || errors.Is(err, ErrNoSource) {
		t.Fatalf("empty quote must be a real error; got %v", err)
	}
}
```

> 注:`formatFloat`/`strconvItoa`/`strconvF`/`strconvFormatInt`/`strconvFormatFloat` 这些 helper 在测试里只是为了构造 body 时格式化价格。**实现 Step 3 时**改用更简洁的写法 —— 实际测试文件直接用 `strconv.FormatFloat(current, 'f', 2, 64)` 构造,删除这些 wrapper。下面 Step 3 给出最终干净的测试文件(替换 Step 1)。

- [ ] **Step 2: 跑测试验证 FAIL**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/adapter/driven/priceprovider/ -run Sina -v -count=1
```
Expected: FAIL / 编译错误(`NewSinaProvider` / `newSinaProviderWithURL` 未定义)。

- [ ] **Step 3: 用干净版本替换测试文件(去 helper wrapper)+ 写实现**

替换 `sina_test.go` 全文为(用 `strconv` 直接构造):
```go
package priceprovider

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"
)

func TestSinaNotCoveredExchange(t *testing.T) {
	p := NewSinaProvider()
	for _, ex := range []string{"NASDAQ", "OTC", "SGE", ""} {
		_, _, err := p.FetchPrice(context.Background(), PriceView{Symbol: "X", Exchange: ex})
		if !errors.Is(err, ErrNoSource) {
			t.Fatalf("exchange %q must be ErrNoSource; got %v", ex, err)
		}
	}
}

// gbkQuote builds a fake sinajs response. Fields after the name:
// open(0), prevClose(1), current(2), high(3), low(4)... — we set current(2).
// ASCII name keeps the payload valid UTF-8 (ASCII is a 1:1 subset of GBK),
// so the GBK decoder yields the same bytes and the test is deterministic.
func gbkQuote(current float64) []byte {
	return []byte("var hq_str_sh600519=\"TEST\",35.00,34.50," +
		strconv.FormatFloat(current, 'f', 2, 64) + ",36.00,34.00,0,0,0,0,0,0,0,0,2024-01-02,15:00:00,00;")
}

func TestSinaCoversSSEAndSZSE(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if got := r.Header.Get("Referer"); got != "https://finance.sina.com.cn" {
			t.Errorf("missing/wrong Referer: %q", got)
		}
		_, _ = w.Write(gbkQuote(34.80))
	}))
	defer srv.Close()

	p := newSinaProviderWithURL(srv.URL)
	for _, ex := range []string{"SSE", "SZSE"} {
		price, src, err := p.FetchPrice(context.Background(), PriceView{Symbol: "600519", Exchange: ex})
		if err != nil {
			t.Fatalf("exchange %s: unexpected error: %v", ex, err)
		}
		if price != 3480 {
			t.Fatalf("exchange %s: got %d cents, want 3480", ex, price)
		}
		if src != "sina" {
			t.Fatalf("source = %q, want sina", src)
		}
	}
}

func TestSinaHttpErrorPropagated(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer srv.Close()
	p := newSinaProviderWithURL(srv.URL)
	_, _, err := p.FetchPrice(context.Background(), PriceView{Symbol: "600519", Exchange: "SSE"})
	if err == nil || errors.Is(err, ErrNoSource) {
		t.Fatalf("HTTP 500 must be a real error; got %v", err)
	}
}

func TestSinaEmptyQuoteIsError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("var hq_str_sh000000=\"\";"))
	}))
	defer srv.Close()
	p := newSinaProviderWithURL(srv.URL)
	_, _, err := p.FetchPrice(context.Background(), PriceView{Symbol: "000000", Exchange: "SSE"})
	if err == nil || errors.Is(err, ErrNoSource) {
		t.Fatalf("empty quote must be a real error; got %v", err)
	}
}
```

写实现 `sina.go`:
```go
package priceprovider

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"golang.org/x/text/encoding/simplifiedchinese"
)

// SinaProvider fetches A-share prices from Sina Finance (hq.sinajs.cn).
// Covers Exchange == "SSE" (Shanghai, prefix sh) or "SZSE" (Shenzhen, sz).
// All other exchanges return ErrNoSource so the router falls through.
//
// The endpoint returns GBK-encoded text:
//   var hq_str_sh600519="贵州茅台",今开,昨收,当前价(2),最高,最低,...
// It requires a Referer header or returns 403. Current price is field index 2.
type SinaProvider struct {
	baseURL string
	client  *http.Client
}

// NewSinaProvider builds a SinaProvider pointing at the public endpoint.
func NewSinaProvider() *SinaProvider {
	return &SinaProvider{
		baseURL: "http://hq.sinajs.cn",
		client:  &http.Client{Timeout: 10 * time.Second},
	}
}

// newSinaProviderWithURL is the test seam: point at a httptest server.
func newSinaProviderWithURL(baseURL string) *SinaProvider {
	return &SinaProvider{baseURL: baseURL, client: &http.Client{Timeout: 5 * time.Second}}
}

func (p *SinaProvider) FetchPrice(ctx context.Context, v PriceView) (int64, string, error) {
	listKey, ok := sinaListKey(v.Exchange, v.Symbol)
	if !ok {
		return 0, "", ErrNoSource
	}
	url := p.baseURL + "/list=" + listKey
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return 0, "", fmt.Errorf("sina build request: %w", err)
	}
	// Sina rejects requests without this Referer (HTTP 403).
	req.Header.Set("Referer", "https://finance.sina.com.cn")

	resp, err := p.client.Do(req)
	if err != nil {
		return 0, "", fmt.Errorf("sina request: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 0, "", fmt.Errorf("sina status %d", resp.StatusCode)
	}

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return 0, "", fmt.Errorf("sina read body: %w", err)
	}
	// Decode GBK → UTF-8. ASCII bytes map 1:1, so mixed/ASCII payloads survive.
	utf8, err := simplifiedchinese.GBK.NewDecoder().Bytes(raw)
	if err != nil {
		return 0, "", fmt.Errorf("sina gbk decode: %w", err)
	}
	price, err := parseSinaCurrentPrice(string(utf8))
	if err != nil {
		return 0, "", fmt.Errorf("sina parse: %w", err)
	}
	return int64(price * 100), "sina", nil
}

// sinaListKey maps exchange + symbol to the sinajs list key (sh/sz prefix).
// Returns ok=false for exchanges Sina does not cover.
func sinaListKey(exchange, symbol string) (string, bool) {
	switch strings.ToUpper(strings.TrimSpace(exchange)) {
	case "SSE":
		return "sh" + symbol, true
	case "SZSE":
		return "sz" + symbol, true
	default:
		return "", false
	}
}

// parseSinaCurrentPrice extracts the current price (field index 2) from a
// sinajs response line of the form:
//   var hq_str_<key>="<name>",f0,f1,f2,...
// An empty quote ("") means the symbol does not exist → error.
func parseSinaCurrentPrice(line string) (float64, error) {
	eq := strings.Index(line, "\"")
	if eq < 0 {
		return 0, fmt.Errorf("no opening quote in response")
	}
	rest := line[eq+1:]
	end := strings.Index(rest, "\"")
	if end < 0 {
		return 0, fmt.Errorf("no closing quote in response")
	}
	inner := rest[:end] // "<name>",f0,f1,f2,...
	if strings.TrimSpace(inner) == "" || strings.HasPrefix(strings.TrimSpace(inner), ",") {
		// Empty quote or name-less → symbol not found.
		return 0, fmt.Errorf("empty quote, symbol not found")
	}
	// Drop the leading "<name>," — the name is everything up to the first comma.
	comma := strings.Index(inner, ",")
	if comma < 0 {
		return 0, fmt.Errorf("no fields in quote")
	}
	fields := strings.Split(inner[comma+1:], ",")
	if len(fields) < 3 {
		return 0, fmt.Errorf("not enough fields: %d", len(fields))
	}
	price, err := strconv.ParseFloat(strings.TrimSpace(fields[2]), 64)
	if err != nil {
		return 0, fmt.Errorf("parse current price %q: %w", fields[2], err)
	}
	return price, nil
}
```

- [ ] **Step 4: 确保 golang.org/x/text 为 direct 依赖**

```bash
cd /e/projects/syfinance/yucai/server && go mod tidy
```
Expected: `go.mod` 的 `golang.org/x/text` 从 `// indirect` 转为 direct(go.sum 不变)。`git diff go.mod` 应只见该行注释去掉。

- [ ] **Step 5: 跑测试验证 PASS**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/adapter/driven/priceprovider/ -v -count=1
```
Expected: PASS(Task 2 的 5 个 + Task 3 的 4 个 = 9 个测试全过)。

- [ ] **Step 6: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/internal/holding/adapter/driven/priceprovider/sina.go yucai/server/internal/holding/adapter/driven/priceprovider/sina_test.go yucai/server/go.mod yucai/server/go.sum
git commit -m "feat(holding-b-server): SinaProvider(新浪A股,GBK 解码,索引2 当前价)

覆盖 SSE(sh)/SZSE(sz),带 Referer header,GBK→UTF-8 解码,字段索引2=当前价,
转 cents。httptest 4 单测(覆盖判定/正常/HTTP错误/空响应)。"
```

---

## Task 4: application.Service.SyncPrices + SetPriceRouter + 单测

**Files:**
- Modify: `yucai/server/internal/holding/application/service.go`(加 priceRouter 字段 + SetPriceRouter + SyncPrices)
- Test: `yucai/server/internal/holding/application/service_test.go`(新建或追加 SyncPrices 测试)

**Interfaces:**
- Consumes: `priceprovider.Router`(Task 2)、`domain.SecurityRepository.FindAll`(现有)、`Service.UpdateSecurityPrice`(现有 line 51)
- Produces:
  - `application.Service` 加 `priceRouter priceprovider.Router` 字段 + `SetPriceRouter(r priceprovider.Router)`
  - `SyncPrices(ctx context.Context) (int, error)` — 返回 synced count;实现 scheduler 的 `PriceSyncer` 接口
- Task 5(scheduler)、Task 6(handler)、Task 7(wire)依赖

**背景**:service 持有 securityRepo,遍历全部 security → router.FetchPrice → UpdateSecurityPrice。`NewService` 签名不变(现有 tests 不破坏),用 setter 注入 router。`ErrNoSource` 跳过(无源),真错误日志 + 计 0(不中断)。

- [ ] **Step 1: 写失败测试 service_test.go(SyncPrices 部分)**

新建 `yucai/server/internal/holding/application/service_test.go`(若已存在则追加;先检查):

先确认是否已存在:
```bash
ls /e/projects/syfinance/yucai/server/internal/holding/application/service_test.go 2>/dev/null && echo EXISTS || echo NEW
```

新建/追加测试文件 `service_test.go`,加入:
```go
package application

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/holding/domain"
	"github.com/yucai/server/internal/holding/adapter/driven/priceprovider"
)

// fakePriceRouter is a test double for priceprovider.Router.
type fakePriceRouter struct {
	// prices maps symbol → price in cents to return.
	prices map[string]int64
	// errOn maps symbol → error to return (real error, not ErrNoSource).
	errOn map[string]error
	// noSource is a set of symbols that return ErrNoSource.
	noSource map[string]bool
}

func (r *fakePriceRouter) FetchPrice(_ context.Context, v priceprovider.PriceView) (int64, string, error) {
	if r.errOn != nil {
		if e, ok := r.errOn[v.Symbol]; ok {
			return 0, "", e
		}
	}
	if r.noSource[v.Symbol] {
		return 0, "", priceprovider.ErrNoSource
	}
	if p, ok := r.prices[v.Symbol]; ok {
		return p, "fake", nil
	}
	return 0, "", priceprovider.ErrNoSource
}

func TestSyncPricesUpdatesCoveredAndSkipsNoSource(t *testing.T) {
	repo, svcs := newTestServiceWithSecurities(t, []seedSec{
		{Symbol: "600519", Exchange: "SSE", StartPriceCents: 100},
		{Symbol: "AAPL", Exchange: "NASDAQ", StartPriceCents: 200},
	})
	svcs.SetPriceRouter(&fakePriceRouter{
		prices:    map[string]int64{"600519": 3480},
		noSource:  map[string]bool{"AAPL": true},
	})

	count, err := svcs.SyncPrices(context.Background())
	if err != nil {
		t.Fatalf("SyncPrices error: %v", err)
	}
	if count != 1 {
		t.Fatalf("synced count = %d, want 1 (only SSE covered)", count)
	}
	got := repo.priceFor("600519")
	if got != 3480 {
		t.Fatalf("600519 price = %d, want 3480", got)
	}
	// AAPL is no-source → price untouched.
	if aapl := repo.priceFor("AAPL"); aapl != 200 {
		t.Fatalf("AAPL no-source price should stay 200, got %d", aapl)
	}
}

func TestSyncPricesContinuesPastRealError(t *testing.T) {
	repo, svcs := newTestServiceWithSecurities(t, []seedSec{
		{Symbol: "600519", Exchange: "SSE", StartPriceCents: 100},
		{Symbol: "510300", Exchange: "SSE", StartPriceCents: 100},
	})
	svcs.SetPriceRouter(&fakePriceRouter{
		prices: map[string]int64{"600519": 3480, "510300": 4250},
		errOn:  map[string]error{"600519": errors.New("upstream 500")},
	})

	count, err := svcs.SyncPrices(context.Background())
	if err != nil {
		t.Fatalf("SyncPrices should not abort on per-security error: %v", err)
	}
	if count != 1 {
		t.Fatalf("synced = %d, want 1 (510300 ok, 600519 errored)", count)
	}
	// 600519 errored → price untouched at 100.
	if got := repo.priceFor("600519"); got != 100 {
		t.Fatalf("600519 should stay 100 after error, got %d", got)
	}
	if got := repo.priceFor("510300"); got != 4250 {
		t.Fatalf("510300 should be updated to 4250, got %d", got)
	}
}

func TestSyncPricesWithoutRouterErrors(t *testing.T) {
	// Defensive: if SetPriceRouter was never called, SyncPrices errors clearly
	// (rather than nil-dereferencing). Wire always injects; this guards tests.
	_, svcs := newTestServiceWithSecurities(t, nil)
	if _, err := svcs.SyncPrices(context.Background()); err == nil {
		t.Fatal("SyncPrices without router must error")
	}
}
```

测试引用的 `newTestServiceWithSecurities` helper + `seedSec` + 一个能记录价格的 fake repo。在同一文件顶部加入(test-only fakes):
```go
// seedSec describes a security to seed into the fake repo for a test.
type seedSec struct {
	Symbol           string
	Exchange         string
	StartPriceCents  int64
	Type             domain.SecurityType
}

// fakeSecurityRepo is an in-memory SecurityRepository for SyncPrices tests.
type fakeSecurityRepo struct {
	prices map[string]int64   // symbol → price cents
	ids    map[string]uuid.UUID
}

func newFakeSecurityRepo(seeds []seedSec) *fakeSecurityRepo {
	r := &fakeSecurityRepo{prices: map[string]int64{}, ids: map[string]uuid.UUID{}}
	for _, s := range seeds {
		r.prices[s.Symbol] = s.StartPriceCents
		r.ids[s.Symbol] = uuid.New()
	}
	return r
}
func (r *fakeSecurityRepo) priceFor(symbol string) int64 { return r.prices[symbol] }
```

> ⚠️ `fakeSecurityRepo` 必须实现 `domain.SecurityRepository` 接口。**Step 2 前先查接口签名**:运行 `grep -n "type SecurityRepository" /e/projects/syfinance/yucai/server/internal/holding/domain/*.go` 找到接口定义,然后给 fakeSecurityRepo 实现其**所有**方法(FindAll / FindByID / FindBySymbol / Save / UpdatePrice / Search 等)。FindAll 返回 seeds 对应的 `domain.Security` 列表(字段:ID/Symbol/Name/SecurityType/Exchange/CurrencyCode/CurrentPriceCents);UpdatePrice 更新 `r.prices[symbol]`。其余方法可 panic("not used in test") 或返回零值,只要 SyncPrices 路径覆盖的方法真实工作。在 Step 2 把完整 fake 实现补齐。

- [ ] **Step 2: 查 SecurityRepository 接口 + 补全 fakeSecurityRepo 实现**

```bash
grep -rn "type SecurityRepository interface" /e/projects/syfinance/yucai/server/internal/holding/domain/
# 找到文件后,Read 它的 SecurityRepository 接口块,把每个方法在 fakeSecurityRepo 上实现
```

把 `newTestServiceWithSecurities` helper 也补全(用 fakeSecurityRepo 构造 Service):
```go
func newTestServiceWithSecurities(t *testing.T, seeds []seedSec) (*fakeSecurityRepo, *Service) {
	t.Helper()
	repo := newFakeSecurityRepo(seeds)
	// holdingRepo / tradeRepo can be nil-ish fakes; SyncPrices doesn't touch them.
	// Use minimal fakes implementing the interfaces (panic on unused methods).
	svc := NewService(repo, nilHoldingRepo(), nilTradeRepo())
	return repo, svc
}
```
(`nilHoldingRepo` / `nilTradeRepo` 返回实现接口但方法 panic 的最小 fake。查 `domain.HoldingRepository` / `domain.TradeRepository` 接口补全。)

- [ ] **Step 3: 跑测试验证 FAIL**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/application/ -run SyncPrices -v -count=1
```
Expected: FAIL / 编译错误(`SetPriceRouter` / `SyncPrices` 未定义)。

- [ ] **Step 4: 实现 — 改 service.go**

在 `service.go` 顶部 import 块加 `"errors"` 和 `priceprovider` import:
```go
import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/holding/adapter/driven/priceprovider"
	"github.com/yucai/server/internal/holding/domain"
)
```
(只加 `errors`、`slog`、`priceprovider` 三行,保留原有 import。`time` 已有。)

改 `Service` struct(line 13-17)加 priceRouter 字段:
```go
type Service struct {
	securityRepo domain.SecurityRepository
	holdingRepo  domain.HoldingRepository
	tradeRepo    domain.TradeRepository
	priceRouter  priceprovider.Router // injected via SetPriceRouter (wire); nil = SyncPrices errors
}
```
`NewService` 不变。

在 service.go 末尾(`SeedSampleHoldings` 之后)加:
```go
// SetPriceRouter injects the price router used by SyncPrices. Called by wire
// after construction (NewService signature stays unchanged so existing tests
// and callers are not broken).
func (s *Service) SetPriceRouter(r priceprovider.Router) {
	s.priceRouter = r
}

// SyncPrices refreshes current_price_cents for every security via the price
// router, best-effort: ErrNoSource skips the security (keeps old price, not a
// failure); any other error is logged and the security is skipped without
// aborting the batch. Returns the count of successfully updated securities.
// Implements holding/scheduler.PriceSyncer.
func (s *Service) SyncPrices(ctx context.Context) (int, error) {
	if s.priceRouter == nil {
		return 0, fmt.Errorf("sync prices: price router not configured")
	}
	synced := 0
	page := domain.PageRequest{PageSize: 100}
	for {
		result, err := s.securityRepo.FindAll(ctx, nil, page)
		if err != nil {
			return synced, fmt.Errorf("sync prices: list securities: %w", err)
		}
		for _, sec := range result.Items {
			if err := ctx.Err(); err != nil {
				return synced, err
			}
			view := priceprovider.PriceView{Symbol: sec.Symbol, Exchange: sec.Exchange, Type: sec.SecurityType}
			price, _, err := s.priceRouter.FetchPrice(ctx, view)
			if err != nil {
				if errors.Is(err, priceprovider.ErrNoSource) {
					continue // not covered (e.g. US stock) — keep old price
				}
				slog.Warn("holding price sync: fetch failed, keep old price",
					"symbol", sec.Symbol, "exchange", sec.Exchange, "error", err, "operation", "SyncPrices")
				continue
			}
			if err := s.securityRepo.UpdatePrice(ctx, sec.ID, price); err != nil {
				slog.Warn("holding price sync: update failed",
					"symbol", sec.Symbol, "error", err, "operation", "SyncPrices")
				continue
			}
			synced++
		}
		if result.NextPageToken == "" || len(result.Items) == 0 {
			break
		}
		page.PageToken = result.NextPageToken
	}
	return synced, nil
}
```

> 注:`result.Items` 元素类型是 `domain.Security`,字段名以实际 domain 定义为准 —— 实现前 `grep -n "type Security struct" /e/projects/syfinance/yucai/server/internal/holding/domain/*.go` 确认 `Symbol`/`Exchange`/`SecurityType`/`ID` 字段名(SecurityDTO 用 Symbol/Exchange/SecurityType,domain.Security 应一致;ID 是 uuid.UUID)。`securityRepo.FindAll` 返回值结构(SecurityResult 或类似)在 Step 2 已查。

- [ ] **Step 5: 跑测试验证 PASS**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/application/ -run SyncPrices -v -count=1
```
Expected: PASS(3 个 SyncPrices 测试)。

- [ ] **Step 6: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/internal/holding/application/
git commit -m "feat(holding-b-server): application.Service.SyncPrices + SetPriceRouter

遍历 securities 经 router 取价 → UpdateSecurityPrice。best-effort:
ErrNoSource 跳过(非 A 股不动旧价),真错误日志不中断。NewService 签名
不变(setter 注入,现有 tests 不破坏)。3 单测。"
```

---

## Task 5: holding scheduler(PriceScheduler)+ 单测

**Files:**
- Create: `yucai/server/internal/holding/scheduler/scheduler.go`
- Test: `yucai/server/internal/holding/scheduler/scheduler_test.go`

**Interfaces:**
- Consumes: `IntervalSource` 接口(`MinIntervalHours(ctx) int`,由 auth TenantRepository 实现,wire 复用同一 provider)
- Produces:
  - `scheduler.PriceSyncer` 接口 `SyncPrices(ctx) (int, error)`(由 application.Service 实现)
  - `scheduler.Scheduler` + `NewScheduler(syncer PriceSyncer, src IntervalSource, tick time.Duration, log *slog.Logger)` + `Start(ctx)` + `SyncNow(ctx)(int, error)`
- Task 7(wire)依赖

**背景**:逐行对齐 `currency/scheduler/scheduler.go`(已读过全文),仅把 RateSyncer→PriceSyncer、SyncRates→SyncPrices、日志文案改 price。

- [ ] **Step 1: 写 scheduler.go**

`yucai/server/internal/holding/scheduler/scheduler.go`:
```go
// Package scheduler runs periodic security-price sync as a background task.
// Mirrors currency/scheduler: time.NewTicker + context.WithCancel + go func,
// gated by IntervalSource so the tick only fires when MinIntervalHours elapsed.
package scheduler

import (
	"context"
	"log/slog"
	"sync"
	"time"
)

// IntervalSource reports the minimum hours between automatic price syncs.
// Reused from the currency scheduler (same auth TenantRepository provider).
type IntervalSource interface {
	MinIntervalHours(ctx context.Context) int
}

// PriceSyncer refreshes security prices, returning the count updated.
// Implemented by holding/application.Service.SyncPrices.
type PriceSyncer interface {
	SyncPrices(ctx context.Context) (int, error)
}

// Scheduler periodically calls PriceSyncer.SyncPrices, gated by IntervalSource.
type Scheduler struct {
	syncer PriceSyncer
	src    IntervalSource
	tick   time.Duration
	log    *slog.Logger

	mu       sync.Mutex
	lastSync time.Time
}

// NewScheduler builds a Scheduler. tick is the polling cadence (prod 1h;
// tests use ~10ms).
func NewScheduler(syncer PriceSyncer, src IntervalSource, tick time.Duration, log *slog.Logger) *Scheduler {
	if log == nil {
		log = slog.Default()
	}
	return &Scheduler{syncer: syncer, src: src, tick: tick, log: log}
}

// Start runs the scheduler loop until ctx is cancelled. It performs an
// immediate SyncPrices, then on each tick re-syncs only if at least
// MinIntervalHours have elapsed since the last sync. Errors are logged but
// never exit the loop.
func (s *Scheduler) Start(ctx context.Context) {
	if _, err := s.doSync(ctx); err != nil {
		s.log.Error("price sync failed", "error", err, "operation", "scheduler.Start.doSync")
	}

	ticker := time.NewTicker(s.tick)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			interval := time.Duration(s.src.MinIntervalHours(ctx)) * time.Hour
			s.mu.Lock()
			elapsed := time.Since(s.lastSync)
			s.mu.Unlock()
			if elapsed >= interval {
				if _, err := s.doSync(ctx); err != nil {
					s.log.Error("price sync failed", "error", err, "operation", "scheduler.Start.doSync")
				}
			}
		}
	}
}

// SyncNow triggers an immediate price sync (manual trigger). Returns the count
// and propagates the syncer error (honest contract).
func (s *Scheduler) SyncNow(ctx context.Context) (int, error) {
	return s.doSync(ctx)
}

// doSync runs SyncPrices once, updates lastSync, logs the result, and returns
// the count plus the syncer error (if any). A cancelled ctx short-circuits.
func (s *Scheduler) doSync(ctx context.Context) (int, error) {
	if err := ctx.Err(); err != nil {
		return 0, err
	}
	count, err := s.syncer.SyncPrices(ctx)
	if err != nil {
		s.log.Error("price sync failed", "error", err, "operation", "scheduler.SyncPrices")
	} else {
		s.log.Info("price sync completed", "count", count, "operation", "scheduler.SyncPrices")
	}
	s.mu.Lock()
	s.lastSync = time.Now()
	s.mu.Unlock()
	return count, err
}
```

- [ ] **Step 2: 写 scheduler_test.go(对齐 currency scheduler_test 结构)**

`yucai/server/internal/holding/scheduler/scheduler_test.go`:
```go
package scheduler

import (
	"context"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

type fakeIntervalSource struct {
	hours int
	mu    sync.Mutex
}

func (f *fakeIntervalSource) MinIntervalHours(_ context.Context) int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.hours
}

type mockSyncer struct {
	calls atomic.Int64
	err   error
}

func (m *mockSyncer) SyncPrices(_ context.Context) (int, error) {
	m.calls.Add(1)
	if m.err != nil {
		return 0, m.err
	}
	return 3, nil
}

func TestStartRunsOnceImmediately(t *testing.T) {
	src := &fakeIntervalSource{hours: 9999}
	syncer := &mockSyncer{}
	s := NewScheduler(syncer, src, 10*time.Millisecond, nil)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go s.Start(ctx)

	if !waitForCalls(syncer, 1, 50*time.Millisecond) {
		t.Fatalf("SyncPrices not called within 50ms; calls=%d", syncer.calls.Load())
	}
}

func TestStartDoesNotSyncBeforeInterval(t *testing.T) {
	src := &fakeIntervalSource{hours: 9999}
	syncer := &mockSyncer{}
	s := NewScheduler(syncer, src, 5*time.Millisecond, nil)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go s.Start(ctx)

	if !waitForCalls(syncer, 1, 100*time.Millisecond) {
		t.Fatalf("initial sync did not occur; calls=%d", syncer.calls.Load())
	}
	initial := syncer.calls.Load()
	time.Sleep(40 * time.Millisecond)
	if got := syncer.calls.Load(); got != initial {
		t.Fatalf("unexpected extra sync: initial=%d now=%d", initial, got)
	}
}

func TestCtxCancelStopsGoroutine(t *testing.T) {
	src := &fakeIntervalSource{hours: 0}
	syncer := &mockSyncer{}
	s := NewScheduler(syncer, src, 5*time.Millisecond, nil)

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		s.Start(ctx)
		close(done)
	}()

	if !waitForCalls(syncer, 3, 200*time.Millisecond) {
		t.Fatalf("expected multiple syncs before cancel; calls=%d", syncer.calls.Load())
	}
	beforeCancel := syncer.calls.Load()

	cancel()
	select {
	case <-done:
	case <-time.After(500 * time.Millisecond):
		t.Fatal("Start did not return after ctx cancel")
	}

	time.Sleep(30 * time.Millisecond)
	if got := syncer.calls.Load(); got > beforeCancel+1 {
		t.Fatalf("goroutine synced after cancel; before=%d after=%d", beforeCancel, got)
	}
}

func TestSyncNowPropagatesError(t *testing.T) {
	src := &fakeIntervalSource{hours: 9999}
	wantErr := errors.New("upstream price provider unavailable")
	syncer := &mockSyncer{err: wantErr}
	s := NewScheduler(syncer, src, time.Hour, nil)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	count, err := s.SyncNow(ctx)
	if !errors.Is(err, wantErr) {
		t.Fatalf("SyncNow did not propagate error; got %v want %v", err, wantErr)
	}
	if count != 0 {
		t.Fatalf("count on error should be 0; got %d", count)
	}
}

func TestSyncNowCtxCancelledShortCircuits(t *testing.T) {
	src := &fakeIntervalSource{hours: 9999}
	syncer := &mockSyncer{}
	s := NewScheduler(syncer, src, time.Hour, nil)

	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	before := syncer.calls.Load()
	count, err := s.SyncNow(ctx)
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("expected context.Canceled; got %v", err)
	}
	if count != 0 {
		t.Fatalf("count on cancelled ctx should be 0; got %d", count)
	}
	if got := syncer.calls.Load(); got != before {
		t.Fatalf("doSync should not call syncer on cancelled ctx; before=%d after=%d", before, got)
	}
}

func waitForCalls(syncer *mockSyncer, want int64, max time.Duration) bool {
	deadline := time.Now().Add(max)
	for time.Now().Before(deadline) {
		if syncer.calls.Load() >= want {
			return true
		}
		time.Sleep(2 * time.Millisecond)
	}
	return syncer.calls.Load() >= want
}
```

- [ ] **Step 3: 跑测试验证 PASS**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/scheduler/ -v -count=1
```
Expected: PASS(5 测试)。

- [ ] **Step 4: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/internal/holding/scheduler/
git commit -m "feat(holding-b-server): holding/scheduler PriceScheduler(复用 currency 模式)

NewScheduler+Start+SyncNow+doSync,IntervalSource 复用 currency 同源。
PriceSyncer 接口=SyncPrices(ctx)(int,error)(application.Service 实现)。
5 单测对齐 currency scheduler_test。"
```

---

## Task 6: handler.SyncPrices + 单测(让 server 编译转绿)

**Files:**
- Modify: `yucai/server/internal/holding/adapter/driving/grpc/holding_handler.go`(加 SyncPrices 方法)
- Test: `yucai/server/internal/holding/adapter/driving/grpc/holding_handler_test.go`(新建或追加)

**Interfaces:**
- Consumes: `pb.SyncPricesRequest`/`SyncPricesResponse`(Task 1 生成)、`service.SyncPrices`(Task 4)、`getTenantID`(现有 helper)
- Produces: `HoldingHandler` 满足 `HoldingServiceServer` 接口(Task 1 red 转绿)

**背景**:handler 持有 `service *application.Service`(已有 SyncPrices 方法),直接调。鉴权用 getTenantID(验证登录,价格不按 tenant 但保留门)。`synced_at = now`。

- [ ] **Step 1: 确认 holding_handler_test.go 是否存在**

```bash
ls /e/projects/syfinance/yucai/server/internal/holding/adapter/driving/grpc/holding_handler_test.go 2>/dev/null && echo EXISTS || echo NEW
```

- [ ] **Step 2: 写失败测试(在 holding_handler_test.go 追加或新建)**

```go
package grpc

import (
	"context"

	"testing"
)

// TestSyncPricesReturnsCount 验证 handler.SyncPrices 调 service.SyncPrices
// 并映射 synced_count + synced_at。service 用 stub(若 holding_handler 已有
// stub service 模式则复用;否则本测试用最小 ctx 校验不 panic + 字段非零)。
func TestSyncPricesReturnsCount(t *testing.T) {
	// holding_handler_test.go 已有测试的话,复用其 stub service 构造模式。
	// 若无,见下方最小路径:此 handler 方法薄(getTenantID + service.SyncPrices
	// + 映射),核心是 service.SyncPrices 被正确调用且 response 字段填好。
	//
	// 实现:构造 HoldingHandler(用现有测试的 stub service 注入 SyncPrices=2),
	// 调 h.SyncPrices(ctx, &pb.SyncPricesRequest{}),断言 resp.SyncedCount==2
	// 且 resp.SyncedAt != nil。
	//
	// 见 Step 4 的具体代码(取决于现有 test 的 stub service 形态)。
	t.Skip("填入 Step 4 具体实现:复用现有 holding_handler_test stub service 模式")
}
```

> 注:handler 测试的精确形态取决于现有 `holding_handler_test.go`(若存在)的 stub service 模式。**Step 4 前先 Read 它**:`Read yucai/server/internal/holding/adapter/driving/grpc/holding_handler_test.go`,看它怎么 stub `application.Service`,照搬构造一个 stub service(`SyncPrices` 返回固定 2),然后:
```go
func TestSyncPricesReturnsCount(t *testing.T) {
	h := NewHoldingHandler(stubSvc, nil, nil) // 复用现有测试的 stub + nil txn/lookup
	resp, err := h.SyncPrices(ctxWithTenant(), &pb.SyncPricesRequest{})
	if err != nil { t.Fatalf("unexpected: %v", err) }
	if resp.SyncedCount != 2 { t.Fatalf("count=%d want 2", resp.SyncedCount) }
	if resp.SyncedAt == nil { t.Fatal("synced_at must be set") }
}
```
(`ctxWithTenant` / `stubSvc` 复用现有测试 helper。若现有测试用 mockgen 生成的 mock,照其模式。)

- [ ] **Step 3: 实现 — 在 holding_handler.go 加 SyncPrices(在 ListHoldingTransactions 方法之后)**

```go
// SyncPrices triggers a manual price refresh of all securities via the
// application service (which routes to the configured price provider).
// Prices are security master data (tenant-shared), so we authenticate the
// caller but do not filter by tenant.
func (h *HoldingHandler) SyncPrices(ctx context.Context, _ *pb.SyncPricesRequest) (*pb.SyncPricesResponse, error) {
	if _, err := getTenantID(ctx); err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	count, err := h.service.SyncPrices(ctx)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.SyncPricesResponse{
		SyncedCount: int32(count),
		SyncedAt:    timestamppb.Now(),
	}, nil
}
```

确认 `timestamppb` 已 import(holding_handler.go 现有 imports 含 `google.golang.org/protobuf/types/known/timestamppb`,secToProto 已用)。若无需加。

- [ ] **Step 4: 跑 server 全量 build + handler 测试**

```bash
cd /e/projects/syfinance/yucai/server && go build ./... && go test ./internal/holding/adapter/driving/grpc/ -v -count=1
```
Expected: **build PASS**(Task 1 的红转绿 —— HoldingHandler 现在满足完整 `HoldingServiceServer` 接口);handler 测试 PASS。

- [ ] **Step 5: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/internal/holding/adapter/driving/grpc/
git commit -m "feat(holding-b-server): handler.SyncPrices(调 service.SyncPrices 映射 count+synced_at)

鉴权门(getTenantID)+ service.SyncPrices + timestamppb.Now。
HoldingHandler 满足 Task1 新增的 HoldingServiceServer.SyncPrices,server 编译转绿。"
```

---

## Task 7: wire providers + wire_gen.go 手改 + app.go + main 启动

**Files:**
- Modify: `yucai/server/wire/providers.go`(providePriceRouter + 改 provideHoldingService 加 priceRouter 参数 + providePriceScheduler)
- Modify: `yucai/server/wire/wire_gen.go`(**手改**,不跑 wire CLI)
- Modify: `yucai/server/wire/app.go`(App struct + NewApp 加 HoldingScheduler)
- Modify: `yucai/server/cmd/server/main.go`(go priceScheduler.Start)

**Interfaces:**
- Consumes: Tasks 2-6 全部产物
- Produces: 完整 server 可启动(price scheduler 随 main 启动)

**背景**:wire 工具链坏(见 [[yucai-wire-handmaintained]]),wire_gen.go 手改镜像同模式行(currency scheduler 的 line 144-148 + NewApp line 159)。

- [ ] **Step 1: 改 providers.go — 加 providePriceRouter + providePriceScheduler,改 provideHoldingService**

先 Read 现有 provideHoldingService 签名:
```bash
grep -n "func provideHoldingService" /e/projects/syfinance/yucai/server/wire/providers.go
```
(假设是 `func provideHoldingService(secRepo, hRepo, tRepo) *holdingapp.Service`)

在 `providers.go` 的 currency provider 块(line ~520 `provideCurrencyScheduler` 附近)之后加 holding price 块。**改 `provideHoldingService` 加 priceRouter 参数 + 注入**:
```go
// 改 provideHoldingService(加 priceRouter 参数):
func provideHoldingService(
	secRepo domain.SecurityRepository,        // 保留原有参数(以 grep 实际为准)
	hRepo domain.HoldingRepository,
	tRepo domain.TradeRepository,
	priceRouter priceprovider.Router,
) *holdingapp.Service {
	svc := holdingapp.NewService(secRepo, hRepo, tRepo)
	svc.SetPriceRouter(priceRouter) // wire 注入价格 router
	return svc
}
```
(⚠️ `provideHoldingService` 的原有参数类型以 grep 结果为准 —— 它可能不直接接 repo 而是接 ent client + repo。Read 该函数原样,保留所有原有参数,只**追加** `priceRouter priceprovider.Router` 一个参数 + 两行 body。)

加 import:`priceprovider "github.com/yucai/server/internal/holding/adapter/driven/priceprovider"` + `holdingscheduler "github.com/yucai/server/internal/holding/scheduler"`。

加新 provider 函数(在 provideCurrencyScheduler 之后):
```go
// providePriceRouter builds the price-provider router: Sina (A-share) first,
// then the Stub fallback (non-covered types → keep old price).
func providePriceRouter() priceprovider.Router {
	return priceprovider.NewCompositeRouter(
		priceprovider.NewSinaProvider(),
		priceprovider.NewStubProvider(),
	)
}

// providePriceScheduler builds the price-sync scheduler. *holdingapp.Service
// implements holdingscheduler.PriceSyncer via SyncPrices. tick is 1h in prod;
// reuses the same IntervalSource as the currency scheduler.
func providePriceScheduler(svc *holdingapp.Service, src holdingscheduler.IntervalSource) *holdingscheduler.Scheduler {
	return holdingscheduler.NewScheduler(svc, src, 1*time.Hour, nil)
}
```
(注意:`holdingscheduler.IntervalSource` 与 currency `scheduler.IntervalSource` 是相同接口签名(都 `MinIntervalHours(ctx) int`),wire 的 `provideIntervalSource` 返回值可同时满足两者 —— 但 Go 是结构类型,`tenantIntervalSource` 实现了 `MinIntervalHours`,自动满足 holding 包的 IntervalSource 接口。wire_gen.go 里复用同一 `intervalSource` 变量。)

- [ ] **Step 2: 手改 wire_gen.go(镜像 currency 行)**

Read wire_gen.go 的 line 120-160 区间,定位:
- line 126 `holdingHandler := provideHoldingHandler(holdingService, txnService, accountRepo)`
- line 144 `exchangeRateProvider := provideExchangeRateProvider()`
- line 147 `intervalSource := provideIntervalSource(tenantRepo)`
- line 148 `currencyScheduler := provideCurrencyScheduler(currencyService, intervalSource)`
- line 159 `app := NewApp(...)`(含 currencyScheduler)

手改(在 line 144 之后/exchangeRateProvider 附近加 priceRouter;在 line 148 之后加 priceScheduler;**改 holdingService 构造行加 priceRouter 实参**;NewApp 加 priceScheduler 实参):

```go
// 在 exchangeRateProvider 那行(line 144)之后加:
priceRouter := providePriceRouter()

// 找到 holdingService := provideHoldingService(...) 那行(在 line 126 holdingHandler 之前),
// 改为追加 priceRouter 实参(镜像原有参数顺序 + 新增最后一个):
holdingService := provideHoldingService(securityRepo, holdingRepo, tradeRepo, priceRouter)
// ⚠️ 以实际 provideHoldingService 原参数为准 —— Read 该行原样,只在末尾加 ", priceRouter"

// 在 currencyScheduler 行(line 148)之后加:
priceScheduler := providePriceScheduler(holdingService, intervalSource)

// 改 NewApp 调用(line 159)末尾加 priceScheduler 实参(在 currencyScheduler 之后):
app := NewApp(cfg, log, grpcSrv, tenantRepo, userRepo, accountService, authHandler, accountHandler, txnHandler, budgetHandler, debtHandler, goalHandler, tagHandler, templateHandler, holdingHandler, holdingService, backupHandler, syncHandler, currencyHandler, currencyScheduler, currencyService, priceScheduler)
```

> 关键:**先 Read wire_gen.go line 120-165**,把 holdingService 原构造行的**确切参数**抄下来,只追加 `, priceRouter`;NewApp 原参数抄下来,只追加 `, priceScheduler`。不要凭记忆改。

- [ ] **Step 3: 改 app.go — App struct + NewApp 加 HoldingScheduler**

Read `wire/app.go` line 26-95(struct + NewApp)。改:
- App struct 加字段(在 `CurrencyScheduler *scheduler.Scheduler` 之后):
```go
HoldingScheduler *holdingscheduler.Scheduler
```
- 加 import:`holdingscheduler "github.com/yucai/server/internal/holding/scheduler"`
- NewApp 签名加参数(在 `currencyScheduler *scheduler.Scheduler` 之后,`currencyService` 之前/之后以实际为准):
```go
holdingScheduler *holdingscheduler.Scheduler,
```
- NewApp body 的 struct literal 加:`HoldingScheduler: holdingScheduler,`(在 `CurrencyScheduler: currencyScheduler,` 之后)

> 现有 NewApp 参数顺序以 Read 为准 —— 在 currencyScheduler 参数后插入 holdingScheduler。

- [ ] **Step 4: 改 main.go — go priceScheduler.Start(schedCtx)**

Read `cmd/server/main.go` line 60-70(现有 `go app.CurrencyScheduler.Start(schedCtx)` 在 line 69)。在它之后加:
```go
// Start holding price-sync scheduler. Performs an immediate SyncPrices on
// start, then refreshes A-share prices at most once per MinIntervalHours.
go app.HoldingScheduler.Start(schedCtx)
```

(注册 HoldingServiceServer 不需改 —— 它在 line 83 附近 `pb.RegisterHoldingServiceServer(app.GRPCServer, app.HoldingHandler)` 已存在,handler 现在含 SyncPrices。Read 确认。)

- [ ] **Step 5: go build 全量绿**

```bash
cd /e/projects/syfinance/yucai/server && go build ./...
```
Expected: **PASS**(无错)。若报错:
- `holdingService` 参数不匹配 → 检查 Step 2 的 provideHoldingService 实参顺序
- `intervalSource` 类型不满足 holding IntervalSource → 确认 tenantIntervalSource 有 MinIntervalHours 方法(它满足,结构类型)
- NewApp 参数个数 → 检查 Step 3

- [ ] **Step 6: 跑 server 全量测试确保不破坏**

```bash
cd /e/projects/syfinance/yucai/server && go test ./... -count=1
```
Expected: PASS(现有测试 + 新增 priceprovider/scheduler/service handler 测试)。

- [ ] **Step 7: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/wire/ yucai/server/cmd/server/main.go
git commit -m "feat(holding-b-server): wire+main 接线 priceRouter/PriceScheduler

providers.go:providePriceRouter(Sina+Stub)+providePriceScheduler+
provideHoldingService 加 priceRouter 注入。wire_gen.go 手改(工具链坏,
镜像 currency scheduler 行)。app.go+main:App.HoldingScheduler + Start。
go build ./... 绿 + 全量 test 过。"
```

---

## Task 8: server 端到端手动验证(新浪真实拉价)

**Files:** 无改动(验证 task)

**背景**:验证 server 启动后 scheduler 自动拉一次 + 手动 RPC 触发,能把 600519/510300/511010 的 `current_price_cents` 更新为真实价。

- [ ] **Step 1: 起 podman DB + 重建 server**

```bash
# 确认 DB 容器在跑
"C:\Users\andy\AppData\Local\Programs\Podman\podman.exe" ps --filter name=yucai-pg --format '{{.Names}} {{.Status}}'
# 重建 server.exe
cd /e/projects/syfinance/yucai/server && go build -o bin/server.exe ./cmd/server
```

- [ ] **Step 2: 启动 server(background,绝对路径 cwd)**

用 Bash run_in_background:
```bash
cd /e/projects/syfinance/yucai/server && \
export DATABASE_URL='postgresql://yucai:yucai@localhost:5432/yucai?sslmode=disable' && \
export JWT_SECRET='dev-secret-change-me-32chars-minimum-aaaa' && \
export GRPC_PORT=9090 && export LOG_LEVEL=debug && \
./bin/server.exe 2>&1
```
监听启动日志,确认有 `price sync completed count:N operation=scheduler.SyncPrices`(N≥1 表示至少拉到 1 支 A 股;理想 N=3 即 600519/510300/511010)。

- [ ] **Step 3: DB 验证 current_price_cents 更新**

```bash
"C:\Users\andy\AppData\Local\Programs\Podman\podman.exe" exec yucai-pg psql -U yucai -d yucai -c "SELECT symbol, exchange, current_price_cents FROM securities ORDER BY symbol;"
```
Expected: 600519(茅台,SSE)的 `current_price_cents` ≈ 真实股价×100(不再是 seed 的 168000,除非巧合);510300/511010 同理(若当日有行情)。AAPL/000001/AU9999/OP100006 保持 seed 原值(stub 无源)。记下实际值作验证证据。

- [ ] **Step 4(可选): 用 grpcurl 手动触发 SyncPrices RPC**

若装了 grpcurl:
```bash
# 先登录拿 token(用 test@yucai.local/test1234),再调 SyncPrices
grpcurl -plaintext -d '{}' -H "authorization: Bearer <TOKEN>" localhost:9090 yucai.holding.v1.HoldingService/SyncPrices
```
Expected: `{"syncedCount": N, "syncedAt": "..."}`。若没装 grpcurl,Step 2-3 的 scheduler 自动拉价已足够证明端到端通。

- [ ] **Step 5: TaskStop server,记录结果**

停掉 background server。在 plan 的 task 进度里记 "Task 8 验证通过:600519/510300/511010 价格更新到 X,其他保持 seed"。(无 commit — 纯验证)

---

## Task 9: Flutter remote_ds + repository syncPrices + 单测

**Files:**
- Modify: `yucai/client/lib/holding/data/holding_remote_ds.dart`(加 syncPrices)
- Modify: `yucai/client/lib/holding/domain/repositories/holding_repository.dart`(加 syncPrices 抽象)
- Modify: `yucai/client/lib/holding/data/holding_repository_impl.dart`(加 syncPrices 实现)
- Test: `yucai/client/test/holding/data/holding_remote_ds_test.dart` 或现有 ds test(若有 mock)

**Interfaces:**
- Consumes: Dart stub `HoldingServiceClient.syncPrices` + `SyncPricesRequest/Response`(Task 1 make gen-dart 生成)
- Produces:
  - `HoldingRemoteDataSource.syncPrices() → Future<({int syncedCount, DateTime syncedAt})>`(或自定义 SyncPricesResult 类)
  - `HoldingRepository.syncPrices() → Future<Either<Failure, SyncPricesResult>>`
- Task 10(bloc)依赖

**背景**:对齐现有 ds 方法模式(`_retry.call(() async { final res = await _client.xxx(req); return ...; })`)。需要一个结果类型存 syncedCount + syncedAt。

- [ ] **Step 1: 定义 SyncPricesResult 类型**

在 `yucai/client/lib/holding/domain/entities/holding_entity.dart` 末尾(或新建 `sync_prices_result.dart`)加:
```dart
/// SyncPrices RPC 结果(client 用)。对齐 proto SyncPricesResponse。
class SyncPricesResult extends Equatable {
  const SyncPricesResult({required this.syncedCount, required this.syncedAt});
  final int syncedCount;     // 成功更新的 security 数
  final DateTime syncedAt;   // server 同步时间

  @override
  List<Object?> get props => [syncedCount, syncedAt];
}
```
(若 holding_entity.dart 没 import equatable,加 `import 'package:equatable/equatable.dart';`。或放独立文件避免污染。)

- [ ] **Step 2: remote_ds 加 syncPrices**

在 `holding_remote_ds.dart` 的 `updateSecurityPrice` 方法之后加:
```dart
  /// 触发 server 端批量价格同步(手动刷新)。返回成功更新数 + server 同步时间。
  Future<SyncPricesResult> syncPrices() async {
    return _retry.call(() async {
      final res = await _client.syncPrices(pb.SyncPricesRequest());
      return SyncPricesResult(
        syncedCount: res.syncedCount,
        syncedAt: res.syncedAt.toDateTime(),
      );
    });
  }
```
(需 import SyncPricesResult:`import 'package:yucai_client/holding/domain/entities/holding_entity.dart';` 已有,确保 SyncPricesResult 在那。`res.syncedAt` 是 `pb.Timestamp`,`toDateTime()` 是 protobuf Timestamp 扩展方法 —— 确认 stub 生成后 Timestamp 有 `toDateTime()`(protobuf 6.x 有)。若不是,用 `DateTime.fromMillisecondsSinceEpoch(res.syncedAt.seconds * 1000)`。)

- [ ] **Step 3: domain 抽象加 syncPrices**

在 `holding_repository.dart` 的 `updateSecurityPrice` 抽象之后加:
```dart
  Future<Either<Failure, SyncPricesResult>> syncPrices();
```
(确保 `SyncPricesResult` import 到 holding_repository.dart。)

- [ ] **Step 4: repository_impl 加 syncPrices**

在 `holding_repository_impl.dart` 的 `updateSecurityPrice` 实现之后加:
```dart
  @override
  Future<Either<Failure, SyncPricesResult>> syncPrices() =>
      _guard(() => _remote.syncPrices());
```

- [ ] **Step 5: 写/补单测**

查现有 ds test:
```bash
ls /e/projects/syfinance/yucai/client/test/holding/data/ 2>/dev/null
```
若有 `holding_remote_ds_test.dart`,照其 mock 模式加 `syncPrices` 测试(mock `HoldingServiceClient.syncPrices` 返回 `SyncPricesResponse(syncedCount: 3, syncedAt: Timestamp)` → 断言 ds 返回 `SyncPricesResult(syncedCount: 3, ...)`)。若无 ds test,跳过(bloc test Task 10 会覆盖 repo 层)。

- [ ] **Step 6: flutter analyze + test**

```bash
cd /e/projects/syfinance/yucai/client && flutter analyze lib/holding/data/holding_remote_ds.dart lib/holding/data/holding_repository_impl.dart lib/holding/domain/repositories/holding_repository.dart
```
Expected: 0 新 error(基线 22 全 *.pbserver.dart,非本 task)。

```bash
cd /e/projects/syfinance/yucai/client && flutter test test/holding/
```
Expected: PASS(现有 + 新增)。

- [ ] **Step 7: Commit**

```bash
cd /e/projects/syfinance
git add yucai/client/lib/holding/
git commit -m "feat(holding-b-flutter): remote_ds+repository syncPrices 对接 SyncPrices RPC

ds.syncPrices → stub.syncPrices → SyncPricesResult(syncedCount+syncedAt)。
domain 抽象 + impl 一致。retry 包裹(401 自动刷新)。"
```

---

## Task 10: Flutter bloc RefreshPricesRequested + state + 单测

**Files:**
- Modify: `yucai/client/lib/holding/presentation/bloc/holding_event.dart`(加 RefreshPricesRequested)
- Modify: `yucai/client/lib/holding/presentation/bloc/holding_state.dart`(HoldingLoaded 加 lastPriceSyncedAt,去 const)
- Modify: `yucai/client/lib/holding/presentation/bloc/holding_bloc.dart`(加 _lastPriceSyncedAt 字段 + _onRefreshPrices + on<RefreshPricesRequested> + _onLoadHoldings 带上 lastPriceSyncedAt)
- Test: `yucai/client/test/holding/presentation/bloc/holding_bloc_test.dart`

**Interfaces:**
- Consumes: `HoldingRepository.syncPrices`(Task 9)、`LoadHoldingsRequested`(现有,刷新后重发以重算 marketValue/pnl)
- Produces: `RefreshPricesRequested` event;`HoldingLoaded.lastPriceSyncedAt`(UI 显示用)

**背景**:`_onUpdatePrice` 是 `_onRefreshPrices` 的完美模板(emit Submitting → repo → Right: add LoadHoldingsRequested 自刷新;Left: Error)。`lastPriceSyncedAt` 存 bloc 私有字段,刷新成功后更新,`_onLoadHoldings` 构造 HoldingLoaded 时带上(跨 state 保持)。

- [ ] **Step 1: holding_event.dart 加 RefreshPricesRequested**

在 `UpdatePriceRequested` 之后加:
```dart
/// 手动触发 server 端批量价格同步(持仓页刷新按钮)。
class RefreshPricesRequested extends HoldingEvent {
  const RefreshPricesRequested();
}
```

- [ ] **Step 2: holding_state.dart — HoldingLoaded 加 lastPriceSyncedAt(去 const)**

`DateTime` 非 const,所以 `HoldingLoaded` 构造函数去 `const` 关键字。改 HoldingLoaded(line 43-57):
```dart
class HoldingLoaded extends HoldingState {
  HoldingLoaded({
    required this.holdings,
    required this.summary,
    this.securities = const [],
    this.typeFilter,
    this.lastPriceSyncedAt,
  });
  final List<Holding> holdings;
  final HoldingSummary summary;
  final List<Security> securities;
  final SecurityType? typeFilter;
  final DateTime? lastPriceSyncedAt; // 上次价格刷新时间(client 本地记录,拍板点①)

  @override
  List<Object?> get props => [holdings, summary, securities, typeFilter, lastPriceSyncedAt];
}
```
> 检查全代码库是否有 `const HoldingLoaded(` 调用(grep):若有,去掉那些 const。`_onLoadSecurities` 里 `HoldingLoaded(holdings: const [], summary: const HoldingSummary(...), ...)` —— 注意那里的 `const` 是给 `[]`/`HoldingSummary` 的,不是给 `HoldingLoaded`,保留即可(HoldingLoaded 构造去 const 后,该调用仍合法)。

- [ ] **Step 3: holding_bloc.dart — 加字段 + handler + 注册**

在 `_lastSecurities` 字段之后(line 33 附近)加:
```dart
  /// 上次价格刷新时间(client 本地,刷新成功后更新,_onLoadHoldings 带入 state)。
  DateTime? _lastPriceSyncedAt;
```

在构造函数的 `on<...>` 块(line 14-23)末尾(`on<UpdatePriceRequested>(_onUpdatePrice);` 之后)加:
```dart
    on<RefreshPricesRequested>(_onRefreshPrices);
```

改 `_onLoadHoldings`(line 53-73):构造 HoldingLoaded 时带上 `lastPriceSyncedAt: _lastPriceSyncedAt`。把 line 63-68 的 `final loaded = HoldingLoaded(...)` 改为:
```dart
        final loaded = HoldingLoaded(
          holdings: holdings,
          summary: _summarize(holdings),
          securities: _lastSecurities,
          typeFilter: event.typeFilter,
          lastPriceSyncedAt: _lastPriceSyncedAt,
        );
```

在文件末尾(`_onUpdatePrice` 之后,line 308 前)加 `_onRefreshPrices`:
```dart
  /// 手动刷新价格:调 repo.syncPrices(server 批量拉价)→ 成功则记录时间 +
  /// 重发 LoadHoldingsRequested(用新价格重算 marketValue/pnl);失败 HoldingError。
  Future<void> _onRefreshPrices(
    RefreshPricesRequested event,
    Emitter<HoldingState> emit,
  ) async {
    emit(HoldingSubmitting(last: _last));
    final result = await _repo.syncPrices();
    result.fold(
      (failure) => emit(HoldingError(failure.displayMessage, last: _last)),
      (r) {
        _lastPriceSyncedAt = r.syncedAt;
        add(LoadHoldingsRequested(typeFilter: _lastFilter));
      },
    );
  }
```

- [ ] **Step 4: 写 bloc 测试**

在 `holding_bloc_test.dart` 加(复用现有 mock repo 模式):
```dart
test('RefreshPricesRequested: syncPrices Right → 更新 lastPriceSyncedAt + 重发 LoadHoldings',
    () async {
  // arrange: mock repo.syncPrices → Right(SyncPricesResult(syncedCount: 3, syncedAt: T))
  //          mock repo.listHoldings → Right([holding1, holding2])
  // act: bloc.add(RefreshPricesRequested())
  // assert: emit 顺序 [HoldingSubmitting, HoldingLoaded(lastPriceSyncedAt: T)]
  //         最后 state 是 HoldingLoaded,lastPriceSyncedAt == T
});
```
(具体 mock 构造照搬现有 holding_bloc_test 的 `when(repo.listHoldings)` 模式,改成 `when(repo.syncPrices)`。)

- [ ] **Step 5: flutter analyze + test**

```bash
cd /e/projects/syfinance/yucai/client && flutter analyze lib/holding/presentation/bloc/
cd /e/projects/syfinance/yucai/client && flutter test test/holding/presentation/bloc/holding_bloc_test.dart
```
Expected: analyze 0 新 error;test PASS(含新 RefreshPrices 测试 + 现有不破坏)。

- [ ] **Step 6: Commit**

```bash
cd /e/projects/syfinance
git add yucai/client/lib/holding/presentation/bloc/ yucai/client/test/holding/presentation/bloc/
git commit -m "feat(holding-b-flutter): bloc RefreshPricesRequested + lastPriceSyncedAt

_onRefreshPrices: repo.syncPrices → Right 记录 syncedAt + 重发 LoadHoldings
(新价格重算)。HoldingLoaded 加 lastPriceSyncedAt(client 本地,去 const)。
_onUpdatePrice 作模板。bloc 测试。"
```

---

## Task 11: 持仓页刷新 UX + 清 A 尾巴(ListHoldingTransactions)+ 端到端

**Files:**
- Modify: `yucai/client/lib/holding/presentation/pages/holdings_page.dart`(刷新按钮 + last-updated 显示,对齐 OD 原型)
- Modify: `yucai/client/lib/holding/presentation/bloc/holding_bloc.dart`(清 _onLoadDetail 过时 ⏳ 注释 line 77-82)
- Verify: 端到端(client run → 持仓详情交易历史真数据)

**Interfaces:**
- Consumes: Task 10 bloc RefreshPricesRequested + lastPriceSyncedAt

**背景**:持仓页加"刷新价格"按钮(↻ icon + loading + last-updated HH:mm),对齐 OD 原型 `design-output/holding/` holdings_page。同时清 A 尾巴:bloc `_onLoadDetail` 过时注释("⏳ 后端 B/C/D 未实现")→ 后端已实现(Task 1-7 之前就实现了,见 [holding_handler.go:229]);核实 remote_ds listHoldingTransactions stub 对齐 + 端到端验证。

- [ ] **Step 1: 核实 listHoldingTransactions 端到端(A 尾巴)**

Read `holding_remote_ds.dart` line 55-67(listHoldingTransactions 方法,已确认存在且调 `_client.listHoldingTransactions(pb.ListTradesRequest(...))`)。确认 Dart stub `holding.pb.dart` 的 `ListTradesRequest` 有 `accountId`/`securityId`/`page` 字段 + `ListTradesResponse.trades`(Task 1 make gen-dart 已重生成,字段应齐 —— proto line 140-144 + 151 定义)。

- [ ] **Step 2: 清 _onLoadDetail 过时注释**

Read `holding_bloc.dart` line 75-82(`_onLoadDetail` 的文档注释)。把:
```dart
  /// ⏳ 关键:listHoldingTransactions 是 ⏳ 端点(后端 B/C/D 未实现)。
  /// 其 fail → **HoldingDetailLoaded(found, trades: [], isPendingBackend: true)**:
  /// ...
```
改为:
```dart
  /// 详情加载:listHoldings 找单条 + listHoldingTransactions 取流水(后端✅已实现,
  /// holding_handler.go:229)。fail 仅作兜底降级(网络/后端异常)→
  /// HoldingDetailLoaded(found, trades: [], isPendingBackend: true),
  /// holding 仍展示,交易历史区空态。listHoldings fail / not found → 真错误。
```
(行为不变 —— 只清过时注释,保留 isPendingBackend 兜底逻辑。同步清 holding_state.dart line 89-92 HoldingError 文档里"⏳ 端点(后端 B/C/D 未实现)"表述。)

- [ ] **Step 3: 持仓页刷新按钮 + last-updated UX**

Read `holdings_page.dart` 找顶部 StatCard/AppBar 区域。加刷新按钮(对齐 OD 原型 holdings_page 刷新 UX):
```dart
// 在 AppBar actions 或 StatCard 行加:
BlocBuilder<HoldingBloc, HoldingState>(
  builder: (context, state) {
    final syncing = state is HoldingSubmitting;
    final last = state is HoldingLoaded ? state.lastPriceSyncedAt : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (last != null)
          Text('上次更新 ${DateFormat('HH:mm').format(last)}', style: theme.textTheme.bodySmall),
        IconButton(
          icon: syncing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh),
          onPressed: syncing ? null : () => context.read<HoldingBloc>().add(const RefreshPricesRequested()),
        ),
      ],
    );
  },
),
```
(对齐 OD 原型 `design-output/holding/holdings_page.html` 的刷新按钮位置/样式。icon 用 lucide_icons 的 `refresh-cw` 线性库对齐原型线性 SVG —— 见 [[od-prototype-to-flutter]];若 holdings_page 已用 lucide,照搬;否则用 Material Icons.refresh。`DateFormat` 来自 `package:intl/intl.dart`,确认依赖或用 `'$last'` 简化。)

- [ ] **Step 4: flutter analyze + 全量 test**

```bash
cd /e/projects/syfinance/yucai/client && flutter analyze lib/holding/
cd /e/projects/syfinance/yucai/client && flutter test test/holding/
```
Expected: analyze 0 新 error(22 基线 *.pbserver);test PASS(现有 93 + 新增不破坏)。

- [ ] **Step 5: 端到端 — 启动 server + client,验证两件事**

```bash
# 1. server 在跑(Task 8 起的 background,或重启)
# 2. client debug 模式(避免 release accessibility_bridge 卡,见 [[yucai-dev-env]])
cd /e/projects/syfinance/yucai/client && flutter run -d windows
```
验证:
1. **B 刷新**:持仓页点刷新按钮 → loading → last-updated 时间更新 → holdings 的 marketValue/pnl 反映新价(server Task 8 已更新 DB 的真实 A 股价)
2. **A 尾巴清掉**:点持仓详情 → 交易历史区显示真 trades(非空态,非"⏳ 待后端")

- [ ] **Step 6: Commit**

```bash
cd /e/projects/syfinance
git add yucai/client/lib/holding/
git commit -m "feat(holding-b-flutter): 持仓页刷新UX + 清 ListHoldingTransactions A 尾巴

刷新按钮(loading+last-updated HH:mm,对齐 OD 原型)触发 RefreshPricesRequested。
清 _onLoadDetail/HoldingError 过时⏳注释(后端✅已实现),保留 isPendingBackend
兜底。端到端验证:刷新反映新价 + 持仓详情交易历史真数据。"
```

---

## 全链路验证(plan 收尾)

- [ ] **server**:`cd yucai/server && go build ./... && go test ./... -count=1` 全绿
- [ ] **flutter**:`cd yucai/client && flutter analyze lib/holdings` 0 新 error + `flutter test test/holding/` 全绿
- [ ] **端到端**:server + client run,刷新价格反映真实 A 股价 + 持仓详情交易历史真数据
- [ ] **A 尾巴清零**:三个 ⏳ 降级点之一(ListHoldingTransactions)转真对接;剩 snapshot/goal 仍 ⏳(C/D 做)
- [ ] **commit 历史**:Task 0-11 各自 conventional commit

## Self-Review(plan 自查)

**1. Spec coverage**(对照 spec 各节):
- §1 目标(自动+手动+provider 可插拔+清 A 尾巴)→ Tasks 1-11 ✅
- §2 范围边界 → 全部 task 在范围内,无 history/snapshot/goal/C/D 越界 ✅
- §3 架构(provider server 端 + scheduler + RPC + Flutter)→ Tasks 2-7(server)+ 9-11(Flutter)✅
- §4 复用对照(currency→holding)→ Tasks 2/3(Frankfurter→Sina)、5(scheduler)、7(wire)✅
- §5.1 priceprovider(接口+Sina+Stub+Router)→ Task 2(接口+Stub+Router)+ Task 3(Sina)✅
- §5.2 service.SyncPrices → Task 4 ✅(refine:返回 (int,error) 而非 SyncPricesResult,对齐 currency)
- §5.3 scheduler → Task 5 ✅
- §5.4 proto SyncPrices RPC → Task 1 ✅(refine:去 failed_count,见 Global Constraints)
- §5.5 handler.SyncPrices → Task 6 ✅
- §5.6 wire+main → Task 7 ✅
- §6 schema 零改动 → 全 plan 无 migration/ent schema 改动 ✅
- §7 Flutter(ds/repository/bloc/state/UX)→ Tasks 9/10/11 ✅
- §7.4 清 A 尾巴 → Task 11 Step 1-2/5 ✅
- §8 失败/降级 → Task 2 Router 逻辑 + Task 4 service best-effort + Task 5 scheduler ✅
- §9 测试策略 → 每个 task 含 TDD 单测 ✅
- §10 前置清理 → Task 0 ✅
- §11 决策记录 → Global Constraints 反映 5 拍板点 ✅
- §12 新浪接口技术 → Global Constraints 索引2(修正 spec 的3)+ Task 3 SinaProvider 完整实现 ✅
- §13 实施顺序 → Task 0-11 顺序对齐 ✅

**2. Placeholder scan**:
- Task 4 Step 1-2 的 `fakeSecurityRepo` 实现依赖 `domain.SecurityRepository` 接口签名 —— plan 给了"先 grep 接口再补全"的明确路径(非 placeholder,是必要的接口发现步骤,因接口方法多且 plan 不凭记忆写)
- Task 6 Step 2/4 的 handler 测试依赖现有 `holding_handler_test.go` 的 stub service 模式 —— plan 给了"先 Read 再照搬"的明确路径
- Task 7 wire 改动依赖实际 wire_gen.go / provideHoldingService / NewApp 的确切参数 —— plan 给了"先 Read 再镜像"的明确路径
- 这三处是"对现有代码精确对齐"的必要步骤,不是内容缺失;执行者按指引 Read 后能直接写

**3. Type consistency**:
- `SyncPrices(ctx) (int, error)`:Task 4 service 定义 → Task 5 PriceSyncer 接口 → Task 6 handler 调用 → 一致 ✅
- `priceprovider.Router.FetchPrice(ctx, PriceView) (int64, string, error)`:Task 2 定义 → Task 3 SinaProvider 实现 → Task 4 service 调用 → 一致 ✅
- `ErrNoSource`:Task 2 定义 → Task 3 Sina 返回 → Task 4 service 判断 → 一致 ✅
- `SyncPricesResult{syncedCount, syncedAt}`(Dart):Task 9 定义 → Task 10 bloc 用 `r.syncedAt` → 一致 ✅
- `HoldingLoaded.lastPriceSyncedAt`:Task 2 state 定义 → Task 10 bloc 赋值 + UI 读 → 一致 ✅
- proto `SyncPricesResponse{synced_count, synced_at}`:Task 1 定义 → Task 6 handler 映射(`SyncedCount`/`SyncedAt`)→ Dart stub `syncedCount`/`syncedAt` → 一致 ✅

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-06-30-holding-price-sync.md`. 执行方式见下方对话。
