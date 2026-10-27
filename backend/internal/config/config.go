package config

import (
	"bufio"
	"os"
	"strings"
)

type Config struct {
	Port                  string
	DBPath                string
	JWTSecret             string
	Environment           string // "development" or "production"
	FixedOTP              string // used only when Environment == development
	FirebaseAPIKey        string // used only when Environment == production
	TwoFactorAPIKey       string
	TwoFactorBaseURL      string
	TwoFactorSenderID     string
	TwoFactorTemplateName string
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// Load reads configuration from environment variables (see .env.example).
// This is the single switch point between dev-mode fixed-OTP auth and
// production Firebase Phone Auth - nothing else in the codebase branches
// on environment.
func Load() *Config {
	loadDotEnv(".env")
	return &Config{
		Port:                  getEnv("PORT", "8080"),
		DBPath:                getEnv("DB_PATH", "./dagadi.db"),
		JWTSecret:             getEnv("JWT_SECRET", "dev-insecure-secret-change-me"),
		Environment:           getEnv("APP_ENV", "development"),
		FixedOTP:              getEnv("DEV_FIXED_OTP", "123456"),
		FirebaseAPIKey:        getEnv("FIREBASE_API_KEY", ""),
		TwoFactorAPIKey:       getEnv("TWO_FACTOR_API_KEY", ""),
		TwoFactorBaseURL:      getEnv("TWO_FACTOR_BASE_URL", "https://2factor.in"),
		TwoFactorSenderID:     getEnv("TWO_FACTOR_SENDER_ID", ""),
		TwoFactorTemplateName: getEnv("TWO_FACTOR_TEMPLATE_NAME", "Dagadi_Verification"),
	}
}

// loadDotEnv supports a local backend/.env file without adding another
// runtime dependency. Existing environment variables always take priority.
func loadDotEnv(path string) {
	file, err := os.Open(path)
	if err != nil {
		return
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok || os.Getenv(strings.TrimSpace(key)) != "" {
			continue
		}
		_ = os.Setenv(strings.TrimSpace(key), strings.Trim(strings.TrimSpace(value), "\""))
	}
}

func (c *Config) IsDevelopment() bool {
	return c.Environment == "development"
}
