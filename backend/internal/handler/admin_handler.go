package handler

import (
	"github.com/gofiber/fiber/v2"

	"dagadi-backend/internal/service"
	"dagadi-backend/pkg/utils"
)

type AdminHandler struct {
	admin *service.AdminService
}

func NewAdminHandler(a *service.AdminService) *AdminHandler {
	return &AdminHandler{admin: a}
}

type adminLoginBody struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

func (h *AdminHandler) Login(c *fiber.Ctx) error {
	var body adminLoginBody
	if err := c.BodyParser(&body); err != nil || body.Username == "" || body.Password == "" {
		return utils.Fail(c, fiber.StatusBadRequest, "username and password are required")
	}
	token, err := h.admin.Login(body.Username, body.Password)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "invalid admin credentials")
	}
	return utils.OK(c, fiber.Map{"access_token": token})
}

type updateCredentialsBody struct {
	CurrentUsername string `json:"current_username"`
	NewUsername     string `json:"new_username"`
	NewPassword     string `json:"new_password"`
}

// UpdateCredentials - "Admin credentials should be editable from Admin Settings."
func (h *AdminHandler) UpdateCredentials(c *fiber.Ctx) error {
	var body updateCredentialsBody
	if err := c.BodyParser(&body); err != nil || body.NewUsername == "" || body.NewPassword == "" {
		return utils.Fail(c, fiber.StatusBadRequest, "new_username and new_password are required")
	}
	if len(body.NewPassword) < 8 {
		return utils.Fail(c, fiber.StatusBadRequest, "password must be at least 8 characters")
	}
	if err := h.admin.UpdateCredentials(body.CurrentUsername, body.NewUsername, body.NewPassword); err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not update credentials")
	}
	return utils.OK(c, fiber.Map{"updated": true})
}

func (h *AdminHandler) Dashboard(c *fiber.Ctx) error {
	data, err := h.admin.Dashboard()
	if err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not load dashboard")
	}
	return utils.OK(c, data)
}

type userStatusBody struct {
	IsActive bool `json:"is_active"`
}

func (h *AdminHandler) SetUserStatus(c *fiber.Ctx) error {
	var body userStatusBody
	if err := c.BodyParser(&body); err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "is_active is required")
	}
	if err := h.admin.SetUserActive(c.Params("id"), body.IsActive); err != nil {
		return utils.Fail(c, fiber.StatusNotFound, "user not found")
	}
	return utils.OK(c, fiber.Map{"updated": true, "is_active": body.IsActive})
}

func (h *AdminHandler) UserDetails(c *fiber.Ctx) error {
	detail, err := h.admin.UserDetails(c.Params("id"), c.Query("period", "today"))
	if err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not load user details")
	}
	if detail == nil {
		return utils.Fail(c, fiber.StatusNotFound, "user not found")
	}
	return utils.OK(c, detail)
}

func (h *AdminHandler) Fleets(c *fiber.Ctx) error {
	fleets, err := h.admin.Fleets()
	if err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not load fleets")
	}
	return utils.OK(c, fleets)
}
