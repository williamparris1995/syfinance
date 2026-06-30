# Holding 子项目 C · 收益 snapshot 设计

- **日期**: 2026-06-30
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: `holding-asset-management`
- **范围**: C 完整(收益统计:时序 snapshot + FIFO realized + 收益曲线 + 年化 + CSI300 基准 + Flutter 接真)
- **上游全景设计**: [2026-06-28-holding-asset-management-design.md](2026-06-28-holding-asset-management-design.md) §6
- **前置**: A(server 双写 + OD 原型 + Flutter 移植)+ B(价格 sync)已完成
- **复用模式**: [holding/scheduler/](../../yucai/server/internal/holding/scheduler/) scheduler 骨架(B)+ [priceprovider/](../../yucai/server/internal/holding/adapter/driven/priceprovider/) provider 三件套(B)+ [perf_curve_chart.dart](../../yucai/client/lib/holding/presentation/widgets/perf_curve_chart.dart) 已定型 widget

## 1. 背景与目标

A-flutter 有 6 个 ⏳C 降级点(组合曲线 / 详情曲线 / realized 分解 / 年化 / 基准 / 详情 realized 近似),后端无任何时序数据。C 是御财**第一个引入时序快照**的模块(server 全仓无 snapshot/price_history/balance_history 先例)。

C 核心目标:security 价格 + holding 市值**每日定时落库时序**,server 端算好**收益曲线(组合/单标的,日/月/年)+ FIFO 精确 realized + 年化 + CSI300 基准**,通过 RPC 一次返回,Flutter 把 6 个 ⏳C 点接真数据。

**现状关键发现**:
- `ApplySell`([entity.go:76](../../yucai/server/internal/holding/domain/entity.go))已算 realized(移动加权)但 [service.go:111](../../yucai/server/internal/holding/application/service.go) 丢弃不落库
- market_value/unrealized 仅即时算([dto.go:114](../../yucai/server/internal/holding/application/dto.go)),不记历史
- proto 完全无 snapshot/curve/performance RPC
- [currency.go:29](../../yucai/server/internal/currency/ent/schema/currency.go) 只有单点 `exchange_rate`,无 rate history
- `holding.created_at` ent 已存([holding.go](../../yucai/server/internal/holding/ent/schema/holding.go) Immutable),proto HoldingDTO 未暴露 → 年化 server 端算,不改 DTO
- 基准 CSI300(sh000300)可走 [SinaProvider](../../yucai/server/internal/holding/adapter/driven/priceprovider/sina.go)(只判 exchange 不判 type),零改动

## 2. 范围边界

| 在范围(C 完整) | 不在范围(D / 后续) |
|---|---|
| 4 张时序表(security_price_history / holding_snapshot / holding_lots / currency_rate_history) | budget 关联(D) |
| FIFO 精确 realized(lot 队列)+ 落 trade | holding ↔ goal 关联(D) |
| 收益曲线 RPC(组合 CNY + 单标的原币,日/月/年) | 完整多币种 rate 折算可视化(D,但 rate_history 已建,折算逻辑 C 内含) |
| 年化(基于 holding created_at 持仓时长) | 其他基准标的(首批固定 CSI300) |
| CSI300 基准(SinaProvider 复用) | Yahoo/美股历史 K 线(首批新浪 A 股 + CSI300) |
| price_history 回填(新浪日 K)+ snapshot 从上线累积 | snapshot 全量逐日回算(明确不做,见决策⑤) |
| Flutter 6 个 ⏳C 点接真 + 新建 PerformanceBloc | — |

## 3. 架构总览

```
                         ┌─ 时序写入(复用现有 scheduler,各写各的)────────────────┐
                         │                                                          │
  hq.sinajs.cn 实时价 ──▶ │ B SyncPrices ──▶ security.current_price                 │
                         │                   + security_price_history(新,当日点)    │
                         │ currency SyncRates ─▶ currency.exchange_rate             │
                         │                       + currency_rate_history(新,当日点) │
                         │ SnapshotScheduler(新) ─▶ holding_snapshot(新)            │ 每日各 active holding:
                         │                          = qty×当日price(原币)           │   当日 qty×当日价(原币)
                         └──────────────────────────────────────────────────────────┘

  买入/卖出/拆分(A 双写)──▶ holding_lots(新,FIFO lot 队列)
                             + holding_transaction.realized_pnl_cents(新列,sell 填 FIFO)

  Flutter performance_page ──GetPortfolioPerformance──▶ server:
       组合曲线/基准/realized/年化       Σ holding_snapshot(原币)× rate_history → CNY,日/月/年采样
                                       + 跨持仓 Σ realized + 年化(holding created_at)
  Flutter holding_detail ──GetHoldingPerformance──▶ security_price_history(原币) + 该持仓 realized
```

**复用对照(B → C)**:

| B(已存在) | C(新建/扩展) |
|---|---|
| `priceprovider.Provider` (FetchPrice) | 加 `HistoricalProvider.FetchHistory(ctx, v, range)`(新浪日 K,回填用) |
| `SinaProvider`(实时 hq.sinajs.cn) | 兼拉 CSI300(sh000300);新增 `FetchHistory` 日 K |
| `holding/scheduler` PriceScheduler | 新增 `SnapshotScheduler`(同骨架,写 holding_snapshot) |
| `currency/scheduler` SyncRates | 扩展:刷新 rate 时顺手写 `currency_rate_history` |
| `ApplySell` 移动加权 | **重写 FIFO**(消耗 holding_lots)+ realized 落 trade |

**两个跨模块点**:
1. currency 模块加 `currency_rate_history` 表 + SyncRates 写历史(C 读它折算)。表归 currency,职责正确。
2. 基准 CSI300 作为一个特殊 security(symbol=`000300`, exchange=`SSE`, type=`INDEX`)seed 进 security 表,复用 price_history 存指数时序 —— 不引入独立"指数"概念。

**排除**:不在 client 算曲线聚合(FIFO/跨持仓Σ/折算都放 server);不做 snapshot 全量逐日回填(决策⑤)。

## 4. Schema(4 新表 + 1 新列)

所有金额 `int64` cents,日期 `time.Time`,数量 `float64`(对齐 entity.Quantity)。

### ① security_price_history(holding 模块,无 tenant — 价格是全局主数据)
| 字段 | 说明 |
|---|---|
| id (uuid) | |
| security_id (uuid) | 关联 security(含基准 000300) |
| price_date (time) | 每日 1 条 |
| price_cents (int64) | 当日收盘价(原币) |
| currency_code (string) | 冗余,折算用 |
| source (string) | `sina` / `backfill` / `manual` |
| created_at | |
| **UNIQUE**(security_id, price_date) + INDEX(security_id, price_date) | 防 scheduler 重复写 |

### ② holding_snapshot(holding 模块,TenantMixin)
| 字段 | 说明 |
|---|---|
| id, tenant_id | |
| holding_id, security_id, account_id (uuid) | 关联 + 冗余(按 security/account 聚合) |
| snapshot_date (time) | 每日 1 条 per holding |
| market_value_cents (int64) | 当日市值(qty×当日价,原币) |
| unrealized_pnl_cents (int64) | 当日浮动盈亏(原币) |
| currency_code (string) | 原币种(折算用) |
| created_at | |
| **UNIQUE**(tenant_id, holding_id, snapshot_date) + INDEX(tenant_id, snapshot_date)、INDEX(tenant_id, security_id, snapshot_date) | |

组合曲线某日 CNY = Σ_holding `market_value × rate_history(currency→CNY, 当日)`。不存 quantity/avg_cost(YAGNI,曲线只要市值)。

### ③ holding_lots(holding 模块,TenantMixin — FIFO)
| 字段 | 说明 |
|---|---|
| id, tenant_id | |
| holding_id, security_id (uuid) | |
| acquired_date (time) | 买入日(从 trade_date) |
| acquired_trade_id (uuid) | 创建 lot 的 buy trade(holding_transaction.id) |
| price_cents (int64) | 买入成本价 |
| quantity (float) | 原始量 |
| remaining_quantity (float) | 剩余(sell 消耗、split 按 ratio 调整) |
| created_at | |
| INDEX(tenant_id, holding_id, acquired_date) | FIFO 按日期升序消耗 |

`remaining=0` 的 lot 保留(审计/历史 realized 可溯)。

### ④ currency_rate_history(currency 模块,无 tenant — 跨模块小改)
| 字段 | 说明 |
|---|---|
| id (uuid) | |
| currency_code (string) | ISO 4217(CNY=base=1.0) |
| rate_date (time) | 每日 1 条 |
| exchange_rate (float) | to base(CNY) |
| created_at | |
| **UNIQUE**(currency_code, rate_date) | |

### ⑤ holding_transaction 加 1 列
`realized_pnl_cents` (int64, Optional, Default 0) — 仅 sell trade 填 FIFO 实现收益,其他类型 0。

## 5. server 改动

### 5.1 domain(entity.go + repository.go)

- 新聚合 `HoldingLot`(字段同 §4③)+ 实体 `SecurityPriceHistory` / `HoldingSnapshot`
- **重写 `ApplySell` 为 FIFO 纯函数**:`ApplySellFIFO(sellQty, sellPriceCents, feeCents, openLots) → (realized int64, consumed []LotConsumption, err)`,按 `acquired_date` 升序消耗 `remaining_quantity`
- **`ApplyBuy` 创建 lot**(整个买入量 = 1 个新 lot);**`RecordSplit` 按 ratio 调整所有 open lot 的 quantity+remaining**(成本价不变)
- **`AvgCostCents` 改为从 open lots 派生**(Σ lot.remaining×lot.price / Σ remaining)—— 与 FIFO 一致,消除移动加权/FIFO 两套成本
- ⚠️ 改动 A 已实现的 entity 成本逻辑(A 双写金额 = price×qty 不依赖 avgCost,不受影响,但需回归 A 的 6 domain 测)

**新 repository 接口**(独立,职责单一):
- `SnapshotRepository`:`FindSnapshots(tenantID, from, to, accountID*, securityID*)` + `Save`
- `LotRepository`:`FindByHolding(holdingID)`(按 acquired_date 升序)+ `Save` + `UpdateRemaining` + `SaveAll`(事务批量)
- `PriceHistoryRepository`:`FindBySecurity(securityID, from, to)` + `Save` + `Exists(securityID)`(回填门控)
- `RateHistoryRepository`(currency 模块):`FindRate(currencyCode, date)`(向前填充最近可用)+ `FindRange(code, from, to)` + `Save`

### 5.2 application(service.go)

| 方法 | 职责 |
|---|---|
| `SnapshotHoldings(ctx)` | 每日:遍历 active holding,算 market_value+unrealized,写 holding_snapshot(实现 `Snapshotter` 接口供 scheduler) |
| `BackfillPriceHistory(ctx, range)` | 一次性:调 `HistoricalProvider.FetchHistory` 拉日 K → 写 security_price_history |
| `GetPortfolioPerformance(ctx, tenant, range, withBenchmark)` | 组合曲线:Σ holding_snapshot(原币)× rate_history → CNY,日/月/年采样;带基准时同查 CSI300 price_history;+ 跨持仓 Σ realized + 年化 |
| `GetHoldingPerformance(ctx, holdingID, range)` | 单标的曲线:security_price_history(原币)+ 该持仓 FIFO realized |

(realized/年化由 `GetPortfolioPerformance` 统一返回组合级数据,无独立 RPC;组合年化基于最早 holding `created_at` 即组合起始时间,具体算法 plan 定)

`BuyHolding`/`SellHolding`/`RecordSplit` 在现有 A 双写后追加 lot 维护(LotRepository,事务内)。

### 5.3 scheduler — 时序写入分工(关键复用,不新建多 scheduler)

| 时序表 | 写入者(复用) |
|---|---|
| `security_price_history` | **B `SyncPrices`**(已每日拉价)更新 current_price 后顺手 insert 当日点 |
| `currency_rate_history` | **currency `SyncRates`**(已每日)刷新 exchange_rate 后顺手 insert 当日点 |
| `holding_snapshot` | **新增 `SnapshotScheduler`**(照搬 B 骨架:Snapshotter 接口 + IntervalSource 门控 + 1h tick + 24h interval) |

### 5.4 priceprovider — 加历史 K 线

- `SinaProvider` 已能拉基准 CSI300(`sh000300` 走 hq.sinajs.cn)—— 基准实时价零改动
- **新增 `HistoricalProvider` 接口**:`FetchHistory(ctx, v, range) ([]HistoryPoint, err)`,仅 `SinaProvider` 实现(新浪日 K `CN_MarketDataService.getKLineData`,见 §14)。Router 不路由历史,回填直接用 Sina。StubProvider 无历史(ErrNoSource)

### 5.5 回填触发

启动时(`main.go`,**异步 goroutine 不阻塞启动**)检测 `security_price_history` 为空 → 自动调 `BackfillPriceHistory`(A股 holding securities + CSI300);非空跳过(幂等)。另暴露手动 `BackfillPriceHistory` RPC(调试/补数据)。

### 5.6 wire + main

- providers.go:新 4 repo + `SnapshotScheduler` + backfill 入口
- **手改 `wire/wire_gen.go`**(见 [[yucai-wire-handmaintained]],镜像 B 的 SnapshotScheduler 行)
- main.go:`go SnapshotScheduler.Start(ctx)` + 启动时一次性 backfill(若空)
- 验证:`cd yucai/server && go build ./...` 绿 + `go test ./...` 全过

## 6. proto 改动(`proto/holding/v1/holding.proto`)

2 主 RPC + 1 可选,共享 enum/message:

```proto
enum CurveRange {
  CURVE_RANGE_UNSPECIFIED = 0;
  CURVE_RANGE_DAY = 1;    // 近 30 日(逐日)
  CURVE_RANGE_MONTH = 2;  // 近 12 月(逐月)
  CURVE_RANGE_YEAR = 3;   // 近 5 年(逐年)
}

message CurvePoint {
  google.protobuf.Timestamp time = 1;
  double value = 2;   // 组合=CNY 市值(元);单标的=原币价(元);基准=指数点位
}

// RPC 1:performance_page 一次取组合曲线+基准+realized+年化
rpc GetPortfolioPerformance(GetPortfolioPerformanceRequest) returns (PortfolioPerformanceResponse);
message GetPortfolioPerformanceRequest {
  string account_id = 1;         // optional 筛选(空=全组合)
  CurveRange range = 2;
  bool include_benchmark = 3;
}
message PortfolioPerformanceResponse {
  repeated CurvePoint portfolio_points = 1;  // 组合 CNY 总市值时序
  repeated CurvePoint benchmark_points = 2;  // CSI300(optional)
  string benchmark_name = 3;
  int64 realized_cents = 4;
  int64 unrealized_cents = 5;
  int64 total_cents = 6;
  double annualized_pct = 7;    // 年化 %(server 算,holding created_at)
  double total_pct = 8;         // 累计 %
  string currency = 9;          // CNY
}

// RPC 2:holding_detail_page 单标的曲线 + 该持仓 realized
rpc GetHoldingPerformance(GetHoldingPerformanceRequest) returns (HoldingPerformanceResponse);
message GetHoldingPerformanceRequest {
  string holding_id = 1;
  CurveRange range = 2;
}
message HoldingPerformanceResponse {
  repeated CurvePoint price_points = 1;  // 单标的原币价时序
  int64 realized_cents = 2;
  int64 unrealized_cents = 3;
  int64 total_cents = 4;
  string currency = 5;                   // 原币
}

// RPC 3(可选):手动回填
rpc BackfillPriceHistory(BackfillPriceHistoryRequest) returns (BackfillPriceHistoryResponse);
message BackfillPriceHistoryRequest { CurveRange range = 1; }
message BackfillPriceHistoryResponse { int32 backfilled_count = 1; }
```

**要点**:
- 年化 server 端算(holding.created_at),**不改 HoldingDTO**
- CurvePoint.value 用 double(元/点位,对齐 A-od mock + Flutter PerfPoint.double);foot realized/unrealized/total 用 int64 cents(精确金额)
- 重生成:`cd yucai/proto && buf generate --template buf.gen.go.yaml`(Go)+ `bash gen-dart.sh`(Dart,**protoc_plugin 25.0.0**,见 [[yucai-dev-env]])

## 7. Flutter 改动

### 7.1 6 个 ⏳C 点映射

| # | 位置(文件:行) | C 后数据源 | 改动 |
|---|---|---|---|
| ① | performance_page 总收益曲线 `:227` | `GetPortfolioPerformance.portfolio_points` | 替换 `const []` → 真点 |
| ② | holding_detail 详情曲线 `:445` | `GetHoldingPerformance.price_points` | 替换 `_costBasisCurve`(trades 重建)→ 真行情 |
| ③ | performance realized 分解 `:381` | `GetPortfolioPerformance.realized_cents` | 替换「⏳C 待后端」→ 真 realized |
| ④ | performance 年化 `:468` | `GetPortfolioPerformance.annualized_pct` | 替换 `'⏳'` → 真% |
| ⑤ | performance 基准 `:456` | `GetPortfolioPerformance.benchmark_points` | 替换 mock → 真 CSI300 |
| ⑥ | holding_detail realized `:464` | `GetHoldingPerformance.realized_cents` | 替换前端 Σ sell+dividend 近似 → server FIFO |

### 7.2 bloc 架构(新建 + 扩展)
- **新建 `PerformanceBloc`**(performance 页,职责分离):
  - event `LoadPortfolioPerformanceRequested(range, accountId?)`,range 切换重发
  - state `PerformanceLoading/Loaded/Error`,`Loaded` 带 portfolioPoints/benchmarkPoints/benchmarkName/foot/annualizedPct/totalPct
- **扩展 `HoldingBloc`**(详情页曲线):
  - 新子 event `LoadHoldingCurveRequested(holdingId, range)`(range 切换只更曲线,不重拉 holding/trades)
  - `HoldingDetailLoaded` 加字段 `holdingCurve: List<PerfPoint>?` + `holdingCurveFoot: PerfCurveFoot?`

### 7.3 各层改动
| 层 | 改动 |
|---|---|
| **data** | `holding_remote_ds` 加 `getPortfolioPerformance` / `getHoldingPerformance`(+ 可选 `backfillPriceHistory`)调 stub;repository 抽象+impl 加 `Either<Failure, ...>` |
| **domain** | 新 entity `PortfolioPerformance` / `HoldingPerformance`(points + foot + 年化);presentation mapper 映射到现有 `PerfPoint`/`PerfCurveFoot`(widget 契约不变) |
| **presentation** | performance_page 接 PerformanceBloc 填 ①③④⑤;holding_detail_page 接 HoldingBloc 新字段填 ②⑥(删 `_costBasisCurve`/`_realizedFromTrades` 近似);`perf_curve_chart.dart` **零改动** |
| **DI/路由** | `PerformanceBloc` @injectable 注册 + build_runner;performance_page `BlocProvider<PerformanceBloc>` |

### 7.4 失败降级(沿用 A-flutter `isPendingBackend` 局部降级惯例)
- 曲线 RPC fail → 保留页面其他区,仅曲线区空态(非整页)
- 年化/realized fail → 该格 `'—'`
- 点数 < 2 → `perf_curve_chart` 现有空态(`:125`,不伪造)

## 8. 失败/降级策略(server)

| 场景 | 处理 |
|---|---|
| `FetchHistory`(回填)HTTP 失败 | 该 security 跳过 + 日志,best-effort(对齐 B SyncPrices) |
| snapshot 写入(某 holding price 缺失) | 跳过该 holding + 日志,不中断 |
| 曲线点数不足 | 返回实际点数,client `<2 → 空态` |
| FIFO sell 量 > open lots remaining | error,不写负 remaining(超卖防御,A SellHolding 已校验,双层) |
| 某日 rate_history 缺失(节假日) | 向前填充最近可用 rate + 日志 |
| 回填启动触发 | 空表才触发,非空跳过(幂等) |

## 9. 测试策略(全程 TDD,对齐 B)

### server
- **domain**:`ApplySellFIFO`(多 lot/部分消耗/跨 lot/超卖 error)+ `ApplyBuy` 建 lot + `RecordSplit` 调整 lot + `AvgCost` 派生;**proptest**(FIFO 守恒:Σ realized + remaining cost = 总成本)。**回归 A 的 6 domain 测**
- **application**:SnapshotHoldings / GetPortfolioPerformance(采样+折算+基准+realized+年化)/ GetHoldingPerformance / BackfillPriceHistory(mock HistoricalProvider)
- **priceprovider**:SinaProvider.FetchHistory(httptest mock 新浪 K 线 JSON)+ 基准 sh000300
- **scheduler**:SnapshotScheduler(复用 [scheduler_test.go](../../yucai/server/internal/holding/scheduler/scheduler_test.go) 模式)
- **handler**:3 RPC 映射;**repository**:ent 集成测(price_history/snapshot/lot/rate_history)

### Flutter
- PerformanceBloc `_onLoadPortfolioPerformance`(Right/Left + range 切换)、HoldingBloc `_onLoadHoldingCurve`、mapper(CurvePoint→PerfPoint)、widget test(performance/detail 真数据 + 空态)
- **回归现有 101 测**不破坏

## 10. 前置验证(Task 0)

C 开工前:
- **验证 ent 模块内生成可用**:C 首次给 holding(3 表)+ currency(1 表)加新 schema。各模块有 `ent/generate.go` 控制本模块生成。Task 0 先验证 `cd <module>/ent && go generate` 可用;若坏(参照 [[yucai-wire-handmaintained]] wire 教训),手维护生成代码 + 记 ledger。
- **清工作区**(若有 B 遗留临时文件)
- **seed CSI300 security**:启动时确保 security 表有 `000300/SSE/INDEX` 基准记录(若空)

## 11. 实施顺序建议(供 writing-plans,约 14 task)

```
Task 0  前置:验证 ent 模块内生成 + 清工作区 + seed CSI300
───────── server ─────────
Task 1  domain:HoldingLot + ApplySellFIFO 重写 + ApplyBuy/RecordSplit lot + AvgCost 派生 + 回归 A 测(TDD)
Task 2  schema + ent 生成:4 表 + holding_transaction 加列 + migrate
Task 3  repository:Snapshot/Lot/PriceHistory/RateHistory ent 集成测
Task 4  priceprovider:HistoricalProvider 接口 + SinaProvider.FetchHistory(httptest)
Task 5  application:SnapshotHoldings/Backfill/GetPortfolioPerformance/GetHoldingPerformance + Buy/Sell/Split lot 维护(TDD)
Task 6  scheduler:SnapshotScheduler + B SyncPrices/currency SyncRates 顺手写 history
Task 7  proto + handler:3 RPC + buf 重生成 + handler 单测
Task 8  wire + main:SnapshotScheduler 接线 + 回填启动触发 + wire_gen 手改;go build 绿
Task 9  端到端:启动回填 price_history(CSI300+A股)+ snapshot 写入 + 曲线 RPC 真数据
───────── flutter ─────────
Task 10 proto stub:`make gen-dart`(protoc_plugin 25.0.0)
Task 11 data/domain:getPortfolioPerformance/getHoldingPerformance + entity + mapper(TDD)
Task 12 presentation:PerformanceBloc + HoldingBloc 曲线子 event + 填 6 点 + widget test
Task 13 全链路验证(flutter run 看曲线)+ final whole-branch review(C commits)
```

## 12. 决策记录(用户拍板)

| # | 决策 | 选定 |
|---|---|---|
| 范围 | 核心曲线+realized+年化(基准 defer)/ 完整 C(含基准)/ 最小曲线 | **完整 C(含基准)** |
| ① snapshot 存储 | 双表(price_history+holding_snapshot)/ 单表 holding 市值 / 单表 price history | **双表** |
| ② realized 算法 | 移动加权(复用 ApplySell)/ FIFO 精确 lot / 简单累计 | **FIFO 精确 lot** |
| ③ 多币种折算 | 快照时折算 CNY / 完整 rate history / 单币种假设 | **完整 rate history**(存原币+历史汇率) |
| ④ 历史回填 | price_history 回填+snapshot 累积 / 完整回填 / 全累积 | **price_history 回填 + snapshot 累积** |
| ⑤ lot 成本源 | —(设计内定) | **lot 成为成本真相源,AvgCost 从 open lots 派生** |
| ⑥ 时序写入 | —(设计内定) | **复用现有 scheduler 顺手写,仅 holding_snapshot 新建 SnapshotScheduler** |
| ⑦ proto RPC | —(设计内定) | **2 主 RPC 合并返回 + BackfillPriceHistory 可选** |
| ⑧ Flutter bloc | —(设计内定) | **新建 PerformanceBloc + HoldingBloc 曲线子 event** |

## 13. 风险清单(plan 需显式处理)

1. **ent 生成工具链**(Task 0):C 首次给 holding/currency 加表,模块内 `go generate` 可用性未知;坏则手维护(参照 [[yucai-wire-handmaintained]])
2. **新浪日 K 接口**(Task 4/9):`CN_MarketDataService.getKLineData` 格式需 httptest 验证 + 真实连通性端到端确认(对齐 B Task3/8"真实格式可能与 mock 不同"教训)
3. **改 A 的 entity 成本逻辑**(Task 1):ApplyBuy/Sell/Split 改 lot-based,回归 A 的 6 domain 测 + A-server 双写不破坏
4. **跨模块改 currency**(Task 2/6):currency_rate_history 表 + SyncRates 加 history insert,currency 模块测试回归

## 14. 新浪历史 K 线接口备忘

- 实时价(B 已用):`http://hq.sinajs.cn/list={prefix}{symbol}`(GBK,字段在引号内,索引 2 当前价,必带 Referer)
- **历史日 K**(C 回填用):`https://quotes.sina.cn/cn/api/jsonp.php/var_/CN_MarketDataService.getKLineData?symbol={prefix}{symbol}&scale=240&ma=no&datalen={N}`
  - `scale=240` = 日 K(240 分钟);`datalen=N` = 返回最近 N 根( YEAR→~1200, MONTH→~250, DAY→~30 )
  - 响应:JSONP 包裹的 JSON 数组 `[{day:"2025-01-02", open, high, low, close, volume}, ...]`(UTF-8,非 GBK)
  - 取 `close` × 100 = cents;`day` 转 time.Time
  - 覆盖同实时:A 股(sh/sz)+ ETF + 指数(sh000300);美股/OTC 不覆盖(走 stub,首批无历史)
- Task 4 用 httptest mock 该 JSONP 响应验证解析;Task 9 真实连通性 + count 验证(对齐 B Task8 count=3 模式)
