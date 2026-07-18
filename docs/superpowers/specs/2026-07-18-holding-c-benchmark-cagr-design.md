# holding C · benchmark⑤ chart + 年化 CAGR · 设计 spec

- **日期**: 2026-07-18
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans → subagent session)
- **分支**: 待定(main-driven,从 main 最新 `1f36a6e`)
- **范围**: holding C 收益两项 defer —— ① **基准⑤**:client `perf_curve_chart` 渲染 benchmark 第二线(组合 vs 沪深300,**rebase 100** 归一化,server/client 数据已 ready 只差 chart);② **年化 CAGR**:server 加 simple CAGR(`(final/initial)^(365/days)-1`,组合 MV-based + 单标的 price-based,full+range)对比 XIRR/TWR,proto + client stat tile。零 schema。

## 1. 背景

holding C-收益 snapshot([2026-06-30-holding-snapshot-design.md](2026-06-30-holding-snapshot-design.md))final review 标两项 defer(memory `holding-asset-management-todo` D-currency C defer):

1. **基准⑤曲线未渲染**:server [GetPortfolioPerformance](../../yucai/server/internal/holding/application/service.go) `withBenchmark` 时已返 `BenchmarkPoints`(CSI300 沪深300,`benchmarkCurve`)+ `BenchmarkName="沪深300"`;client `PortfolioPerformanceResponse`(Dart proto)有 `benchmarkPoints` + `PerformanceLoaded` 已含。但 [perf_curve_chart.dart](../../yucai/client/lib/holding/presentation/widgets/perf_curve_chart.dart) **只渲染 portfolio 线,未渲染 benchmark**("perf_curve_chart 零改 defer")。量纲问题:portfolio CNY 元 vs benchmark 指数点位,同 chart 需归一化。
2. **年化 CAGR**:XIRR(资金加权 actual/365)+ TWR(时间加权 actual/365)已 annualized(legacy simple-annualization retired)。加 **simple CAGR**((final/initial)^(365/days)-1)对比,让用户看 naive 复合 vs 资金加权 vs 时间加权三种年化。

**brainstorm 决策**(visual companion mockup 确认):归一化用 **Rebase 100**(起点=100,相对增长,金融惯例,斜率可比);CAGR 加 simple 对比(非改 XIRR/TWR)。

## 2. 目标

- 基准⑤:client `perf_curve_chart` 渲染 benchmark 第二线(rebase 100 归一化 + 灰虚线 + 图例)
- CAGR:server 加 simple CAGR(组合 MV-based + 单标的 price-based,full+range)+ proto field + client stat tile(与 XIRR/TWR 3 tile 并列)
- 零 schema;XIRR/TWR 不动;server benchmark 数据已 ready(只 client chart 改)

## 3. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | 归一化方式 | **Rebase 100**(起点=100) | brainstorm mockup A;金融惯例(index rebase);portfolio + benchmark 量纲不同(元 vs 点位),rebase 后斜率可比;Y 轴 "起点=100" |
| 2 | benchmark 线样式 | **灰虚线**(`#8a8a8a` dashed)+ 图例(组合 实线金/沪深300 虚线灰) | mockup;区别 portfolio 实线金(#b08d57);图例标名 |
| 3 | 基准⑤范围 | **组合 performance_page only** | benchmark 是组合级(对比大盘);单标的 holding_detail 是原币 price curve(无 benchmark 概念,memory 基准⑤ = performance 基准) |
| 4 | CAGR 公式 | **`(final/initial)^(365/days)-1`** | simple 复合年化(无现金流时序);对比 XIRR(资金加权)/TWR(时间加权) |
| 5 | CAGR full initial(组合) | **cost basis**(投入,`currentCostBasisInBase`) | 衡量"投入→现在"复合增长;server 已算 costBasis(用于 totalPct);days=earliest holding `created_at`→now |
| 6 | CAGR range initial(组合) | **range start MV**(`marketValueAtDateAsOf`,照 range XIRR/TWR) | range 期初市值;days=range start→now;照 range XIRR/TWR 范式 |
| 7 | CAGR 单标的 | **price-based**(`(currentPrice/initialPrice)^(365/days)-1`,原币) | 单标的 price curve 原币;full initial=first price_history / range initial=range start price |
| 8 | CAGR 降级 | **nil**(initial=0 / days<1 / history missing) | 照 XIRR/TWR;proto `*float64` optional(nil=降级,区别 0.0%);client `—` |
| 9 | stat tile | **3 tile 并列**(XIRR 资金加权 / TWR 时间加权 / CAGR 复合年化) | 三种年化并列对比;不替代(XIRR/TWR 专业,CAGR naive 参照) |
| 10 | 范围 | server(2 RPC CAGR)+ proto(2 message × 2 field)+ client(chart rebase + 2 page tile) | 完整覆盖组合 + 单标的 |

## 4. 范围边界

| 在范围 | 不在范围(defer / out) |
|---|---|
| client `perf_curve_chart` rebase 100 + benchmark 第二线(组合 performance_page) | 单标的 holding_detail benchmark(原币 price curve,无 benchmark) |
| server `portfolioCAGR`(full: cost basis→current MV;range: range start MV→current MV) | 第二 benchmark(如 中证500/SPX,memory "第二线" 实指 chart 第二线渲染,非第二基准) |
| server `holdingCAGR`(full: first price→current;range: range start price→current) | XIRR/TWR 公式改(actual/365 保留,不动) |
| proto `cagr_annualized_pct` + `range_cagr_annualized_pct`(PortfolioPerformanceResponse + HoldingPerformanceResponse) | benchmark 第二基准标的(首批固定 CSI300) |
| client performance_page + holding_detail stat tile 加 CAGR(3 tile) | |
| perf_curve_chart rebase 归一化(portfolio 线也 rebase,Y 轴 "起点=100") | |

## 5. 架构

| 层 | 组件 | 改动 |
|---|---|---|
| **server application**(holding) | `Service` | +`portfolioCAGR`(组合 MV-based full+range)+ `holdingCAGR`(单标的 price-based full+range);接入 `GetPortfolioPerformance` / `GetHoldingPerformance` |
| **proto** | `holding.proto` | `PortfolioPerformanceResponse` +`cagr_annualized_pct`=13 +`range_cagr_annualized_pct`=14;`HoldingPerformanceResponse` +同 2 field;regen Go+Dart |
| **server handler** | `GetPortfolioPerformance` / `GetHoldingPerformance` | 填 cagr field(*float64 nil=降级) |
| **client data** | holding mapper / entity | `PortfolioPerformance` + `HoldingPerformance` entity 加 cagr field;mapper proto→domain |
| **client presentation** | `perf_curve_chart.dart` | rebase 100(portfolio + benchmark / startPoint × 100)+ benchmark 灰虚线 + 图例 |
| **client presentation** | performance_page + holding_detail_page | stat tile 加 CAGR(3 tile:资金加权/时间加权/复合年化) |

**不改**:domain XIRR/TWR(annualized 保留)/ ent schema / server benchmark 算(已 ready)/ wire。

## 6. 核心改动

### 6.1 server — portfolioCAGR(组合 MV-based)

[holding/application/service.go](../../yucai/server/internal/holding/application/service.go)(照 `portfolioXIRR`/`portfolioTWR` full+range 范式):

```go
// portfolioCAGR computes the simple compound annual growth rate
// (final/initial)^(365/days) - 1 for the portfolio, in the base currency.
//   full:   initial = cost basis (currentCostBasisInBase, the total invested),
//           days = earliest holding created_at → now.
//   range:  initial = range-start market value (marketValueAtDateAsOf, same as
//           range XIRR/TWR), days = rangeStart → now.
// Degrades to nil (initial ≤ 0, days < 1, range history missing), matching
// XIRR/TWR. This is the naive compound rate for comparison — XIRR is money-
// weighted, TWR is time-weighted; CAGR ignores cash-flow timing.
func (s *Service) portfolioCAGR(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, baseCurrency string, rangeStart time.Time) (full, rng *float64) {
	base := baseCurrency
	if base == "" {
		base = "CNY"
	}
	finalMV := s.currentMarketValueInBase(ctx, tenantID, accountID, base)
	// full: cost basis → current MV
	costBasis := s.currentCostBasisInBase(ctx, tenantID, accountID, base)
	earliest := s.earliestHoldingCreated(ctx, tenantID, accountID) // plan 确认:repo 查 MIN(created_at) 或 first snapshot
	if costBasis > 0 && !earliest.IsZero() {
		days := int(time.Since(earliest).Hours() / 24)
		if days >= 1 {
			f := math.Pow(float64(finalMV)/float64(costBasis), 365.0/float64(days)) - 1
			full = ptrFloat(f)
		}
	}
	// range: range-start MV → current MV
	startMV, ok := s.marketValueAtDate(ctx, tenantID, accountID, rangeStart, s.rateForBase(ctx, base), base)
	if ok && startMV > 0 {
		days := int(time.Since(rangeStart).Hours() / 24)
		if days >= 1 {
			r := math.Pow(float64(finalMV)/float64(startMV), 365.0/float64(days)) - 1
			rng = ptrFloat(r)
		}
	}
	return full, rng
}
```

接入 `GetPortfolioPerformance`(照 `portfolioXIRR`/`portfolioTWR` 调用):
```go
fullCagr, rangeCagr := s.portfolioCAGR(ctx, tenantID, accountID, base, from)
out.CagrAnnualizedPct = fullCagr
out.RangeCagrAnnualizedPct = rangeCagr
```

> `earliestHoldingCreated`(plan 确认):holdingRepo 查 tenant(account-scoped)最早 `created_at`(MIN),或 first snapshot date。照 `currentCostBasisInBase` 已有的 holding 遍历范式。

### 6.2 server — holdingCAGR(单标的 price-based)

```go
// holdingCAGR computes the simple CAGR on the security's original-currency
// price: (currentPrice/initialPrice)^(365/days) - 1.
//   full:   initial = first price_history point, days = first price date → now.
//   range:  initial = range-start price, days = rangeStart → now.
// Degrades to nil (no price history / days < 1), matching holdingXIRR/holdingTWR.
func (s *Service) holdingCAGR(ctx context.Context, h domain.Holding, sec domain.Security, rangeStart time.Time) (full, rng *float64) {
	cur := float64(sec.CurrentPriceCents)
	if cur <= 0 {
		return nil, nil
	}
	// full: first price_history
	first, firstDate, ok := s.firstPriceFor(ctx, h.SecurityID) // plan 确认:priceHistoryRepo earliest
	if ok && first > 0 && !firstDate.IsZero() {
		days := int(time.Since(firstDate).Hours() / 24)
		if days >= 1 {
			f := math.Pow(cur/first, 365.0/float64(days)) - 1
			full = ptrFloat(f)
		}
	}
	// range: range-start price
	startPrice, ok := s.priceAtOrBefore(ctx, h.SecurityID, rangeStart)
	if ok && startPrice > 0 {
		days := int(time.Since(rangeStart).Hours() / 24)
		if days >= 1 {
			r := math.Pow(cur/startPrice, 365.0/float64(days)) - 1
			rng = ptrFloat(r)
		}
	}
	return full, rng
}
```

接入 `GetHoldingPerformance`:
```go
fullCagr, rangeCagr := s.holdingCAGR(ctx, *h, *sec, rangeStart)
// add to HoldingPerformance{..., CagrAnnualizedPct: fullCagr, RangeCagrAnnualizedPct: rangeCagr}
```

> `firstPriceFor` / `priceAtOrBefore`(plan 确认):priceHistoryRepo earliest + as-of(s holding snapshot TWR 已用 priceAtOrBefore 范式,复用)。

### 6.3 proto — cagr field

[proto/holding/v1/holding.proto](../../yucai/proto/holding/v1/holding.proto):

```proto
message PortfolioPerformanceResponse {
  // ... existing 1-12 ...
  optional double cagr_annualized_pct = 13;       // CAGR: simple 复合年化 (final/initial)^(365/days)-1, nil=降级
  optional double range_cagr_annualized_pct = 14; // range CAGR (range start→now)
}
message HoldingPerformanceResponse {
  // ... existing fields ...
  optional double cagr_annualized_pct = N;        // 单标的 price-based CAGR
  optional double range_cagr_annualized_pct = N+1;
}
```

> `optional`(proto3,XIRR/TWR 已用 optional 区分 nil 降级 vs 0.0%);regen Go(`cd yucai/proto && buf generate --template buf.gen.go.yaml`)+ Dart(`cd yucai && make gen-dart`,**protoc_plugin 25.0.0**)。HoldingPerformanceResponse 现有 field 数 plan 确认(append cagr 在末尾)。

### 6.4 client — perf_curve_chart rebase 100 + benchmark 线

[perf_curve_chart.dart](../../yucai/client/lib/holding/presentation/widgets/perf_curve_chart.dart)(plan 确认现有 fl_chart LineChart API):

```dart
// Rebase both series to 100 at start (量纲归一化: portfolio CNY 元 vs benchmark 指数点位).
List<FlSpot> _rebase100(List<PerfPoint> pts) {
  if (pts.isEmpty) return [];
  final start = pts.first.value;
  if (start == 0) return pts.map((p) => FlSpot(p.dx, 100)).toList(); // 防除零
  return pts.map((p) => FlSpot(p.dx, p.value / start * 100)).toList();
}

// In build: portfolio line (rebased) + benchmark line (rebased, dashed grey) + legend.
LineChartData(
  lineBarsData: [
    LineChartBarData(spots: _rebase100(perf.portfolioPoints), color: AppColors.accent, isCurved: true, ...), // 金实线
    if (perf.benchmarkPoints.isNotEmpty)
      LineChartBarData(spots: _rebase100(perf.benchmarkPoints), color: Color(0xFF8A8A8A), dashArray: [4, 3], ...), // 灰虚线
  ],
  ...
)
// Y 轴标题 "起点=100";legend row: ━ 组合 / ┄ 沪深300
```

> plan 确认:perf_curve_chart 现有 LineChart 结构(spots/LineChartBarData)+ PerfPoint(Plan 确认 dx/value)。Y 轴 title + legend widget 加。

### 6.5 client — stat tile CAGR(3 tile)

[performance_page.dart](../../yucai/client/lib/holding/presentation/pages/performance_page.dart) + [holding_detail_page.dart](../../yucai/client/lib/holding/presentation/pages/holding_detail_page.dart):

现有 XIRR/TWR stat tile(资金加权/时间加权)。加 CAGR tile(复合年化):

```dart
// 3 tile 并列:资金加权 XIRR / 时间加权 TWR / 复合年化 CAGR
_StatTile(label: '资金加权', value: perf.annualizedPct),       // XIRR full
_StatTile(label: '时间加权', value: perf.twrAnnualizedPct),    // TWR full
_StatTile(label: '复合年化', value: perf.cagrAnnualizedPct),   // CAGR full (new)
// nil → '—'
```

> plan 确认:performance_page / holding_detail_page 现有 stat tile 布局(行/列)+ _StatTile widget(复用)。range tile 同理(range XIRR/TWR/CAGR)。

## 7. 数据流

- **基准⑤**(组合 chart):`GetPortfolioPerformance`(withBenchmark=true)→ `BenchmarkPoints`(CSI300)+ `PortfolioPoints` → client `PerformanceLoaded` → `perf_curve_chart` rebase 100(portfolio + benchmark / start × 100)→ 双线(金实线 + 灰虚线)+ 图例。
- **CAGR**(组合):`GetPortfolioPerformance` → `portfolioCAGR`(full: costBasis→currentMV;range: rangeStartMV→currentMV)→ `cagr_annualized_pct` / `range_cagr_annualized_pct` → client stat tile。
- **CAGR**(单标的):`GetHoldingPerformance` → `holdingCAGR`(full: firstPrice→current;range: rangeStartPrice→current)→ cagr field → holding_detail stat tile。
- **降级**:CAGR initial=0/days<1/history missing → nil → proto field absent → client `—`。

## 8. 测试

- **server domain**:无新 domain(CAGR 是 application 纯算,照 XIRR/TWR application 测)。
- **server application** `portfolioCAGR`:full(costBasis→MV,days≥1 → CAGR;costBasis=0/days<1 → nil)+ range(rangeStartMV→MV;history missing → nil)。照 `portfolioXIRR` 测范式(fake snapshot/trade)。
- **server application** `holdingCAGR`:full(firstPrice→current;no history → nil)+ range(rangeStartPrice→current)。
- **server handler**:cagr field 填(*float64 nil round-trip)。
- **client** `perf_curve_chart`:rebase 100(portfolio + benchmark / start × 100,start=0 → 100 防除零)+ benchmark 虚线渲染(widget test,benchmarkPoints 非空 → 2 LineChartBarData)+ 图例。
- **client** stat tile:CAGR tile 显示(nil → `—`)+ 3 tile 并列。
- **回归**:XIRR/TWR 测不改动;server benchmark 测不改动(数据 ready,只 client chart 新渲染)。

## 9. 风险

1. **earliestHoldingCreated / firstPriceFor / priceAtOrBefore**(plan 确认):repo 查 MIN(created_at) / priceHistoryRepo earliest + as-of。holding snapshot TWR 已用 `priceAtOrBefore`(split-adjusted),复用。`earliestHoldingCreated` 新(holdingRepo 加 method 或遍历)。
2. **proto optional**(XIRR/TWR 已用):`cagr_annualized_pct` optional 区分 nil 降级 vs 0.0%。regen Go+Dart(protoc_plugin 25.0.0)。
3. **rebase 100 start=0**:portfolio/benchmark startPoint=0(MV 0 / 指数 0,不应发生)→ 防 除零(rebase → 100 平线)。client `perf_curve_chart` 守卫。
4. **rebase 改 Y 轴语义**:portfolio 线从"CNY 元"变"起点=100"。现有 client 可能依赖 portfolio 线原值(如 tooltip 显示元)。plan 确认 perf_curve_chart tooltip / 依赖(portfolio 线 rebase 后,tooltip 需显原值 or rebase 值)。若 tooltip 显元,rebase 仅 chart 视觉,tooltip 用原 points。
5. **CAGR vs XIRR/TWR 语义**:CAGR naive(无现金流时序),用户可能困惑(为何 ≠ XIRR)。stat tile label 明确("复合年化" vs "资金加权" vs "时间加权")+ 文案说明。
6. **单标的 CAGR price-based vs 组合 MV-based**:语义不同(单标的 price 涨跌,组合 MV 含 cash flow)。label 区分(单标的 "价格年化" vs 组合 "复合年化"?或都 "复合年化")。plan 定 label。
7. **3 tile 布局**(plan 确认):performance_page / holding_detail_page 现有 stat tile 行/列 + 加 CAGR(3 tile)。plan 确认布局(行 wrap / 列)。

## 10. 参考

- holding C spec:[2026-06-30-holding-snapshot-design.md](2026-06-30-holding-snapshot-design.md)(基准⑤ + 年化设计 + CSI300 benchmark)
- server benchmark:[GetPortfolioPerformance benchmarkCurve](../../yucai/server/internal/holding/application/service.go)(withBenchmark → CSI300 price_history)
- XIRR/TWR 范式:[portfolioXIRR](../../yucai/server/internal/holding/application/service.go) + [portfolioTWR](../../yucai/server/internal/holding/application/service.go)(full+range + 降级 nil)
- [currencydomain.ConvertToBase](../../yucai/server/internal/currency/domain/convert.go)(组合 MV 折算,portfolioCAGR 复用)
- memory:`holding-asset-management-todo`(D-currency C defer 基准⑤第二线/年化 CAGR)、`yucai-dev-env`(protoc_plugin 25.0.0)
