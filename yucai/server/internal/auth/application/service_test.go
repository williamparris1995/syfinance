package application_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/yucai/server/internal/auth/application"
	"github.com/yucai/server/internal/auth/application/command"
	"github.com/yucai/server/internal/auth/domain"
	authjwt "github.com/yucai/server/internal/auth/infrastructure/jwt"
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
		repo, nil, nil, nil, nil, nil, nil, nil, nil, checker,
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

// --- Logout: access-token blacklist integration ---

// fakeSessionStore is a minimal command.SessionStore for the Logout test —
// only Revoke is exercised; Create/Rotate return errors so any unplanned call
// surfaces loudly.
type fakeSessionStore struct {
	revokedToken string
}

func (f *fakeSessionStore) Create(_ context.Context, _, _, _, _ string, _ time.Duration) error {
	return fmt.Errorf("Create should not be called in this test")
}
func (f *fakeSessionStore) Rotate(_ context.Context, _, _ string, _ time.Duration) (string, string, error) {
	return "", "", fmt.Errorf("Rotate should not be called in this test")
}
func (f *fakeSessionStore) Revoke(_ context.Context, token string) error {
	f.revokedToken = token
	return nil
}

// fakeBlacklist records the most recent Add call so the test can assert the
// access token's jti was pushed on logout.
type fakeBlacklist struct {
	addedJTI string
	addedEXP time.Time
}

func (f *fakeBlacklist) Add(_ context.Context, jti string, exp time.Time) error {
	f.addedJTI = jti
	f.addedEXP = exp
	return nil
}
func (f *fakeBlacklist) IsBlacklisted(_ context.Context, _ string) (bool, error) {
	return false, nil
}

// TestLogout_BlacklistsAccessTokenJTI verifies that Service.Logout both revokes
// the refresh session AND pushes the access token's jti into the blacklist —
// closing the post-logout 15min window where the access JWT would otherwise
// still authenticate.
func TestLogout_BlacklistsAccessTokenJTI(t *testing.T) {
	const secret = "logout-test-secret-at-least-32-bytes"
	const issuer = "yucai-server-test"

	ts := authjwt.NewTokenService(secret, issuer)
	uid, tid := uuid.New(), uuid.New()
	accessToken, err := ts.GenerateAccessToken(uid, tid, false)
	if err != nil {
		t.Fatalf("generate access token: %v", err)
	}
	wantJTI, wantEXP, ok := ts.ParseAccessTokenJTI(accessToken)
	if !ok {
		t.Fatal("ParseAccessTokenJTI returned ok=false for freshly minted token")
	}

	store := &fakeSessionStore{}
	bl := &fakeBlacklist{}
	refreshHandler := command.NewRefreshHandler(store)
	svc := application.NewService(
		nil, nil, ts, store, bl, nil, nil, refreshHandler, nil, nil,
	)

	const refreshToken = "opaque-refresh-token"
	if err := svc.Logout(context.Background(), refreshToken, accessToken); err != nil {
		t.Fatalf("Logout: %v", err)
	}

	if store.revokedToken != refreshToken {
		t.Errorf("refresh token revoked = %q, want %q", store.revokedToken, refreshToken)
	}
	if bl.addedJTI != wantJTI {
		t.Errorf("blacklisted jti = %q, want %q", bl.addedJTI, wantJTI)
	}
	if !bl.addedEXP.Equal(wantEXP) {
		t.Errorf("blacklisted exp = %v, want %v", bl.addedEXP, wantEXP)
	}
}

// TestLogout_NoAccessTokenSkipsBlacklist confirms backward compat: a caller
// that doesn't pass an access token still gets a working logout (refresh
// session revoked), and the blacklist is left untouched.
func TestLogout_NoAccessTokenSkipsBlacklist(t *testing.T) {
	ts := authjwt.NewTokenService("logout-test-secret-at-least-32-bytes", "yucai-server-test")
	store := &fakeSessionStore{}
	bl := &fakeBlacklist{}
	refreshHandler := command.NewRefreshHandler(store)
	svc := application.NewService(
		nil, nil, ts, store, bl, nil, nil, refreshHandler, nil, nil,
	)

	if err := svc.Logout(context.Background(), "rt", ""); err != nil {
		t.Fatalf("Logout: %v", err)
	}
	if store.revokedToken != "rt" {
		t.Errorf("refresh token revoked = %q, want %q", store.revokedToken, "rt")
	}
	if bl.addedJTI != "" {
		t.Errorf("blacklist should not be touched when accessToken is empty, got jti=%q", bl.addedJTI)
	}
}
