package middleware

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	"github.com/yucai/server/internal/auth/application/command"
	authjwt "github.com/yucai/server/internal/auth/infrastructure/jwt"
)

const (
	mwTestSecret = "middleware-test-secret-at-least-32-bytes"
	mwTestIssuer = "yucai-server-test"
)

// mdWithBearer builds incoming gRPC metadata carrying a Bearer token.
func mdWithBearer(token string) metadata.MD {
	return metadata.Pairs("authorization", "Bearer "+token)
}

// fakeBlacklist is an in-memory command.TokenBlacklist for unit tests. It
// records Add calls and lets the test mark specific jtis as revoked, optionally
// return an error from IsBlacklisted to exercise the fail-closed path.
type fakeBlacklist struct {
	revoked  map[string]time.Time
	checkErr error
}

func newFakeBlacklist() *fakeBlacklist {
	return &fakeBlacklist{revoked: map[string]time.Time{}}
}

func (f *fakeBlacklist) Add(_ context.Context, jti string, exp time.Time) error {
	f.revoked[jti] = exp
	return nil
}

func (f *fakeBlacklist) IsBlacklisted(_ context.Context, jti string) (bool, error) {
	if f.checkErr != nil {
		return false, f.checkErr
	}
	_, ok := f.revoked[jti]
	return ok, nil
}

// setupMW installs a TokenService + (optional) blacklist as the package-level
// vars read by AuthInterceptor, restoring the previous values on cleanup. The
// interceptor chain runs against these globals, so tests must pin them.
func setupMW(t *testing.T, bl command.TokenBlacklist) *authjwt.TokenService {
	t.Helper()
	ts := authjwt.NewTokenService(mwTestSecret, mwTestIssuer)
	prevTS := TokenService
	prevBL := TokenBlacklist
	TokenService = ts
	TokenBlacklist = bl
	t.Cleanup(func() {
		TokenService = prevTS
		TokenBlacklist = prevBL
	})
	return ts
}

// TestAuthInterceptor_AcceptsValidToken confirms the happy path: a freshly
// minted token with no blacklist entry reaches the handler.
func TestAuthInterceptor_AcceptsValidToken(t *testing.T) {
	ts := setupMW(t, newFakeBlacklist())
	uid, tid := uuid.New(), uuid.New()
	tok, err := ts.GenerateAccessToken(uid, tid, false)
	if err != nil {
		t.Fatalf("generate: %v", err)
	}
	ctx := metadata.NewIncomingContext(context.Background(), mdWithBearer(tok))
	info := &grpc.UnaryServerInfo{FullMethod: "/yucai.holding.v1.HoldingService/GetHolding"}

	invoked := false
	resp, err := AuthInterceptor(ctx, nil, info, func(ctx context.Context, _ any) (any, error) {
		invoked = true
		return "ok", nil
	})
	if err != nil {
		t.Fatalf("AuthInterceptor rejected valid token: %v", err)
	}
	if !invoked {
		t.Error("handler was not invoked")
	}
	if resp != "ok" {
		t.Errorf("resp = %v, want ok", resp)
	}
}

// TestAuthInterceptor_RejectsBlacklistedToken verifies that a token whose jti
// is in the blacklist is rejected as Unauthenticated — the core revocation
// guarantee (logout / refresh rotation closes the 15min TTL window).
func TestAuthInterceptor_RejectsBlacklistedToken(t *testing.T) {
	bl := newFakeBlacklist()
	ts := setupMW(t, bl)
	uid, tid := uuid.New(), uuid.New()
	tok, _ := ts.GenerateAccessToken(uid, tid, false)

	// Extract the jti and pre-revoke it, simulating a logout that just happened.
	jti, exp, ok := ts.ParseAccessTokenJTI(tok)
	if !ok {
		t.Fatalf("ParseAccessTokenJTI returned ok=false")
	}
	if err := bl.Add(context.Background(), jti, exp); err != nil {
		t.Fatalf("Add: %v", err)
	}

	ctx := metadata.NewIncomingContext(context.Background(), mdWithBearer(tok))
	info := &grpc.UnaryServerInfo{FullMethod: "/yucai.holding.v1.HoldingService/GetHolding"}

	invoked := false
	_, err := AuthInterceptor(ctx, nil, info, func(context.Context, any) (any, error) {
		invoked = true
		return nil, nil
	})
	if invoked {
		t.Error("handler should NOT be invoked for a blacklisted token")
	}
	if status.Code(err) != codes.Unauthenticated {
		t.Errorf("error code = %v, want %v", status.Code(err), codes.Unauthenticated)
	}
	if !strings.Contains(err.Error(), "revoked") {
		t.Errorf("error should mention revocation, got: %v", err)
	}
}

// TestAuthInterceptor_BlacklistLookupErrorFailsClosed verifies that a broken
// Redis (simulated via fakeBlacklist.checkErr) doesn't silently un-revoke a
// token. The interceptor must surface an error rather than let the call through.
func TestAuthInterceptor_BlacklistLookupErrorFailsClosed(t *testing.T) {
	bl := newFakeBlacklist()
	bl.checkErr = errors.New("redis is down")
	ts := setupMW(t, bl)
	uid, tid := uuid.New(), uuid.New()
	tok, _ := ts.GenerateAccessToken(uid, tid, false)

	ctx := metadata.NewIncomingContext(context.Background(), mdWithBearer(tok))
	info := &grpc.UnaryServerInfo{FullMethod: "/yucai.holding.v1.HoldingService/GetHolding"}

	invoked := false
	_, err := AuthInterceptor(ctx, nil, info, func(context.Context, any) (any, error) {
		invoked = true
		return nil, nil
	})
	if invoked {
		t.Error("handler should NOT be invoked when blacklist lookup errors")
	}
	// Fail-closed surfaces as Unavailable (not Unauthenticated) so monitoring
	// can tell "revoked" apart from "redis down".
	if status.Code(err) != codes.Unavailable {
		t.Errorf("error code = %v, want %v", status.Code(err), codes.Unavailable)
	}
}

// TestAuthInterceptor_SkipsBlacklistWhenNil confirms the pre-T02 behavior is
// preserved for tests/callers that don't wire a blacklist: nil means skip the
// check entirely.
func TestAuthInterceptor_SkipsBlacklistWhenNil(t *testing.T) {
	ts := setupMW(t, nil) // nil blacklist
	uid, tid := uuid.New(), uuid.New()
	tok, _ := ts.GenerateAccessToken(uid, tid, false)

	ctx := metadata.NewIncomingContext(context.Background(), mdWithBearer(tok))
	info := &grpc.UnaryServerInfo{FullMethod: "/yucai.holding.v1.HoldingService/GetHolding"}

	invoked := false
	_, err := AuthInterceptor(ctx, nil, info, func(context.Context, any) (any, error) {
		invoked = true
		return nil, nil
	})
	if err != nil {
		t.Fatalf("nil blacklist should not cause rejection: %v", err)
	}
	if !invoked {
		t.Error("handler was not invoked")
	}
}

// TestAuthInterceptor_RejectsWrongAudience confirms the parser enforces aud at
// the interceptor boundary — a token forged for a different consumer must not
// pass even if its signature verifies.
func TestAuthInterceptor_RejectsWrongAudience(t *testing.T) {
	setupMW(t, nil)
	uid, tid := uuid.New(), uuid.New()
	// Forge a token signed with the right secret but stamped for a different
	// audience — simulates a token leak from another service that shares the
	// HMAC key but shouldn't be honored here.
	tok := forgeWithAudience(t, uid, tid, "some-other-audience")

	ctx := metadata.NewIncomingContext(context.Background(), mdWithBearer(tok))
	info := &grpc.UnaryServerInfo{FullMethod: "/yucai.holding.v1.HoldingService/GetHolding"}
	_, err := AuthInterceptor(ctx, nil, info, func(context.Context, any) (any, error) {
		t.Fatal("handler should not be invoked for wrong-audience token")
		return nil, nil
	})
	if status.Code(err) != codes.Unauthenticated {
		t.Errorf("error code = %v, want %v", status.Code(err), codes.Unauthenticated)
	}
}

// forgeWithAudience builds a signed JWT with the test secret but a custom aud.
// Used to verify the Parser's audience check rejects tokens minted for another
// consumer.
func forgeWithAudience(t *testing.T, uid, tid uuid.UUID, aud string) string {
	t.Helper()
	now := time.Now()
	claims := authjwt.Claims{
		UserID:   uid.String(),
		TenantID: tid.String(),
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(now.Add(15 * time.Minute)),
			IssuedAt:  jwt.NewNumericDate(now),
			ID:        uuid.NewString(),
			Audience:  []string{aud},
			Issuer:    mwTestIssuer,
		},
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := tok.SignedString([]byte(mwTestSecret))
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	return signed
}
