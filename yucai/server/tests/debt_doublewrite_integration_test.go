package tests

import (
	"context"
	"database/sql"
	"testing"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"

	"github.com/google/uuid"
	accountdomain "github.com/yucai/server/internal/account/domain"
	accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"
	accountapp "github.com/yucai/server/internal/account/application"
	accountent "github.com/yucai/server/internal/account/ent"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	debtrepo "github.com/yucai/server/internal/debt/adapter/driven/repository"
	grpcdebt "github.com/yucai/server/internal/debt/adapter/driving/grpc"
	"github.com/yucai/server/internal/debt/application"
	debtent "github.com/yucai/server/internal/debt/ent"
	pb "github.com/yucai/server/internal/proto/debt/v1"
	txnbalance "github.com/yucai/server/internal/transaction/adapter/driven/balance"
	txnrepo "github.com/yucai/server/internal/transaction/adapter/driven/repository"
	txnapp "github.com/yucai/server/internal/transaction/application"
	txnent "github.com/yucai/server/internal/transaction/ent"
)

// setupDebtDoubleWriteTestDB opens a single shared in-memory sqlite and migrates
// three ent schemas (account, transaction, debt) against the same driver so the
// debt handler's double-write can flow through real repos + real BalanceUpdater
// + real transaction service into the same DB the accounts live in.
func setupDebtDoubleWriteTestDB(t *testing.T) (*accountent.Client, *txnent.Client, *debtent.Client) {
	t.Helper()
	db, err := sql.Open("sqlite", "file:debt_dw?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}

	drv := entsql.OpenDB(dialect.SQLite, db)

	acctClient := accountent.NewClient(accountent.Driver(drv))
	txnClient := txnent.NewClient(txnent.Driver(drv))
	debtClient := debtent.NewClient(debtent.Driver(drv))

	ctx := context.Background()
	if err := acctClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create account schema: %v", err)
	}
	if err := txnClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create transaction schema: %v", err)
	}
	if err := debtClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create debt schema: %v", err)
	}

	t.Cleanup(func() { acctClient.Close() })
	t.Cleanup(func() { txnClient.Close() })
	t.Cleanup(func() { debtClient.Close() })
	return acctClient, txnClient, debtClient
}

// setupDebtDoubleWriteHarness wires a real DebtHandler against real ent-backed
// repos + a real BalanceUpdater, sharing one in-memory sqlite so the double-write
// is observable through real account balance reads (GetAccount). accountRepo is
// reused as the handler's AccountLookup.
func setupDebtDoubleWriteHarness(t *testing.T) (
	h *grpcdebt.DebtHandler,
	acctSvc accountapp.Service,
	tenantID uuid.UUID,
) {
	t.Helper()
	acctClient, txnClient, debtClient := setupDebtDoubleWriteTestDB(t)

	accountRepo := accountrepo.NewAccountRepository(acctClient)
	chartRepo := accountrepo.NewChartRepository(acctClient)
	acctSvc = *accountapp.NewService(accountRepo, chartRepo)

	txnRepo := txnrepo.NewTransactionRepository(txnClient, nil)
	balanceUpdater := txnbalance.NewBalanceUpdater(accountRepo)
	txnSvc := txnapp.NewService(txnRepo, accountRepo, balanceUpdater, nil)

	debtRepo := debtrepo.NewDebtRepository(debtClient)
	debtSvc := application.NewService(debtRepo)

	h = grpcdebt.NewDebtHandler(debtSvc, txnSvc, accountRepo)
	tenantID = uuid.New()
	return
}

// TestCreateDebt_DoubleWrite_EndToEnd drives CreateDebt on a borrowedOut debt
// through the real gRPC handler wired to real ent-backed repos + a real
// BalanceUpdater, then asserts the lent principal actually persisted to account
// balances in the shared in-memory sqlite (black-box: read via acctSvc.GetAccount).
//
// Expected (borrowedOut double-write):
//   - receivable account (req.AccountId): debit principal → asset +principal (0 → 50000)
//   - source account (req.SourceAccountId): credit principal → asset -principal (100000 → 50000)
func TestCreateDebt_DoubleWrite_EndToEnd(t *testing.T) {
	h, acctSvc, tenantID := setupDebtDoubleWriteHarness(t)
	ctx := context.Background()

	// Seed source (cash) account with ample initial balance (1000.00 = 100000 cents).
	source, err := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID:            tenantID,
		Name:                "Cash",
		AccountType:         accountdomain.AccountTypeAsset,
		Category:            accountdomain.AccountCategorySavings,
		CurrencyCode:        "CNY",
		InitialBalanceCents: 100000,
	})
	if err != nil {
		t.Fatalf("create source account: %v", err)
	}

	// Seed receivable account at zero.
	receivable, err := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID:     tenantID,
		Name:         "Receivable",
		AccountType:  accountdomain.AccountTypeAsset,
		Category:     accountdomain.AccountCategoryOtherAsset,
		CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("create receivable account: %v", err)
	}

	// Drive CreateDebt through the real handler with a tenant-bearing context.
	debtCtx := authgrpc.WithTenantID(ctx, tenantID)
	debtCtx = authgrpc.WithUserID(debtCtx, uuid.New())
	const principal int64 = 50000
	resp, err := h.CreateDebt(debtCtx, &pb.CreateDebtRequest{
		AccountId:           receivable.ID.String(),
		SourceAccountId:     source.ID.String(),
		Counterparty:        "张三",
		InterestRate:        5.0,
		AmortizationMethod:  pb.AmortizationMethod_AMORTIZATION_LUMP_SUM,
		StartDate:           "2026-01-01",
		DueDate:             "2026-12-31",
		TotalPrincipalCents: principal,
		DebtType:            pb.DebtType_DEBT_TYPE_BORROWED_OUT,
	})
	if err != nil {
		t.Fatalf("CreateDebt: %v", err)
	}
	if resp == nil || resp.Debt == nil || resp.Debt.Id == "" {
		t.Fatal("CreateDebt returned empty debt")
	}

	// Black-box assertion: read balances back through the real account service.
	gotReceivable, err := acctSvc.GetAccount(ctx, tenantID, receivable.ID)
	if err != nil {
		t.Fatalf("GetAccount receivable: %v", err)
	}
	if gotReceivable.CurrentBalanceCents != principal {
		t.Errorf("receivable balance: got %d, want %d (debit principal persisted)",
			gotReceivable.CurrentBalanceCents, principal)
	}

	gotSource, err := acctSvc.GetAccount(ctx, tenantID, source.ID)
	if err != nil {
		t.Fatalf("GetAccount source: %v", err)
	}
	wantSource := int64(100000 - principal)
	if gotSource.CurrentBalanceCents != wantSource {
		t.Errorf("source balance: got %d, want %d (credit principal persisted)",
			gotSource.CurrentBalanceCents, wantSource)
	}
}
