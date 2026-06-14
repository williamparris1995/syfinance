package command

import (
	"context"
	"errors"
	"time"

	"github.com/yucai/server/internal/shared/application/command"
)

// Sentinel errors for refresh-token outcomes.
var (
	// ErrInvalidRefreshToken is returned when the presented refresh token is
	// unknown or expired (no matching record in the session store).
	ErrInvalidRefreshToken = errors.New("invalid or expired refresh token")
	// ErrRefreshTokenReuse is returned when a refresh token that was already
	// rotated (revoked) is presented again — a strong signal of token theft.
	// Per OWASP guidance, the entire session family is revoked.
	ErrRefreshTokenReuse = errors.New("refresh token reuse detected")
)

// SessionStore is the port for refresh-token session management.
//
// Refresh tokens are OPAQUE (per RFC 6749 §1.5): the token itself is a random
// string and carries no user identity. The store keys records by the token's
// SHA-256 hash, so a presented token can be resolved to its session in O(1)
// without any client-supplied user identifier.
//
// Industry-standard guarantees:
//   - Token rotation: each Rotate issues a fresh token and tombstones the old one.
//   - Reuse detection: replaying a tombstoned token revokes the whole family.
//   - Hashed at rest: only SHA-256(token) is stored, never the raw token.
type SessionStore interface {
	// Create opens a new session family for a freshly issued refresh token.
	Create(ctx context.Context, token, familyID, userID, tenantID string, ttl time.Duration) error
	// Rotate validates oldToken, tombstones it, and registers newToken as the
	// family's active token (atomic). Returns the session's userID/tenantID.
	// Returns ErrInvalidRefreshToken if unknown/expired, ErrRefreshTokenReuse
	// if oldToken was already rotated (family is revoked).
	Rotate(ctx context.Context, oldToken, newToken string, ttl time.Duration) (userID, tenantID string, err error)
	// Revoke deletes a refresh token (logout / explicit revocation).
	Revoke(ctx context.Context, token string) error
}

// RefreshHandler orchestrates refresh-token rotation via the SessionStore.
// Token string generation and JWT issuance live in the application Service.
type RefreshHandler struct {
	store SessionStore
}

// NewRefreshHandler creates a new RefreshHandler.
func NewRefreshHandler(store SessionStore) *RefreshHandler {
	return &RefreshHandler{store: store}
}

// Rotate performs token rotation. The caller (Service) supplies oldToken and a
// freshly generated newToken; this returns the session identity for JWT issuance.
func (h *RefreshHandler) Rotate(ctx context.Context, oldToken, newToken string, ttl time.Duration) (userID, tenantID string, err error) {
	return h.store.Rotate(ctx, oldToken, newToken, ttl)
}

// Revoke removes a refresh-token session.
func (h *RefreshHandler) Revoke(ctx context.Context, token string) error {
	return h.store.Revoke(ctx, token)
}

// Handle satisfies command.Handler[RefreshCommand] (unused — Service drives rotation).
func (h *RefreshHandler) Handle(ctx context.Context, cmd RefreshCommand) error {
	return nil
}

// Compile-time interface check.
var _ command.Handler[RefreshCommand] = (*RefreshHandler)(nil)
