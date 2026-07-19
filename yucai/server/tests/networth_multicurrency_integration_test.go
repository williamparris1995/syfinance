package tests

import (
	"context"
	"database/sql"
	"testing"
	"time"

	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"

	"github.com/google/uuid"
	accountapp "github.com/yucai/server/internal/account/application"
	accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"
	accountdomain "github.com/yucai/server/internal/account/domain"
	accountent "github.com/yucai/server/internal/account/ent"
	currencyrepo "github.com/yucai/server/internal/currency/adapter/driven/repository"
	currencyent "github.com/yucai/server/internal/currency/ent"
	debtapp "github.com/yucai/server/internal/debt/application"
	debtrepo "github.com/yucai/server/internal/debt/adapter/driven/repository"
	debtdomain "github.com/yucai/server/internal/debt/domain"
	debtent "github.com/yucai/server/internal/debt/ent"
	holdingapp "github.com/yucai/server/internal/holding/application"
	holdingsec "github.com/yucai/server/internal/holding/adapter/driven/repository"
	holdingdomain "github.com/yucai/server/internal/holding/domain"
	holdingent "github.com/yucai/server/internal/holding/ent"
	networthapp "github.com/yucai/server/internal/networth/application"
)

// setupNetWorthHarness wires real ent-backed account + holding + debt + currency
// services against ONE in-memory sqlite (4 ent clients share the driver — networth
// has no ent, pure aggregation). debt.SetAccountLookup is required so non-CNY debt
// resolves its currency from the account. Mirrors setupHoldingDoubleWriteTestDB /
// setupGoalHoldingHarness multi-client pattern.
func setupNetWorthHarness(t *testing.T) (
	networthSvc *networthapp.Service,
	acctSvc *accountapp.Service, holdSvc *holdingapp.Service, debtSvc *debtapp.Service,
	currencyClient *currencyent.Client,
	tenantID uuid.UUID,
) {
	t.Helper()
	db, err := sql.Open("sqlite", "file:net_worth_dw?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	db.SetMaxOpenConns(1)
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}

	drv := entsql.OpenDB("sqlite3", db)
	acctClient := accountent.NewClient(accountent.Driver(drv))
	holdClient := holdingent.NewClient(holdingent.Driver(drv))
	debtClient := debtent.NewClient(debtent.Driver(drv))
	currencyClient = currencyent.NewClient(currencyent.Driver(drv))

	ctx := context.Background()
	if err := acctClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create account schema: %v", err)
	}
	if err := holdClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create holding schema: %v", err)
	}
	if err := debtClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create debt schema: %v", err)
	}
	if err := currencyClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create currency schema: %v", err)
	}
	// t.Cleanup LIFO: clients close before db (correct order — registered
	// after db at the top of the harness, so they run first on teardown).
	t.Cleanup(func() { acctClient.Close() })
	t.Cleanup(func() { holdClient.Close() })
	t.Cleanup(func() { debtClient.Close() })
	t.Cleanup(func() { currencyClient.Close() })

	// account service
	accountRepo := accountrepo.NewAccountRepository(acctClient)
	chartRepo := accountrepo.NewChartRepository(acctClient)
	acctSvc = accountapp.NewService(accountRepo, chartRepo)

	// holding service
	secRepo := holdingsec.NewSecurityRepository(holdClient)
	holdRepo := holdingsec.NewHoldingRepository(holdClient)
	tradeRepo := holdingsec.NewTradeRepository(holdClient)
	holdSvc = holdingapp.NewService(secRepo, holdRepo, tradeRepo)

	// debt service — MUST SetAccountLookup so non-CNY debt resolves currency
	debtRepo := debtrepo.NewDebtRepository(debtClient)
	debtSvc = debtapp.NewService(debtRepo)
	debtSvc.SetAccountLookup(accountRepo)

	// currency rate repo
	rateRepo := currencyrepo.NewRateHistoryRepository(currencyClient)

	// networth aggregation (no ent, pure port consumption)
	networthSvc = networthapp.NewService(acctSvc, holdSvc, debtSvc, rateRepo, nil)

	tenantID = uuid.New()
	return networthSvc, acctSvc, holdSvc, debtSvc, currencyClient, tenantID
}

// seedRate writes a currency rate history row. rateDate MUST be <= time.Now(),
// otherwise RateHistoryRepository.FindRate's forward-fill (RateDateLTE(date))
// misses it and returns the 1.0 fallback — GetNetWorth calls FindRate(code,
// time.Now()) hardcoded, so fixture seeds a past date.
func seedRate(t *testing.T, client *currencyent.Client, code string, rateDate time.Time, rate float64) {
	t.Helper()
	ctx := context.Background()
	if _, err := client.RateHistory.Create().
		SetCurrencyCode(code).SetRateDate(rateDate).SetExchangeRate(rate).
		Save(ctx); err != nil {
		t.Fatalf("seed rate %s: %v", code, err)
	}
}

// TestNetWorth_MultiCurrency drives networth.GetNetWorth with real ent-backed
// account/holding/debt + currency rate history, verifying multi-currency
// aggregation to base CNY.
//
// Fixture: account CNY 10000 (asset) + security USD + holding USD (mv 1000) +
// debt CNY 5000 (borrowed-in, lump-sum → remaining=principal) + rate USD=7
// (past date). Expected: GetNetWorth base CNY assets=17000 (10000+7000) /
// liab=5000 / net=12000.
//
// Cross-module coverage: 4 ent clients (account/holding/debt/currency) share
// one in-memory sqlite driver; networth is pure aggregation (no ent). The debt
// resolves its currency from the parent CNY account via the harness-wired
// SetAccountLookup, exercising the full production code path.
func TestNetWorth_MultiCurrency(t *testing.T) {
	networthSvc, acctSvc, holdSvc, debtSvc, currencyClient, tenantID := setupNetWorthHarness(t)
	ctx := context.Background()

	// Seed CNY savings account (asset) with 10000 cents initial balance.
	cnyAcc, err := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID:            tenantID,
		Name:                "CNY Savings",
		AccountType:         accountdomain.AccountTypeAsset,
		Category:            accountdomain.AccountCategorySavings,
		CurrencyCode:        "CNY",
		InitialBalanceCents: 10000,
	})
	if err != nil {
		t.Fatalf("CreateAccount CNY: %v", err)
	}

	// Seed USD investment account (asset, 0 balance — only used as holding home).
	usdAcc, err := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID:     tenantID,
		Name:         "USD Investment",
		AccountType:  accountdomain.AccountTypeAsset,
		Category:     accountdomain.AccountCategoryInvestment,
		CurrencyCode: "USD",
	})
	if err != nil {
		t.Fatalf("CreateAccount USD: %v", err)
	}

	// Seed security USD + price 10 cents, then buy 100 qty → mv = 100×10 = 1000
	// cents USD. SumMarketValueByCurrency reads sec.CurrencyCode (USD) and the
	// security's CurrentPriceCents (set via UpdateSecurityPrice).
	sec, err := holdSvc.CreateSecurity(ctx, holdingapp.CreateSecurityRequest{
		Symbol:       "AAPL",
		Name:         "Apple",
		SecurityType: holdingdomain.SecurityTypeStock,
		Exchange:     "NASDAQ",
		CurrencyCode: "USD",
	})
	if err != nil {
		t.Fatalf("CreateSecurity USD: %v", err)
	}
	if err := holdSvc.UpdateSecurityPrice(ctx, sec.ID, 10); err != nil {
		t.Fatalf("UpdateSecurityPrice: %v", err)
	}
	if _, err := holdSvc.BuyHolding(ctx, holdingapp.HoldingTradeRequest{
		TenantID:   tenantID,
		AccountID:  usdAcc.ID,
		SecurityID: sec.ID,
		Quantity:   100,
		PriceCents: 10,
		TradeDate:  time.Now(),
	}); err != nil {
		t.Fatalf("BuyHolding USD: %v", err)
	}

	// Seed borrowed-in debt CNY 5000 under the CNY account. Lump-sum amortization
	// emits a single entry at due date; DueDate (2026-12-31) is in the future so
	// the lump-sum entry is unpaid, and RemainingPrincipal equals
	// TotalPrincipalCents = 5000. DebtType=BorrowedIn (money the user owes) →
	// networth classifies under liabilities. The harness wires
	// debt.SetAccountLookup(accountRepo), so SumRemainingByCurrency resolves this
	// debt's currency from cnyAcc.CurrencyCode = "CNY".
	if _, err := debtSvc.CreateDebt(ctx, debtapp.CreateDebtRequest{
		TenantID:            tenantID,
		AccountID:           cnyAcc.ID,
		Counterparty:        "Bank",
		InterestRate:        0,
		AmortizationMethod:  debtdomain.AmortizationLumpSum,
		StartDate:           time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC),
		DueDate:             time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC),
		TotalPrincipalCents: 5000,
		DebtType:            debtdomain.BorrowedIn,
	}); err != nil {
		t.Fatalf("CreateDebt CNY: %v", err)
	}

	// Seed USD→CNY rate 7.0 at a past date (<= time.Now). GetNetWorth calls
	// FindRate("USD", time.Now()); RateHistoryRepository forward-fills to the
	// most recent RateDateLTE(now), so a past-date seed is picked up. Without
	// this row FindRate returns 1.0 and the USD holding stays unconverted.
	// Convention: only one rate row per currency in this test.
	pastDate := time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC)
	seedRate(t, currencyClient, "USD", pastDate, 7.0)

	// Drive aggregation: base = CNY.
	result, err := networthSvc.GetNetWorth(ctx, tenantID, "CNY")
	if err != nil {
		t.Fatalf("GetNetWorth: %v", err)
	}

	// Assets = account CNY 10000 + holding USD (1000 × rate 7.0) = 17000.
	if result.TotalAssetsCents != 17000 {
		t.Errorf("TotalAssetsCents: got %d, want 17000 (account CNY 10000 + holding USD 1000×7)",
			result.TotalAssetsCents)
	}
	// Liabilities = debt CNY 5000.
	if result.TotalLiabilitiesCents != 5000 {
		t.Errorf("TotalLiabilitiesCents: got %d, want 5000 (debt CNY 5000)",
			result.TotalLiabilitiesCents)
	}
	// Net = 17000 − 5000 = 12000.
	if result.NetWorthCents != 12000 {
		t.Errorf("NetWorthCents: got %d, want 12000 (17000 − 5000)",
			result.NetWorthCents)
	}
	if result.Currency != "CNY" {
		t.Errorf("Currency: got %q, want \"CNY\"", result.Currency)
	}
}
