package middleware

import (
	"strings"

	"github.com/gofiber/fiber/v2"

	"dagadi-backend/pkg/utils"
)

// RequireAuth validates the JWT access token and stores user_id/role
// in the request context (c.Locals) for downstream handlers.
func RequireAuth(secret string) fiber.Handler {
	return func(c *fiber.Ctx) error {
		header := c.Get("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			return utils.Fail(c, fiber.StatusUnauthorized, "missing bearer token")
		}
		token := strings.TrimPrefix(header, "Bearer ")
		claims, err := utils.ParseToken(secret, token)
		if err != nil {
			return utils.Fail(c, fiber.StatusUnauthorized, "invalid or expired token")
		}
		c.Locals("user_id", claims.UserID)
		c.Locals("role", claims.Role)
		return c.Next()
	}
}

// RequireRole must be chained after RequireAuth.
func RequireRole(roles ...string) fiber.Handler {
	allowed := make(map[string]bool)
	for _, r := range roles {
		allowed[r] = true
	}
	return func(c *fiber.Ctx) error {
		role, _ := c.Locals("role").(string)
		if !allowed[role] {
			return utils.Fail(c, fiber.StatusForbidden, "insufficient permissions")
		}
		return c.Next()
	}
}
