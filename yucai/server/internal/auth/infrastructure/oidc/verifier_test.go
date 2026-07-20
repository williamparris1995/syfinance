package oidc

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/coreos/go-oidc/v3/oidc"
	"github.com/coreos/go-oidc/v3/oidc/oidctest"
)

// mockIDP wraps oidctest.Server (which provides discovery + JWKS) and adds a
// /token endpoint that returns a freshly signed id_token for any auth code.
// This lets us exercise the full Exchange + VerifyIDToken path against a real
// go-oidc Provider rather than pre-signing and skipping the oauth2 round trip.
type mockIDP struct {
	oidcSrv  *oidctest.Server
	priv     *rsa.PrivateKey
	keyID    string
	clientID string
	issuer   string
	// tokenClaims, if non-nil, is called for each /token hit to build the
	// id_token claims; the default returns a valid subject/email. Tests set
	// this to mutate (or break) the claims for negative cases.
	tokenClaims func() string
	// signAlg lets a test override the algorithm advertised in discovery.
	signAlg string
	// receivedCodeVerifier captures the code_verifier form value from the
	// most recent /token request. Tests assert against this to prove PKCE
	// propagation survived the oauth2 Exchange path (regression guard against
	// accidentally dropping the option in Provider.Exchange).
	receivedCodeVerifier string
}

func (m *mockIDP) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path == "/token" {
		m.serveToken(w, r)
		return
	}
	// discovery + /keys delegated to oidctest.Server (which also handles
	// SetIssuer correctly).
	m.oidcSrv.ServeHTTP(w, r)
}

func (m *mockIDP) serveToken(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		http.Error(w, "bad form", http.StatusBadRequest)
		return
	}
	// Capture the PKCE code_verifier so tests can assert it reached the IDP
	// (regression guard against accidentally dropping the option in
	// Provider.Exchange).
	m.receivedCodeVerifier = r.FormValue("code_verifier")
	claims := m.tokenClaims()
	raw := oidctest.SignIDToken(m.priv, m.keyID, m.signAlg, claims)
	resp := map[string]any{
		"access_token": "fake-access-token",
		"token_type":   "Bearer",
		"expires_in":   3600,
		"id_token":     raw,
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

// newMockIDP stands up an httptest server with discovery + JWKS + token
// endpoint and returns it together with the discovered Provider. Tests use the
// returned *Provider to call Exchange + VerifyIDToken.
func newMockIDP(t *testing.T, clientID string) (*httptest.Server, *Provider, *mockIDP) {
	t.Helper()
	priv, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatalf("generate rsa key: %v", err)
	}
	const keyID = "test-key-1"
	m := &mockIDP{
		priv:     priv,
		keyID:    keyID,
		clientID: clientID,
		signAlg:  oidc.RS256,
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

	// Default claims: valid token for clientID with a 1h expiry.
	m.tokenClaims = func() string {
		return defaultClaims(m.issuer, m.clientID, "user-123", "user@example.com", true)
	}

	p, err := NewProvider(context.Background(), ProviderConfig{
		Name:         "mock",
		DisplayName:  "Mock IDP",
		Issuer:       srv.URL,
		ClientID:     clientID,
		ClientSecret: "test-secret",
		Scopes:       []string{"openid", "email", "profile"},
		RedirectURI:  srv.URL + "/callback",
	})
	if err != nil {
		t.Fatalf("NewProvider against mock IDP: %v", err)
	}
	return srv, p, m
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

func TestVerifyIDToken_FullExchangeFlow(t *testing.T) {
	const clientID = "yucai-test-client"
	_, p, m := newMockIDP(t, clientID)

	tok, err := p.Exchange(context.Background(),
		"fake-auth-code", "test-pkce-verifier", "")
	if err != nil {
		t.Fatalf("Exchange: %v", err)
	}
	// Regression guard: if Provider.Exchange ever drops the
	// oauth2.SetAuthURLParam("code_verifier", ...) option, the IDP receives
	// an empty code_verifier and PKCE protection is silently lost.
	if m.receivedCodeVerifier != "test-pkce-verifier" {
		t.Errorf("code_verifier at IDP = %q, want %q", m.receivedCodeVerifier, "test-pkce-verifier")
	}
	rawIDToken, ok := tok.Extra("id_token").(string)
	if !ok || rawIDToken == "" {
		t.Fatalf("Exchange result missing id_token; got %#v", tok)
	}

	res, err := p.VerifyIDToken(context.Background(), rawIDToken)
	if err != nil {
		t.Fatalf("VerifyIDToken: %v", err)
	}
	if res.Provider != "mock" {
		t.Errorf("Provider = %q, want %q", res.Provider, "mock")
	}
	if res.Subject != "user-123" {
		t.Errorf("Subject = %q, want %q", res.Subject, "user-123")
	}
	if res.Email != "user@example.com" {
		t.Errorf("Email = %q, want %q", res.Email, "user@example.com")
	}
	if !res.EmailVerified {
		t.Errorf("EmailVerified = false, want true")
	}
	if res.Issuer == "" {
		t.Errorf("Issuer is empty")
	}
}

func TestVerifyIDToken_RejectsTamperedSignature(t *testing.T) {
	const clientID = "yucai-test-client"
	_, p, m := newMockIDP(t, clientID)
	raw := oidctest.SignIDToken(m.priv, m.keyID, oidc.RS256,
		defaultClaims(m.issuer, clientID, "evil", "evil@example.com", true))

	parts := strings.Split(raw, ".")
	if len(parts) != 3 {
		t.Fatalf("expected 3 jwt parts, got %d", len(parts))
	}
	// Flip a character near the middle of the signature so the decoded
	// signature bytes differ (the last base64 char encodes only padding bits
	// for an RSA-2048 sig, so flipping that one would NOT change the decoded
	// value). Mangling the middle guarantees a real signature-byte change.
	sig := parts[2]
	if len(sig) < 4 {
		t.Fatalf("signature too short to tamper: %d", len(sig))
	}
	pos := len(sig) / 2
	flipped := sig[:pos] + string(flipChar(sig[pos])) + sig[pos+1:]
	tampered := parts[0] + "." + parts[1] + "." + flipped

	if _, err := p.VerifyIDToken(context.Background(), tampered); err == nil {
		t.Fatalf("VerifyIDToken accepted tampered signature; want error")
	}
}

func TestVerifyIDToken_RejectsWrongAudience(t *testing.T) {
	const clientID = "yucai-test-client"
	_, p, m := newMockIDP(t, clientID)
	// Sign a token for a different client_id: signature is valid against the
	// IDP JWKS but the aud check inside the verifier must reject it.
	raw := oidctest.SignIDToken(m.priv, m.keyID, oidc.RS256,
		defaultClaims(m.issuer, "some-other-client", "user-999", "x@example.com", true))

	_, err := p.VerifyIDToken(context.Background(), raw)
	if err == nil {
		t.Fatalf("VerifyIDToken accepted token with wrong aud; want error")
	}
}

func TestVerifyIDToken_RejectsWrongIssuer(t *testing.T) {
	const clientID = "yucai-test-client"
	_, p, m := newMockIDP(t, clientID)
	// Claims.iss does not match the discovery issuer; the verifier must reject.
	raw := oidctest.SignIDToken(m.priv, m.keyID, oidc.RS256,
		defaultClaims("https://attacker.example.com", clientID, "user-123", "x@example.com", true))

	_, err := p.VerifyIDToken(context.Background(), raw)
	if err == nil {
		t.Fatalf("VerifyIDToken accepted token with wrong iss; want error")
	}
}

func TestVerifyIDToken_RejectsExpiredToken(t *testing.T) {
	const clientID = "yucai-test-client"
	_, p, m := newMockIDP(t, clientID)
	raw := oidctest.SignIDToken(m.priv, m.keyID, oidc.RS256, `{
		"iss": "`+m.issuer+`",
		"aud": "`+clientID+`",
		"sub": "expired",
		"exp": `+strconv.FormatInt(time.Now().Add(-time.Hour).Unix(), 10)+`,
		"email": "old@example.com",
		"email_verified": false
	}`)

	_, err := p.VerifyIDToken(context.Background(), raw)
	if err == nil {
		t.Fatalf("VerifyIDToken accepted expired token; want error")
	}
}

func TestProviderRegistry_ListConfigs_StripsSecret(t *testing.T) {
	const clientID = "yucai-test-client"
	_, p, _ := newMockIDP(t, clientID)
	p.Config.ClientSecret = "super-secret"
	// Mirror what registry.Load does: discovery populates the auth endpoint
	// into the published config.
	p.Config.AuthorizationEndpoint = p.AuthorizationEndpoint()

	reg := &ProviderRegistry{
		providers: map[string]*Provider{"mock": p},
		configs:   []ProviderConfig{p.Config},
	}
	out := reg.ListConfigs()
	if len(out) != 1 {
		t.Fatalf("ListConfigs = %d items, want 1", len(out))
	}
	if out[0].ClientSecret != "" {
		t.Errorf("ListConfigs did not strip ClientSecret: got %q", out[0].ClientSecret)
	}
	if out[0].AuthorizationEndpoint == "" {
		t.Errorf("ListConfigs returned empty AuthorizationEndpoint")
	}
}

func TestProviderRegistry_Get(t *testing.T) {
	const clientID = "yucai-test-client"
	_, p, _ := newMockIDP(t, clientID)
	reg := &ProviderRegistry{
		providers: map[string]*Provider{"mock": p},
	}
	if got, ok := reg.Get("mock"); !ok || got != p {
		t.Errorf(`Get("mock") = (%p, %v), want (%p, true)`, got, ok, p)
	}
	if _, ok := reg.Get("nonexistent"); ok {
		t.Errorf(`Get("nonexistent") returned ok=true, want false`)
	}
}

// TestLoad exercises registry.Load end-to-end: yaml parse,
// OIDC_<NAME_UPPER>_CLIENT_SECRET env injection, discovery loop, and
// AuthorizationEndpoint writeback into both Provider.Config and ListConfigs.
// Locks the env-name convention so a future rename silently breaks the test
// instead of breaking production at runtime.
func TestLoad(t *testing.T) {
	const clientID = "yucai-test-client"
	srv, _, _ := newMockIDP(t, clientID)

	// Minimal yaml pointing at the mock IDP. Provider name "testprov" maps to
	// env var OIDC_TESTPROV_CLIENT_SECRET (convention: OIDC_<UPPER>_CLIENT_SECRET).
	yamlContent := `providers:
  - name: testprov
    display_name: Test Provider
    issuer: ` + srv.URL + `
    client_id: ` + clientID + `
    scopes: [openid, email, profile]
    redirect_uri: ` + srv.URL + `/callback
`
	dir := t.TempDir()
	yamlPath := filepath.Join(dir, "oidc_providers.yaml")
	if err := os.WriteFile(yamlPath, []byte(yamlContent), 0600); err != nil {
		t.Fatalf("write yaml: %v", err)
	}

	t.Setenv("OIDC_TESTPROV_CLIENT_SECRET", "super-secret")

	reg, err := Load(context.Background(), yamlPath)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}

	p, ok := reg.Get("testprov")
	if !ok {
		t.Fatalf(`Get("testprov") returned ok=false, want true`)
	}
	// Minor 2 fix: NewProvider must writeback the discovered endpoint into
	// Provider.Config so Task 6 handlers can read it directly without
	// mirroring the registry.Load writeback.
	if p.Config.AuthorizationEndpoint == "" {
		t.Errorf(`Get("testprov").Config.AuthorizationEndpoint is empty; want discovery to populate`)
	}
	if p.Config.ClientSecret != "super-secret" {
		t.Errorf("Provider.Config.ClientSecret = %q, want %q (env-injected at Load)", p.Config.ClientSecret, "super-secret")
	}

	configs := reg.ListConfigs()
	if len(configs) != 1 {
		t.Fatalf("ListConfigs = %d items, want 1", len(configs))
	}
	if configs[0].Name != "testprov" {
		t.Errorf("ListConfigs[0].Name = %q, want %q", configs[0].Name, "testprov")
	}
	if configs[0].ClientSecret != "" {
		t.Errorf("ListConfigs did not strip ClientSecret: got %q", configs[0].ClientSecret)
	}
	if configs[0].AuthorizationEndpoint == "" {
		t.Errorf("ListConfigs returned empty AuthorizationEndpoint")
	}
}

// flipChar mangles a base64url character to guarantee a different signature
// byte without producing an invalid character set.
func flipChar(b byte) byte {
	switch {
	case b == 'A':
		return 'B'
	case b >= 'a' && b < 'z':
		return b + 1
	case b >= 'A' && b < 'Z':
		return b + 1
	case b >= '0' && b < '9':
		return b + 1
	default:
		return 'A'
	}
}
