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
	holdingsec "github.com/yucai/server/internal/holding/adapter/driven/repository"
	holdgrpc "github.com/yucai/server/internal/holding/adapter/driving/grpc"
	"github.com/yucai/server/internal/holding/application"
	holdingent "github.com/yucai/server/internal/holding/ent"
	pb "github.com/yucai/server/internal/proto/holding/v1"
	txnbalance "github.com/yucai/server/internal/transaction/adapter/driven/balance"
	txnrepo "github.com/yucai/server/internal/transaction/adapter/driven/repository"
	txnapp "github.com/yucai/server/internal/transaction/application"
	txnent "github.com/yucai/server/internal/transaction/ent"
)

// setupHoldingDoubleWriteTestDB opens a single shared in-memory sqlite and migrates
// three ent schemas (account, transaction, holding) against the same driver so the
// holding handler's double-write can flow through real repos + real BalanceUpdater
// + real transaction service into the same DB the accounts live in.
func setupHoldingDoubleWriteTestDB(t *testing.T) (*accountent.Client, *txnent.Client, *holdingent.Client) {
	t.Helper()
	db, err := sql.Open("sqlite", "file:hold_dw?mode=memory")
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
	holdClient := holdingent.NewClient(holdingent.Driver(drv))

	ctx := context.Background()
	if err := acctClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create account schema: %v", err)
	}
	if err := txnClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create transaction schema: %v", err)
	}
	if err := holdClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create holding schema: %v", err)
	}

	t.Cleanup(func() { acctClient.Close() })
	t.Cleanup(func() { txnClient.Close() })
	t.Cleanup(func() { holdClient.Close() })
	return acctClient, txnClient, holdClient
}

// setupHoldingDoubleWriteHarness wires a real HoldingHandler against real ent-backed
// repos + a real BalanceUpdater, sharing one in-memory sqlite so the double-write is
// observable through real account balance reads (GetAccount). accountRepo is reused as
// the handler's AccountLookup. It also pre-seeds a holding account (zero) and a cash
// from-account (InitialBalanceCents=100000) and returns their IDs.
func setupHoldingDoubleWriteHarness(t *testing.T) (
	h *holdgrpc.HoldingHandler,
	acctSvc accountapp.Service,
	tenantID, fromAccID, holdAccID uuid.UUID,
) {
	t.Helper()
	acctClient, txnClient, holdClient := setupHoldingDoubleWriteTestDB(t)

	accountRepo := accountrepo.NewAccountRepository(acctClient)
	chartRepo := accountrepo.NewChartRepository(acctClient)
	acctSvc = *accountapp.NewService(accountRepo, chartRepo)

	txnRepo := txnrepo.NewTransactionRepository(txnClient, nil)
	balanceUpdater := txnbalance.NewBalanceUpdater(accountRepo)
	txnSvc := txnapp.NewService(txnRepo, accountRepo, balanceUpdater)

	secRepo := holdingsec.NewSecurityRepository(holdClient)
	holdRepo := holdingsec.NewHoldingRepository(holdClient)
	tradeRepo := holdingsec.NewTradeRepository(holdClient)
	holdSvc := application.NewService(secRepo, holdRepo, tradeRepo)

	h = holdgrpc.NewHoldingHandler(holdSvc, txnSvc, accountRepo)
	tenantID = uuid.New()

	ctx := context.Background()
	holdAcc, err := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID:     tenantID,
		Name:         "投资账户",
		AccountType:  accountdomain.AccountTypeAsset,
		Category:     accountdomain.AccountCategoryInvestment,
		CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("create holding account: %v", err)
	}
	holdAccID = holdAcc.ID

	fromAcc, err := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID:            tenantID,
		Name:                "现金",
		AccountType:         accountdomain.AccountTypeAsset,
		Category:            accountdomain.AccountCategorySavings,
		CurrencyCode:        "CNY",
		InitialBalanceCents: 100000,
	})
	if err != nil {
		t.Fatalf("create from account: %v", err)
	}
	fromAccID = fromAcc.ID
	return
}

// TestHoldingBuy_DoubleWrite_EndToEnd drives BuyHolding through the real gRPC handler
// wired to real ent-backed repos + a real BalanceUpdater, then asserts the trade amount
// actually persisted to account balances in the shared in-memory sqlite (black-box: read
// via acctSvc.GetAccount).
//
// Expected (buy double-write):
//   - from_account (cash):  credit amount → asset −amount (100000 → 50000)
//   - holding account:       debit amount → asset +amount (0 → 50000)
func TestHoldingBuy_DoubleWrite_EndToEnd(t *testing.T) {
	h, acctSvc, tenantID, fromAccID, holdAccID := setupHoldingDoubleWriteHarness(t)
	ctx := context.Background()

	sec, err := h.CreateSecurity(ctx, &pb.CreateSecurityRequest{
		Symbol: "600000", Name: "浦发",
		SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK,
		CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}

	// buy 10 × 5000 = 50000 cents.
	const amount int64 = 50000
	tradeCtx := authgrpc.WithTenantID(ctx, tenantID)
	tradeCtx = authgrpc.WithUserID(tradeCtx, uuid.New())
	resp, err := h.BuyHolding(tradeCtx, &pb.HoldingTradeRequest{
		AccountId:    holdAccID.String(),
		SecurityId:   sec.Security.Id,
		FromAccountId: fromAccID.String(),
		Quantity:     10,
		PriceCents:   5000,
		TradeDate:    "2026-06-28",
	})
	if err != nil {
		t.Fatalf("BuyHolding: %v", err)
	}
	if resp == nil || resp.Transaction == nil || resp.Transaction.Id == "" {
		t.Fatal("BuyHolding returned empty trade")
	}

	// Black-box assertion: read balances back through the real account service.
	gotFrom, err := acctSvc.GetAccount(ctx, tenantID, fromAccID)
	if err != nil {
		t.Fatalf("GetAccount from: %v", err)
	}
	if want := int64(100000 - amount); gotFrom.CurrentBalanceCents != want {
		t.Errorf("from balance: got %d, want %d (credit amount persisted)",
			gotFrom.CurrentBalanceCents, want)
	}

	gotHold, err := acctSvc.GetAccount(ctx, tenantID, holdAccID)
	if err != nil {
		t.Fatalf("GetAccount holding: %v", err)
	}
	if gotHold.CurrentBalanceCents != amount {
		t.Errorf("holding balance: got %d, want %d (debit amount persisted)",
			gotHold.CurrentBalanceCents, amount)
	}
}

// TestHoldingBuy_InsufficientBalance_FailFast asserts that when the from_account has
// insufficient balance for a buy, BuyHolding rejects the request BEFORE any trade or
// account change is made (fail-fast): no holding is created and the from balance is
// unchanged.
func TestHoldingBuy_InsufficientBalance_FailFast(t *testing.T) {
	h, acctSvc, tenantID, fromAccID, holdAccID := setupHoldingDoubleWriteHarness(t)
	ctx := context.Background()

	sec, err := h.CreateSecurity(ctx, &pb.CreateSecurityRequest{
		Symbol: "600001", Name: "X",
		SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK,
		CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}

	// from balance = 100000; buy 10 × 20000 = 200000 (insufficient).
	tradeCtx := authgrpc.WithTenantID(ctx, tenantID)
	tradeCtx = authgrpc.WithUserID(tradeCtx, uuid.New())
	_, err = h.BuyHolding(tradeCtx, &pb.HoldingTradeRequest{
		AccountId:    holdAccID.String(),
		SecurityId:   sec.Security.Id,
		FromAccountId: fromAccID.String(),
		Quantity:     10,
		PriceCents:   20000,
		TradeDate:    "2026-06-28",
	})
	if err == nil {
		t.Fatal("expected insufficient balance error, got nil")
	}

	// fail-fast: no holding should have been created.
	list, err := h.ListHoldings(tradeCtx, &pb.ListHoldingsRequest{})
	if err != nil {
		t.Fatalf("ListHoldings: %v", err)
	}
	if len(list.Holdings) != 0 {
		t.Errorf("fail-fast: no holding should be created, got %d", len(list.Holdings))
	}

	// fail-fast: from balance must be unchanged.
	gotFrom, err := acctSvc.GetAccount(ctx, tenantID, fromAccID)
	if err != nil {
		t.Fatalf("GetAccount from: %v", err)
	}
	if gotFrom.CurrentBalanceCents != 100000 {
		t.Errorf("from balance should be unchanged: got %d, want 100000",
			gotFrom.CurrentBalanceCents)
	}
}

// TestHoldingSell_DoubleWrite_EndToEnd drives SellHolding through the real gRPC
// handler wired to real ent-backed repos + BalanceUpdater, then asserts the
// sell amount flows through to account balances (black-box: GetAccount) and
// holding Quantity decrements.
//
// Expected (sell double-write, cash in from + investment out holding):
//   - buy 10 @ 5000 builds holding: from 100000→50000, holding 0→50000, qty 10
//   - sell 5 @ 6000 (amount 30000): from 50000→80000, holding 50000→20000, qty 10→5
func TestHoldingSell_DoubleWrite_EndToEnd(t *testing.T) {
	h, acctSvc, tenantID, fromAccID, holdAccID := setupHoldingDoubleWriteHarness(t)
	ctx := context.Background()

	sec, err := h.CreateSecurity(ctx, &pb.CreateSecurityRequest{
		Symbol: "600002", Name: "Sell Test",
		SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK,
		CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}

	tradeCtx := authgrpc.WithTenantID(ctx, tenantID)
	tradeCtx = authgrpc.WithUserID(tradeCtx, uuid.New())

	// buy 10 qty @ 5000 cents/share → amount 50000 (builds holding).
	if _, err := h.BuyHolding(tradeCtx, &pb.HoldingTradeRequest{
		AccountId:     holdAccID.String(),
		SecurityId:    sec.Security.Id,
		FromAccountId: fromAccID.String(),
		Quantity:      10,
		PriceCents:    5000,
		TradeDate:     "2026-06-28",
	}); err != nil {
		t.Fatalf("BuyHolding (setup): %v", err)
	}

	// sell 5 qty @ 6000 cents/share → amount 5*6000 = 30000.
	const sellAmount int64 = 5 * 6000
	if _, err := h.SellHolding(tradeCtx, &pb.HoldingTradeRequest{
		AccountId:     holdAccID.String(),
		SecurityId:    sec.Security.Id,
		FromAccountId: fromAccID.String(),
		Quantity:      5,
		PriceCents:    6000,
		TradeDate:     "2026-06-29",
	}); err != nil {
		t.Fatalf("SellHolding: %v", err)
	}

	// Black-box: from balance = 50000 (after buy) + 30000 (sell cash in) = 80000.
	gotFrom, err := acctSvc.GetAccount(ctx, tenantID, fromAccID)
	if err != nil {
		t.Fatalf("GetAccount from: %v", err)
	}
	if want := int64(50000 + sellAmount); gotFrom.CurrentBalanceCents != want {
		t.Errorf("from balance: got %d, want %d (sell cash in)", gotFrom.CurrentBalanceCents, want)
	}

	// Black-box: holding balance = 50000 (after buy) - 30000 (investment out) = 20000.
	gotHold, err := acctSvc.GetAccount(ctx, tenantID, holdAccID)
	if err != nil {
		t.Fatalf("GetAccount holding: %v", err)
	}
	if want := int64(50000 - sellAmount); gotHold.CurrentBalanceCents != want {
		t.Errorf("holding balance: got %d, want %d (investment out)", gotHold.CurrentBalanceCents, want)
	}

	// holding.Quantity: 10 → 5.
	list, err := h.ListHoldings(tradeCtx, &pb.ListHoldingsRequest{})
	if err != nil {
		t.Fatalf("ListHoldings: %v", err)
	}
	if len(list.Holdings) != 1 || list.Holdings[0].Quantity != 5 {
		t.Errorf("holding quantity: got len=%d qty=%v, want qty=5", len(list.Holdings), func() []float64 {
			q := make([]float64, len(list.Holdings))
			for i, h := range list.Holdings {
				q[i] = h.Quantity
			}
			return q
		}())
	}
}

// TestHoldingSell_QuantityInsufficient_FailFast asserts that when sell quantity
// exceeds holding position, SellHolding rejects BEFORE any trade or account
// change is made (fail-fast): holding Quantity unchanged and balances unchanged.
// Sell does not check from balance (validateTradeFromAccount isBuy=false); the
// fail comes from service.SellHolding quantity check, before recordTradeTransaction.
func TestHoldingSell_QuantityInsufficient_FailFast(t *testing.T) {
	h, acctSvc, tenantID, fromAccID, holdAccID := setupHoldingDoubleWriteHarness(t)
	ctx := context.Background()

	sec, err := h.CreateSecurity(ctx, &pb.CreateSecurityRequest{
		Symbol: "600003", Name: "Fail Fast",
		SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK,
		CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}

	tradeCtx := authgrpc.WithTenantID(ctx, tenantID)
	tradeCtx = authgrpc.WithUserID(tradeCtx, uuid.New())

	// buy 10 qty @ 5000 → from 100000→50000, holding 0→50000.
	const buyAmount int64 = 10 * 5000
	if _, err := h.BuyHolding(tradeCtx, &pb.HoldingTradeRequest{
		AccountId:     holdAccID.String(),
		SecurityId:    sec.Security.Id,
		FromAccountId: fromAccID.String(),
		Quantity:      10,
		PriceCents:    5000,
		TradeDate:     "2026-06-28",
	}); err != nil {
		t.Fatalf("BuyHolding (setup): %v", err)
	}

	// sell 20 qty > holding 10 → service.SellHolding must fail.
	_, err = h.SellHolding(tradeCtx, &pb.HoldingTradeRequest{
		AccountId:     holdAccID.String(),
		SecurityId:    sec.Security.Id,
		FromAccountId: fromAccID.String(),
		Quantity:      20,
		PriceCents:    6000,
		TradeDate:     "2026-06-29",
	})
	if err == nil {
		t.Fatal("expected quantity-insufficient error, got nil")
	}

	// fail-fast: holding Quantity unchanged (still 10).
	list, err := h.ListHoldings(tradeCtx, &pb.ListHoldingsRequest{})
	if err != nil {
		t.Fatalf("ListHoldings: %v", err)
	}
	if len(list.Holdings) != 1 || list.Holdings[0].Quantity != 10 {
		t.Errorf("fail-fast: holding quantity should be unchanged (10), got len=%d", len(list.Holdings))
	}

	// fail-fast: from balance unchanged (50000 after buy).
	gotFrom, err := acctSvc.GetAccount(ctx, tenantID, fromAccID)
	if err != nil {
		t.Fatalf("GetAccount from: %v", err)
	}
	if gotFrom.CurrentBalanceCents != 100000-buyAmount {
		t.Errorf("from balance should be unchanged: got %d, want %d", gotFrom.CurrentBalanceCents, 100000-buyAmount)
	}

	// fail-fast: holding balance unchanged (50000 after buy).
	gotHold, err := acctSvc.GetAccount(ctx, tenantID, holdAccID)
	if err != nil {
		t.Fatalf("GetAccount holding: %v", err)
	}
	if gotHold.CurrentBalanceCents != buyAmount {
		t.Errorf("holding balance should be unchanged: got %d, want %d", gotHold.CurrentBalanceCents, buyAmount)
	}
}
