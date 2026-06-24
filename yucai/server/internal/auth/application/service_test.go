package application_test

import (
	"context"
	"fmt"
	"testing"

	"github.com/google/uuid"

	"github.com/yucai/server/internal/auth/application"
	"github.com/yucai/server/internal/auth/domain"
)

// --- Test doubles ---

type fakeTenantRepo struct {
	tenant  *domain.Tenant
	saved   *domain.Tenant
	saveErr error
}

func (f *fakeTenantRepo) Save(ctx context.Context, t *domain.Tenant) error {
	if f.saveErr != nil {
		return f.saveErr
	}
	f.saved = t
	return nil
}
func (f *fakeTenantRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.Tenant, error) {
	if f.tenant == nil {
		return nil, fmt.Errorf("tenant not found")
	}
	return f.tenant, nil
}
func (f *fakeTenantRepo) FindAllIDs(ctx context.Context) ([]uuid.UUID, error) { return nil, nil }
func (f *fakeTenantRepo) FindAllIntervalHours(ctx context.Context) ([]int, error) {
	return nil, nil
}
func (f *fakeTenantRepo) Update(ctx context.Context, t *domain.Tenant) error {
	if f.saveErr != nil {
		return f.saveErr
	}
	f.saved = t
	return nil
}

type fakeCurrencyChecker struct {
	exists map[string]bool
}

func (f *fakeCurrencyChecker) FindByCode(ctx context.Context, code string) (bool, error) {
	return f.exists[code], nil
}

// newPrefService builds a Service wired with only the dependencies the
// preference RPCs touch (all others nil). This keeps the test focused and
// avoids constructing the full register/login/refresh handler graph.
func newPrefService(t *testing.T, repo *fakeTenantRepo, checker *fakeCurrencyChecker) *application.Service {
	t.Helper()
	return application.NewService(
		repo, nil, nil, nil, nil, nil, nil, nil, checker,
	)
}

// --- GetPreferences ---

func TestGetPreferences_ReturnsDTO(t *testing.T) {
	tenant, err := domain.NewTenant("Acme", domain.TenantTypePersonal)
	if err != nil {
		t.Fatalf("new tenant: %v", err)
	}
	if err := tenant.UpdatePreferences("USD", 12); err != nil {
		t.Fatalf("seed preferences: %v", err)
	}
	repo := &fakeTenantRepo{tenant: tenant}
	svc := newPrefService(t, repo, &fakeCurrencyChecker{})

	dto, err := svc.GetPreferences(context.Background(), tenant.ID)
	if err != nil {
		t.Fatalf("GetPreferences: %v", err)
	}
	if dto.PreferredCurrency != "USD" {
		t.Errorf("preferred_currency = %q, want USD", dto.PreferredCurrency)
	}
	if dto.RateSyncIntervalHours != 12 {
		t.Errorf("rate_sync_interval_hours = %d, want 12", dto.RateSyncIntervalHours)
	}
}

func TestGetPreferences_TenantNotFound(t *testing.T) {
	repo := &fakeTenantRepo{tenant: nil}
	svc := newPrefService(t, repo, &fakeCurrencyChecker{})

	if _, err := svc.GetPreferences(context.Background(), uuid.New()); err == nil {
		t.Fatal("expected error for missing tenant, got nil")
	}
}

// --- UpdatePreferences ---

func TestUpdatePreferences_Valid(t *testing.T) {
	tenant, err := domain.NewTenant("Acme", domain.TenantTypePersonal)
	if err != nil {
		t.Fatalf("new tenant: %v", err)
	}
	repo := &fakeTenantRepo{tenant: tenant}
	checker := &fakeCurrencyChecker{exists: map[string]bool{"CNY": true}}
	svc := newPrefService(t, repo, checker)

	dto, err := svc.UpdatePreferences(context.Background(), application.UpdatePreferencesRequest{
		TenantID:          tenant.ID,
		PreferredCurrency: "cny", // lower-case on purpose: service should validate the upper'd code
		IntervalHours:     8,
	})
	if err != nil {
		t.Fatalf("UpdatePreferences: %v", err)
	}
	if dto.PreferredCurrency != "CNY" {
		t.Errorf("preferred_currency = %q, want CNY", dto.PreferredCurrency)
	}
	if dto.RateSyncIntervalHours != 8 {
		t.Errorf("rate_sync_interval_hours = %d, want 8", dto.RateSyncIntervalHours)
	}
	if repo.saved == nil {
		t.Fatal("tenant was not persisted via repo Update/Save")
	}
	if repo.saved.PreferredCurrency != "CNY" {
		t.Errorf("persisted preferred_currency = %q, want CNY", repo.saved.PreferredCurrency)
	}
}

func TestUpdatePreferences_InvalidCurrencyCode(t *testing.T) {
	tenant, _ := domain.NewTenant("Acme", domain.TenantTypePersonal)
	repo := &fakeTenantRepo{tenant: tenant}
	// code XXX is not in the currency catalog
	checker := &fakeCurrencyChecker{exists: map[string]bool{}}
	svc := newPrefService(t, repo, checker)

	_, err := svc.UpdatePreferences(context.Background(), application.UpdatePreferencesRequest{
		TenantID:          tenant.ID,
		PreferredCurrency: "XXX",
		IntervalHours:     8,
	})
	if err == nil {
		t.Fatal("expected error for unknown currency code, got nil")
	}
}

func TestUpdatePreferences_IntervalZero(t *testing.T) {
	tenant, _ := domain.NewTenant("Acme", domain.TenantTypePersonal)
	repo := &fakeTenantRepo{tenant: tenant}
	checker := &fakeCurrencyChecker{exists: map[string]bool{"CNY": true}}
	svc := newPrefService(t, repo, checker)

	_, err := svc.UpdatePreferences(context.Background(), application.UpdatePreferencesRequest{
		TenantID:          tenant.ID,
		PreferredCurrency: "CNY",
		IntervalHours:     0,
	})
	if err == nil {
		t.Fatal("expected error for interval=0, got nil")
	}
}

func TestUpdatePreferences_IntervalTooLarge(t *testing.T) {
	tenant, _ := domain.NewTenant("Acme", domain.TenantTypePersonal)
	repo := &fakeTenantRepo{tenant: tenant}
	checker := &fakeCurrencyChecker{exists: map[string]bool{"CNY": true}}
	svc := newPrefService(t, repo, checker)

	_, err := svc.UpdatePreferences(context.Background(), application.UpdatePreferencesRequest{
		TenantID:          tenant.ID,
		PreferredCurrency: "CNY",
		IntervalHours:     200,
	})
	if err == nil {
		t.Fatal("expected error for interval=200, got nil")
	}
}
