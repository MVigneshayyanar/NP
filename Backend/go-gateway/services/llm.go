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

// ChatWithCoach sends a chat message with full RAG context (profile, goals, constraints, recent scans) to LLM.
func (ls *LLMService) ChatWithCoach(userMsg string, lightSens, soundSens int) (string, error) {
	return ls.ChatWithCoachRAG(userMsg, nil, &models.SensoryProfile{
		LightSensitivity: lightSens,
		SoundSensitivity: soundSens,
	}, nil)
}

// ChatWithCoachRAG sends a chat message with full RAG context to Gemini or dynamic AI Coach generator.
func (ls *LLMService) ChatWithCoachRAG(userMsg string, user *models.User, profile *models.SensoryProfile, scans []map[string]interface{}) (string, error) {
	// 1. Build RAG Profile Summary
	lightSens := 50
	soundSens := 50
	textureSens := 50
	colorSens := 50
	goals := "Enhance sensory comfort and daily productivity"

	if profile != nil {
		if profile.LightSensitivity > 0 {
			lightSens = profile.LightSensitivity
		}
		if profile.SoundSensitivity > 0 {
			soundSens = profile.SoundSensitivity
		}
		if profile.TextureSensitivity > 0 {
			textureSens = profile.TextureSensitivity
		}
		if profile.ColorSensitivity > 0 {
			colorSens = profile.ColorSensitivity
		}
		if len(profile.Goals) > 0 {
			goals = strings.Join(profile.Goals, ", ")
		}
	}

	userName := "Friend"
	propertyStatus := "renter"
	livingSituation := "apartment"
	if user != nil {
		if user.FullName != "" {
			userName = strings.Split(user.FullName, " ")[0]
		} else if user.Username != "" {
			userName = user.Username
		}
		if user.PropertyStatus != "" {
			propertyStatus = user.PropertyStatus
		}
		if user.LivingSituation != "" {
			livingSituation = user.LivingSituation
		}
	}

	// 2. Build RAG Scan Summary
	scansSummary := "No prior room scans recorded yet."
	if len(scans) > 0 {
		var scanLines []string
		for i, s := range scans {
			if i >= 3 {
				break
			}
			roomName := "Room"
			if rn, ok := s["room_name"].(string); ok && rn != "" {
				roomName = rn
			}
			score := 70
			if sc, ok := s["environment_score"].(float64); ok {
				score = int(sc)
			}
			scanLines = append(scanLines, fmt.Sprintf("- %s (Environmental Score: %d/100)", roomName, score))
		}
		scansSummary = strings.Join(scanLines, "\n")
	}

	systemPrompt := fmt.Sprintf(`You are "Sensory AI Coach", an empathetic, expert AI environmental psychologist and neuro-architectural wellness coach.

=== RETRIEVED USER CONTEXT (RAG) ===
- User: %s
- Living Situation: %s
- Property Status: %s
- Goals: %s
- Sensitivities (0-100 scale, >60 indicates high sensitivity / sensory avoidance, <30 indicates sensory seeking):
  * Light & Brightness: %d/100
  * Acoustic & Noise: %d/100
  * Tactile & Texture: %d/100
  * Color & Visual: %d/100

=== RECENT ENVIRONMENT SCANS (RAG) ===
%s

=== COACHING RULES ===
1. Speak warmly, encouragingly, and like an authentic AI specialist.
2. Directly address the user's specific question using their retrieved sensory profile and scan history.
3. If property status is renter, keep all advice 100%% non-destructive and temporary (e.g. lighting temp, rugs, curtains, acoustic panels, layout, plant placement).
4. Provide structured, actionable, and science-backed recommendations. Keep response concise and conversational.`,
		userName, livingSituation, propertyStatus, goals,
		lightSens, soundSens, textureSens, colorSens,
		scansSummary,
	)

	// If API Key is configured, execute request to Gemini API
	if ls.apiKey != "" && ls.apiKey != "sk-your-openai-api-key-here" {
		geminiUrl := fmt.Sprintf("%s?key=%s", ls.apiURL, ls.apiKey)
		payload := map[string]interface{}{
			"contents": []map[string]interface{}{
				{
					"parts": []map[string]interface{}{
						{"text": systemPrompt + "\n\nUser Question: " + userMsg},
					},
				},
			},
			"generationConfig": map[string]interface{}{
				"temperature":     0.7,
				"maxOutputTokens": 350,
			},
		}

		bodyBytes, err := json.Marshal(payload)
		if err == nil {
			req, err := http.NewRequest("POST", geminiUrl, bytes.NewReader(bodyBytes))
			if err == nil {
				req.Header.Set("Content-Type", "application/json")
				resp, err := ls.httpClient.Do(req)
				if err == nil {
					defer resp.Body.Close()
					if resp.StatusCode == http.StatusOK {
						respBody, err := io.ReadAll(resp.Body)
						if err == nil {
							var result struct {
								Candidates []struct {
									Content struct {
										Parts []struct {
											Text string `json:"text"`
										} `json:"parts"`
									} `json:"content"`
								} `json:"candidates"`
							}
							if err := json.Unmarshal(respBody, &result); err == nil && len(result.Candidates) > 0 && len(result.Candidates[0].Content.Parts) > 0 {
								return strings.TrimSpace(result.Candidates[0].Content.Parts[0].Text), nil
							}
						}
					}
				}
			}
		}
	}

	// Dynamic RAG Synthesis Fallback
	return generateDynamicRAGAdvice(userMsg, userName, lightSens, soundSens, textureSens, colorSens, propertyStatus, goals, scansSummary), nil
}

func generateDynamicRAGAdvice(userMsg, userName string, lightSens, soundSens, textureSens, colorSens int, propertyStatus, goals, scansSummary string) string {
	msgTrimmed := strings.TrimSpace(strings.ToLower(userMsg))

	// 1. Conversational Chit-chat & Greetings
	if msgTrimmed == "how are you" || msgTrimmed == "how are you?" || strings.HasPrefix(msgTrimmed, "how are you") || strings.Contains(msgTrimmed, "how r u") {
		return "I'm doing great, thank you for asking! I'm here and ready to help you optimize your living and working space for sensory wellness, better focus, and restorative sleep. How is your room feeling today?"
	}

	if msgTrimmed == "hi" || msgTrimmed == "hello" || msgTrimmed == "hey" || strings.HasPrefix(msgTrimmed, "hi ") || strings.HasPrefix(msgTrimmed, "hello ") || strings.HasPrefix(msgTrimmed, "hey ") {
		return fmt.Sprintf("Hello %s! Great to chat with you. How can I help you adjust your lighting, acoustics, or overall sensory space today?", userName)
	}

	if strings.Contains(msgTrimmed, "who are you") || strings.Contains(msgTrimmed, "what can you do") || strings.Contains(msgTrimmed, "what do you do") {
		return "I'm your Sensory AI Coach! I analyze your sensory profile and environment scans to give you actionable, science-backed guidance on ambient lighting, acoustic balance, restorative colors, and room ergonomics to help you focus and recharge."
	}

	if strings.Contains(msgTrimmed, "thank") || strings.Contains(msgTrimmed, "thx") {
		return "You're very welcome! Let me know whenever you'd like to explore more ways to elevate your space."
	}

	// 2. Specific Topic-Driven AI Advice
	if strings.Contains(msgTrimmed, "light") || strings.Contains(msgTrimmed, "bright") || strings.Contains(msgTrimmed, "lamp") || strings.Contains(msgTrimmed, "glare") || strings.Contains(msgTrimmed, "bulb") {
		if lightSens > 50 {
			return "Since you are sensitive to harsh light, direct cool-white LEDs can quickly trigger visual fatigue and eye strain. I recommend switching to diffuse, warm lighting (2700K to 3000K) placed at eye level or below, and using sheer linen shades to filter harsh direct sunlight."
		}
		return "For clean, energized focus, position your desk perpendicular to natural daylight to avoid monitor glare. During the evening, switch off cool ceiling lights and use warm layered task lamps to support your circadian melatonin production."
	}

	if strings.Contains(msgTrimmed, "sound") || strings.Contains(msgTrimmed, "noise") || strings.Contains(msgTrimmed, "quiet") || strings.Contains(msgTrimmed, "echo") || strings.Contains(msgTrimmed, "loud") {
		if soundSens > 50 {
			return "Hard walls and exposed flooring create flutter echoes that amplify background noise. To create a calm acoustic sanctuary, add dense plush rugs, floor-length curtains, and acoustic felt panels to absorb mid-frequency sound waves."
		}
		return "To maintain steady concentration, consider continuous gentle background brown noise or biophilic soundscapes (like flowing water or rustling leaves) to mask sudden ambient audio spikes."
	}

	if strings.Contains(msgTrimmed, "sleep") || strings.Contains(msgTrimmed, "night") || strings.Contains(msgTrimmed, "bed") || strings.Contains(msgTrimmed, "insomnia") {
		return "To optimize your sleep sanctuary, begin dimming all ambient lighting 60 minutes before bedtime. Keep background sound below 35dB, ensure breathable tactile bedding (such as washed cotton or linen), and keep your bedroom temperature between 65°F–68°F (18°C–20°C)."
	}

	if strings.Contains(msgTrimmed, "focus") || strings.Contains(msgTrimmed, "work") || strings.Contains(msgTrimmed, "desk") || strings.Contains(msgTrimmed, "productivity") {
		return "For uninterrupted deep work, keep your primary field of view minimalist and free of visual clutter. Position indirect 4000K lighting across your desk, keep acoustic distractions minimal, and introduce a low-maintenance plant to provide gentle biophilic rest."
	}

	if strings.Contains(msgTrimmed, "headache") || strings.Contains(msgTrimmed, "tired") || strings.Contains(msgTrimmed, "overload") || strings.Contains(msgTrimmed, "stress") {
		return "Sensory overload often stems from a combination of screen flicker, high-contrast overhead glare, and high ambient reverberation. Try stepping into a dim, quiet room for 5–10 minutes, lowering screen brightness, and taking slow diaphragmatic breaths."
	}

	if strings.Contains(msgTrimmed, "plant") || strings.Contains(msgTrimmed, "nature") || strings.Contains(msgTrimmed, "green") {
		return "Biophilic design has a profound calming effect on the nervous system. Low-maintenance plants like Snake Plants, Pothos, or Peace Lilies improve air quality and provide soothing natural visual patterns that reduce heart rate and cortisol levels."
	}

	if strings.Contains(msgTrimmed, "color") || strings.Contains(msgTrimmed, "paint") || strings.Contains(msgTrimmed, "wall") {
		return "For a restorative atmosphere, muted earthy tones like sage green, warm taupe, or soft slate blue promote tranquility and reduce cognitive load compared to high-saturation bright colors."
	}

	// 3. Holistic Personalized Response
	return fmt.Sprintf("Based on your wellness goals (%s), fine-tuning your room with warm 2700K indirect lighting, adding soft textiles to absorb echo, and maintaining a clear visual workspace will create the greatest immediate improvement in your daily comfort.", goals)
}

