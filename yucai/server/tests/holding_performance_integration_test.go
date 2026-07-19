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

// TestS1_SingleHolding_Baseline: buy 100 @ ¥100 (2020-01-02) → current ¥130
// (eval 2021-01-01, 365 天). 无 dividend/sell/split.
//
// 锁定单标的计算基线:domain 包单测此前只验方向/非空,本测验证 XIRR/CAGR 在
// 整 365 天、单笔 buy、无中断的简单情形下精确重合(0.30 ±1e-6)。
//
// 注 1:trade date 用 2020-01-02(非 2020-01-01)— 2020 是闰年,2020-01-01 →
// 2021-01-01 实际是 366 天(actual/365 day-count),会让 XIRR/CAGR 算成 0.299068
// 而非 0.30。2020-01-02 → 2021-01-01 = 整 365 天,XIRR/CAGR = 0.30 精确命中。
//
// 注 2:TWR 在单笔 buy 时按 holdingTWR 实现降级为 nil(len(trades)<2 sentinel)。
// 数学上单笔 buy 的 TWR = (final/initial)^(365/days) - 1 = 0.30(与 XIRR/CAGR
// 重合),但实现需要 ≥2 个现金流日子切分子区间 — 单笔 buy 只有 1 个,降级。
// 此处锁定当前实现行为(nil);数学闭环需 holdingTWR 补单 buy 分支(follow-up)。
func TestS1_SingleHolding_Baseline(t *testing.T) {
	svc, _, phRepo, holdRepo, tenantID, accountID := setupPerformanceHarness(t)
	ctx := context.Background()

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
	secID := sec.ID

	// buy 100 @ ¥100 (10000 cents) on 2020-01-02 (见上注 1:闰年避开).
	trade, err := svc.BuyHolding(ctx, application.HoldingTradeRequest{
		TenantID: tenantID, AccountID: accountID, SecurityID: secID,
		Quantity: 100, PriceCents: 10000, TradeDate: day(t, "2020-01-02"),
	})
	if err != nil {
		t.Fatalf("BuyHolding: %v", err)
	}
	_ = trade

	// price_history firstPrice = ¥100 (CAGR full: firstPrice→current).
	seedPriceHistory(t, phRepo, secID, day(t, "2020-01-02"), 10000)

	holding, err := holdRepo.FindByAccountAndSecurity(ctx, tenantID, accountID, secID)
	if err != nil || holding == nil {
		t.Fatalf("find holding: %v", err)
	}
	perf, err := svc.GetHoldingPerformance(ctx, holding.ID, "MONTH", "CNY")
	if err != nil {
		t.Fatalf("GetHoldingPerformance: %v", err)
	}

	// full 期:单笔 buy、无中断、整 365 天 → XIRR=CAGR=0.30 精确命中.
	approxFloat(t, perf.AnnualizedPct, 0.30, "S1 full XIRR")
	approxFloat(t, perf.CagrAnnualizedPct, 0.30, "S1 full CAGR")

	// TWR:当前 holdingTWR 实现对单笔 buy(len(trades)<2)降级为 nil(见注 2).
	// 锁定该降级行为;数学上单 buy 的 TWR 应 = 0.30,实现补单 buy 分支后此处
	// 可改 assert 0.30(follow-up,不在 Task 2 范围).
	if perf.TwrAnnualizedPct != nil {
		t.Errorf("S1 full TWR: got %.9f, want nil (single-buy degrade; see test comment)",
			*perf.TwrAnnualizedPct)
	}
}
