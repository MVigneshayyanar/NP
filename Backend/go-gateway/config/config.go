package config

import (
	"os"
	"strconv"
	"time"
)

// Config holds all configuration for the gateway.
type Config struct {
	// Server
	Port string

	// Django backend
	DjangoBaseURL string

	// JWT
	JWTSecret    string
	JWTAlgorithm string

	// LLM
	LLMApiKey        string
	LLMApiURL        string
	LLMModel         string
	LLMTimeout       time.Duration

	// Rate limiting
	RateLimitMax      int
	RateLimitWindow   time.Duration
}

// Load reads configuration from environment variables.
func Load() *Config {
	timeoutSec, _ := strconv.Atoi(getEnv("LLM_TIMEOUT_SECONDS", "60"))
	rateLimitMax, _ := strconv.Atoi(getEnv("RATE_LIMIT_MAX", "30"))
	rateLimitWindowSec, _ := strconv.Atoi(getEnv("RATE_LIMIT_WINDOW_SECONDS", "60"))

	return &Config{
		Port:              getEnv("GO_PORT", "3000"),
		DjangoBaseURL:     getEnv("DJANGO_BASE_URL", "http://django-core:8000"),
		JWTSecret:         getEnv("JWT_SECRET", "change-me"),
		JWTAlgorithm:      getEnv("JWT_ALGORITHM", "HS256"),
		LLMApiKey:         getEnv("LLM_API_KEY", ""),
		LLMApiURL:         getEnv("LLM_API_URL", "https://api.openai.com/v1/chat/completions"),
		LLMModel:          getEnv("LLM_MODEL", "gpt-4o"),
		LLMTimeout:        time.Duration(timeoutSec) * time.Second,
		RateLimitMax:      rateLimitMax,
		RateLimitWindow:   time.Duration(rateLimitWindowSec) * time.Second,
	}
}

func getEnv(key, fallback string) string {
	if val, ok := os.LookupEnv(key); ok {
		return val
	}
	return fallback
}
