package jwt

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

// AccessTokenAudience is the aud stamped on every御财 access token. Tokens
// minted for any other audience (e.g. a third-party IDP's own resource server)
// are rejected by ParseAccessToken.
const AccessTokenAudience = "yucai"

// TokenService handles JWT token generation and parsing.
type TokenService struct {
	secretKey        string
	issuer           string // stamped on iss claim; enforced by Parser
	accessTokenTTL   time.Duration
	refreshTokenTTL  time.Duration
}

// NewTokenService creates a new TokenService with the given secret key and issuer.
// The secret must be ≥32 bytes (enforced upstream in config.Load); the issuer is
// stamped on every access token's iss claim and enforced on parse, so a token
// minted for a different issuer is rejected even if its signature verifies.
func NewTokenService(secretKey, issuer string) *TokenService {
	return &TokenService{
		secretKey:       secretKey,
		issuer:          issuer,
		accessTokenTTL:  15 * time.Minute,
		refreshTokenTTL: 7 * 24 * time.Hour,
	}
}

// Issuer returns the configured iss claim value.
func (s *TokenService) Issuer() string { return s.issuer }

// Claims represents the JWT payload for access tokens.
type Claims struct {
	jwt.RegisteredClaims
	UserID   string `json:"user_id"`
	TenantID string `json:"tenant_id"`
	IsAdmin  bool   `json:"is_admin"`
}

// JTI returns the JWT ID (jti claim), used for access-token revocation via the
// Redis blacklist. Empty when the token was forged without one (e.g. a legacy
// pre-T02 token), in which case the blacklist is not consulted for it.
func (c *Claims) JTI() string {
	if c == nil {
		return ""
	}
	return c.ID
}

// GenerateAccessToken creates a signed JWT access token for the given user.
// isAdmin is the platform-admin flag (authorizes securities write RPCs).
//
// Registered claims stamped for revocation + audience-binding:
//   - jti (ID): random UUID — added to Redis blacklist on logout / refresh rotation
//     so the token can be revoked before its 15min TTL elapses.
//   - aud: "yucai" — Parser rejects tokens minted for any other audience.
//   - iss: configured issuer — Parser rejects tokens minted by a different issuer.
func (s *TokenService) GenerateAccessToken(userID, tenantID uuid.UUID, isAdmin bool) (string, error) {
	now := time.Now()
	claims := Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID.String(),
			ExpiresAt: jwt.NewNumericDate(now.Add(s.accessTokenTTL)),
			IssuedAt:  jwt.NewNumericDate(now),
			ID:        uuid.NewString(),
			Audience:  []string{AccessTokenAudience},
			Issuer:    s.issuer,
		},
		UserID:   userID.String(),
		TenantID: tenantID.String(),
		IsAdmin:  isAdmin,
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(s.secretKey))
}

// ParseAccessTokenClaims validates signature, expiry, audience, and issuer, then
// returns the full Claims. Callers that need jti (e.g. AuthInterceptor consulting
// the blacklist) use this; callers that only need identity can use ParseAccessToken.
func (s *TokenService) ParseAccessTokenClaims(tokenStr string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return []byte(s.secretKey), nil
	},
		jwt.WithAudience(AccessTokenAudience),
		jwt.WithIssuer(s.issuer),
	)
	if err != nil {
		return nil, fmt.Errorf("parse token: %w", err)
	}
	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, fmt.Errorf("invalid token claims")
	}
	return claims, nil
}

// ParseAccessToken validates and extracts claims from an access token. Returns
// userID, tenantID, and the platform-admin flag. Signature, expiry, audience,
// and issuer are all enforced; jti is not exposed here — use ParseAccessTokenClaims
// when you need it (e.g. for blacklist lookup).
func (s *TokenService) ParseAccessToken(tokenStr string) (userID, tenantID uuid.UUID, isAdmin bool, err error) {
	claims, err := s.ParseAccessTokenClaims(tokenStr)
	if err != nil {
		return uuid.Nil, uuid.Nil, false, err
	}
	userID, err = uuid.Parse(claims.UserID)
	if err != nil {
		return uuid.Nil, uuid.Nil, false, fmt.Errorf("parse user_id: %w", err)
	}
	tenantID, err = uuid.Parse(claims.TenantID)
	if err != nil {
		return uuid.Nil, uuid.Nil, false, fmt.Errorf("parse tenant_id: %w", err)
	}
	return userID, tenantID, claims.IsAdmin, nil
}

// ParseAccessTokenJTI extracts the jti and ExpiresAt from an access token
// WITHOUT enforcing aud/iss/expiry. It's used by revocation triggers (logout,
// refresh rotation) that receive an access token they already know was valid
// (it authenticated the caller moments ago) and just need its identity + exp
// to compute the blacklist TTL. Returns ok=false on any parse failure — the
// caller treats that as "no jti to blacklist" and moves on, so a malformed
// token on the logout path doesn't fail the refresh-token revocation.
func (s *TokenService) ParseAccessTokenJTI(tokenStr string) (jti string, exp time.Time, ok bool) {
	claims, err := s.ParseAccessTokenClaims(tokenStr)
	if err != nil || claims == nil {
		return "", time.Time{}, false
	}
	if claims.ExpiresAt == nil {
		return "", time.Time{}, false
	}
	return claims.JTI(), claims.ExpiresAt.Time, true
}

// GenerateRefreshToken creates a cryptographically random refresh token.
func (s *TokenService) GenerateRefreshToken() string {
	return uuid.New().String() + uuid.New().String()
}

// AccessTokenTTL returns the configured access token duration.
func (s *TokenService) AccessTokenTTL() time.Duration {
	return s.accessTokenTTL
}

// RefreshTokenTTL returns the configured refresh token duration (7 days).
func (s *TokenService) RefreshTokenTTL() time.Duration {
	return s.refreshTokenTTL
}
