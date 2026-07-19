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
	debtapp "github.com/yucai/server/internal/debt/application"
	debtrepo "github.com/yucai/server/internal/debt/adapter/driven/repository"
	debtdomain "github.com/yucai/server/internal/debt/domain"
	debtent "github.com/yucai/server/internal/debt/ent"
	goaldomain "github.com/yucai/server/internal/goal/domain"
	"github.com/yucai/server/internal/goal/adapter/driven/repository"
	goalapp "github.com/yucai/server/internal/goal/application"
	goalent "github.com/yucai/server/internal/goal/ent"
	holdingapp "github.com/yucai/server/internal/holding/application"
	holdingsec "github.com/yucai/server/internal/holding/adapter/driven/repository"
	holdingdomain "github.com/yucai/server/internal/holding/domain"
	holdingent "github.com/yucai/server/internal/holding/ent"
)

// setupGoalHoldingHarness wires real ent-backed account + holding + debt + goal
// services against ONE in-memory sqlite (4 ent clients share the same driver so
// cross-module data is visible — mirrors setupHoldingDoubleWriteTestDB). goalSvc
// consumes holding's GetAccountsMarketValue via structural AccountMarketValueSource
// port, account's GetAccountsBalance via AccountBalanceSource (Savings goals), and
// debt's progress via DebtProgressSource (DebtPayoff goals).
func setupGoalHoldingHarness(t *testing.T) (
	goalSvc *goalapp.Service, goalRepo *repository.GoalRepository,
	holdSvc *holdingapp.Service, acctSvc *accountapp.Service,
	debtSvc *debtapp.Service, tenantID uuid.UUID,
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
	debtClient := debtent.NewClient(debtent.Driver(drv))
	goalClient := goalent.NewClient(goalent.Driver(drv))

	ctx := context.Background()
	if err := acctClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create account schema: %v", err)
	}
	if err := holdClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create holding schema: %v", err)
	}
	// debt schema before goal: goal_debt_links has no DB-level FK to debt rows
	// (application-level reference / logical join table only), but we still
	// create debt first for semantic ordering.
	if err := debtClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create debt schema: %v", err)
	}
	if err := goalClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create goal schema: %v", err)
	}
	t.Cleanup(func() { acctClient.Close() })
	t.Cleanup(func() { holdClient.Close() })
	t.Cleanup(func() { debtClient.Close() })
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

	// debt service
	debtRepo := debtrepo.NewDebtRepository(debtClient)
	debtSvc = debtapp.NewService(debtRepo)

	// goal service — inject holding/account/debt as structural ports:
	//   - AccountMarketValueSource (Investment goals)
	//   - AccountBalanceSource (Savings goals)
	//   - DebtProgressSource (DebtPayoff goals)
	goalRepo = repository.NewGoalRepository(goalClient)
	goalSvc = goalapp.NewService(goalRepo)
	goalSvc.SetAccountMarketValueSource(holdSvc)
	goalSvc.SetAccountBalanceSource(acctSvc)
	goalSvc.SetDebtProgressSource(debtSvc)

	tenantID = uuid.New()
	return goalSvc, goalRepo, holdSvc, acctSvc, debtSvc, tenantID
}

// TestGoalScheduler_HoldingBackedCurrentAmount drives goalSvc.SyncAllGoals for an
// Investment goal linked to a real holding account, then verifies the scheduler
// pulled Σ holdings market value via the holding AccountMarketValueSource port
// and wrote it to goal.CurrentAmountCents.
//
// MV source = sec.CurrentPriceCents (NOT priceHistoryRepo); mv 原币不折算.
// Expected: 100 qty × 13000 cents = 1,300,000 cents.
func TestGoalScheduler_HoldingBackedCurrentAmount(t *testing.T) {
	goalSvc, goalRepo, holdSvc, acctSvc, _, tenantID := setupGoalHoldingHarness(t)
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
	if count != 1 {
		t.Errorf("SyncAllGoals count=%d, want == 1 (single investment goal per tenant)", count)
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

// TestGoalScheduler_SavingsBackedCurrentAmount verifies Savings goal progress
// = Σ linked account CurrentBalanceCents (via balSrc.GetAccountsBalance).
// Fixture: savings account(InitialBalance 800000) + savings goal(target 1000000)
// → current = 800000.
func TestGoalScheduler_SavingsBackedCurrentAmount(t *testing.T) {
	goalSvc, goalRepo, _, acctSvc, _, tenantID := setupGoalHoldingHarness(t)
	ctx := context.Background()

	// seed savings account (InitialBalance 800000 = 8000 元).
	acc, err := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID:             tenantID,
		Name:                 "储蓄账户",
		AccountType:          accountdomain.AccountTypeAsset,
		Category:             accountdomain.AccountCategorySavings,
		CurrencyCode:         "CNY",
		InitialBalanceCents:  800000,
	})
	if err != nil {
		t.Fatalf("CreateAccount savings: %v", err)
	}

	// seed Savings goal (linked to savings account, target 1000000).
	goal, err := goaldomain.NewGoal(tenantID, "储蓄目标", goaldomain.GoalTypeSavings,
		1000000, "CNY", nil, []uuid.UUID{acc.ID}, nil, "")
	if err != nil {
		t.Fatalf("NewGoal savings: %v", err)
	}
	if err := goalRepo.Save(ctx, goal); err != nil {
		t.Fatalf("goalRepo.Save: %v", err)
	}

	// SyncAllGoals: computeGoalProgress(Savings) → balSrc.GetAccountsBalance([acc.ID]) = 800000.
	count, err := goalSvc.SyncAllGoals(ctx, tenantID)
	if err != nil {
		t.Fatalf("SyncAllGoals: %v", err)
	}
	if count != 1 {
		t.Errorf("SyncAllGoals count=%d, want == 1 (single savings goal per tenant)", count)
	}

	// Verify goal.CurrentAmountCents = 800000.
	got, err := goalRepo.FindAll(ctx, tenantID, nil, nil, goaldomain.PageRequest{PageSize: 10})
	if err != nil || len(got.Items) == 0 {
		t.Fatalf("goalRepo.FindAll: err=%v len=%d", err, len(got.Items))
	}
	if got.Items[0].CurrentAmountCents != 800000 {
		t.Errorf("savings goal CurrentAmountCents: got %d, want 800000 (account balance)", got.Items[0].CurrentAmountCents)
	}
}

// TestGoalScheduler_DebtPayoffBackedCurrentAmount verifies DebtPayoff goal progress
// = Σ (TotalPrincipal − RemainingPrincipal) of linked debts (via debtSrc.GetDebtsPaid).
// Fixture: debt(total 600000, EqualPrincipal 3-month term → 月 principal 200000) +
// mark Schedule[0] paid → paid=200000, remaining=400000 + debt payoff goal
// (target 600000) → current = 200000.
func TestGoalScheduler_DebtPayoffBackedCurrentAmount(t *testing.T) {
	goalSvc, goalRepo, _, _, debtSvc, tenantID := setupGoalHoldingHarness(t)
	ctx := context.Background()

	// seed debt: total 600000, EqualPrincipal, 3-month term → 月 principal 200000.
	// AccountID is any uuid — GetDebtsPaid reads only TotalPrincipal/Remaining,
	// never the account. BorrowedOut would require a CollectionAccountID; BorrowedIn doesn't.
	debtDTO, err := debtSvc.CreateDebt(ctx, debtapp.CreateDebtRequest{
		TenantID:            tenantID,
		AccountID:           uuid.New(),
		Counterparty:        "测试负债",
		InterestRate:        0.05,
		AmortizationMethod:  debtdomain.AmortizationEqualPrincipal,
		StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		DueDate:             time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC), // 3-month term
		TotalPrincipalCents: 600000,
		DebtType:            debtdomain.BorrowedIn,
	})
	if err != nil {
		t.Fatalf("CreateDebt: %v", err)
	}
	debtID := debtDTO.ID

	// mark Schedule[0] paid → principal paid=200000, remaining=600000-200000=400000.
	// RecordPayment is the canonical pattern (照 debt_integration_test): application
	// layer just flips Paid + sets PaidCents + repo.Update — FromAccountID is read
	// only by the gRPC handler (transaction double-write), unused here.
	detail, err := debtSvc.GetDebt(ctx, tenantID, debtID)
	if err != nil {
		t.Fatalf("GetDebt: %v", err)
	}
	if _, err := debtSvc.RecordPayment(ctx, debtapp.RecordPaymentRequest{
		TenantID:        tenantID,
		DebtID:          debtID,
		ScheduleEntryID: detail.Schedule[0].ID,
		FromAccountID:   uuid.New(),
	}); err != nil {
		t.Fatalf("RecordPayment: %v", err)
	}

	// seed DebtPayoff goal (linked to debt, target 600000 > paid 200000 避 auto-complete).
	goal, err := goaldomain.NewGoal(tenantID, "还款目标", goaldomain.GoalTypeDebtPayoff,
		600000, "CNY", nil, nil, []uuid.UUID{debtID}, "")
	if err != nil {
		t.Fatalf("NewGoal debtpayoff: %v", err)
	}
	if err := goalRepo.Save(ctx, goal); err != nil {
		t.Fatalf("goalRepo.Save: %v", err)
	}

	// SyncAllGoals: computeGoalProgress(DebtPayoff) → debtSrc.GetDebtsPaid([debtID])
	// = TotalPrincipal − RemainingPrincipal = 600000 − 400000 = 200000.
	count, err := goalSvc.SyncAllGoals(ctx, tenantID)
	if err != nil {
		t.Fatalf("SyncAllGoals: %v", err)
	}
	if count != 1 {
		t.Errorf("SyncAllGoals count=%d, want == 1 (single debtpayoff goal per tenant)", count)
	}

	// Verify goal.CurrentAmountCents = 200000.
	got, err := goalRepo.FindAll(ctx, tenantID, nil, nil, goaldomain.PageRequest{PageSize: 10})
	if err != nil || len(got.Items) == 0 {
		t.Fatalf("goalRepo.FindAll: err=%v len=%d", err, len(got.Items))
	}
	if got.Items[0].CurrentAmountCents != 200000 {
		t.Errorf("debtpayoff goal CurrentAmountCents: got %d, want 200000 (600000 total − 400000 remaining)",
			got.Items[0].CurrentAmountCents)
	}
}
