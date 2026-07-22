package handlers

import (
	"fmt"
	"io"
	"net/http"
	"strings"

	"github.com/gofiber/fiber/v2"
)

// ProxyHandler creates a reverse proxy handler that forwards requests to Django.
func ProxyHandler(djangoBaseURL string) fiber.Handler {
	return func(c *fiber.Ctx) error {
		// Build the target URL: replace /api/v1/ with /internal/
		path := c.Path()
		targetPath := strings.Replace(path, "/api/v1/", "/internal/", 1)
		targetURL := djangoBaseURL + targetPath

		// Add query string if present
		if qs := string(c.Request().URI().QueryString()); qs != "" {
			targetURL += "?" + qs
		}

		// Create the proxied request
		req, err := http.NewRequest(c.Method(), targetURL, strings.NewReader(string(c.Body())))
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"error": "Failed to create proxy request",
			})
		}

		// Forward relevant headers
		req.Header.Set("Content-Type", c.Get("Content-Type", "application/json"))
		if auth := c.Get("Authorization"); auth != "" {
			req.Header.Set("Authorization", auth)
		}

		// Execute the request
		client := &http.Client{}
		resp, err := client.Do(req)
		if err != nil {
			return c.Status(fiber.StatusBadGateway).JSON(fiber.Map{
				"error": fmt.Sprintf("Django backend unavailable: %v", err),
			})
		}
		defer resp.Body.Close()

		// Read response body
		body, err := io.ReadAll(resp.Body)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"error": "Failed to read backend response",
			})
		}

		// Forward status code and response
		c.Set("Content-Type", resp.Header.Get("Content-Type"))
		return c.Status(resp.StatusCode).Send(body)
	}
}
