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
	currencyrepo "github.com/yucai/server/internal/currency/adapter/driven/repository"
	currencyent "github.com/yucai/server/internal/currency/ent"
	debtapp "github.com/yucai/server/internal/debt/application"
	debtrepo "github.com/yucai/server/internal/debt/adapter/driven/repository"
	debtent "github.com/yucai/server/internal/debt/ent"
	holdingapp "github.com/yucai/server/internal/holding/application"
	holdingsec "github.com/yucai/server/internal/holding/adapter/driven/repository"
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
