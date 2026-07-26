package jwt

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

// TokenService handles JWT token generation and parsing.
type TokenService struct {
	secretKey       string
	accessTokenTTL  time.Duration
	refreshTokenTTL time.Duration
}

// NewTokenService creates a new TokenService with the given secret key.
func NewTokenService(secretKey string) *TokenService {
	return &TokenService{
		secretKey:       secretKey,
		accessTokenTTL:  15 * time.Minute,
		refreshTokenTTL: 7 * 24 * time.Hour,
	}
}

// Claims represents the JWT payload for access tokens.
type Claims struct {
	jwt.RegisteredClaims
	UserID   string `json:"user_id"`
	TenantID string `json:"tenant_id"`
	IsAdmin  bool   `json:"is_admin"`
}

// GenerateAccessToken creates a signed JWT access token for the given user.
// isAdmin is the platform-admin flag (authorizes securities write RPCs).
func (s *TokenService) GenerateAccessToken(userID, tenantID uuid.UUID, isAdmin bool) (string, error) {
	now := time.Now()
	claims := Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID.String(),
			ExpiresAt: jwt.NewNumericDate(now.Add(s.accessTokenTTL)),
			IssuedAt:  jwt.NewNumericDate(now),
		},
		UserID:   userID.String(),
		TenantID: tenantID.String(),
		IsAdmin:  isAdmin,
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(s.secretKey))
}

// ParseAccessToken validates and extracts claims from an access token. Returns
// userID, tenantID, and the platform-admin flag.
func (s *TokenService) ParseAccessToken(tokenStr string) (userID, tenantID uuid.UUID, isAdmin bool, err error) {
	token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return []byte(s.secretKey), nil
	})
	if err != nil {
		return uuid.Nil, uuid.Nil, false, fmt.Errorf("parse token: %w", err)
	}
	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return uuid.Nil, uuid.Nil, false, fmt.Errorf("invalid token claims")
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
