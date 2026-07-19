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
