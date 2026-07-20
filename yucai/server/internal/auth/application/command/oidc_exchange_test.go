package command_test

// This file exercises OIDCExchangeHandler.Exchange end-to-end against a mock
// IDP (real RSA-signed id_token, real OIDC discovery, real oauth2 code
// exchange) and enttest SQLite repos. Coverage:
//   - jit provisioning on first login (tenant + seed + user + identity)
//   - existing-identity short-circuit (no duplicate rows)
//   - unknown provider error
//   - lookup-error propagation (regression guard for the Task 5+6 fix that
//     keeps a transient FindByProviderSubject failure from creating a
//     duplicate tenant+user+identity)
//   - email_verified=false → user.Email stays empty (privacy guard)
//
// The mock IDP + Load-via-yaml helpers mirror the patterns established in
// internal/auth/infrastructure/oidc/verifier_test.go and
// internal/auth/adapter/driven/repository/identity_repo_test.go. They are
// duplicated here because verifier_test's mockIDP lives in package-local test
// scope (not a shared helper), and Load is the only exported way to build a
// populated *ProviderRegistry.

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"testing"
	"time"

	"github.com/coreos/go-oidc/v3/oidc"
	"github.com/coreos/go-oidc/v3/oidc/oidctest"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	_ "modernc.org/sqlite"

	entsql "entgo.io/ent/dialect/sql"

	"github.com/yucai/server/internal/auth/adapter/driven/repository"
	authcmd "github.com/yucai/server/internal/auth/application/command"
	"github.com/yucai/server/internal/auth/domain"
	authent "github.com/yucai/server/internal/auth/ent"
	yucaioidc "github.com/yucai/server/internal/auth/infrastructure/oidc"
)

// --- mock IDP (mirrors verifier_test.go's mockIDP; lives there in package- ---
// --- local scope, so we duplicate the minimal version here).              ---

type mockIDP struct {
	oidcSrv  *oidctest.Server
	priv     *rsa.PrivateKey
	keyID    string
	clientID string
	issuer   string
	// tokenClaims returns the JSON claims signed into each /token id_token.
	// Tests can swap this to mutate (or break) the claims for negative cases.
	tokenClaims func() string
	signAlg     string
	// receivedCodeVerifier captures the code_verifier form value from the
	// most recent /token hit; tests assert PKCE propagation.
	receivedCodeVerifier string
}

func (m *mockIDP) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path == "/token" {
		m.serveToken(w, r)
		return
	}
	// discovery + /keys delegated to oidctest.Server.
	m.oidcSrv.ServeHTTP(w, r)
}

func (m *mockIDP) serveToken(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		http.Error(w, "bad form", http.StatusBadRequest)
		return
	}
	m.receivedCodeVerifier = r.FormValue("code_verifier")
	raw := oidctest.SignIDToken(m.priv, m.keyID, m.signAlg, m.tokenClaims())
	resp := map[string]any{
		"access_token": "fake-access-token",
		"token_type":   "Bearer",
		"expires_in":   3600,
		"id_token":     raw,
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

type mockIDPConfig struct {
	subject       string
	email         string
	emailVerified bool
}

// newMockIDP stands up an httptest IDP that handles OIDC discovery + JWKS via
// oidctest.Server and serves a /token endpoint that returns a freshly signed
// id_token for any auth code. The returned httptest.Server's URL is the issuer
// to feed into yucaioidc.Load via a temp yaml.
func newMockIDP(t *testing.T, cfg mockIDPConfig) (*mockIDP, *httptest.Server) {
	t.Helper()
	priv, err := rsa.GenerateKey(rand.Reader, 2048)
	require.NoError(t, err, "generate rsa key")
	const keyID = "test-key-1"
	m := &mockIDP{
		priv:     priv,
		keyID:    keyID,
		signAlg:  oidc.RS256,
		clientID: "yucai-test-client",
	}
	m.oidcSrv = &oidctest.Server{
		PublicKeys: []oidctest.PublicKey{
			{PublicKey: priv.Public(), KeyID: keyID, Algorithm: oidc.RS256},
		},
	}
	srv := httptest.NewServer(m)
	t.Cleanup(srv.Close)
	m.oidcSrv.SetIssuer(srv.URL)
	m.issuer = srv.URL
	m.tokenClaims = func() string {
		return defaultClaims(m.issuer, m.clientID, cfg.subject, cfg.email, cfg.emailVerified)
	}
	return m, srv
}

func defaultClaims(iss, aud, sub, email string, emailVerified bool) string {
	return `{
		"iss": "` + iss + `",
		"aud": "` + aud + `",
		"sub": "` + sub + `",
		"exp": ` + strconv.FormatInt(time.Now().Add(time.Hour).Unix(), 10) + `,
		"iat": ` + strconv.FormatInt(time.Now().Unix(), 10) + `,
		"email": "` + email + `",
		"email_verified": ` + strconv.FormatBool(emailVerified) + `
	}`
}

// loadRegistry writes a minimal oidc_providers.yaml pointing one provider at
// the mock IDP, injects the per-name secret via env (mirrors production wire),
// and calls yucaioidc.Load. This is the only exported way to obtain a
// populated *ProviderRegistry.
func loadRegistry(t *testing.T, srv *httptest.Server, name, clientID string) *yucaioidc.ProviderRegistry {
	t.Helper()
	yaml := `providers:
  - name: ` + name + `
    display_name: ` + name + ` (mock)
    issuer: ` + srv.URL + `
    client_id: ` + clientID + `
    scopes: [openid, email, profile]
    redirect_uri: ` + srv.URL + `/callback
`
	dir := t.TempDir()
	path := filepath.Join(dir, "oidc_providers.yaml")
	require.NoError(t, os.WriteFile(path, []byte(yaml), 0600))

	// Convention: OIDC_<NAME_UPPER>_CLIENT_SECRET (locked by TestLoad in
	// verifier_test.go).
	t.Setenv("OIDC_"+envName(name)+"_CLIENT_SECRET", "test-secret")

	reg, err := yucaioidc.Load(context.Background(), path)
	require.NoError(t, err, "Load against mock IDP")
	return reg
}

// envName upper-cases name for the OIDC_<NAME>_CLIENT_SECRET env var. Matches
// the registry.Load convention.
func envName(name string) string {
	out := make([]byte, 0, len(name))
	for i := 0; i < len(name); i++ {
		c := name[i]
		if c >= 'a' && c <= 'z' {
			c -= 'a' - 'A'
		}
		out = append(out, c)
	}
	return string(out)
}

// --- enttest SQLite (mirrors identity_repo_test.go) ---

// setupAuthTestDB opens an in-memory SQLite DB and runs ent auto-migration
// for the auth schema.
func setupAuthTestDB(t *testing.T) *authent.Client {
	t.Helper()
	dbName := "auth_cmd_" + sanitizeAuth(t.Name())
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory")
	require.NoError(t, err, "open sqlite")
	t.Cleanup(func() { db.Close() })

	db.SetMaxOpenConns(1)
	_, err = db.Exec("PRAGMA foreign_keys = ON")
	require.NoError(t, err, "enable foreign keys")

	drv := entsql.OpenDB("sqlite3", db)
	client := authent.NewClient(authent.Driver(drv))
	require.NoError(t, client.Schema.Create(context.Background()), "migrate schema")
	t.Cleanup(func() { client.Close() })
	return client
}

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

// --- test doubles for the lookup-error propagation scenario ---

// failingUserRepo embeds domain.UserRepository so it still satisfies the
// interface, but overrides FindByProviderSubject to return a non-NotFound
// error. Only methods Exchange actually invokes can be safely called; other
// methods would panic on the nil embedded interface.
type failingUserRepo struct {
	domain.UserRepository
	lookupErr error
}

func (f *failingUserRepo) FindByProviderSubject(ctx context.Context, provider, subject string) (*domain.User, error) {
	return nil, f.lookupErr
}

// --- tests ---

// TestOIDCExchange_JitProvisioning verifies first-login flow: an unknown
// (provider, subject) triggers creation of tenant + user + identity, the
// PKCE code_verifier reaches the IDP, and the verified email is normalized
// (lowercased + trimmed) into the user row.
func TestOIDCExchange_JitProvisioning(t *testing.T) {
	client := setupAuthTestDB(t)
	ctx := context.Background()

	const (
		providerName = "testprov"
		clientID     = "yucai-test-client"
		subject      = "user-123"
		// Caps + whitespace exercised on purpose; production should normalize.
		email = "Alice.Name@Example.com"
	)
	m, srv := newMockIDP(t, mockIDPConfig{
		subject:       subject,
		email:         email,
		emailVerified: true,
	})
	reg := loadRegistry(t, srv, providerName, clientID)

	userRepo := repository.NewUserRepository(client)
	identityRepo := repository.NewIdentityRepository(client)
	tenantRepo := repository.NewTenantRepository(client)
	handler := authcmd.NewOIDCExchangeHandler(reg, userRepo, identityRepo, tenantRepo, nil)

	user, err := handler.Exchange(ctx, providerName, "any-code", "test-pkce-verifier", "")
	require.NoError(t, err)
	require.NotNil(t, user)

	// Regression guard: code_verifier must reach the IDP. If
	// Provider.Exchange ever drops the oauth2.SetAuthURLParam option, the
	// IDP receives an empty string and PKCE protection is silently lost.
	assert.Equal(t, "test-pkce-verifier", m.receivedCodeVerifier,
		"PKCE code_verifier must reach the IDP")

	// Verified email is normalized (lowercase + trim) into the user row.
	assert.Equal(t, "alice.name@example.com", user.Email,
		"verified email must be lowercased into user.Email")
	// Display name falls back to the email local-part.
	assert.Equal(t, "Alice.Name", user.DisplayName)

	// Identity row persisted: FindByProviderSubject now resolves to the new user.
	found, err := userRepo.FindByProviderSubject(ctx, providerName, subject)
	require.NoError(t, err)
	assert.Equal(t, user.ID, found.ID, "FindByProviderSubject must resolve to the provisioned user")

	// Jit created exactly one tenant + one user (no duplicates).
	userCount, err := client.User.Query().Count(ctx)
	require.NoError(t, err)
	assert.Equal(t, 1, userCount, "jit should provision exactly one user")
	tenantCount, err := client.Tenant.Query().Count(ctx)
	require.NoError(t, err)
	assert.Equal(t, 1, tenantCount, "jit should provision exactly one tenant")
	identityCount, err := client.UserIdentity.Query().Count(ctx)
	require.NoError(t, err)
	assert.Equal(t, 1, identityCount, "jit should provision exactly one identity")
}

// TestOIDCExchange_ExistingIdentity verifies that when an identity already
// exists for the (provider, subject) pair, Exchange returns the existing user
// without provisioning any new rows.
func TestOIDCExchange_ExistingIdentity(t *testing.T) {
	client := setupAuthTestDB(t)
	ctx := context.Background()

	tenantRepo := repository.NewTenantRepository(client)
	userRepo := repository.NewUserRepository(client)
	identityRepo := repository.NewIdentityRepository(client)

	// Pre-insert tenant + user + identity.
	tenant, err := domain.NewTenant("Pre-existing Tenant", domain.TenantTypePersonal)
	require.NoError(t, err)
	require.NoError(t, tenantRepo.Save(ctx, tenant))
	preUser, err := domain.NewUser(tenant.ID, "pre@exists.com", "PreExisting")
	require.NoError(t, err)
	require.NoError(t, userRepo.Save(ctx, preUser))
	preIdentity, err := domain.NewUserIdentity(tenant.ID, preUser.ID,
		"testprov", "sub-pre", "https://issuer.example.com", "pre@idp.com")
	require.NoError(t, err)
	require.NoError(t, identityRepo.Save(ctx, preIdentity))

	// Stand up mock IDP emitting the SAME subject as the pre-inserted identity.
	m, srv := newMockIDP(t, mockIDPConfig{
		subject:       "sub-pre",
		email:         "pre@idp.com",
		emailVerified: true,
	})
	reg := loadRegistry(t, srv, "testprov", "yucai-test-client")
	handler := authcmd.NewOIDCExchangeHandler(reg, userRepo, identityRepo, tenantRepo, nil)

	user, err := handler.Exchange(ctx, "testprov", "any-code", "verifier-pre", "")
	require.NoError(t, err)
	require.NotNil(t, user)

	// Same user returned — no duplicate row created.
	assert.Equal(t, preUser.ID, user.ID, "existing-identity path must return the same user")
	assert.Equal(t, preUser.Email, user.Email)
	assert.Equal(t, preUser.DisplayName, user.DisplayName)

	// Count unchanged: still one tenant / one user / one identity.
	userCount, err := client.User.Query().Count(ctx)
	require.NoError(t, err)
	assert.Equal(t, 1, userCount, "existing-identity path must not create a new user")
	tenantCount, err := client.Tenant.Query().Count(ctx)
	require.NoError(t, err)
	assert.Equal(t, 1, tenantCount, "existing-identity path must not create a new tenant")
	identityCount, err := client.UserIdentity.Query().Count(ctx)
	require.NoError(t, err)
	assert.Equal(t, 1, identityCount, "existing-identity path must not create a new identity")

	// PKCE regression guard holds on this path too.
	assert.Equal(t, "verifier-pre", m.receivedCodeVerifier)
}

// TestOIDCExchange_UnknownProvider verifies that Exchange rejects an unknown
// provider name with an "unknown provider" error before touching the network
// or provisioning any rows.
func TestOIDCExchange_UnknownProvider(t *testing.T) {
	client := setupAuthTestDB(t)
	ctx := context.Background()

	_, srv := newMockIDP(t, mockIDPConfig{
		subject: "x", email: "x@example.com", emailVerified: true,
	})
	reg := loadRegistry(t, srv, "testprov", "yucai-test-client")

	handler := authcmd.NewOIDCExchangeHandler(
		reg,
		repository.NewUserRepository(client),
		repository.NewIdentityRepository(client),
		repository.NewTenantRepository(client),
		nil,
	)

	_, err := handler.Exchange(ctx, "nobody", "any-code", "any-verifier", "")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "unknown provider")
	assert.Contains(t, err.Error(), "nobody")

	// Nothing provisioned (the error path must not have side effects).
	userCount, err := client.User.Query().Count(ctx)
	require.NoError(t, err)
	assert.Equal(t, 0, userCount, "unknown-provider path must not provision a user")
	tenantCount, err := client.Tenant.Query().Count(ctx)
	require.NoError(t, err)
	assert.Equal(t, 0, tenantCount, "unknown-provider path must not provision a tenant")
}

// TestOIDCExchange_LookupErrorPropagation is a regression guard for the Task
// 5+6 lookup-error fix: a transient (non-NotFound) error from
// FindByProviderSubject must propagate, and Exchange must NOT fall through to
// jit provisioning — otherwise a single connection blip during login would
// create a duplicate tenant+user+identity for the same (provider, subject).
func TestOIDCExchange_LookupErrorPropagation(t *testing.T) {
	client := setupAuthTestDB(t)
	ctx := context.Background()

	_, srv := newMockIDP(t, mockIDPConfig{
		subject: "user-123", email: "x@example.com", emailVerified: true,
	})
	reg := loadRegistry(t, srv, "testprov", "yucai-test-client")

	failingRepo := &failingUserRepo{
		UserRepository: repository.NewUserRepository(client),
		lookupErr:      errors.New("simulated connection failure"),
	}
	handler := authcmd.NewOIDCExchangeHandler(
		reg,
		failingRepo,
		repository.NewIdentityRepository(client),
		repository.NewTenantRepository(client),
		nil,
	)

	_, err := handler.Exchange(ctx, "testprov", "any-code", "any-verifier", "")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "lookup identity by provider subject")
	assert.Contains(t, err.Error(), "simulated connection failure")

	// Critical invariant: a transient lookup failure must not provision any
	// duplicate rows. This is exactly the bug the Task 5+6 fix prevents.
	userCount, err := client.User.Query().Count(ctx)
	require.NoError(t, err)
	assert.Equal(t, 0, userCount, "transient lookup failure must not create a duplicate user")
	tenantCount, err := client.Tenant.Query().Count(ctx)
	require.NoError(t, err)
	assert.Equal(t, 0, tenantCount, "transient lookup failure must not create a duplicate tenant")
	identityCount, err := client.UserIdentity.Query().Count(ctx)
	require.NoError(t, err)
	assert.Equal(t, 0, identityCount, "transient lookup failure must not create a duplicate identity")
}

// TestOIDCExchange_EmailUnverifiedNotFilled verifies the privacy guard: when
// the IDP has not verified the email claim, user.Email stays empty even though
// a non-empty email arrived in the id_token. (Display name still derives from
// the email local-part so the user is not stuck with the "User" fallback.)
func TestOIDCExchange_EmailUnverifiedNotFilled(t *testing.T) {
	client := setupAuthTestDB(t)
	ctx := context.Background()

	_, srv := newMockIDP(t, mockIDPConfig{
		subject:       "user-456",
		email:         "Unverified@Example.com",
		emailVerified: false,
	})
	reg := loadRegistry(t, srv, "testprov", "yucai-test-client")
	handler := authcmd.NewOIDCExchangeHandler(
		reg,
		repository.NewUserRepository(client),
		repository.NewIdentityRepository(client),
		repository.NewTenantRepository(client),
		nil,
	)

	user, err := handler.Exchange(ctx, "testprov", "any-code", "any-verifier", "")
	require.NoError(t, err)
	require.NotNil(t, user)

	assert.Equal(t, "", user.Email,
		"unverified email must not be copied into user.Email (privacy guard)")
	assert.Equal(t, "Unverified", user.DisplayName,
		"display name still derives from the email local-part")

	// The identity row, however, retains the email-at-provider for audit.
	id, err := repository.NewIdentityRepository(client).FindByProviderSubject(ctx, "testprov", "user-456")
	require.NoError(t, err)
	assert.Equal(t, "Unverified@Example.com", id.EmailAtProvider,
		"EmailAtProvider retains the raw claim regardless of email_verified")
}
