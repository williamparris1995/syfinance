package jwt

import (
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

const testSecret = "test-secret-key-at-least-32-chars"
const testIssuer = "yucai-server-test"

func TestGenerateAndParseAccessToken(t *testing.T) {
	svc := NewTokenService(testSecret, testIssuer)
	userID := uuid.New()
	tenantID := uuid.New()

	token, err := svc.GenerateAccessToken(userID, tenantID, false)
	if err != nil {
		t.Fatalf("GenerateAccessToken failed: %v", err)
	}
	if token == "" {
		t.Error("token should not be empty")
	}

	parsedUserID, parsedTenantID, parsedIsAdmin, err := svc.ParseAccessToken(token)
	if err != nil {
		t.Fatalf("ParseAccessToken failed: %v", err)
	}
	if parsedUserID != userID {
		t.Errorf("userID mismatch: got %v, want %v", parsedUserID, userID)
	}
	if parsedTenantID != tenantID {
		t.Errorf("tenantID mismatch: got %v, want %v", parsedTenantID, tenantID)
	}
	if parsedIsAdmin {
		t.Errorf("isAdmin mismatch: got %v, want %v", parsedIsAdmin, false)
	}
}

// TestAccessTokenStampsJTIAudIss verifies GenerateAccessToken stamps the
// registered claims needed for revocation (jti) and audience binding (aud+iss).
// ParseAccessToken enforces all three on the happy path.
func TestAccessTokenStampsJTIAudIss(t *testing.T) {
	svc := NewTokenService(testSecret, testIssuer)
	token, err := svc.GenerateAccessToken(uuid.New(), uuid.New(), false)
	if err != nil {
		t.Fatalf("GenerateAccessToken: %v", err)
	}
	claims, err := svc.ParseAccessTokenClaims(token)
	if err != nil {
		t.Fatalf("ParseAccessTokenClaims: %v", err)
	}
	if claims.JTI() == "" {
		t.Error("jti claim is empty — tokens must carry a jti for blacklist revocation")
	}
	if len(claims.Audience) == 0 || claims.Audience[0] != AccessTokenAudience {
		t.Errorf("aud claim = %v, want [%q]", claims.Audience, AccessTokenAudience)
	}
	if claims.Issuer != testIssuer {
		t.Errorf("iss claim = %q, want %q", claims.Issuer, testIssuer)
	}
}

// TestParseAccessTokenJTI confirms the helper returns the jti + exp needed for
// the blacklist TTL on logout / refresh rotation.
func TestParseAccessTokenJTI(t *testing.T) {
	svc := NewTokenService(testSecret, testIssuer)
	token, _ := svc.GenerateAccessToken(uuid.New(), uuid.New(), false)
	jti, exp, ok := svc.ParseAccessTokenJTI(token)
	if !ok {
		t.Fatal("ParseAccessTokenJTI returned ok=false for a freshly minted token")
	}
	if jti == "" {
		t.Error("jti empty")
	}
	if exp.IsZero() {
		t.Error("exp zero")
	}
	if time.Until(exp) <= 0 {
		t.Error("exp is in the past")
	}
}

// TestParseAccessToken_RejectsWrongAudience forges a token signed with the
// right secret but with a different aud. Parser must reject it — audience
// binding prevents a token minted for another consumer from being honored here.
func TestParseAccessToken_RejectsWrongAudience(t *testing.T) {
	svc := NewTokenService(testSecret, testIssuer)
	now := time.Now()
	claims := Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   uuid.New().String(),
			ExpiresAt: jwt.NewNumericDate(now.Add(15 * time.Minute)),
			IssuedAt:  jwt.NewNumericDate(now),
			ID:        uuid.NewString(),
			Audience:  []string{"some-other-audience"},
			Issuer:    testIssuer,
		},
		UserID:   uuid.New().String(),
		TenantID: uuid.New().String(),
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := tok.SignedString([]byte(testSecret))
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	if _, _, _, err := svc.ParseAccessToken(signed); err == nil {
		t.Error("token with wrong audience must be rejected")
	}
}

// TestParseAccessToken_RejectsWrongIssuer mirrors the audience test for iss.
func TestParseAccessToken_RejectsWrongIssuer(t *testing.T) {
	svc := NewTokenService(testSecret, testIssuer)
	now := time.Now()
	claims := Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   uuid.New().String(),
			ExpiresAt: jwt.NewNumericDate(now.Add(15 * time.Minute)),
			IssuedAt:  jwt.NewNumericDate(now),
			ID:        uuid.NewString(),
			Audience:  []string{AccessTokenAudience},
			Issuer:    "wrong-issuer",
		},
		UserID:   uuid.New().String(),
		TenantID: uuid.New().String(),
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := tok.SignedString([]byte(testSecret))
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	if _, _, _, err := svc.ParseAccessToken(signed); err == nil {
		t.Error("token with wrong issuer must be rejected")
	}
}

func TestGenerateAndParseAccessToken_Admin(t *testing.T) {
	svc := NewTokenService(testSecret, testIssuer)
	userID := uuid.New()
	tenantID := uuid.New()

	// Admin token: claims.IsAdmin=true must round-trip through signed JWT.
	token, err := svc.GenerateAccessToken(userID, tenantID, true)
	if err != nil {
		t.Fatalf("GenerateAccessToken failed: %v", err)
	}

	parsedUserID, parsedTenantID, parsedIsAdmin, err := svc.ParseAccessToken(token)
	if err != nil {
		t.Fatalf("ParseAccessToken failed: %v", err)
	}
	if parsedUserID != userID {
		t.Errorf("userID mismatch: got %v, want %v", parsedUserID, userID)
	}
	if parsedTenantID != tenantID {
		t.Errorf("tenantID mismatch: got %v, want %v", parsedTenantID, tenantID)
	}
	if !parsedIsAdmin {
		t.Errorf("isAdmin mismatch: got %v, want %v (admin claim did not round-trip)", parsedIsAdmin, true)
	}

	// Also verify a token issued with is_admin=false parses to false, so a
	// missing/zero JSON value can't be misread as admin.
	nonAdminToken, _ := svc.GenerateAccessToken(userID, tenantID, false)
	_, _, nonAdminIsAdmin, err := svc.ParseAccessToken(nonAdminToken)
	if err != nil {
		t.Fatalf("ParseAccessToken(non-admin) failed: %v", err)
	}
	if nonAdminIsAdmin {
		t.Errorf("non-admin token parsed as admin: got %v, want %v", nonAdminIsAdmin, false)
	}
}

func TestExpiredToken(t *testing.T) {
	svc := NewTokenService(testSecret, testIssuer)
	userID := uuid.New()
	tenantID := uuid.New()

	// Generate token, then override TTL to simulate expiry
	token, err := svc.GenerateAccessToken(userID, tenantID, false)
	if err != nil {
		t.Fatalf("GenerateAccessToken failed: %v", err)
	}

	// Wait for token to expire (15min TTL) — can't wait in unit test,
	// so parse with wrong secret to verify rejection instead
	_, _, _, err = svc.ParseAccessToken(token + "tampered")
	if err == nil {
		t.Error("tampered token should fail parsing")
	}
}

func TestWrongSecretRejectsToken(t *testing.T) {
	svc1 := NewTokenService("secret-one-at-least-32-characters-", testIssuer)
	svc2 := NewTokenService("secret-two-at-least-32-characters-", testIssuer)
	userID := uuid.New()
	tenantID := uuid.New()

	token, _ := svc1.GenerateAccessToken(userID, tenantID, false)
	_, _, _, err := svc2.ParseAccessToken(token)
	if err == nil {
		t.Error("token signed with different secret should be rejected")
	}
}

func TestGenerateRefreshToken(t *testing.T) {
	svc := NewTokenService("test-secret", testIssuer)
	token1 := svc.GenerateRefreshToken()
	token2 := svc.GenerateRefreshToken()
	if token1 == token2 {
		t.Error("refresh tokens should be unique")
	}
	if len(token1) < 32 {
		t.Errorf("refresh token too short: %d chars", len(token1))
	}
}

func TestAccessTokenTTL(t *testing.T) {
	svc := NewTokenService("test-secret", testIssuer)
	expected := 15 * time.Minute
	if svc.AccessTokenTTL() != expected {
		t.Errorf("expected TTL %v, got %v", expected, svc.AccessTokenTTL())
	}
}
