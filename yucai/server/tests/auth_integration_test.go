package tests

import (
	"context"
	"database/sql"
	"sync"
	"testing"
	"time"

	_ "modernc.org/sqlite"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"

	"github.com/yucai/server/internal/auth/adapter/driven/repository"
	"github.com/yucai/server/internal/auth/application"
	"github.com/yucai/server/internal/auth/application/command"
	"github.com/yucai/server/internal/auth/application/query"
	authdomain "github.com/yucai/server/internal/auth/domain"
	authent "github.com/yucai/server/internal/auth/ent"
	authjwt "github.com/yucai/server/internal/auth/infrastructure/jwt"
)

// memorySessionStore is an in-memory command.SessionStore for tests that don't
// have a Redis dependency. It implements Create/Rotate/Revoke with a simple
// map keyed by the refresh-token string. Sufficient for the register/login
// flow exercised here (Create is the only path hit; Rotate/Revoke are stubbed
// so the interface is satisfied).
type memorySessionStore struct {
	mu       sync.Mutex
	sessions map[string]struct{}
}

func newMemorySessionStore() *memorySessionStore {
	return &memorySessionStore{sessions: make(map[string]struct{})}
}

func (s *memorySessionStore) Create(_ context.Context, token, _, _, _ string, _ time.Duration) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.sessions[token] = struct{}{}
	return nil
}

func (s *memorySessionStore) Rotate(_ context.Context, oldToken, newToken string, _ time.Duration) (string, string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.sessions, oldToken)
	s.sessions[newToken] = struct{}{}
	return "", "", nil
}

func (s *memorySessionStore) Revoke(_ context.Context, token string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.sessions, token)
	return nil
}

// noopCurrencyChecker is a domain.CurrencyCodeChecker that always reports the
// code as known. The integration tests don't exercise UpdatePreferences, so a
// real catalog lookup is unnecessary.
type noopCurrencyChecker struct{}

func (noopCurrencyChecker) FindByCode(_ context.Context, _ string) (bool, error) {
	return true, nil
}

// setupTestDB creates an in-memory SQLite database with auth schema migrated.
func setupTestDB(t *testing.T) *authent.Client {
	t.Helper()
	db, err := sql.Open("sqlite", "file:ent?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	// Enable foreign keys explicitly
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}

	drv := entsql.OpenDB(dialect.SQLite, db)
	client := authent.NewClient(authent.Driver(drv))

	ctx := context.Background()
	if err := client.Schema.Create(ctx); err != nil {
		t.Fatalf("create schema: %v", err)
	}
	t.Cleanup(func() { client.Close() })
	return client
}

// setupTestService wires up the auth service with a real database.
func setupTestService(t *testing.T) *application.Service {
	t.Helper()
	client := setupTestDB(t)

	tenantRepo := repository.NewTenantRepository(client)
	userRepo := repository.NewUserRepository(client)
	tokenService := authjwt.NewTokenService("test-secret-key-at-least-32-chars-long")
	sessionStore := newMemorySessionStore()

	registerHandler := command.NewRegisterHandler(tenantRepo, userRepo, tokenService, nil)
	loginHandler := command.NewLoginHandler(userRepo, tokenService)
	refreshHandler := command.NewRefreshHandler(sessionStore)
	profileHandler := query.NewGetProfileHandler(userRepo)

	var currencyChecker authdomain.CurrencyCodeChecker = noopCurrencyChecker{}
	svc := application.NewService(tenantRepo, userRepo, tokenService, sessionStore, registerHandler, loginHandler, refreshHandler, profileHandler, currencyChecker)
	return svc
}

func TestRegisterLoginFlow(t *testing.T) {
	svc := setupTestService(t)
	ctx := context.Background()

	// Step 1: Register
	regResp, err := svc.Register(ctx, application.RegisterRequest{
		Email: "alice@example.com", Password: "securePassword123", DisplayName: "Alice",
	})
	if err != nil {
		t.Fatalf("Register failed: %v", err)
	}
	if regResp.AccessToken == "" {
		t.Error("expected access token")
	}
	if regResp.RefreshToken == "" {
		t.Error("expected refresh token")
	}
	if regResp.User.Email != "alice@example.com" {
		t.Errorf("expected alice@example.com, got %s", regResp.User.Email)
	}
	if regResp.User.TenantID.String() == "" {
		t.Error("expected non-empty tenant ID")
	}

	// Step 2: Login with correct password
	loginResp, err := svc.Login(ctx, application.LoginRequest{
		Email: "alice@example.com", Password: "securePassword123",
	})
	if err != nil {
		t.Fatalf("Login failed: %v", err)
	}
	if loginResp.AccessToken == "" {
		t.Error("expected access token from login")
	}
}

func TestDuplicateEmail(t *testing.T) {
	svc := setupTestService(t)
	ctx := context.Background()

	_, err := svc.Register(ctx, application.RegisterRequest{
		Email: "bob@example.com", Password: "pass1", DisplayName: "Bob",
	})
	if err != nil {
		t.Fatalf("first register failed: %v", err)
	}

	_, err = svc.Register(ctx, application.RegisterRequest{
		Email: "bob@example.com", Password: "pass2", DisplayName: "Bob2",
	})
	if err == nil {
		t.Error("expected error for duplicate email registration")
	}
}

func TestInvalidCredentials(t *testing.T) {
	svc := setupTestService(t)
	ctx := context.Background()

	_, err := svc.Register(ctx, application.RegisterRequest{
		Email: "charlie@example.com", Password: "correctPass", DisplayName: "Charlie",
	})
	if err != nil {
		t.Fatalf("register failed: %v", err)
	}

	_, err = svc.Login(ctx, application.LoginRequest{
		Email: "charlie@example.com", Password: "wrongPass",
	})
	if err == nil {
		t.Error("expected error for wrong password")
	}
}

func TestGetProfile(t *testing.T) {
	svc := setupTestService(t)
	ctx := context.Background()

	regResp, err := svc.Register(ctx, application.RegisterRequest{
		Email: "dave@example.com", Password: "pass123", DisplayName: "Dave",
	})
	if err != nil {
		t.Fatalf("register failed: %v", err)
	}

	profile, err := svc.GetProfile(ctx, regResp.User.ID, regResp.User.TenantID)
	if err != nil {
		t.Fatalf("GetProfile failed: %v", err)
	}
	if profile.Email != "dave@example.com" {
		t.Errorf("expected dave@example.com, got %s", profile.Email)
	}
}

func TestUpdateProfile(t *testing.T) {
	svc := setupTestService(t)
	ctx := context.Background()

	regResp, err := svc.Register(ctx, application.RegisterRequest{
		Email: "eve@example.com", Password: "pass123", DisplayName: "Eve",
	})
	if err != nil {
		t.Fatalf("register failed: %v", err)
	}

	updated, err := svc.UpdateProfile(ctx, application.UpdateProfileRequest{
		UserID: regResp.User.ID, TenantID: regResp.User.TenantID,
		DisplayName: "Eve Updated", AvatarURL: "https://avatar.url/eve.png",
	})
	if err != nil {
		t.Fatalf("UpdateProfile failed: %v", err)
	}
	if updated.DisplayName != "Eve Updated" {
		t.Errorf("expected Eve Updated, got %s", updated.DisplayName)
	}
	if updated.AvatarURL != "https://avatar.url/eve.png" {
		t.Errorf("expected avatar URL, got %s", updated.AvatarURL)
	}
}

func TestJWTTokenFromRegistration(t *testing.T) {
	svc := setupTestService(t)
	ctx := context.Background()

	regResp, err := svc.Register(ctx, application.RegisterRequest{
		Email: "jwt@example.com", Password: "pass", DisplayName: "JWT",
	})
	if err != nil {
		t.Fatalf("register failed: %v", err)
	}

	// Verify the access token contains correct user/tenant IDs
	ts := authjwt.NewTokenService("test-secret-key-at-least-32-chars-long")
	userID, tenantID, err := ts.ParseAccessToken(regResp.AccessToken)
	if err != nil {
		t.Fatalf("ParseAccessToken failed: %v", err)
	}
	if userID != regResp.User.ID {
		t.Errorf("userID mismatch: got %v, want %v", userID, regResp.User.ID)
	}
	if tenantID != regResp.User.TenantID {
		t.Errorf("tenantID mismatch: got %v, want %v", tenantID, regResp.User.TenantID)
	}
}
