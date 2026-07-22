package main

import (
	"fmt"
	"log"
	"os"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/joho/godotenv"

	"sensory-ai-gateway/config"
	"sensory-ai-gateway/handlers"
	"sensory-ai-gateway/middleware"
	"sensory-ai-gateway/services"
)

func main() {
	// Load .env file if present (for local dev)
	godotenv.Load()

	cfg := config.Load()

	// Initialize services
	djangoClient := services.NewDjangoClient(cfg.DjangoBaseURL)
	llmService := services.NewLLMService(cfg.LLMApiKey, cfg.LLMApiURL, cfg.LLMModel, cfg.LLMTimeout)
	colorMatcher := services.NewColorMatcher()

	// Use mock LLM if no API key is configured
	useMock := cfg.LLMApiKey == "" || cfg.LLMApiKey == "sk-your-openai-api-key-here"
	if useMock {
		log.Println("⚠️  LLM API key not configured — using mock responses")
	}

	// Initialize handlers
	analyzeHandler := handlers.NewAnalyzeHandler(djangoClient, llmService, colorMatcher, useMock)

	// Rate limiter
	rateLimiter := middleware.NewRateLimiter(cfg.RateLimitMax, cfg.RateLimitWindow)

	// Create Fiber app
	app := fiber.New(fiber.Config{
		BodyLimit:    20 * 1024 * 1024, // 20 MB for multipart uploads
		ErrorHandler: errorHandler,
	})

	// Global middleware
	app.Use(recover.New())
	app.Use(logger.New(logger.Config{
		Format: "${time} | ${status} | ${latency} | ${method} ${path}\n",
	}))
	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
		AllowHeaders: "Origin, Content-Type, Accept, Authorization",
		AllowMethods: "GET, POST, PUT, PATCH, DELETE, OPTIONS",
	}))

	// Health check (no auth)
	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"status":  "healthy",
			"service": "sensory-ai-gateway",
		})
	})

	// ── API v1 routes ──
	v1 := app.Group("/api/v1")

	// Public routes (no auth required) — proxied to Django
	v1.Post("/auth/register/", handlers.ProxyHandler(cfg.DjangoBaseURL))
	v1.Post("/auth/login/", handlers.ProxyHandler(cfg.DjangoBaseURL))

	// Authenticated routes
	authenticated := v1.Group("", middleware.AuthMiddleware(cfg.JWTSecret))
	authenticated.Use(rateLimiter.Middleware())

	// Auth routes (proxied to Django)
	authenticated.Get("/auth/me/", handlers.ProxyHandler(cfg.DjangoBaseURL))
	authenticated.Put("/auth/user/:id/", handlers.ProxyHandler(cfg.DjangoBaseURL))
	authenticated.Patch("/auth/user/:id/", handlers.ProxyHandler(cfg.DjangoBaseURL))

	// Profile routes (proxied to Django)
	authenticated.Get("/profile/:user_id/", handlers.ProxyHandler(cfg.DjangoBaseURL))
	authenticated.Put("/profile/:user_id/", handlers.ProxyHandler(cfg.DjangoBaseURL))
	authenticated.Patch("/profile/:user_id/", handlers.ProxyHandler(cfg.DjangoBaseURL))

	// Scan routes
	authenticated.Get("/scans/", handlers.ProxyHandler(cfg.DjangoBaseURL))
	authenticated.Get("/scans/:id/", handlers.ProxyHandler(cfg.DjangoBaseURL))

	// Recommendation routes (proxied to Django)
	authenticated.Get("/recommendations/", handlers.ProxyHandler(cfg.DjangoBaseURL))
	authenticated.Patch("/recommendations/:id/", handlers.ProxyHandler(cfg.DjangoBaseURL))

	// Progress routes (proxied to Django)
	authenticated.Get("/progress/:user_id/", handlers.ProxyHandler(cfg.DjangoBaseURL))

	// ── Gateway-owned route: Analyze Environment & AI Coach ──
	authenticated.Post("/analyze-environment", analyzeHandler.Handle)
	authenticated.Post("/coach/chat", handlers.CoachChatHandler(llmService, djangoClient))


	// Start server
	port := cfg.Port
	log.Printf("🚀 Sensory AI Gateway starting on port %s", port)
	log.Printf("   Django backend: %s", cfg.DjangoBaseURL)
	log.Printf("   LLM mock mode: %v", useMock)

	if err := app.Listen(":" + port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
		os.Exit(1)
	}
}

func errorHandler(c *fiber.Ctx, err error) error {
	code := fiber.StatusInternalServerError
	if e, ok := err.(*fiber.Error); ok {
		code = e.Code
	}

	return c.Status(code).JSON(fiber.Map{
		"error":   err.Error(),
		"code":    code,
		"message": fmt.Sprintf("An error occurred: %s", err.Error()),
	})
}
