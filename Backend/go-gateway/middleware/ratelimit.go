package middleware

import (
	"sync"
	"time"

	"github.com/gofiber/fiber/v2"
)

// rateLimitEntry tracks requests for a single key.
type rateLimitEntry struct {
	count     int
	expiresAt time.Time
}

// RateLimiter provides per-user token bucket rate limiting.
type RateLimiter struct {
	mu       sync.Mutex
	entries  map[string]*rateLimitEntry
	max      int
	window   time.Duration
}

// NewRateLimiter creates a rate limiter with the given max requests per window.
func NewRateLimiter(max int, window time.Duration) *RateLimiter {
	rl := &RateLimiter{
		entries: make(map[string]*rateLimitEntry),
		max:     max,
		window:  window,
	}

	// Background cleanup every 5 minutes
	go func() {
		ticker := time.NewTicker(5 * time.Minute)
		defer ticker.Stop()
		for range ticker.C {
			rl.cleanup()
		}
	}()

	return rl
}

// Middleware returns a Fiber handler that enforces rate limits.
func (rl *RateLimiter) Middleware() fiber.Handler {
	return func(c *fiber.Ctx) error {
		// Use user_id if authenticated, otherwise IP
		key := c.IP()
		if userID, ok := c.Locals("user_id").(string); ok && userID != "" {
			key = "user:" + userID
		}

		rl.mu.Lock()
		entry, exists := rl.entries[key]
		now := time.Now()

		if !exists || now.After(entry.expiresAt) {
			// New window
			rl.entries[key] = &rateLimitEntry{
				count:     1,
				expiresAt: now.Add(rl.window),
			}
			rl.mu.Unlock()
			return c.Next()
		}

		if entry.count >= rl.max {
			rl.mu.Unlock()
			retryAfter := entry.expiresAt.Sub(now).Seconds()
			c.Set("Retry-After", time.Duration(retryAfter).String())
			return c.Status(fiber.StatusTooManyRequests).JSON(fiber.Map{
				"error":       "Rate limit exceeded",
				"retry_after": retryAfter,
			})
		}

		entry.count++
		rl.mu.Unlock()

		return c.Next()
	}
}

func (rl *RateLimiter) cleanup() {
	rl.mu.Lock()
	defer rl.mu.Unlock()
	now := time.Now()
	for key, entry := range rl.entries {
		if now.After(entry.expiresAt) {
			delete(rl.entries, key)
		}
	}
}
