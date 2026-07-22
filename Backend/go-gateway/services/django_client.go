package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"sensory-ai-gateway/models"
)

// DjangoClient communicates with the Django internal API.
type DjangoClient struct {
	baseURL    string
	httpClient *http.Client
}

// NewDjangoClient creates a new Django API client.
func NewDjangoClient(baseURL string) *DjangoClient {
	return &DjangoClient{
		baseURL: baseURL,
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// GetSensoryProfile fetches a user's sensory profile by user ID.
func (dc *DjangoClient) GetSensoryProfile(userID, token string) (*models.SensoryProfile, error) {
	url := fmt.Sprintf("%s/internal/profile/%s/", dc.baseURL, userID)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+token)

	resp, err := dc.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("fetching sensory profile: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("django returned %d: %s", resp.StatusCode, string(body))
	}

	var profile models.SensoryProfile
	if err := json.NewDecoder(resp.Body).Decode(&profile); err != nil {
		return nil, fmt.Errorf("decoding profile: %w", err)
	}

	return &profile, nil
}

// GetUser fetches user data (for living_situation/property_status checks).
func (dc *DjangoClient) GetUser(token string) (*models.User, error) {
	url := fmt.Sprintf("%s/internal/auth/me/", dc.baseURL)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+token)

	resp, err := dc.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("fetching user: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("django returned %d: %s", resp.StatusCode, string(body))
	}

	var user models.User
	if err := json.NewDecoder(resp.Body).Decode(&user); err != nil {
		return nil, fmt.Errorf("decoding user: %w", err)
	}

	return &user, nil
}

// CreateScan creates a new EnvironmentScan in Django.
func (dc *DjangoClient) CreateScan(scan models.DjangoScanCreate, token string) (map[string]interface{}, error) {
	url := fmt.Sprintf("%s/internal/scans/", dc.baseURL)

	body, err := json.Marshal(scan)
	if err != nil {
		return nil, fmt.Errorf("marshaling scan: %w", err)
	}

	req, err := http.NewRequest("POST", url, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := dc.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("creating scan: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		respBody, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("django returned %d: %s", resp.StatusCode, string(respBody))
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("decoding scan response: %w", err)
	}

	return result, nil
}

// CreateRecommendations bulk-creates recommendations in Django.
func (dc *DjangoClient) CreateRecommendations(recs []models.DjangoRecommendationCreate, token string) error {
	url := fmt.Sprintf("%s/internal/recommendations/", dc.baseURL)

	body, err := json.Marshal(recs)
	if err != nil {
		return fmt.Errorf("marshaling recommendations: %w", err)
	}

	req, err := http.NewRequest("POST", url, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("creating request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := dc.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("creating recommendations: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("django returned %d: %s", resp.StatusCode, string(respBody))
	}

	return nil
}
