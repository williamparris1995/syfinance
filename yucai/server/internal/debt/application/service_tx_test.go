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

	debtrepo "github.com/yucai/server/internal/debt/adapter/driven/repository"
	"github.com/yucai/server/internal/debt/domain"
	debtent "github.com/yucai/server/internal/debt/ent"
)

// debtTxTestDialect is the ent dialect string for SQLite (==
// entgo.io/ent/dialect.SQLite). Forwarded to ent's mutation builders so they
// emit "?" placeholders instead of PostgreSQL's "$1" (mirrors Task 4/5's
// service_tx_test.go constants in transaction/holding application packages).
const debtTxTestDialect = "sqlite3"

// setupDebtTxTestDB opens ONE shared in-memory SQLite database, runs the debt
// ent auto-migration against it, and returns the underlying *sql.DB plus a
// ready debt ent client. The shared *sql.DB is what the service's WithTx opens
// its transaction on (mirrors Task 1's provideDB + Task 4/5's setupTxTestDB
// pattern in transaction/holding application packages).
//
// SetMaxOpenConns(1) is mandatory for shared in-memory SQLite — it pins the
// pool to a single physical connection so the *sql.Tx grabbed by WithTx and
// the subsequent read-through-default-client hit the same database.
func setupDebtTxTestDB(t *testing.T) (*sql.DB, *debtent.Client) {
	t.Helper()
	dbName := "debt_app_shared_" + strings.ReplaceAll(t.Name(), "/", "_")
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })

	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}
	db.SetMaxOpenConns(1)

	drv := entsql.OpenDB(debtTxTestDialect, db)
	client := debtent.NewClient(debtent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate debt schema: %v", err)
	}
	t.Cleanup(func() { _ = client.Close() })
	return db, client
}

// failingCashRecorder returns failErr from Record, simulating a cash-transaction
// write failure AFTER the debt's schedule.Paid + principal persist have
// succeeded inside the debt service's WithTx fn. Mirrors Task 5's failingLotRepo
// mid-flow failure injection pattern in holding/application/service_tx_test.go.
type failingCashRecorder struct{ failErr error }

func (r *failingCashRecorder) Record(_ context.Context, _ domain.RepaymentCashRecordRequest) (uuid.UUID, error) {
	return uuid.Nil, r.failErr
}

// seedOneEntryDebt builds + persists a BorrowedIn debt with a single unpaid
// schedule entry via the real ent repo. Returns the seeded debt + its entry ID
// so tests can drive RecordPayment and assert on the post-state.
func seedOneEntryDebt(t *testing.T, repo domain.DebtRepository, tenantID uuid.UUID) (*domain.DebtDetails, uuid.UUID) {
	t.Helper()
	debt, err := domain.NewDebtDetails(
		tenantID, uuid.New(), "Bank", 0.0, domain.AmortizationLumpSum,
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC),
		1_000_00, domain.BorrowedIn, "", "", "", nil,
	)
	if err != nil {
		t.Fatalf("seed debt: build: %v", err)
	}
	entryID := uuid.New()
	debt.Schedule = []domain.PaymentScheduleEntry{{
		ID:             entryID,
		DebtID:         debt.ID,
		PaymentDate:    time.Date(2026, 2, 1, 0, 0, 0, 0, time.UTC),
		PrincipalCents: 1_000_00,
		InterestCents:  0,
		TotalCents:     1_000_00,
		Paid:           false,
	}}
	if err := repo.Save(context.Background(), debt); err != nil {
		t.Fatalf("seed debt: save: %v", err)
	}
	return debt, entryID
}

// TestRecordPayment_RollbackOnCashRecordFailure is the headline transactional
// guarantee for Task 6 (audit D3): when the cash-record write fails AFTER the
// debt's schedule.Paid + principal persist have succeeded inside the service's
// WithTx fn, the entire operation must roll back — leaving the schedule entry
// unpaid. Pre-Task-6 (no sqltx.WithTx wrapping of RecordPayment, cash-write
// best-effort in the handler), the debt write persists and the entry is marked
// paid; post-Task-6 the WithTx wrapper rolls back with the failed cash record.
//
// The failingCashRecorder is wired in place of a real recorder so the debt
// write path still goes through the real ent client (the system under test for
// the rollback assertion). Mirrors Task 5's TestBuyHolding_RollbackOnLotSaveFailure.
func TestRecordPayment_RollbackOnCashRecordFailure(t *testing.T) {
	db, client := setupDebtTxTestDB(t)
	tenantID := uuid.New()
	ctx := context.Background()

	debtRepo := debtrepo.NewDebtRepository(client)
	debt, entryID := seedOneEntryDebt(t, debtRepo, tenantID)

	svc := NewService(debtRepo)
	svc.SetDB(db)
	svc.SetCashRecorder(&failingCashRecorder{failErr: errors.New("simulated cash record failure")})

	fromAccID, debtAccID := uuid.New(), uuid.New()
	_, err := svc.RecordPayment(ctx, RecordPaymentRequest{
		TenantID:        tenantID,
		DebtID:          debt.ID,
		ScheduleEntryID: entryID,
		FromAccountID:   fromAccID,
		CashRecord: &domain.RepaymentCashRecordRequest{
			TenantID:        tenantID,
			TransactionDate: time.Now(),
			Description:     "test repayment",
			Entries: []domain.RepaymentCashEntry{
				{AccountID: fromAccID, ChartOfAccountCode: "1001", CreditCents: 1_000_00},
				{AccountID: debtAccID, ChartOfAccountCode: "2202", DebitCents: 1_000_00},
			},
		},
	})
	if err == nil {
		t.Fatal("expected RecordPayment to surface the cash-record error, got nil")
	}

	// Headline assertion: the schedule entry must have rolled back to unpaid.
	// Pre-Task-6 it persisted via the default auto-commit client (Paid=true);
	// post-Task-6 WithTx rolls it back with the failed cash record (Paid=false).
	got, err := debtRepo.FindByID(ctx, tenantID, debt.ID)
	if err != nil {
		t.Fatalf("find debt post-call: %v", err)
	}
	for _, e := range got.Schedule {
		if e.ID == entryID {
			if e.Paid {
				t.Errorf("schedule entry should have rolled back to unpaid, got Paid=true")
			}
			if e.TransactionID != nil {
				t.Errorf("schedule entry TransactionID should have rolled back to nil, got %v", e.TransactionID)
			}
		}
	}
}

// TestRecordPayment_CommitsOnSuccess is the paired control for the rollback
// test: when the cash recorder is nil (skip path) and every step succeeds, the
// WithTx wrapper commits and the schedule entry is durably marked paid.
// Without this control a bug where WithTx always rolled back would pass the
// rollback test silently.
func TestRecordPayment_CommitsOnSuccess(t *testing.T) {
	db, client := setupDebtTxTestDB(t)
	tenantID := uuid.New()
	ctx := context.Background()

	debtRepo := debtrepo.NewDebtRepository(client)
	debt, entryID := seedOneEntryDebt(t, debtRepo, tenantID)

	svc := NewService(debtRepo)
	svc.SetDB(db)

	resp, err := svc.RecordPayment(ctx, RecordPaymentRequest{
		TenantID:        tenantID,
		DebtID:          debt.ID,
		ScheduleEntryID: entryID,
		FromAccountID:   uuid.New(),
	})
	if err != nil {
		t.Fatalf("RecordPayment success-path: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil response on success")
	}

	got, err := debtRepo.FindByID(ctx, tenantID, debt.ID)
	if err != nil {
		t.Fatalf("find debt post-call: %v", err)
	}
	var found bool
	for _, e := range got.Schedule {
		if e.ID == entryID {
			found = true
			if !e.Paid {
				t.Errorf("schedule entry should be Paid=true after commit, got false")
			}
		}
	}
	if !found {
		t.Fatal("schedule entry not found post-call")
	}
}
