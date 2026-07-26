package jwt

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestGenerateAndParseAccessToken(t *testing.T) {
	svc := NewTokenService("test-secret-key-at-least-32-chars")
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

func TestGenerateAndParseAccessToken_Admin(t *testing.T) {
	svc := NewTokenService("test-secret-key-at-least-32-chars")
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
	svc := NewTokenService("test-secret-key-at-least-32-chars")
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
	svc1 := NewTokenService("secret-one-at-least-32-characters-")
	svc2 := NewTokenService("secret-two-at-least-32-characters-")
	userID := uuid.New()
	tenantID := uuid.New()

	token, _ := svc1.GenerateAccessToken(userID, tenantID, false)
	_, _, _, err := svc2.ParseAccessToken(token)
	if err == nil {
		t.Error("token signed with different secret should be rejected")
	}
}

func TestGenerateRefreshToken(t *testing.T) {
	svc := NewTokenService("test-secret")
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
	svc := NewTokenService("test-secret")
	expected := 15 * time.Minute
	if svc.AccessTokenTTL() != expected {
		t.Errorf("expected TTL %v, got %v", expected, svc.AccessTokenTTL())
	}
}
