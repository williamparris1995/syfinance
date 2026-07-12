# 美股/OTC price history 回填 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 扩展 `HistoricalProvider` 覆盖美股/OTC(Yahoo Finance chart API),Sina 不覆盖的 symbol fallback Yahoo,解 holding 区间 XIRR 美股降级。

**Architecture:** 新增 `YahooProvider`(implement `HistoricalProvider`)+ `HistoricalRouter`(多源,对称 `CompositeRouter`,ErrNoSource 跳下一个)。wire `provideHistoricalProvider` 从单 SinaProvider 改注入 HistoricalRouter(Sina→Yahoo)。零 schema/proto/application 接口改动 —— `BackfillPriceHistory` 调 `historicalProvider.FetchHistory` 不变,内部 router 路由。

**Tech Stack:** Go(server,DDD + ent + 手改 wire)+ Yahoo Finance chart API v8(免费无 key,JSON)。

**Spec:** [docs/superpowers/specs/2026-07-12-yahoo-price-history-design.md](../specs/2026-07-12-yahoo-price-history-design.md)

## Global Constraints

- **英文结构化日志** — slog(`slog.Warn("op", "key", val)`),无 CJK 在 log 串。
- **wire 手改** — `wire_gen.go` 手改(工具链坏,见 [[yucai-wire-handmaintained]]),镜像现有 provider 声明顺序,不跑 wire CLI。
- **server test** — `cd yucai/server && go test ./internal/holding/... -count=1`。
- **零改动** — ent schema(price_history 表已建)/ proto / client / application 接口(`BackfillPriceHistory` 签名不变,`Service.historicalProvider` 字段类型 `HistoricalProvider` 不变)。
- **复用第一** — 复用 `HistoricalProvider`/`PriceView`/`HistoryPoint`/`ErrNoSource`(不改 domain);对齐 `SinaProvider`/`CompositeRouter`/`sina_test`/`provider_test` 模式。
- **降级不造假** — Yahoo 404→`ErrNoSource`;403/429→error(best-effort 跳过+日志);回填失败 → XIRR 区间降级 `—`(全期不受影响)。

## File Structure

| 文件 | 责任 | 动作 |
|---|---|---|
| `yucai/server/internal/holding/adapter/driven/priceprovider/yahoo.go` | `YahooProvider` implement `HistoricalProvider.FetchHistory`(Yahoo chart API) | Create |
| `yucai/server/internal/holding/adapter/driven/priceprovider/yahoo_test.go` | httptest mock chart(正常/404/403/null close/symbol 转换) | Create |
| `yucai/server/internal/holding/adapter/driven/priceprovider/history_router.go` | `HistoricalRouter` 多源 history(对称 CompositeRouter) | Create |
| `yucai/server/internal/holding/adapter/driven/priceprovider/history_router_test.go` | router 多源(对齐 provider_test stubProbe 模式) | Create |
| `yucai/server/wire/providers.go` | `provideHistoricalProvider` 改注入 HistoricalRouter | Modify(:642-644) |
| `yucai/server/wire/wire_gen.go` | 手改镜像 provideHistoricalProvider | Modify(手改) |

---

### Task 1: YahooProvider(Yahoo chart API)

**Files:**
- Create: `yucai/server/internal/holding/adapter/driven/priceprovider/yahoo.go`
- Test: `yucai/server/internal/holding/adapter/driven/priceprovider/yahoo_test.go`

**Interfaces:**
- Consumes: `PriceView{Symbol, Exchange, Type}`([provider.go:21](../../yucai/server/internal/holding/adapter/driven/priceprovider/provider.go#L21))、`HistoryPoint{Date, PriceCents}`([history.go:9](../../yucai/server/internal/holding/adapter/driven/priceprovider/history.go#L9))、`ErrNoSource`([provider.go:17](../../yucai/server/internal/holding/adapter/driven/priceprovider/provider.go#L17))、`HistoricalProvider` 接口([history.go:19](../../yucai/server/internal/holding/adapter/driven/priceprovider/history.go#L19))。
- Produces: `YahooProvider` struct + `NewYahooProvider()` + `FetchHistory(ctx, v PriceView, datalen int) ([]HistoryPoint, error)`。Task 2/3 用 `NewYahooProvider()`。

- [ ] **Step 1: Write the failing test**

Create `yahoo_test.go`:

```go
package priceprovider

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestYahooFetchHistoryParsesChart(t *testing.T) {
	close129, close130 := 129.41, 130.92
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("User-Agent") == "" {
			t.Errorf("missing User-Agent header")
		}
		if path := r.URL.Path; path != "/v8/finance/chart/AAPL" {
			t.Errorf("path = %q, want /v8/finance/chart/AAPL", path)
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"chart": map[string]interface{}{
				"result": []map[string]interface{}{
					{
						"timestamp": []int64{1609459200, 1609545600},
						"indicators": map[string]interface{}{
							"quote": []map[string]interface{}{
								{"close": []*float64{&close129, &close130}},
							},
						},
					},
				},
			},
		})
	}))
	defer srv.Close()

	p := newYahooProviderWithURL(srv.URL)
	pts, err := p.FetchHistory(context.Background(), PriceView{Symbol: "AAPL", Exchange: "NASDAQ"}, 30)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(pts) != 2 {
		t.Fatalf("got %d points, want 2", len(pts))
	}
	if pts[0].PriceCents != 12941 || pts[1].PriceCents != 13092 {
		t.Errorf("prices = %d/%d, want 12941/13092", pts[0].PriceCents, pts[1].PriceCents)
	}
	// UTC date truncation: 1609459200 = 2021-01-01 00:00:00 UTC.
	wantDate := time.Unix(1609459200, 0).UTC().Truncate(24 * time.Hour)
	if !pts[0].Date.Equal(wantDate) {
		t.Errorf("date = %v, want %v", pts[0].Date, wantDate)
	}
}

func TestYahooNullCloseSkipped(t *testing.T) {
	close130 := 130.92
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"chart": map[string]interface{}{
				"result": []map[string]interface{}{
					{
						"timestamp": []int64{1609459200, 1609545600},
						"indicators": map[string]interface{}{
							"quote": []map[string]interface{}{
								{"close": []*float64{nil, &close130}},
							},
						},
					},
				},
			},
		})
	}))
	defer srv.Close()

	p := newYahooProviderWithURL(srv.URL)
	pts, err := p.FetchHistory(context.Background(), PriceView{Symbol: "AAPL"}, 30)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(pts) != 1 || pts[0].PriceCents != 13092 {
		t.Fatalf("null close must be skipped; got %v", pts)
	}
}

func TestYahoo404NoSource(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	defer srv.Close()
	p := newYahooProviderWithURL(srv.URL)
	_, err := p.FetchHistory(context.Background(), PriceView{Symbol: "UNKNOWN"}, 30)
	if !errors.Is(err, ErrNoSource) {
		t.Fatalf("404 must be ErrNoSource; got %v", err)
	}
}

func TestYahoo403RealError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusForbidden)
	}))
	defer srv.Close()
	p := newYahooProviderWithURL(srv.URL)
	_, err := p.FetchHistory(context.Background(), PriceView{Symbol: "AAPL"}, 30)
	if err == nil || errors.Is(err, ErrNoSource) {
		t.Fatalf("403 must be a real error (not ErrNoSource); got %v", err)
	}
}

func TestYahooSymbolConversion(t *testing.T) {
	var gotPath string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		_, _ = w.Write([]byte(`{"chart":{"result":[{"timestamp":[],"indicators":{"quote":[{"close":[]}]}}]}}`))
	}))
	defer srv.Close()
	p := newYahooProviderWithURL(srv.URL)
	_, _ = p.FetchHistory(context.Background(), PriceView{Symbol: "BRK.B"}, 30)
	if gotPath != "/v8/finance/chart/BRK-B" {
		t.Errorf("BRK.B → path %q, want /v8/finance/chart/BRK-B", gotPath)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd yucai/server && go test ./internal/holding/adapter/driven/priceprovider/ -run TestYahoo -count=1 -v`
Expected: FAIL / 编译失败(`YahooProvider`/`newYahooProviderWithURL` undefined)。

- [ ] **Step 3: Write minimal implementation**

Create `yahoo.go`:

```go
package priceprovider

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"strings"
	"time"
)

// YahooProvider fetches daily K-line history from Yahoo Finance
// (query1.finance.yahoo.com/v8/finance/chart). Free, no API key. Covers any
// symbol Yahoo knows (US stocks/ETFs, HK, global) — used as the fallback
// after SinaProvider (which covers A-share SSE/SZSE + CSI300 only).
//
// Returns ErrNoSource on HTTP 404 (symbol not in Yahoo); HTTP 403/429
// (rate-limit) are real errors so BackfillPriceHistory logs + skips the
// security (best-effort, mirroring Sina SyncPrices). No retry/rate-limit
// sleep (YAGNI; rerun the BackfillPriceHistory RPC to refill skips).
type YahooProvider struct {
	baseURL string
	client  *http.Client
}

// NewYahooProvider builds a YahooProvider pointing at the public endpoint.
func NewYahooProvider() *YahooProvider {
	return &YahooProvider{
		baseURL: "https://query1.finance.yahoo.com",
		client:  &http.Client{Timeout: 10 * time.Second},
	}
}

// newYahooProviderWithURL is the test seam: point at a httptest server.
func newYahooProviderWithURL(baseURL string) *YahooProvider {
	return &YahooProvider{baseURL: baseURL, client: &http.Client{Timeout: 5 * time.Second}}
}

// yahooChartResponse matches the v8 chart API JSON shape. close is []*float64
// so null entries (holiday/missing) decode to nil and can be skipped distinctly
// from a real 0.0 price (which stocks never have).
type yahooChartResponse struct {
	Chart struct {
		Result []struct {
			Timestamp []int64 `json:"timestamp"`
			Indicators struct {
				Quote []struct {
					Close []*float64 `json:"close"`
				} `json:"quote"`
			} `json:"indicators"`
		} `json:"result"`
	} `json:"chart"`
}

// FetchHistory fetches daily K-line history from Yahoo chart API.
// datalen is the number of bars requested (DAY 30 / MONTH 250 / YEAR 1200).
func (p *YahooProvider) FetchHistory(ctx context.Context, v PriceView, datalen int) ([]HistoryPoint, error) {
	sym := yahooSymbol(v.Symbol)
	period1 := time.Now().AddDate(0, 0, -datalen).Unix()
	period2 := time.Now().Unix()
	url := fmt.Sprintf("%s/v8/finance/chart/%s?period1=%d&period2=%d&interval=1d",
		p.baseURL, sym, period1, period2)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("yahoo history build request: %w", err)
	}
	// Yahoo chart API rejects requests without a browser-like User-Agent (HTTP 403).
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36")

	resp, err := p.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("yahoo history request: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound {
		return nil, ErrNoSource // symbol not in Yahoo → router falls through
	}
	if resp.StatusCode != http.StatusOK {
		// 403/429 (rate-limit) → real error; BackfillPriceHistory logs + skips.
		return nil, fmt.Errorf("yahoo history status %d", resp.StatusCode)
	}

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("yahoo history read body: %w", err)
	}
	var yc yahooChartResponse
	if err := json.Unmarshal(raw, &yc); err != nil {
		return nil, fmt.Errorf("yahoo history parse json: %w", err)
	}
	if len(yc.Chart.Result) == 0 {
		return nil, ErrNoSource // empty result → no data for this symbol
	}
	res := yc.Chart.Result[0]
	if len(res.Indicators.Quote) == 0 {
		return nil, fmt.Errorf("yahoo history: no quote indicators")
	}
	closes := res.Indicators.Quote[0].Close
	pts := make([]HistoryPoint, 0, len(res.Timestamp))
	for i, ts := range res.Timestamp {
		if i >= len(closes) || closes[i] == nil {
			continue // null close (holiday/missing) → skip
		}
		pts = append(pts, HistoryPoint{
			// UTC midnight: Yahoo timestamp is UTC sec; Truncate(24h) gives the
			// trading-day UTC date (US EST 9:30 open = 14:30 UTC, same calendar day).
			Date:       time.Unix(ts, 0).UTC().Truncate(24 * time.Hour),
			PriceCents: int64(math.Round(*closes[i] * 100)),
		})
	}
	return pts, nil
}

// yahooSymbol maps a security symbol to Yahoo's chart-API form: Yahoo uses
// '-' in place of '.' (BRK.B → BRK-B, BRK.A → BRK-A). Other symbols pass
// through unchanged.
func yahooSymbol(symbol string) string {
	return strings.ReplaceAll(strings.TrimSpace(symbol), ".", "-")
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd yucai/server && go test ./internal/holding/adapter/driven/priceprovider/ -run TestYahoo -count=1 -v`
Expected: PASS(ok 5 tests: parsesChart / nullCloseSkipped / 404NoSource / 403RealError / symbolConversion)。

- [ ] **Step 5: Commit**

```bash
git add yucai/server/internal/holding/adapter/driven/priceprovider/yahoo.go yucai/server/internal/holding/adapter/driven/priceprovider/yahoo_test.go
git commit -m "feat(holding/priceprovider): YahooProvider chart API 历史日 K(美股/非 A 股)"
```

---

### Task 2: HistoricalRouter(多源 history 路由)

**Files:**
- Create: `yucai/server/internal/holding/adapter/driven/priceprovider/history_router.go`
- Test: `yucai/server/internal/holding/adapter/driven/priceprovider/history_router_test.go`

**Interfaces:**
- Consumes: `HistoricalProvider` 接口([history.go:19](../../yucai/server/internal/holding/adapter/driven/priceprovider/history.go#L19))、`PriceView`、`HistoryPoint`、`ErrNoSource`。对齐 `CompositeRouter`([router.go:13](../../yucai/server/internal/holding/adapter/driven/priceprovider/router.go#L13))模式。
- Produces: `HistoricalRouter` struct + `NewHistoricalRouter(providers ...HistoricalProvider) *HistoricalRouter` + `FetchHistory`(implement `HistoricalProvider` 结构型)。Task 3 `provideHistoricalProvider` 用 `NewHistoricalRouter(NewSinaProvider(), NewYahooProvider())`。

- [ ] **Step 1: Write the failing test**

Create `history_router_test.go`(对齐 `provider_test.go` 的 `stubProbe` 模式):

```go
package priceprovider

import (
	"context"
	"errors"
	"testing"
	"time"
)

// historyProbe is a test HistoricalProvider returning a configured result,
// driving the router through all branches (ok / real-error / no-source).
type historyProbe struct {
	pts []HistoryPoint
	err error
}

func (p *historyProbe) FetchHistory(_ context.Context, _ PriceView, _ int) ([]HistoryPoint, error) {
	return p.pts, p.err
}

func TestHistoricalRouterReturnsFirstCovering(t *testing.T) {
	// First provider no-source (Sina for non-A-share), second covers (Yahoo).
	want := []HistoryPoint{{Date: time.Unix(1609459200, 0).UTC(), PriceCents: 12941}}
	r := NewHistoricalRouter(
		&historyProbe{err: ErrNoSource},
		&historyProbe{pts: want},
	)
	got, err := r.FetchHistory(context.Background(), PriceView{Symbol: "AAPL", Exchange: "NASDAQ"}, 30)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(got) != 1 || got[0].PriceCents != 12941 {
		t.Fatalf("got %v, want %v", got, want)
	}
}

func TestHistoricalRouterFallsThroughAllNoSource(t *testing.T) {
	// All no-source → router returns ErrNoSource.
	r := NewHistoricalRouter(&historyProbe{err: ErrNoSource}, &historyProbe{err: ErrNoSource})
	_, err := r.FetchHistory(context.Background(), PriceView{Symbol: "X"}, 30)
	if !errors.Is(err, ErrNoSource) {
		t.Fatalf("all-no-source router must return ErrNoSource; got %v", err)
	}
}

func TestHistoricalRouterPropagatesRealError(t *testing.T) {
	// A real (non ErrNoSource) error is propagated, not swallowed.
	wantErr := errors.New("yahoo timeout")
	r := NewHistoricalRouter(&historyProbe{err: ErrNoSource}, &historyProbe{err: wantErr})
	_, err := r.FetchHistory(context.Background(), PriceView{Symbol: "AAPL"}, 30)
	if !errors.Is(err, wantErr) {
		t.Fatalf("router must propagate real error; got %v want %v", err, wantErr)
	}
}

func TestHistoricalRouterRealErrorStopsSearch(t *testing.T) {
	// If an earlier provider returns a real error, later providers are not tried.
	called := false
	later := &recordingHistoryProbe{onCall: func() { called = true }, pts: []HistoryPoint{{PriceCents: 1}}}
	r := NewHistoricalRouter(&historyProbe{err: errors.New("boom")}, later)
	_, _ = r.FetchHistory(context.Background(), PriceView{}, 30)
	if called {
		t.Fatal("router must not try later provider after a real error")
	}
}

// recordingHistoryProbe records whether FetchHistory was called.
type recordingHistoryProbe struct {
	onCall func()
	pts    []HistoryPoint
}

func (p *recordingHistoryProbe) FetchHistory(_ context.Context, _ PriceView, _ int) ([]HistoryPoint, error) {
	if p.onCall != nil {
		p.onCall()
	}
	return p.pts, nil
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd yucai/server && go test ./internal/holding/adapter/driven/priceprovider/ -run TestHistoricalRouter -count=1 -v`
Expected: FAIL / 编译失败(`HistoricalRouter`/`NewHistoricalRouter` undefined)。

- [ ] **Step 3: Write minimal implementation**

Create `history_router.go`:

```go
package priceprovider

import (
	"context"
	"errors"
)

// HistoricalRouter routes FetchHistory to the first HistoricalProvider that
// covers the security. ErrNoSource from a provider means "try the next"; any
// other error is a real failure and propagates immediately (BackfillPriceHistory
// logs it and skips the security, but does not abort the batch). If every
// provider returns ErrNoSource, the router returns ErrNoSource.
//
// Mirrors CompositeRouter (FetchPrice routing). Ordered: SinaProvider
// (A-share SSE/SZSE + CSI300) → YahooProvider (non A-share fallback).
type HistoricalRouter struct {
	providers []HistoricalProvider
}

// NewHistoricalRouter builds a HistoricalRouter from an ordered provider list.
// Order matters: put specific providers (SinaProvider) before the broader
// fallback (YahooProvider).
func NewHistoricalRouter(providers ...HistoricalProvider) *HistoricalRouter {
	return &HistoricalRouter{providers: providers}
}

// FetchHistory implements HistoricalProvider (structural). Iterates providers
// in order; returns the first non-ErrNoSource result.
func (r *HistoricalRouter) FetchHistory(ctx context.Context, v PriceView, datalen int) ([]HistoryPoint, error) {
	for _, p := range r.providers {
		pts, err := p.FetchHistory(ctx, v, datalen)
		if err == nil {
			return pts, nil
		}
		if !errors.Is(err, ErrNoSource) {
			return nil, err // real error → propagate, stop search
		}
	}
	return nil, ErrNoSource // all providers no-source
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd yucai/server && go test ./internal/holding/adapter/driven/priceprovider/ -count=1 -v`
Expected: PASS(全部:Yahoo 5 + HistoricalRouter 4 + 现有 Sina/router/stub 测不破)。

- [ ] **Step 5: Commit**

```bash
git add yucai/server/internal/holding/adapter/driven/priceprovider/history_router.go yucai/server/internal/holding/adapter/driven/priceprovider/history_router_test.go
git commit -m "feat(holding/priceprovider): HistoricalRouter 多源 history 路由(对称 CompositeRouter)"
```

---

### Task 3: wire 注入(provideHistoricalProvider → HistoricalRouter)

**Files:**
- Modify: `yucai/server/wire/providers.go:642-644`(`provideHistoricalProvider`)
- Modify: `yucai/server/wire/wire_gen.go`(手改镜像,见 [[yucai-wire-handmaintained]])

**Interfaces:**
- Consumes: Task 1 `NewYahooProvider()`、Task 2 `NewHistoricalRouter(...)`、现有 `NewSinaProvider()`。
- Produces: `provideHistoricalProvider` 返回 `HistoricalRouter`(Sina→Yahoo),`Service.historicalProvider` 字段类型不变(`HistoricalProvider`)→ 零接口改动。

- [ ] **Step 1: Edit provideHistoricalProvider**

Modify `providers.go:638-644` —— 把:

```go
// provideHistoricalProvider builds the daily K-line history provider. The same
// SinaProvider that serves live A-share prices also implements HistoricalProvider
// (FetchHistory), so backfill reuses it. Wire injects it directly into the
// holding service (not via Router) — backfill wants A-share/CSI300 coverage only.
func provideHistoricalProvider() priceprovider.HistoricalProvider {
	return priceprovider.NewSinaProvider()
}
```

替换为:

```go
// provideHistoricalProvider builds the daily K-line history provider as a
// HistoricalRouter: SinaProvider first (A-share SSE/SZSE + CSI300), then
// YahooProvider fallback (US/OTC/global non-A-share). Wire injects the router
// into the holding service; BackfillPriceHistory calls FetchHistory which the
// router routes. ErrNoSource from Sina falls through to Yahoo.
func provideHistoricalProvider() priceprovider.HistoricalProvider {
	return priceprovider.NewHistoricalRouter(
		priceprovider.NewSinaProvider(),
		priceprovider.NewYahooProvider(),
	)
}
```

- [ ] **Step 2: Hand-edit wire_gen.go**

`wire_gen.go` 的 `InitializeApp` 内有 `provideHistoricalProvider()` 调用(注入 `holdingService`)。`provideHistoricalProvider` 签名/返回类型不变(仍 `priceprovider.HistoricalProvider`),所以 **wire_gen.go 的调用点不变**(`provideHistoricalProvider()` 仍调,返回类型仍 `HistoricalProvider`)。

**核查**:`grep -n "provideHistoricalProvider\|NewSinaProvider\|NewYahooProvider\|NewHistoricalRouter" yucai/server/wire/wire_gen.go`。
- 若 `wire_gen.go` 只调 `provideHistoricalProvider()`(不内联 NewSinaProvider)→ **零改动**(provider 内部组装在 providers.go,wire_gen 透传)。
- 若 `wire_gen.go` 内联了 `NewSinaProvider()`(wire 工具旧产物)→ 改为 `NewHistoricalRouter(NewSinaProvider(), NewYahooProvider())`(镜像 providers.go,声明顺序:NewSinaProvider/NewYahooProvider/NewHistoricalRouter 在 provideHistoricalProvider 前)。

按 [[yucai-wire-handmaintained]]:wire_gen.go 手改,不跑 wire CLI。

- [ ] **Step 3: Build + 全包测试**

Run: `cd yucai/server && go build ./... && go test ./internal/holding/... -count=1`
Expected: build 绿;holding 全包测试过(含 priceprovider Yahoo+Router 新测 + 现有 Sina/router/stub/application/service)。

- [ ] **Step 4: Commit**

```bash
git add yucai/server/wire/providers.go yucai/server/wire/wire_gen.go
git commit -m "feat(holding/wire): provideHistoricalProvider 注入 HistoricalRouter(Sina+Yahoo)"
```

---

### Task 4: 端到端验证(美股回填 + XIRR 区间不降级)

**Files:** 无新文件(验证)。

- [ ] **Step 1: server 全量测**

Run: `cd yucai/server && go test ./... -count=1`
Expected: PASS(holding 全包;account/debt/transaction_detail_page 预存 fail 跳过,非本任务引入)。

- [ ] **Step 2: 真实 Yahoo 连通性(手动/可选)**

启 dev 环境(podman `yucai-pg` + server `bin/server.exe`,见 memory `yucai-dev-env`):
1. 确保 DB 有一只美股 security(如 AAPL/NASDAQ/USD)—— 若无,`CreateSecurity` RPC 建一个。
2. 调 `BackfillPriceHistory` RPC(range=YEAR)→ 返回 `backfilled_count`。
3. 查 DB `security_price_history` 表:应有 AAPL ~1200 条日 K(USD cents)。
4. 调 `GetHoldingPerformance(holding_id=AAPL holding, range=YEAR)` → `range_annualized_pct` **非 nil**(区间 XIRR 不再降级,若该 holding 有 trade + 当前价)。

Expected: Yahoo 真实拉价成功 → price_history 落库 → 美股区间 XIRR 可算。若 Yahoo 限频(403/429),部分 security 跳过 + slog,重跑补。

> ⚠️ 真实 Yahoo 格式可能与 httptest mock 略有差异(对齐 B Task8 教训)。若真实响应解析失败,据 `yahoo history parse json` 错误日志调整 `yahooChartResponse` struct(Yahoo 偶有字段调整,如 `chart.error` 或 indicators 嵌套)。

- [ ] **Step 3: 回归 XIRR 现有测**

Run: `cd yucai/server && go test ./internal/holding/application/ -run "TestXIRR|TestQtyAtDate|TestPortfolioXIRR|TestHoldingXIRR|TestGetPortfolioPerformance" -count=1 -v`
Expected: PASS(XIRR 现有测不破;Yahoo 改动只影响 price_history 数据来源,XIRR 逻辑不变)。

- [ ] **Step 4: 更新 memory**

更新 memory `holding-asset-management-todo` 的 XIRR defer 段:美股/OTC price history 回填(Yahoo)**完成**;defer 剩 e2e Excel 真实数据 / TWR / XIRR 缓存。

---

## 实施顺序依赖图

```
Task 1 (YahooProvider) ──┐
                          ├─→ Task 3 (wire 注入) ─→ Task 4 (e2e 验证)
Task 2 (HistoricalRouter) ┘
```

Task 1/2 可并行(独立 provider/router)。Task 3 依赖 1+2(用 NewYahooProvider/NewHistoricalRouter)。Task 4 依赖 3(注入后端到端)。
