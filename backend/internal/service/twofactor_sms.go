package service

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"

	"dagadi-backend/internal/config"
)

// TwoFactorSMS sends a Dagadi-generated OTP through 2Factor's legacy custom
// OTP-template API. This is the API version supported by the configured key.
// The key never reaches the Flutter app.
type TwoFactorSMS struct {
	apiKey       string
	baseURL      string
	senderID     string
	templateName string
	client       *http.Client
}

func NewTwoFactorSMS(cfg *config.Config) *TwoFactorSMS {
	return &TwoFactorSMS{apiKey: cfg.TwoFactorAPIKey, baseURL: strings.TrimRight(cfg.TwoFactorBaseURL, "/"), senderID: cfg.TwoFactorSenderID, templateName: cfg.TwoFactorTemplateName, client: &http.Client{Timeout: 12 * time.Second}}
}

func (s *TwoFactorSMS) SendOTP(phone, name, code string) error {
	if s.apiKey == "" || s.senderID == "" {
		return fmt.Errorf("TWO_FACTOR_API_KEY or TWO_FACTOR_SENDER_ID is not configured")
	}
	phone = strings.TrimPrefix(strings.TrimSpace(phone), "+")
	phone = strings.TrimPrefix(phone, "91") // legacy OTP API expects 10 digits
	endpoint := fmt.Sprintf("%s/API/V1/%s/SMS/%s/%s/%s", s.baseURL, url.PathEscape(s.apiKey), url.PathEscape(phone), url.PathEscape(code), url.PathEscape(s.templateName))
	req, err := http.NewRequest(http.MethodPost, endpoint, nil)
	if err != nil {
		return err
	}
	resp, err := s.client.Do(req)
	if err != nil {
		return fmt.Errorf("2Factor request failed: %w", err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 2048))
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("2Factor rejected OTP request (%d): %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}
	// The transactional endpoint can return HTTP 200 even when its payload
	// reports a rejected request. Treat that as a failure so we never tell a
	// user an OTP was sent when 2Factor did not accept it.
	var result struct {
		Status    string `json:"Status"`
		StatusAlt string `json:"status"`
		Details   string `json:"Details"`
		SessionID string `json:"session_id"`
	}
	if err := json.Unmarshal(body, &result); err == nil {
		status := result.Status
		if status == "" {
			status = result.StatusAlt
		}
		if status != "" && !strings.EqualFold(status, "Success") && !strings.EqualFold(status, "sent") {
			return fmt.Errorf("2Factor did not accept the OTP request")
		}
	}
	reference := result.SessionID
	if reference == "" {
		reference = result.Details
	}
	if reference != "" {
		// Details is the provider's request/session reference. It is useful for
		// checking its delivery report and does not expose the OTP or API key.
		log.Printf("2Factor custom OTP template accepted; reference=%s", reference)
	}
	return nil
}
