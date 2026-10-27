package handler

import (
	"log"

	"github.com/gofiber/fiber/v2"

	"dagadi-backend/internal/models"
	"dagadi-backend/internal/service"
	"dagadi-backend/pkg/utils"
)

type AuthHandler struct {
	auth *service.AuthService
}

func NewAuthHandler(a *service.AuthService) *AuthHandler {
	return &AuthHandler{auth: a}
}

type requestOTPBody struct {
	Phone string `json:"phone"`
	Name  string `json:"name"`
}

func (h *AuthHandler) RequestOTP(c *fiber.Ctx) error {
	var body requestOTPBody
	if err := c.BodyParser(&body); err != nil || body.Phone == "" {
		return utils.Fail(c, fiber.StatusBadRequest, "phone is required")
	}
	code, err := h.auth.RequestOTP(body.Phone, body.Name)
	if err != nil {
		// Keep provider diagnostics on the server only. The client receives the
		// same safe message, while local troubleshooting retains the cause.
		log.Printf("OTP request failed for mobile ending %s: %v", lastFour(body.Phone), err)
		return utils.Fail(c, fiber.StatusInternalServerError, "could not generate OTP")
	}
	resp := fiber.Map{"otp_sent": true}
	if code != "" {
		resp["dev_otp"] = code // only populated in development mode
	}
	return utils.OK(c, resp)
}

func lastFour(phone string) string {
	if len(phone) <= 4 {
		return phone
	}
	return phone[len(phone)-4:]
}

type verifyOTPBody struct {
	Phone string      `json:"phone"`
	Code  string      `json:"code"`
	Role  models.Role `json:"role"`
	Name  string      `json:"name"`
}

func (h *AuthHandler) VerifyOTP(c *fiber.Ctx) error {
	var body verifyOTPBody
	if err := c.BodyParser(&body); err != nil || body.Phone == "" || body.Code == "" {
		return utils.Fail(c, fiber.StatusBadRequest, "phone and code are required")
	}
	if body.Role == "" {
		body.Role = models.RolePassenger
	}
	access, refresh, user, err := h.auth.VerifyOTPAndLogin(body.Phone, body.Code, body.Role, body.Name)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, err.Error())
	}
	return utils.OK(c, fiber.Map{"access_token": access, "refresh_token": refresh, "user": user})
}

// CheckOTP only validates the code so a new user can supply their profile
// information on the next step before the code is consumed.
func (h *AuthHandler) CheckOTP(c *fiber.Ctx) error {
	var body verifyOTPBody
	if err := c.BodyParser(&body); err != nil || body.Phone == "" || body.Code == "" {
		return utils.Fail(c, fiber.StatusBadRequest, "phone and code are required")
	}
	existing, err := h.auth.CheckOTP(body.Phone, body.Code)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "invalid or expired OTP")
	}
	return utils.OK(c, fiber.Map{"existing_account": existing})
}

func (h *AuthHandler) SwitchRole(c *fiber.Ctx) error {
	var body struct {
		Role models.Role `json:"role"`
	}
	if err := c.BodyParser(&body); err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "role is required")
	}
	userID, _ := c.Locals("user_id").(string)
	access, refresh, user, err := h.auth.SwitchRole(userID, body.Role)
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.OK(c, fiber.Map{"access_token": access, "refresh_token": refresh, "user": user})
}

func (h *AuthHandler) UpdateProfile(c *fiber.Ctx) error {
	var body struct {
		Name string `json:"name"`
	}
	if err := c.BodyParser(&body); err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "name is required")
	}
	user, err := h.auth.UpdateName(c.Locals("user_id").(string), body.Name)
	if err != nil {
		if err.Error() == "account not found" {
			return utils.Fail(c, fiber.StatusUnauthorized, "your previous session is no longer valid; please sign in again")
		}
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.OK(c, user)
}

type refreshBody struct {
	RefreshToken string `json:"refresh_token"`
}

func (h *AuthHandler) Refresh(c *fiber.Ctx) error {
	var body refreshBody
	if err := c.BodyParser(&body); err != nil || body.RefreshToken == "" {
		return utils.Fail(c, fiber.StatusBadRequest, "refresh_token is required")
	}
	access, err := h.auth.Refresh(body.RefreshToken)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "invalid refresh token")
	}
	return utils.OK(c, fiber.Map{"access_token": access})
}
