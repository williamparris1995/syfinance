package tests

import (
	"context"
	"database/sql"
	"testing"

	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"

	"github.com/google/uuid"
	accountapp "github.com/yucai/server/internal/account/application"
	accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"
	accountent "github.com/yucai/server/internal/account/ent"
	"github.com/yucai/server/internal/goal/adapter/driven/repository"
	goalapp "github.com/yucai/server/internal/goal/application"
	goalent "github.com/yucai/server/internal/goal/ent"
	holdingapp "github.com/yucai/server/internal/holding/application"
	holdingsec "github.com/yucai/server/internal/holding/adapter/driven/repository"
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
