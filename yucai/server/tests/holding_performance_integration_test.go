package tests

import (
	"context"
	"database/sql"
	"math"
	"testing"
	"time"

	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/holding/adapter/driven/repository"
	"github.com/yucai/server/internal/holding/application"
	"github.com/yucai/server/internal/holding/domain"
	holdingent "github.com/yucai/server/internal/holding/ent"
)

const perfEvalDate = "2021-01-01" // 固定评估日(now 注入)

// setupPerformanceHarness wires a real ent-backed holding Service against one
// in-memory sqlite (CNY only — rateRepo intentionally nil). Returns the service,
// the ent client (for seed helpers), price-history + holding repos, and a fresh
// tenant/account. Mirrors setupHoldingDoubleWriteTestDB's shared-sqlite pattern
// but scoped to a single holding schema (perf e2e has no double-write).
func setupPerformanceHarness(t *testing.T) (svc *application.Service, client *holdingent.Client, phRepo domain.PriceHistoryRepository, holdRepo domain.HoldingRepository, tenantID, accountID uuid.UUID) {
	t.Helper()
	db, err := sql.Open("sqlite", "file:hold_perf_"+t.Name()+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	db.SetMaxOpenConns(1)
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}

	drv := entsql.OpenDB("sqlite3", db)
	client = holdingent.NewClient(holdingent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		t.Fatalf("create holding schema: %v", err)
	}
	t.Cleanup(func() { client.Close() })

	secRepo := repository.NewSecurityRepository(client)
	holdRepo = repository.NewHoldingRepository(client)
	tradeRepo := repository.NewTradeRepository(client)
	snapRepo := repository.NewSnapshotRepository(client)
	phRepo = repository.NewPriceHistoryRepository(client)

	svc = application.NewService(secRepo, holdRepo, tradeRepo)
	svc.SetSnapshotRepository(snapRepo)
	svc.SetPriceHistoryRepository(phRepo)
	// rateRepo intentionally nil: all CNY (rateForCode returns 1.0).

	evalTime, err := time.Parse("2006-01-02", perfEvalDate)
	if err != nil {
		t.Fatalf("parse eval date: %v", err)
	}
	svc.SetNow(func() time.Time { return evalTime.UTC() })

	tenantID, accountID = uuid.New(), uuid.New()
	return svc, client, phRepo, holdRepo, tenantID, accountID
}

// day parses a YYYY-MM-DD date to UTC midnight (avoids timezone drift; service
// truncates to UTC day internally).
func day(t *testing.T, s string) time.Time {
	t.Helper()
	d, err := time.Parse("2006-01-02", s)
	if err != nil {
		t.Fatalf("parse day %q: %v", s, err)
	}
	return d.UTC()
}

// seedPriceHistory writes one price point (CAGR firstPrice + range rebuild).
func seedPriceHistory(t *testing.T, phRepo domain.PriceHistoryRepository, securityID uuid.UUID, priceDate time.Time, priceCents int64) {
	t.Helper()
	if err := phRepo.Save(context.Background(), domain.SecurityPriceHistory{
		SecurityID: securityID, PriceDate: priceDate, PriceCents: priceCents,
		CurrencyCode: "CNY", Source: "perf-e2e",
	}); err != nil {
		t.Fatalf("seed price history: %v", err)
	}
}

// approxFloat asserts got ≈ want within 1e-6 (XIRR/TWR/CAGR precision).
func approxFloat(t *testing.T, got *float64, want float64, msg string) {
	t.Helper()
	if got == nil {
		t.Fatalf("%s: nil, want %.9f", msg, want)
	}
	if math.Abs(*got-want) > 1e-6 {
		t.Errorf("%s: got %.9f, want %.9f (Δ %.9f)", msg, *got, want, *got-want)
	}
}

// seedBaselineHolding 建一个 buy 100 @ ¥100 (2020-01-02) + current ¥130 +
// price_history firstPrice=¥100 的基线持仓(S1 fixture 流程提取)。
//
// 返 secID + holding 供 S1/S2 复用。S2 在此基线上叠加 dividend/sell/split 等
// 后续 trade,锁定各场景下 XIRR/TWR/CAGR 的预期行为。
//
// 注:trade date 用 2020-01-02(非 2020-01-01)— 2020 是闰年,2020-01-01 →
// 2021-01-01 = 366 天(actual/365 day-count),会让 XIRR/CAGR 算成 0.299068
// 而非 0.30。2020-01-02 → 2021-01-01 = 整 365 天,XIRR/CAGR = 0.30 精确命中。
func seedBaselineHolding(t *testing.T, ctx context.Context, svc *application.Service,
	phRepo domain.PriceHistoryRepository, holdRepo domain.HoldingRepository,
	tenantID, accountID uuid.UUID) (secID uuid.UUID, holding *domain.Holding) {
	t.Helper()
	// CreateSecurity 返 *SecurityDTO;price 单独 UpdateSecurityPrice(照 TestSecurityCRUD).
	sec, err := svc.CreateSecurity(ctx, application.CreateSecurityRequest{
		Symbol: "600519.SH", Name: "Kweichow Moutai", SecurityType: domain.SecurityTypeStock,
		Exchange: "SSE", CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}
	if err := svc.UpdateSecurityPrice(ctx, sec.ID, 13000); err != nil { // ¥130
		t.Fatalf("UpdateSecurityPrice: %v", err)
	}
	secID = sec.ID

	// buy 100 @ ¥100 (10000 cents) on 2020-01-02 (见上注:闰年避开).
	if _, err := svc.BuyHolding(ctx, application.HoldingTradeRequest{
		TenantID: tenantID, AccountID: accountID, SecurityID: secID,
		Quantity: 100, PriceCents: 10000, TradeDate: day(t, "2020-01-02"),
	}); err != nil {
		t.Fatalf("BuyHolding: %v", err)
	}

	// price_history firstPrice = ¥100 (CAGR full: firstPrice→current).
	seedPriceHistory(t, phRepo, secID, day(t, "2020-01-02"), 10000)

	holding, err = holdRepo.FindByAccountAndSecurity(ctx, tenantID, accountID, secID)
	if err != nil || holding == nil {
		t.Fatalf("find holding: %v", err)
	}
	return secID, holding
}

// TestS1_SingleHolding_Baseline: buy 100 @ ¥100 (2020-01-02) → current ¥130
// (eval 2021-01-01, 365 天). 无 dividend/sell/split.
//
// 锁定单标的计算基线:domain 包单测此前只验方向/非空,本测验证 XIRR/CAGR 在
// 整 365 天、单笔 buy、无中断的简单情形下精确重合(0.30 ±1e-6)。
//
// 注:TWR 在单笔 buy 时按 holdingTWR 实现降级为 nil(len(trades)<2 sentinel)。
// 数学上单笔 buy 的 TWR = (final/initial)^(365/days) - 1 = 0.30(与 XIRR/CAGR
// 重合),但实现需要 ≥2 个现金流日子切分子区间 — 单笔 buy 只有 1 个,降级。
// 此处锁定当前实现行为(nil);数学闭环需 holdingTWR 补单 buy 分支(follow-up)。
func TestS1_SingleHolding_Baseline(t *testing.T) {
	svc, _, phRepo, holdRepo, tenantID, accountID := setupPerformanceHarness(t)
	ctx := context.Background()

	_, holding := seedBaselineHolding(t, ctx, svc, phRepo, holdRepo, tenantID, accountID)

	perf, err := svc.GetHoldingPerformance(ctx, holding.ID, "MONTH", "CNY")
	if err != nil {
		t.Fatalf("GetHoldingPerformance: %v", err)
	}

	// full 期:单笔 buy、无中断、整 365 天 → XIRR=CAGR=0.30 精确命中.
	approxFloat(t, perf.AnnualizedPct, 0.30, "S1 full XIRR")
	approxFloat(t, perf.CagrAnnualizedPct, 0.30, "S1 full CAGR")

	// TWR:当前 holdingTWR 实现对单笔 buy(len(trades)<2)降级为 nil(见上注).
	// 锁定该降级行为;数学上单 buy 的 TWR 应 = 0.30,实现补单 buy 分支后此处
	// 可改 assert 0.30(follow-up,不在 Task 2 范围).
	if perf.TwrAnnualizedPct != nil {
		t.Errorf("S1 full TWR: got %.9f, want nil (single-buy degrade; see test comment)",
			*perf.TwrAnnualizedPct)
	}
}

// TestS2_WithDividend: S1 baseline + dividend ¥500 (2020-07-01).
//
// TWR 中性:dividend 在 QtyAtDate 是 no-op(qty 不变),BV_before==BV_after,
// holdingTWR 子区间 HPR=1 → 链 telescoping 后 cumulative 不变 = 0.30(memory
// split-adjusted 教训:现金流日子 BV 不变,subPeriod return=0,final link
// 仍 finalValue/lastAfterCF = 1.30)。S2 = buy+dividend = 2 trades → 不降级。
//
// XIRR 增益:dividend 是真实现金流入(XIRR cash flow AmountCents=50000 cents),
// 在 buy/terminal 之间多一个正 cash flow → IRR 上凸 > 0.30。理论值
// =XIRR([-10000,500,13000],[2020-01-02,2020-07-01,2021-01-01]) ≈ 0.358。
func TestS2_WithDividend(t *testing.T) {
	svc, _, phRepo, holdRepo, tenantID, accountID := setupPerformanceHarness(t)
	ctx := context.Background()

	// S1 基线(buy 100@¥100 + current ¥130 + firstPrice ¥100).
	secID, holding := seedBaselineHolding(t, ctx, svc, phRepo, holdRepo, tenantID, accountID)

	// + dividend ¥500 (每股 ¥5 × 100) on 2020-07-01.
	if _, err := svc.RecordDividend(ctx, application.RecordDividendRequest{
		TenantID: tenantID, AccountID: accountID, SecurityID: secID,
		Quantity: 100, CashPerShareCents: 500, TotalAmountCents: 50000,
		TradeDate: day(t, "2020-07-01"),
	}); err != nil {
		t.Fatalf("RecordDividend: %v", err)
	}

	perf, err := svc.GetHoldingPerformance(ctx, holding.ID, "MONTH", "CNY")
	if err != nil {
		t.Fatalf("GetHoldingPerformance: %v", err)
	}

	// TWR 中性:dividend 切点 BV_before==BV_after → subPeriod HPR=1 → 链不变.
	// S2 不再降级(buy+dividend = 2 trades ≥ 2),返 0.30(同 S1 cumulative).
	approxFloat(t, perf.TwrAnnualizedPct, 0.30, "S2 TWR (dividend neutral)")

	// XIRR 增益:dividend 真实现金流入 → XIRR > 0.30 (S1 baseline).
	if perf.AnnualizedPct == nil || *perf.AnnualizedPct <= 0.30 {
		t.Errorf("S2 XIRR = %v, want > 0.30 (dividend boost)", perf.AnnualizedPct)
	}
}

// seedMonthlySnapshots writes one snapshot per holding per month across
// 2020-02..2021-01. GetPortfolioPerformance requires snapshotRepo to be set
// (it is, in the harness); snapshots feed the portfolio curve points.
// XIRR/TWR/CAGR do NOT depend on snapshot values — they use trades + price
// history — so the market-value ramp here is arbitrary but reasonable.
func seedMonthlySnapshots(t *testing.T, client *holdingent.Client, tenantID, accountID uuid.UUID, secIDs []uuid.UUID) {
	t.Helper()
	ctx := context.Background()
	holdRepo := repository.NewHoldingRepository(client)
	months := []string{
		"2020-02-01", "2020-03-01", "2020-04-01", "2020-05-01", "2020-06-01",
		"2020-07-01", "2020-08-01", "2020-09-01", "2020-10-01", "2020-11-01",
		"2020-12-01", "2021-01-01",
	}
	for _, secID := range secIDs {
		h, err := holdRepo.FindByAccountAndSecurity(ctx, tenantID, accountID, secID)
		if err != nil || h == nil {
			t.Fatalf("find holding for snapshot (sec=%s): %v", secID, err)
		}
		for i, m := range months {
			// Linear ramp 1.0e6 → 1.55e6 cents across the year — pure curve
			// seed; XIRR/TWR/CAGR ignore these values.
			mv := int64(1_000_000 + i*50_000)
			if _, err := client.HoldingSnapshot.Create().
				SetTenantID(tenantID).SetHoldingID(h.ID).SetSecurityID(secID).SetAccountID(accountID).
				SetSnapshotDate(day(t, m)).SetMarketValueCents(mv).SetUnrealizedPnlCents(0).
				SetCurrencyCode("CNY").Save(ctx); err != nil {
				t.Fatalf("seed snapshot %s (sec=%s): %v", m, secID, err)
			}
		}
	}
}

// TestS3_WithSplit: S2 (buy+dividend) + 2:1 split (2020-10-01).
//
// split 市值中性 → TWR / XIRR 与 S2 byte-identical ±1e-6(memory split-adjusted):
//   - holdingTWR:uniqueSortedTradeDates 排除纯 split 日(split 非现金流,GIPS 市值中性);
//     qty 变化(100→200)经 QtyAtDate replay 在相邻现金流日 BV 自然体现。
//   - holdingXIRR:TradeTypeSplit continue(非现金流);terminal = qty_after × price_after
//     = 200×6500 = 1.3e6 同 S2(100×13000)。
//
// fixture 关键:split 2:1 后 raw price ÷2(10000→5000,市值中性:100×10000=200×5000)。
// current price split-adjusted = 6500(200×6500=1.3e6 同 S2 finalValue 100×13000)。
//
// 注:holdingCAGR 不在断言 —— raw firstPrice=10000 + current=6500 → 负(raw price 不
// split-adjusted 的已知 limitation;memory split-adjusted 只修 TWR,不动 CAGR/price 存储)。
func TestS3_WithSplit(t *testing.T) {
	svc, _, phRepo, holdRepo, tenantID, accountID := setupPerformanceHarness(t)
	ctx := context.Background()

	// S2 baseline(harness 每 test 独立 setup → 在 S3 test 内重算 perfS2)。
	secID, holding := seedBaselineHolding(t, ctx, svc, phRepo, holdRepo, tenantID, accountID)
	if _, err := svc.RecordDividend(ctx, application.RecordDividendRequest{
		TenantID: tenantID, AccountID: accountID, SecurityID: secID,
		Quantity: 100, CashPerShareCents: 500, TotalAmountCents: 50000,
		TradeDate: day(t, "2020-07-01"),
	}); err != nil {
		t.Fatalf("RecordDividend: %v", err)
	}
	perfS2, err := svc.GetHoldingPerformance(ctx, holding.ID, "MONTH", "CNY")
	if err != nil {
		t.Fatalf("GetHoldingPerformance S2: %v", err)
	}
	if perfS2.TwrAnnualizedPct == nil || perfS2.AnnualizedPct == nil {
		t.Fatalf("S2 baseline: TWR/XIRR must be non-nil, got TWR=%v XIRR=%v",
			perfS2.TwrAnnualizedPct, perfS2.AnnualizedPct)
	}

	// + 2:1 split on 2020-10-01 (qty 100→200, avgCost 10000→5000)。
	if _, err := svc.RecordSplit(ctx, application.RecordSplitRequest{
		TenantID: tenantID, AccountID: accountID, SecurityID: secID,
		Ratio: 2.0, SplitDate: day(t, "2020-10-01"),
	}); err != nil {
		t.Fatalf("RecordSplit: %v", err)
	}

	// fixture: split 后 raw price ÷ ratio = 10000/2 = 5000(市值中性:
	// split 前 BV 100×10000=1e6 = split 后 BV 200×5000=1e6)。
	seedPriceHistory(t, phRepo, secID, day(t, "2020-10-02"), 5000)
	// current price split-adjusted:200×6500=1.3e6 同 S2 finalValue(100×13000)。
	if err := svc.UpdateSecurityPrice(ctx, secID, 6500); err != nil { // 13000/2
		t.Fatalf("UpdateSecurityPrice post-split: %v", err)
	}

	// 重新查 holding(split 后 qty=200 / avgCost=5000 已更新)。
	holding2, err := holdRepo.FindByAccountAndSecurity(ctx, tenantID, accountID, secID)
	if err != nil || holding2 == nil {
		t.Fatalf("find holding post-split: %v", err)
	}
	perfS3, err := svc.GetHoldingPerformance(ctx, holding2.ID, "MONTH", "CNY")
	if err != nil {
		t.Fatalf("GetHoldingPerformance S3: %v", err)
	}

	// split 市值中性:TWR / XIRR 与 S2 byte-identical ±1e-6。
	approxFloat(t, perfS3.TwrAnnualizedPct, *perfS2.TwrAnnualizedPct, "S3 TWR (split neutral)")
	approxFloat(t, perfS3.AnnualizedPct, *perfS2.AnnualizedPct, "S3 XIRR (split neutral)")
}

// TestS4_Portfolio_CacheTransparent: portfolio-level GetPortfolioPerformance.
//
// Fixture: 2 holdings (different securities, same account) bought on
// **different days** so the portfolio has 2 distinct cashFlowDays — avoiding
// the single-cashflow-day TWR degrade that would hit if both buys were on the
// same date (the original brief's "same-day buy" fixture would have collapsed
// the merged portfolio cash flow to 1 day → portfolioTWR degrade == nil).
//   - holding 1: buy 100 @ ¥100 (2020-01-02)
//   - holding 2: buy 100 @ ¥100 (2020-06-01)
//   - both current price = ¥130 (eval @ 2021-01-01, 365 days from buy1)
//
// Coverage goal: portfolioXIRR / portfolioTWR / portfolioCAGR had ZERO test
// coverage before S4 (codegraph warning). S4 lifts them from nil→non-nil and
// pins portfolioCAGR + portfolioTWR to hand-computable 0.30:
//
//	portfolioCAGR full = (finalMV/costBasis)^(365/days) - 1
//	                  = (2.6e6/2.0e6)^(365/365) - 1 = 0.30 ✓
//	  (costBasis = 2×100×10000 = 2e6; finalMV = 2×100×13000 = 2.6e6;
//	   earliest = holding1.CreatedAt = 2020-01-02 → eval = 365 days)
//	portfolioTWR full = 0.30  (historical price flat at ¥100 → every sub-period
//	  HPR = 1.0 → telescoping chain = finalMV/lastBV = 2.6e6/2e6 = 1.30,
//	  annualized over 365 days = 0.30)
//	portfolioXIRR full ≈ 0.388 (money-weighted: 2 buys at different dates +
//	  terminal; non-trivial, only assert non-nil + cache transparency)
//
// Cache transparency: mvCache (request-scoped map inside portfolioTWR) is
// rebuilt per GetPortfolioPerformance call — no cross-request state. Two
// back-to-back calls must return byte-identical *float64 (exact equality, not
// ±1e-6) for XIRR / TWR / CAGR. Proves cache is transparent (memoization
// doesn't perturb results) AND request-scoped (doesn't leak between calls).
//
// NOTE on fixture tweak: holdings are pre-created via the ent client with an
// explicit CreatedAt = first-buy date. Production BuyHolding now sets
// Holding.CreatedAt = ent time.Now (fixed via holding_repo SaveOrUpdate Create
// IsZero fallback — see 2026-07-19-holding-createdat-bug-design.md). But
// ent time.Now (persistence time) differs from the SetNow eval date
// (2021-01-01): a holding bought "now" has CreatedAt > eval → earliest >
// eval → portfolioCAGR degrades. Pre-creating with CreatedAt = first-buy
// date simulates a "bought in the past" scenario so earliest < eval and the
// CAGR math exercises end-to-end. Not a production-bug workaround (that is
// fixed); it isolates the CAGR math test from ent-time-vs-eval-date timing.
func TestS4_Portfolio_CacheTransparent(t *testing.T) {
	svc, client, phRepo, _, tenantID, accountID := setupPerformanceHarness(t)
	ctx := context.Background()

	// 2 securities (same exchange/currency for simplicity; both CNY so rateRepo=nil is fine).
	secIDs := make([]uuid.UUID, 2)
	for i, sym := range []string{"600519.SH", "000001.SZ"} {
		sec, err := svc.CreateSecurity(ctx, application.CreateSecurityRequest{
			Symbol: sym, Name: sym, SecurityType: domain.SecurityTypeStock,
			Exchange: "SSE", CurrencyCode: "CNY",
		})
		if err != nil {
			t.Fatalf("CreateSecurity %s: %v", sym, err)
		}
		if err := svc.UpdateSecurityPrice(ctx, sec.ID, 13000); err != nil { // ¥130 current
			t.Fatalf("UpdateSecurityPrice %s: %v", sym, err)
		}
		secIDs[i] = sec.ID
	}

	// Pre-create holdings with explicit CreatedAt = first-buy date (see NOTE above).
	// h1: 2020-01-02 (earliest — drives portfolioCAGR day count = 365).
	// h2: 2020-06-01 (different day → 2 portfolio cashFlowDays → portfolioTWR
	// does NOT degrade like a single-buy portfolio would).
	buyDates := []string{"2020-01-02", "2020-06-01"}
	for i, secID := range secIDs {
		if err := client.Holding.Create().
			SetID(uuid.New()).SetTenantID(tenantID).SetAccountID(accountID).SetSecurityID(secID).
			SetQuantity(0).SetAvgCostCents(0).SetVersion(0).
			SetCreatedAt(day(t, buyDates[i])).SetUpdatedAt(day(t, buyDates[i])).
			Exec(ctx); err != nil {
			t.Fatalf("pre-create holding %d (CreatedAt=%s): %v", i+1, buyDates[i], err)
		}
	}

	// Buy 100 @ ¥100 each on the matching date.
	for i, secID := range secIDs {
		if _, err := svc.BuyHolding(ctx, application.HoldingTradeRequest{
			TenantID: tenantID, AccountID: accountID, SecurityID: secID,
			Quantity: 100, PriceCents: 10000, TradeDate: day(t, buyDates[i]),
		}); err != nil {
			t.Fatalf("BuyHolding %d: %v", i+1, err)
		}
		// Flat first-price ¥100 → portfolioTWR sub-period HPRs = 1.0, so the
		// chain telescopes to finalMV/lastBV = 0.30 annualized. priceAtOrBefore
		// lookups at any later day (e.g. 2020-06-01) fall back to this row.
		seedPriceHistory(t, phRepo, secID, day(t, buyDates[i]), 10000)
	}

	// Seed monthly snapshots (curve points; XIRR/TWR/CAGR don't read them).
	seedMonthlySnapshots(t, client, tenantID, accountID, secIDs)

	// First call.
	perf1, err := svc.GetPortfolioPerformance(ctx, tenantID, &accountID, "MONTH", false, "CNY")
	if err != nil {
		t.Fatalf("GetPortfolioPerformance #1: %v", err)
	}

	// PortfolioCAGR full = 0.30 (hand-computed; earliest=2020-01-02, eval=2021-01-01).
	if perf1.CagrAnnualizedPct == nil {
		t.Fatalf("S4 portfolio CAGR full: nil, want 0.30 (earliest holding CreatedAt not propagated?)")
	}
	approxFloat(t, perf1.CagrAnnualizedPct, 0.30, "S4 portfolio full CAGR")

	// PortfolioTWR full = 0.30 (flat historical price → telescopes to final/last BV).
	if perf1.TwrAnnualizedPct == nil {
		t.Fatalf("S4 portfolio TWR full: nil, want 0.30 (cashFlowDays<2 degrade? expected ≥2 for 2 different-day buys)")
	}
	approxFloat(t, perf1.TwrAnnualizedPct, 0.30, "S4 portfolio full TWR")

	// PortfolioXIRR full: non-trivial money-weighted value (2 buys at different
	// dates + terminal). Assert non-nil — the core "zero-coverage lift".
	if perf1.AnnualizedPct == nil {
		t.Fatalf("S4 portfolio XIRR full: nil, want non-nil (cashflows [-1e6@2020-01-02, -1e6@2020-06-01, +2.6e6@2021-01-01] should solve)")
	}
	// Sanity bounds: XIRR must beat CAGR (0.30) — earlier buy is "underwater"
	// longer so money-weighted return is HIGHER than time-weighted for the same
	// final MV (you held less capital for longer before the 2nd buy).
	if *perf1.AnnualizedPct <= 0.30 {
		t.Errorf("S4 portfolio XIRR full = %.9f, want > 0.30 (2-stage buy → money-weighted > time-weighted)",
			*perf1.AnnualizedPct)
	}

	// Cache transparency: 2nd call must return byte-identical pointers for all
	// three metrics. mvCache is request-scoped (rebuilt per portfolioTWR call),
	// so identical inputs → identical outputs, bit-for-bit. Using exact equality
	// (not ±1e-6) because the inputs are deterministic and the cache must not
	// perturb the result.
	perf2, err := svc.GetPortfolioPerformance(ctx, tenantID, &accountID, "MONTH", false, "CNY")
	if err != nil {
		t.Fatalf("GetPortfolioPerformance #2: %v", err)
	}
	if *perf1.AnnualizedPct != *perf2.AnnualizedPct {
		t.Errorf("cache transparency: XIRR call1=%.9f call2=%.9f (Δ=%.9f)",
			*perf1.AnnualizedPct, *perf2.AnnualizedPct, *perf1.AnnualizedPct-*perf2.AnnualizedPct)
	}
	if *perf1.TwrAnnualizedPct != *perf2.TwrAnnualizedPct {
		t.Errorf("cache transparency: TWR call1=%.9f call2=%.9f (Δ=%.9f)",
			*perf1.TwrAnnualizedPct, *perf2.TwrAnnualizedPct, *perf1.TwrAnnualizedPct-*perf2.TwrAnnualizedPct)
	}
	if *perf1.CagrAnnualizedPct != *perf2.CagrAnnualizedPct {
		t.Errorf("cache transparency: CAGR call1=%.9f call2=%.9f (Δ=%.9f)",
			*perf1.CagrAnnualizedPct, *perf2.CagrAnnualizedPct, *perf1.CagrAnnualizedPct-*perf2.CagrAnnualizedPct)
	}
	t.Logf("S4 portfolio perf: XIRR=%.9f TWR=%.9f CAGR=%.9f (call1==call2 byte-identical ✓)",
		*perf1.AnnualizedPct, *perf1.TwrAnnualizedPct, *perf1.CagrAnnualizedPct)
}
