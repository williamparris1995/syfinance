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
	goaldomain "github.com/yucai/server/internal/goal/domain"
	"github.com/yucai/server/internal/goal/adapter/driven/repository"
	goalapp "github.com/yucai/server/internal/goal/application"
	goalent "github.com/yucai/server/internal/goal/ent"
	holdingapp "github.com/yucai/server/internal/holding/application"
	holdingsec "github.com/yucai/server/internal/holding/adapter/driven/repository"
	holdingdomain "github.com/yucai/server/internal/holding/domain"
	holdingent "github.com/yucai/server/internal/holding/ent"
)

// setupGoalHoldingHarness wires real ent-backed account + holding + goal services
// against ONE in-memory sqlite (3 ent clients share the same driver so cross-module
// data is visible — mirrors setupHoldingDoubleWriteTestDB). goalSvc consumes
// holding's GetAccountsMarketValue via structural AccountMarketValueSource port.
func setupGoalHoldingHarness(t *testing.T) (
	goalSvc *goalapp.Service, goalRepo *repository.GoalRepository,
	holdSvc *holdingapp.Service, acctSvc *accountapp.Service,
	tenantID uuid.UUID,
) {
	t.Helper()
	db, err := sql.Open("sqlite", "file:goal_hold_dw?mode=memory")
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
	goalClient := goalent.NewClient(goalent.Driver(drv))

	ctx := context.Background()
	if err := acctClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create account schema: %v", err)
	}
	if err := holdClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create holding schema: %v", err)
	}
	if err := goalClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create goal schema: %v", err)
	}
	t.Cleanup(func() { acctClient.Close() })
	t.Cleanup(func() { holdClient.Close() })
	t.Cleanup(func() { goalClient.Close() })

	// account service
	accountRepo := accountrepo.NewAccountRepository(acctClient)
	chartRepo := accountrepo.NewChartRepository(acctClient)
	acctSvc = accountapp.NewService(accountRepo, chartRepo)

	// holding service
	secRepo := holdingsec.NewSecurityRepository(holdClient)
	holdRepo := holdingsec.NewHoldingRepository(holdClient)
	tradeRepo := holdingsec.NewTradeRepository(holdClient)
	holdSvc = holdingapp.NewService(secRepo, holdRepo, tradeRepo)

	// goal service — inject holding as AccountMarketValueSource (structural)
	goalRepo = repository.NewGoalRepository(goalClient)
	goalSvc = goalapp.NewService(goalRepo)
	goalSvc.SetAccountMarketValueSource(holdSvc)

	tenantID = uuid.New()
	return goalSvc, goalRepo, holdSvc, acctSvc, tenantID
}

// TestGoalScheduler_HoldingBackedCurrentAmount drives goalSvc.SyncAllGoals for an
// Investment goal linked to a real holding account, then verifies the scheduler
// pulled Σ holdings market value via the holding AccountMarketValueSource port
// and wrote it to goal.CurrentAmountCents.
//
// MV source = sec.CurrentPriceCents (NOT priceHistoryRepo); mv 原币不折算.
// Expected: 100 qty × 13000 cents = 1,300,000 cents.
func TestGoalScheduler_HoldingBackedCurrentAmount(t *testing.T) {
	goalSvc, goalRepo, holdSvc, acctSvc, tenantID := setupGoalHoldingHarness(t)
	ctx := context.Background()

	// seed investment account.
	acc, err := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID:     tenantID,
		Name:         "投资账户",
		AccountType:  accountdomain.AccountTypeAsset,
		Category:     accountdomain.AccountCategoryInvestment,
		CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateAccount: %v", err)
	}
	accountID := acc.ID

	// seed security + current price 13000.
	sec, err := holdSvc.CreateSecurity(ctx, holdingapp.CreateSecurityRequest{
		Symbol:       "600519",
		Name:         "Moutai",
		SecurityType: holdingdomain.SecurityTypeStock,
		Exchange:     "SSE",
		CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}
	if err := holdSvc.UpdateSecurityPrice(ctx, sec.ID, 13000); err != nil {
		t.Fatalf("UpdateSecurityPrice: %v", err)
	}

	// seed holding 100 qty under the investment account.
	if _, err := holdSvc.BuyHolding(ctx, holdingapp.HoldingTradeRequest{
		TenantID:   tenantID,
		AccountID:  accountID,
		SecurityID: sec.ID,
		Quantity:   100,
		PriceCents: 10000,
		TradeDate:  time.Now(),
	}); err != nil {
		t.Fatalf("BuyHolding: %v", err)
	}

	// seed Investment goal linked to the real accountID (NOT random uuid.New).
	goal, err := goaldomain.NewGoal(tenantID, "投资目标", goaldomain.GoalTypeInvestment,
		2000000 /*target*/, "CNY", nil /*deadline*/, []uuid.UUID{accountID}, nil /*debts*/, "" /*notes*/)
	if err != nil {
		t.Fatalf("NewGoal: %v", err)
	}
	if err := goalRepo.Save(ctx, goal); err != nil {
		t.Fatalf("goalRepo.Save: %v", err)
	}

	// SyncAllGoals: scheduler core (single tenant). computeGoalProgress →
	// mvSrc.GetAccountsMarketValue([accountID]) = Σ holdings mv = 100×13000.
	count, err := goalSvc.SyncAllGoals(ctx, tenantID)
	if err != nil {
		t.Fatalf("SyncAllGoals: %v", err)
	}
	if count < 1 {
		t.Errorf("SyncAllGoals count=%d, want >= 1", count)
	}

	// Verify goal.CurrentAmountCents = 100 × 13000 = 1,300,000.
	got, err := goalRepo.FindAll(ctx, tenantID, nil, nil, goaldomain.PageRequest{PageSize: 10})
	if err != nil || len(got.Items) == 0 {
		t.Fatalf("goalRepo.FindAll: err=%v len=%d", err, len(got.Items))
	}
	if got.Items[0].CurrentAmountCents != 1300000 {
		t.Errorf("goal.CurrentAmountCents: got %d, want 1300000 (100×13000)",
			got.Items[0].CurrentAmountCents)
	}
}
