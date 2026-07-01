package grpc

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	currencydomain "github.com/yucai/server/internal/currency/domain"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	"github.com/yucai/server/internal/networth/application"
	pb "github.com/yucai/server/internal/proto/networth/v1"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// ---------------------------------------------------------------------------
// D-currency Task 6: NetWorthHandler.GetNetWorth
//
// The handler is a thin adapter over application.Service — it resolves the
// tenant_id from the auth context, forwards base_currency, and maps the result.
// These tests drive the handler end-to-end with a real Service backed by
// in-memory fake source ports + a fake rate repo, asserting:
//   - GetNetWorth returns the aggregated assets/liabilities/net and defaults
//     currency to "CNY" when base_currency is empty.
//   - GetNetWorth forwards a non-empty base_currency (e.g. "USD") and the
//     response echoes it back.
// ---------------------------------------------------------------------------

// fakeAccountSource returns a fixed per-currency balance map.
type fakeAccountSource struct {
	bal map[string]int64
}

func (s *fakeAccountSource) SumBalancesByCurrency(context.Context, uuid.UUID) (map[string]int64, error) {
	return s.bal, nil
}

// fakeHoldingSource returns a fixed per-currency market-value map.
type fakeHoldingSource struct {
	mv map[string]int64
}

func (s *fakeHoldingSource) SumMarketValueByCurrency(context.Context, uuid.UUID) (map[string]int64, error) {
	return s.mv, nil
}

// fakeDebtSource returns a fixed per-currency remaining map.
type fakeDebtSource struct {
	rem map[string]int64
}

func (s *fakeDebtSource) SumRemainingByCurrency(context.Context, uuid.UUID) (map[string]int64, error) {
	return s.rem, nil
}

// fakeRateRepo returns a fixed rate per currency code (1.0 when unknown). It
// implements the full currencydomain.RateHistoryRepository surface so the real
// networth Service can consume it.
type fakeRateRepo struct {
	rates map[string]float64
}

func (r *fakeRateRepo) FindRate(_ context.Context, code string, _ time.Time) (float64, error) {
	if v, ok := r.rates[code]; ok {
		return v, nil
	}
	return 1.0, nil
}

func (r *fakeRateRepo) FindRange(context.Context, string, time.Time, time.Time) ([]currencydomain.RateHistory, error) {
	return nil, nil
}

func (r *fakeRateRepo) Save(context.Context, currencydomain.RateHistory) error { return nil }

// withTenant mirrors what the auth middleware does in production.
func withTenant(tenantID uuid.UUID) context.Context {
	return authgrpc.WithTenantID(authgrpc.WithUserID(context.Background(), uuid.New()), tenantID)
}

// newSvc builds a real networth Service backed by the given fakes.
func newSvc(acct *fakeAccountSource, hold *fakeHoldingSource, debt *fakeDebtSource, rates *fakeRateRepo) *application.Service {
	return application.NewService(acct, hold, debt, rates, nil)
}

// TestGetNetWorthReturnsAggregatedAndDefaultsCNY drives the handler with an
// empty base_currency and asserts the response carries the summed assets
// (account+holding), liabilities (debt), net (assets−liab), and currency=CNY.
func TestGetNetWorthReturnsAggregatedAndDefaultsCNY(t *testing.T) {
	svc := newSvc(
		&fakeAccountSource{bal: map[string]int64{"CNY": 100_00}},
		&fakeHoldingSource{mv: map[string]int64{"CNY": 200_00}},
		&fakeDebtSource{rem: map[string]int64{"CNY": 50_00}},
		&fakeRateRepo{rates: map[string]float64{"CNY": 1.0}},
	)
	h := NewNetWorthHandler(svc)

	resp, err := h.GetNetWorth(withTenant(uuid.New()), &pb.GetNetWorthRequest{})
	if err != nil {
		t.Fatalf("GetNetWorth returned error: %v", err)
	}
	if resp.TotalAssetsCents != 300_00 {
		t.Errorf("total_assets_cents = %d, want %d", resp.TotalAssetsCents, 300_00)
	}
	if resp.TotalLiabilitiesCents != 50_00 {
		t.Errorf("total_liabilities_cents = %d, want %d", resp.TotalLiabilitiesCents, 50_00)
	}
	if resp.NetWorthCents != 250_00 {
		t.Errorf("net_worth_cents = %d, want %d", resp.NetWorthCents, 250_00)
	}
	if resp.Currency != "CNY" {
		t.Errorf("currency = %q, want %q", resp.Currency, "CNY")
	}
}

// TestGetNetWorthForwardsBaseCurrency asserts a non-empty base_currency is
// forwarded to the service and echoed back in the response (the conversion
// math itself is covered by the application-service tests; here we only verify
// the handler plumbs the field through).
func TestGetNetWorthForwardsBaseCurrency(t *testing.T) {
	svc := newSvc(
		&fakeAccountSource{bal: map[string]int64{"CNY": 100_00}},
		&fakeHoldingSource{mv: map[string]int64{}},
		&fakeDebtSource{rem: map[string]int64{}},
		&fakeRateRepo{rates: map[string]float64{"CNY": 1.0, "USD": 7.0}},
	)
	h := NewNetWorthHandler(svc)

	resp, err := h.GetNetWorth(withTenant(uuid.New()), &pb.GetNetWorthRequest{BaseCurrency: "USD"})
	if err != nil {
		t.Fatalf("GetNetWorth returned error: %v", err)
	}
	if resp.Currency != "USD" {
		t.Errorf("currency = %q, want %q", resp.Currency, "USD")
	}
}

// TestGetNetWorthUnauthenticatedNoTenantID asserts the handler rejects a
// request that carries no tenant_id in the context (returns Unauthenticated).
func TestGetNetWorthUnauthenticatedNoTenantID(t *testing.T) {
	svc := newSvc(
		&fakeAccountSource{bal: map[string]int64{}},
		&fakeHoldingSource{mv: map[string]int64{}},
		&fakeDebtSource{rem: map[string]int64{}},
		&fakeRateRepo{rates: map[string]float64{}},
	)
	h := NewNetWorthHandler(svc)

	_, err := h.GetNetWorth(context.Background(), &pb.GetNetWorthRequest{})
	if err == nil {
		t.Fatalf("GetNetWorth without tenant_id: expected error, got nil")
	}
	s, ok := status.FromError(err)
	if !ok {
		t.Fatalf("expected a gRPC status error, got %T: %v", err, err)
	}
	if s.Code() != codes.Unauthenticated {
		t.Errorf("expected Unauthenticated, got %s", s.Code().String())
	}
}
