package repository

import (
	"database/sql"
	"errors"
	"time"

	"dagadi-backend/internal/models"
)

// UserRepository is the interface consumed by services. Swapping the
// backing store to Postgres later only means writing a new struct that
// implements this interface (placeholders "?" -> "$1" etc.) - no
// business logic changes.
type UserRepository interface {
	FindByPhone(phone string) (*models.User, error)
	FindByID(id string) (*models.User, error)
	Create(u *models.User) error
	UpdateRole(userID string, role models.Role) error
	UpdateName(userID, name string) error
	SaveOTP(phone, code string, expiresAt time.Time) error
	VerifyAndConsumeOTP(phone, code string) (bool, error)
	ValidateOTP(phone, code string) (bool, error)
	RecordLogin(userID string) error
}

type sqliteUserRepo struct{ db *sql.DB }

func NewUserRepository(db *sql.DB) UserRepository {
	return &sqliteUserRepo{db: db}
}

func (r *sqliteUserRepo) FindByPhone(phone string) (*models.User, error) {
	row := r.db.QueryRow(`SELECT id, phone, name, role, language, is_active, created_at
		FROM users WHERE phone = ? AND deleted_at IS NULL`, phone)
	return scanUser(row)
}

func (r *sqliteUserRepo) FindByID(id string) (*models.User, error) {
	row := r.db.QueryRow(`SELECT id, phone, name, role, language, is_active, created_at
		FROM users WHERE id = ? AND deleted_at IS NULL`, id)
	return scanUser(row)
}

func scanUser(row *sql.Row) (*models.User, error) {
	var u models.User
	err := row.Scan(&u.ID, &u.Phone, &u.Name, &u.Role, &u.Language, &u.IsActive, &u.CreatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (r *sqliteUserRepo) Create(u *models.User) error {
	_, err := r.db.Exec(`INSERT INTO users (id, phone, name, role, language, is_active)
		VALUES (?, ?, ?, ?, ?, 1)`, u.ID, u.Phone, u.Name, u.Role, u.Language)
	return err
}

func (r *sqliteUserRepo) UpdateRole(userID string, role models.Role) error {
	_, err := r.db.Exec(`UPDATE users SET role = ? WHERE id = ? AND deleted_at IS NULL`, role, userID)
	return err
}

func (r *sqliteUserRepo) UpdateName(userID, name string) error {
	_, err := r.db.Exec(`UPDATE users SET name = ? WHERE id = ? AND deleted_at IS NULL`, name, userID)
	return err
}

func (r *sqliteUserRepo) SaveOTP(phone, code string, expiresAt time.Time) error {
	_, err := r.db.Exec(`INSERT INTO otp_codes (id, phone, code, expires_at)
		VALUES (lower(hex(randomblob(16))), ?, ?, ?)`, phone, code, expiresAt)
	return err
}

func (r *sqliteUserRepo) VerifyAndConsumeOTP(phone, code string) (bool, error) {
	row := r.db.QueryRow(`SELECT id FROM otp_codes
		WHERE phone = ? AND code = ? AND consumed = 0 AND expires_at > CURRENT_TIMESTAMP
		ORDER BY created_at DESC LIMIT 1`, phone, code)
	var id string
	if err := row.Scan(&id); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return false, nil
		}
		return false, err
	}
	_, err := r.db.Exec(`UPDATE otp_codes SET consumed = 1 WHERE id = ?`, id)
	return true, err
}

func (r *sqliteUserRepo) ValidateOTP(phone, code string) (bool, error) {
	row := r.db.QueryRow(`SELECT 1 FROM otp_codes
		WHERE phone = ? AND code = ? AND consumed = 0 AND expires_at > CURRENT_TIMESTAMP
		ORDER BY created_at DESC LIMIT 1`, phone, code)
	var valid int
	if err := row.Scan(&valid); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

func (r *sqliteUserRepo) RecordLogin(userID string) error {
	_, err := r.db.Exec(`INSERT INTO user_login_events (id, user_id) VALUES (lower(hex(randomblob(16))), ?)`, userID)
	return err
}
