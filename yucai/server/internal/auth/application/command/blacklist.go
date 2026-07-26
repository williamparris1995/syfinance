package command

import (
	"context"
	"time"
)

// TokenBlacklist is the port for access-token revocation (RFC 7519 §4.1.7 jti).
//
// Access JWTs are short-lived (default 15min) so we don't consult a database on
// every RPC — but that leaves a window where a stolen/leaked token stays valid
// after logout, password change, refresh rotation, or tenant deletion. Adding
// the token's jti to a Redis blacklist closes that window: AuthInterceptor
// checks it after parsing, and revocation points (logout, refresh rotation)
// write to it. The blacklist entry's TTL equals the token's remaining lifetime,
// so the set is self-pruning (no GC sweep needed).
//
// Storage is Redis (not the DB) so the check stays sub-millisecond and survives
// server restarts; the implementation lives in adapter/driven/session and
// reuses the same *redis.Client as the refresh-token SessionStore.
type TokenBlacklist interface {
	// Add records a jti as revoked until exp. After exp the entry is auto-expired
	// by Redis, so IsBlacklisted returns false for naturally-aged tokens.
	Add(ctx context.Context, jti string, exp time.Time) error
	// IsBlacklisted returns true if Add was called for jti and its TTL has not
	// elapsed. A redis.Nil miss (key absent) is reported as (false, nil).
	IsBlacklisted(ctx context.Context, jti string) (bool, error)
}

// noopTokenBlacklist is the default when no blacklist is wired (e.g. unit tests
// that don't exercise revocation). Every check returns "not revoked".
type noopTokenBlacklist struct{}

func (noopTokenBlacklist) Add(_ context.Context, _ string, _ time.Time) error {
	return nil
}
func (noopTokenBlacklist) IsBlacklisted(_ context.Context, _ string) (bool, error) {
	return false, nil
}

// NoopTokenBlacklist returns a TokenBlacklist that never revokes. Used as the
// default in tests that don't care about revocation.
func NoopTokenBlacklist() TokenBlacklist { return noopTokenBlacklist{} }
