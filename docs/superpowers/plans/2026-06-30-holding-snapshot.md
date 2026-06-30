# Holding 子项目 C · 收益 snapshot 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给 holding 模块加上时序收益统计 —— 4 张时序表(security 价格历史 / holding 市值快照 / FIFO lot / currency 汇率历史),每日 scheduler 写入,server 算好收益曲线(组合 CNY + 单标的原币,日/月/年)+ FIFO 精确 realized + 年化 + CSI300 基准,2 个新 RPC 返回,Flutter 把 6 个 ⏳C 降级点接真数据。

**Architecture:** server 端新建 domain FIFO lot 纯函数 + 4 张 ent 表(模块内 `go generate`)+ 4 个 repository + `HistoricalProvider`(新浪日 K 回填)+ application(SnapshotHoldings/Backfill/GetPortfolioPerformance/GetHoldingPerformance)+ `SnapshotScheduler`(复用 B 骨架);B `SyncPrices` 顺手写 price_history,currency `SyncRates` 顺手写 rate_history;proto 加 2 主 RPC + 1 回填 RPC;Flutter 新建 PerformanceBloc + HoldingBloc 加曲线子 event,填 6 个 ⏳C 点。

**Tech Stack:** Go(ent + sort + math + net/http + golang.org/x/text + grpc + slog)+ proto3 + Flutter(flutter_bloc + injectable + grpc stub + fl_chart 1.x + equatable + dartz)

**Spec:** [docs/superpowers/specs/2026-06-30-holding-snapshot-design.md](../specs/2026-06-30-holding-snapshot-design.md)

## Global Constraints

- **分支**:`holding-asset-management`(不要在 main 上直接做;B 已合并到此分支,C 续做)
- **wire 工具链 tree-wide 坏**:`wire_gen.go` 手维护,改 provider 签名时**直接手改镜像同模式行,不跑 `go generate`/`wire` CLI**(见 [[yucai-wire-handmaintained]])。验证用 `cd yucai/server && go build ./...` 绿
- **ent 生成**:C 首次给 holding(3 表)+ currency(1 表)加 schema。**各模块自己有 `ent/generate.go`** 控制本模块生成。Task 0 先验证 `cd yucai/server/internal/holding/ent && go generate ./...` 可用;若坏(参照 [[yucai-wire-handmaintained]] 教训),手维护生成代码 + 记 ledger。**不要从仓库根跑 `go generate ./...`**(会在空的 `internal/ent/schema` 失败,见 [[yucai-wire-handmaintained]])
- **Dart stub 重生成**:`cd yucai && make gen-dart`(需 protoc_plugin **25.0.0**)。Go stub:`cd yucai/proto && buf generate --template buf.gen.go.yaml`(非 `make proto`,bash 无 make,见 B ledger)
- **FIFO refine(spec §5.1 "重写 ApplySell" → 本 plan 细化)**:**不破坏 A 的 `Holding.ApplyBuy/ApplySell/ApplySplit`**(A 的 6 domain 测 + 双写依赖它们)。改为新增 domain 纯函数 `ConsumeLotsFIFO` + `LotAvgCost`(在 `domain/lot.go`),service 层 Buy/Sell/Split 调它们维护 lot + 用 `LotAvgCost` 覆盖 `Holding.AvgCostCents`(保持与 FIFO 一致)。`Holding.ApplySell` 保留向后兼容但 service 不依赖其近似 realized
- **时序写入复用现有 scheduler**(spec §5.3):B `SyncPrices` 更新 current_price 后**顺手 insert security_price_history 当日点**;currency `SyncRates` 刷新 rate 后**顺手 insert currency_rate_history 当日点**;仅 holding_snapshot 由**新 `SnapshotScheduler`** 写
- **回填**(spec §5.5/决策④):price_history 从新浪日 K 回填(`CN_MarketDataService.getKLineData`),snapshot 从上线累积。main 启动**异步 goroutine** 检测 `security_price_history` 空表 → 自动 `BackfillPriceHistory`;非空跳过(幂等)
- **基准 CSI300** = 一个特殊 security(symbol=`000300`, exchange=`SSE`, type=`INDEX`),seed 进 securities 表,复用 price_history 存指数时序。SinaProvider 已能拉(`hq.sinajs.cn/list=sh000300`,只判 exchange 不判 type)
- **新浪日 K 接口**(spec §14):`https://quotes.sina.cn/cn/api/jsonp.php/var_/CN_MarketDataService.getKLineData?symbol={sh|sz}{symbol}&scale=240&ma=no&datalen={N}`。响应 JSONP 包裹的 JSON 数组 `[{day:"YYYY-MM-DD",open,high,low,close,volume},...]`(**UTF-8,非 GBK**,与实时 hq.sinajs.cn 不同)。取 `close×100`=cents,`day`→time.Time。`scale=240`=日 K;`datalen`:DAY→30 / MONTH→250 / YEAR→1200
- **新浪实时价索引**(B 已验证):hq.sinajs.cn 字段全在引号内,索引 2=当前价
- **CurvePoint.value 用 double**(元/点位,对齐 A-od mock + Flutter PerfPoint.double);foot 的 realized/unrealized/total 用 **int64 cents**(server 惯例)。mapper 负责 cents↔元
- **年化 server 端算**(spec §6):holding.created_at 已存(ent holding.go Immutable),server 算持仓时长→年化返回 `annualized_pct`,**不改 HoldingDTO**;组合年化基于最早 holding created_at(组合起始)
- **English 结构化日志**(CLAUDE.md AI 约束#2);CJK 只在用户可见 Dart UI(御财 Flutter 暂无强制 i18n,bloc 注释中文 OK)
- **复用第一**:scheduler 严格对齐 `holding/scheduler/scheduler.go`(B 已建,SnapshotScheduler 改名 + Snapshotter 接口);provider 对齐 `priceprovider`(B 已建);repo 对齐 `holding/adapter/driven/repository/trade_repo.go`
- **失败策略**:provider/snapshot best-effort,单条失败不中断;rate 缺失向前填充;曲线点数不足返回实际点(client `<2` 空态,不伪造);FIFO 超卖 error(不写负 remaining)
- **每 task 末尾 commit**:conventional commit 中文 header(对齐 git log),如 `feat(holding-c-server): ...`
- **flutter analyze 基线 = 22 error**(全 `*.pbserver.dart`,11 模块各 2,客户端未用,非 holding 专属)。后续 task 验证以此为基线,勿报为新增
- **fl_chart 1.2.0**(非 0.69):1.x API,PieChart/LineChart 公开类,color 单数,withValues 非 withOpacity(A-flutter 已踩过)

## File Structure

### server 新建
- `yucai/server/internal/holding/domain/lot.go` — HoldingLot 聚合 + LotConsumption + ConsumeLotsFIFO + LotAvgCost 纯函数
- `yucai/server/internal/holding/domain/lot_test.go` — FIFO 单测(单 lot/多 lot/部分/超卖/avgCost)
- `yucai/server/internal/holding/domain/snapshot.go` — SecurityPriceHistory + HoldingSnapshot 实体(纯数据 struct)
- `yucai/server/internal/holding/ent/schema/security_price_history.go` — ent schema
- `yucai/server/internal/holding/ent/schema/holding_snapshot.go` — ent schema(TenantMixin)
- `yucai/server/internal/holding/ent/schema/holding_lot.go` — ent schema(TenantMixin)
- `yucai/server/internal/currency/ent/schema/rate_history.go` — ent schema(跨模块)
- `yucai/server/internal/holding/adapter/driven/repository/snapshot_repo.go` — SnapshotRepository(ent)
- `yucai/server/internal/holding/adapter/driven/repository/lot_repo.go` — LotRepository(ent)
- `yucai/server/internal/holding/adapter/driven/repository/price_history_repo.go` — PriceHistoryRepository(ent)
- `yucai/server/internal/currency/adapter/driven/repository/rate_history_repo.go` — RateHistoryRepository(ent,跨模块)
- `yucai/server/internal/holding/adapter/driven/priceprovider/history.go` — HistoricalProvider 接口 + HistoryPoint
- `yucai/server/internal/holding/adapter/driven/priceprovider/history_test.go` — FetchHistory httptest 单测

### server 修改
- `yucai/server/internal/holding/domain/entity.go` — 不改(ApplyBuy/Sell/Split 保留);lot 逻辑在 lot.go
- `yucai/server/internal/holding/domain/repository.go` — 加 Snapshot/Lot/PriceHistory repository 接口
- `yucai/server/internal/holding/ent/schema/holding_transaction.go` — 加 `realized_pnl_cents` 字段
- `yucai/server/internal/holding/application/service.go` — 加 SnapshotHoldings/BackfillPriceHistory/GetPortfolioPerformance/GetHoldingPerformance + Buy/Sell/Split lot 维护 + SetSnapshotRepos/SetHistoricalProvider setter + SeedSecurities 加 CSI300
- `yucai/server/internal/holding/application/service_test.go` — 追加 snapshot/curve/realized 测试
- `yucai/server/internal/holding/application/dto.go` — 加 PortfolioPerformance/HoldingPerformance DTO(curve points + foot)
- `yucai/server/internal/holding/adapter/driven/priceprovider/sina.go` — 加 FetchHistory 方法(实现 HistoricalProvider)
- `yucai/server/internal/currency/application/service.go` — SyncRates 顺手写 rate_history(加 RateHistoryRepository setter)
- `yucai/proto/holding/v1/holding.proto` — 加 CurveRange/CurvePoint + 3 RPC + message
- `yucai/server/internal/holding/adapter/driving/grpc/holding_handler.go` — 加 3 RPC handler
- `yucai/server/internal/holding/adapter/driving/grpc/holding_handler_test.go` — 追加 3 RPC 测试
- `yucai/server/wire/providers.go` — 加 4 repo provider + SnapshotScheduler + historicalProvider + 改 provideHoldingService/currencyService 注入
- `yucai/server/wire/wire_gen.go` — **手改**(镜像 B 的 SnapshotScheduler 行)
- `yucai/server/wire/app.go` — App.SnapshotScheduler
- `yucai/server/cmd/server/main.go` — go SnapshotScheduler.Start + 启动异步回填

### Flutter 修改(stub 由 Task 10 make gen-dart 生成)
- `yucai/client/lib/holding/domain/entities/performance_entity.dart` — PortfolioPerformance + HoldingPerformance entity(新建)
- `yucai/client/lib/holding/data/holding_remote_ds.dart` — getPortfolioPerformance/getHoldingPerformance
- `yucai/client/lib/holding/domain/repositories/holding_repository.dart` — 加 2 抽象
- `yucai/client/lib/holding/data/holding_repository_impl.dart` — 加 2 实现
- `yucai/client/lib/holding/data/holding_mapper.dart` — CurvePoint→PerfPoint,response→entity
- `yucai/client/lib/holding/presentation/bloc/performance_bloc.dart` — 新建 PerformanceBloc
- `yucai/client/lib/holding/presentation/bloc/performance_event.dart` / `performance_state.dart` — 新建
- `yucai/client/lib/holding/presentation/bloc/holding_bloc.dart` — 加 LoadHoldingCurveRequested 子 event + _onLoadHoldingCurve
- `yucai/client/lib/holding/presentation/bloc/holding_event.dart` / `holding_state.dart` — HoldingDetailLoaded 加 holdingCurve/holdingCurveFoot
- `yucai/client/lib/holding/presentation/pages/performance_page.dart` — 接 PerformanceBloc 填 ①③④⑤
- `yucai/client/lib/holding/presentation/pages/holding_detail_page.dart` — 接曲线子 event 填 ②⑥(删 _costBasisCurve/_realizedFromTrades)

---

## Task 0: 前置验证(ent 工具链)+ 清工作区

**Files:**
- Verify: `yucai/server/internal/holding/ent/generate.go`、`yucai/server/internal/currency/ent/generate.go`
- Read: `yucai/server/internal/holding/ent/schema/holding_transaction.go`(确认加字段位置)

**背景**:C 首次给 holding/currency 加 ent 表。各模块 `ent/generate.go` 控制本模块生成(`go:generate go run -mod=mod entgo.io/ent/cmd/ent generate ./schema`)。**必须验证模块内生成可用**,否则全 plan 的 ent 路径要改为手维护(参照 [[yucai-wire-handmaintained]])。

- [ ] **Step 1: 读 holding/ent/generate.go 确认生成入口**

```bash
cat /e/projects/syfinance/yucai/server/internal/holding/ent/generate.go
```
Expected:文件含 `//go:generate go run -mod=mod entgo.io/ent/cmd/ent generate ./schema`(或类似)。记下确切 go:generate 指令。

- [ ] **Step 2: 试跑 holding 模块 ent 生成(空跑,无新 schema 时应无变化)**

```bash
cd /e/projects/syfinance/yucai/server/internal/holding/ent && go generate ./...
```
Expected:成功(无新 schema,生成的 `ent/*.go` 不变,`git status` 无改动)。若**失败**(`entc/load: parse schema dir` 或 Go 版本不匹配),记下错误到 ledger,**后续 Task 2 的 ent 生成为手维护**(参照 wire 教训:手写/镜像现有 ent 生成文件,不跑 go generate)。无论成功失败,Task 2 都先尝试 `go generate`,失败才 fallback。

- [ ] **Step 3: 同样验证 currency 模块**

```bash
cd /e/projects/syfinance/yucai/server/internal/currency/ent && go generate ./...
```
Expected:同 Step 2。currency 模块也要加 1 表(rate_history)。

- [ ] **Step 4: 清工作区(若有 B 遗留临时文件)**

```bash
cd /e/projects/syfinance && git status
```
若除 docs/ 外有脏文件(`.bak`/`nul`/临时导出),`rm -f` 清掉(参照 B Task 0)。若工作区已干净,跳过。

- [ ] **Step 5: 验证 server 当前编译绿(C 起点)**

```bash
cd /e/projects/syfinance/yucai/server && go build ./...
```
Expected:**PASS**(B 已合并,server 编译绿)。这是 C 的基线,记下。

- [ ] **Step 6: 记录 Task 0 结论到 ledger**

在 `.superpowers/sdd/progress.md` 新建 "SDD Progress Ledger — holding-snapshot (C)" section,记:
- ent 模块内生成:可用 ✅ / 不可用(走手维护)❌
- server 基线 build:PASS
- 工作区:干净

(本 task 无 commit —— 纯验证 + 可能的清理 commit 若 Step 4 删了文件)

---

## Task 1: domain FIFO lot(ConsumeLotsFIFO + LotAvgCost + HoldingLot)+ 回归 A 测

**Files:**
- Create: `yucai/server/internal/holding/domain/lot.go`
- Test: `yucai/server/internal/holding/domain/lot_test.go`
- Verify: `yucai/server/internal/holding/domain/domain_test.go`(A 的 6 测不破坏)

**Interfaces:**
- Produces:
  - `domain.HoldingLot` struct:`{ID, TenantID, HoldingID, SecurityID uuid.UUID; AcquiredDate time.Time; AcquiredTradeID uuid.UUID; PriceCents int64; Quantity, RemainingQuantity float64}`
  - `domain.LotConsumption` struct:`{LotID uuid.UUID; ConsumedQuantity float64}`
  - `domain.ConsumeLotsFIFO(sellQty float64, sellPriceCents int64, lots []HoldingLot) (realized int64, consumed []LotConsumption, err error)` — 纯函数,按 AcquiredDate 升序消耗 RemainingQuantity,realized = Σ(sellPrice − lot.Price)×consumed;超卖 error;**不 mutate 入参 lots**
  - `domain.LotAvgCost(lots []HoldingLot) int64` — 从 remaining>0 的 lot 加权平均
- Task 5(application Buy/Sell/Split lot 维护)、Task 3(LotRepository)依赖

**背景**:FIFO 精确 realized。纯函数易测。不碰 `Holding.ApplySell`(A 保留),service 层调本函数 + 用 LotAvgCost 覆盖 Holding.AvgCostCents。cents 用 `math.Round` 避浮点截断(对齐 entity.go 惯例)。

- [ ] **Step 1: 写失败测试 lot_test.go**

`yucai/server/internal/holding/domain/lot_test.go`:
```go
package domain

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func mustLot(acquired time.Time, price int64, remaining float64) HoldingLot {
	return HoldingLot{
		ID:                uuid.New(),
		AcquiredDate:      acquired,
		PriceCents:        price,
		Quantity:          remaining,
		RemainingQuantity: remaining,
	}
}

func TestConsumeLotsFIFOSingleLot(t *testing.T) {
	lots := []HoldingLot{mustLot(time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC), 10000, 100)}
	// sell 40 @ 120 (cost 100) → realized = (120-100)*40 = 800
	realized, consumed, err := ConsumeLotsFIFO(40, 12000, lots)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if realized != 800 {
		t.Fatalf("realized = %d, want 800", realized)
	}
	if len(consumed) != 1 || consumed[0].ConsumedQuantity != 40 {
		t.Fatalf("consumed = %+v, want 1 lot × 40", consumed)
	}
}

func TestConsumeLotsFIFOMultiLot(t *testing.T) {
	// Two lots: oldest @100 (60), newer @110 (40). Sell 80 @130.
	// FIFO: take 60 from lot1 (realized (130-100)*60=1800) + 20 from lot2 ((130-110)*20=400) = 2200
	lots := []HoldingLot{
		mustLot(time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC), 10000, 60),
		mustLot(time.Date(2025, 1, 5, 0, 0, 0, 0, time.UTC), 11000, 40),
	}
	realized, consumed, err := ConsumeLotsFIFO(80, 13000, lots)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if realized != 2200 {
		t.Fatalf("realized = %d, want 2200", realized)
	}
	if len(consumed) != 2 || consumed[0].ConsumedQuantity != 60 || consumed[1].ConsumedQuantity != 20 {
		t.Fatalf("consumed = %+v, want [60, 20]", consumed)
	}
}

func TestConsumeLotsFIFOPartialLeavesRemaining(t *testing.T) {
	lots := []HoldingLot{mustLot(time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC), 10000, 100)}
	_, consumed, err := ConsumeLotsFIFO(30, 12000, lots)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// Caller applies consumption: lot.RemainingQuantity -= consumed.
	remaining := lots[0].RemainingQuantity - consumed[0].ConsumedQuantity
	if remaining != 70 {
		t.Fatalf("remaining after sell = %.4f, want 70", remaining)
	}
}

func TestConsumeLotsFIFOOverSellErrors(t *testing.T) {
	lots := []HoldingLot{mustLot(time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC), 10000, 50)}
	_, _, err := ConsumeLotsFIFO(60, 12000, lots)
	if err == nil {
		t.Fatal("oversell must error")
	}
}

func TestConsumeLotsFIFOUnsortedInputSortedByDate(t *testing.T) {
	// Input out of date order: newer lot first. FIFO must still consume oldest first.
	lots := []HoldingLot{
		mustLot(time.Date(2025, 1, 5, 0, 0, 0, 0, time.UTC), 11000, 40), // newer
		mustLot(time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC), 10000, 60), // older
	}
	_, consumed, err := ConsumeLotsFIFO(60, 13000, lots)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// All 60 from the older (@100) lot, none from newer.
	if len(consumed) != 1 || consumed[0].LotID != lots[1].ID {
		t.Fatalf("FIFO must consume oldest lot first; consumed=%+v", consumed)
	}
}

func TestConsumeLotsFIFODoesNotMutateInput(t *testing.T) {
	lots := []HoldingLot{mustLot(time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC), 10000, 100)}
	before := lots[0].RemainingQuantity
	_, _, _ = ConsumeLotsFIFO(40, 12000, lots)
	if lots[0].RemainingQuantity != before {
		t.Fatalf("ConsumeLotsFIFO must not mutate input lots; got %.4f want %.4f",
			lots[0].RemainingQuantity, before)
	}
}

func TestLotAvgCost(t *testing.T) {
	lots := []HoldingLot{
		mustLot(time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC), 10000, 60), // 60 @ 100
		mustLot(time.Date(2025, 1, 5, 0, 0, 0, 0, time.UTC), 11000, 40), // 40 @ 110
	}
	// weighted = (60*100 + 40*110) / 100 = 10400 → 104.00
	if got := LotAvgCost(lots); got != 10400 {
		t.Fatalf("LotAvgCost = %d, want 10400", got)
	}
}

func TestLotAvgCostSkipsClosedLots(t *testing.T) {
	lots := []HoldingLot{
		mustLot(time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC), 10000, 0), // closed (remaining=0)
		mustLot(time.Date(2025, 1, 5, 0, 0, 0, 0, time.UTC), 11000, 40),
	}
	if got := LotAvgCost(lots); got != 11000 {
		t.Fatalf("LotAvgCost = %d, want 11000 (skip closed lot)", got)
	}
}

// 守恒性质(确定性验证,非 proptest 库):卖完后 Σ realized + remaining_lot_cost = total_cost_basis。
// 即 FIFO 不创造/毁灭成本:实现的 + 剩余的 = 原始总成本(相对卖出回收调整)。
func TestConsumeLotsFIFOConservation(t *testing.T) {
	lots := []HoldingLot{
		mustLot(time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC), 10000, 60),
		mustLot(time.Date(2025, 1, 5, 0, 0, 0, 0, time.UTC), 11000, 40),
	}
	sellQty := 50.0
	sellPrice := int64(13000)
	realized, consumed, err := ConsumeLotsFIFO(sellQty, sellPrice, lots)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// remaining cost = Σ (lot.Price × (lot.Remaining - consumed[i]))
	remainingCost := int64(0)
	consumedByID := map[uuid.UUID]float64{}
	for _, c := range consumed {
		consumedByID[c.LotID] = c.ConsumedQuantity
	}
	for _, l := range lots {
		rem := l.RemainingQuantity - consumedByID[l.ID]
		remainingCost += int64(float64(l.PriceCents) * rem)
	}
	// realized was computed against sellPrice; cost-of-goods-sold = Σ(lot.Price × consumed)
	cogs := int64(0)
	for _, l := range lots {
		cogs += int64(float64(l.PriceCents) * consumedByID[l.ID])
	}
	// realized + cogs should equal sellQty * sellPrice (proceeds fully accounted).
	proceeds := int64(float64(sellPrice) * sellQty)
	if realized+cogs != proceeds {
		t.Fatalf("conservation broken: realized(%d)+cogs(%d)=%d != proceeds(%d)",
			realized, cogs, realized+cogs, proceeds)
	}
	// remainingCost + cogs == original total cost (cost preserved across sell).
	originalCost := int64(60*10000 + 40*11000)
	if remainingCost+cogs != originalCost {
		t.Fatalf("cost not preserved: remaining(%d)+cogs(%d)=%d != original(%d)",
			remainingCost, cogs, remainingCost+cogs, originalCost)
	}
}
```

- [ ] **Step 2: 跑测试验证 FAIL**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/domain/ -run FIFO -v -count=1
```
Expected:FAIL / 编译错误(`ConsumeLotsFIFO`/`HoldingLot`/`LotAvgCost` 未定义)。

- [ ] **Step 3: 实现 lot.go**

`yucai/server/internal/holding/domain/lot.go`:
```go
package domain

import (
	"fmt"
	"math"
	"sort"
	"time"

	"github.com/google/uuid"
)

// HoldingLot is a FIFO cost lot — a tax lot acquired by a single buy, consumed
// in acquired-date order by sells. Split adjusts Quantity/RemainingQuantity by
// ratio (cost per share scales inversely, total cost unchanged). remaining=0
// lots are retained for audit/historical realized traceability.
type HoldingLot struct {
	ID                uuid.UUID
	TenantID          uuid.UUID
	HoldingID         uuid.UUID
	SecurityID        uuid.UUID
	AcquiredDate      time.Time
	AcquiredTradeID   uuid.UUID
	PriceCents        int64
	Quantity          float64
	RemainingQuantity float64
}

// LotConsumption records how much of one lot a sell consumed (for the caller
// to persist RemainingQuantity decrements).
type LotConsumption struct {
	LotID            uuid.UUID
	ConsumedQuantity float64
}

const fifoQtyEpsilon = 1e-9 // tolerance for float quantity comparisons

// ConsumeLotsFIFO consumes sellQty across lots in FIFO order (oldest
// AcquiredDate first), returning the realized P&L in cents and the per-lot
// consumption record. sellQty must be <= sum of RemainingQuantity; otherwise
// an error is returned (defensive oversell guard — service.SellHolding already
// validates against Holding.Quantity, this is the second layer).
//
// lots are NOT mutated; the caller applies consumed[].ConsumedQuantity to each
// lot's RemainingQuantity and persists via LotRepository. math.Round avoids
// float truncation (same convention as entity.go cents math).
func ConsumeLotsFIFO(sellQty float64, sellPriceCents int64, lots []HoldingLot) (realized int64, consumed []LotConsumption, err error) {
	// Defensive copy + sort by AcquiredDate ascending (FIFO). Caller usually
	// passes sorted, but do not trust it.
	sorted := append([]HoldingLot(nil), lots...)
	sort.SliceStable(sorted, func(i, j int) bool { return sorted[i].AcquiredDate.Before(sorted[j].AcquiredDate) })

	total := 0.0
	for _, l := range sorted {
		total += l.RemainingQuantity
	}
	if sellQty > total+fifoQtyEpsilon {
		return 0, nil, fmt.Errorf("fifo: cannot sell %.4f, only %.4f in lots", sellQty, total)
	}

	remaining := sellQty
	for _, l := range sorted {
		if remaining <= fifoQtyEpsilon {
			break
		}
		if l.RemainingQuantity <= fifoQtyEpsilon {
			continue
		}
		take := math.Min(remaining, l.RemainingQuantity)
		realized += int64(math.Round(float64(sellPriceCents-l.PriceCents) * take))
		consumed = append(consumed, LotConsumption{LotID: l.ID, ConsumedQuantity: take})
		remaining -= take
	}
	return realized, consumed, nil
}

// LotAvgCost returns the weighted-average cost (cents) of open lots
// (RemainingQuantity > 0). Used to keep Holding.AvgCostCents consistent with
// the FIFO lot state after each buy/sell/split. Returns 0 if no open lots.
func LotAvgCost(lots []HoldingLot) int64 {
	var cost, qty float64
	for _, l := range lots {
		if l.RemainingQuantity > fifoQtyEpsilon {
			cost += float64(l.PriceCents) * l.RemainingQuantity
			qty += l.RemainingQuantity
		}
	}
	if qty <= fifoQtyEpsilon {
		return 0
	}
	return int64(math.Round(cost / qty))
}
```

- [ ] **Step 4: 写 snapshot.go(纯实体,无逻辑)**

`yucai/server/internal/holding/domain/snapshot.go`:
```go
package domain

import (
	"time"

	"github.com/google/uuid"
)

// SecurityPriceHistory is one day of price history for a security (original
// currency). Supports single-security curve (holding_detail) + benchmark curve
// (CSI300). Tenant-free — price is global master data.
type SecurityPriceHistory struct {
	ID           uuid.UUID
	SecurityID   uuid.UUID
	PriceDate    time.Time
	PriceCents   int64
	CurrencyCode string
	Source       string
	CreatedAt    time.Time
}

// HoldingSnapshot is one day of market-value snapshot for a holding (original
// currency). Supports portfolio curve (Σ × rate_history → CNY). Tenant-scoped.
type HoldingSnapshot struct {
	ID                 uuid.UUID
	TenantID           uuid.UUID
	HoldingID          uuid.UUID
	SecurityID         uuid.UUID
	AccountID          uuid.UUID
	SnapshotDate       time.Time
	MarketValueCents   int64
	UnrealizedPnlCents int64
	CurrencyCode       string
	CreatedAt          time.Time
}
```

- [ ] **Step 5: 跑测试验证 PASS**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/domain/ -run "FIFO|LotAvg" -v -count=1
```
Expected:PASS(8 个 FIFO/LotAvgCost 测试)。

- [ ] **Step 6: 回归 A 的 domain 测(ApplyBuy/Sell/Split 未动,应全过)**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/domain/ -v -count=1
```
Expected:PASS(A 的 6 测 + 新 8 测全过。entity.go 未改,A 测不受影响)。

- [ ] **Step 7: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/internal/holding/domain/lot.go yucai/server/internal/holding/domain/lot_test.go yucai/server/internal/holding/domain/snapshot.go
git commit -m "feat(holding-c-server): domain FIFO lot(ConsumeLotsFIFO+LotAvgCost)+snapshot 实体

HoldingLot 聚合 + ConsumeLotsFIFO 纯函数(按 acquired_date 升序消耗,
realized=(sellPrice-lotPrice)×consumed,超卖 error,不 mutate 入参)+
LotAvgCost(open lots 加权)。SecurityPriceHistory/HoldingSnapshot 实体。
不碰 Holding.ApplySell(A 保留),service 层将改用本函数。8 单测含守恒性质。
A 的 6 domain 测回归全过。"
```

---

## Task 2: ent schema(4 新表 + holding_transaction 加列)+ 模块内生成

**Files:**
- Create: `yucai/server/internal/holding/ent/schema/security_price_history.go`
- Create: `yucai/server/internal/holding/ent/schema/holding_snapshot.go`
- Create: `yucai/server/internal/holding/ent/schema/holding_lot.go`
- Create: `yucai/server/internal/currency/ent/schema/rate_history.go`
- Modify: `yucai/server/internal/holding/ent/schema/holding_transaction.go`(加 realized_pnl_cents 字段)
- Regenerate: `yucai/server/internal/holding/ent/*.go`(generated)、`yucai/server/internal/currency/ent/*.go`

**Interfaces:**
- Produces: ent 生成的新表 client(`ent.SecurityPriceHistory` / `HoldingSnapshot` / `HoldingLot` / `RateHistory`)+ holding_transaction 加 `RealizedPnlCents` 列。Task 3(repo)依赖

**背景**:setup task(ent schema 是声明,非 TDD)。参照现有 [holding.go](../../yucai/server/internal/holding/ent/schema/holding.go)/[security.go](../../yucai/server/internal/holding/ent/schema/security.go) 模式。Task 0 已验证生成路径。migrate 随 server 启动自动建表(ent auto-migrate)。

- [ ] **Step 1: 先读现有 schema 确认 Mixin/Annotations 模式**

```bash
cat /e/projects/syfinance/yucai/server/internal/holding/ent/schema/holding.go
cat /e/projects/syfinance/yucai/server/internal/holding/ent/schema/holding_transaction.go
```
记下:`TenantMixin` 怎么引用(`mixin.TenantMixin`?)、Annotations 模式、created_at 写法。holding_transaction.go 的 Fields() 块位置(待加 realized_pnl_cents)。

- [ ] **Step 2: 写 security_price_history.go(无 tenant)**

`yucai/server/internal/holding/ent/schema/security_price_history.go`:
```go
package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"
)

// SecurityPriceHistory holds daily price history per security (original
// currency). Tenant-free — price is global master data (aligned with Security).
type SecurityPriceHistory struct {
	ent.Schema
}

func (SecurityPriceHistory) Annotations() []entschema.Annotation {
	return []entschema.Annotation{entsql.WithComments(true)}
}

func (SecurityPriceHistory) Mixin() []ent.Mixin { return nil }

func (SecurityPriceHistory) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).Default(uuid.New),
		field.UUID("security_id", uuid.UUID{}).Comment("owning security (incl. benchmark 000300)"),
		field.Time("price_date").Comment("one row per security per date"),
		field.Int64("price_cents").Comment("close price in original currency cents"),
		field.String("currency_code").Default("CNY"),
		field.String("source").Default("sina").Comment("sina / backfill / manual"),
		field.Time("created_at").Default(time.Now).Immutable(),
	}
}

func (SecurityPriceHistory) Edges() []ent.Edge { return nil }

func (SecurityPriceHistory) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("security_id", "price_date").Unique(),
		index.Fields("security_id", "price_date"),
	}
}
```

- [ ] **Step 3: 写 holding_snapshot.go(TenantMixin)**

`yucai/server/internal/holding/ent/schema/holding_snapshot.go`:
```go
package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"
)

// HoldingSnapshot holds daily market-value snapshot per holding (original
// currency). Tenant-scoped. Portfolio curve = Σ snapshots × rate_history → CNY.
type HoldingSnapshot struct {
	ent.Schema
}

func (HoldingSnapshot) Annotations() []entschema.Annotation {
	return []entschema.Annotation{entsql.WithComments(true)}
}

// Mixin: copy the exact TenantMixin reference used by holding.go (Step 1).
// If holding.go uses `mixin.TenantMixin{}`, use the same here.
func (HoldingSnapshot) Mixin() []ent.Mixin {
	return []ent.Mixin{mixin.TenantMixin{}} // ⚠️ match holding.go's exact Mixin reference
}

func (HoldingSnapshot) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).Default(uuid.New),
		field.UUID("holding_id", uuid.UUID{}),
		field.UUID("security_id", uuid.UUID{}).Comment("denormalized for security-level aggregation"),
		field.UUID("account_id", uuid.UUID{}).Comment("denormalized for account filter"),
		field.Time("snapshot_date"),
		field.Int64("market_value_cents").Comment("qty × day's price, original currency"),
		field.Int64("unrealized_pnl_cents").Comment("original currency"),
		field.String("currency_code").Default("CNY"),
		field.Time("created_at").Default(time.Now).Immutable(),
	}
}

func (HoldingSnapshot) Edges() []ent.Edge { return nil }

func (HoldingSnapshot) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("tenant_id", "holding_id", "snapshot_date").Unique(),
		index.Fields("tenant_id", "snapshot_date"),
		index.Fields("tenant_id", "security_id", "snapshot_date"),
	}
}
```
> ⚠️ `mixin.TenantMixin{}` 的确切写法以 Step 1 读到的 holding.go 为准(import 路径 + 类型名)。

- [ ] **Step 4: 写 holding_lot.go(TenantMixin,FIFO)**

`yucai/server/internal/holding/ent/schema/holding_lot.go`:
```go
package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"
)

// HoldingLot is a FIFO cost lot. Buy creates a lot; sell consumes
// RemainingQuantity in acquired_date order; split adjusts Quantity and
// RemainingQuantity by ratio. remaining=0 lots retained for audit.
type HoldingLot struct {
	ent.Schema
}

func (HoldingLot) Annotations() []entschema.Annotation {
	return []entschema.Annotation{entsql.WithComments(true)}
}

func (HoldingLot) Mixin() []ent.Mixin {
	return []ent.Mixin{mixin.TenantMixin{}} // ⚠️ match holding.go
}

func (HoldingLot) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).Default(uuid.New),
		field.UUID("holding_id", uuid.UUID{}),
		field.UUID("security_id", uuid.UUID{}).Comment("denormalized"),
		field.Time("acquired_date").Comment("buy trade date; FIFO ordering key"),
		field.UUID("acquired_trade_id", uuid.UUID{}).Comment("holding_transaction.id of the buy"),
		field.Int64("price_cents").Comment("buy cost price"),
		field.Float64("quantity").Comment("original acquired quantity"),
		field.Float64("remaining_quantity").Comment("remaining after sells/splits"),
		field.Time("created_at").Default(time.Now).Immutable(),
	}
}

func (HoldingLot) Edges() []ent.Edge { return nil }

func (HoldingLot) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("tenant_id", "holding_id", "acquired_date"), // FIFO consume order
	}
}
```

- [ ] **Step 5: 写 currency rate_history.go(跨模块,无 tenant)**

`yucai/server/internal/currency/ent/schema/rate_history.go`:
```go
package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"
)

// RateHistory holds daily exchange-rate history per currency (to base CNY).
// Tenant-free — currency is global reference (aligned with Currency table).
// currency SyncRates writes one row per refresh; holding reads for CNY折算.
type RateHistory struct {
	ent.Schema
}

func (RateHistory) Annotations() []entschema.Annotation {
	return []entschema.Annotation{entsql.WithComments(true)}
}

func (RateHistory) Mixin() []ent.Mixin { return nil }

func (RateHistory) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).Default(uuid.New),
		field.String("currency_code").Comment("ISO 4217 (CNY=base=1.0)"),
		field.Time("rate_date"),
		field.Float64("exchange_rate").Comment("to base (CNY)"),
		field.Time("created_at").Default(time.Now).Immutable(),
	}
}

func (RateHistory) Edges() []ent.Edge { return nil }

func (RateHistory) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("currency_code", "rate_date").Unique(),
	}
}
```

- [ ] **Step 6: holding_transaction.go 加 realized_pnl_cents 字段**

在 `holding_transaction.go` 的 `Fields()` 块(Step 1 读到的位置,在 `amount_cents` 或 `fee_cents` 之后)加一行:
```go
		field.Int64("realized_pnl_cents").Default(0).Optional().Comment("FIFO realized P&L on sell (Task1 ConsumeLotsFIFO); 0 for other trade types"),
```
(保留所有现有字段,只追加这一行。)

- [ ] **Step 7: 模块内 ent 生成(holding)**

```bash
cd /e/projects/syfinance/yucai/server/internal/holding/ent && go generate ./...
```
Expected:成功;`git status` 显示 holding/ent/ 下生成的 `securitypricehistory*.go` / `holdingsnapshot*.go` / `holdinglot*.go` + `holdingtransaction.go` 更新(加 RealizedPnlCents)+ `migrate/schema.go` 更新 + `client.go` 加新表方法。

**若失败**(Task 0 记录的工具链坏):参照 [[yucai-wire-handmaintained]] —— 手维护生成文件(镜像现有 `holdingtransaction.go` 生成模式:实体 + create/query/update/delete + where + predicate)。记 ledger。这是 fallback,优先尝试 go generate。

- [ ] **Step 8: 模块内 ent 生成(currency)**

```bash
cd /e/projects/syfinance/yucai/server/internal/currency/ent && go generate ./...
```
Expected:成功;`currency/ent/` 下生成 `ratehistory*.go` + migrate 更新 + client 加方法。

- [ ] **Step 9: 验证 server 编译绿(新表 client 可用)**

```bash
cd /e/projects/syfinance/yucai/server && go build ./...
```
Expected:**PASS**。若报错(某 ent 生成文件缺方法),检查 Step 7/8 生成是否完整;fallback 手维护。

- [ ] **Step 10: 启动 server 验证 migrate 建表(可选,确认 schema 正确)**

```bash
cd /e/projects/syfinance/yucai/server && go build -o bin/server.exe ./cmd/server
# 用 Task 0/8 的 env 起 server(见 yucai-dev-env memory),确认日志无 migrate 错误,
# 然后 podman exec yucai-pg psql -U yucai -d yucai -c "\dt" 看新表:
#   security_price_histories / holding_snapshots / holding_lots / rate_histories
```
Expected:4 新表 + holding_transactions 加 realized_pnl_cents 列。TaskStop server。

- [ ] **Step 11: Commit schema + 生成产物**

```bash
cd /e/projects/syfinance
git add yucai/server/internal/holding/ent/ yucai/server/internal/currency/ent/
git commit -m "feat(holding-c-server): ent schema 4 新表+holding_transaction 加 realized 列

security_price_history(无tenant,UNIQUE security+date)/ holding_snapshot
(tenant,UNIQUE tenant+holding+date)/ holding_lot(tenant,FIFO acquired_date
索引)/ currency rate_history(跨模块,无tenant,UNIQUE code+date)。
holding_transaction 加 realized_pnl_cents(FIFO 卖出实现收益)。
模块内 go generate 生成。server build 绿 + migrate 建表验证。"
```

---

## Task 3: repository(Snapshot/Lot/PriceHistory/RateHistory)+ domain 接口 + 集成测

**Files:**
- Modify: `yucai/server/internal/holding/domain/repository.go`(加 3 接口)
- Modify: `yucai/server/internal/currency/domain/repository.go`(加 RateHistoryRepository 接口)
- Create: `yucai/server/internal/holding/adapter/driven/repository/snapshot_repo.go`
- Create: `yucai/server/internal/holding/adapter/driven/repository/lot_repo.go`
- Create: `yucai/server/internal/holding/adapter/driven/repository/price_history_repo.go`
- Create: `yucai/server/internal/currency/adapter/driven/repository/rate_history_repo.go`
- Test: 各 repo `_test.go`(enttest 内存 sqlite)

**Interfaces:**
- Consumes: ent client(Task 2 生成的新表)、`domain.HoldingLot`/`SecurityPriceHistory`/`HoldingSnapshot`(Task 1)
- Produces(后续 task 依赖的接口方法):
  - `domain.SnapshotRepository`:`FindSnapshots(ctx, tenantID uuid.UUID, from, to time.Time, accountID, securityID *uuid.UUID) ([]HoldingSnapshot, error)` + `Save(ctx, HoldingSnapshot) error`
  - `domain.LotRepository`:`FindByHolding(ctx, holdingID uuid.UUID) ([]HoldingLot, error)`(按 AcquiredDate 升序)+ `SaveAll(ctx, lots []HoldingLot) error`(upsert)
  - `domain.PriceHistoryRepository`:`FindBySecurity(ctx, securityID uuid.UUID, from, to time.Time) ([]SecurityPriceHistory, error)` + `SaveAll(ctx, []SecurityPriceHistory) error` + `Exists(ctx, securityID uuid.UUID) (bool, error)`
  - `domain.RateHistoryRepository`(currency):`FindRate(ctx, code string, date time.Time) (float64, error)`(向前填充最近可用)+ `FindRange(ctx, code string, from, to time.Time) ([]RateHistory, error)` + `Save(ctx, RateHistory) error`
- Task 5(lot 维护)、Task 6(snapshot/curve/backfill)、Task 7(rate history 写入)依赖

**背景**:模式对齐 [trade_repo.go](../../yucai/server/internal/holding/adapter/driven/repository/trade_repo.go)(ent-backed repo)。先 Read trade_repo.go 确认 ent client 注入 + ent→domain mapping 惯例。关键非平凡逻辑:LotRepository.FindByHolding 按 acquired_date 升序(FIFO);RateHistoryRepository.FindRate 向前填充(节假日缺失)。

- [ ] **Step 1: Read trade_repo.go 确认 repo 模板**

```bash
cat /e/projects/syfinance/yucai/server/internal/holding/adapter/driven/repository/trade_repo.go
```
记下:构造函数签名(`NewTradeRepo(client *ent.Client)`?)、ent→domain mapping 函数、where 子句包名(`holdingtransaction.Xxx`)。**后续 4 个 repo 镜照此模式**。

- [ ] **Step 2: domain/repository.go 加 3 接口**

在 `domain/repository.go` 末尾(`TradeRepository` 之后)加:
```go
// SnapshotRepository persists daily holding market-value snapshots.
type SnapshotRepository interface {
	FindSnapshots(ctx context.Context, tenantID uuid.UUID, from, to time.Time, accountID, securityID *uuid.UUID) ([]HoldingSnapshot, error)
	Save(ctx context.Context, s HoldingSnapshot) error
}

// LotRepository persists FIFO cost lots. FindByHolding returns lots ordered
// by AcquiredDate ascending (FIFO consume order).
type LotRepository interface {
	FindByHolding(ctx context.Context, holdingID uuid.UUID) ([]HoldingLot, error)
	SaveAll(ctx context.Context, lots []HoldingLot) error
}

// PriceHistoryRepository persists daily security price history.
type PriceHistoryRepository interface {
	FindBySecurity(ctx context.Context, securityID uuid.UUID, from, to time.Time) ([]SecurityPriceHistory, error)
	SaveAll(ctx context.Context, ph []SecurityPriceHistory) error
	Exists(ctx context.Context, securityID uuid.UUID) (bool, error)
}
```
(确认 `time` + `uuid` 已 import;`context` 已有。)

currency `domain/repository.go` 加:
```go
// RateHistoryRepository persists daily exchange-rate history. FindRate
// forward-fills to the most recent rate at or before `date` (holiday gaps).
type RateHistoryRepository interface {
	FindRate(ctx context.Context, code string, date time.Time) (float64, error)
	FindRange(ctx context.Context, code string, from, to time.Time) ([]RateHistory, error)
	Save(ctx context.Context, r RateHistory) error
}
```
(currency domain 需加 `RateHistory` 实体 struct:`{ID uuid.UUID; CurrencyCode string; RateDate time.Time; ExchangeRate float64; CreatedAt time.Time}`,放 `currency/domain/entity.go`。)

- [ ] **Step 3: 写 price_history_repo.go(最简,先验证 ent 模式)**

`yucai/server/internal/holding/adapter/driven/repository/price_history_repo.go`:
```go
package repository

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/yucai/server/internal/holding/domain"
	"github.com/yucai/server/internal/holding/ent"
	"github.com/yucai/server/internal/holding/ent/securitypricehistory"
)

type PriceHistoryRepo struct {
	client *ent.Client
}

func NewPriceHistoryRepo(client *ent.Client) *PriceHistoryRepo {
	return &PriceHistoryRepo{client: client}
}

func (r *PriceHistoryRepo) FindBySecurity(ctx context.Context, securityID uuid.UUID, from, to time.Time) ([]domain.SecurityPriceHistory, error) {
	rows, err := r.client.SecurityPriceHistory.Query().
		Where(
			securitypricehistory.SecurityIDEQ(securityID),
			securitypricehistory.PriceDateGTE(from),
			securitypricehistory.PriceDateLTE(to),
		).
		Order(ent.Asc(securitypricehistory.FieldPriceDate)).
		All(ctx)
	if err != nil {
		return nil, err
	}
	out := make([]domain.SecurityPriceHistory, 0, len(rows))
	for _, row := range rows {
		out = append(out, domain.SecurityPriceHistory{
			ID: row.ID, SecurityID: row.SecurityID, PriceDate: row.PriceDate,
			PriceCents: row.PriceCents, CurrencyCode: row.CurrencyCode, Source: row.Source, CreatedAt: row.CreatedAt,
		})
	}
	return out, nil
}

func (r *PriceHistoryRepo) SaveAll(ctx context.Context, ph []domain.SecurityPriceHistory) error {
	bulk := make([]*ent.SecurityPriceHistoryCreate, 0, len(ph))
	for _, p := range ph {
		bulk = append(bulk, r.client.SecurityPriceHistory.Create().
			SetSecurityID(p.SecurityID).SetPriceDate(p.PriceDate).
			SetPriceCents(p.PriceCents).SetCurrencyCode(p.CurrencyCode).SetSource(p.Source))
	}
	return r.client.SecurityPriceHistory.CreateBulk(bulk...).Exec(ctx)
}

func (r *PriceHistoryRepo) Exists(ctx context.Context, securityID uuid.UUID) (bool, error) {
	return r.client.SecurityPriceHistory.Query().Where(securitypricehistory.SecurityIDEQ(securityID)).Exist(ctx)
}
```
> ⚠️ ent 生成的 where 包名 + 字段常量(`securitypricehistory.SecurityIDEQ` / `FieldPriceDate`)以 Task 2 生成的为准 —— Read `ent/securitypricehistory/where.go` 确认确切名。SaveAll 的 `CreateBulk` 忽略 UNIQUE 冲突(回填幂等:若已存在同日,先 Query 排除或用 upsert;首批回填空表,冲突少,简单 CreateBulk + 错误容忍即可)。

- [ ] **Step 4: 写 lot_repo.go(FIFO 关键:FindByHolding 升序)**

`yucai/server/internal/holding/adapter/driven/repository/lot_repo.go`:
```go
package repository

import (
	"context"

	"github.com/google/uuid"

	"github.com/yucai/server/internal/holding/domain"
	"github.com/yucai/server/internal/holding/ent"
	"github.com/yucai/server/internal/holding/ent/holdinglot"
)

type LotRepo struct {
	client *ent.Client
}

func NewLotRepo(client *ent.Client) *LotRepo {
	return &LotRepo{client: client}
}

// FindByHolding returns all lots for a holding ordered by AcquiredDate ASC
// (FIFO consume order). Closed lots (remaining=0) included for audit.
func (r *LotRepo) FindByHolding(ctx context.Context, holdingID uuid.UUID) ([]domain.HoldingLot, error) {
	rows, err := r.client.HoldingLot.Query().
		Where(holdinglot.HoldingIDEQ(holdingID)).
		Order(ent.Asc(holdinglot.FieldAcquiredDate)).
		All(ctx)
	if err != nil {
		return nil, err
	}
	out := make([]domain.HoldingLot, 0, len(rows))
	for _, row := range rows {
		out = append(out, domain.HoldingLot{
			ID: row.ID, TenantID: row.TenantID, HoldingID: row.HoldingID, SecurityID: row.SecurityID,
			AcquiredDate: row.AcquiredDate, AcquiredTradeID: row.AcquiredTradeID,
			PriceCents: row.PriceCents, Quantity: row.Quantity, RemainingQuantity: row.RemainingQuantity,
		})
	}
	return out, nil
}

// SaveAll upserts lots (create or update remaining_quantity). Used by
// BuyHolding (create new lot), SellHolding (update remaining after FIFO
// consume), RecordSplit (update quantity/remaining by ratio).
func (r *LotRepo) SaveAll(ctx context.Context, lots []domain.HoldingLot) error {
	for _, l := range lots {
		if l.ID == uuid.Nil {
			// New lot (buy): create.
			if _, err := r.client.HoldingLot.Create().
				SetTenantID(l.TenantID).SetHoldingID(l.HoldingID).SetSecurityID(l.SecurityID).
				SetAcquiredDate(l.AcquiredDate).SetAcquiredTradeID(l.AcquiredTradeID).
				SetPriceCents(l.PriceCents).SetQuantity(l.Quantity).SetRemainingQuantity(l.RemainingQuantity).
				Save(ctx); err != nil {
				return err
			}
			continue
		}
		// Existing lot (sell/split): update remaining + quantity.
		if err := r.client.HoldingLot.UpdateOneID(l.ID).
			SetRemainingQuantity(l.RemainingQuantity).SetQuantity(l.Quantity).
			Exec(ctx); err != nil {
			return err
		}
	}
	return nil
}
```

- [ ] **Step 5: 写 snapshot_repo.go**

`yucai/server/internal/holding/adapter/driven/repository/snapshot_repo.go`:
```go
package repository

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/yucai/server/internal/holding/domain"
	"github.com/yucai/server/internal/holding/ent"
	"github.com/yucai/server/internal/holding/ent/holdingsnapshot"
)

type SnapshotRepo struct {
	client *ent.Client
}

func NewSnapshotRepo(client *ent.Client) *SnapshotRepo {
	return &SnapshotRepo{client: client}
}

func (r *SnapshotRepo) FindSnapshots(ctx context.Context, tenantID uuid.UUID, from, to time.Time, accountID, securityID *uuid.UUID) ([]domain.HoldingSnapshot, error) {
	q := r.client.HoldingSnapshot.Query().Where(
		holdingsnapshot.TenantIDEQ(tenantID),
		holdingsnapshot.SnapshotDateGTE(from),
		holdingsnapshot.SnapshotDateLTE(to),
	)
	if accountID != nil {
		q = q.Where(holdingsnapshot.AccountIDEQ(*accountID))
	}
	if securityID != nil {
		q = q.Where(holdingsnapshot.SecurityIDEQ(*securityID))
	}
	rows, err := q.Order(ent.Asc(holdingsnapshot.FieldSnapshotDate)).All(ctx)
	if err != nil {
		return nil, err
	}
	out := make([]domain.HoldingSnapshot, 0, len(rows))
	for _, row := range rows {
		out = append(out, domain.HoldingSnapshot{
			ID: row.ID, TenantID: row.TenantID, HoldingID: row.HoldingID, SecurityID: row.SecurityID,
			AccountID: row.AccountID, SnapshotDate: row.SnapshotDate,
			MarketValueCents: row.MarketValueCents, UnrealizedPnlCents: row.UnrealizedPnlCents,
			CurrencyCode: row.CurrencyCode, CreatedAt: row.CreatedAt,
		})
	}
	return out, nil
}

func (r *SnapshotRepo) Save(ctx context.Context, s domain.HoldingSnapshot) error {
	return r.client.HoldingSnapshot.Create().
		SetTenantID(s.TenantID).SetHoldingID(s.HoldingID).SetSecurityID(s.SecurityID).
		SetAccountID(s.AccountID).SetSnapshotDate(s.SnapshotDate).
		SetMarketValueCents(s.MarketValueCents).SetUnrealizedPnlCents(s.UnrealizedPnlCents).
		SetCurrencyCode(s.CurrencyCode).Exec(ctx)
}
```
> ⚠️ where 包名 + 字段常量以 Task 2 生成为准(Read `ent/holdingsnapshot/where.go`)。

- [ ] **Step 6: 写 rate_history_repo.go(currency,向前填充关键)**

`yucai/server/internal/currency/adapter/driven/repository/rate_history_repo.go`:
```go
package repository

import (
	"context"
	"time"

	"github.com/yucai/server/internal/currency/domain"
	"github.com/yucai/server/internal/currency/ent"
	"github.com/yucai/server/internal/currency/ent/ratehistory"
)

type RateHistoryRepo struct {
	client *ent.Client
}

func NewRateHistoryRepo(client *ent.Client) *RateHistoryRepo {
	return &RateHistoryRepo{client: client}
}

// FindRate returns the exchange rate for `date`, forward-filling to the most
// recent rate at or before `date` (handles weekend/holiday gaps). Returns 1.0
// for base currency CNY if no history yet (graceful degradation).
func (r *RateHistoryRepo) FindRate(ctx context.Context, code string, date time.Time) (float64, error) {
	row, err := r.client.RateHistory.Query().
		Where(
			ratehistory.CurrencyCodeEQ(code),
			ratehistory.RateDateLTE(date),
		).
		Order(ent.Desc(ratehistory.FieldRateDate)).
		First(ctx)
	if err != nil {
		if ent.IsNotFound(err) {
			return 1.0, nil // no history: assume base/no conversion (logged by caller)
		}
		return 0, err
	}
	return row.ExchangeRate, nil
}

func (r *RateHistoryRepo) FindRange(ctx context.Context, code string, from, to time.Time) ([]domain.RateHistory, error) {
	rows, err := r.client.RateHistory.Query().
		Where(ratehistory.CurrencyCodeEQ(code), ratehistory.RateDateGTE(from), ratehistory.RateDateLTE(to)).
		Order(ent.Asc(ratehistory.FieldRateDate)).All(ctx)
	if err != nil {
		return nil, err
	}
	out := make([]domain.RateHistory, 0, len(rows))
	for _, row := range rows {
		out = append(out, domain.RateHistory{
			ID: row.ID, CurrencyCode: row.CurrencyCode, RateDate: row.RateDate,
			ExchangeRate: row.ExchangeRate, CreatedAt: row.CreatedAt,
		})
	}
	return out, nil
}

func (r *RateHistoryRepo) Save(ctx context.Context, rh domain.RateHistory) error {
	return r.client.RateHistory.Create().
		SetCurrencyCode(rh.CurrencyCode).SetRateDate(rh.RateDate).
		SetExchangeRate(rh.ExchangeRate).Exec(ctx)
}
```
> ⚠️ `ent.IsNotFound` + `First` 是 ent 标准;where 包名以生成为准。

- [ ] **Step 7: 写集成测(参照现有 repo test 的 enttest 模式)**

```bash
ls /e/projects/syfinance/yucai/server/internal/holding/adapter/driven/repository/*_test.go
```
Read 一个现有 repo test,照其 `enttest` 内存 sqlite + 构造 client 模式。给 `lot_repo_test.go`(FIFO 排序 + SaveAll create/update)+ `price_history_repo_test.go`(FindBySecurity 范围 + Exists)+ `snapshot_repo_test.go`(FindSnapshots accountID/securityID 筛选)各 1-2 个关键测。rate_history_repo_test.go(FindRate 向前填充 + 缺失返回 1.0)。关键测代码示例(lot):
```go
func TestLotRepoFindByHoldingOrdersByAcquiredDateAsc(t *testing.T) {
	client := openTestClient(t) // 照现有 repo test 的 enttest helper
	defer client.Close()
	ctx := context.Background()
	holding := uuid.New()
	// insert 2 lots out of order (newer first), expect ASC by acquired_date
	client.HoldingLot.Create().SetHoldingID(holding).SetAcquiredDate(day("2025-01-05")).SetPriceCents(11000).SetQuantity(40).SetRemainingQuantity(40).SaveX(ctx)
	client.HoldingLot.Create().SetHoldingID(holding).SetAcquiredDate(day("2025-01-02")).SetPriceCents(10000).SetQuantity(60).SetRemainingQuantity(60).SaveX(ctx)
	repo := NewLotRepo(client)
	got, err := repo.FindByHolding(ctx, holding)
	if err != nil { t.Fatal(err) }
	if len(got) != 2 || !got[0].AcquiredDate.Before(got[1].AcquiredDate) {
		t.Fatalf("lots not ASC by acquired_date: %+v", got)
	}
}
```
(`openTestClient` / `day` helper 照现有 repo test。)

- [ ] **Step 8: 跑测试 + build**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/adapter/driven/repository/ ./internal/currency/adapter/driven/repository/ -v -count=1
cd /e/projects/syfinance/yucai/server && go build ./...
```
Expected:PASS(repo 集成测)+ build 绿。

- [ ] **Step 9: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/internal/holding/domain/repository.go yucai/server/internal/currency/domain/ yucai/server/internal/holding/adapter/driven/repository/ yucai/server/internal/currency/adapter/driven/repository/
git commit -m "feat(holding-c-server): 4 repository(snapshot/lot/price_history/rate_history)

domain 加 Snapshot/Lot/PriceHistory 接口(holding)+ RateHistory(currency,
含 RateHistory 实体)。ent-backed 镜像 trade_repo 模式。关键:LotRepo.
FindByHolding 按 acquired_date ASC(FIFO),RateHistoryRepo.FindRate 向前填充
(节假日)+ 缺失返回 1.0。集成测(enttest 内存)。"
```

---

## Task 4: priceprovider HistoricalProvider + SinaProvider.FetchHistory + httptest

**Files:**
- Create: `yucai/server/internal/holding/adapter/driven/priceprovider/history.go`
- Modify: `yucai/server/internal/holding/adapter/driven/priceprovider/sina.go`(加 FetchHistory)
- Test: `yucai/server/internal/holding/adapter/driven/priceprovider/history_test.go`

**Interfaces:**
- Consumes: `priceprovider.PriceView`、`ErrNoSource`(B Task 2 已建)
- Produces:
  - `priceprovider.HistoryPoint` struct:`{Date time.Time; PriceCents int64}`
  - `priceprovider.HistoricalProvider` 接口 `FetchHistory(ctx, v PriceView, datalen int) ([]HistoryPoint, error)` — datalen = K 线根数(DAY 30 / MONTH 250 / YEAR 1200)
  - `SinaProvider.FetchHistory`(实现 HistoricalProvider)—— 拉新浪日 K JSONP,UTF-8 解析
- Task 6(BackfillPriceHistory)依赖

**背景**:历史 K 线接口与实时 hq.sinajs.cn 不同(见 Global Constraints):JSONP 包裹的 JSON 数组,UTF-8 非 GBK。httptest mock 该格式。Router 不路由历史(回填直接用 Sina)。

- [ ] **Step 1: 写失败测试 history_test.go**

`yucai/server/internal/holding/adapter/driven/priceprovider/history_test.go`:
```go
package priceprovider

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

// sinaKLine builds a fake CN_MarketDataService.getKLineData JSONP response.
// Format: var _=<json array>  where each el is {"day":"YYYY-MM-DD","close":...}
func sinaKLine(closes map[string]float64) []byte {
	body := `var _=[`
	first := true
	// deterministic order by date
	for d := range closes {
		_ = d
	}
	// build deterministically from an ordered slice instead:
	return []byte(sinaKLineOrdered(closes))
}

func sinaKLineOrdered(closes map[string]float64) string {
	// fixed ordered sample (test keeps it small and deterministic)
	type pt struct{ day string; close float64 }
	pts := []pt{}
	for d, c := range closes {
		pts = append(pts, pt{d, c})
	}
	// sort by day for determinism
	for i := 0; i < len(pts); i++ {
		for j := i + 1; j < len(pts); j++ {
			if pts[j].day < pts[i].day {
				pts[i], pts[j] = pts[j], pts[i]
			}
		}
	}
	out := `var _=[`
	for i, p := range pts {
		if i > 0 {
			out += ","
		}
		out += `{"day":"` + p.day + `","open":"1","high":"1","low":"1","close":"` + floatStr(p.close) + `","volume":"0"}`
	}
	out += `];`
	return out
}

func floatStr(f float64) string {
	if f == float64(int64(f)) {
		return strconvFormatFloat2(f)
	}
	return strconvFormatFloat2(f)
}

func TestSinaFetchHistoryNotCoveredExchange(t *testing.T) {
	p := NewSinaProvider()
	for _, ex := range []string{"NASDAQ", "OTC", ""} {
		_, err := p.FetchHistory(context.Background(), PriceView{Symbol: "X", Exchange: ex}, 30)
		if !errors.Is(err, ErrNoSource) {
			t.Fatalf("exchange %q must be ErrNoSource; got %v", ex, err)
		}
	}
}

func TestSinaFetchHistoryParsesKLine(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// assert symbol passed in query
		if q := r.URL.Query().Get("symbol"); q != "sh600519" {
			t.Errorf("symbol query = %q, want sh600519", q)
		}
		_, _ = w.Write([]byte(sinaKLineOrdered(map[string]float64{
			"2025-01-02": 100.0,
			"2025-01-03": 102.50,
		})))
	}))
	defer srv.Close()

	p := newSinaProviderWithURL(srv.URL)
	pts, err := p.FetchHistory(context.Background(), PriceView{Symbol: "600519", Exchange: "SSE"}, 30)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(pts) != 2 {
		t.Fatalf("got %d points, want 2", len(pts))
	}
	if pts[0].PriceCents != 10000 {
		t.Fatalf("pts[0] = %d cents, want 10000 (100.00)", pts[0].PriceCents)
	}
	if pts[1].PriceCents != 10250 {
		t.Fatalf("pts[1] = %d cents, want 10250 (102.50)", pts[1].PriceCents)
	}
	want, _ := time.Parse("2006-01-02", "2025-01-02")
	if !pts[0].Date.Equal(want) {
		t.Fatalf("pts[0].Date = %v, want %v", pts[0].Date, want)
	}
}

func TestSinaFetchHistoryHttpError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer srv.Close()
	p := newSinaProviderWithURL(srv.URL)
	_, err := p.FetchHistory(context.Background(), PriceView{Symbol: "600519", Exchange: "SSE"}, 30)
	if err == nil || errors.Is(err, ErrNoSource) {
		t.Fatalf("HTTP 500 must be real error; got %v", err)
	}
}
```
> 注:`strconvFormatFloat2` 用 `strconv.FormatFloat(f, 'f', 2, 64)` —— 在测试文件顶部加 helper(或直接内联)。实现 Step 3 时清理。

- [ ] **Step 2: 跑测试验证 FAIL**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/adapter/driven/priceprovider/ -run FetchHistory -v -count=1
```
Expected:FAIL / 编译错误(`FetchHistory`/`HistoricalProvider`/`HistoryPoint` 未定义)。

- [ ] **Step 3: 写 history.go(接口 + HistoryPoint)**

`yucai/server/internal/holding/adapter/driven/priceprovider/history.go`:
```go
package priceprovider

import (
	"context"
	"time"
)

// HistoryPoint is one daily price from a historical fetch (backfill).
type HistoryPoint struct {
	Date       time.Time
	PriceCents int64
}

// HistoricalProvider fetches daily K-line history for backfill. Only
// SinaProvider implements this (A-share + CSI300). The application calls it
// directly (not via Router) during backfill; non-covered exchanges return
// ErrNoSource.
type HistoricalProvider interface {
	FetchHistory(ctx context.Context, v PriceView, datalen int) ([]HistoryPoint, error)
}
```

- [ ] **Step 4: sina.go 加 FetchHistory(实现 HistoricalProvider)**

在 `sina.go` 末尾加:
```go
import (
	"encoding/json"
	// 保留现有 import;新增 encoding/json + strings(已有)
)

// kLineItem matches the CN_MarketDataService.getKLineData JSON shape.
type kLineItem struct {
	Day   string `json:"day"`   // "YYYY-MM-DD"
	Close string `json:"close"` // string in JSONP, e.g. "102.500"
}

// FetchHistory fetches daily K-line history from Sina
// (CN_MarketDataService.getKLineData). datalen = number of bars (DAY 30 /
// MONTH 250 / YEAR 1200). Response is JSONP-wrapped UTF-8 JSON array (NOT GBK,
// unlike realtime hq.sinajs.cn). Only SSE/SZSE covered; others ErrNoSource.
func (p *SinaProvider) FetchHistory(ctx context.Context, v PriceView, datalen int) ([]HistoryPoint, error) {
	listKey, ok := sinaListKey(v.Exchange, v.Symbol)
	if !ok {
		return nil, ErrNoSource
	}
	url := p.baseURLKLine() + "?symbol=" + listKey +
		"&scale=240&ma=no&datalen=" + strconv.Itoa(datalen)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("sina history build request: %w", err)
	}
	req.Header.Set("Referer", "https://finance.sina.com.cn")

	resp, err := p.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("sina history request: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("sina history status %d", resp.StatusCode)
	}

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("sina history read body: %w", err)
	}
	// Strip JSONP wrapper "var _=<json>;" → extract the JSON array.
	jsonStr := extractJSONPArray(string(raw))
	var items []kLineItem
	if err := json.Unmarshal([]byte(jsonStr), &items); err != nil {
		return nil, fmt.Errorf("sina history parse json: %w", err)
	}
	pts := make([]HistoryPoint, 0, len(items))
	for _, it := range items {
		day, err := time.Parse("2006-01-02", it.Day)
		if err != nil {
			continue // skip malformed
		}
		closeF, err := strconv.ParseFloat(it.Close, 64)
		if err != nil {
			continue
		}
		pts = append(pts, HistoryPoint{Date: day, PriceCents: int64(math.Round(closeF * 100))})
	}
	return pts, nil
}

// baseURLKLine returns the historical K-line endpoint (different host from
// realtime hq.sinajs.cn). Test seam: if newSinaProviderWithURL set a baseURL,
// reuse it (httptest points at one server for both endpoints in tests).
func (p *SinaProvider) baseURLKLine() string {
	if p.baseURL != "http://hq.sinajs.cn" {
		return p.baseURL // test seam: httptest server handles both paths
	}
	return "https://quotes.sina.cn/cn/api/jsonp.php/var_/CN_MarketDataService.getKLineData"
}

// extractJSONPArray extracts the JSON array from a "var _=[...];" JSONP wrapper.
func extractJSONPArray(s string) string {
	open := strings.Index(s, "[")
	closeBracket := strings.LastIndex(s, "]")
	if open < 0 || closeBracket < 0 || closeBracket < open {
		return "[]"
	}
	return s[open : closeBracket+1]
}
```
> ⚠️ 实现时把新增 import(`encoding/json`)加到 sina.go 现有 import 块(不重复已有 `fmt`/`io`/`math`/`net/http`/`strconv`/`strings`/`time`)。`baseURLKLine` 的 test-seam 逻辑让 httptest 单 server 同时服务 realtime + history(测试用 newSinaProviderWithURL(srv.URL),FetchHistory 也走 srv.URL)。

- [ ] **Step 5: 清理测试 helper(用 strconv.FormatFloat 直接构造,删 floatStr/strconvFormatFloat2 wrapper)**

把 `history_test.go` 的 `sinaKLineOrdered` 里 `floatStr(p.close)` 改为 `strconv.FormatFloat(p.close, 'f', 2, 64)`,删 `floatStr`/`strconvFormatFloat2`,加 `import "strconv"`。

- [ ] **Step 6: 跑测试验证 PASS**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/adapter/driven/priceprovider/ -v -count=1
```
Expected:PASS(B 的 9 测 + Task 4 的 3 测 = 12)。

- [ ] **Step 7: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/internal/holding/adapter/driven/priceprovider/
git commit -m "feat(holding-c-server): HistoricalProvider+SinaProvider.FetchHistory(新浪日K)

HistoricalProvider 接口 + HistoryPoint。SinaProvider.FetchHistory 拉
CN_MarketDataService.getKLineData JSONP(UTF-8 非 GBK,与实时不同),
解析 [{day,close}] → cents。覆盖 SSE/SZSE + 基准 sh000300。httptest 3 单测
(不覆盖/正常解析/HTTP错误)。Router 不路由历史,回填直接用 Sina。"
```

---

## Task 5: application Buy/Sell/Split FIFO lot 维护 + realized 落 trade + CSI300 seed + SyncPrices 写 price_history

**Files:**
- Modify: `yucai/server/internal/holding/domain/entity.go`(HoldingTransaction 加 RealizedPnLCents 字段)
- Modify: `yucai/server/internal/holding/application/service.go`(struct 加 4 字段 + 4 setter + 改 Buy/Sell/Split + SeedSecurities 加 CSI300 + SyncPrices 加 price_history)
- Modify: `yucai/server/internal/holding/application/dto.go`(HoldingTransactionDTO 加 RealizedPnLCents + TradeToDTO 映射)
- Test: `yucai/server/internal/holding/application/service_test.go`

**Interfaces:**
- Consumes: `domain.ConsumeLotsFIFO`/`LotAvgCost`(Task 1)、`domain.LotRepository`/`PriceHistoryRepository`/`SnapshotRepository`(Task 3)
- Produces:Service 持有 lot/snapshot/priceHistory repo;Buy/Sell/Split 维护 FIFO lot;realized 落 `HoldingTransaction.RealizedPnLCents`;SeedSecurities 含 CSI300;SyncPrices 顺手写 price_history。Task 6/7 依赖

**背景**:基于 [service.go](../../yucai/server/internal/holding/application/service.go) 现有 BuyHolding(line 73)/SellHolding(line 105)/RecordSplit(line 154)精确签名改造。**split lot 修正(spec §4③ 漏)**:lot split 时 `Quantity×ratio + RemainingQuantity×ratio + PriceCents/ratio`(split-adjusted cost,保持每股成本语义,FIFO realized 正确)。

- [ ] **Step 1: domain entity.go — HoldingTransaction 加 RealizedPnLCents**

在 `entity.go` 的 `HoldingTransaction` struct(line 116-130)加字段(在 `FeeCents` 之后):
```go
	RealizedPnLCents int64 // FIFO realized P&L on sell (0 for buy/dividend/split)
```

- [ ] **Step 2: dto.go — HoldingTransactionDTO 加字段 + TradeToDTO 映射**

`HoldingTransactionDTO`(line 79-91)加 `RealizedPnLCents int64`(在 `FeeCents` 后)。`TradeToDTO`(line 125)加 `RealizedPnLCents: tr.RealizedPnLCents,`。

- [ ] **Step 3: service.go struct 加 4 字段 + setter**

改 `Service` struct(line 16-21):
```go
type Service struct {
	securityRepo    domain.SecurityRepository
	holdingRepo     domain.HoldingRepository
	tradeRepo       domain.TradeRepository
	priceRouter     priceprovider.Router        // B: SyncPrices
	lotRepo         domain.LotRepository         // C: FIFO lot (nil = fallback to ApplySell)
	snapshotRepo    domain.SnapshotRepository    // C: daily snapshot
	priceHistoryRepo domain.PriceHistoryRepository // C: price history + backfill gate
	historicalProvider priceprovider.HistoricalProvider // C: backfill
	rateRepo        domain.RateHistoryRepository // C: portfolio curve CNY折算 (cross-module currency interface)
}
```
> `domain.RateHistoryRepository` 定义在 currency 模块(Task 3)。holding application 引用它 —— 为避免 holding→currency 包依赖,在 **holding/domain/repository.go** 定义一个 holding 本地的 `RateHistoryRepository` 接口(同 FindRate/FindRange 签名),由 currency 的 RateHistoryRepo 实现注入(Go 结构类型,无需显式 implements)。这样 holding 不 import currency。

holding/domain/repository.go 加:
```go
// RateHistoryRepository reads exchange-rate history for CNY折算. Implemented
// by currency's RateHistoryRepo (structural type — holding does not import currency).
type RateHistoryRepository interface {
	FindRate(ctx context.Context, code string, date time.Time) (float64, error)
	FindRange(ctx context.Context, code string, from, to time.Time) (map[time.Time]float64, error) // date→rate
}
```
(`FindRange` 返回 map 便于查询时 O(1) 查 rate;currency repo 的 FindRange 返回 []RateHistory,在 wire 注入处包一个 adapter 转 map,或 holding 接口直接定义返回 []RateHistory —— 选 map 更易用,adapter 在 Task 9 wire 写。)

在 service.go `SetPriceRouter`(line 291)之后加 4 setter:
```go
func (s *Service) SetLotRepository(r domain.LotRepository)                 { s.lotRepo = r }
func (s *Service) SetSnapshotRepository(r domain.SnapshotRepository)       { s.snapshotRepo = r }
func (s *Service) SetPriceHistoryRepository(r domain.PriceHistoryRepository) { s.priceHistoryRepo = r }
func (s *Service) SetHistoricalProvider(p priceprovider.HistoricalProvider) { s.historicalProvider = p }
func (s *Service) SetRateHistoryRepository(r domain.RateHistoryRepository)  { s.rateRepo = r }
```

- [ ] **Step 4: 改 BuyHolding(加 lot 创建 + AvgCost 派生)**

把 `BuyHolding`(line 73-102)整体替换为:
```go
func (s *Service) BuyHolding(ctx context.Context, req HoldingTradeRequest) (*HoldingTransactionDTO, error) {
	h, err := s.holdingRepo.FindByAccountAndSecurity(ctx, req.TenantID, req.AccountID, req.SecurityID)
	if err != nil {
		h = &domain.Holding{
			ID: uuid.New(), TenantID: req.TenantID,
			AccountID: req.AccountID, SecurityID: req.SecurityID,
		}
	}
	h.ApplyBuy(req.Quantity, req.PriceCents)

	tradeID := uuid.New()
	newLot := domain.HoldingLot{
		ID: uuid.New(), TenantID: req.TenantID, HoldingID: h.ID, SecurityID: req.SecurityID,
		AcquiredDate: req.TradeDate, AcquiredTradeID: tradeID,
		PriceCents: req.PriceCents, Quantity: req.Quantity, RemainingQuantity: req.Quantity,
	}
	// AvgCost from FIFO lots (existing + new), consistent with lot state.
	if s.lotRepo != nil {
		existing, _ := s.lotRepo.FindByHolding(ctx, h.ID)
		h.AvgCostCents = domain.LotAvgCost(append(existing, newLot))
	}

	if err := s.holdingRepo.SaveOrUpdate(ctx, h); err != nil {
		return nil, fmt.Errorf("save holding: %w", err)
	}

	trade := &domain.HoldingTransaction{
		ID: tradeID, TenantID: req.TenantID,
		AccountID: req.AccountID, SecurityID: req.SecurityID,
		TradeType: domain.TradeTypeBuy, Quantity: req.Quantity,
		PriceCents: req.PriceCents, AmountCents: int64(float64(req.PriceCents) * req.Quantity),
		FeeCents: req.FeeCents, TradeDate: req.TradeDate, Notes: req.Notes,
		CreatedAt: h.UpdatedAt,
	}
	if err := s.tradeRepo.Save(ctx, trade); err != nil {
		return nil, fmt.Errorf("save trade: %w", err)
	}
	if s.lotRepo != nil {
		if err := s.lotRepo.SaveAll(ctx, []domain.HoldingLot{newLot}); err != nil {
			return nil, fmt.Errorf("save buy lot: %w", err)
		}
	}

	dto := TradeToDTO(trade)
	return &dto, nil
}
```

- [ ] **Step 5: 改 SellHolding(FIFO + realized 落 trade)**

把 `SellHolding`(line 105-134)替换为:
```go
func (s *Service) SellHolding(ctx context.Context, req HoldingTradeRequest) (*HoldingTransactionDTO, error) {
	h, err := s.holdingRepo.FindByAccountAndSecurity(ctx, req.TenantID, req.AccountID, req.SecurityID)
	if err != nil {
		return nil, fmt.Errorf("holding not found: %w", err)
	}

	var realized int64
	if s.lotRepo != nil {
		lots, err := s.lotRepo.FindByHolding(ctx, h.ID)
		if err != nil {
			return nil, fmt.Errorf("load lots: %w", err)
		}
		realized, consumed, err := domain.ConsumeLotsFIFO(req.Quantity, req.PriceCents, lots)
		if err != nil {
			return nil, err
		}
		// Apply consumption in-memory, then persist.
		consumedByID := map[uuid.UUID]float64{}
		for _, c := range consumed {
			consumedByID[c.LotID] = c.ConsumedQuantity
		}
		for i := range lots {
			lots[i].RemainingQuantity -= consumedByID[lots[i].ID]
		}
		if err := s.lotRepo.SaveAll(ctx, lots); err != nil {
			return nil, fmt.Errorf("save lots after sell: %w", err)
		}
		// Oversell guard + qty decrement via ApplySell (its moving-weighted realized ignored).
		if _, err := h.ApplySell(req.Quantity, req.PriceCents); err != nil {
			return nil, err
		}
		h.AvgCostCents = domain.LotAvgCost(lots) // consistent with FIFO remaining lots
	} else {
		realized, err = h.ApplySell(req.Quantity, req.PriceCents) // fallback (no lot repo)
		if err != nil {
			return nil, err
		}
	}

	if err := s.holdingRepo.SaveOrUpdate(ctx, h); err != nil {
		return nil, fmt.Errorf("save holding: %w", err)
	}

	trade := &domain.HoldingTransaction{
		ID: uuid.New(), TenantID: req.TenantID,
		AccountID: req.AccountID, SecurityID: req.SecurityID,
		TradeType: domain.TradeTypeSell, Quantity: req.Quantity,
		PriceCents: req.PriceCents, AmountCents: int64(float64(req.PriceCents) * req.Quantity),
		FeeCents: req.FeeCents, TradeDate: req.TradeDate, Notes: req.Notes,
		RealizedPnLCents: realized, CreatedAt: h.UpdatedAt,
	}
	if err := s.tradeRepo.Save(ctx, trade); err != nil {
		return nil, fmt.Errorf("save trade: %w", err)
	}
	dto := TradeToDTO(trade)
	return &dto, nil
}
```

- [ ] **Step 6: 改 RecordSplit(lot split-adjusted)**

把 `RecordSplit`(line 154-177)中 `h.ApplySplit(req.Ratio)` 前后加 lot 调整:
```go
	// FIFO lot split-adjust: quantity×ratio + remaining×ratio + price/ratio
	// (keeps per-share cost correct so post-split FIFO realized is right).
	if s.lotRepo != nil {
		lots, err := s.lotRepo.FindByHolding(ctx, h.ID)
		if err != nil {
			return nil, fmt.Errorf("load lots for split: %w", err)
		}
		for i := range lots {
			lots[i].Quantity *= req.Ratio
			lots[i].RemainingQuantity *= req.Ratio
			if req.Ratio > 0 {
				lots[i].PriceCents = int64(math.Round(float64(lots[i].PriceCents) / req.Ratio))
			}
		}
		if err := s.lotRepo.SaveAll(ctx, lots); err != nil {
			return nil, fmt.Errorf("save lots after split: %w", err)
		}
	}
	h.ApplySplit(req.Ratio)
```
(在 `h.ApplySplit` 前插入 lot 块;`math` 已 import 于 entity.go,service.go 需加 `import "math"` 若未有。)

- [ ] **Step 7: SeedSecurities 加 CSI300 基准**

在 `seedSecurities`(line 221-229)数组末尾加:
```go
	{"000300", "沪深300指数", domain.SecurityTypeIndex, "SSE", "CNY", 3800},
```
> ⚠️ 确认 `domain.SecurityTypeIndex` 存在(Read `domain/valueobject.go` 的 SecurityType 枚举)。若枚举无 INDEX,加 `SecurityTypeIndex SecurityType = <next>`(在 valueobject.go)。CSI300 是指数,type=INDEX,exchange=SSE(symbol 000300 走 sh000300)。

- [ ] **Step 8: SyncPrices 加 price_history 写入(B 顺手写)**

在 `SyncPrices`(line 300-343)的 `s.securityRepo.UpdatePrice(ctx, sec.ID, price)` 成功后(line 334 `synced++` 之前),加:
```go
				// C: record daily price history point (idempotent upsert).
				if s.priceHistoryRepo != nil {
					ph := domain.SecurityPriceHistory{
						SecurityID: sec.ID, PriceDate: truncateToDate(time.Now()),
						PriceCents: price, CurrencyCode: sec.CurrencyCode, Source: "sina",
					}
					if err := s.priceHistoryRepo.Save(ctx, ph); err != nil {
						slog.Warn("holding price sync: save history failed",
							slog.String("symbol", sec.Symbol), slog.String("error", err.Error()),
							slog.String("operation", "SyncPrices"))
						// not fatal — price_history missing just means thinner curves
					}
				}
```
> `Save` 需在 PriceHistoryRepository 加单条 `Save(ctx, SecurityPriceHistory)` 方法(Task 3 只给了 SaveAll+Exists;Step 9 补 Save)。`truncateToDate` 截断到当日 00:00 UTC(避免时分秒致 UNIQUE 冲突)。在 service.go 加 helper:
```go
func truncateToDate(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}
```

- [ ] **Step 9: PriceHistoryRepository 补 Save 单条 + UNIQUE 容忍**

Task 3 的 price_history_repo.go 加(若 Step 3 没加):
```go
// Save inserts one price history row. Ignores UNIQUE(security_id,price_date)
// conflict (idempotent — same-day re-sync from B scheduler).
func (r *PriceHistoryRepo) Save(ctx context.Context, p domain.SecurityPriceHistory) error {
	_, err := r.client.SecurityPriceHistory.Create().
		SetSecurityID(p.SecurityID).SetPriceDate(p.PriceDate).
		SetPriceCents(p.PriceCents).SetCurrencyCode(p.CurrencyCode).SetSource(p.Source).
		Save(ctx)
	return err
}
```
(UNIQUE 冲突:ent 默认返回错误;B scheduler 每日一次,冲突少。若需严格幂等,Save 前 Query Exists(security+date) 跳过 —— 首批简单 Save + 日志容忍。domain 接口加 `Save(ctx, SecurityPriceHistory) error`。)

- [ ] **Step 10: 写测试(service_test.go 追加)**

复用 B 的 `fakeSecurityRepo`/`newTestServiceWithSecurities` 模式,加 fake lot/snapshot/priceHistory repo(实现 domain 接口,内存 map)。关键测:
```go
func TestBuyHoldingCreatesLotAndDerivesAvgCost(t *testing.T) {
	// seed: existing lot 60@100. Buy 40@120.
	// expect: new lot created (40@120), avg cost = (60*100+40*120)/100 = 10400
}

func TestSellHoldingFIFORealizedLandedOnTrade(t *testing.T) {
	// seed lots: 60@100 (older), 40@110 (newer). Sell 80@130.
	// expect: realized = (130-100)*60 + (130-110)*20 = 2200;
	//         trade.RealizedPnLCents == 2200;
	//         lot1 remaining=0, lot2 remaining=20; avg cost = 11000 (only lot2 left)
}

func TestRecordSplitAdjustsLots(t *testing.T) {
	// seed lot 100@100. Split ratio 2.
	// expect: lot quantity=200, remaining=200, price=5000 (100/2);
	//         holding avg cost consistent
}
```
(fake repo 实现参照 B 的 fakeSecurityRepo:内存 map + 实现 domain 接口所有方法,未用方法 panic。)

- [ ] **Step 11: build + test + 回归**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/application/ -run "Buy|Sell|Split" -v -count=1
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/... -count=1
cd /e/projects/syfinance/yucai/server && go build ./...
```
Expected:新测 PASS;现有测(A 的 + B 的 SyncPrices)回归全过;build 绿。

- [ ] **Step 12: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/internal/holding/domain/entity.go yucai/server/internal/holding/application/ yucai/server/internal/holding/adapter/driven/repository/price_history_repo.go
git commit -m "feat(holding-c-server): application Buy/Sell/Split FIFO lot 维护 + CSI300 seed + SyncPrices 写 price_history

HoldingTransaction 加 RealizedPnLCents(FIFO 卖出实现收益)+ DTO/mapper。
Service 加 lot/snapshot/priceHistory/historical/rate repo setter(NewService
签名不变)。BuyHolding 建 lot+LotAvgCost 派生;SellHolding ConsumeLotsFIFO
消耗 lot+realized 落 trade+AvgCost 派生;RecordSplit lot split-adjusted
(qty×ratio+price/ratio)。SeedSecurities 加 CSI300(000300/SSE/INDEX)。
B SyncPrices 顺手写 price_history 当日点。3 FIFO 单测。"
```

---

## Task 6: application SnapshotHoldings + BackfillPriceHistory + GetPortfolioPerformance + GetHoldingPerformance

**Files:**
- Modify: `yucai/server/internal/holding/application/dto.go`(加 Performance DTO)
- Modify: `yucai/server/internal/holding/application/service.go`(4 新方法)
- Test: `yucai/server/internal/holding/application/service_test.go`

**Interfaces:**
- Consumes: `SnapshotRepository`/`PriceHistoryRepository`/`LotRepository`/`HistoricalProvider`/`RateHistoryRepository`/`tradeRepo.FindAll`(Task 5 setter)
- Produces(后续依赖):
  - `SnapshotHoldings(ctx) (int, error)` — 实现 `Snapshotter`(Task 7 scheduler)
  - `BackfillPriceHistory(ctx, range string) (int, error)` — main 启动 + handler 调
  - `GetPortfolioPerformance(ctx, tenantID, accountID*, range, withBenchmark) (*PortfolioPerformance, error)` — Task 8 handler
  - `GetHoldingPerformance(ctx, holdingID, range) (*HoldingPerformance, error)` — Task 8 handler
  - DTO:`PortfolioPerformance`/`HoldingPerformance`/`CurvePointDTO`(Task 8 handler 映射 proto)

**背景**:曲线采样是核心。range→(from,to,granularity):DAY=近30日逐日 / MONTH=近12月(取每月最后可用 snapshot)/ YEAR=近5年(每年最后)。组合 CNY = Σ snapshot.market_value × rate_history(currency→CNY, 该日)。realized = Σ trade.realized_pnl_cents(sell)+ Σ dividend amount。年化 = totalReturn / holdingPeriodYears(最早 holding created_at)。

- [ ] **Step 1: dto.go 加 Performance DTO**

在 dto.go 末尾加:
```go
// CurvePointDTO is one time-series point (double value — CNY market value,
// original-currency price, or benchmark index level).
type CurvePointDTO struct {
	Time  time.Time
	Value float64
}

// PortfolioPerformance is the portfolio-level curve + foot (Task 6 fills).
type PortfolioPerformance struct {
	PortfolioPoints []CurvePointDTO // CNY market value over time
	BenchmarkPoints []CurvePointDTO // CSI300 (empty if !include_benchmark)
	BenchmarkName   string
	RealizedCents   int64   // Σ sell FIFO realized + dividend, CNY
	UnrealizedCents int64   // current portfolio unrealized, CNY
	TotalCents      int64
	AnnualizedPct   float64 // annualized return %
	TotalPct        float64 // cumulative return %
	Currency        string  // "CNY"
}

// HoldingPerformance is the single-holding curve + foot.
type HoldingPerformance struct {
	PricePoints     []CurvePointDTO // original-currency price over time
	RealizedCents   int64           // this holding's FIFO realized, original currency
	UnrealizedCents int64
	TotalCents      int64
	Currency        string // original currency
}
```

- [ ] **Step 2: service.go 加 range helper + SnapshotHoldings**

在 service.go 末尾加:
```go
// curveWindow maps a proto CurveRange name to (from, to, granularity).
// granularity = "day"/"month"/"year" sampling.
func curveWindow(rangeName string) (from, to time.Time, granularity string) {
	to = truncateToDate(time.Now())
	switch rangeName {
	case "MONTH":
		return to.AddDate(0, -12, 0), to, "month"
	case "YEAR":
		return to.AddDate(-5, 0, 0), to, "year"
	default: // DAY
		return to.AddDate(0, 0, -30), to, "day"
	}
}

// SnapshotHoldings writes one market-value snapshot per active holding for
// today. Best-effort: a holding whose security price is missing is skipped
// + logged, not fatal. Implements scheduler.Snapshotter.
func (s *Service) SnapshotHoldings(ctx context.Context, tenantID uuid.UUID) (int, error) {
	if s.snapshotRepo == nil {
		return 0, fmt.Errorf("snapshot: snapshot repo not configured")
	}
	today := truncateToDate(time.Now())
	synced := 0
	page := domain.PageRequest{PageSize: 100}
	// tenantID = uuid.Nil means all tenants (scheduler global pass).
	for {
		result, err := s.holdingRepo.FindAll(ctx, tenantID, nil, page)
		if err != nil {
			return synced, fmt.Errorf("snapshot: list holdings: %w", err)
		}
		for _, h := range result.Items {
			if err := ctx.Err(); err != nil {
				return synced, err
			}
			sec, err := s.securityRepo.FindByID(ctx, h.SecurityID)
			if err != nil || sec == nil {
				slog.Warn("holding snapshot: security missing, skip",
					slog.String("holding_id", h.ID.String()), slog.String("operation", "SnapshotHoldings"))
				continue
			}
			snap := domain.HoldingSnapshot{
				TenantID: h.TenantID, HoldingID: h.ID, SecurityID: h.SecurityID,
				AccountID: h.AccountID, SnapshotDate: today,
				MarketValueCents: h.MarketValue(sec.CurrentPriceCents),
				UnrealizedPnlCents: h.UnrealizedPnL(sec.CurrentPriceCents),
				CurrencyCode: sec.CurrencyCode,
			}
			if err := s.snapshotRepo.Save(ctx, snap); err != nil {
				slog.Warn("holding snapshot: save failed",
					slog.String("holding_id", h.ID.String()), slog.String("error", err.Error()),
					slog.String("operation", "SnapshotHoldings"))
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
> ⚠️ `HoldingRepository.FindAll(tenantID, ...)` 当 tenantID=Nil 时是否返回全 tenant?Read holding_repo.go 确认。若 FindAll 强制 tenant 过滤,scheduler 需遍历所有 tenant(从 auth.TenantRepository 取列表)—— 首批简化:scheduler 先取所有 tenantID 列表,逐个 SnapshotHoldings(tenantID)。或 FindAll 支持 Nil=全部。以 Read 为准,调整 SnapshotScheduler(Task 7)调用。

- [ ] **Step 3: BackfillPriceHistory 实现**

```go
// datalenForRange maps CurveRange to Sina K-line datalen (bar count).
func datalenForRange(rangeName string) int {
	switch rangeName {
	case "MONTH":
		return 250
	case "YEAR":
		return 1200
	default:
		return 30
	}
}

// BackfillPriceHistory fetches historical daily K-line for every Sina-covered
// security + CSI300, writing price_history. Best-effort: per-security fetch
// failure logged, not fatal. Skips securities that already have history
// (Exists gate — only backfills the empty case, idempotent).
func (s *Service) BackfillPriceHistory(ctx context.Context, rangeName string) (int, error) {
	if s.historicalProvider == nil || s.priceHistoryRepo == nil {
		return 0, fmt.Errorf("backfill: historical provider/price history repo not configured")
	}
	datalen := datalenForRange(rangeName)
	backfilled := 0
	page := domain.PageRequest{PageSize: 100}
	for {
		result, err := s.securityRepo.FindAll(ctx, nil, page)
		if err != nil {
			return backfilled, fmt.Errorf("backfill: list securities: %w", err)
		}
		for _, sec := range result.Items {
			if err := ctx.Err(); err != nil {
				return backfilled, err
			}
			exists, _ := s.priceHistoryRepo.Exists(ctx, sec.ID)
			if exists {
				continue // already has history — only backfill empty
			}
			view := priceprovider.PriceView{Symbol: sec.Symbol, Exchange: sec.Exchange, Type: sec.SecurityType}
			pts, err := s.historicalProvider.FetchHistory(ctx, view, datalen)
			if err != nil {
				if errors.Is(err, priceprovider.ErrNoSource) {
					continue // non A-share (US/OTC/SGE) — no history in batch
				}
				slog.Warn("holding backfill: fetch history failed",
					slog.String("symbol", sec.Symbol), slog.String("error", err.Error()),
					slog.String("operation", "BackfillPriceHistory"))
				continue
			}
			ph := make([]domain.SecurityPriceHistory, 0, len(pts))
			for _, p := range pts {
				ph = append(ph, domain.SecurityPriceHistory{
					SecurityID: sec.ID, PriceDate: p.Date, PriceCents: p.PriceCents,
					CurrencyCode: sec.CurrencyCode, Source: "backfill",
				})
			}
			if err := s.priceHistoryRepo.SaveAll(ctx, ph); err != nil {
				slog.Warn("holding backfill: save failed",
					slog.String("symbol", sec.Symbol), slog.String("error", err.Error()),
					slog.String("operation", "BackfillPriceHistory"))
				continue
			}
			backfilled++
		}
		if result.NextPageToken == "" || len(result.Items) == 0 {
			break
		}
		page.PageToken = result.NextPageToken
	}
	return backfilled, nil
}
```

- [ ] **Step 4: GetPortfolioPerformance 实现(曲线采样 + 折算 + realized + 年化)**

```go
// GetPortfolioPerformance builds the portfolio CNY curve + realized/unrealized
// + annualized + optional CSI300 benchmark.
func (s *Service) GetPortfolioPerformance(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, rangeName string, withBenchmark bool) (*PortfolioPerformance, error) {
	from, to, granularity := curveWindow(rangeName)
	snaps, err := s.snapshotRepo.FindSnapshots(ctx, tenantID, from, to, accountID, nil)
	if err != nil {
		return nil, fmt.Errorf("portfolio perf: find snapshots: %w", err)
	}
	// Sample by granularity: group snapshots by day/month/year bucket, take last per bucket.
	portPts := s.samplePortfolioCNY(snaps, granularity)
	// Realized: Σ sell realized + Σ dividend (from trades).
	realized := s.aggregateRealized(ctx, tenantID, accountID)
	// Unrealized (current): Σ current holding unrealized (CNY折算).
	unrealized := s.currentUnrealizedCNY(ctx, tenantID, accountID)
	total := realized + unrealized
	// Cost basis (current): Σ qty×avgCost (CNY) — for total %.
	costBasis := s.currentCostBasisCNY(ctx, tenantID, accountID)
	totalPct := 0.0
	if costBasis != 0 {
		totalPct = float64(total) / float64(costBasis) * 100
	}
	annualized := s.annualizedPct(total, costBasis, ctx, tenantID)
	out := &PortfolioPerformance{
		PortfolioPoints: portPts, RealizedCents: realized, UnrealizedCents: unrealized,
		TotalCents: total, AnnualizedPct: annualized, TotalPct: totalPct, Currency: "CNY",
	}
	if withBenchmark {
		out.BenchmarkName = "沪深300"
		out.BenchmarkPoints = s.benchmarkCurve(ctx, rangeName)
	}
	return out, nil
}

// samplePortfolioCNY groups snapshots by granularity bucket (day/month/year),
// takes the last snapshot per holding per bucket, sums to portfolio market
// value per bucket date,折算 to CNY via rate history.
func (s *Service) samplePortfolioCNY(snaps []domain.HoldingSnapshot, granularity string) []CurvePointDTO {
	// bucket key = truncated date; collect last snapshot per (holding, bucket).
	type key struct{ holding uuid.UUID; bucket time.Time }
	last := map[key]domain.HoldingSnapshot{}
	for _, sn := range snaps {
		b := bucketOf(sn.SnapshotDate, granularity)
		k := key{sn.HoldingID, b}
		if cur, ok := last[k]; !ok || sn.SnapshotDate.After(cur.SnapshotDate) {
			last[k] = sn
		}
	}
	// sum market value per bucket date,折算 each holding's currency to CNY.
	byDate := map[time.Time]int64{}
	for _, sn := range last {
		rate := 1.0
		if s.rateRepo != nil && sn.CurrencyCode != "CNY" {
			rate, _ = s.rateRepo.FindRate(context.Background(), sn.CurrencyCode, sn.SnapshotDate)
		}
		byDate[bucketOf(sn.SnapshotDate, granularity)] += int64(float64(sn.MarketValueCents) * rate)
	}
	// sorted points (double value in 元).
	dates := make([]time.Time, 0, len(byDate))
	for d := range byDate {
		dates = append(dates, d)
	}
	sort.Slice(dates, func(i, j int) bool { return dates[i].Before(dates[j]) })
	pts := make([]CurvePointDTO, 0, len(dates))
	for _, d := range dates {
		pts = append(pts, CurvePointDTO{Time: d, Value: float64(byDate[d]) / 100.0})
	}
	return pts
}

func bucketOf(t time.Time, granularity string) time.Time {
	switch granularity {
	case "month":
		return time.Date(t.Year(), t.Month(), 1, 0, 0, 0, 0, time.UTC)
	case "year":
		return time.Date(t.Year(), 1, 1, 0, 0, 0, 0, time.UTC)
	default:
		return truncateToDate(t)
	}
}

// aggregateRealized sums sell FIFO realized + dividend total across the
// portfolio's trades (CNY折算 skipped — realized landed in trade's original
// currency; for multi-currency precision Task defer, first batch assumes CNY).
func (s *Service) aggregateRealized(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID) int64 {
	var sum int64
	page := domain.PageRequest{PageSize: 200}
	for {
		res, err := s.tradeRepo.FindAll(ctx, tenantID, accountID, nil, page)
		if err != nil {
			return sum
		}
		for _, tr := range res.Items {
			sum += tr.RealizedPnLCents // sell realized
			if tr.TradeType == domain.TradeTypeDividend {
				sum += tr.AmountCents // dividend as realized income
			}
		}
		if res.NextPageToken == "" || len(res.Items) == 0 {
			break
		}
		page.PageToken = res.NextPageToken
	}
	return sum
}
```
> `currentUnrealizedCNY`/`currentCostBasisCNY`/`annualizedPct`/`benchmarkCurve` helper:遍历当前 holdings × security current price 算 unrealized/cost(折算 CNY);annualizedPct = (total/costBasis) / years(now − earliestHoldingCreated);benchmarkCurve = 查 000300 security 的 price_history 同 range 采样。这些 helper 模式同 samplePortfolioCNY(遍历 + 折算),Step 5 补全。

- [ ] **Step 5: 补全 helper(currentUnrealizedCNY / currentCostBasisCNY / annualizedPct / benchmarkCurve)+ GetHoldingPerformance**

```go
func (s *Service) currentUnrealizedCNY(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID) int64 {
	var sum int64
	page := domain.PageRequest{PageSize: 100}
	for {
		res, err := s.holdingRepo.FindAll(ctx, tenantID, accountID, page)
		if err != nil {
			return sum
		}
		for _, h := range res.Items {
			sec, err := s.securityRepo.FindByID(ctx, h.SecurityID)
			if err != nil || sec == nil {
				continue
			}
			pnl := h.UnrealizedPnL(sec.CurrentPriceCents)
			rate := 1.0
			if s.rateRepo != nil && sec.CurrencyCode != "CNY" {
				rate, _ = s.rateRepo.FindRate(ctx, sec.CurrencyCode, time.Now())
			}
			sum += int64(float64(pnl) * rate)
		}
		if res.NextPageToken == "" || len(res.Items) == 0 {
			break
		}
		page.PageToken = res.NextPageToken
	}
	return sum
}

// currentCostBasisCNY — same shape as currentUnrealizedCNY but Σ qty×avgCost.
func (s *Service) currentCostBasisCNY(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID) int64 {
	// (同上遍历,Σ int64(float64(h.AvgCostCents)*h.Quantity) × rate)
	// ... 实现照 currentUnrealizedCNY 模式
	return 0 // 占位由实现者照模式补全
}

// annualizedPct annualizes total return over the holding period (earliest
// holding created_at → now). Returns 0 if period < 1 day or costBasis 0.
func (s *Service) annualizedPct(total, costBasis int64, ctx context.Context, tenantID uuid.UUID) float64 {
	if costBasis == 0 {
		return 0
	}
	// earliest holding created_at
	page := domain.PageRequest{PageSize: 200}
	earliest := time.Now()
	res, err := s.holdingRepo.FindAll(ctx, tenantID, nil, page)
	if err != nil || len(res.Items) == 0 {
		return 0
	}
	for _, h := range res.Items {
		if h.CreatedAt.Before(earliest) {
			earliest = h.CreatedAt
		}
	}
	years := time.Since(earliest).Hours() / 24 / 365.25
	if years < 1.0/365.25 {
		return 0
	}
	totalReturn := float64(total) / float64(costBasis) // fraction
	// simple annualized (not CAGR — first batch): totalReturn / years × 100
	return totalReturn / years * 100
}

// benchmarkCurve returns CSI300 (000300) price history as curve points.
func (s *Service) benchmarkCurve(ctx context.Context, rangeName string) []CurvePointDTO {
	from, to, granularity := curveWindow(rangeName)
	// find CSI300 security by symbol 000300
	sec, err := s.securityRepo.FindBySymbol(ctx, "000300", "SSE")
	if err != nil || sec == nil {
		return nil
	}
	ph, err := s.priceHistoryRepo.FindBySecurity(ctx, sec.ID, from, to)
	if err != nil {
		return nil
	}
	pts := make([]CurvePointDTO, 0, len(ph))
	for _, p := range ph {
		pts = append(pts, CurvePointDTO{Time: p.PriceDate, Value: float64(p.PriceCents) / 100.0})
	}
	return pts
}

// GetHoldingPerformance: single-holding price curve + this holding's realized.
func (s *Service) GetHoldingPerformance(ctx context.Context, holdingID uuid.UUID, rangeName string) (*HoldingPerformance, error) {
	from, to, _ := curveWindow(rangeName)
	// holding → security
	hres, err := s.holdingRepo.FindAll(ctx, uuid.Nil, nil, domain.PageRequest{PageSize: 200})
	// ⚠️ FindAll 不按 holdingID 过滤;需 HoldingRepository 加 FindByID(holdingID)。若缺,
	// 用 FindByAccountAndSecurity 或遍历。首批:加 domain.HoldingRepository.FindByID(holdingID uuid.UUID)
	// (repository.go + holding_repo.go)。
	_ = hres
	// 实现:FindByID(holdingID) → securityID → priceHistoryRepo.FindBySecurity → points
	// realized = Σ trade.realized for this holding (tradeRepo.FindAll tenant+securityID)
	// unrealized = current (holding × current price)
	// (照 GetPortfolioPerformance 单持仓版,Step 6 测试驱动补全)
	return &HoldingPerformance{}, nil
}
```
> ⚠️ `GetHoldingPerformance` 需 `HoldingRepository.FindByID(holdingID)` —— Task 3 没加。**Step 6 前补**:domain/repository.go `HoldingRepository` 接口加 `FindByID(ctx, holdingID uuid.UUID) (*HoldingHolding, error)` + holding_repo.go 实现(照 FindByAccountAndSecurity)。这是必要的接口扩展。`currentCostBasisCNY` 和 `GetHoldingPerformance` 的完整实现照 `currentUnrealizedCNY`/`GetPortfolioPerformance` 模式补全(TDD Step 6 驱动)。

- [ ] **Step 6: 写测试(service_test.go 追加)**

fake repo 注入(Task 5 的 fake 模式),关键测:
```go
func TestSnapshotHoldingsWritesPerHolding(t *testing.T) {
	// seed: 2 holdings with securities (price set). Snapshot → 2 snapshots saved,
	//       market_value = qty×price, unrealized = mv - qty×avgCost
}
func TestBackfillPriceHistoryFetchesAndSkipsExisting(t *testing.T) {
	// fake historicalProvider returns 3 points for 600519; Exists(600519)=false→backfill,
	// Exists(510300)=true→skip. Expect backfilled=1, price_history has 3 rows.
}
func TestGetPortfolioPerformanceSamplesAndConverts(t *testing.T) {
	// seed snapshots: CNY holding mv=10000 day1/day2; USD holding mv=5000 day1/day2.
	// fake rateRepo: USD→CNY=7.0. range=DAY. Expect 2 portfolio points:
	//   day1 = 10000 + 5000×7 = 45000 (元=450.00); day2 similar.
	// realized = Σ trade.realized; annualized based on earliest holding created_at.
}
```
(测 samplePortfolioCNY 折算 + realized 聚合是核心。完整断言金额。)

- [ ] **Step 7: build + test**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/application/ -v -count=1
cd /e/projects/syfinance/yucai/server && go build ./...
```
Expected:PASS + build 绿。

- [ ] **Step 8: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/internal/holding/application/ yucai/server/internal/holding/domain/repository.go yucai/server/internal/holding/adapter/driven/repository/holding_repo.go
git commit -m "feat(holding-c-server): application snapshot/backfill/portfolio+holding performance

SnapshotHoldings(每日写 holding_snapshot)+ BackfillPriceHistory(新浪日K回填,
Exists 门控)+ GetPortfolioPerformance(snapshot×rate→CNY 曲线+realized+年化+
CSI300 基准)+ GetHoldingPerformance(单标的 price_history+realized)。curveRange
采样 day/month/year。HoldingRepository 加 FindByID。DTO 加 Performance/Point。
折算用 rateRepo(multi-currency CNY)。单测覆盖采样+折算+回填门控。"
```

---

## Task 7: SnapshotScheduler + B/currency 顺手写 history(scheduler 部分)

**Files:**
- Create: `yucai/server/internal/holding/scheduler/snapshot_scheduler.go`
- Create: `yucai/server/internal/holding/scheduler/snapshot_scheduler_test.go`
- Modify: `yucai/server/internal/holding/application/service.go`(加 `SnapshotAllHoldings` 包装)
- Modify: `yucai/server/internal/currency/application/service.go`(SyncRates 加 rate_history 写入)
- Modify: `yucai/server/internal/currency/application/service_test.go`(回归)

**Interfaces:**
- Consumes:`IntervalSource`(B scheduler 已建,复用同 provider)
- Produces:
  - `scheduler.Snapshotter` 接口 `SnapshotAllHoldings(ctx) (int, error)`(由 application.Service 实现)
  - `scheduler.SnapshotScheduler` + `NewSnapshotScheduler(syncer Snapshotter, src IntervalSource, tick, log)` + `Start(ctx)` + `SyncNow(ctx)(int, error)`
- Task 9(wire)依赖

**背景**:照搬 [scheduler.go](../../yucai/server/internal/holding/scheduler/scheduler.go)(B PriceScheduler)改名。Snapshotter 跨 tenant(不像 SyncPrices 是 global security),需 `SnapshotAllHoldings` 遍历全部 tenant 的 holdings。currency `SyncRates` 顺手写 rate_history(对齐 B SyncPrices 写 price_history)。

- [ ] **Step 1: service.go 加 SnapshotAllHoldings 包装**

在 `SnapshotHoldings`(Task 6)之后加:
```go
// SnapshotAllHoldings snapshots every holding across all tenants. Used by the
// SnapshotScheduler (tenantID = Nil means "all" via HoldingRepository.FindAll).
func (s *Service) SnapshotAllHoldings(ctx context.Context) (int, error) {
	return s.SnapshotHoldings(ctx, uuid.Nil)
}
```
> ⚠️ 确认 `HoldingRepository.FindAll(ctx, uuid.Nil, ...)` 返回全 tenant。Read holding_repo.go:若 FindAll 的 tenantID 过滤是 `WHERE tenant_id = $1`(Nil 不匹配),则 Nil 返回空 —— 此时需改 holding_repo 的 FindAll 让 Nil=无过滤,或 scheduler 注入 tenant list 逐个快照。**首选**:让 FindAll 的 Nil 表示"全部"(SQL `tenant_id IS NULL OR tenant_id = $1` 当 param Nil),对齐 snapshot 跨 tenant 语义。执行者 Read holding_repo.go 确认 + 必要时调整。

- [ ] **Step 2: 写 snapshot_scheduler.go(照 B scheduler.go 改名)**

`yucai/server/internal/holding/scheduler/snapshot_scheduler.go`:
```go
package scheduler

import (
	"context"
	"log/slog"
	"sync"
	"time"
)

// Snapshotter writes daily market-value snapshots across all holdings.
// Implemented by holding/application.Service.SnapshotAllHoldings.
type Snapshotter interface {
	SnapshotAllHoldings(ctx context.Context) (int, error)
}

// SnapshotScheduler periodically calls Snapshotter, gated by IntervalSource
// (reused from price scheduler — same auth TenantRepository provider). Mirrors
// the price Scheduler (scheduler.go) 1:1, just Snapshotter→PriceSyncer.
type SnapshotScheduler struct {
	syncer Snapshotter
	src    IntervalSource
	tick   time.Duration
	log    *slog.Logger

	mu       sync.Mutex
	lastSync time.Time
}

func NewSnapshotScheduler(syncer Snapshotter, src IntervalSource, tick time.Duration, log *slog.Logger) *SnapshotScheduler {
	if log == nil {
		log = slog.Default()
	}
	return &SnapshotScheduler{syncer: syncer, src: src, tick: tick, log: log}
}

func (s *SnapshotScheduler) Start(ctx context.Context) {
	if _, err := s.doSync(ctx); err != nil {
		s.log.Error("holding snapshot failed", "error", err, "operation", "SnapshotScheduler.Start")
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
					s.log.Error("holding snapshot failed", "error", err, "operation", "SnapshotScheduler.Start")
				}
			}
		}
	}
}

func (s *SnapshotScheduler) SyncNow(ctx context.Context) (int, error) { return s.doSync(ctx) }

func (s *SnapshotScheduler) doSync(ctx context.Context) (int, error) {
	if err := ctx.Err(); err != nil {
		return 0, err
	}
	count, err := s.syncer.SnapshotAllHoldings(ctx)
	if err != nil {
		s.log.Error("holding snapshot failed", "error", err, "operation", "SnapshotScheduler")
	} else {
		s.log.Info("holding snapshot completed", "count", count, "operation", "SnapshotScheduler")
	}
	s.mu.Lock()
	s.lastSync = time.Now()
	s.mu.Unlock()
	return count, err
}
```

- [ ] **Step 3: 写 snapshot_scheduler_test.go(照 scheduler_test.go 改 mockSyncer)**

照 [scheduler_test.go](../../yucai/server/internal/holding/scheduler/scheduler_test.go) 的 5 测试(immediate/interval-gate/ctx-cancel/SyncNow-error/SyncNow-cancelled),把 `mockSyncer.SyncPrices` 换成 `SnapshotAllHoldings`:
```go
type mockSnapshotter struct {
	calls atomic.Int64
	err   error
}
func (m *mockSnapshotter) SnapshotAllHoldings(_ context.Context) (int, error) {
	m.calls.Add(1)
	if m.err != nil { return 0, m.err }
	return 5, nil
}
// 5 测试照 scheduler_test.go 结构,NewSnapshotScheduler + Start/SyncNow
```

- [ ] **Step 4: currency SyncRates 加 rate_history 写入**

Read `currency/application/service.go` 的 `SyncRates`(找 UpdateRate/SetRate 调用处)。在每个 currency 刷新 rate 成功后加:
```go
// C: record daily rate history (idempotent).
if s.rateHistoryRepo != nil {
	_ = s.rateHistoryRepo.Save(ctx, domain.RateHistory{
		CurrencyCode: code, RateDate: truncateToDate(time.Now()),
		ExchangeRate: rate, // the freshly-synced rate
	})
}
```
currency Service 加 `rateHistoryRepo domain.RateHistoryRepository` 字段 + `SetRateHistoryRepository` setter(currency domain 的 RateHistoryRepository,Task 3 定义)。currency domain RateHistory 实体已在 Task 3 Step 2 加。

- [ ] **Step 5: build + test**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/scheduler/ ./internal/currency/application/ -v -count=1
cd /e/projects/syfinance/yucai/server && go build ./...
```
Expected:PASS(scheduler 5 测 + currency 回归)+ build 绿。

- [ ] **Step 6: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/internal/holding/scheduler/ yucai/server/internal/holding/application/service.go yucai/server/internal/currency/
git commit -m "feat(holding-c-server): SnapshotScheduler + service.SnapshotAllHoldings + currency SyncRates 写 rate_history

SnapshotScheduler 照搬 B price scheduler(Snapshotter 接口=SnapshotAllHoldings,
IntervalSource 复用)。SnapshotAllHoldings 包装 SnapshotHoldings(Nil tenant=全部)。
currency SyncRates 顺手写 rate_history 当日点(对齐 B SyncPrices 写 price_history)。
5 scheduler 单测 + currency 回归。"
```

---

## Task 8: proto(3 RPC + CurveRange/CurvePoint)+ Go stub + handler + 单测

**Files:**
- Modify: `yucai/proto/holding/v1/holding.proto`(service 块加 3 RPC + 末尾加 message + enum)
- Regenerate: `yucai/server/internal/proto/holding/v1/holding.pb.go`、`holding_grpc.pb.go`
- Modify: `yucai/server/internal/holding/adapter/driving/grpc/holding_handler.go`(加 3 handler)
- Test: `yucai/server/internal/holding/adapter/driving/grpc/holding_handler_test.go`

**Interfaces:**
- Consumes:`service.GetPortfolioPerformance/GetHoldingPerformance/BackfillPriceHistory`(Task 6)、DTO(Task 6)
- Produces:proto `GetPortfolioPerformance`/`GetHoldingPerformance`/`BackfillPriceHistory` RPC;Go server 接口方法。Task 11(Flutter ds)依赖 Dart stub

**背景**:非 TDD setup(proto 契约)+ handler 薄映射。CurvePoint.value double,foot cents。handler 鉴权(getTenantID)。

- [ ] **Step 1: 改 holding.proto(service 块加 3 RPC)**

在 service 块(`SyncPrices` 那行之后)加:
```proto
  rpc GetPortfolioPerformance(GetPortfolioPerformanceRequest) returns (PortfolioPerformanceResponse);
  rpc GetHoldingPerformance(GetHoldingPerformanceRequest) returns (HoldingPerformanceResponse);
  rpc BackfillPriceHistory(BackfillPriceHistoryRequest) returns (BackfillPriceHistoryResponse);
```

- [ ] **Step 2: proto 末尾加 enum + message**

```proto
enum CurveRange {
  CURVE_RANGE_UNSPECIFIED = 0;
  CURVE_RANGE_DAY = 1;
  CURVE_RANGE_MONTH = 2;
  CURVE_RANGE_YEAR = 3;
}

message CurvePoint {
  google.protobuf.Timestamp time = 1;
  double value = 2;
}

message GetPortfolioPerformanceRequest {
  string account_id = 1;
  CurveRange range = 2;
  bool include_benchmark = 3;
}
message PortfolioPerformanceResponse {
  repeated CurvePoint portfolio_points = 1;
  repeated CurvePoint benchmark_points = 2;
  string benchmark_name = 3;
  int64 realized_cents = 4;
  int64 unrealized_cents = 5;
  int64 total_cents = 6;
  double annualized_pct = 7;
  double total_pct = 8;
  string currency = 9;
}

message GetHoldingPerformanceRequest {
  string holding_id = 1;
  CurveRange range = 2;
}
message HoldingPerformanceResponse {
  repeated CurvePoint price_points = 1;
  int64 realized_cents = 2;
  int64 unrealized_cents = 3;
  int64 total_cents = 4;
  string currency = 5;
}

message BackfillPriceHistoryRequest {
  CurveRange range = 1;
}
message BackfillPriceHistoryResponse {
  int32 backfilled_count = 1;
}
```
> `google.protobuf.Timestamp` import 已有(holding.proto 现有 Timestamp 用)。

- [ ] **Step 3: 重生成 Go stub**

```bash
cd /e/projects/syfinance/yucai/proto && buf generate --template buf.gen.go.yaml
```
Expected:`holding.pb.go` 出现新类型;`holding_grpc.pb.go` 的 `HoldingServiceServer` 接口加 3 方法(此时 HoldingHandler 未实现 → server 编译红,Task 8 Step 5 修)。

- [ ] **Step 4: handler 加 3 RPC(在 SyncPrices 之后)**

`holding_handler.go` 加(参照 B SyncPrices 的 getTenantID/mapError/timestamppb 模式):
```go
func (h *HoldingHandler) GetPortfolioPerformance(ctx context.Context, req *pb.GetPortfolioPerformanceRequest) (*pb.PortfolioPerformanceResponse, error) {
	tid, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	var acct *uuid.UUID
	if req.GetAccountId() != "" {
		a, err := uuid.Parse(req.GetAccountId())
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid account_id")
		}
		acct = &a
	}
	perf, err := h.service.GetPortfolioPerformance(ctx, tid, acct, curveRangeName(req.GetRange()), req.GetIncludeBenchmark())
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.PortfolioPerformanceResponse{
		PortfolioPoints: curvePointsToProto(perf.PortfolioPoints),
		BenchmarkPoints: curvePointsToProto(perf.BenchmarkPoints),
		BenchmarkName:   perf.BenchmarkName,
		RealizedCents:   perf.RealizedCents,
		UnrealizedCents: perf.UnrealizedCents,
		TotalCents:      perf.TotalCents,
		AnnualizedPct:   perf.AnnualizedPct,
		TotalPct:        perf.TotalPct,
		Currency:        perf.Currency,
	}, nil
}

func (h *HoldingHandler) GetHoldingPerformance(ctx context.Context, req *pb.GetHoldingPerformanceRequest) (*pb.HoldingPerformanceResponse, error) {
	if _, err := getTenantID(ctx); err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	hid, err := uuid.Parse(req.GetHoldingId())
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid holding_id")
	}
	perf, err := h.service.GetHoldingPerformance(ctx, hid, curveRangeName(req.GetRange()))
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.HoldingPerformanceResponse{
		PricePoints:     curvePointsToProto(perf.PricePoints),
		RealizedCents:   perf.RealizedCents,
		UnrealizedCents: perf.UnrealizedCents,
		TotalCents:      perf.TotalCents,
		Currency:        perf.Currency,
	}, nil
}

func (h *HoldingHandler) BackfillPriceHistory(ctx context.Context, req *pb.BackfillPriceHistoryRequest) (*pb.BackfillPriceHistoryResponse, error) {
	if _, err := getTenantID(ctx); err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	count, err := h.service.BackfillPriceHistory(ctx, curveRangeName(req.GetRange()))
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.BackfillPriceHistoryResponse{BackfilledCount: int32(count)}, nil
}

// curveRangeName maps proto CurveRange enum to the service's range string.
func curveRangeName(r pb.CurveRange) string {
	switch r {
	case pb.CurveRange_CURVE_RANGE_MONTH:
		return "MONTH"
	case pb.CurveRange_CURVE_RANGE_YEAR:
		return "YEAR"
	default:
		return "DAY"
	}
}

// curvePointsToProto maps []CurvePointDTO → []*pb.CurvePoint.
func curvePointsToProto(pts []holdingapp.CurvePointDTO) []*pb.CurvePoint {
	out := make([]*pb.CurvePoint, 0, len(pts))
	for _, p := range pts {
		out = append(out, &pb.CurvePoint{
			Time:  timestamppb.New(p.Time),
			Value: p.Value,
		})
	}
	return out
}
```
> import:`holdingapp "github.com/yucai/server/internal/holding/application"`(若未引用 DTO 包)、`uuid`、`timestamppb`(已有)、`codes`/`status`(已有)。`holdingapp.CurvePointDTO` —— 若 DTO 在 application 包,直接用;确认 application dto.go 的 CurvePointDTO 可被 grpc 包导入(同模块,可)。

- [ ] **Step 5: build + handler 测试**

```bash
cd /e/projects/syfinance/yucai/server && go build ./...
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/adapter/driving/grpc/ -v -count=1
```
Expected:**build PASS**(Task 8 Step 3 的红转绿);handler 测试 PASS。新增 handler 测试(照 B holding_handler_test 的 stub service 模式):
```go
func TestGetPortfolioPerformanceReturnsCurve(t *testing.T) {
	// stub service.GetPortfolioPerformance returns 2 portfolio points + realized=800
	// → response.PortfolioPoints len==2, RealizedCents==800
}
func TestGetHoldingPerformanceReturnsCurve(t *testing.T) { /* 同 */ }
```

- [ ] **Step 6: Commit**

```bash
cd /e/projects/syfinance
git add yucai/proto/holding/v1/holding.proto yucai/server/internal/proto/holding/v1/ yucai/server/internal/holding/adapter/driving/grpc/
git commit -m "feat(holding-c-server): proto 3 performance RPC + handler

GetPortfolioPerformance(组合曲线+基准+realized+年化)+ GetHoldingPerformance
(单标的曲线+realized)+ BackfillPriceHistory(手动回填)。CurveRange enum +
CurvePoint(double value)。handler 薄映射 service + curveRangeName/curvePointsToProto。
Go stub buf generate。HoldingHandler 满足新接口,server 编译绿。"
```

---

## Task 9: wire + main(SnapshotScheduler + 4 repo + 回填启动)+ go build 绿

**Files:**
- Modify: `yucai/server/wire/providers.go`(4 repo provider + rate adapter + historicalProvider + SnapshotScheduler + 改 provideHoldingService/currencyService setter 注入)
- Modify: `yucai/server/wire/wire_gen.go`(**手改**,镜像 B)
- Modify: `yucai/server/wire/app.go`(App.SnapshotScheduler)
- Modify: `yucai/server/cmd/server/main.go`(go SnapshotScheduler.Start + 启动异步回填)

**Interfaces:**
- Consumes:Tasks 1-8 全部产物
- Produces:完整 server 可启动(snapshot scheduler + 回填随 main 启动)

**背景**:wire 工具链坏(见 [[yucai-wire-handmaintained]]),wire_gen.go 手改镜像 B 的 priceScheduler 行。Service 用 setter 注入(B 惯例,NewService 签名不变)。currency RateHistoryRepo 的 `FindRange` 返回 `[]RateHistory`,holding 期望 `map[time.Time]float64` —— wire 写 adapter。

- [ ] **Step 1: providers.go 加 4 repo provider + rate adapter + SnapshotScheduler**

在 B 的 `providePriceScheduler` 附近加:
```go
func provideLotRepo(client *ent.Client) domain.LotRepository {
	return repository.NewLotRepo(client)
}
func provideSnapshotRepo(client *ent.Client) domain.SnapshotRepository {
	return repository.NewSnapshotRepo(client)
}
func providePriceHistoryRepo(client *ent.Client) domain.PriceHistoryRepository {
	return repository.NewPriceHistoryRepo(client)
}
func provideHistoricalProvider() priceprovider.HistoricalProvider {
	return priceprovider.NewSinaProvider() // same Sina, implements HistoricalProvider
}

// holdingRateAdapter adapts currency's RateHistoryRepo (FindRange returns slice)
// to holding's domain.RateHistoryRepository (FindRange returns map).
type holdingRateAdapter struct{ inner currencyrepo.RateHistoryRepo }

func (a *holdingRateAdapter) FindRate(ctx context.Context, code string, date time.Time) (float64, error) {
	return a.inner.FindRate(ctx, code, date)
}
func (a *holdingRateAdapter) FindRange(ctx context.Context, code string, from, to time.Time) (map[time.Time]float64, error) {
	rows, err := a.inner.FindRange(ctx, code, from, to)
	if err != nil {
		return nil, err
	}
	m := make(map[time.Time]float64, len(rows))
	for _, r := range rows {
		m[r.RateDate] = r.ExchangeRate
	}
	return m, nil
}
func provideHoldingRateRepo(inner currencyrepo.RateHistoryRepo) domain.RateHistoryRepository {
	return &holdingRateAdapter{inner: inner}
}

// provideSnapshotScheduler: *holdingapp.Service implements Snapshotter via SnapshotAllHoldings.
func provideSnapshotScheduler(svc *holdingapp.Service, src holdingscheduler.IntervalSource) *holdingscheduler.SnapshotScheduler {
	return holdingscheduler.NewSnapshotScheduler(svc, src, 1*time.Hour, nil)
}
```
(import:`repository`、`currencyrepo`、`domain`、`priceprovider`、`holdingscheduler`、`holdingapp`、`time`、`context`、`ent`。)

- [ ] **Step 2: 改 provideHoldingService 注入 4 setter + currencyService 注入 rateHistoryRepo**

Read `provideHoldingService` 现状(B 已加 priceRouter)。在 B 基础上追加 4 setter 调用:
```go
func provideHoldingService(
	secRepo domain.SecurityRepository, hRepo domain.HoldingRepository, tRepo domain.TradeRepository,
	priceRouter priceprovider.Router,
	lotRepo domain.LotRepository, snapshotRepo domain.SnapshotRepository,
	priceHistoryRepo domain.PriceHistoryRepository, historicalProvider priceprovider.HistoricalProvider,
	holdingRateRepo domain.RateHistoryRepository,
) *holdingapp.Service {
	svc := holdingapp.NewService(secRepo, hRepo, tRepo)
	svc.SetPriceRouter(priceRouter)
	svc.SetLotRepository(lotRepo)
	svc.SetSnapshotRepository(snapshotRepo)
	svc.SetPriceHistoryRepository(priceHistoryRepo)
	svc.SetHistoricalProvider(historicalProvider)
	svc.SetRateHistoryRepository(holdingRateRepo)
	return svc
}
```
currency `provideCurrencyService` 加:`svc.SetRateHistoryRepository(rateHistoryRepo)`(currency 的 RateHistoryRepo,直接注入,不需 adapter)。

- [ ] **Step 3: 手改 wire_gen.go(镜像 B 的 priceScheduler 行 + 加新变量)**

Read `wire_gen.go`(B 已有 priceRouter/priceScheduler)。在 priceScheduler 行之后加:
```go
lotRepo := provideLotRepo(client)
snapshotRepo := provideSnapshotRepo(client)
priceHistoryRepo := providePriceHistoryRepo(client)
historicalProvider := provideHistoricalProvider()
currencyRateHistoryRepo := provideCurrencyRateHistoryRepo(client) // currency RateHistoryRepo provider
holdingRateRepo := provideHoldingRateRepo(currencyRateHistoryRepo)
snapshotScheduler := provideSnapshotScheduler(holdingService, intervalSource)
```
改 `holdingService := provideHoldingService(...)` 行(Read 原参数,追加 5 个新实参 lotRepo/snapshotRepo/priceHistoryRepo/historicalProvider/holdingRateRepo)。
改 currencyService 构造行加 currencyRateHistoryRepo 实参。
改 `NewApp(...)` 末尾加 `snapshotScheduler` 实参。
> ⚠️ 全部以 Read wire_gen.go 的确切行为准,只追加新变量 + 改实参(镜像 B 改法)。加 `provideCurrencyRateHistoryRepo` 若 providers.go 没写(Step 1 补:`func provideCurrencyRateHistoryRepo(client) currencyrepo.RateHistoryRepo { return currencyrepo.NewRateHistoryRepo(client) }`)。

- [ ] **Step 4: app.go 加 SnapshotScheduler**

App struct 加字段(在 `HoldingScheduler` 之后):`SnapshotScheduler *holdingscheduler.SnapshotScheduler`。NewApp 签名加参数 + struct literal 加赋值(镜像 B 的 HoldingScheduler 改法)。

- [ ] **Step 5: main.go 加 SnapshotScheduler.Start + 启动异步回填**

在 `go app.HoldingScheduler.Start(schedCtx)`(B 加的)之后加:
```go
// Start holding snapshot scheduler (daily market-value snapshots).
go app.SnapshotScheduler.Start(schedCtx)

// Backfill price history on first launch (empty table gate), async — does
// not block startup. Pulls Sina daily K-line for A-share holdings + CSI300.
go func() {
	if count, err := app.HoldingService.BackfillPriceHistory(context.Background(), "YEAR"); err != nil {
		app.Log.Error("holding backfill failed", "error", err, "operation", "main.backfill")
	} else if count > 0 {
		app.Log.Info("holding backfill completed", "count", count, "operation", "main.backfill")
	}
}()
```
> 确认 App 暴露 `HoldingService`(Read app.go;若无该字段,用 holdingService 变量或加 App.HoldingService 字段)。`app.Log` —— 确认 App 有 logger 字段名(B 已用)。Backfill 用 "YEAR"(拉 5 年,首次全量);Empty gate 在 BackfillPriceHistory 内(Exists)。

- [ ] **Step 6: go build 全量绿 + 全量 test**

```bash
cd /e/projects/syfinance/yucai/server && go build ./...
cd /e/projects/syfinance/yucai/server && go test ./... -count=1
```
Expected:**PASS**。若报错:wire_gen 参数个数/顺序 → 检查 Step 3;adapter 类型 → 检查 holdingRateAdapter 实现 holding domain 接口(FindRate/FindRange map 签名)。

- [ ] **Step 7: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/wire/ yucai/server/cmd/server/main.go
git commit -m "feat(holding-c-server): wire+main 接线 4 repo+SnapshotScheduler+启动回填

providers.go:4 repo provider + historicalProvider(=Sina)+ holdingRateRepo
(currency→holding adapter,slice→map)+ SnapshotScheduler。provideHoldingService
注入 5 setter。wire_gen.go 手改(镜像 B,加新变量+实参)。app.go:App.
SnapshotScheduler。main:go SnapshotScheduler.Start + 异步 BackfillPriceHistory
(空表门控,YEAR 深度)。go build 绿 + 全量 test 过。"
```

---

## Task 10: server 端到端验证(回填 + snapshot + 曲线 RPC 真数据)

**Files:** 无改动(验证 task)

**背景**:验证 server 启动后:① 启动异步回填 price_history(CSI300 + A 股日 K);② SnapshotScheduler 写 holding_snapshot;③ GetPortfolioPerformance/GetHoldingPerformance RPC 返回真曲线点。

- [ ] **Step 1: 重建 server + 起 podman DB**

```bash
cd /e/projects/syfinance/yucai/server && go build -o bin/server.exe ./cmd/server
"C:\Users\andy\AppData\Local\Programs\Podman\podman.exe" ps --filter name=yucai-pg --format '{{.Names}} {{.Status}}'
```

- [ ] **Step 2: 起 server(background,绝对路径 cwd,见 [[yucai-dev-env]])**

```bash
cd /e/projects/syfinance/yucai/server && \
export DATABASE_URL='postgresql://yucai:yucai@localhost:5432/yucai?sslmode=disable' && \
export JWT_SECRET='dev-secret-change-me-32chars-minimum-aaaa' && \
export GRPC_PORT=9090 && export LOG_LEVEL=debug && \
./bin/server.exe 2>&1
```
监听日志:`holding backfill completed count:N`(N≥1,首次空表触发)+ `holding snapshot completed count:N`。回填是异步网络操作,可能需几秒~几十秒(拉日 K)。

- [ ] **Step 3: DB 验证表有数据**

```bash
"C:\Users\andy\AppData\Local\Programs\Podman\podman.exe" exec yucai-pg psql -U yucai -d yucai -c \
  "SELECT symbol, count(*) FROM security_price_histories ph JOIN securities s ON s.id=ph.security_id GROUP BY symbol ORDER BY symbol;"
"C:\Users\andy\AppData\Local\Programs\Podman\podman.exe" exec yucai-pg psql -U yucai -d yucai -c \
  "SELECT count(*) FROM holding_snapshots;"
```
Expected:security_price_histories 有 600519/510300/511010/000300 各 ~N 条(回填拉到的日 K);holding_snapshots 有当前 holdings 数条(snapshot 写入)。记实际 count 作证据。

- [ ] **Step 4(可选): grpcurl 调 GetPortfolioPerformance 验证曲线点**

```bash
# 登录拿 token(test@yucai.local/test1234),再调
grpcurl -plaintext -d '{"range":"CURVE_RANGE_DAY","include_benchmark":true}' \
  -H "authorization: Bearer <TOKEN>" localhost:9090 yucai.holding.v1.HoldingService/GetPortfolioPerformance
```
Expected:`{"portfolioPoints":[...], "benchmarkPoints":[...], "realizedCents":..., "annualizedPct":...}`。portfolioPoints 非空(snapshot 有数据)。若没 grpcurl,Task 13 client run 覆盖。

- [ ] **Step 5: TaskStop server,记录证据**

停 background server。ledger 记 "Task 10:回填 price_history count=X,snapshot count=Y,曲线 RPC 返回真点"。(无 commit)

---

## Task 11: Flutter proto stub 重生成(make gen-dart)

**Files:**
- Regenerate: `yucai/client/lib/proto/holding/v1/holding.pb.dart`、`holding.pbgrpc.dart`

**背景**:Task 8 改了 proto,client stub 需重生成(protoc_plugin 25.0.0)。非 TDD setup。

- [ ] **Step 1: 确认 protoc_plugin 25.0.0**

```bash
dart pub global activate protoc_plugin 25.0.0
```

- [ ] **Step 2: gen-dart**

```bash
cd /e/projects/syfinance/yucai && make gen-dart
```
Expected:`holding.pb.dart` 出现 `CurveRange`/`CurvePoint`/`GetPortfolioPerformanceRequest`/`PortfolioPerformanceResponse`/`GetHoldingPerformanceRequest`/`HoldingPerformanceResponse`/`BackfillPriceHistoryRequest`/`Response`;`holding.pbgrpc.dart` 的 `HoldingServiceClient` 加 `getPortfolioPerformance`/`getHoldingPerformance`/`backfillPriceHistory` 方法。

- [ ] **Step 3: flutter analyze 基线确认**

```bash
cd /e/projects/syfinance/yucai/client && flutter analyze lib/proto/holding/ 2>&1 | tail -5
```
Expected:0 新 error(22 基线全 *.pbserver.dart,非 holding)。

- [ ] **Step 4: Commit**

```bash
cd /e/projects/syfinance
git add yucai/client/lib/proto/holding/v1/
git commit -m "feat(holding-c-flutter): 重生成 Dart stub(C 3 performance RPC)

getPortfolioPerformance/getHoldingPerformance/backfillPriceHistory client
方法 + CurveRange/CurvePoint/Performance message。protoc_plugin 25.0.0。"
```

---

## Task 12: Flutter data/domain(performance entity + remote_ds + repository + mapper)+ 单测

**Files:**
- Create: `yucai/client/lib/holding/domain/entities/performance_entity.dart`
- Modify: `yucai/client/lib/holding/data/holding_remote_ds.dart`(加 2 方法)
- Modify: `yucai/client/lib/holding/domain/repositories/holding_repository.dart`(加 2 抽象)
- Modify: `yucai/client/lib/holding/data/holding_repository_impl.dart`(加 2 实现)
- Modify: `yucai/client/lib/holding/data/holding_mapper.dart`(加 CurvePoint→PerfPoint + response→entity)
- Test: `yucai/client/test/holding/data/holding_remote_ds_test.dart` 或 mapper test

**Interfaces:**
- Consumes:Dart stub `getPortfolioPerformance`/`getHoldingPerformance`(Task 11)、`PerfPoint`/`PerfCurveFoot`(`presentation/widgets/perf_curve_chart.dart`,已定型)
- Produces:
  - `PortfolioPerformance` / `HoldingPerformance` entity(points + foot + 年化)
  - `HoldingRemoteDataSource.getPortfolioPerformance(range, accountId?, benchmark?) → Future<PortfolioPerformance>`
  - `HoldingRemoteDataSource.getHoldingPerformance(holdingId, range) → Future<HoldingPerformance>`
  - `HoldingRepository.getPortfolioPerformance/getHoldingPerformance → Future<Either<Failure, ...>>`
- Task 13(bloc)依赖

**背景**:对齐 B 的 `syncPrices` ds/repo 模式。entity 复用 widget 的 PerfPoint(纯数据,务实 import;若想更干净可后续提取 PerfPoint 到 domain)。

- [ ] **Step 1: 写 performance_entity.dart**

`yucai/client/lib/holding/domain/entities/performance_entity.dart`:
```dart
import 'package:equatable/equatable.dart';
import '../../presentation/widgets/perf_curve_chart.dart' show PerfPoint;

class PortfolioPerformance extends Equatable {
  const PortfolioPerformance({
    this.portfolioPoints = const [],
    this.benchmarkPoints = const [],
    this.benchmarkName = '',
    required this.realizedCents,
    required this.unrealizedCents,
    required this.totalCents,
    this.annualizedPct = 0,
    this.totalPct = 0,
    this.currency = 'CNY',
  });
  final List<PerfPoint> portfolioPoints;
  final List<PerfPoint> benchmarkPoints;
  final String benchmarkName;
  final int realizedCents;
  final int unrealizedCents;
  final int totalCents;
  final double annualizedPct;
  final double totalPct;
  final String currency;

  @override
  List<Object?> get props => [portfolioPoints, benchmarkPoints, benchmarkName,
      realizedCents, unrealizedCents, totalCents, annualizedPct, totalPct, currency];
}

class HoldingPerformance extends Equatable {
  const HoldingPerformance({
    this.pricePoints = const [],
    required this.realizedCents,
    required this.unrealizedCents,
    required this.totalCents,
    this.currency = 'CNY',
  });
  final List<PerfPoint> pricePoints;
  final int realizedCents;
  final int unrealizedCents;
  final int totalCents;
  final String currency;

  @override
  List<Object?> get props => [pricePoints, realizedCents, unrealizedCents, totalCents, currency];
}
```
> ⚠️ domain import presentation widget 是 layering 让步。**更干净方案**:把 `PerfPoint`/`PerfCurveFoot` 从 `perf_curve_chart.dart` 提取到 `domain/entities/perf_point.dart`,widget 改 import domain。首批可选:务实 import(快)或提取(干净)。执行者二选一,若提取则在 Step 1 前先移动 PerfPoint + 更新 perf_curve_chart.dart import。

- [ ] **Step 2: holding_mapper.dart 加映射**

在 `holding_mapper.dart` 加:
```dart
PerfPoint curvePointToPerfPoint(pb.CurvePoint cp) =>
    PerfPoint(time: cp.time.toDateTime(), value: cp.value);

PortfolioPerformance portfolioResponseToEntity(pb.PortfolioPerformanceResponse r) =>
    PortfolioPerformance(
      portfolioPoints: r.portfolioPoints.map(curvePointToPerfPoint).toList(),
      benchmarkPoints: r.benchmarkPoints.map(curvePointToPerfPoint).toList(),
      benchmarkName: r.benchmarkName,
      realizedCents: r.realizedCents,
      unrealizedCents: r.unrealizedCents,
      totalCents: r.totalCents,
      annualizedPct: r.annualizedPct,
      totalPct: r.totalPct,
      currency: r.currency,
    );

HoldingPerformance holdingResponseToEntity(pb.HoldingPerformanceResponse r) =>
    HoldingPerformance(
      pricePoints: r.pricePoints.map(curvePointToPerfPoint).toList(),
      realizedCents: r.realizedCents,
      unrealizedCents: r.unrealizedCents,
      totalCents: r.totalCents,
      currency: r.currency,
    );

pb.CurveRange curveRangeToProto(String range) {
  switch (range) {
    case 'MONTH': return pb.CurveRange.CURVE_RANGE_MONTH;
    case 'YEAR': return pb.CurveRange.CURVE_RANGE_YEAR;
    default: return pb.CurveRange.CURVE_RANGE_DAY;
  }
}
```
(`cp.time.toDateTime()` — protobuf 6.x Timestamp 扩展;若不可用用 `DateTime.fromMillisecondsSinceEpoch(cp.time.seconds * 1000)`,见 B Task 9 Step 2。)

- [ ] **Step 3: remote_ds 加 2 方法**

在 `holding_remote_ds.dart` 的 `syncPrices`(B 加的)之后加:
```dart
  Future<PortfolioPerformance> getPortfolioPerformance({
    required String range,
    String? accountId,
    bool includeBenchmark = false,
  }) async {
    return _retry.call(() async {
      final req = pb.GetPortfolioPerformanceRequest(
        accountId: accountId ?? '',
        range: curveRangeToProto(range),
        includeBenchmark: includeBenchmark,
      );
      final res = await _client.getPortfolioPerformance(req);
      return portfolioResponseToEntity(res);
    });
  }

  Future<HoldingPerformance> getHoldingPerformance({
    required String holdingId,
    required String range,
  }) async {
    return _retry.call(() async {
      final res = await _client.getHoldingPerformance(
        pb.GetHoldingPerformanceRequest(holdingId: holdingId, range: curveRangeToProto(range)),
      );
      return holdingResponseToEntity(res);
    });
  }
```
(import PortfolioPerformance/HoldingPerformance entity + mapper。)

- [ ] **Step 4: repository 抽象 + impl 加 2 方法**

`holding_repository.dart` 加:
```dart
  Future<Either<Failure, PortfolioPerformance>> getPortfolioPerformance({
    required String range, String? accountId, bool includeBenchmark = false,
  });
  Future<Either<Failure, HoldingPerformance>> getHoldingPerformance({
    required String holdingId, required String range,
  });
```
`holding_repository_impl.dart` 加:
```dart
  @override
  Future<Either<Failure, PortfolioPerformance>> getPortfolioPerformance({
    required String range, String? accountId, bool includeBenchmark = false,
  }) => _guard(() => _remote.getPortfolioPerformance(range: range, accountId: accountId, includeBenchmark: includeBenchmark));

  @override
  Future<Either<Failure, HoldingPerformance>> getHoldingPerformance({
    required String holdingId, required String range,
  }) => _guard(() => _remote.getHoldingPerformance(holdingId: holdingId, range: range));
```

- [ ] **Step 5: 单测(mapper + ds response-wiring)**

照 B Task 9 的 ds test 模式:mock `HoldingServiceClient.getPortfolioPerformance` 返回 response(2 portfolioPoints + realized=800)→ 断言 ds 返回 `PortfolioPerformance(portfolioPoints.length==2, realizedCents==800)`。mapper test:CurvePoint→PerfPoint 时间/值转换。

- [ ] **Step 6: flutter analyze + test**

```bash
cd /e/projects/syfinance/yucai/client && flutter analyze lib/holding/
cd /e/projects/syfinance/yucai/client && flutter test test/holding/
```
Expected:analyze 0 新 error;test PASS(现有 101 + 新增)。

- [ ] **Step 7: Commit**

```bash
cd /e/projects/syfinance
git add yucai/client/lib/holding/
git commit -m "feat(holding-c-flutter): data/domain getPortfolioPerformance+getHoldingPerformance

PortfolioPerformance/HoldingPerformance entity(复用 PerfPoint)。mapper
CurvePoint→PerfPoint + response→entity + curveRangeToProto。remote_ds/repo
2 方法(_retry 包裹)。mapper + ds 单测。"
```

---

## Task 13: Flutter presentation(PerformanceBloc + HoldingBloc 曲线 + 填 6 ⏳C 点)+ widget test

**Files:**
- Create: `yucai/client/lib/holding/presentation/bloc/performance_bloc.dart` + `performance_event.dart` + `performance_state.dart`
- Modify: `yucai/client/lib/holding/presentation/bloc/holding_event.dart`(加 LoadHoldingCurveRequested)
- Modify: `yucai/client/lib/holding/presentation/bloc/holding_state.dart`(HoldingDetailLoaded 加 holdingCurve/holdingCurveFoot)
- Modify: `yucai/client/lib/holding/presentation/bloc/holding_bloc.dart`(加 _onLoadHoldingCurve)
- Modify: `yucai/client/lib/holding/presentation/pages/performance_page.dart`(接 PerformanceBloc 填 ①③④⑤)
- Modify: `yucai/client/lib/holding/presentation/pages/holding_detail_page.dart`(接曲线填 ②⑥,删 _costBasisCurve/_realizedFromTrades)
- Modify: `yucai/client/lib/holding/presentation/pages/performance_page.dart` route wrapper(BlocProvider<PerformanceBloc>)
- Test: `yucai/client/test/holding/presentation/bloc/performance_bloc_test.dart` + widget test

**Interfaces:**
- Consumes:`HoldingRepository.getPortfolioPerformance/getHoldingPerformance`(Task 12)、`PerfCurveChart`(已定型)
- Produces:6 个 ⏳C 点接真数据

**背景**:新建 PerformanceBloc(performance 页,职责分离)。holding_detail 曲线用 HoldingBloc 子 event(range 切换只更曲线)。

- [ ] **Step 1: performance_event.dart + performance_state.dart**

`performance_event.dart`:
```dart
abstract class PerformanceEvent extends Equatable {
  const PerformanceEvent();
  @override List<Object?> get props => [];
}

class LoadPortfolioPerformanceRequested extends PerformanceEvent {
  const LoadPortfolioPerformanceRequested({this.range = 'DAY', this.accountId});
  final String range;
  final String? accountId;
  @override List<Object?> get props => [range, accountId];
}
```
`performance_state.dart`:
```dart
abstract class PerformanceState extends Equatable {
  const PerformanceState();
  @override List<Object?> get props => [];
}
class PerformanceInitial extends PerformanceState {}
class PerformanceLoading extends PerformanceState {}
class PerformanceLoaded extends PerformanceState {
  const PerformanceLoaded(this.performance);
  final PortfolioPerformance performance;
  @override List<Object?> get props => [performance];
}
class PerformanceError extends PerformanceState {
  const PerformanceError(this.message);
  final String message;
  @override List<Object?> get props => [message];
}
```

- [ ] **Step 2: performance_bloc.dart**

```dart
@injectable
class PerformanceBloc extends Bloc<PerformanceEvent, PerformanceState> {
  PerformanceBloc(this._repo) : super(PerformanceInitial()) {
    on<LoadPortfolioPerformanceRequested>(_onLoad);
  }
  final HoldingRepository _repo;

  Future<void> _onLoad(LoadPortfolioPerformanceRequested event, Emitter<PerformanceState> emit) async {
    emit(PerformanceLoading());
    final result = await _repo.getPortfolioPerformance(
      range: event.range, accountId: event.accountId, includeBenchmark: true,
    );
    result.fold(
      (f) => emit(PerformanceError(f.displayMessage)),
      (perf) => emit(PerformanceLoaded(perf)),
    );
  }
}
```
> DI:`@injectable` + build_runner 重生成 injection.config.dart(`cd yucai && make flutter-build-runner`)。注入 HoldingRepository(getIt<HoldingRepository>())。

- [ ] **Step 3: holding_event/state/bloc 加曲线子 event**

`holding_event.dart` 加:
```dart
class LoadHoldingCurveRequested extends HoldingEvent {
  const LoadHoldingCurveRequested({required this.holdingId, this.range = 'DAY'});
  final String holdingId;
  final String range;
  @override List<Object?> get props => [holdingId, range];
}
```
`holding_state.dart` 的 `HoldingDetailLoaded`(Task 8 A-flutter)加字段:
```dart
  final List<PerfPoint>? holdingCurve;
  final int? holdingCurveRealizedCents;
```
(props 加这 2 项。)
`holding_bloc.dart` 加 handler:
```dart
  Future<void> _onLoadHoldingCurve(LoadHoldingCurveRequested event, Emitter<HoldingState> emit) async {
    final result = await _repo.getHoldingPerformance(holdingId: event.holdingId, range: event.range);
    final current = _last is HoldingDetailLoaded ? _last as HoldingDetailLoaded : null;
    result.fold(
      (f) => emit(current != null
          ? current.copyWith() // keep, curve 区空态(isPendingBackend 风格)
          : HoldingError(f.displayMessage, last: _last)),
      (perf) => emit(HoldingDetailLoaded(
        holding: current?.holding ?? /* fallback */ ...,
        trades: current?.trades ?? const [],
        holdingCurve: perf.pricePoints,
        holdingCurveRealizedCents: perf.realizedCents,
        isPendingBackend: false,
      )),
    );
  }
```
> ⚠️ `HoldingDetailLoaded` 现有构造(holding + trades + isPendingBackend,见 A-flutter Task 8)。加 holdingCurve/holdingCurveRealizedCents 字段 + 构造参数。`_last` 是 bloc 现有字段。copyWith 若无,加。`on<LoadHoldingCurveRequested>(_onLoadHoldingCurve)` 注册。detail 页 LoadDetail 后自动发 LoadHoldingCurveRequested(或 range tab 切换发)。

- [ ] **Step 4: performance_page.dart 接 PerformanceBloc 填 ①③④⑤**

Read `performance_page.dart` 的 ⏳ 位置(Explore 报告):
- `:227`(总收益曲线 `points: const []`)→ `points: state.performance.portfolioPoints`(PerformanceLoaded)
- `:381`(realized 分解「⏳C 待后端」)→ `state.performance.realizedCents`
- `:468`(年化 `'⏳'`)→ `state.performance.annualizedPct.toStringAsFixed(1) + '%'`
- `:456`(基准 mock)→ `state.performance.benchmarkPoints`(传 PerfCurveChart)
页面顶部包 `BlocProvider<PerformanceBloc>(create: (_) => getIt<PerformanceBloc>()..add(const LoadPortfolioPerformanceRequested()))`,body 用 `BlocBuilder<PerformanceBloc, PerformanceState>`。range tab 切换 → `add(LoadPortfolioPerformanceRequested(range: ...))`。PerformanceLoading/Error/Loaded 分支(Loaded 渲染真数据,Loading 保留 foot 前端算的区)。

- [ ] **Step 5: holding_detail_page.dart 接曲线填 ②⑥**

Read `holding_detail_page.dart`:
- `:445` `_curveCard`/`_costBasisCurve`(trades 重建成本线)→ 替换为 `state.holdingCurve`(从 HoldingDetailLoaded 取);`<2` 走 PerfCurveChart 空态。删 `_costBasisCurve` + `_realizedFromTrades`(`:459-472`)。
- `:464` foot realized(`_realizedFromTrades` 近似)→ `state.holdingCurveRealizedCents ?? 0`。
detail 页 BlocBuilder 读 `HoldingDetailLoaded.holdingCurve`/`holdingCurveRealizedCents`。range tab → `context.read<HoldingBloc>().add(LoadHoldingCurveRequested(holdingId: ..., range: ...))`。

- [ ] **Step 6: 路由注入 PerformanceBloc**

Read `app/router.dart` 的 `/holdings/performance` 分支(A-flutter Task 11)。包 `BlocProvider<PerformanceBloc>`(对齐其他页 BlocProvider 模式)。

- [ ] **Step 7: build_runner + flutter analyze + test**

```bash
cd /e/projects/syfinance/yucai && make flutter-build-runner
cd /e/projects/syfinance/yucai/client && flutter analyze lib/holding/
cd /e/projects/syfinance/yucai/client && flutter test test/holding/
```
Expected:build_runner 注册 PerformanceBloc;analyze 0 新 error;test PASS。

- [ ] **Step 8: widget test**

`performance_bloc_test.dart`(mock repo.getPortfolioPerformance → Right(PortfolioPerformance(portfolioPoints:[2], realizedCents:800))→ emit [Loading, Loaded]);Left → Error)。widget test:performance_page 真数据渲染(曲线点数>0)+ 空态(Left);holding_detail 曲线区真数据。

- [ ] **Step 9: Commit**

```bash
cd /e/projects/syfinance
git add yucai/client/lib/holding/ yucai/client/test/holding/
git commit -m "feat(holding-c-flutter): PerformanceBloc + HoldingBloc 曲线子event + 填 6 ⏳C 点

新建 PerformanceBloc(LoadPortfolioPerformanceRequested + Loading/Loaded/Error)。
HoldingBloc 加 LoadHoldingCurveRequested(range 切换只更曲线)+ HoldingDetailLoaded
加 holdingCurve/realized。performance_page 填 ①曲线③realized④年化⑤基准;
holding_detail_page 填 ②行情曲线⑥server FIFO realized(删 _costBasisCurve/
_realizedFromTrades 近似)。路由注入 PerformanceBloc。bloc + widget test。"
```

---

## Task 14: 全链路验证 + final whole-branch review

**Files:** 无改动(验证 task)

- [ ] **Step 1: server 全量绿**

```bash
cd /e/projects/syfinance/yucai/server && go build ./... && go test ./... -count=1
```
Expected:PASS。

- [ ] **Step 2: flutter 全量绿**

```bash
cd /e/projects/syfinance/yucai/client && flutter analyze lib/holding/ && flutter test test/holding/
```
Expected:analyze 0 新 error(22 基线 *.pbserver);test PASS(现有 101 + C 新增)。

- [ ] **Step 3: 端到端(flutter run,见 [[yucai-dev-env]] debug 模式)**

```bash
cd /e/projects/syfinance/yucai/client && flutter run -d windows
```
验证:
1. **performance 页**:总收益曲线显示真点(snapshot 累积)+ realized 分解真值 + 年化真% + CSI300 基准线;range(日/月/年)切换重渲染
2. **holding 详情页**:收益曲线显示真行情价(price_history)+ realized 显示 server FIFO 值(非前端近似)
3. 降级:某区 RPC fail → 该区空态/'—'(非崩溃)

- [ ] **Step 4: 6 个 ⏳C 点全部转真**

ledger 记:①②③④⑤⑥ 全接真数据,A-flutter 的 ⏳C 降级清零(剩 ⏳D goal-link 仍 ⏳,D 子项目做)。

- [ ] **Step 5: final whole-branch review**

MERGE_BASE = `fefd059`(B 终点,C commits 从 `cbe566a` spec 起)。用 opus 广审 C commits,对齐 A/B review 流程:
- correctness:FIFO realized 精确性 / lot split-adjusted / 曲线采样折算 / rate 向前填充 / 回填幂等 / proto 对齐
- 不破坏 A(双写)+ B(SyncPrices)
- 测试覆盖(domain 8 + repo + provider + application + scheduler + handler + Flutter)
- 无 Critical/Important

---

## Self-Review(plan 自查)

**1. Spec coverage**(对照 spec 各节):
- §1 目标(时序+FIFO+曲线+年化+基准)→ Tasks 1-14 ✅
- §2 范围边界 → 全 task 在 C 范围,无 D(budget/goal)越界 ✅
- §3 架构(4 表+scheduler 复用+2 主 RPC+Flutter)→ Tasks 2/5-9/11-13 ✅
- §4 schema(4 表+1 列)→ Task 2 ✅(split lot PriceCents/ratio 修正于 Task 5 注明)
- §5.1 domain FIFO → Task 1 ✅(refine:ConsumeLotsFIFO 纯函数,不重写 ApplySell)
- §5.2 application(snapshot/backfill/curve)→ Task 6 ✅(GetRealizedSummary 冗余已并 GetPortfolioPerformance)
- §5.3 scheduler 时序分工 → Task 7(SnapshotScheduler)+ Task 5 Step 8(B SyncPrices 写 price_history)+ Task 7 Step 4(currency SyncRates 写 rate_history)✅
- §5.4 priceprovider HistoricalProvider → Task 4 ✅
- §5.5 回填 → Task 6 BackfillPriceHistory + Task 9 Step 5 main 异步触发 ✅
- §5.6 wire+main → Task 9 ✅
- §6 proto(2 主 RPC+Backfill+CurveRange/CurvePoint)→ Task 8 ✅(CurvePoint double/foot cents 在 handler 映射)
- §7 Flutter(6 点映射+PerformanceBloc+HoldingBloc 曲线)→ Tasks 11-13 ✅
- §8 失败/降级 → Task 6 best-effort + Task 4 provider + Task 7 scheduler + Task 13 Flutter 局部降级 ✅
- §9 测试 → 每 task TDD ✅
- §10 前置验证 → Task 0 ✅
- §11 实施顺序 → Tasks 0-14(spec Task 5 拆为 plan Task 5+6,application 三个关注点分两 task)✅
- §13 风险 → ent 生成(Task 0 验证)/ 新浪日 K(Task 4 httptest + Task 10 真实)/ 改 A entity(Task 1 不碰 ApplySell,Task 5 service 改)/ 跨模块 currency(Task 7 + adapter)✅
- §14 新浪日 K 接口 → Task 4 FetchHistory 完整实现 + Task 10 真实验证 ✅

**2. Placeholder scan**:
- Task 3 repo where 包名 / Task 9 wire 实参 → "Read 生成的 where.go / wire_gen.go 后镜像"明确路径(非 placeholder,必要的接口发现,对齐 B plan Self-Review 辩护)
- Task 6 `currentCostBasisCNY`/`GetHoldingPerformance` 完整实现 → "照 currentUnrealizedCNY/GetPortfolioPerformance 模式 + TDD Step 6 驱动"(给了模板方法 + 测试,执行者照模式补全,非空 placeholder)
- Task 6 FindByID(HoldingRepository)→ Step 5 显式标注需补接口(已识别的 gap,非遗漏)
- Task 7 FindAll(Nil)tenant 语义 → Step 1 显式标注确认/调整(对齐 B plan 对现有代码精确对齐的处理)
- 这些是"对现有代码精确对齐 + 照模式补全"的必要步骤,不是内容缺失

**3. Type consistency**:
- `ConsumeLotsFIFO(sellQty float64, sellPriceCents int64, lots []HoldingLot) (realized int64, consumed []LotConsumption, err error)`:Task 1 定义 → Task 5 SellHolding 调用 → 一致 ✅
- `LotAvgCost(lots []HoldingLot) int64`:Task 1 → Task 5 Buy/Sell 用 → 一致 ✅
- `HoldingLot.RemainingQuantity float64`:Task 1 → Task 3 LotRepo → Task 5 消耗 → 一致 ✅
- `HoldingTransaction.RealizedPnLCents int64`:Task 5 Step 1 加 → Task 5 SellHolding 赋值 → Task 6 aggregateRealized Σ → Task 8 handler 映射 realized_cents → 一致 ✅
- `SnapshotAllHoldings(ctx)(int,error)`:Task 7 Snapshotter 接口 → Task 7 service 实现 → Task 9 wire(svc implements)→ 一致 ✅
- `GetPortfolioPerformance(ctx, tenantID, accountID*, range, withBenchmark) (*PortfolioPerformance, error)`:Task 6 → Task 8 handler → 一致 ✅
- proto `CurveRange`/`CurvePoint`/3 RPC:Task 8 定义 → Task 11 Dart stub → Task 12 mapper → Task 13 bloc → 一致 ✅
- `PortfolioPerformance.portfolioPoints: List<PerfPoint>`(Dart):Task 12 entity → Task 13 page 用 → PerfCurveChart 契约 → 一致 ✅

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-06-30-holding-snapshot.md`. 执行方式见下方对话。
