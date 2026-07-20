package repository_test

import (
	"context"
	"database/sql"
	"testing"

	entsql "entgo.io/ent/dialect/sql"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	_ "modernc.org/sqlite"

	authent "github.com/yucai/server/internal/auth/ent"
	"github.com/yucai/server/internal/auth/adapter/driven/repository"
	"github.com/yucai/server/internal/auth/domain"
)

// setupAuthTestDB opens an in-memory SQLite database and runs ent auto-migration
// for the auth schema. Mirrors the debt test-db helper (file:<name>?mode=memory,
// MaxOpenConn(1) keeps the in-memory DB shared across the same connection).
func setupAuthTestDB(t *testing.T) *authent.Client {
	t.Helper()
	dbName := "auth_ent_" + sanitizeAuth(t.Name())
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	db.SetMaxOpenConns(1)
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}

	drv := entsql.OpenDB("sqlite3", db)
	client := authent.NewClient(authent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate schema: %v", err)
	}
	t.Cleanup(func() { client.Close() })
	return client
}

// sanitizeAuth strips characters illegal in sqlite file names from a test name.
func sanitizeAuth(s string) string {
	out := make([]byte, 0, len(s))
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c == '/' || c == '\\' || c == ' ' || c == ':' {
			out = append(out, '_')
			continue
		}
		out = append(out, c)
	}
	return string(out)
}

// createUserRow is a test helper that saves a fresh domain.User via the
// UserRepository so identity FK constraints are satisfied.
func createUserRow(t *testing.T, repo *repository.UserRepository, tenantID uuid.UUID) *domain.User {
	t.Helper()
	u, err := domain.NewUser(tenantID, "u@example.com", "Alice")
	require.NoError(t, err)
	require.NoError(t, repo.Save(context.Background(), u))
	return u
}

// TestIdentityRepository_SaveAndFind verifies the round trip: an identity
// saved with (provider, subject) is retrievable by that same key, with all
// metadata fields (issuer, email_at_provider, tenant/user ID) preserved.
func TestIdentityRepository_SaveAndFind(t *testing.T) {
	client := setupAuthTestDB(t)
	ctx := context.Background()
	tenantID := uuid.New()

	userRepo := repository.NewUserRepository(client)
	u := createUserRow(t, userRepo, tenantID)

	repo := repository.NewIdentityRepository(client)
	id, err := domain.NewUserIdentity(
		tenantID, u.ID,
		"google", "sub-123",
		"https://accounts.google.com",
		"u@example.com",
	)
	require.NoError(t, err)

	require.NoError(t, repo.Save(ctx, id))

	got, err := repo.FindByProviderSubject(ctx, "google", "sub-123")
	require.NoError(t, err)
	assert.Equal(t, id.ID, got.ID)
	assert.Equal(t, tenantID, got.TenantID)
	assert.Equal(t, u.ID, got.UserID)
	assert.Equal(t, "google", got.Provider)
	assert.Equal(t, "sub-123", got.Subject)
	assert.Equal(t, "https://accounts.google.com", got.Issuer)
	assert.Equal(t, "u@example.com", got.EmailAtProvider)
}

// TestIdentityRepository_FindNotFound verifies that a miss returns a non-nil
// error (callers wrap ent NotFound to drive the jit-provisioning path).
func TestIdentityRepository_FindNotFound(t *testing.T) {
	client := setupAuthTestDB(t)
	ctx := context.Background()

	repo := repository.NewIdentityRepository(client)
	_, err := repo.FindByProviderSubject(ctx, "google", "never-exists")
	require.Error(t, err)
}

// TestIdentityRepository_FindByProviderSubject_UserLookup verifies the
// cross-repo path: a user attached to a saved identity is findable via
// UserRepository.FindByProviderSubject — i.e. the two repos share the same
// FK (user_id) and the (provider, subject) unique pair resolves to one user.
func TestIdentityRepository_FindByProviderSubject_UserLookup(t *testing.T) {
	client := setupAuthTestDB(t)
	ctx := context.Background()
	tenantID := uuid.New()

	userRepo := repository.NewUserRepository(client)
	u := createUserRow(t, userRepo, tenantID)

	idRepo := repository.NewIdentityRepository(client)
	id, err := domain.NewUserIdentity(tenantID, u.ID, "github", "gh-456", "", "")
	require.NoError(t, err)
	require.NoError(t, idRepo.Save(ctx, id))

	gotUser, err := userRepo.FindByProviderSubject(ctx, "github", "gh-456")
	require.NoError(t, err)
	assert.Equal(t, u.ID, gotUser.ID)
	assert.Equal(t, "Alice", gotUser.DisplayName)
}
