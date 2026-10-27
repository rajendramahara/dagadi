package service

import (
	"context"
	"database/sql"
	"log"

	"github.com/google/uuid"
)

// FCMSender is the interface the notification service depends on rather
// than the concrete Firebase SDK client, so it can be swapped for a fake
// in tests or a real firebase.google.com/go/v4/messaging.Client in
// production without touching callers.
type FCMSender interface {
	SendToToken(ctx context.Context, token, title, body string, data map[string]string) error
}

// noopFCMSender is used until Firebase credentials are configured; it
// logs instead of sending, so the rest of the notification flow (saving
// to the notifications table, choosing titles/bodies per event type) is
// fully exercised in development without needing real credentials.
type noopFCMSender struct{}

func (noopFCMSender) SendToToken(_ context.Context, token, title, body string, _ map[string]string) error {
	log.Printf("[fcm-noop] would send to token=%s title=%q body=%q", token, title, body)
	return nil
}

type NotificationService struct {
	db  *sql.DB
	fcm FCMSender
}

// NewNotificationService defaults to the no-op sender. Call
// SetFCMSender once Firebase Admin SDK credentials are wired up
// (cmd/server/main.go is the place to do that).
func NewNotificationService(db *sql.DB) *NotificationService {
	return &NotificationService{db: db, fcm: noopFCMSender{}}
}

func (s *NotificationService) SetFCMSender(sender FCMSender) {
	s.fcm = sender
}

// NotifyEvent is the single entry point every service calls for the
// notification types listed in the spec: OTP, Ride Request, Ride
// Accepted/Rejected, Parcel Accepted, Driver Arrival, Ticket Completed,
// Review Reminder, Admin Notices.
func (s *NotificationService) NotifyEvent(userID, eventType, title, body string, data map[string]string) error {
	id := uuid.NewString()
	dataJSON := "{}"
	if _, err := s.db.Exec(`INSERT INTO notifications (id, user_id, type, title, body, data_json)
		VALUES (?, ?, ?, ?, ?, ?)`, id, userID, eventType, title, body, dataJSON); err != nil {
		return err
	}

	rows, err := s.db.Query(`SELECT token FROM fcm_tokens WHERE user_id = ?`, userID)
	if err != nil {
		return err
	}
	defer rows.Close()
	var tokens []string
	for rows.Next() {
		var t string
		if err := rows.Scan(&t); err != nil {
			return err
		}
		tokens = append(tokens, t)
	}

	ctx := context.Background()
	for _, token := range tokens {
		if err := s.fcm.SendToToken(ctx, token, title, body, data); err != nil {
			log.Printf("fcm send failed for user %s: %v", userID, err)
		}
	}
	return nil
}

func (s *NotificationService) RegisterToken(userID, token string) error {
	_, err := s.db.Exec(`INSERT INTO fcm_tokens (id, user_id, token) VALUES (?, ?, ?)
		ON CONFLICT(token) DO UPDATE SET user_id = excluded.user_id`, uuid.NewString(), userID, token)
	return err
}
