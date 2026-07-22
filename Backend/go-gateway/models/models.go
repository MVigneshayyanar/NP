package models

// ── Request Models ──

// AnalyzeRequest represents the parsed multipart form data for room analysis.
type AnalyzeRequest struct {
	UserID    string `json:"user_id"`
	ImageData []byte `json:"-"`
	AudioData []byte `json:"-"`
	RoomName  string `json:"room_name"`
}

// ── Response Models ──

// LLMResponse represents the structured JSON response from the multimodal LLM.
type LLMResponse struct {
	EnvironmentScore int               `json:"environment_score"`
	FocusScore       int               `json:"focus_score"`
	SleepScore       int               `json:"sleep_score"`
	MoodScore        int               `json:"mood_score"`
	Lighting         SensoryDetail     `json:"lighting"`
	Noise            SensoryDetail     `json:"noise"`
	Texture          SensoryDetail     `json:"texture"`
	Recommendations  []RecommendationItem `json:"recommendations"`
}

// SensoryDetail represents a scored sensory category with notes.
type SensoryDetail struct {
	Score          int      `json:"score"`
	Notes          string   `json:"notes"`
	RecommendedHex []string `json:"recommended_hex,omitempty"`
}

// RecommendationItem represents a single recommendation from the LLM.
type RecommendationItem struct {
	Title    string `json:"title"`
	Category string `json:"category"`
	Priority string `json:"priority"`
	Action   string `json:"action"`
}

// ── Django API Models ──

// SensoryProfile represents the user's sensory profile fetched from Django.
type SensoryProfile struct {
	ID                 string   `json:"id"`
	UserID             string   `json:"user"`
	LightSensitivity   int      `json:"light_sensitivity"`
	SoundSensitivity   int      `json:"sound_sensitivity"`
	TextureSensitivity int      `json:"texture_sensitivity"`
	ColorSensitivity   int      `json:"color_sensitivity"`
	Goals              []string `json:"goals"`
}

// User represents user data from Django.
type User struct {
	ID              string `json:"id"`
	Username        string `json:"username"`
	Email           string `json:"email"`
	FullName        string `json:"full_name"`
	LivingSituation string `json:"living_situation"`
	PropertyStatus  string `json:"property_status"`
}

// AnalyzeResponse is the final response sent back to the mobile app.
type AnalyzeResponse struct {
	EnvironmentScore int               `json:"environment_score"`
	FocusScore       int               `json:"focus_score"`
	SleepScore       int               `json:"sleep_score"`
	MoodScore        int               `json:"mood_score"`
	Lighting         SensoryDetail     `json:"lighting"`
	Noise            SensoryDetail     `json:"noise"`
	Texture          SensoryDetail     `json:"texture"`
	Recommendations  []RecommendationItem `json:"recommendations"`
	ColorMatches     []ColorMatch      `json:"color_matches"`
	ScanID           string            `json:"scan_id"`
	Disclaimer       string            `json:"disclaimer"`
}

// ColorMatch represents a matched paint color.
type ColorMatch struct {
	AIHex       string  `json:"ai_hex"`
	PaintName   string  `json:"paint_name"`
	PaintCode   string  `json:"paint_code"`
	PaintBrand  string  `json:"paint_brand"`
	PaintHex    string  `json:"paint_hex"`
	LRV         float64 `json:"lrv"`
	DeltaE      float64 `json:"delta_e"`
}

// DjangoScanCreate is the payload sent to Django to create an EnvironmentScan.
type DjangoScanCreate struct {
	UserID           string        `json:"user"`
	ImageRef         string        `json:"image_ref"`
	AudioRef         string        `json:"audio_ref"`
	LLMOutput        interface{}   `json:"llm_output"`
	EnvironmentScore int           `json:"environment_score"`
	FocusScore       int           `json:"focus_score"`
	SleepScore       int           `json:"sleep_score"`
	MoodScore        int           `json:"mood_score"`
	ColorMatches     []ColorMatch  `json:"color_matches"`
	RoomName         string        `json:"room_name"`
}

// DjangoRecommendationCreate is the payload to create a recommendation in Django.
type DjangoRecommendationCreate struct {
	ScanID   string `json:"scan"`
	UserID   string `json:"user"`
	Category string `json:"category"`
	Priority string `json:"priority"`
	Title    string `json:"title"`
	Action   string `json:"action_text"`
}
