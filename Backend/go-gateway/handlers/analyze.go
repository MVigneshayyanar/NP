package handlers

import (
	"fmt"
	"log"

	"github.com/gofiber/fiber/v2"

	"sensory-ai-gateway/models"
	"sensory-ai-gateway/services"
)

const (
	maxImageSize = 10 * 1024 * 1024 // 10 MB
	maxAudioSize = 5 * 1024 * 1024  // 5 MB
	colorDisclaimer = "Phone-camera color capture is not lighting-condition-accurate. Varying LED warmth, shadows, and ambient light all distort what the camera sees vs. the true wall color. The matched paint codes are approximations."
)

// AnalyzeHandler handles POST /api/v1/analyze-environment.
// Orchestrates: multipart parsing → profile fetch → LLM call → color matching → save to Django → respond.
type AnalyzeHandler struct {
	djangoClient *services.DjangoClient
	llmService   *services.LLMService
	colorMatcher *services.ColorMatcher
	useMock      bool
}

// NewAnalyzeHandler creates a new analyze handler.
func NewAnalyzeHandler(
	djangoClient *services.DjangoClient,
	llmService *services.LLMService,
	colorMatcher *services.ColorMatcher,
	useMock bool,
) *AnalyzeHandler {
	return &AnalyzeHandler{
		djangoClient: djangoClient,
		llmService:   llmService,
		colorMatcher: colorMatcher,
		useMock:      useMock,
	}
}

// Handle processes the analyze-environment request.
func (ah *AnalyzeHandler) Handle(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)
	token := c.Locals("token").(string)
	roomName := c.FormValue("room_name", "Room")

	// 1. Parse multipart form data — image is required, audio is optional
	imageFile, err := c.FormFile("image")
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Image file is required",
		})
	}

	if imageFile.Size > maxImageSize {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": fmt.Sprintf("Image file too large (max %d MB)", maxImageSize/(1024*1024)),
		})
	}

	// Read image data
	imgReader, err := imageFile.Open()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to read image file",
		})
	}
	defer imgReader.Close()

	imageData := make([]byte, imageFile.Size)
	if _, err := imgReader.Read(imageData); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to read image data",
		})
	}

	// Read audio data (optional)
	var audioDBLevel float64 = 40.0 // Default moderate ambient level
	audioFile, err := c.FormFile("audio")
	if err == nil && audioFile != nil {
		if audioFile.Size > maxAudioSize {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": fmt.Sprintf("Audio file too large (max %d MB)", maxAudioSize/(1024*1024)),
			})
		}
		// In production, extract actual dB level from audio
		// For now, use a reasonable estimate
		audioDBLevel = 45.0
	}

	// 2. Fetch user's sensory profile from Django
	profile, err := ah.djangoClient.GetSensoryProfile(userID, token)
	if err != nil {
		log.Printf("Failed to fetch sensory profile for user %s: %v", userID, err)
		// Use default profile if fetch fails
		profile = &models.SensoryProfile{
			LightSensitivity:   50,
			SoundSensitivity:   50,
			TextureSensitivity: 50,
			ColorSensitivity:   50,
			Goals:              []string{},
		}
	}

	// 3. Fetch user data for living situation / property status constraints
	user, err := ah.djangoClient.GetUser(token)
	livingStatus := "apartment"
	propertyStatus := "renter"
	if err == nil && user != nil {
		if user.LivingSituation != "" {
			livingStatus = user.LivingSituation
		}
		if user.PropertyStatus != "" {
			propertyStatus = user.PropertyStatus
		}
	}

	// 4. Call LLM (or mock)
	var llmResponse *models.LLMResponse
	if ah.useMock {
		llmResponse = ah.llmService.GenerateMockResponse()
		log.Printf("Using mock LLM response for user %s", userID)
	} else {
		llmResponse, err = ah.llmService.AnalyzeRoom(imageData, audioDBLevel, profile, livingStatus, propertyStatus)
		if err != nil {
			log.Printf("LLM call failed for user %s: %v — falling back to mock", userID, err)
			// Fallback to mock on LLM failure
			llmResponse = ah.llmService.GenerateMockResponse()
		}
	}

	// 5. Color matching — match LLM-suggested hex codes to real paint colors
	var colorMatches []models.ColorMatch
	if len(llmResponse.Lighting.RecommendedHex) > 0 {
		colorMatches = ah.colorMatcher.MatchAllHexCodes(llmResponse.Lighting.RecommendedHex)
	}

	// 6. Save scan + recommendations to Django
	scanCreate := models.DjangoScanCreate{
		UserID:           userID,
		ImageRef:         fmt.Sprintf("scans/%s/%s", userID, imageFile.Filename),
		AudioRef:         "",
		LLMOutput:        llmResponse,
		EnvironmentScore: llmResponse.EnvironmentScore,
		FocusScore:       llmResponse.FocusScore,
		SleepScore:       llmResponse.SleepScore,
		MoodScore:        llmResponse.MoodScore,
		ColorMatches:     colorMatches,
		RoomName:         roomName,
	}

	if audioFile != nil {
		scanCreate.AudioRef = fmt.Sprintf("scans/%s/%s", userID, audioFile.Filename)
	}

	scanResult, err := ah.djangoClient.CreateScan(scanCreate, token)
	if err != nil {
		log.Printf("Failed to save scan to Django: %v", err)
		// Still return the analysis even if save fails
	}

	scanID := ""
	if scanResult != nil {
		if id, ok := scanResult["id"].(string); ok {
			scanID = id
		}
	}

	// Save recommendations to Django
	if scanID != "" && len(llmResponse.Recommendations) > 0 {
		var recs []models.DjangoRecommendationCreate
		for _, rec := range llmResponse.Recommendations {
			recs = append(recs, models.DjangoRecommendationCreate{
				ScanID:   scanID,
				UserID:   userID,
				Category: rec.Category,
				Priority: rec.Priority,
				Title:    rec.Title,
				Action:   rec.Action,
			})
		}
		if err := ah.djangoClient.CreateRecommendations(recs, token); err != nil {
			log.Printf("Failed to save recommendations: %v", err)
		}
	}

	// 7. Build and return the response
	response := models.AnalyzeResponse{
		EnvironmentScore: llmResponse.EnvironmentScore,
		FocusScore:       llmResponse.FocusScore,
		SleepScore:       llmResponse.SleepScore,
		MoodScore:        llmResponse.MoodScore,
		Lighting:         llmResponse.Lighting,
		Noise:            llmResponse.Noise,
		Texture:          llmResponse.Texture,
		Recommendations:  llmResponse.Recommendations,
		ColorMatches:     colorMatches,
		ScanID:           scanID,
		Disclaimer:       colorDisclaimer,
	}

	return c.Status(fiber.StatusOK).JSON(response)
}

// CoachChatHandler handles live AI Coach conversations with Gemini API.
func CoachChatHandler(llm *services.LLMService, django *services.DjangoClient) fiber.Handler {
	return func(c *fiber.Ctx) error {
		userID := c.Locals("user_id").(string)
		token := c.Locals("token").(string)

		var req struct {
			Message string `json:"message"`
		}
		if err := c.BodyParser(&req); err != nil || req.Message == "" {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Message is required"})
		}

		profile, _ := django.GetSensoryProfile(userID, token)
		lightSens := 50
		soundSens := 50
		if profile != nil {
			lightSens = profile.LightSensitivity
			soundSens = profile.SoundSensitivity
		}

		reply, err := llm.ChatWithCoach(req.Message, lightSens, soundSens)
		if err != nil || reply == "" {
			if err != nil {
				log.Printf("ChatWithCoach error: %v", err)
			}
			reply = fmt.Sprintf("Based on your sensory profile (Light: %d/100, Sound: %d/100), I recommend adjusting your ambient room environment for maximum comfort.", lightSens, soundSens)
		}

		return c.JSON(fiber.Map{
			"reply": reply,
		})
	}
}


