# 美股/OTC price history 回填 · 设计 spec

- **日期**: 2026-07-12
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: `holding-asset-management`
- **范围**: 扩展 `HistoricalProvider` 覆盖美股/OTC(及所有非 A 股),Yahoo Finance 数据源 + 多源路由,解 holding 区间 XIRR 美股降级
- **上游**: [2026-07-12-xirr-design.md](2026-07-12-xirr-design.md) §7.4(美股区间 XIRR 降级)+ [2026-06-30-holding-snapshot-design.md](2026-06-30-holding-snapshot-design.md) §14(美股/OTC 不覆盖,首批无历史)

## 1. 背景

XIRR 修正(P0)完成后,美股 holding 的**区间 XIRR 仍降级 `—`**:C snapshot 的 `HistoricalProvider` 只有 `SinaProvider`(A股 SSE/SZSE + CSI300 新浪日 K),美股/OTC 走 `ErrNoSource` 跳过 → `price_history` 无美股数据 → XIRR `priceAtOrBefore` 返 `ok=false` → 区间降级(spec §7.4 / §14)。

全期 XIRR 不受影响(只要现金流 + 当前价,当前价从 `security.current_price` 有)。但区间 XIRR(近30日/12月/5年)对美股 holding 缺失。

本 spec 扩展 `HistoricalProvider` 加 Yahoo Finance 数据源(免费无 key,覆盖全球),Sina 不覆盖的 symbol fallback Yahoo,解美股区间 XIRR 降级。

## 2. 目标

美股/非 A 股 `price_history` 回填,使区间 XIRR 可算(Yahoo 回填成功时)。零 schema / proto / application 接口改动。

## 3. 范围边界

| 在范围 | 不在范围(defer) |
|---|---|
| `YahooProvider` implement `HistoricalProvider`(Yahoo chart API) | Yahoo 实时价(`FetchPrice`,B SyncPrices 仍 Sina;美股实时价 defer) |
| `HistoricalRouter` 多源 history 路由(Sina→Yahoo) | rate-limit sleep / retry 机制(YAGNI,重跑 RPC 补) |
| `provideHistoricalProvider` 注入 router(手改 wire) | Yahoo 限频自适应退避 |
| 美股/非 A 股 price_history 回填(BackfillPriceHistory 自动含美股) | 港股/全球特殊处理(Yahoo 按 symbol 统一查,无特例) |
| yahoo_test + history_router_test(httptest mock) | 真实 Yahoo 连通性 e2e(可选,对齐 B Task9 模式) |

**零改动**:ent schema(price_history 表已建)/ proto / client / application 接口(`BackfillPriceHistory` 签名不变,`Service.historicalProvider` 字段类型不变)。

## 4. 决策记录(brainstorm 拍板)

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | 数据源 | **Yahoo Finance**(chart API v8) | 免费无 key,覆盖广(美股/ETF/港股/全球),JSON 易解析;国内通常可访;best-effort 跳过对齐 Sina |
| 2 | 覆盖范围 | **Yahoo fallback 所有非 A 股**(Sina 先,Yahoo 后) | 最简(exchange 非 SSE/SZSE 都试 Yahoo)+ 最广;Yahoo 按 symbol 查不严格按 exchange;BackfillPriceHistory 遍历用户 DB 的 security,非 A 股都回填 |
| 3 | FetchHistory 路由架构 | **HistoricalRouter**(CompositeRouter for history) | 对称现有 `CompositeRouter`(FetchPrice 模式);application 零改(只换注入);YahooProvider 独立可测 |
| 4 | key/限流 | **无 key,UA 头避 403,不加 retry** | 个人用足够;403/429 best-effort 跳过+日志(对齐 Sina SyncPrices);重跑 RPC 补 |
| 5 | symbol 转换 | **`.` → `-`**(BRK.B → BRK-B) | Yahoo chart API 用 `-` 代 `.`;其他直传 |
| 6 | 时区 | **UTC timestamp → `Truncate(24h)`** | Yahoo timestamp 是 UTC sec;美股 EST 交易日 UTC date ≈ 当地日,XIRR day-count 精度够 |
| 7 | currency | **不碰**(原币 USD,落库用 `sec.CurrencyCode`) | YahooProvider 返 `HistoryPoint{Date, PriceCents}`;USD rate_history 已有 → XIRR 折算就绪 |

## 5. 架构与分层

**新增** `yucai/server/internal/holding/adapter/driven/priceprovider/`:
- `yahoo.go` —— `YahooProvider` implement `HistoricalProvider.FetchHistory`(Yahoo chart API,JSON 解析)
- `history_router.go` —— `HistoricalRouter`(多源 history,ErrNoSource 跳下一个,结构型 implement `HistoricalProvider`)

**修改**:
- `wire/providers.go` `provideHistoricalProvider`([:642](../../yucai/server/wire/providers.go#L642))—— 从 `NewSinaProvider()` 改 `NewHistoricalRouter(NewSinaProvider(), NewYahooProvider())`
- `wire/wire_gen.go` 手改镜像(见 [[yucai-wire-handmaintained]];声明 SinaProvider/YahooProvider/HistoricalRouter 在 `provideHistoricalProvider` 前)

**零改动**:
- `domain`(`HistoricalProvider` 接口不变,[:history.go:19](../../yucai/server/internal/holding/adapter/driven/priceprovider/history.go#L19))
- `application`(`BackfillPriceHistory` 调 `s.historicalProvider.FetchHistory`,字段类型不变)
- `proto` / `client` / ent schema

**数据流**:
```
BackfillPriceHistory(启动自动 / 手动 RPC)
  → historicalProvider.FetchHistory(view, datalen)   [现 = HistoricalRouter]
    → SinaProvider.FetchHistory(SSE/SZSE/CSI300 → 返;其他 ErrNoSource)
    → YahooProvider.FetchHistory(Yahoo chart API → 返;404 ErrNoSource;403/429 error)
  → price_history 落库(原币 USD cents,CurrencyCode=sec.CurrencyCode)
  → XIRR priceAtOrBefore 读到 → 美股区间 XIRR 不再降级
```

**依赖注入**:`HistoricalRouter` 结构型 implement `HistoricalProvider`(`FetchHistory` 方法签名一致),`Service.historicalProvider` 字段类型不变 → wire 只改 `provideHistoricalProvider` 一处注入,零接口改动。

## 6. YahooProvider 实现

### 6.1 Yahoo chart API

```
GET https://query1.finance.yahoo.com/v8/finance/chart/{yahooSymbol}
    ?period1={unixSec start}&period2={unixSec end}&interval=1d
Header: User-Agent: Mozilla/5.0 ... (避 403)
```

- `datalen`(DAY 30 / MONTH 250 / YEAR 1200)→ `period1 = now.AddDate(0,0,-datalen).Unix()`, `period2 = now.Unix()`
- 响应 JSON:`chart.result[0].timestamp[]` + `chart.result[0].indicators.quote[0].close[]`(平行数组,close 可 null)

### 6.2 YahooProvider 结构(对齐 SinaProvider)

```go
type YahooProvider struct {
    baseURL string        // "https://query1.finance.yahoo.com"
    client  *http.Client  // 10s timeout
}
func NewYahooProvider() *YahooProvider { /* ... */ }
func newYahooProviderWithURL(baseURL string) *YahooProvider { /* httptest seam */ }

func (p *YahooProvider) FetchHistory(ctx context.Context, v PriceView, datalen int) ([]HistoryPoint, error) {
    sym := yahooSymbol(v.Symbol)                       // BRK.B → BRK-B
    period1 := time.Now().AddDate(0, 0, -datalen).Unix()
    period2 := time.Now().Unix()
    url := p.baseURL + "/v8/finance/chart/" + sym +
        "?period1=" + strconv.FormatInt(period1, 10) +
        "&period2=" + strconv.FormatInt(period2, 10) + "&interval=1d"
    // GET + User-Agent header
    // HTTP 404 → ErrNoSource(symbol Yahoo 无)
    // HTTP 403/429 → fmt.Errorf("yahoo history status %d", code)  // best-effort 跳过+日志
    // 非 200 → error
    // 解析 chart.result[0].timestamp[i] + indicators.quote[0].close[i]
    //   close[i] == null → skip
    //   HistoryPoint{Date: time.Unix(ts,0).UTC().Truncate(24h), PriceCents: round(close*100)}
}

// yahooSymbol:Yahoo chart API 用 '-' 代 '.'(BRK.B → BRK-B)。其他直传。
func yahooSymbol(symbol string) string {
    return strings.ReplaceAll(strings.TrimSpace(symbol), ".", "-")
}
```

### 6.3 时区与 currency

- **时区**:`timestamp` 是 UTC sec → `time.Unix(ts,0).UTC().Truncate(24h)` = 交易日 UTC date。美股 EST 交易日(9:30 EST = 14:30 UTC,同日)→ UTC date ≈ EST 交易日 date,与 A 股 Sina(当地日 `YYYY-MM-DD`)一致粒度,XIRR day-count 精度够。
- **currency**:YahooProvider 不碰 currency(返 `HistoryPoint{Date, PriceCents}` 原币 USD 价);`BackfillPriceHistory` 落库时用 `sec.CurrencyCode`(USD)填 `SecurityPriceHistory.CurrencyCode`。USD `rate_history` 已有(D-currency)→ XIRR 区间折算就绪。

### 6.4 限流/封处理(无 key)

- UA 头避 403;无 Referer 需要(Yahoo chart 不强制)
- **403/429**(transient)→ 返 error → `BackfillPriceHistory` 跳过该 security + slog(对齐 Sina SyncPrices best-effort,不中断 batch)
- **404**(symbol 不存在)→ `ErrNoSource`(Yahoo 无此 symbol,router 无下一源 → 跳过无日志)
- 不加 rate-limit sleep / retry(首批 YAGNI;用户可重跑 `BackfillPriceHistory` RPC 补跳过的)

## 7. 触发 + 回填 + wire

### 7.1 application 零改动

`BackfillPriceHistory`([service.go:587](../../yucai/server/internal/holding/application/service.go#L587))调 `s.historicalProvider.FetchHistory` —— 字段类型 `HistoricalProvider` 不变,只是注入的实现从单 SinaProvider 换成 HistoricalRouter。美股 security 不再 `ErrNoSource` 跳过,真回填。

### 7.2 触发不变

- 启动时(`main.go` 异步 goroutine,不阻塞启动)若 `price_history` 为空 → 自动 `BackfillPriceHistory`(现含美股,spec §5.5)
- 手动 `BackfillPriceHistory` RPC(调试/补数据)

### 7.3 wire(手改)

- `providers.go` `provideHistoricalProvider`:从 `NewSinaProvider()` 改 `NewHistoricalRouter(NewSinaProvider(), NewYahooProvider())`
- `wire_gen.go` 手改镜像:`NewSinaProvider()` / `NewYahooProvider()` / `NewHistoricalRouter(...)` 声明在 `provideHistoricalProvider` 之前(消费方在依赖方后,见 [[yucai-wire-handmaintained]])
- `Service.historicalProvider` 字段类型不变 → 零接口改动

## 8. 降级矩阵

| 场景 | 处理 | XIRR 影响 |
|---|---|---|
| A 股(SSE/SZSE/CSI300) | Sina 返,router 用 Sina | 不变 |
| 美股/非 A 股 | Sina `ErrNoSource` → Yahoo 返 | 区间 XIRR 可算 ✅ |
| Yahoo 无 symbol(HTTP 404) | Yahoo `ErrNoSource` → router `ErrNoSource` → Backfill 跳过(无日志) | 区间 `—`(全期不受影响) |
| Yahoo 限频(403/429) | Yahoo error → Backfill 跳过 + slog(不中断 batch) | 区间 `—`(全期不受影响) |
| Yahoo 回填失败(price_history 仍空) | XIRR `priceAtOrBefore` 返 `ok=false` → 区间降级 | 区间 `—`(全期不受影响) |

**关键**:全期 XIRR 始终不受影响。区间 XIRR 从"美股必降级"变"美股可算(Yahoo 回填成功时)"。

## 9. 测试策略(全程 TDD,对齐 B/C 模式)

### `yahoo_test.go`(httptest mock chart JSON,对齐 `sina_test.go`)
- **正常**:mock chart 响应(timestamp+close 平行数组)→ `HistoryPoint` 对(含 null close skip、UTC date `Truncate(24h)`)
- **404** → `ErrNoSource`
- **403/429** → error(非 `ErrNoSource`)
- **symbol 转换**:请求 URL 含 `BRK-B`(`BRK.B` 输入)
- **空响应/格式错** → error

### `history_router_test.go`(对齐 `router_test.go` `TestRouterReturnsFirstCovering`)
- Sina 返 → 用 Sina(不调 Yahoo)
- Sina `ErrNoSource` → 调 Yahoo → Yahoo 返
- 都 `ErrNoSource` → router `ErrNoSource`
- Sina 真 error(非 ErrNoSource)→ 立即传播(不调 Yahoo)

### 集成(可选,对齐 B Task9 端到端 count)
- `BackfillPriceHistory` 美股 security → `price_history` 落库(Yahoo mock 或真实连通性)

### 回归
- `go build ./...` 绿 + `go test ./internal/holding/...` 全过
- XIRR 现有测试不破(`TestXIRR*` / `TestQtyAtDate*` / `TestPortfolioXIRR*` 等)

## 10. 风险清单(plan 需显式处理)

1. **Yahoo 限频/封**(403/429)→ best-effort 跳过 + 日志;重跑 RPC 补。无 retry(YAGNI)。
2. **Yahoo chart API 格式变更**(v8 偶有调整)→ httptest mock 锁定当前格式;真实连通性 e2e 确认(对齐 B Task8 "真实格式可能与 mock 不同"教训)。
3. **symbol 转换不全**(`.`→`-` 只覆盖 BRK.B/A 类;其他特殊 symbol 如含 `/`?)→ 首批只 `.`→`-`,遇其他在 e2e 补。
4. **时区精度**(UTC date vs EST 交易日)→ `Truncate(24h)` 一致;XIRR day-count 误差 < 1 天,可接受(对齐 XIRR actual/365)。
5. **wire 手改**(provideHistoricalProvider 注入换 HistoricalRouter)→ 镜像现有 provider 声明顺序,go build 验证(见 [[yucai-wire-handmaintained]])。
6. **国内访问 Yahoo**(query1.finance.yahoo.com 国内通常可访但偶慢)→ 10s timeout + best-effort;若长期不可访,后续可加 stooq fallback(本 spec 不含)。

## 11. 实施顺序建议(供 writing-plans,约 4 task)

```
Task 1  YahooProvider:yahoo.go + yahoo_test.go(httptest mock chart,TDD)
Task 2  HistoricalRouter:history_router.go + history_router_test.go(TDD,对齐 CompositeRouter)
Task 3  wire:provideHistoricalProvider 改 HistoricalRouter(Sina+Yahoo)+ wire_gen 手改;go build 绿
Task 4  端到端:BackfillPriceHistory 美股 security 回填 price_history(真实 Yahoo 连通性 / mock)+ XIRR 区间不降级验证
```

## 12. 参考

- 上游 XIRR spec:[2026-07-12-xirr-design.md](2026-07-12-xirr-design.md) §7.4(美股区间降级)/ §14(price_history 回填)
- C snapshot spec:[2026-06-30-holding-snapshot-design.md](2026-06-30-holding-snapshot-design.md) §14(美股/OTC 不覆盖)
- 现状代码:[sina.go FetchHistory](../../yucai/server/internal/holding/adapter/driven/priceprovider/sina.go#L152) / [history.go HistoricalProvider](../../yucai/server/internal/holding/adapter/driven/priceprovider/history.go#L19) / [router.go CompositeRouter](../../yucai/server/internal/holding/adapter/driven/priceprovider/router.go) / [service.go BackfillPriceHistory](../../yucai/server/internal/holding/application/service.go#L587)
- memory:[[holding-asset-management-todo]](XIRR defer 美股历史价)/ [[yucai-wire-handmaintained]](wire 手改)/ [[yucai-dev-env]]
