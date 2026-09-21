package grpc

import (
	"sync"
	"time"
)

// Rate-limit parameters: at most feedbackRatePerMin submissions per source IP
// per feedbackWindow. Capacity = feedbackRatePerMin (burst), refilled
// continuously at feedbackRatePerMin per feedbackWindow.
const (
	feedbackRatePerMin = 5
	feedbackWindow     = time.Minute
)

// feedbackBucket is one source IP's token bucket.
type feedbackBucket struct {
	tokens   float64
	lastSeen time.Time
}

// FeedbackRateLimiter is a hand-written per-IP token-bucket limiter
// (~30 lines, map + mutex + time window — zero external dependencies by
// design: golang.org/x/time/rate is not in go.mod and must not be added).
// Lazy cleanup of stale buckets is intentionally omitted: the entry set is
// bounded by distinct client IPs and each entry is a few dozen bytes.
type FeedbackRateLimiter struct {
	mu      sync.Mutex
	buckets map[string]*feedbackBucket
}

// NewFeedbackRateLimiter creates an empty limiter.
func NewFeedbackRateLimiter() *FeedbackRateLimiter {
	return &FeedbackRateLimiter{buckets: map[string]*feedbackBucket{}}
}

// Allow reports whether one request from ip may proceed. Buckets are created
// lazily at full capacity and refilled continuously based on elapsed time.
func (l *FeedbackRateLimiter) Allow(ip string) bool {
	now := time.Now()
	l.mu.Lock()
	defer l.mu.Unlock()

	b, ok := l.buckets[ip]
	if !ok {
		b = &feedbackBucket{tokens: feedbackRatePerMin, lastSeen: now}
		l.buckets[ip] = b
	} else {
		elapsed := now.Sub(b.lastSeen).Seconds()
		refill := elapsed * float64(feedbackRatePerMin) / feedbackWindow.Seconds()
		if b.tokens += refill; b.tokens > feedbackRatePerMin {
			b.tokens = feedbackRatePerMin
		}
	}
	b.lastSeen = now

	if b.tokens < 1 {
		return false
	}
	b.tokens--
	return true
}
