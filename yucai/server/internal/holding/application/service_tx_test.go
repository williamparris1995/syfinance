package application

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"testing"
	"time"

	entsql "entgo.io/ent/dialect/sql"
	"github.com/google/uuid"
	_ "modernc.org/sqlite"

	holdingsec "github.com/yucai/server/internal/holding/adapter/driven/repository"
	"github.com/yucai/server/internal/holding/domain"
	holdingent "github.com/yucai/server/internal/holding/ent"
)

// txTestDialect is the ent dialect string for SQLite
// (== entgo.io/ent/dialect.SQLite). Forwarded to the service's WithTx call so
// ent's mutation builders emit "?" placeholders instead of PostgreSQL's "$1".
const txTestDialect = "sqlite3"

// setupHoldingTxTestDB opens ONE shared in-memory SQLite database, runs the
// holding ent auto-migration against it, and returns the underlying *sql.DB
// plus a ready holding ent client. The shared *sql.DB is what the service's
// WithTx opens its transaction on (mirrors Task 1's provideDB + Task 4's
// setupTxTestDB pattern in transaction/application).
//
// SetMaxOpenConns(1) is mandatory for shared in-memory SQLite — it pins the
// pool to a single physical connection so the *sql.Tx grabbed by WithTx and
// the subsequent read-through-default-client hit the same database.
func setupHoldingTxTestDB(t *testing.T) (*sql.DB, *holdingent.Client) {
	t.Helper()
	dbName := "holding_app_shared_" + strings.ReplaceAll(t.Name(), "/", "_")
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })

	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}
	db.SetMaxOpenConns(1)

	drv := entsql.OpenDB(txTestDialect, db)
	client := holdingent.NewClient(holdingent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate holding schema: %v", err)
	}
	t.Cleanup(func() { _ = client.Close() })
	return db, client
}

// failingLotRepo wraps a real LotRepository, delegating FindByHolding to the
// inner repo so BuyHolding's avg-cost calculation proceeds normally, but
// returning failSave from SaveAll — simulating a mid-flow persistence failure
// AFTER holdingRepo.SaveOrUpdate + tradeRepo.Save have succeeded. Mirrors the
// failingUpdateAccountRepo mid-flow failure injection pattern from Task 4's
// service_tx_test.go.
type failingLotRepo struct {
	domain.LotRepository
	failSave error
}

func (r *failingLotRepo) SaveAll(_ context.Context, _ []domain.HoldingLot) error {
	return r.failSave
}

// TestBuyHolding_RollbackOnLotSaveFailure is the headline transactional
// guarantee for Task 5 (audit D2): when the lot save fails AFTER the holding +
// trade writes have succeeded, the entire operation must roll back — leaving
// zero holding rows and zero trade rows in the database. Pre-Task-5 (no
// sqltx.WithTx wrapping of BuyHolding, repos writing through their default
// auto-commit clients), the holding + trade persist and the assertion fails;
// post-Task-5 the WithTx wrapper rolls them back with the failed lot save.
//
// The failingLotRepo is wired in place of the real lot repo so the holding +
// trade paths still go through their real ent clients (the systems under test
// for the rollback assertion). Security/security is seeded via NewService +
// SetLotRepository, mirroring production wire.
func TestBuyHolding_RollbackOnLotSaveFailure(t *testing.T) {
	db, client := setupHoldingTxTestDB(t)

	tenantID, accountID, securityID := uuid.New(), uuid.New(), uuid.New()
	ctx := context.Background()

	holdRepo := holdingsec.NewHoldingRepository(client)
	tradeRepo := holdingsec.NewTradeRepository(client)
	realLotRepo := holdingsec.NewLotRepository(client)

	svc := NewService(nil /*securityRepo unused on buy path*/, holdRepo, tradeRepo)
	svc.SetLotRepository(&failingLotRepo{LotRepository: realLotRepo, failSave: errors.New("simulated lot save failure")})
	svc.SetDB(db)

	_, err := svc.BuyHolding(ctx, HoldingTradeRequest{
		TenantID:   tenantID,
		AccountID:  accountID,
		SecurityID: securityID,
		Quantity:   10,
		PriceCents: 5000,
		TradeDate:  time.Now(),
	})
	if err == nil {
		t.Fatal("expected BuyHolding to surface the lot-save error, got nil")
	}

	// Headline assertion: the holding + trade rows must have been rolled back.
	// Pre-Task-5 they persist via the default auto-commit client (1 each); post-
	// Task-5 WithTx rolls them back with the failed lot save (0 each).
	holdingCount, err := client.Holding.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count holdings: %v", err)
	}
	if holdingCount != 0 {
		t.Errorf("holding row should have rolled back, got %d row(s)", holdingCount)
	}
	tradeCount, err := client.HoldingTransaction.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count trades: %v", err)
	}
	if tradeCount != 0 {
		t.Errorf("trade row should have rolled back, got %d row(s)", tradeCount)
	}
}

// TestBuyHolding_CommitsOnSuccess is the paired control for the rollback test:
// when every step succeeds, the WithTx wrapper commits and the holding + trade
// + lot writes are all durable. Without this control a bug where WithTx always
// rolled back would pass the rollback test silently.
func TestBuyHolding_CommitsOnSuccess(t *testing.T) {
	db, client := setupHoldingTxTestDB(t)

	tenantID, accountID, securityID := uuid.New(), uuid.New(), uuid.New()
	ctx := context.Background()

	holdRepo := holdingsec.NewHoldingRepository(client)
	tradeRepo := holdingsec.NewTradeRepository(client)
	lotRepo := holdingsec.NewLotRepository(client)

	svc := NewService(nil, holdRepo, tradeRepo)
	svc.SetLotRepository(lotRepo)
	svc.SetDB(db)

	dto, err := svc.BuyHolding(ctx, HoldingTradeRequest{
		TenantID:   tenantID,
		AccountID:  accountID,
		SecurityID: securityID,
		Quantity:   10,
		PriceCents: 5000,
		TradeDate:  time.Now(),
	})
	if err != nil {
		t.Fatalf("BuyHolding succeeded-path: %v", err)
	}
	if dto == nil {
		t.Fatal("expected non-nil DTO on success")
	}

	holdingCount, err := client.Holding.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count holdings: %v", err)
	}
	if holdingCount != 1 {
		t.Errorf("holding row should have committed, got %d row(s)", holdingCount)
	}
	tradeCount, err := client.HoldingTransaction.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count trades: %v", err)
	}
	if tradeCount != 1 {
		t.Errorf("trade row should have committed, got %d row(s)", tradeCount)
	}
	lotCount, err := client.HoldingLot.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count lots: %v", err)
	}
	if lotCount != 1 {
		t.Errorf("lot row should have committed, got %d row(s)", lotCount)
	}
}
