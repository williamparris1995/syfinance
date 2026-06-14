package session

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"

	"github.com/yucai/server/internal/auth/application/command"
)

// RedisSessionStore implements command.SessionStore using Redis.
//
// Storage layout (refresh tokens are opaque — keyed by SHA-256 hash so the raw
// token is never persisted):
//
//	rt:{sha256(token)}   HASH { family_id, user_id, tenant_id, state }   TTL = refresh TTL
//	                     state ∈ {"active", "revoked"}
//	rtf:{family_id}      STRING = sha256(active_token)   TTL = refresh TTL
//
// `rtf:` enables family-wide revocation when reuse is detected (OWASP pattern).
type RedisSessionStore struct {
	client *redis.Client
}

// NewRedisSessionStore creates a new RedisSessionStore.
func NewRedisSessionStore(client *redis.Client) *RedisSessionStore {
	return &RedisSessionStore{client: client}
}

func sha256hex(s string) string {
	sum := sha256.Sum256([]byte(s))
	return hex.EncodeToString(sum[:])
}

func rtKey(token string) string { return "rt:" + sha256hex(token) }

// Create stores a freshly issued refresh token, opening a new session family.
func (s *RedisSessionStore) Create(ctx context.Context, token, familyID, userID, tenantID string, ttl time.Duration) error {
	h := sha256hex(token)
	pipe := s.client.TxPipeline()
	pipe.HSet(ctx, "rt:"+h, "family_id", familyID, "user_id", userID, "tenant_id", tenantID, "state", "active")
	pipe.Expire(ctx, "rt:"+h, ttl)
	pipe.Set(ctx, "rtf:"+familyID, h, ttl)
	if _, err := pipe.Exec(ctx); err != nil {
		return fmt.Errorf("create session: %w", err)
	}
	return nil
}

// rotateScript atomically: reads the old token's state; if revoked → reuse
// (revoke family); if active → tombstone old + register new as family active.
//
//	KEYS[1] = rt:{h(old)}   KEYS[2] = rt:{h(new)}
//	ARGV[1] = new ttl seconds   ARGV[2] = tombstone ttl seconds
//	ARGV[3] = new token hash   ARGV[4] = new family key (rtf:{family})
//	returns {"invalid"} | {"reuse"} | {"ok", user_id, tenant_id}
var rotateScript = redis.NewScript(`
local old = redis.call('HGETALL', KEYS[1])
if #old == 0 then return {'invalid'} end
local state, family, user, tenant = '', '', '', ''
for i = 1, #old, 2 do
  local k, v = old[i], old[i+1]
  if k == 'state' then state = v
  elseif k == 'family_id' then family = v
  elseif k == 'user_id' then user = v
  elseif k == 'tenant_id' then tenant = v end
end
if state == 'revoked' then
  -- Reuse detected: revoke the family's currently-active token.
  local familyKey = 'rtf:' .. family
  local active = redis.call('GET', familyKey)
  if active then redis.call('DEL', 'rt:' .. active) end
  redis.call('DEL', familyKey)
  return {'reuse'}
end
-- Rotate: tombstone old, register new as active for the family.
redis.call('HSET', KEYS[1], 'state', 'revoked')
redis.call('EXPIRE', KEYS[1], tonumber(ARGV[2]))
redis.call('HSET', KEYS[2], 'family_id', family, 'user_id', user, 'tenant_id', tenant, 'state', 'active')
redis.call('EXPIRE', KEYS[2], tonumber(ARGV[1]))
redis.call('SET', 'rtf:' .. family, ARGV[3], 'EX', tonumber(ARGV[1]))
return {'ok', user, tenant}
`)

// Rotate validates oldToken and atomically rotates to newToken.
func (s *RedisSessionStore) Rotate(ctx context.Context, oldToken, newToken string, ttl time.Duration) (userID, tenantID string, err error) {
	tombstoneTTL := ttl // keep revoked tokens resolvable (for reuse detection) until they'd naturally expire
	res, err := rotateScript.Run(ctx, s.client,
		[]string{rtKey(oldToken), rtKey(newToken)},
		int64(ttl.Seconds()), int64(tombstoneTTL.Seconds()), sha256hex(newToken),
	).Result()
	if err != nil {
		return "", "", fmt.Errorf("rotate refresh token: %w", err)
	}

	slice, ok := res.([]any)
	if !ok || len(slice) == 0 {
		return "", "", fmt.Errorf("rotate: unexpected script result")
	}
	outcome, _ := slice[0].(string)
	switch outcome {
	case "invalid":
		return "", "", command.ErrInvalidRefreshToken
	case "reuse":
		return "", "", command.ErrRefreshTokenReuse
	case "ok":
		if len(slice) < 3 {
			return "", "", fmt.Errorf("rotate: malformed ok result")
		}
		u, _ := slice[1].(string)
		t, _ := slice[2].(string)
		return u, t, nil
	default:
		return "", "", fmt.Errorf("rotate: unknown outcome %q", outcome)
	}
}

// Revoke deletes a refresh-token record (logout / explicit revocation).
func (s *RedisSessionStore) Revoke(ctx context.Context, token string) error {
	if err := s.client.Del(ctx, rtKey(token)).Err(); err != nil && !errors.Is(err, redis.Nil) {
		return fmt.Errorf("revoke refresh token: %w", err)
	}
	return nil
}
