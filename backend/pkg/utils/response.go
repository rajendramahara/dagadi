package utils

import "github.com/gofiber/fiber/v2"

type APIResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

func OK(c *fiber.Ctx, data interface{}) error {
	return c.JSON(APIResponse{Success: true, Data: data})
}

func Created(c *fiber.Ctx, data interface{}) error {
	return c.Status(fiber.StatusCreated).JSON(APIResponse{Success: true, Data: data})
}

func Fail(c *fiber.Ctx, status int, msg string) error {
	return c.Status(status).JSON(APIResponse{Success: false, Error: msg})
}
