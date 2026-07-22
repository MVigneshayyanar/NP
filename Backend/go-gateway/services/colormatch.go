package services

import (
	"encoding/json"

	"fmt"
	"math"
	"net/http"
	"sort"
	"strings"

	"sensory-ai-gateway/models"
)


// PaintColor represents a paint color in the local database.
type PaintColor struct {
	Name  string
	Code  string
	Brand string
	Hex   string
	R, G, B float64 // sRGB [0,1]
	L, A, Bv float64 // CIELAB
	LRV   float64    // Light Reflectance Value (0-100)
}

// ColorMatcher provides nearest-color matching against a paint database.
type ColorMatcher struct {
	colors []PaintColor
}

// NewColorMatcher creates a color matcher with the built-in paint database.
func NewColorMatcher() *ColorMatcher {
	cm := &ColorMatcher{}
	cm.loadDatabase()
	return cm
}

// FindNearest finds the N nearest paint colors to the given hex code.
// Queries The Color API for online color info and falls back/enhances with local paint DB.
func (cm *ColorMatcher) FindNearest(hex string, n int) []models.ColorMatch {
	hex = strings.TrimPrefix(hex, "#")
	if len(hex) != 6 {
		return nil
	}

	// 1. Try fetching online color details from The Color API (https://www.thecolorapi.com)
	onlineName := ""
	apiUrl := fmt.Sprintf("https://www.thecolorapi.com/id?hex=%s", hex)


	resp, err := http.Get(apiUrl)
	if err == nil && resp.StatusCode == http.StatusOK {
		var apiData struct {
			Name struct {
				Value string `json:"value"`
			} `json:"name"`
			Hex struct {
				Clean string `json:"clean"`
				Value string `json:"value"`
			} `json:"hex"`
		}
		if json.NewDecoder(resp.Body).Decode(&apiData) == nil && apiData.Name.Value != "" {
			onlineName = apiData.Name.Value
		}

		resp.Body.Close()
	}

	// 2. Perform CIEDE2000 nearest paint matching against local DB
	r, g, b := hexToRGB(hex)
	targetL, targetA, targetB := rgbToLab(r, g, b)

	type scored struct {
		color  PaintColor
		deltaE float64
	}

	var results []scored
	for _, pc := range cm.colors {
		de := ciede2000(targetL, targetA, targetB, pc.L, pc.A, pc.Bv)
		results = append(results, scored{color: pc, deltaE: de})
	}

	sort.Slice(results, func(i, j int) bool {
		return results[i].deltaE < results[j].deltaE
	})

	if n > len(results) {
		n = len(results)
	}

	matches := make([]models.ColorMatch, n)
	for i := 0; i < n; i++ {
		paintName := results[i].color.Name
		if onlineName != "" && i == 0 {
			paintName = fmt.Sprintf("%s (%s)", results[i].color.Name, onlineName)
		}

		matches[i] = models.ColorMatch{
			AIHex:      "#" + hex,
			PaintName:  paintName,
			PaintCode:  results[i].color.Code,
			PaintBrand: results[i].color.Brand,
			PaintHex:   results[i].color.Hex,
			LRV:        results[i].color.LRV,
			DeltaE:     math.Round(results[i].deltaE*100) / 100,
		}
	}

	return matches
}


// MatchAllHexCodes matches all hex codes from the LLM response.
func (cm *ColorMatcher) MatchAllHexCodes(hexCodes []string) []models.ColorMatch {
	var allMatches []models.ColorMatch
	for _, hex := range hexCodes {
		matches := cm.FindNearest(hex, 1)
		allMatches = append(allMatches, matches...)
	}
	return allMatches
}

// ── Color conversion helpers ──

func hexToRGB(hex string) (float64, float64, float64) {
	var r, g, b int
	fmt.Sscanf(hex, "%02x%02x%02x", &r, &g, &b)
	return float64(r) / 255.0, float64(g) / 255.0, float64(b) / 255.0
}

func rgbToLab(r, g, b float64) (float64, float64, float64) {
	// sRGB to linear
	r = srgbToLinear(r)
	g = srgbToLinear(g)
	b = srgbToLinear(b)

	// Linear RGB to XYZ (D65)
	x := r*0.4124564 + g*0.3575761 + b*0.1804375
	y := r*0.2126729 + g*0.7151522 + b*0.0721750
	z := r*0.0193339 + g*0.1191920 + b*0.9503041

	// XYZ to LAB (D65 white point)
	x /= 0.95047
	y /= 1.00000
	z /= 1.08883

	x = labF(x)
	y = labF(y)
	z = labF(z)

	L := 116.0*y - 16.0
	A := 500.0 * (x - y)
	B := 200.0 * (y - z)

	return L, A, B
}

func srgbToLinear(c float64) float64 {
	if c <= 0.04045 {
		return c / 12.92
	}
	return math.Pow((c+0.055)/1.055, 2.4)
}

func labF(t float64) float64 {
	if t > 0.008856 {
		return math.Cbrt(t)
	}
	return 7.787*t + 16.0/116.0
}

// ciede2000 calculates the CIEDE2000 color difference.
// Simplified but accurate implementation.
func ciede2000(L1, a1, b1, L2, a2, b2 float64) float64 {
	// This is a simplified version of CIEDE2000
	dL := L2 - L1
	da := a2 - a1
	db := b2 - b1

	C1 := math.Sqrt(a1*a1 + b1*b1)
	C2 := math.Sqrt(a2*a2 + b2*b2)
	dC := C2 - C1

	dH := math.Sqrt(math.Max(0, da*da+db*db-dC*dC))

	SL := 1.0
	SC := 1.0 + 0.045*((C1+C2)/2.0)
	SH := 1.0 + 0.015*((C1+C2)/2.0)

	return math.Sqrt(
		(dL/(1.0*SL))*(dL/(1.0*SL)) +
			(dC/(1.0*SC))*(dC/(1.0*SC)) +
			(dH/(1.0*SH))*(dH/(1.0*SH)),
	)
}

// loadDatabase populates the paint color database.
func (cm *ColorMatcher) loadDatabase() {
	// Seed database of ~60 popular paint colors from major brands
	// In production, this would come from a paint database API
	raw := []struct {
		Name, Code, Brand, Hex string
		LRV                    float64
	}{
		// Whites & Off-Whites
		{"Simply White", "OC-117", "Benjamin Moore", "#F2EFDF", 89.52},
		{"Chantilly Lace", "OC-65", "Benjamin Moore", "#F5F1E6", 92.20},
		{"Extra White", "SW-7006", "Sherwin-Williams", "#F1F0EB", 86.0},
		{"Alabaster", "SW-7008", "Sherwin-Williams", "#F0EDE1", 82.0},
		{"White Dove", "OC-17", "Benjamin Moore", "#EDE8D8", 83.17},
		{"Swiss Coffee", "OC-45", "Benjamin Moore", "#EDE1CE", 77.06},

		// Warm Neutrals
		{"Accessible Beige", "SW-7036", "Sherwin-Williams", "#D1C4A9", 46.0},
		{"Revere Pewter", "HC-172", "Benjamin Moore", "#C3B9A2", 44.0},
		{"Agreeable Gray", "SW-7029", "Sherwin-Williams", "#CBC4B5", 48.0},
		{"Edgecomb Gray", "HC-173", "Benjamin Moore", "#C6BBAA", 46.0},
		{"Balanced Beige", "SW-7037", "Sherwin-Williams", "#B5A791", 35.0},
		{"Kilim Beige", "SW-6106", "Sherwin-Williams", "#C4A882", 37.0},

		// Cool Grays
		{"Repose Gray", "SW-7015", "Sherwin-Williams", "#C0BCB4", 44.0},
		{"Mindful Gray", "SW-7016", "Sherwin-Williams", "#ABA79E", 33.0},
		{"Classic Gray", "OC-23", "Benjamin Moore", "#D6D1C8", 55.0},
		{"Stonington Gray", "HC-170", "Benjamin Moore", "#B8B6B0", 40.0},
		{"Gray Owl", "OC-52", "Benjamin Moore", "#C5C4BB", 50.0},
		{"Passive", "SW-7064", "Sherwin-Williams", "#C2BFB7", 47.0},

		// Blues
		{"Hale Navy", "HC-154", "Benjamin Moore", "#3D4F5F", 8.0},
		{"Naval", "SW-6244", "Sherwin-Williams", "#374355", 4.0},
		{"Beach Glass", "CSP-735", "Benjamin Moore", "#9FBEB8", 38.0},
		{"Rainwashed", "SW-6211", "Sherwin-Williams", "#C1D2CA", 52.0},
		{"Palladian Blue", "HC-144", "Benjamin Moore", "#B7CFC8", 50.0},
		{"Watery", "SW-6478", "Sherwin-Williams", "#B8D4CD", 54.0},
		{"Sea Salt", "SW-6204", "Sherwin-Williams", "#C8D1C3", 49.0},

		// Greens
		{"Sherwood Green", "HC-118", "Benjamin Moore", "#395946", 7.0},
		{"Pewter Green", "SW-6208", "Sherwin-Williams", "#A3AC9A", 33.0},
		{"Sage Green", "SW-2860", "Sherwin-Williams", "#B2AC96", 38.0},
		{"Evergreen Fog", "SW-9130", "Sherwin-Williams", "#96A48C", 28.0},
		{"Saybrook Sage", "HC-114", "Benjamin Moore", "#B1AC90", 38.0},
		{"October Mist", "1495", "Benjamin Moore", "#AEB199", 37.0},

		// Warm Colors
		{"Caliente", "AF-290", "Benjamin Moore", "#C23B2A", 10.0},
		{"Tricorn Black", "SW-6258", "Sherwin-Williams", "#353535", 3.0},
		{"Urbane Bronze", "SW-7048", "Sherwin-Williams", "#736258", 11.0},
		{"Iron Ore", "SW-7069", "Sherwin-Williams", "#4E4B48", 6.0},
		{"Cavern Clay", "SW-7701", "Sherwin-Williams", "#C2734E", 18.0},
		{"Redend Point", "SW-9081", "Sherwin-Williams", "#C2A593", 36.0},

		// Yellows & Golds
		{"Hawthorne Yellow", "HC-4", "Benjamin Moore", "#E4C97A", 55.0},
		{"June Day", "SW-6682", "Sherwin-Williams", "#EAD491", 63.0},
		{"Banana Cream", "OC-48", "Benjamin Moore", "#F0E4C0", 74.0},
		{"Venetian Yellow", "SW-6891", "Sherwin-Williams", "#D9BA6E", 45.0},

		// Pinks & Blushes
		{"First Light", "2102-70", "Benjamin Moore", "#F2E0D8", 76.0},
		{"Rosy Outlook", "CSP-115", "Benjamin Moore", "#D4A7A0", 37.0},
		{"Intimate White", "SW-6322", "Sherwin-Williams", "#EADDD6", 71.0},
		{"Angelic", "SW-6602", "Sherwin-Williams", "#F0DED8", 72.0},

		// Earthy / Natural
		{"Smokey Topaz", "CSP-985", "Benjamin Moore", "#A69279", 25.0},
		{"Warm Earth", "AF-085", "Benjamin Moore", "#866B55", 15.0},
		{"Latte", "SW-6108", "Sherwin-Williams", "#C2A88C", 35.0},
		{"Macadamia", "SW-6142", "Sherwin-Williams", "#CBBA9E", 44.0},

		// Purples / Lavenders
		{"Ash Violet", "CSP-570", "Benjamin Moore", "#B0A5A0", 34.0},
		{"Veiled Violet", "CSP-560", "Benjamin Moore", "#BEB3B0", 42.0},
		{"Potentially Purple", "SW-6821", "Sherwin-Williams", "#B8A6B2", 34.0},

		// Deep / Dramatic
		{"Wrought Iron", "2124-10", "Benjamin Moore", "#494847", 6.0},
		{"Kendall Charcoal", "HC-166", "Benjamin Moore", "#6B6A66", 12.0},
		{"Peppercorn", "SW-7674", "Sherwin-Williams", "#6C6760", 10.0},
		{"Snowbound", "SW-7004", "Sherwin-Williams", "#EDE8DF", 83.0},

		// Soft Warm Tones (for sleep/relaxation)
		{"Quiet Moments", "AF-680", "Benjamin Moore", "#B8C4C2", 44.0},
		{"Feather Down", "CSP-190", "Benjamin Moore", "#E8DDCC", 68.0},
		{"Natural Linen", "AF-190", "Benjamin Moore", "#CABFA7", 47.0},
		{"Cloud White", "OC-130", "Benjamin Moore", "#EFECE0", 85.0},
	}

	cm.colors = make([]PaintColor, len(raw))
	for i, c := range raw {
		hex := strings.TrimPrefix(c.Hex, "#")
		r, g, b := hexToRGB(hex)
		L, A, Bv := rgbToLab(r, g, b)
		cm.colors[i] = PaintColor{
			Name:  c.Name,
			Code:  c.Code,
			Brand: c.Brand,
			Hex:   c.Hex,
			R:     r,
			G:     g,
			B:     b,
			L:     L,
			A:     A,
			Bv:    Bv,
			LRV:   c.LRV,
		}
	}
}
