package service

import (
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"

	"dagadi-backend/internal/config"
	"dagadi-backend/internal/models"
	"dagadi-backend/internal/repository"
	"dagadi-backend/pkg/utils"
)

type AuthService struct {
	cfg     *config.Config
	users   repository.UserRepository
	drivers repository.DriverRepository
	sms     *TwoFactorSMS
}

func NewAuthService(cfg *config.Config, users repository.UserRepository, drivers repository.DriverRepository) *AuthService {
	return &AuthService{cfg: cfg, users: users, drivers: drivers, sms: NewTwoFactorSMS(cfg)}
}

// RequestOTP issues an OTP for a phone number.
//   - development: always issues cfg.FixedOTP, no SMS sent (per spec).
//   - production: generates a random code; actual delivery happens via
//     Firebase Phone Auth on the client, this endpoint is only used for
//     the fallback/testing channel.
func (s *AuthService) RequestOTP(phone, name string) (string, error) {
	user, err := s.users.FindByPhone(phone)
	if err != nil {
		return "", err
	}
	recipientName := strings.TrimSpace(name)
	if user != nil && strings.TrimSpace(user.Name) != "" {
		recipientName = strings.TrimSpace(user.Name)
	}
	// Older local accounts may not have a display name. The approved DLT
	// template requires its first variable to contain a value, so never send
	// an empty name to 2Factor.
	if recipientName == "" {
		recipientName = "friend"
	}
	code := s.cfg.FixedOTP
	if !s.cfg.IsDevelopment() {
		var err error
		code, err = utils.GenerateOTP()
		if err != nil {
			return "", err
		}
		if err := s.sms.SendOTP(phone, recipientName, code); err != nil {
			return "", err
		}
	}
	expiry := time.Now().Add(10 * time.Minute)
	if err := s.users.SaveOTP(phone, code, expiry); err != nil {
		return "", err
	}
	// In development we return the code so the client can auto-fill it;
	// in production this would never be returned to the client.
	if s.cfg.IsDevelopment() {
		return code, nil
	}
	return "", nil
}

// CheckOTP verifies an entered code without consuming it. First-time users
// complete their name and role on the following screen, then VerifyOTPAndLogin
// performs the one-time consuming verification and creates the account.
func (s *AuthService) CheckOTP(phone, code string) (bool, error) {
	valid, err := s.users.ValidateOTP(phone, code)
	if err != nil || !valid {
		return false, err
	}
	user, err := s.users.FindByPhone(phone)
	if err != nil {
		return false, err
	}
	return user != nil, nil
}

// VerifyOTPAndLogin verifies the code, creating the user (and driver
// profile, if role=driver) on first login, then issues tokens.
func (s *AuthService) VerifyOTPAndLogin(phone, code string, role models.Role, name string) (accessToken, refreshToken string, user *models.User, err error) {
	name = strings.TrimSpace(name)
	// A first-time account must have a name. Unicode is preserved, so names
	// written in Hindi work exactly like names written in English.
	existingUser, err := s.users.FindByPhone(phone)
	if err != nil {
		return "", "", nil, err
	}
	if existingUser == nil && name == "" {
		return "", "", nil, errors.New("display name is required")
	}
	valid, err := s.users.VerifyAndConsumeOTP(phone, code)
	if err != nil {
		return "", "", nil, err
	}
	if !valid {
		return "", "", nil, errors.New("invalid or expired OTP")
	}

	user = existingUser
	if user == nil {
		user = &models.User{
			ID:       uuid.NewString(),
			Phone:    phone,
			Name:     name,
			Role:     role,
			Language: "en",
			IsActive: true,
		}
		if err := s.users.Create(user); err != nil {
			return "", "", nil, err
		}
		if role == models.RoleDriver {
			profile := &models.DriverProfile{ID: uuid.NewString(), UserID: user.ID}
			if err := s.drivers.CreateProfile(profile); err != nil {
				return "", "", nil, err
			}
		}
	}
	if !user.IsActive {
		return "", "", nil, errors.New("this account has been disabled by an administrator")
	}
	if err := s.users.RecordLogin(user.ID); err != nil {
		return "", "", nil, err
	}

	access, refresh, err := utils.GenerateTokenPair(s.cfg.JWTSecret, user.ID, string(user.Role))
	if err != nil {
		return "", "", nil, err
	}
	return access, refresh, user, nil
}

func (s *AuthService) Refresh(refreshToken string) (string, error) {
	claims, err := utils.ParseToken(s.cfg.JWTSecret, refreshToken)
	if err != nil {
		return "", err
	}
	access, _, err := utils.GenerateTokenPair(s.cfg.JWTSecret, claims.UserID, claims.Role)
	return access, err
}

func (s *AuthService) SwitchRole(userID string, role models.Role) (accessToken, refreshToken string, user *models.User, err error) {
	if role != models.RolePassenger && role != models.RoleDriver {
		return "", "", nil, errors.New("invalid role")
	}
	user, err = s.users.FindByID(userID)
	if err != nil || user == nil {
		return "", "", nil, errors.New("user not found")
	}
	if !user.IsActive {
		return "", "", nil, errors.New("this account has been disabled by an administrator")
	}
	if err := s.users.UpdateRole(userID, role); err != nil {
		return "", "", nil, err
	}
	user.Role = role
	if role == models.RoleDriver {
		profile, profileErr := s.drivers.FindByUserID(userID)
		if profileErr != nil {
			return "", "", nil, profileErr
		}
		if profile == nil {
			if err := s.drivers.CreateProfile(&models.DriverProfile{ID: uuid.NewString(), UserID: user.ID}); err != nil {
				return "", "", nil, err
			}
		}
	}
	accessToken, refreshToken, err = utils.GenerateTokenPair(s.cfg.JWTSecret, user.ID, string(role))
	return accessToken, refreshToken, user, err
}

func (s *AuthService) UpdateName(userID, name string) (*models.User, error) {
	name = strings.TrimSpace(name)
	if len(name) < 2 {
		return nil, errors.New("name must have at least 2 characters")
	}
	if err := s.users.UpdateName(userID, name); err != nil {
		return nil, err
	}
	user, err := s.users.FindByID(userID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, errors.New("account not found")
	}
	return user, nil
}
