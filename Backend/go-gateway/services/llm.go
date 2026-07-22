package services

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"sensory-ai-gateway/models"
)

// LLMService handles communication with the multimodal LLM API.
type LLMService struct {
	apiKey     string
	apiURL     string
	model      string
	httpClient *http.Client
}

// NewLLMService creates a new LLM service client.
func NewLLMService(apiKey, apiURL, model string, timeout time.Duration) *LLMService {
	return &LLMService{
		apiKey: apiKey,
		apiURL: apiURL,
		model:  model,
		httpClient: &http.Client{
			Timeout: timeout,
		},
	}
}

// AnalyzeRoom sends room image + profile to Google Gemini multimodal API and returns structured analysis.
func (ls *LLMService) AnalyzeRoom(
	imageData []byte,
	audioDBLevel float64,
	profile *models.SensoryProfile,
	livingStatus string,
	propertyStatus string,
) (*models.LLMResponse, error) {

	systemPrompt := ls.buildSystemPrompt(livingStatus, propertyStatus)
	userMessage := ls.buildUserMessage(profile, audioDBLevel)
	imageB64 := base64.StdEncoding.EncodeToString(imageData)

	// Build Gemini API payload
	geminiUrl := fmt.Sprintf("%s?key=%s", ls.apiURL, ls.apiKey)

	payload := map[string]interface{}{
		"system_instruction": map[string]interface{}{
			"parts": []map[string]interface{}{
				{"text": systemPrompt},
			},
		},
		"contents": []map[string]interface{}{
			{
				"parts": []map[string]interface{}{
					{"text": userMessage},
					{
						"inline_data": map[string]string{
							"mime_type": "image/jpeg",
							"data":      imageB64,
						},
					},
				},
			},
		},
		"generationConfig": map[string]interface{}{
			"response_mime_type": "application/json",
			"temperature":        0.3,
		},
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("marshaling Gemini payload: %w", err)
	}

	req, err := http.NewRequest("POST", geminiUrl, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("creating Gemini request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := ls.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("Gemini API call failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("Gemini API returned %d: %s", resp.StatusCode, string(respBody))
	}

	// Parse Gemini API response
	var geminiResp struct {
		Candidates []struct {
			Content struct {
				Parts []struct {
					Text string `json:"text"`
				} `json:"parts"`
			} `json:"content"`
		} `json:"candidates"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&geminiResp); err != nil {
		return nil, fmt.Errorf("decoding Gemini response: %w", err)
	}

	if len(geminiResp.Candidates) == 0 || len(geminiResp.Candidates[0].Content.Parts) == 0 {
		return nil, fmt.Errorf("Gemini returned no response text")
	}

	content := geminiResp.Candidates[0].Content.Parts[0].Text
	var llmResponse models.LLMResponse
	if err := json.Unmarshal([]byte(content), &llmResponse); err != nil {
		return nil, fmt.Errorf("parsing Gemini JSON output: %w (raw: %s)", err, content)
	}

	if err := ls.validateResponse(&llmResponse); err != nil {
		return nil, fmt.Errorf("Gemini response validation failed: %w", err)
	}

	return &llmResponse, nil
}


// GenerateMockResponse returns a realistic mock LLM response for testing.
func (ls *LLMService) GenerateMockResponse() *models.LLMResponse {
	return &models.LLMResponse{
		EnvironmentScore: 72,
		FocusScore:       68,
		SleepScore:       75,
		MoodScore:        70,
		Lighting: models.SensoryDetail{
			Score: 65,
			Notes: "The room has moderate natural lighting but could benefit from warmer-toned lamps for evening use. Current overhead lighting appears to be cool white, which may interfere with relaxation.",
			RecommendedHex: []string{"#F5E6D3", "#E8D5B7", "#FFF8E7"},
		},
		Noise: models.SensoryDetail{
			Score: 78,
			Notes: "Ambient noise levels appear moderate. Consider adding soft furnishings to absorb echo and improve acoustic comfort.",
		},
		Texture: models.SensoryDetail{
			Score: 70,
			Notes: "A mix of hard and soft surfaces detected. Adding a textured rug or cushions could enhance tactile comfort and reduce visual harshness.",
		},
		Recommendations: []models.RecommendationItem{
			{
				Title:    "Add Warm Lighting",
				Category: "lighting",
				Priority: "high",
				Action:   "Replace cool-white overhead lights with warm-toned (2700K-3000K) LED bulbs or add a floor lamp with a warm shade for evening relaxation.",
			},
			{
				Title:    "Reduce Echo",
				Category: "noise",
				Priority: "medium",
				Action:   "Add a medium-weight curtain to the window and consider a soft area rug to absorb sound reflections.",
			},
			{
				Title:    "Add Textural Variety",
				Category: "texture",
				Priority: "low",
				Action:   "Introduce throw pillows or a knitted blanket with varied textures to create a more inviting tactile environment.",
			},
			{
				Title:    "Optimize Desk Placement",
				Category: "layout",
				Priority: "medium",
				Action:   "Consider positioning your workspace perpendicular to the window to reduce glare while maintaining natural light exposure for focus.",
			},
		},
	}
}

func (ls *LLMService) buildSystemPrompt(livingStatus, propertyStatus string) string {
	constraints := ""
	if propertyStatus == "renter" {
		constraints = `
CRITICAL CONSTRAINT: The user is a RENTER. You MUST NOT suggest any of the following:
- Removing, adding, or modifying walls
- Plumbing changes
- Electrical rewiring
- Permanent fixtures that require drilling into walls
- Painting (unless explicitly noted as removable/temporary)
- Any structural modifications
Only suggest reversible, non-permanent changes that a renter can make.`
	}

	return fmt.Sprintf(`You are Sensory AI, an expert environmental wellness analyst. You analyze room photos for sensory comfort — lighting, noise, texture, color — and provide personalized recommendations.

You MUST respond with ONLY valid JSON matching this exact schema:
{
  "environment_score": <0-100 integer>,
  "focus_score": <0-100 integer>,
  "sleep_score": <0-100 integer>,
  "mood_score": <0-100 integer>,
  "lighting": {
    "score": <0-100 integer>,
    "notes": "<detailed observation about lighting>",
    "recommended_hex": ["<hex color codes for suggested wall/accent colors>"]
  },
  "noise": {
    "score": <0-100 integer>,
    "notes": "<observation about potential noise/acoustic characteristics>"
  },
  "texture": {
    "score": <0-100 integer>,
    "notes": "<observation about textures, materials, surfaces>"
  },
  "recommendations": [
    {
      "title": "<short actionable title>",
      "category": "lighting|noise|texture|layout",
      "priority": "high|medium|low",
      "action": "<specific, actionable recommendation>"
    }
  ]
}

Living situation: %s
Property status: %s
%s

Score interpretation: 0-30 = poor, 31-50 = below average, 51-70 = average, 71-85 = good, 86-100 = excellent.
Provide 3-6 practical recommendations. Be specific and actionable.`, livingStatus, propertyStatus, constraints)
}

func (ls *LLMService) buildUserMessage(profile *models.SensoryProfile, audioDBLevel float64) string {
	goals := "none specified"
	if len(profile.Goals) > 0 {
		goals = strings.Join(profile.Goals, ", ")
	}

	return fmt.Sprintf(`Analyze this room photo for sensory comfort.

User's sensory sensitivities (0-100, higher = more sensitive):
- Light & Brightness: %d
- Sound: %d
- Touch & Texture: %d
- Colors: %d

User's goals: %s
Ambient audio level: %.1f dB

Please provide a comprehensive sensory analysis with scores and recommendations tailored to these sensitivities and goals.`,
		profile.LightSensitivity,
		profile.SoundSensitivity,
		profile.TextureSensitivity,
		profile.ColorSensitivity,
		goals,
		audioDBLevel,
	)
}

func (ls *LLMService) validateResponse(resp *models.LLMResponse) error {
	if resp.EnvironmentScore < 0 || resp.EnvironmentScore > 100 {
		return fmt.Errorf("environment_score out of range: %d", resp.EnvironmentScore)
	}
	if resp.FocusScore < 0 || resp.FocusScore > 100 {
		return fmt.Errorf("focus_score out of range: %d", resp.FocusScore)
	}
	if resp.SleepScore < 0 || resp.SleepScore > 100 {
		return fmt.Errorf("sleep_score out of range: %d", resp.SleepScore)
	}
	if resp.MoodScore < 0 || resp.MoodScore > 100 {
		return fmt.Errorf("mood_score out of range: %d", resp.MoodScore)
	}

	// Validate recommendations
	validCategories := map[string]bool{"lighting": true, "noise": true, "texture": true, "layout": true}
	validPriorities := map[string]bool{"high": true, "medium": true, "low": true}

	for i, rec := range resp.Recommendations {
		if !validCategories[rec.Category] {
			return fmt.Errorf("recommendation %d has invalid category: %s", i, rec.Category)
		}
		if !validPriorities[rec.Priority] {
			return fmt.Errorf("recommendation %d has invalid priority: %s", i, rec.Priority)
		}
		if rec.Title == "" || rec.Action == "" {
			return fmt.Errorf("recommendation %d missing title or action", i)
		}
	}

	return nil
}

// ChatWithCoach sends a chat message to Gemini API with user sensory profile context.
func (ls *LLMService) ChatWithCoach(userMsg string, lightSens, soundSens int) (string, error) {
	if ls.apiKey == "" {
		return fmt.Sprintf("Based on your sensitivities (Light: %d/100, Sound: %d/100), warm dim lighting and low acoustic reverberation will help you focus.", lightSens, soundSens), nil
	}

	geminiUrl := fmt.Sprintf("%s?key=%s", ls.apiURL, ls.apiKey)
	prompt := fmt.Sprintf(
		"You are Sensory AI Coach. The user has light sensitivity %d/100 and sound sensitivity %d/100 (higher = more sensitive). Answer this question helpfully in 2-3 sentences with personalized sensory advice: %s",
		lightSens, soundSens, userMsg,
	)

	payload := map[string]interface{}{
		"contents": []map[string]interface{}{
			{
				"parts": []map[string]interface{}{
					{"text": prompt},
				},
			},
		},
		"generationConfig": map[string]interface{}{
			"temperature":     0.7,
			"maxOutputTokens": 200,
		},
	}

	bodyBytes, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("marshal payload: %w", err)
	}

	req, err := http.NewRequest("POST", geminiUrl, bytes.NewReader(bodyBytes))
	if err != nil {
		return "", fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := ls.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("gemini request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("gemini returned %d: %s", resp.StatusCode, string(respBody))
	}

	var result struct {
		Candidates []struct {
			Content struct {
				Parts []struct {
					Text string `json:"text"`
				} `json:"parts"`
			} `json:"content"`
		} `json:"candidates"`
	}

	if err := json.Unmarshal(respBody, &result); err != nil {
		return "", fmt.Errorf("decode gemini response: %w (raw: %s)", err, string(respBody))
	}

	if len(result.Candidates) > 0 && len(result.Candidates[0].Content.Parts) > 0 {
		return strings.TrimSpace(result.Candidates[0].Content.Parts[0].Text), nil
	}

	return "", fmt.Errorf("gemini returned empty candidates: %s", string(respBody))
}

