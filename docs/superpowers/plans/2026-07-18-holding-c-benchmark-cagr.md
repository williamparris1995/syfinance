# holding C · benchmark⑤ chart + 年化 CAGR · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** holding C 两项 defer —— ① **基准⑤**:client `perf_curve_chart` 渲染 benchmark 第二线(组合 vs 沪深300,**rebase 100** 归一化);② **年化 CAGR**:server 加 simple CAGR(`(final/initial)^(365/days)-1`,组合 MV-based + 单标的 price-based,full+range)对比 XIRR/TWR,proto + client stat tile。

**Architecture:** server `portfolioCAGR`(组合:full cost basis→MV / range start MV→MV)+ `holdingCAGR`(单标的:full first price→current / range start price→current,复用 `priceAtOrBefore`/`FindBySecurity`)+ proto `cagr_annualized_pct`/`range_cagr_annualized_pct`(optional,nil 降级)+ handler 填;client entity/mapper 加 cagr + `perf_curve_chart` 改 `_spots` min-max→rebase 100 + benchmark 灰虚线 + performance_page/holding_detail_page 3 tile。**零 schema;XIRR/TWR/benchmark-data 不动**。

**Tech Stack:** Go ent + DDD · proto3(Go+Dart regen 25.0.0)· Flutter fl_chart 1.x · TDD

---

## Global Constraints

(每个 task 隐含;从 spec §3/§9 + CLAUDE.md)

1. **英文 slog**(无 CJK)。
2. **proto regen**:Go `cd yucai/proto && buf generate --template buf.gen.go.yaml`(spec Task 2 确认路径)+ Dart `cd yucai && make gen-dart`(**protoc_plugin 25.0.0**)。改 proto 后 Go+Dart 都 regen。
3. **proto `optional`** cagr field(`*float64` Go / nullable Dart),nil=降级(区别 0.0%),照 XIRR/TWR(field 7/10/11/12 已 optional)。
4. **CAGR = `(final/initial)^(365/days)-1`**;降级 nil(initial≤0 / days<1 / history missing),照 XIRR/TWR。
5. **归一化 rebase 100**:改 `perf_curve_chart._spots`(现状 min-max [0,1] → `/firstPoint×100`),portfolio + benchmark 都 rebase(共享归一)。benchmark 灰虚线(`#8A8A8A` dashed)+ 图例。**注意**:portfolio 线视觉变(Y 轴 0-1 → 100+),tooltip 若显原值需保留原 points(plan 确认 tooltip)。
6. **零 schema**;XIRR/TWR 公式(actual/365)不动;server benchmark 算(`benchmarkCurve`,已 ready)不动。
7. **commit multi `-m`**(Bash here-string 坏),TDD。

---

## File Structure

| 文件 | 责任 | 改动 |
|---|---|---|
| [proto/holding/v1/holding.proto](../../yucai/proto/holding/v1/holding.proto) | proto | `PortfolioPerformanceResponse` +`cagr_annualized_pct=13`+`range_cagr_annualized_pct=14`;`HoldingPerformanceResponse` +2 cagr field(append 末尾,plan 确认 range_twr 后号) |
| server gen .pb.go | Go stub | regen(buf) |
| [holding/application/service.go](../../yucai/server/internal/holding/application/service.go) | `Service` | +`portfolioCAGR`(full: cost basis→currentMV;range: rangeStartMV→currentMV)+ `holdingCAGR`(full: firstPrice→current;range: rangeStartPrice→current);接入 `GetPortfolioPerformance`/`GetHoldingPerformance`;`earliestHoldingCreated` helper |
| [holding/application/dto.go](../../yucai/server/internal/holding/application/dto.go)(或 service.go inline) | DTO | `PortfolioPerformance` + `HoldingPerformance` struct +`CagrAnnualizedPct`+`RangeCagrAnnualizedPct` `*float64` |
| [holding/adapter/driving/grpc/holding_handler.go](../../yucai/server/internal/holding/adapter/driving/grpc/holding_handler.go) | handler | `GetPortfolioPerformance`/`GetHoldingPerformance` 填 cagr field |
| server test | application test | +`portfolioCAGR`/`holdingCAGR` 测(full/range/降级) |
| client gen .pb.dart | Dart stub | regen(make gen-dart,25.0.0) |
| [client holding/domain/entities/performance_entity.dart](../../yucai/client/lib/holding/domain/entities/performance_entity.dart) | entity | `PortfolioPerformance` + `HoldingPerformance` +cagr field |
| client holding/data mapper | mapper | proto→domain cagr |
| [client perf_curve_chart.dart](../../yucai/client/lib/holding/presentation/widgets/perf_curve_chart.dart) | chart | `_spots` min-max→rebase 100;+ benchmark 第二 `LineChartBarData`(灰虚线)+ 图例;+ optional `benchmarkPoints` param |
| [client performance_page.dart](../../yucai/client/lib/holding/presentation/pages/performance_page.dart) | page | stat tile 加 CAGR(3 tile)+ 传 benchmarkPoints 给 chart |
| [client holding_detail_page.dart](../../yucai/client/lib/holding/presentation/pages/holding_detail_page.dart) | page | stat tile 加 CAGR |
| client test | widget test | perf_curve_chart rebase + benchmark 线;stat tile CAGR |

---

## Task 1: server CAGR(portfolio + holding + proto + handler)

proto + Go regen + application CAGR + handler + test。

**Files:**
- Modify: [proto/holding/v1/holding.proto](../../yucai/proto/holding/v1/holding.proto)
- Regen: server `.pb.go`
- Modify: [holding/application/service.go](../../yucai/server/internal/holding/application/service.go)
- Modify: [holding/application/dto.go](../../yucai/server/internal/holding/application/dto.go)(PortfolioPerformance/HoldingPerformance struct)或 service.go inline
- Modify: [holding/adapter/driving/grpc/holding_handler.go](../../yucai/server/internal/holding/adapter/driving/grpc/holding_handler.go)
- Modify: server test(application)

**Interfaces:**
- Consumes: 现有 `currentCostBasisInBase`/`currentMarketValueInBase`/`marketValueAtDate`/`priceAtOrBefore`/`FindBySecurity`/`rateForBase`;XIRR/TWR 范式(`ptrFloat`)
- Produces: `portfolioCAGR`/`holdingCAGR` + cagr proto field

- [ ] **Step 1: 改 proto — cagr field**

[holding.proto](../../yucai/proto/holding/v1/holding.proto):

`PortfolioPerformanceResponse`(line 185-197,现有 1-12)加:
```proto
  optional double cagr_annualized_pct = 13;        // CAGR: simple 复合年化 (final/initial)^(365/days)-1, nil=降级
  optional double range_cagr_annualized_pct = 14;  // range CAGR (range start→now, nil=降级)
```

`HoldingPerformanceResponse`(line 208-216,现有 1-8 含 twr=8;**plan 确认 range_twr 号** —— grep `range_twr_annualized_pct` in holding.proto)append:
```proto
  optional double cagr_annualized_pct = N;        // 单标的 price-based CAGR (first/range-start price→current)
  optional double range_cagr_annualized_pct = N+1;
```
(N = 现有最大号 + 1,append 末尾)

- [ ] **Step 2: regen Go stub**

Run: `cd yucai/proto && buf generate --template buf.gen.go.yaml`(spec Task 2 确认 buf.gen.go.yaml 在 yucai/proto/)
Expected: 成功;`PortfolioPerformanceResponse.CagrAnnualizedPct`/`RangeCagrAnnualizedPct`(`*float64`)+ `HoldingPerformanceResponse` 同。

- [ ] **Step 3: 写 application CAGR 测(失败态)**

server test(application,照 `portfolioXIRR`/`portfolioTWR` 测范式):`portfolioCAGR`(full: costBasis→MV,days≥1→CAGR;costBasis=0→nil)+ range(rangeStartMV→MV;history missing→nil);`holdingCAGR`(full: firstPrice→current;no history→nil)+ range。照 XIRR/TWR fake snapshot/trade/price fixture。

- [ ] **Step 4: 跑测看失败**

Run: `cd yucai/server && go test ./internal/holding/application/... -run 'CAGR' -count=1`
Expected: FAIL(`portfolioCAGR`/`holdingCAGR` undefined)

- [ ] **Step 5: 加 portfolioCAGR + holdingCAGR + earliestHoldingCreated**

[service.go](../../yucai/server/internal/holding/application/service.go)(照 spec §6.1/6.2 代码雏形):

`portfolioCAGR`(组合 MV-based full+range):
```go
func (s *Service) portfolioCAGR(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, baseCurrency string, rangeStart time.Time) (full, rng *float64) {
	base := baseCurrency
	if base == "" { base = "CNY" }
	finalMV := s.currentMarketValueInBase(ctx, tenantID, accountID, base)
	costBasis := s.currentCostBasisInBase(ctx, tenantID, accountID, base)
	earliest := s.earliestHoldingCreated(ctx, tenantID, accountID)
	if costBasis > 0 && !earliest.IsZero() {
		if days := int(time.Since(earliest).Hours() / 24); days >= 1 {
			f := math.Pow(float64(finalMV)/float64(costBasis), 365.0/float64(days)) - 1
			full = ptrFloat(f)
		}
	}
	startMV, ok := s.marketValueAtDate(ctx, tenantID, accountID, rangeStart, s.rateForBase(ctx, base), base)
	if ok && startMV > 0 {
		if days := int(time.Since(rangeStart).Hours() / 24); days >= 1 {
			r := math.Pow(float64(finalMV)/float64(startMV), 365.0/float64(days)) - 1
			rng = ptrFloat(r)
		}
	}
	return full, rng
}
```

`holdingCAGR`(单标的 price-based full+range,复用 `priceAtOrBefore` + `FindBySecurity`):
```go
func (s *Service) holdingCAGR(ctx context.Context, h domain.Holding, sec domain.Security, rangeStart time.Time) (full, rng *float64) {
	cur := float64(sec.CurrentPriceCents)
	if cur <= 0 { return nil, nil }
	// full: first price_history (FindBySecurity epoch→now, asc, first=oldest)
	all, _ := s.priceHistoryRepo.FindBySecurity(ctx, h.SecurityID, time.Time{}, time.Now())
	if len(all) > 0 && all[0].PriceCents > 0 {
		first := float64(all[0].PriceCents)
		firstDate := all[0].PriceDate
		if days := int(time.Since(firstDate).Hours() / 24); days >= 1 {
			f := math.Pow(cur/first, 365.0/float64(days)) - 1
			full = ptrFloat(f)
		}
	}
	// range: priceAtOrBefore(rangeStart) — application 已有 (split-adjusted)
	startPriceCents, ok := s.priceAtOrBefore(ctx, h.SecurityID, rangeStart)
	if ok && startPriceCents > 0 {
		if days := int(time.Since(rangeStart).Hours() / 24); days >= 1 {
			r := math.Pow(cur/float64(startPriceCents), 365.0/float64(days)) - 1
			rng = ptrFloat(r)
		}
	}
	return full, rng
}
```

`earliestHoldingCreated`(plan 确认:遍历 FindAll + min CreatedAt):
```go
// earliestHoldingCreated returns the earliest holding.CreatedAt for the tenant
// (account-scoped). Zero if no holdings. Used by portfolioCAGR full-period days.
func (s *Service) earliestHoldingCreated(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID) time.Time {
	var earliest time.Time
	page := domain.PageRequest{PageSize: 100}
	for {
		res, err := s.holdingRepo.FindAll(ctx, tenantID, accountID, page)
		if err != nil { break }
		for _, h := range res.Items {
			if earliest.IsZero() || h.CreatedAt.Before(earliest) { earliest = h.CreatedAt }
		}
		if res.NextPageToken == "" || len(res.Items) == 0 { break }
		page.PageToken = res.NextPageToken
	}
	return earliest
}
```

> 确认 `priceAtOrBefore` 返 `(int64, bool)`(plan grep service.go:1477 signature);`math`/`time` import 已有;`ptrFloat` XIRR/TWR 已用。

- [ ] **Step 6: 接入 GetPortfolioPerformance / GetHoldingPerformance**

service.go `GetPortfolioPerformance`(照 `portfolioXIRR`/`portfolioTWR` 调用,`from` 是 rangeStart):
```go
fullCagr, rangeCagr := s.portfolioCAGR(ctx, tenantID, accountID, base, from)
out.CagrAnnualizedPct = fullCagr
out.RangeCagrAnnualizedPct = rangeCagr
```

`GetHoldingPerformance`:
```go
fullCagr, rangeCagr := s.holdingCAGR(ctx, *h, *sec, rangeStart)
// add to HoldingPerformance return: ..., CagrAnnualizedPct: fullCagr, RangeCagrAnnualizedPct: rangeCagr
```

DTO struct `PortfolioPerformance` + `HoldingPerformance` 加 `CagrAnnualizedPct` + `RangeCagrAnnualizedPct *float64`。

- [ ] **Step 7: handler 填 cagr**

[holding_handler.go](../../yucai/server/internal/holding/adapter/driving/grpc/holding_handler.go) `GetPortfolioPerformance`/`GetHoldingPerformance` response 加 `CagrAnnualizedPct: perf.CagrAnnualizedPct` + `RangeCagrAnnualizedPct: perf.RangeCagrAnnualizedPct`(*float64 proto optional 直传,照 XIRR/TWR)。

- [ ] **Step 8: 跑测 + build + 全量**

Run: `cd yucai/server && go test ./internal/holding/... -count=1`(CAGR 测 + XIRR/TWR 不回归)
Run: `cd yucai/server && go build ./...`
Run: `cd yucai/server && go test ./... -count=1`

- [ ] **Step 9: Commit**

```bash
cd e:/projects/syfinance
git add yucai/proto/holding/v1/holding.proto \
  yucai/server/internal/proto/holding/v1/*.pb.go \
  yucai/server/internal/holding/application/service.go \
  yucai/server/internal/holding/application/dto.go \
  yucai/server/internal/holding/adapter/driving/grpc/holding_handler.go \
  yucai/server/internal/holding/application/*_test.go
git commit -m "feat(holding): CAGR (portfolio MV + holding price) + proto cagr field (Task 1)" -m "portfolioCAGR (full: costBasis->currentMV;range: rangeStartMV->currentMV) + holdingCAGR (full: firstPrice->current;range: rangeStartPrice->current, 复用 priceAtOrBefore) + earliestHoldingCreated. proto cagr_annualized_pct + range_cagr_annualized_pct optional (Portfolio+Holding PerformanceResponse). nil degrade (initial<=0/days<1/history missing), 照 XIRR/TWR. zero schema; XIRR/TWR untouched."
```

---

## Task 2: client(chart rebase 100 + benchmark + stat tile)

Dart regen + entity/mapper + perf_curve_chart rebase 100 + benchmark 线 + 2 page stat tile。

**Files:**
- Regen: client `.pb.dart`
- Modify: [client holding/domain/entities/performance_entity.dart](../../yucai/client/lib/holding/domain/entities/performance_entity.dart)
- Modify: client holding/data mapper(proto→domain cagr)
- Modify: [client perf_curve_chart.dart](../../yucai/client/lib/holding/presentation/widgets/perf_curve_chart.dart)
- Modify: [client performance_page.dart](../../yucai/client/lib/holding/presentation/pages/performance_page.dart)
- Modify: [client holding_detail_page.dart](../../yucai/client/lib/holding/presentation/pages/holding_detail_page.dart)
- Modify: client test

**Interfaces:**
- Consumes: Task 1 cagr proto field;现有 PerfCurveChart/PerfPoint/performance_page stat tile
- Produces: client cagr 显示 + benchmark chart 第二线

- [ ] **Step 1: regen Dart stub**

Run: `cd yucai && make gen-dart`(**protoc_plugin 25.0.0**;drift 则 `dart pub global activate protoc_plugin 25.0.0`)
Expected: `PortfolioPerformanceResponse`/`HoldingPerformanceResponse` Dart stub 含 cagrAnnualizedPct/rangeCagrAnnualizedPct。

- [ ] **Step 2: entity + mapper cagr**

[performance_entity.dart](../../yucai/client/lib/holding/domain/entities/performance_entity.dart) `PortfolioPerformance` + `HoldingPerformance` 加 `cagrAnnualizedPct` + `rangeCagrAnnualizedPct`(double?,nullable=nil 降级)。mapper proto→domain(照 XIRR/TWR 映射)。

- [ ] **Step 3: perf_curve_chart rebase 100 + benchmark 线**

[perf_curve_chart.dart](../../yucai/client/lib/holding/presentation/widgets/perf_curve_chart.dart):

加 optional `benchmarkPoints` param + `benchmarkName`(默认 '沪深300'):
```dart
class PerfCurveChart extends StatelessWidget {
  const PerfCurveChart({
    ...,
    this.benchmarkPoints = const [],
    this.benchmarkName = '沪深300',
  });
  final List<PerfPoint> benchmarkPoints;
  final String benchmarkName;
  ...
}
```

改 `_spots` min-max → **rebase 100**(/ startPoint × 100):
```dart
/// points → rebase 100 (起点=100,相对增长)。startPoint=0 → 100 平线(防除零)。
/// 量纲归一化:portfolio 元 vs benchmark 点位 都 rebase 后斜率可比。
List<FlSpot> _rebase100(List<PerfPoint> pts) {
  if (pts.length <= 1) return const [FlSpot(0, 100), FlSpot(1, 100)];
  final start = pts.first.value;
  if (start == 0) return [for (var i = 0; i < pts.length; i++) FlSpot(i.toDouble(), 100)];
  return [for (var i = 0; i < pts.length; i++) FlSpot(i.toDouble(), pts[i].value / start * 100)];
}
```

`_chart()` 改 2 lineBarData(portfolio 金实线 rebase + benchmark 灰虚线 rebase)+ minY/maxY 自适应(100 附近):
```dart
Widget _chart() {
  final portSpots = _rebase100(points);
  final benchSpots = _rebase100(benchmarkPoints);
  // Y range: min/max across both series (100 附近),fallback 0-200
  final all = [...portSpots, ...benchSpots];
  final ys = all.map((s) => s.y).toList()..sort();
  final minY = ys.isEmpty ? 0.0 : ys.first;
  final maxY = ys.isEmpty ? 200.0 : ys.last;
  return LineChart(LineChartData(
    titlesData: const FlTitlesData(show: false),
    gridData: const FlGridData(show: false),
    borderData: FlBorderData(show: false),
    lineTouchData: const LineTouchData(enabled: false),
    clipData: const FlClipData.all(),
    minX: 0, maxX: (portSpots.length - 1).toDouble().clamp(0, double.infinity),
    minY: minY, maxY: maxY == minY ? minY + 1 : maxY,
    lineBarsData: [
      LineChartBarData(spots: portSpots, isCurved: true, color: AppColors.accent, barWidth: 1.8, isStrokeCapRound: true, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: AppColors.accent.withValues(alpha: 0.16))),
      if (benchmarkPoints.isNotEmpty)
        LineChartBarData(spots: benchSpots, isCurved: true, color: const Color(0xFF8A8A8A), barWidth: 1.4, isStrokeCapRound: true, dotData: const FlDotData(show: false), dashArray: [4, 3]),  // 灰虚线
    ],
  ));
}
```

图例(head 下方或 chart 上):`━ 组合`(金)/ `┄ 沪深300`(灰虚线)。**注意**:现状 `_spots` min-max 用于 portfolio 单线视觉归一;改 rebase 100 后 portfolio 线也 rebase(Y 轴 100 附近,非 0-1)。**tooltip**(plan 确认:perf_curve_chart 现 `lineTouchData(enabled:false)` 无 tooltip —— 无需处理 tooltip 原值)。

> plan 确认:perf_curve_chart 现 `LineTouchData(enabled:false)`(无 tooltip),rebase 不影响 tooltip。Y 轴无 title widget(Plan 确认是否加 "起点=100" 标注)。

- [ ] **Step 4: performance_page 传 benchmarkPoints + stat tile CAGR**

[performance_page.dart](../../yucai/client/lib/holding/presentation/pages/performance_page.dart):

`PerfCurveChart` 调用传 `benchmarkPoints`(PerformanceLoaded.performance.benchmarkPoints → PerfPoint list)+ `benchmarkName`。

stat tile 加 CAGR(3 tile:资金加权 XIRR / 时间加权 TWR / 复合年化 CAGR):
```dart
// plan 确认现有 stat tile 布局(行/列/_StatTile widget 复用)
_StatTile(label: '资金加权', value: perf.annualizedPct),      // XIRR
_StatTile(label: '时间加权', value: perf.twrAnnualizedPct),   // TWR
_StatTile(label: '复合年化', value: perf.cagrAnnualizedPct),  // CAGR (new), nil → '—'
```

- [ ] **Step 5: holding_detail_page stat tile CAGR**

[holding_detail_page.dart](../../yucai/client/lib/holding/presentation/pages/holding_detail_page.dart):stat tile 加 CAGR(同 performance_page 范式,单标的 cagr)。

- [ ] **Step 6: client 测**

widget test:`perf_curve_chart` benchmarkPoints 非空 → 2 LineChartBarData(portfolio + benchmark);rebase(startPoint × 100)。stat tile CAGR(nil → '—')。

(注:client test 基线 4 fail/3 文件 CLAUDE.md;不引入新 fail。)

- [ ] **Step 7: analyze + test + build**

Run: `cd yucai/client && flutter analyze`(22 基线无新增)
Run: `cd yucai/client && flutter test test/holding/`(新测过 + 基线 fail 不在 holding)
Run: `cd yucai/client && flutter build windows --debug`

- [ ] **Step 8: Commit**

```bash
cd e:/projects/syfinance
git add yucai/client/lib/proto/holding/v1/*.pb.dart \
  yucai/client/lib/holding/domain/entities/performance_entity.dart \
  yucai/client/lib/holding/data/holding_repository_impl.dart \
  yucai/client/lib/holding/presentation/widgets/perf_curve_chart.dart \
  yucai/client/lib/holding/presentation/pages/performance_page.dart \
  yucai/client/lib/holding/presentation/pages/holding_detail_page.dart \
  yucai/client/test/holding/
git commit -m "feat(holding/client): benchmark⑤ chart rebase100 + CAGR stat tile (Task 2)" -m "Dart regen (protoc_plugin 25.0.0). perf_curve_chart _spots min-max -> rebase 100 (portfolio + benchmark / startPoint x 100, 斜率可比); benchmark 灰虚线第二 LineChartBarData + 图例 (组合/沪深300). performance_page + holding_detail_page stat tile 3 tile (资金加权 XIRR / 时间加权 TWR / 复合年化 CAGR, nil -> '—'). entity/mapper cagr."
```

---

## Spec coverage 矩阵

| spec 决策/章节 | 落地 task | 备注 |
|---|---|---|
| §3 #1 归一化 rebase 100 | Task 2 Step 3 `_rebase100` | 改 _spots min-max |
| §3 #2 benchmark 灰虚线 | Task 2 Step 3 | `#8A8A8A` dashed + 图例 |
| §3 #3 组合 only benchmark | Task 2(performance_page) | holding_detail 无 benchmark |
| §3 #4 CAGR 公式 | Task 1 Step 5 | `(final/initial)^(365/days)-1` |
| §3 #5 full cost basis | Task 1 portfolioCAGR | currentCostBasisInBase |
| §3 #6 range start MV | Task 1 portfolioCAGR | marketValueAtDate |
| §3 #7 单标的 price-based | Task 1 holdingCAGR | priceAtOrBefore + FindBySecurity first |
| §3 #8 nil 降级 | Task 1(proto optional)+ Task 2('—') | |
| §3 #9 3 tile | Task 2 Step 4/5 | |
| §6.1 portfolioCAGR | Task 1 Step 5 | |
| §6.2 holdingCAGR | Task 1 Step 5 | 复用 priceAtOrBefore |
| §6.3 proto cagr | Task 1 Step 1 | Portfolio=13/14,Holding append |
| §6.4 chart rebase | Task 2 Step 3 | 改 _spots |
| §6.5 stat tile | Task 2 Step 4/5 | |
| §9 风险 1 earliest/priceAtOrBefore | Task 1(priceAtOrBefore 已有,earliestHoldingCreated 新)| |
| §9 风险 3 rebase start=0 | Task 2 `_rebase100` 防除零 | |
| §9 风险 4 tooltip | Task 2(现 lineTouchData disabled,无 tooltip)| |
