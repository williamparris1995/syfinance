# Holding 子项目 B · 价格自动 sync 设计

- **日期**: 2026-06-30
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: `holding-asset-management`
- **范围**: B 首批(价格 sync 管道:provider+scheduler+手动刷新+Flutter UX)+ 清 A 尾巴(ListHoldingTransactions)
- **上游全景设计**: [2026-06-28-holding-asset-management-design.md](2026-06-28-holding-asset-management-design.md) §5
- **复用模式**: [currency/exchangerate/](../../yucai/server/internal/currency/adapter/driven/exchangerate/) provider 三件套 + [currency/scheduler/](../../yucai/server/internal/currency/scheduler/) scheduler

## 1. 背景与目标

A 子项目(holding 基础 + 双写 + OD 原型 + Flutter 移植)已完成。A-flutter 三个端点 ⏳ 降级:ListHoldingTransactions / snapshot / goal。其中 **ListHoldingTransactions 后端已实现**([holding_handler.go:229](../../yucai/server/internal/holding/adapter/driving/grpc/holding_handler.go#L229) + [service.go:193](../../yucai/server/internal/holding/application/service.go#L193)),Flutter repository/bloc 也已接真调用([holding_repository_impl.dart:22](../../yucai/client/lib/holding/data/holding_repository_impl.dart#L22) + [holding_bloc.dart:113](../../yucai/client/lib/holding/presentation/bloc/holding_bloc.dart#L113)),但 bloc 注释仍标 ⏳ 过时。B 首批顺带清掉它。

B 核心目标:security 的 `current_price_cents` 能**自动(每日 scheduler)+ 手动(刷新按钮)**更新,provider 可插拔,UI 反映最新价 + last-updated。价格只更 current,**不碰 history/snapshot**(那是 C 子项目)。

**首批交付边界**(用户拍板):管道优先 + 1 个真实源(新浪 A 股)+ stub 兜底(显式"无源",不动旧价)+ scheduler(复用 currency)+ 手动刷新 RPC + Flutter 刷新 UX。schema 零改动。

## 2. 范围边界

| 在范围(B 首批) | 不在范围(C/D) |
|---|---|
| `current_price_cents` 更新(手动 + 每日自动) | 价格 history / snapshot 表(C) |
| provider 接口 + SinaProvider(新浪 A 股) + StubProvider(兜底) + Router | realized 收益统计 / 年化(C) |
| PriceScheduler(复用 currency scheduler 模式) | goal / budget / currency 关联(D) |
| `SyncPrices` RPC(手动触发)+ Flutter 刷新按钮 | Yahoo/美股等真实多源(后续可插拔) |
| last-updated UX(client 本地记录,不持久化) | per-security 持久化同步时间(过度设计) |
| 清 A 尾巴:ListHoldingTransactions 核实 + 过时注释 + 端到端验证 | — |

## 3. 架构总览

```
Flutter 持仓页                    server (Go, holding 模块)
┌─────────────────┐   SyncPrices RPC   ┌─────────────────────────────────┐
│ [↻ 刷新价格]     │ ──────────────────▶│ HoldingHandler.SyncPrices        │
│ 上次更新 14:32   │◀── count+synced_at │  → service.SyncPrices            │
└─────────────────┘                    │     遍历 securities              │
                                       │     Router.Route(exchange,type)  │
   每日自动(收盘后)                     │       ├─ SSE/SZSE → SinaProvider │
┌─────────────────┐  每 tick 门控        │       └─ 其他    → StubProvider │
│ PriceScheduler  │───────────────────▶│     UpdateSecurityPrice(cents)   │
│ 复用 currency   │                     │     best-effort,fail 不中断      │
└─────────────────┘                     └─────────────────────────────────┘
```

provider 在 **server 端**(统一 scheduler + 客户端不直连行情 API + symbol 映射集中),对齐 [currency/exchangerate/](../../yucai/server/internal/currency/adapter/driven/exchangerate/) 的 `Provider` + `FrankfurterProvider` + `MockProvider` 三件套。

## 4. 复用对照(currency → holding price)

| currency(已存在,参照) | holding price(B 新建) |
|---|---|
| `exchangerate.Provider`(FetchRate/FetchRates) | `priceprovider.Provider`(FetchPrice) |
| `FrankfurterProvider`(真实 HTTP) | `SinaProvider`(新浪 HTTP) |
| `MockProvider`(静态兜底) | `StubProvider`(显式无源) |
| `scheduler.Scheduler`(NewScheduler/Start/SyncNow) | `scheduler.Scheduler`(同模式,PriceSyncer) |
| `RateSyncer` 接口(SyncRates) | `PriceSyncer` 接口(SyncPrices) |
| `IntervalSource`(MinIntervalHours) | 复用同一 `IntervalSource` |
| scheduler_test(doSync/SyncNow/门控) | 同模式新写 |

## 5. server 改动

### 5.1 priceprovider 包(`holding/adapter/driven/priceprovider/`)

**provider.go** — 接口 + 视图:
```go
// PriceView 是 provider 取价所需的最小安全视图(不泄漏完整 Security 聚合)。
type PriceView struct {
    Symbol   string
    Exchange string
    Type     domain.SecurityType
}

// Provider 是行情数据源端口(对齐 exchangerate.Provider)。
type Provider interface {
    // FetchPrice 返回 security 最新价(cents)+ 数据源标识。
    // ErrNoSource 表示该 provider 不覆盖此 security(路由用)。
    FetchPrice(ctx context.Context, v PriceView) (priceCents int64, source string, err error)
}

var ErrNoSource = errors.New("price: no source for security")
```

**sina.go** — SinaProvider(新浪 A 股):
- 路由判定:`Exchange == "SSE" || Exchange == "SZSE"` → 覆盖,否则 `ErrNoSource`
- exchange→前缀映射:`SSE`→`sh`、`SZSE`→`sz`
- HTTP `GET http://hq.sinajs.cn/list={prefix}{symbol}`(net/http,带 timeout)
- **必须带 header** `Referer: https://finance.sina.com.cn`(否则 403)
- **响应是 GBK 编码**:用 `golang.org/x/text/encoding/simplifiedchinese.GBK.NewDecoder()` 解码
- 解析 `var hq_str_sh600519="名称",开,昨收,最新价(索引3),...;`,取索引 3 转 cents(`int64(price*100)`)
- 错误:HTTP 非 200 / 解析失败 / 空响应 → 包装返回(不 panic)

**stub.go** — StubProvider:
- 所有 security 返回 `ErrNoSource`(显式"无源",价格不动旧值,不伪造行情)

**router.go** — CompositeRouter:
- 持有 `[]Provider`(顺序:Sina, Stub)
- `Route(ctx, v)`:遍历 providers,第一个返回非 `ErrNoSource` 的结果胜出;全 `ErrNoSource` 则返回 `ErrNoSource`

### 5.2 application service(`holding/application/service.go`)

新增 `SyncPrices`:
```go
type SyncPricesResult struct {
    Synced int
    Failed int
}

// SyncPrices 遍历所有 security,经 Router 取价 → UpdateSecurityPrice。
// best-effort:单条失败计 Failed 不中断。tenantID="" 全局(首批价格是
// security 主数据,跨 tenant 共享,无 tenant 隔离)。
func (s *Service) SyncPrices(ctx context.Context) (SyncPricesResult, error)
```
- `ListSecurities`(全部,分页聚合)→ 逐条 `Router.FetchPrice` → `UpdateSecurityPrice`
- 实现 `PriceSyncer` 接口(`SyncPrices(ctx) (int, error)`,返回 synced count)供 scheduler 用

### 5.3 scheduler(`holding/scheduler/scheduler.go`)

照搬 [currency/scheduler/scheduler.go](../../yucai/server/internal/currency/scheduler/scheduler.go)(独立 scheduler 包,接口形状按需调整):
- `PriceSyncer` 接口 = `SyncPrices(ctx) (SyncPricesResult, error)`(**复用 §5.2 service 同签名**,scheduler 与 service 通过此接口解耦)
- `Scheduler` struct(syncer + IntervalSource + tick + log + lastSync)
- `NewScheduler(syncer PriceSyncer, src IntervalSource, tick time.Duration, log *slog.Logger)`
- `Start(ctx)`:立即 doSync → ticker 每 tick 检查 `MinIntervalHours` 门控 → doSync。errors logged 不退出
- `doSync`:调 `syncer.SyncPrices` → 日志 `result.Synced/result.Failed` → 更新 lastSync(currency 的 doSync 用 int count,此处用 result.Synced;返回 `result.Synced, err`)
- `SyncNow(ctx) (int, error)`:手动立即触发,返回 synced count
- tick = 1h(同 currency prod)

### 5.4 proto 改动(`proto/holding/v1/holding.proto`)

新增 1 个 RPC + 2 消息:
```proto
rpc SyncPrices(SyncPricesRequest) returns (SyncPricesResponse);

message SyncPricesRequest {}  // 首批刷全部 security
message SyncPricesResponse {
  int32 synced_count = 1;
  int32 failed_count = 2;
  google.protobuf.Timestamp synced_at = 3;
}
```
重生成:`cd yucai && make proto`(server buf) + `make gen-dart`(client,**protoc_plugin 25.0.0**,见 [[yucai-dev-env]])。

### 5.5 gRPC handler(`holding/adapter/driving/grpc/holding_handler.go`)

```go
func (h *HoldingHandler) SyncPrices(ctx, req) (*pb.SyncPricesResponse, error)
```
- 鉴权(getTenantID,首批不按 tenant 隔离但保留鉴权门)
- 调 `service.SyncPrices` → 映射 `Synced/Failed/synced_at(now)` → response

### 5.6 启动 + wire(`cmd/server/main.go` + `wire/`)

- main:go `priceScheduler.Start(ctx)`(紧邻 currency scheduler.Start)
- `wire/providers.go`:加 `providePriceRouter` / `providePriceScheduler`(注入 IntervalSource)
- **手改 `wire/wire_gen.go`**(见 [[yucai-wire-handmaintained]],wire 工具链坏,镜像 currency scheduler 行)
- 验证:`cd yucai/server && go build ./...` 绿

## 6. schema 改动

**零改动**。拍板点①:last-updated 不持久化。Security 表无 `updated_at`,首批不新增字段。理由:C 的 snapshot 会做更完整价格历史,B 阶段 per-security 持久化同步时间是过度设计。client 端在 `SyncPrices` 成功后本地记录时间戳显示。

## 7. Flutter 改动

### 7.1 proto stub 重生成
`cd yucai && make gen-dart` → `holding.pb.dart` 加 `SyncPricesRequest/Response` + client `syncPrices` 方法。

### 7.2 data + domain 层
- `holding_remote_ds.dart`:`syncPrices()` 调 stub.syncPrices,映射回 `SyncPricesResult`
- `holding_repository.dart`(抽象)+ `holding_repository_impl.dart`(实现):加 `syncPrices()` → `Either<Failure, SyncPricesResult>`

### 7.3 presentation 层
- `holding_event.dart`:加 `RefreshPricesRequested`
- `holding_state.dart`:`HoldingLoaded` 加 `DateTime? lastPriceSyncedAt`(client 本地,拍板点①)
- `holding_bloc.dart`:`_onRefreshPrices` — emit HoldingSubmitting → `repo.syncPrices()` → Right:更新 `lastPriceSyncedAt=now` + `add(LoadHoldingsRequested)`(重算 marketValue/pnl);Left:`HoldingError`
- **持仓页 UI**:刷新按钮(↻ icon)+ last-updated 显示(对齐 OD 原型 `design-output/holding/` holdings_page 刷新 UX:loading 态 + "上次更新 HH:mm")

### 7.4 清 A 尾巴(ListHoldingTransactions)
1. **核实**:[holding_bloc.dart:77-82](../../yucai/client/lib/holding/presentation/bloc/holding_bloc.dart#L77) 过时注释("⏳ 后端 B/C/D 未实现")→ 后端已实现。核实 `holding_remote_ds.dart` 的 `listHoldingTransactions` 方法体 + stub `ListTradesRequest` 字段对齐
2. **清过时注释**:bloc `_onLoadDetail` 注释改为"后端✅已实现,fail 仅作兜底降级"
3. **端到端验证**:server run + client run → 进持仓详情 → 确认交易历史显示真数据(非空态)
4. **保留** `isPendingBackend:true` 作 fail 兜底(不删,网络/后端异常时仍优雅降级)

## 8. 失败/降级策略

- **provider 层**:SinaProvider HTTP 超时/403/解析失败 → 包装 error;StubProvider → `ErrNoSource`
- **service.SyncPrices**:单条 fail 计 `Failed++` 不中断,日志带 `symbol + exchange + error`;**不覆写旧价**(fetch 失败时跳过 UpdateSecurityPrice)
- **scheduler.Start**:对齐 currency "errors logged but never exit loop",单轮 sync 全失败下轮仍重试
- **handler.SyncPrices**:返回 `failed_count`,client 可提示"N 支失败";整体不因部分失败报错
- **Flutter**:`syncPrices` Left → `HoldingError`(toast);Right → 重算 + 更新时间

## 9. 测试策略

### server
- **SinaProvider 单测**:httptest mock 新浪响应(GBK 编码构造)→ 验证解析 + exchange→prefix 映射(SSE→sh/SZSE→sz)+ 错误(403/超时/空响应/非 SSE 返回 ErrNoSource)
- **StubProvider 单测**:恒返回 ErrNoSource
- **Router 单测**:Sina 覆盖优先,全 ErrNoSource 透传
- **service.SyncPrices 单测**:mock repo + Router,验证 synced/failed 计数 + 失败不中断 + 旧价不动
- **scheduler 单测**:复用 [scheduler_test.go](../../yucai/server/internal/currency/scheduler/scheduler_test.go) 模式(doSync/SyncNow/MinIntervalHours 门控/ctx cancel)
- **handler.SyncPrices 单测**:mock service → 验证 response 映射

### Flutter
- **bloc `_onRefreshPrices` 单测**:mock repo.syncPrices → Right 触发 LoadHoldingsRequested + lastPriceSyncedAt;Left → HoldingError
- 现有 93 测试(domain6+data33+presentation54)不破坏

## 10. 前置清理(plan Task 0)

B 开工前清工作区(A 阶段遗留):
- **提交** `yucai/server/cmd/server/main.go`:A 收尾 seed 集中化(demo→test account),单独 commit
- **删除**:`design-output/holding/mock-data.task1.js.bak`、`styles.task1.css.bak`、`nul`(Windows `>nul` 误产物)、根目录 `goal-link-*` / `holding-detail-desktop-goalcard-fixed`(A-od 临时导出)

## 11. 决策记录(用户拍板)

| # | 决策 | 选定 |
|---|---|---|
| 首批边界 | 管道优先 / 完整多源 / 最小手动 | **管道优先 + 1 真实源** |
| ① last-updated | client 本地 / per-security 持久化 | **client 本地(schema 零改动)** |
| ② stub 兜底 | 固定价演示 / 显式无源不动旧价 | **显式无源,不动旧价** |
| ③ 路由键 | SecurityType / exchange | **exchange**(SSE→sh/SZSE→sz),symbol 纯代码无前缀 |
| ④ 新浪接口 | hq.sinajs.cn / qt.gtimg.cn | **hq.sinajs.cn**(A股/ETF/债) |
| ⑤ 前置清理 | 提交 main.go + 删垃圾 | **是** |

## 12. 新浪接口技术备忘

- URL:`http://hq.sinajs.cn/list={prefix}{symbol}`(HTTP;prefix=sh/sz)
- **必带** `Referer: https://finance.sina.com.cn`(缺则 403)
- **GBK 解码**:响应 `var hq_str_sh600519="贵州茅台",开,昨收,最新(索引3),高,低,...,日期,时间,...;`(分号结尾,字段逗号分隔)
- 取索引 3(最新价;盘中=现价,收盘后=收盘价)→ `int64(price * 100)` cents
- 覆盖:A 股(sh/sz)、ETF(sh510300/sh511010)、场内基金、交易所债
- 不覆盖(走 stub):美股(NASDAQ)、OTC 基金、SGE 黄金现货、期权(首批)

## 13. 实施顺序建议(供 writing-plans)

1. 前置清理(Task 0)
2. server provider 三件套 + Router + 单测(可独立验证)
3. server service.SyncPrices + 单测
4. server scheduler + 单测
5. proto SyncPrices + server buf 重生成 + handler + 单测
6. server wire 手改 + main 启动 + go build 绿
7. server 端到端:启动 → scheduler 自动 / 手动调 SyncPrices → DB 验证 current_price_cents 更新(茅台/300ETF/国债ETF)
8. Flutter stub 重生成(gen-dart)
9. Flutter data/domain syncPrices + bloc _onRefreshPrices + 单测
10. Flutter 持仓页刷新 UX(对齐 OD 原型)+ last-updated
11. 清 A 尾巴:核实 remote_ds + 清过时注释 + 端到端(持仓详情交易历史)
12. 全链路验证 + review
