package session

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// RedisSessionStore implements command.SessionStore using Redis.
type RedisSessionStore struct {
	client *redis.Client
}

// NewRedisSessionStore creates a new RedisSessionStore.
func NewRedisSessionStore(client *redis.Client) *RedisSessionStore {
	return &RedisSessionStore{client: client}
}

// Store saves a refresh token for the given user with a TTL.
func (s *RedisSessionStore) Store(ctx context.Context, userID string, refreshToken string, ttlSeconds int64) error {
	key := fmt.Sprintf("refresh_token:%s", userID)
	ttl := time.Duration(ttlSeconds) * time.Second
	if err := s.client.Set(ctx, key, refreshToken, ttl).Err(); err != nil {
		return fmt.Errorf("store refresh token: %w", err)
	}
	return nil
}

// Validate checks if the refresh token matches the stored value.
func (s *RedisSessionStore) Validate(ctx context.Context, userID string, refreshToken string) (bool, error) {
	key := fmt.Sprintf("refresh_token:%s", userID)
	stored, err := s.client.Get(ctx, key).Result()
	if err == redis.Nil {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("validate refresh token: %w", err)
	}
	return stored == refreshToken, nil
}

// Delete removes the refresh token for the given user.
func (s *RedisSessionStore) Delete(ctx context.Context, userID string) error {
	key := fmt.Sprintf("refresh_token:%s", userID)
	if err := s.client.Del(ctx, key).Err(); err != nil {
		return fmt.Errorf("delete refresh token: %w", err)
	}
	return nil
}
