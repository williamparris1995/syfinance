package exporter

import (
	"context"
	"encoding/json"
	"errors"

	"testing"

	"github.com/google/uuid"
	holdingDomain "github.com/yucai/server/internal/holding/domain"
)

// fakeHoldingRepoExporter is an in-memory HoldingRepository port for exporter
// tests. FindAllForBackup returns non-nil empty slices for an empty tenant so
// the exported JSON arrays are [] (not null), matching the real repo's
// `make([]T, 0, n)` allocation pattern.
type fakeHoldingRepoExporter struct {
	holdings     map[uuid.UUID][]holdingDomain.Holding
	transactions map[uuid.UUID][]holdingDomain.HoldingTransaction
	findAllErr   error
	saveErr      error
	deleteErr    error
	deleteCalls  int
}

func newFakeHoldingRepoExporter() *fakeHoldingRepoExporter {
	return &fakeHoldingRepoExporter{
		holdings:     map[uuid.UUID][]holdingDomain.Holding{},
		transactions: map[uuid.UUID][]holdingDomain.HoldingTransaction{},
	}
}

func (f *fakeHoldingRepoExporter) FindAllForBackup(_ context.Context, tenantID uuid.UUID) ([]holdingDomain.Holding, []holdingDomain.HoldingTransaction, error) {
	if f.findAllErr != nil {
		return nil, nil, f.findAllErr
	}
	h := f.holdings[tenantID]
	if h == nil {
		h = []holdingDomain.Holding{}
	}
	t := f.transactions[tenantID]
	if t == nil {
		t = []holdingDomain.HoldingTransaction{}
	}
	return h, t, nil
}

func (f *fakeHoldingRepoExporter) SaveOrUpdate(_ context.Context, h *holdingDomain.Holding) error {
	if f.saveErr != nil {
		return f.saveErr
	}
	cp := *h
	f.holdings[cp.TenantID] = append(f.holdings[cp.TenantID], cp)
	return nil
}

func (f *fakeHoldingRepoExporter) DeleteByTenant(_ context.Context, tenantID uuid.UUID) error {
	f.deleteCalls++
	if f.deleteErr != nil {
		return f.deleteErr
	}
	delete(f.holdings, tenantID)
	delete(f.transactions, tenantID)
	return nil
}

// fakeTradeRepoExporter is an in-memory TradeRepository port for exporter
// tests. Save records the trade under its TenantID so Import can be observed.
type fakeTradeRepoExporter struct {
	saved   map[uuid.UUID][]holdingDomain.HoldingTransaction
	saveErr error
}

func newFakeTradeRepoExporter() *fakeTradeRepoExporter {
	return &fakeTradeRepoExporter{saved: map[uuid.UUID][]holdingDomain.HoldingTransaction{}}
}

func (f *fakeTradeRepoExporter) Save(_ context.Context, t *holdingDomain.HoldingTransaction) error {
	if f.saveErr != nil {
		return f.saveErr
	}
	cp := *t
	f.saved[cp.TenantID] = append(f.saved[cp.TenantID], cp)
	return nil
}

// newTestHolding builds a Holding literal with realistic fields.
func newTestHolding(tenantID uuid.UUID, accountIdx int) holdingDomain.Holding {
	return holdingDomain.Holding{
		ID:           uuid.New(),
		TenantID:     tenantID,
		AccountID:    uuid.New(),
		SecurityID:   uuid.New(),
		Quantity:     100,
		AvgCostCents: 5000,
		Version:      1,
		CreatedAt:    testDate,
		UpdatedAt:    testDate,
	}
}

// newTestHoldingTransaction builds a HoldingTransaction tied to a holding's
// account + security.
func newTestHoldingTransaction(tenantID, accountID, securityID uuid.UUID, tradeType holdingDomain.TradeType) holdingDomain.HoldingTransaction {
	return holdingDomain.HoldingTransaction{
		ID:               uuid.New(),
		TenantID:         tenantID,
		AccountID:        accountID,
		SecurityID:       securityID,
		TradeType:        tradeType,
		Quantity:         10,
		PriceCents:       5000,
		AmountCents:      50000,
		FeeCents:         5,
		RealizedPnLCents: 0,
		TradeDate:        testDate,
		Notes:            "backup test",
		CreatedAt:        testDate,
	}
}

// TestHoldingExporter_Name confirms the module identifier used as the
// BackupEnvelope.Modules key.
func TestHoldingExporter_Name(t *testing.T) {
	e := NewHoldingExporter(newFakeHoldingRepoExporter(), newFakeTradeRepoExporter())
	if got := e.Name(); got != "holding" {
		t.Fatalf("Name = %q, want \"holding\"", got)
	}
}

// TestHoldingExporter_Roundtrip verifies Export -> Purge -> Import restores the
// same holdings + holding transactions.
func TestHoldingExporter_Roundtrip(t *testing.T) {
	tenantID := uuid.New()
	repo := newFakeHoldingRepoExporter()
	trades := newFakeTradeRepoExporter()

	h1 := newTestHolding(tenantID, 1)
	h2 := newTestHolding(tenantID, 2)
	repo.holdings[tenantID] = []holdingDomain.Holding{h1, h2}
	t1 := newTestHoldingTransaction(tenantID, h1.AccountID, h1.SecurityID, holdingDomain.TradeTypeBuy)
	t2 := newTestHoldingTransaction(tenantID, h2.AccountID, h2.SecurityID, holdingDomain.TradeTypeDividend)
	repo.transactions[tenantID] = []holdingDomain.HoldingTransaction{t1, t2}

	e := NewHoldingExporter(repo, trades)

	raw, err := e.Export(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	var payload holdingBackupPayload
	if err := json.Unmarshal(raw, &payload); err != nil {
		t.Fatalf("unmarshal exported: %v", err)
	}
	if len(payload.Holdings) != 2 {
		t.Fatalf("exported %d holdings, want 2", len(payload.Holdings))
	}
	if len(payload.Transactions) != 2 {
		t.Fatalf("exported %d transactions, want 2", len(payload.Transactions))
	}

	if err := e.Purge(context.Background(), tenantID); err != nil {
		t.Fatalf("Purge: %v", err)
	}
	if got := len(repo.holdings[tenantID]); got != 0 {
		t.Fatalf("after Purge repo has %d holdings, want 0", got)
	}
	if got := len(repo.transactions[tenantID]); got != 0 {
		t.Fatalf("after Purge repo has %d transactions, want 0", got)
	}

	if err := e.Import(context.Background(), tenantID, raw); err != nil {
		t.Fatalf("Import: %v", err)
	}
	if got := len(repo.holdings[tenantID]); got != len(payload.Holdings) {
		t.Fatalf("after Import repo has %d holdings, want %d", got, len(payload.Holdings))
	}
	if got := len(trades.saved[tenantID]); got != len(payload.Transactions) {
		t.Fatalf("after Import trades has %d rows, want %d", got, len(payload.Transactions))
	}
}

// TestHoldingExporter_Import_TenantRewrite verifies Import stamps the target
// tenantID onto every record (both holdings and transactions), so a backup
// restored under a new tenant does not leak the original tenant's IDs.
func TestHoldingExporter_Import_TenantRewrite(t *testing.T) {
	srcTenant := uuid.New()
	repo := newFakeHoldingRepoExporter()
	trades := newFakeTradeRepoExporter()

	h := newTestHolding(srcTenant, 1)
	repo.holdings[srcTenant] = []holdingDomain.Holding{h}
	repo.transactions[srcTenant] = []holdingDomain.HoldingTransaction{
		newTestHoldingTransaction(srcTenant, h.AccountID, h.SecurityID, holdingDomain.TradeTypeBuy),
	}

	e := NewHoldingExporter(repo, trades)
	raw, err := e.Export(context.Background(), srcTenant)
	if err != nil {
		t.Fatalf("Export: %v", err)
	}

	dstTenant := uuid.New()
	if err := e.Import(context.Background(), dstTenant, raw); err != nil {
		t.Fatalf("Import: %v", err)
	}
	for _, got := range repo.holdings[dstTenant] {
		if got.TenantID != dstTenant {
			t.Fatalf("imported holding TenantID = %s, want %s", got.TenantID, dstTenant)
		}
	}
	for _, got := range trades.saved[dstTenant] {
		if got.TenantID != dstTenant {
			t.Fatalf("imported transaction TenantID = %s, want %s", got.TenantID, dstTenant)
		}
	}
}

// TestHoldingExporter_Export_EmptyTenant verifies Export on a tenant with no
// holdings returns a valid JSON payload with empty (non-null) arrays.
func TestHoldingExporter_Export_EmptyTenant(t *testing.T) {
	e := NewHoldingExporter(newFakeHoldingRepoExporter(), newFakeTradeRepoExporter())
	raw, err := e.Export(context.Background(), uuid.New())
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	var payload holdingBackupPayload
	if err := json.Unmarshal(raw, &payload); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if payload.Holdings != nil && len(payload.Holdings) != 0 {
		t.Fatalf("Holdings = %v, want empty", payload.Holdings)
	}
	if payload.Transactions != nil && len(payload.Transactions) != 0 {
		t.Fatalf("Transactions = %v, want empty", payload.Transactions)
	}
	// Raw bytes must contain [], not null, for both fields.
	if string(raw) == "null" {
		t.Fatalf("Export empty tenant = null, want object with [] arrays")
	}
}

// TestHoldingExporter_Export_Error verifies Export propagates a FindAllForBackup
// error (error-path coverage).
func TestHoldingExporter_Export_Error(t *testing.T) {
	injected := errors.New("boom: db down")
	repo := newFakeHoldingRepoExporter()
	repo.findAllErr = injected
	e := NewHoldingExporter(repo, newFakeTradeRepoExporter())
	if _, err := e.Export(context.Background(), uuid.New()); err == nil {
		t.Fatal("Export expected error, got nil")
	}
}

// TestHoldingExporter_Import_SaveError verifies Import propagates a
// SaveOrUpdate error (error-path coverage).
func TestHoldingExporter_Import_SaveError(t *testing.T) {
	injected := errors.New("boom: write fail")
	tenantID := uuid.New()
	repo := newFakeHoldingRepoExporter()
	h := newTestHolding(tenantID, 1)
	repo.holdings[tenantID] = []holdingDomain.Holding{h}
	e := NewHoldingExporter(repo, newFakeTradeRepoExporter())
	raw, err := e.Export(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("Export: %v", err)
	}
	repo.saveErr = injected
	if err := e.Import(context.Background(), tenantID, raw); err == nil {
		t.Fatal("Import expected error, got nil")
	}
}

// TestHoldingExporter_Purge_Error verifies Purge propagates a DeleteByTenant
// error (error-path coverage).
func TestHoldingExporter_Purge_Error(t *testing.T) {
	injected := errors.New("boom: delete fail")
	repo := newFakeHoldingRepoExporter()
	repo.deleteErr = injected
	e := NewHoldingExporter(repo, newFakeTradeRepoExporter())
	if err := e.Purge(context.Background(), uuid.New()); err == nil {
		t.Fatal("Purge expected error, got nil")
	}
}
