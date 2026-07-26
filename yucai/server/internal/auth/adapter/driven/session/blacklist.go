package session

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// RedisTokenBlacklist implements command.TokenBlacklist using Redis.
//
// Storage layout:
//
//	jwt:blacklist:{jti}   STRING = "1"   TTL = seconds until the token's exp
//
// The TTL makes the set self-pruning: once the revoked token would have
// expired naturally, Redis drops the key, so the blacklist cannot grow
// unbounded and a transient Redis flush doesn't weaken revocation long-term
// (after exp the token is invalid anyway).
//
// We reuse the same *redis.Client as RedisSessionStore — refresh-token
// sessions and access-token revocation live in the same Redis instance, just
// under disjoint key prefixes (rt:*, rtf:*, jwt:blacklist:*).
type RedisTokenBlacklist struct {
	client *redis.Client
}

// NewRedisTokenBlacklist creates a new RedisTokenBlacklist.
func NewRedisTokenBlacklist(client *redis.Client) *RedisTokenBlacklist {
	return &RedisTokenBlacklist{client: client}
}

func blacklistKey(jti string) string { return "jwt:blacklist:" + jti }

// Add records a jti as revoked until exp. If exp has already passed the call is
// a no-op (the token is already invalid — nothing to revoke).
func (b *RedisTokenBlacklist) Add(ctx context.Context, jti string, exp time.Time) error {
	if jti == "" {
		return nil
	}
	ttl := time.Until(exp)
	if ttl <= 0 {
		// Token already expired — no point writing a key with a non-positive TTL.
		return nil
	}
	if err := b.client.Set(ctx, blacklistKey(jti), "1", ttl).Err(); err != nil {
		return fmt.Errorf("blacklist add: %w", err)
	}
	return nil
}

// IsBlacklisted returns true if jti was Add-ed and is still within its TTL.
// A missing key (redis.Nil) is the common case and reports (false, nil).
func (b *RedisTokenBlacklist) IsBlacklisted(ctx context.Context, jti string) (bool, error) {
	if jti == "" {
		// Token carries no jti (legacy pre-T02). Fail-open: don't reject — there
		// is nothing to look up. The signature + aud/iss checks have already run.
		return false, nil
	}
	n, err := b.client.Exists(ctx, blacklistKey(jti)).Result()
	if err != nil {
		if errors.Is(err, redis.Nil) {
			return false, nil
		}
		return false, fmt.Errorf("blacklist check: %w", err)
	}
	return n > 0, nil
}
