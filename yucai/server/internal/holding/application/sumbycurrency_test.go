package application

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/holding/domain"
)

// --- D-currency Task 5: SumMarketValueByCurrency ---

// pagedHoldingRepo is an in-memory HoldingRepository that honours PageSize by
// returning one page at a time with a non-empty NextPageToken until exhausted,
// so the pagination loop in SumMarketValueByCurrency can be exercised.
type pagedHoldingRepo struct {
	all []domain.Holding
}

func (r *pagedHoldingRepo) SaveOrUpdate(_ context.Context, h *domain.Holding) error {
	r.all = append(r.all, *h)
	return nil
}
func (r *pagedHoldingRepo) FindByAccountAndSecurity(context.Context, uuid.UUID, uuid.UUID, uuid.UUID) (*domain.Holding, error) {
	panic("not used")
}
func (r *pagedHoldingRepo) FindByID(context.Context, uuid.UUID) (*domain.Holding, error) {
	panic("not used")
}
func (r *pagedHoldingRepo) FindAllForBackup(context.Context, uuid.UUID) ([]domain.Holding, []domain.HoldingTransaction, error) {
	panic("not used")
}
func (r *pagedHoldingRepo) DeleteByTenant(context.Context, uuid.UUID) error {
	panic("not used")
}
func (r *pagedHoldingRepo) FindAll(_ context.Context, tenantID uuid.UUID, accountID *uuid.UUID, page domain.PageRequest) (*domain.PaginatedResult[domain.Holding], error) {
	// Filter by tenant + optional account.
	filtered := make([]domain.Holding, 0, len(r.all))
	for _, h := range r.all {
		if h.TenantID != tenantID {
			continue
		}
		if accountID != nil && h.AccountID != *accountID {
			continue
		}
		filtered = append(filtered, h)
	}

	// Fixed test page size of 2, regardless of the service's requested
	// PageSize (100): this forces the service's pagination loop to actually
	// iterate with a small seed set.
	const ps = 2
	// Determine the offset from the opaque token (simple integer encoding).
	skip := 0
	if n, err := atoiSafe(page.PageToken); err == nil {
		skip = n
	}
	end := skip + ps
	if end > len(filtered) {
		end = len(filtered)
	}
	items := filtered[skip:end]
	res := &domain.PaginatedResult[domain.Holding]{
		Items:      items,
		TotalCount: int32(len(filtered)),
	}
	if end < len(filtered) {
		res.NextPageToken = itoaSafe(end)
	}
	return res, nil
}

// atoiSafe / itoaSafe — minimal int<->string for the test token encoding.
func atoiSafe(s string) (int, error) {
	if s == "" {
		return 0, errors.New("empty")
	}
	n := 0
	for _, c := range s {
		if c < '0' || c > '9' {
			return 0, errors.New("not a number")
		}
		n = n*10 + int(c-'0')
	}
	return n, nil
}
func itoaSafe(n int) string {
	if n == 0 {
		return "0"
	}
	out := ""
	for n > 0 {
		out = string(rune('0'+n%10)) + out
		n /= 10
	}
	return out
}

// TestSumMarketValueByCurrency_PerSecurityCurrency verifies:
//   - Σ mv (qty × currentPrice) grouped by each security's CurrencyCode;
//   - mixed CNY + USD securities land in separate buckets;
//   - tenant scoping (other tenant's holdings excluded);
//   - a holding whose security is missing is skipped (best-effort).
func TestSumMarketValueByCurrency_PerSecurityCurrency(t *testing.T) {
	tenant := uuid.New()
	otherTenant := uuid.New()
	cnySec, usdSec, missingSec := uuid.New(), uuid.New(), uuid.New()

	secRepo := newFullSecRepo([]secSeed{
		{ID: cnySec, Symbol: "600519", Exchange: "SSE", Type: domain.SecurityTypeStock, Currency: "CNY", CurrentPriceCents: 1680},
		{ID: usdSec, Symbol: "AAPL", Exchange: "NASDAQ", Type: domain.SecurityTypeStock, Currency: "USD", CurrentPriceCents: 19500},
		// missingSec deliberately NOT seeded → holding skipped.
	})

	hr := &pagedHoldingRepo{}
	// CNY holding: 10 × 1680 = 16800.
	hr.all = append(hr.all, domain.Holding{ID: uuid.New(), TenantID: tenant, AccountID: uuid.New(), SecurityID: cnySec, Quantity: 10, AvgCostCents: 1600})
	// USD holding: 2 × 19500 = 39000.
	hr.all = append(hr.all, domain.Holding{ID: uuid.New(), TenantID: tenant, AccountID: uuid.New(), SecurityID: usdSec, Quantity: 2, AvgCostCents: 19000})
	// Holding with missing security → skipped, not fatal.
	hr.all = append(hr.all, domain.Holding{ID: uuid.New(), TenantID: tenant, AccountID: uuid.New(), SecurityID: missingSec, Quantity: 99, AvgCostCents: 1})
	// Other tenant's holding → excluded by tenant scoping.
	hr.all = append(hr.all, domain.Holding{ID: uuid.New(), TenantID: otherTenant, AccountID: uuid.New(), SecurityID: cnySec, Quantity: 100, AvgCostCents: 1})

	svc := NewService(secRepo, hr, &memTradeRepo{})
	got, err := svc.SumMarketValueByCurrency(context.Background(), tenant)
	if err != nil {
		t.Fatalf("SumMarketValueByCurrency error: %v", err)
	}
	if got["CNY"] != 16800 {
		t.Errorf("CNY mv = %d, want 16800 (missing-security + other-tenant excluded)", got["CNY"])
	}
	if got["USD"] != 39000 {
		t.Errorf("USD mv = %d, want 39000", got["USD"])
	}
	if _, ok := got[""]; ok {
		t.Errorf("missing-security holding must not contribute to any bucket, got %v", got)
	}
}

// TestSumMarketValueByCurrency_Pagination verifies the service loops across
// pages when the repo returns a NextPageToken.
func TestSumMarketValueByCurrency_Pagination(t *testing.T) {
	tenant := uuid.New()
	secID := uuid.New()
	secRepo := newFullSecRepo([]secSeed{
		{ID: secID, Symbol: "X", Exchange: "SSE", Type: domain.SecurityTypeStock, Currency: "CNY", CurrentPriceCents: 100},
	})

	hr := &pagedHoldingRepo{}
	// 3 holdings × 100 mv = 300; PageSize 2 → 2 pages.
	for i := 0; i < 3; i++ {
		hr.all = append(hr.all, domain.Holding{
			ID: uuid.New(), TenantID: tenant, AccountID: uuid.New(), SecurityID: secID,
			Quantity: 1, AvgCostCents: 100,
		})
	}

	svc := NewService(secRepo, hr, &memTradeRepo{})
	got, err := svc.SumMarketValueByCurrency(context.Background(), tenant)
	if err != nil {
		t.Fatalf("SumMarketValueByCurrency error: %v", err)
	}
	if got["CNY"] != 300 {
		t.Errorf("CNY mv across pages = %d, want 300", got["CNY"])
	}
}

// TestSumMarketValueByCurrency_EmptyTenant returns an empty (non-nil) map.
func TestSumMarketValueByCurrency_EmptyTenant(t *testing.T) {
	secRepo := newFullSecRepo(nil)
	hr := &pagedHoldingRepo{}
	svc := NewService(secRepo, hr, &memTradeRepo{})
	got, err := svc.SumMarketValueByCurrency(context.Background(), uuid.New())
	if err != nil {
		t.Fatalf("SumMarketValueByCurrency error: %v", err)
	}
	if got == nil {
		t.Fatal("expected non-nil map for empty tenant")
	}
	if len(got) != 0 {
		t.Errorf("expected empty map, got %v", got)
	}
}
