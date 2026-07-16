# split-adjusted price(TWR split 日 BV 修正)Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修正 TWR 在 stock split 当天的 BV 跨尺度 bug —— 纯 split 日不作为 cashFlowDays 切点,使 split 市值中性、不产生虚假 HPR。

**Architecture:** 单函数改动 `uniqueSortedTradeDates`([service.go:1355](../../yucai/server/internal/holding/application/service.go#L1355))排除纯 split 日(split 是非现金流事件);`holdingTWR` + `portfolioTWR` 两 caller 自动受益,split 份额变化经 `QtyAtDate` replay 在相邻现金流日的 BV 自然体现。不动 XIRR / price 存储 / `QtyAtDate` / `priceAtOrBefore` / proto / client / handler。

**Tech Stack:** Go(server DDD application 层)、`go test`、现有 fake helper(`fakeSecurityRepoByID` / `fakeHoldingRepoSingle` / `fakeTradeRepo` / `fakeRateRepo`),新增 date-aware `splitPriceRepo`。

## Global Constraints

- 仅改 `yucai/server/internal/holding/application/service.go`(`uniqueSortedTradeDates`)+ `yucai/server/internal/holding/application/twr_service_test.go`(测试)。**无 proto / client / handler / domain ent / storage 改动。**
- 复用现有 fake helper(同包,见 `twr_service_test.go` 用法);date-aware price 场景新增 `splitPriceRepo`(定义在 `twr_service_test.go`)。
- split trade 构造照 `RecordSplit`([service.go:237](../../yucai/server/internal/holding/application/service.go#L237)):`TradeType: domain.TradeTypeSplit, Quantity: ratio`(ratio=2 表 1:2)。
- TDD:每个 task 先写失败测 → 跑证红 → 改实现 → 跑证绿 → commit。
- 测试命令(绝对路径 cd):`cd /e/projects/syfinance/yucai/server && go test ./internal/holding/application/... -count=1 -run <TestName>`;全量回归 `go test ./internal/holding/... -count=1`。
- English 结构化日志约束(本改动无新增日志,保持)。

参考 spec:[2026-07-16-split-adjusted-design.md](../specs/2026-07-16-split-adjusted-design.md)。

---

### Task 1: `uniqueSortedTradeDates` 排除纯 split 日

**Files:**
- Modify: `yucai/server/internal/holding/application/service.go:1354-1367`(`uniqueSortedTradeDates`)
- Test: `yucai/server/internal/holding/application/twr_service_test.go`(新增 2 个纯函数测)

**Interfaces:**
- Consumes: `domain.HoldingTransaction`(含 `TradeType` / `TradeDate`)、`domain.TradeTypeSplit` 常量(见 [xirr.go:132](../../yucai/server/internal/holding/domain/xirr.go#L132) 已用)
- Produces: `uniqueSortedTradeDates(trades []domain.HoldingTransaction) []time.Time` —— 签名不变,语义变为「只返回含 buy/sell/dividend 的日子」(纯 split 日排除)。2 个 caller(`portfolioTWR:1341` + `holdingTWR:1428`)自动受益,无需改 caller。

- [ ] **Step 1: 写失败测 —— 纯 split 日排除 + split+buy 同日保留**

追加到 `twr_service_test.go` 末尾:

```go
// TestUniqueSortedTradeDatesExcludesPureSplitDay: a day with only a split trade
// is NOT a cash-flow day (split is market-value-neutral, non-cash-flow) → must
// not seed a TWR sub-period. The split trade stays in trades for QtyAtDate replay.
func TestUniqueSortedTradeDatesExcludesPureSplitDay(t *testing.T) {
	secID := uuid.New()
	day0 := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	day1 := time.Date(2020, 1, 2, 0, 0, 0, 0, time.UTC)
	day2 := time.Date(2020, 1, 3, 0, 0, 0, 0, time.UTC)
	// buy day0, split day1 (pure split day), sell day2.
	trades := []domain.HoldingTransaction{
		{TradeType: domain.TradeTypeBuy, Quantity: 100, SecurityID: secID, TradeDate: day0},
		{TradeType: domain.TradeTypeSplit, Quantity: 2, SecurityID: secID, TradeDate: day1},
		{TradeType: domain.TradeTypeSell, Quantity: 50, SecurityID: secID, TradeDate: day2},
	}
	days := uniqueSortedTradeDates(trades)
	// day1 (pure split) excluded; day0 (buy) + day2 (sell) kept.
	if len(days) != 2 {
		t.Fatalf("len(days)=%d, want 2 (pure split day excluded); days=%v", len(days), days)
	}
	if !days[0].Equal(day0) || !days[1].Equal(day2) {
		t.Errorf("days=%v, want [day0, day2] (day1 pure split excluded)", days)
	}
}

// TestUniqueSortedTradeDatesKeepsSplitPlusBuyDay: split+buy same day → the buy
// makes it a cash-flow day, so the day is kept (split folded via QtyAtDate).
func TestUniqueSortedTradeDatesKeepsSplitPlusBuyDay(t *testing.T) {
	secID := uuid.New()
	day0 := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	day1 := time.Date(2020, 1, 2, 0, 0, 0, 0, time.UTC)
	trades := []domain.HoldingTransaction{
		{TradeType: domain.TradeTypeBuy, Quantity: 100, SecurityID: secID, TradeDate: day0},
		{TradeType: domain.TradeTypeSplit, Quantity: 2, SecurityID: secID, TradeDate: day1},
		{TradeType: domain.TradeTypeBuy, Quantity: 50, SecurityID: secID, TradeDate: day1}, // split+buy same day
	}
	days := uniqueSortedTradeDates(trades)
	if len(days) != 2 {
		t.Fatalf("len(days)=%d, want 2 (day1 has buy → kept); days=%v", len(days), days)
	}
	if !days[1].Equal(day1) {
		t.Errorf("days=%v, want day1 kept (split+buy same day is a cash-flow day)", days)
	}
}
```

- [ ] **Step 2: 跑测证红**

Run: `cd /e/projects/syfinance/yucai/server && go test ./internal/holding/application/... -count=1 -run 'TestUniqueSortedTradeDates'`
Expected: **FAIL** —— 当前 `uniqueSortedTradeDates` 含 split 日,`TestUniqueSortedTradeDatesExcludesPureSplitDay` 得 `len(days)=3`,断言 `len==2` 失败。

- [ ] **Step 3: 改实现 —— 排除纯 split 日**

替换 `service.go:1354-1367` 的 `uniqueSortedTradeDates`:

```go
// uniqueSortedTradeDates extracts unique trade_date values (day-truncated,
// sorted ascending) that are TWR cash-flow days — days with at least one
// buy/sell/dividend. Pure-split days are excluded: a split is a non-cash-flow
// event (market-value-neutral under GIPS), so it must not seed a TWR sub-period,
// or BV_before/after would pair one price with cross-scale (pre-/post-split)
// quantities → phantom HPR. The split trade stays in trades so QtyAtDate replay
// folds the ratio into the BV of the adjacent cash-flow days.
func uniqueSortedTradeDates(trades []domain.HoldingTransaction) []time.Time {
	hasCashFlow := map[time.Time]bool{}
	for _, t := range trades {
		if t.TradeType == domain.TradeTypeSplit {
			continue
		}
		hasCashFlow[t.TradeDate.Truncate(24*time.Hour)] = true
	}
	days := make([]time.Time, 0, len(hasCashFlow))
	for d := range hasCashFlow {
		days = append(days, d)
	}
	sort.Slice(days, func(i, j int) bool { return days[i].Before(days[j]) })
	return days
}
```

- [ ] **Step 4: 跑测证绿**

Run: `cd /e/projects/syfinance/yucai/server && go test ./internal/holding/application/... -count=1 -run 'TestUniqueSortedTradeDates'`
Expected: **PASS**(两个纯函数测均过)。

- [ ] **Step 5: 跑全 application 包回归证零回归**

Run: `cd /e/projects/syfinance/yucai/server && go test ./internal/holding/application/... -count=1`
Expected: **PASS** —— 无 split 场景的现有 TWR/XIRR 测 byte-identical(无纯 split 日 → cashFlowDays 不变)。

- [ ] **Step 6: Commit**

```bash
git add yucai/server/internal/holding/application/service.go yucai/server/internal/holding/application/twr_service_test.go
git commit -m "fix(holding/twr): split 日不作为 cashFlowDays 切点(纯 split 日排除,split 市值中性经 QtyAtDate replay 在相邻现金流日体现,无 split byte-identical)"
```

---

### Task 2: split 场景 TWR 集成验证(holdingTWR + portfolioTWR)+ 零回归

**Files:**
- Test: `yucai/server/internal/holding/application/twr_service_test.go`(新增 `splitPriceRepo` helper + 2 个集成测)
- 不改生产代码(Task 1 改动已使这些测转绿)

**Interfaces:**
- Consumes: Task 1 的 `uniqueSortedTradeDates` 新语义;`holdingTWR(holdingID)` / `portfolioTWR(tenantID, accountID, base, rangeStart)`;现有 fake helper;`domain.SecurityPriceHistory{PriceDate, PriceCents}`
- Produces: `splitPriceRepo`(date-aware fake,本 task 内定义,仅测试用)

**说明:** split bug 需 raw price **跨 split 跳变**(pre ¥100=10000 cents / post ¥50=5000 cents)才显现 —— 现有 `fakePriceRepo` 返恒定 price 测不出。故新增 `splitPriceRepo` 镜像 Sina(不复权)/ Yahoo(`quote.close` raw)的 raw 价格存储。

- [ ] **Step 1: 写失败测 —— date-aware `splitPriceRepo` + holdingTWR + portfolioTWR split 场景**

追加到 `twr_service_test.go` 末尾:

```go
// splitPriceRepo serves raw (unadjusted) prices that jump across a split:
// preSplitCents strictly before splitDay, postSplitCents on/after splitDay.
// Mirrors how Sina (不复权) and Yahoo (quote.close raw, not adjclose) store
// split-jumping raw prices — the root cause of the TWR split-day BV cross-scale
// bug (one price paired with pre-/post-split quantities).
type splitPriceRepo struct {
	splitDay       time.Time
	preSplitCents  int64
	postSplitCents int64
}

func (r *splitPriceRepo) FindBySecurity(ctx context.Context, securityID uuid.UUID, from, to time.Time) ([]domain.SecurityPriceHistory, error) {
	// preSplit entry predates any buy day (one year before split) so priceAtOrBefore
	// returns preSplit for every date strictly before splitDay, postSplit on/after.
	return []domain.SecurityPriceHistory{
		{PriceDate: r.splitDay.AddDate(-1, 0, 0), PriceCents: r.preSplitCents},
		{PriceDate: r.splitDay, PriceCents: r.postSplitCents},
	}, nil
}

// TestHoldingTWRSplitNoPhantomHPR: buy 100@¥100(day0) → split 1:2(day1) →
// sell 50@¥60(day2); raw price jumps 10000→5000 across split; current ¥60.
//
// GIPS hand-math (split day must NOT seed a sub-period):
//	cashFlowDays = [day0, day2]                       (day1 pure split excluded)
//	BV_after(day0)  = QtyAtDate(day1)×price(day0)   = 100×10000 = 1,000,000 (pre-split)
//	BV_before(day2) = QtyAtDate(day2)×price(day2)   = 200×6000  = 1,200,000 (post-split; replay split 100×2)
//	subPeriod HPR   = 1,200,000 / 1,000,000 = 1.2   → +20% real gain, NO phantom split HPR.
//
// Bug (split day as cut point) pairs one price with cross-scale qty at day1:
//	BV_before(day1)=100×5000=500,000 (pre-split qty × post-split price) → phantom −50% HPR
//	→ cumulative ≈ −40% (negative). Fix → positive TWR. Assert TWR > 0 to lock the fix.
func TestHoldingTWRSplitNoPhantomHPR(t *testing.T) {
	secID := uuid.New()
	holdID := uuid.New()
	accID := uuid.New()
	day0 := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	day1 := time.Date(2020, 1, 2, 0, 0, 0, 0, time.UTC)
	day2 := time.Date(2020, 1, 3, 0, 0, 0, 0, time.UTC)
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 6000}},
		holdingRepo:  &fakeHoldingRepoSingle{h: domain.Holding{ID: holdID, AccountID: accID, SecurityID: secID, Quantity: 150}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: day0, AccountID: accID},
			{TradeType: domain.TradeTypeSplit, Quantity: 2, SecurityID: secID, TradeDate: day1, AccountID: accID},
			{TradeType: domain.TradeTypeSell, Quantity: 50, AmountCents: 300000, SecurityID: secID, TradeDate: day2, AccountID: accID},
		}},
		priceHistoryRepo: &splitPriceRepo{splitDay: day1, preSplitCents: 10000, postSplitCents: 5000},
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	twr, err := svc.holdingTWR(context.Background(), holdID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if twr == nil {
		t.Fatal("holdingTWR nil, want non-nil (split folded; 2 cash-flow days day0/day2)")
	}
	// Real gain (current ¥60 > post-split cost basis ¥50) → positive TWR.
	// Bug (split as cut point) yields negative TWR (phantom −50% HPR at split day).
	if *twr <= 0 {
		t.Errorf("holdingTWR = %v, want > 0 (split must not seed phantom HPR; +20%% real gain)", *twr)
	}
}

// TestHoldingTWRSplitLastNeutral: split is the LAST trade. cashFlowDays exclude
// the pure-split day2 → [day0, day1]. lastAfterCF comes from day1 (pre-split
// scale: 50 × ¥100); finalValue is post-split (100 × ¥50). Split market-value
// neutrality (50×10000 == 100×5000) must connect the two scales → cumulative 0%.
//
// GIPS hand-math:
//	cashFlowDays = [day0, day1]                          (day2 pure split excluded)
//	BV_after(day0) = QtyAtDate(day1)×price(day0)       = 100×10000 = 1,000,000
//	subPeriod [day0→day1]: Begin=1,000,000, End=BV_before(day1)=100×10000=1,000,000 → HPR=1.0
//	lastAfterCF = BV_after(day1) = QtyAtDate(day2)×price(day1) = 50×10000 = 500,000 (pre-split)
//	finalValue  = 100(post-split)×5000 = 500,000
//	cumulative = 1.0 × 500,000/500,000 − 1 = 0  ✓
//
// Bug (day2 as cut point): BV_before(day2)=50×5000=250,000 (pre qty × post price)
// → phantom HPR 0.5 → cumulative ≈ −50%. Assert |TWR|<0.01 to lock neutrality.
func TestHoldingTWRSplitLastNeutral(t *testing.T) {
	secID := uuid.New()
	holdID := uuid.New()
	accID := uuid.New()
	day0 := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	day1 := time.Date(2020, 1, 2, 0, 0, 0, 0, time.UTC)
	day2 := time.Date(2020, 1, 3, 0, 0, 0, 0, time.UTC)
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 5000}},
		holdingRepo:  &fakeHoldingRepoSingle{h: domain.Holding{ID: holdID, AccountID: accID, SecurityID: secID, Quantity: 100}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: day0, AccountID: accID},
			{TradeType: domain.TradeTypeSell, Quantity: 50, AmountCents: 500000, SecurityID: secID, TradeDate: day1, AccountID: accID},
			{TradeType: domain.TradeTypeSplit, Quantity: 2, SecurityID: secID, TradeDate: day2, AccountID: accID},
		}},
		priceHistoryRepo: &splitPriceRepo{splitDay: day2, preSplitCents: 10000, postSplitCents: 5000},
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	twr, err := svc.holdingTWR(context.Background(), holdID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if twr == nil {
		t.Fatal("holdingTWR nil, want non-nil (split folded; 2 cash-flow days day0/day1)")
	}
	// Split last + market-value-neutral current (¥50) → cumulative 0%.
	// Bug (split as cut point) → strongly negative (phantom HPR). Assert ~0.
	if *twr > 0.01 || *twr < -0.01 {
		t.Errorf("holdingTWR = %v, want ~0 (split last, market-value-neutral; bug would be strongly negative)", *twr)
	}
}

// TestPortfolioTWRSplitNoPhantomHPR: same scenario at portfolio level — split
// must not seed a phantom sub-period in computeTWR either. rangeStart=day0 →
// rng == full (byte-identical, mirrors TestPortfolioTWRSimple). Both must be > 0.
func TestPortfolioTWRSplitNoPhantomHPR(t *testing.T) {
	secID := uuid.New()
	day0 := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	day1 := time.Date(2020, 1, 2, 0, 0, 0, 0, time.UTC)
	day2 := time.Date(2020, 1, 3, 0, 0, 0, 0, time.UTC)
	svc := &Service{
		securityRepo: &fakeSecurityRepoByID{sec: domain.Security{ID: secID, CurrencyCode: "CNY", CurrentPriceCents: 6000}},
		holdingRepo:  &fakeHoldingRepoSingle{h: domain.Holding{SecurityID: secID, Quantity: 150}},
		tradeRepo: &fakeTradeRepo{items: []domain.HoldingTransaction{
			{TradeType: domain.TradeTypeBuy, Quantity: 100, AmountCents: 1000000, SecurityID: secID, TradeDate: day0},
			{TradeType: domain.TradeTypeSplit, Quantity: 2, SecurityID: secID, TradeDate: day1},
			{TradeType: domain.TradeTypeSell, Quantity: 50, AmountCents: 300000, SecurityID: secID, TradeDate: day2},
		}},
		priceHistoryRepo: &splitPriceRepo{splitDay: day1, preSplitCents: 10000, postSplitCents: 5000},
		rateRepo:         &fakeRateRepo{rateByCode: map[string]float64{"CNY": 1.0}},
	}
	full, rng, err := svc.portfolioTWR(context.Background(), uuid.Nil, nil, "CNY", day0)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if full == nil {
		t.Fatal("portfolioTWR full nil, want non-nil (split folded; 2 cash-flow days)")
	}
	if *full <= 0 {
		t.Errorf("portfolioTWR full = %v, want > 0 (split must not seed phantom HPR)", *full)
	}
	if rng == nil {
		t.Fatal("portfolioTWR rng nil when rangeStart == cashFlowDays[0], want non-nil (== full)")
	}
	if diff := *rng - *full; diff > 1e-9 || diff < -1e-9 {
		t.Errorf("rng (%v) != full (%v) when rangeStart == cashFlowDays[0]", *rng, *full)
	}
}
```

- [ ] **Step 2: 跑测证绿(Task 1 改动已修 bug)**

Run: `cd /e/projects/syfinance/yucai/server && go test ./internal/holding/application/... -count=1 -run 'TestHoldingTWRSplit|TestPortfolioTWRSplit'`
Expected: **PASS**。

> 注:这两个测在 Task 1 改动**之前**会 FAIL(bug:`holdingTWR` 返负、`portfolioTWR` full 返负)。Task 1 已修,此处直接绿 —— 这验证 Task 1 改动对端到端 split 场景的修复生效。若想亲见红,可临时 `git stash` Task 1 的 service.go 改动后跑(可选,非必需)。

- [ ] **Step 3: 跑全 holding 包回归证零回归**

Run: `cd /e/projects/syfinance/yucai/server && go test ./internal/holding/... -count=1`
Expected: **PASS** —— 全 holding 包(domain + application + adapter)测全绿,含现有 TWR/XIRR/cache 测 byte-identical。

- [ ] **Step 4: Commit**

```bash
git add yucai/server/internal/holding/application/twr_service_test.go
git commit -m "test(holding/twr): split 场景 GIPS 集成测(holdingTWR+portfolioTWR 无虚假 HPR,date-aware splitPriceRepo 镜像 raw 价跳变)+ 零回归"
```

---

## 自审记录(plan 作者)

- **Spec coverage**:spec §6 核心改动 → Task 1;spec §8 测试(holdingTWR split 中性/涨、portfolioTWR split、零回归)→ Task 1 纯函数测 + Task 2 集成测。spec §9 风险(split+buy 同日)→ Task 1 `TestUniqueSortedTradeDatesKeepsSplitPlusBuyDay` 覆盖语义。✓
- **Placeholder**:无 TBD/TODO;所有 step 含完整代码 + 确切命令 + expected。✓
- **Type 一致性**:`uniqueSortedTradeDates` 签名不变;`splitPriceRepo.FindBySecurity` 签名匹配 `priceHistoryRepo` 接口(`FindBySecurity(ctx, securityID, from, to) ([]domain.SecurityPriceHistory, error)`,见 [service.go:1467](../../yucai/server/internal/holding/application/service.go#L1467));`domain.TradeTypeSplit` / `domain.SecurityPriceHistory{PriceDate, PriceCents}` 与既有用法一致。✓
- **split 中性 0% / split 最后 场景**:spec §8「split 中性(buy+split,current ¥50)」场景在 Task 1 改动后 cashFlowDays < 2(buy+split,split 排除)→ `holdingTWR` 返 nil,无法断言 0%,故用「buy+split+sell 真实涨 +20%」(`TestHoldingTWRSplitNoPhantomHPR`,断言 TWR>0)验证 split 不产生虚假 HPR。另加 `TestHoldingTWRSplitLastNeutral`(buy+sell+split-最后,current ¥50 市值中性,≥2 cashFlowDays)直接验证 spec §7 数值例 B 的 lastAfterCF(pre 尺度)/ finalValue(post 尺度)市值中性连接 → cumulative 0%(断言 |TWR|<0.01;bug 会显著负)。`splitPriceRepo` 的 preSplit entry 用 `splitDay.AddDate(-1,0,0)`(非 `-1 day`)以覆盖「split 在最后、buy 在前数天」场景下 day0 的 priceAtOrBefore 查询。
